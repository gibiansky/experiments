"""
Utility functions for working with data.
"""
import itertools

import numpy as np

from theano.tensor.extra_ops import to_one_hot

def shuffle(inputs, outputs):
    """Jointly shuffle an array of inputs and an array of outputs."""
    num_samples = inputs.shape[0]
    shuffle_order = np.random.permutation(num_samples)
    return inputs[shuffle_order, :, :], outputs[shuffle_order, :]


def encode(samples, max_int):
    """Convert inputs to one-hot matrix form.
    The result is shape (S, R, M), where, as usual:
    S - num samples, R - num registers, M - max int
    """
    samples = np.asarray(samples)

    # Encode each register separately.
    # to_one_hot requires a 1-d vector.
    encoded = []
    for i in range(samples.shape[1]):
        encoded.append(to_one_hot(samples[:, i], max_int).eval())
    return np.asarray(encoded).swapaxes(0, 1)


def generate_data(num_inputs, max_int, fun):
    """Generate all possible input-output pairs using a generator function."""
    inputs = list(itertools.product(range(max_int),
                                    repeat=num_inputs))

    outputs = [fun(*values) for values in inputs]
    return inputs, outputs


def split_data(inputs, outputs, test_ratio=0.3):
    """Split the data into test and training sets."""
    num_samples = inputs.shape[0]
    split = int(num_samples * test_ratio)

    test_inputs = inputs[:split, :, :]
    test_outputs = outputs[:split, :]
    train_inputs = inputs[split:, :, :]
    train_outputs = outputs[split:, :]

    return (test_inputs, test_outputs), (train_inputs, train_outputs)
