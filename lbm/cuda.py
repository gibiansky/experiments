import pycuda.autoinit  # noqa
import pycuda.driver as drv
from pycuda.compiler import SourceModule

with open("kernels.cu", "r") as f:
    mod = SourceModule(f.read())

stream_cuda = mod.get_function("stream")
density_cuda = mod.get_function("density")
velocity_cuda = mod.get_function("velocity")
equilibrium_cuda = mod.get_function("equilibrium")
update_cuda = mod.get_function("update")


def stream(out, inp, width, height):
    inp = drv.In(inp)
    out = drv.Out(out)
    stream_cuda(out, inp, block=(1, 1, 1), grid=(width, height))


def compute_density(out, inp, width, height):
    inp = drv.In(inp)
    out = drv.Out(out)
    density_cuda(out, inp, block=(1, 1, 1), grid=(width, height))


def compute_velocity(out, density, directions, width, height):
    density = drv.In(density)
    directions = drv.In(directions)
    out = drv.Out(out)
    velocity_cuda(out, density, directions, block=(1, 1, 1), grid=(width,
                                                                   height))


def equilibriate(equilibrium, density, velocity, width, height):
    density = drv.In(density)
    velocity = drv.In(velocity)
    equilibrium = drv.Out(equilibrium)
    equilibrium_cuda(equilibrium, density, velocity, block=(1, 1, 1),
                     grid=(width, height))


def update_distribution(out, equilibrium, directions, width, height):
    directions = drv.In(directions)
    equilibrium = drv.In(equilibrium)
    out = drv.Out(out)
    update_cuda(out, equilibrium, directions, block=(1, 1, 1),
                grid=(width, height))
