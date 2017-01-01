"""
Optimization methods for NRAM.
"""
import numpy as np

def adam_optimize(params, make_batch, train,
                  alpha=0.001, b1=0.9, b2=0.999,
                  epsilon=1e-8, noise=10, noise_decay=0.995):
    """Implementation of Adam optimization method, with hyperparameters
    taken as recommended by the original publication."""
    # Initialize first and second moment estimates to zero.
    # This causes some bias, which is addressed later.
    moment1 =  [0 for _ in params]
    moment2 = [0 for _ in params]

    timestep = 0  # Current optimization step

    converged = False
    while not converged:
        timestep += 1
        train_args  = make_batch(timestep)
        cost, *gradients = train(*train_args)

        # Clip gradients elementwise and normalize the vector to a given size.
        mag = 10.0
        norm = 30.0
        gradients = [np.clip(g, -mag, mag) for g in gradients]
        g_norm = np.sqrt(sum((g * g).sum() for g in gradients))
        gradients = [g * norm / g_norm for g in gradients]
        n = noise * noise_decay ** timestep
        gradients = [g + n * np.random.randn(*g.shape) for g in gradients]

        # Compute first and second moment estimates.
        # These are decaying moving averages; first moment
        # uses the gradient, second uses squared gradient.
        moment1  = [b1 * m + (1 - b1) * gradient
                    for (m, gradient)
                    in zip(moment1, gradients)]
        moment2 = [b2 * v + (1 - b2) * gradient ** 2
                   for (v, gradient)
                   in zip(moment2, gradients)]

        # Correct for initialization bias and compute new values.
        correction1 = 1. / (1 - b1 ** timestep)
        correction2 = 1. / (1 - b2 ** timestep)
        corrected1 = [correction1 * m for m in moment1]
        corrected2 = [correction2 * v for v in moment2]

        # Compute new parameter values.
        params_new = [p.get_value() - alpha * m1 / (np.sqrt(m2) + epsilon)
                      for (p, m1, m2) in zip(params, corrected1, corrected2)]

        # Check for convergence by looking at magnitude of delta.
        delta = [abs(p.get_value() - p_new)
                 for (p, p_new) in zip(params, params_new)]
        converged = all((d < 0.5 * alpha).all() for d in delta)

        # Update parameters to new values.
        for p, p_new in zip(params, params_new):
            p.set_value(p_new.astype('float32'))

        # Provide some output for tracking during runtime.
        if timestep % 100 == 1 or converged:
            print("Cost (t = %4d): \t%.2f" % (timestep - 1, cost))
