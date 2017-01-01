"""
Gate implementations for NRAM.

A gate is represented as a named tuple with 'arity' and 'module':
    - 'arity': Number of input parameters the gate takes.
        0 for constants, 1 for unary, 2 for binary.
    - 'module': A Python function for computing gate output.

The 'module' function should take 'arity' + 2 arguments:
    - The first 'arity' arguments are inputs to the gate (wires).
    - The next argument is the integer limit M.
    - The last argument is the memory buffer at the current timestep.

The 'module' function should return a tuple of its output and the (potentially)
modified memory buffer.
"""
from collections import namedtuple

import numpy as np

from theano.tensor.extra_ops import to_one_hot
from theano.tensor import (set_subtensor, roll, batched_dot, zeros_like, stack,
                           shape_padright)

Gate = namedtuple("Gate", "arity module")


def make_constant_gate(value):
    """Create a gate that returns a constant distribution."""
    # Arguments to to_one_hot must be Numpy arrays.
    arr = np.asarray([value])

    def module(max_int, mem):
        """Return the one-hot encoded constant."""
        return to_one_hot(arr, max_int), mem

    arity = 0
    return Gate(arity, module)


def eq_zero_fun(A, max_int, mem):
    """Given a Theano vector A, return a vector
    of the same shape where the first component is
    1 - A[0], the second component is A[0], and the
    other components are all zero.

    This corresponds to a neural gate that checks for zero."""

    # Initialize result to be zeros in the same shape as A.
    # This should be a list of row vectors of length max_int.
    # By operating on all rows at once we allow multiple samples
    # to be processed in one call to this function.
    result = zeros_like(A)
    result = set_subtensor(result[:, 1], A[:, 0])
    result = set_subtensor(result[:, 0], 1 - A[:, 0])
    return result, mem


def negate_fun(A, max_int, mem):
    """Negate a distribution over integers."""
    return roll(A[:, ::-1], 1, axis=1), mem


def add_fun(A, B, max_int, mem):
    """Returns the distribution for a sum of integers."""
    rows = [roll(B[:, ::-1], shift + 1, axis=1)
            for shift in range(max_int)]
    B_prime = stack(rows, axis=1).transpose(0, 2, 1)
    return batched_dot(A, B_prime), mem


def read_fun(ptr, max_int, mem):
    """Read from the memory tape."""
    # Reading from memory ends up being a matrix multiplication (per sample),
    # but getting it right just involves shuffling the dimensions to be right:
    #
    #                           mem:  S x M' x M
    #                           ptr:  S x M'
    #    m = mem.transpose(0, 2, 1):  S x M x M'
    #    p = shape_padright(ptr, 1):  S x M' x 1
    #             batched_dot(m, p):  S x M x 1
    #   batched_dot(m, p).flatten():  S x M
    return batched_dot(mem.transpose(0, 2, 1),
                       shape_padright(ptr, 1)).flatten(2), mem


def write_fun(ptr, val, max_int, mem):
    """Write to the memory tape, and return the written value."""
    # As with reading, tracking the dimensions makes this operation simple.
    # We want to compute an "old" contribution and a "new" contribution.
    #                            mem: S x M' x M
    #                            ptr: S x M'
    #                            val: S x M
    #     p = shape_padright(ptr, 1): S x M' x 1
    #  v = val.dimshuffle(0, 'x', 1): S x 1 x M
    #                        1 - ptr: S x M'
    # J = shape_padright(1 - ptr, 1): S x M' x 1
    #                  old = J * mem: S x M' x M (broadcasting)
    #                    new = p * v: S x M' x M
    p = shape_padright(ptr, 1)
    v = val.dimshuffle(0, 'x', 1)
    j = shape_padright(1 - ptr, 1)
    new_mem = j * mem + batched_dot(p, v)
    return val, new_mem


# Built in gates.
zero = make_constant_gate(0)
one  = make_constant_gate(1)
two  = make_constant_gate(2)
eq_zero = Gate(1, eq_zero_fun)
add = Gate(2, add_fun)
negate = Gate(1, negate_fun)
read = Gate(1, read_fun)
write = Gate(2, write_fun)
