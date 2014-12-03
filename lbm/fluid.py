import numpy as np
import matplotlib.pyplot as plt
import matplotlib.cm as cm
import matplotlib.animation as animation

import cuda

# Parameters.
HEIGHT, WIDTH = 3, 3
RESOLUTION = 30

# Initialize figure.
fig = plt.figure()
axis = fig.add_subplot(1, 1, 1)
axis.get_yaxis().set_visible(False)
axis.get_xaxis().set_visible(False)

# Initialize matrices.
density = np.ones((RESOLUTION * WIDTH, RESOLUTION * HEIGHT))
velocity = np.zeros((RESOLUTION * WIDTH, RESOLUTION * HEIGHT, 2))
directions = np.zeros((RESOLUTION * WIDTH, RESOLUTION * HEIGHT, 9))
directions_next = np.zeros_like(directions)
equilibrium = np.zeros_like(directions)

# Grid dimensions.
w = RESOLUTION * WIDTH
h = RESOLUTION * HEIGHT


def initialize():
    # Things start out immobile.
    directions[:, :, 4] = 10

    # Compute dependent quantities.
    cuda.compute_density(density, directions, w, h)
    cuda.compute_velocity(velocity, density, directions, w, h)
    cuda.equilibriate(equilibrium, density, velocity, w, h)


def boundary_conditions(d, i):
    if i < 30:
        # Things move somewhere.
        d[50:70, 50:70, 3] = 5
        d[10:30, 40:50, 1] = 5


def update(i):
    boundary_conditions(directions, i)
    cuda.stream(directions_next, directions, w, h)
    cuda.compute_density(density, directions_next, w, h)
    cuda.compute_velocity(velocity, density, directions_next, w, h)
    cuda.equilibriate(equilibrium, density, velocity, w, h)
    cuda.compute_velocity(velocity, density, directions_next, w, h)

    cuda.update_distribution(directions, equilibrium, directions_next, w, h)


def draw_fluid(vals, xlow, xhigh, ylow, yhigh):
    axis.clear()
    axis.imshow(vals, extent=(xlow, xhigh, ylow, yhigh),
                interpolation='bicubic', cmap=cm.Blues,
                vmin=0, vmax=20)


def frame(i):
    print 'Frame', i + 1
    update(i)
    mag = (velocity[:, :, 0] * velocity[:, :, 0] +
           velocity[:, :, 1] * velocity[:, :, 1])
    draw_fluid(density, 0, WIDTH, 0, HEIGHT)


initialize()
anim = animation.FuncAnimation(fig, frame, interval=30, frames=550)
plt.show()
