"""
Neural network implementation for NRAM.
"""

import numpy as np
from numpy.random import uniform

from theano import shared
from theano.tensor.nnet import softmax, relu, sigmoid


def init_weight(*dims, low=-0.3, high=0.3):
    """Create a randomly-initialized shared variable weight matrix."""
    weights = uniform(low=low, high=high, size=dims)
    var = shared(weights.astype(np.float32), name="W{0}x{1}".format(*dims))

    return var

def mlp_weights(num_registers, layer_sizes, gates):
    """
    Generate weights and biases for all the connections
    in the neural network controller.

    layer_sizes: Number of units in each hidden layer.
    """

    # The first layer has one input per register.
    prev_layer = num_registers

    # Weights for making the hidden layers.
    for layer_size in layer_sizes:
        # Weights.
        yield init_weight(prev_layer, layer_size)
        # Biases.
        yield init_weight(1, layer_size)

        # Keep track of last layer size.
        prev_layer = layer_size

    # Weights for gate coefficients (output layers).
    for prev_gates, gate in enumerate(gates):
        num_outputs = num_registers + prev_gates
        for _ in range(gate.arity):
            # Weights.
            yield init_weight(prev_layer, num_outputs)
            # Biases.
            yield init_weight(1, num_outputs)

    # Weights for new register value coefficients (output layers).
    num_outputs = num_registers + len(gates)
    for _ in range(num_registers):
        # Weights.
        yield init_weight(prev_layer, num_outputs)
        # Biases.
        yield init_weight(1, num_outputs)

    # Weights for willingness to complete computation output.
    yield init_weight(prev_layer, 1)
    # Biases.
    yield init_weight(1, 1)

def take(values, i):
    """Return the next pair of weights and biases after the
    starting index and the new starting index."""
    return values[i], values[i + 1], i + 2

def mlp_forward_prop(num_registers, num_layers, gates,
                     registers, params):
    """Run forward propogation on the register machine (one step)."""
    debug = {}
    # Extract 0th component from all registers.
    last_layer = registers[:, :, 0]
    debug['input'] = last_layer

    # Propogate forward to hidden layers.
    idx = 0
    for i in range(num_layers):
        W, b, idx = take(params, idx)
        last_layer = relu(last_layer.dot(W) + b)
        debug['hidden-%d' % i] = last_layer

    # Propogate forward to gate coefficient outputs.
    # In the result list, each result is a list of
    # coefficients, as gates may have 0, 1, or 2 inputs.
    controller_coefficients = []
    for i, gate in enumerate(gates):
        coeffs = []
        for j in range(gate.arity):
            W, b, idx = take(params, idx)
            layer = softmax(last_layer.dot(W) + b)
            coeffs.append(layer)
            debug['coeff-gate-%d/%d' % (i, j)] = layer
        controller_coefficients.append(coeffs)

    # Forward propogate to new register value coefficients.
    for i in range(num_registers):
        W, b, idx = take(params, idx)
        coeffs = softmax(last_layer.dot(W) + b)
        controller_coefficients.append(coeffs)
        debug['coeff-reg-%d' % i] = coeffs

    # Forward propogate to generate willingness to complete.
    W, b, idx = take(params, idx)
    complete = sigmoid(last_layer.dot(W) + b)
    debug['complete'] = complete

    return debug, controller_coefficients, complete
