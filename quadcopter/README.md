This is a simulation of a quadcopter. The physics behind the simulation as well as the control theory behind the quadcopter stabilization is detailed in the report PDF. 

Directions for running things
---
I was not terribly concerned with speed when implementing this, so the implementation may not be optimal or even fast.

The two main functions are `simulate` and `visualize` in the respective *.m files. `simulate` simulates the system and outputs some data, which 'visualize' can then display. In order to use `simulate`, you must first create a controller. For instance, to use a PID controller, you can use

```matlab
pParam = 0.5; iParam = 0.01; dParam = 0.1;
control = controller('pid', pParam, iParam, dParam);
```

Then, you can create the simulated data by specifying the start and end times and the time step

```matlab
tstart = 0; tend = 3; dt = 0.01;
data = simulate(control, tstart, tend, dt);
```

Finally, you can visualize what happened using `visualize`:

```matlab
visualize(data);
```

`visualize` waits for you to press 'enter' before showing the animations, so you can run the entire thing with this:

```matlab
visualize(simulate(controller('pid', 0.5, 0.01, 0.1), 0, 5, 0.01)) % Don't forget to press Enter/Return
```

You can also use `matlab` to find optimal PID parameters as described in my writing. The tune function will occasionally give you numerical errors (quite often actually) in which case you can simply re-run it.
