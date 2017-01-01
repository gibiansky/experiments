"""
Implementation of Kurach et al. 2015 Neural Random Access Machines,
using Numpy and Theano.
"""
import theano
from theano import tensor
from theano.tensor.extra_ops import to_one_hot
from theano.tensor import (batched_dot, concatenate, as_tensor, dtensor3,
                           imatrix, bmatrix, stack, shape_padright, zeros,
                           set_subtensor, shape_padleft, repeat, addbroadcast,
                           arange, dscalar)

from nnet import mlp_forward_prop

def avg(distributions, coefficients):
    """
    Return the weighted average of a set of vectors.

    Shapes:
       distributions: (S, N, M)
       coefficients:  (S, N)
       return value:  (S, M)

    where
        S:  number of samples to perform this operation on
        N:  number of vectors in the set
        M:  number of elements in each vector
    """
    # Shuffle coefficients to shape (S, N, 1)
    coeffs = coefficients.dimshuffle(0, 1, 'x')

    # Transpose distributions to (S, M, N)
    dists = distributions.transpose(0, 2, 1)

    # Batched multiply to get shape (S, M, 1),
    # then drop the last dimension.
    return batched_dot(dists, coeffs).flatten(2)

def run_gate(gate_inputs, mem, gate, controller_coefficients, max_int):
    """Return the output of a gate in the circuit.

    gate_inputs:
      The values of the registers and previous gate outputs.
    gate:
      The gate to compute output for. Arity must
      match len(controller_coefficients).
    controller_coeffficients:
      A list of coefficient arrays from the controller,
      one coefficient for every gate input (0 for constants).
    """
    args = [avg(gate_inputs, coefficients)
            for coefficients in controller_coefficients]
    output, mem = gate.module(*args, max_int, mem)

    # Special-case constant gates.
    # Since they have no outputs, they always output
    # one sample. Repeat their outputs as many times
    # as necessary, effectively doing manual broadcasting
    # to generate an output of the right size.
    if gate.arity == 0:
        output = output.repeat(gate_inputs.shape[0], axis=0)

    return output, mem


def run_circuit(debug, registers, mem, gates, controller_coefficients,
                max_int):
    # Initially, only the registers may be used as inputs.
    gate_inputs = registers

    # Run through all the gates.
    for i, (gate, coeffs) in enumerate(zip(gates, controller_coefficients)):
        output, mem = run_gate(gate_inputs, mem, gate, coeffs, max_int)
        debug['gate-out-%d' % i] = output
        debug['gate-mem-%d' % i] = mem

        # Append the output of the gate as an input for future gates.
        gate_inputs = concatenate([gate_inputs, output.dimshuffle(0, 'x', 1)],
                                  axis=1)

    # All leftover coefficients are for registers.
    new_registers = []
    for i, coeff in enumerate(controller_coefficients[len(gates):]):
        reg = avg(gate_inputs, coeff)
        new_registers.append(reg)
        debug['reg-%d' % i] = reg
    return stack(new_registers, axis=1), mem


def step_machine(gates, max_int, num_registers, num_layers,
                 registers, mem, params):
    """Run a single timestep of the machine."""
    # Run single-step forward propagation.
    controller_out = mlp_forward_prop(num_registers, num_layers, gates,
                                      registers, params)
    debug, coefficients, complete = controller_out

    # Using the generated coefficients, advance the registers.
    new_registers, new_mem = run_circuit(debug, registers, mem, gates,
                                         coefficients, max_int)

    return debug, new_registers, new_mem, complete


def log_prob_correct(mem, desired_output, cost_mask, max_int):
    """Compute log-probability of correctness over all registers."""
    cost = 0

    # Add epsilon to every log to avoid having inf in costs.
    epsilon = 1e-100

    samples = mem.shape[0]
    sample_idxs = repeat(shape_padright(arange(samples), 1), max_int, axis=1)
    cell_idxs = repeat(shape_padleft(arange(max_int), 1), samples, axis=0)
    vals = mem[sample_idxs, cell_idxs, desired_output]
    cost = (cost_mask * tensor.log(vals + epsilon)).sum(axis=1, keepdims=True)

    return cost


def step_cost(gates, max_int, desired_output, cost_mask, max_timesteps,
              num_registers, num_layers, entropy_weight, timestep, registers,
              mem, cost, cum_prob_complete, prob_incomplete, params):
    # Run the machine forward one step.
    machine_result = step_machine(gates, max_int, num_registers,
                                  num_layers, registers, mem, params)
    debug, registers, mem, complete = machine_result

    # Complete the probability that the algorithm is done
    # after this step. Force the algorithm to complete after
    # T timesteps.
    if timestep == max_timesteps:
        prob_complete = 1 - cum_prob_complete
    else:
        prob_complete = complete * prob_incomplete
    debug['complete-prob'] = prob_complete

    # Update the probability that the computation isn't complete
    prob_incomplete *= 1 - complete
    debug['incomplete-prob'] = prob_incomplete

    # Accumulate the probability that a result has been produced.
    cum_prob_complete += prob_complete
    debug['complete-prob-cum'] = cum_prob_complete

    # Cost for this timestep.
    unscaled_cost = log_prob_correct(mem, desired_output, cost_mask, max_int)
    debug['cost-unscaled'] = unscaled_cost

    entropy_cost = entropy_weight * ((mem * tensor.log(mem + 1e-100))
                                     .sum(axis=2).sum(axis=1, keepdims=True))
    debug['cost-entropy'] = entropy_cost

    scaled_cost = prob_complete * unscaled_cost
    debug['cost-scaled'] = scaled_cost
    cost -= scaled_cost - entropy_cost
    debug['cost-cum'] = cost

    return debug, (registers, mem, cost, cum_prob_complete, prob_incomplete)


def make_broadcastable(weights, clip_gradients=None):
    """Shared variables (the weights of the controller) are
    not broadcastable by default. We need to make them broadcastable
    to use them. This function does so manually."""
    broadcastable = []
    for var in weights:
        # Only make biases broadcastable.
        if var.get_value().shape[0] == 1:
            # Keep the name the same.
            name = var.name
            var = addbroadcast(var, 0)
            var.name = name

        if clip_gradients is not None:
            var = theano.gradient.grad_clip(var, -clip_gradients,
                                            clip_gradients)
        broadcastable.append(var)

    return broadcastable

def run(gates, num_registers, max_int, num_timesteps, num_layers, reg_lambda,
        params, clip_gradients=None):
    params = make_broadcastable(params, clip_gradients=clip_gradients)

    # Create symbolic variables for the input to the machine
    # and for the desired output of the machine.
    initial_mem = dtensor3("InMem")
    desired_mem = imatrix("OutMem")
    cost_mask = bmatrix("CostMask")
    entropy_weight = dscalar("EntropyWeight")

    # Initialize all registers to zero. Instead of using to_one_hot,
    # create the shape directly; it's simpler this way.
    initial_registers = zeros((initial_mem.shape[0], num_registers, max_int),
                              dtype='float64')
    initial_registers = set_subtensor(initial_registers[:, :, 0], 1.0)

    # Run the model for all timesteps. The arguments are
    # registers, memory, cost, cumulative probability complete,
    # and probability incomplete. The latter are initialized
    # to zero and to one, respectively.
    v0 = as_tensor(0)
    v1 = as_tensor(1)
    output = (initial_registers, initial_mem, v0, v0, v1)
    debug = {}
    for timestep in range(num_timesteps):
        debug_local, output = step_cost(gates, max_int, desired_mem, cost_mask,
                                        num_timesteps, num_registers,
                                        num_layers, entropy_weight, 
                                        timestep + 1, *output, params)
        debug.update(("%d:%s" % (timestep, k), v)
                     for (k, v) in debug_local.items())


    # Add in regularization, to avoid overfitting simple examples.
    reg_cost = reg_lambda * sum((p * p).sum() for p in params)
    debug['cost-regularization'] = reg_cost

    # Get the final cost: regularization plus loss.
    final_cost = reg_cost + output[2].sum()
    debug['cost-final'] = final_cost

    # Return the symbolic variables, the final cost, and the
    # intermediate register values for analysis and prediction.
    mem = output[1]
    return debug, initial_mem, desired_mem, cost_mask, mem, final_cost, entropy_weight

def percent_correct(predict, inputs, outputs):
    """Compute the percent of examples that were computed correctly."""
    # Convert the one-hot encoding to integers.
    result = predict(inputs).argmax(axis=2)

    # Check how many of the registers for each sample
    # had the expected result.
    num_eq = (result == outputs).sum(axis=1)

    # A sample was correct if *all* of the registers
    # were correct. Count correct samples.
    all_eq = (num_eq == inputs.shape[1]).sum()

    # Return ratio of correct samples times 100.
    return 100 * float(all_eq) / inputs.shape[0]
