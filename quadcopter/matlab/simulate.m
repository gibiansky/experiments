% Perform a simulation of a quadcopter, from t = 0 through t = 10.
% As an argument, take a controller function. This function must accept
% a struct containing the physical parameters of the system and the current
% gyro readings. The controller may use the strust to store persistent state, and
% return this state as a second output value. If no controller is given,
% a simulation is run with some pre-determined inputs.
% The output of this function is a data struct with the following fields, recorded
% at each time-step during the simulation:
%
% data =
%
%         x: [3xN double]
%     theta: [3xN double]
%       vel: [3xN double]
%    angvel: [3xN double]
%         t: [1xN double]
%     input: [4xN double]
%        dt: 0.0050
function result = simulate(controller, tstart, tend, dt)
    % Physical constants.
    g = 9.81;
    m = 0.5;
    L = 0.25;
    k = 3e-6;
    b = 1e-7;
    I = diag([5e-3, 5e-3, 10e-3]);
    kd = 0.25;

    % Simulation times, in seconds.
    if nargin < 4
        tstart = 0;
        tend = 4;
        dt = 0.005;
    end
    ts = tstart:dt:tend;

    % Number of points in the simulation.
    N = numel(ts);

    % Output values, recorded as the simulation runs.
    xout = zeros(3, N);
    xdotout = zeros(3, N);
    thetaout = zeros(3, N);
    thetadotout = zeros(3, N);
    inputout = zeros(4, N);

    % Struct given to the controller. Controller may store its persistent state in it.
    controller_params = struct('dt', dt, 'I', I, 'k', k, 'L', L, 'b', b, 'm', m, 'g', g);

    % Initial system state.
    x = [0; 0; 10];
    xdot = zeros(3, 1);
    theta = zeros(3, 1);

    % If we are running without a controller, do not disturb the system.
    if nargin == 0
        thetadot = zeros(3, 1);
    else
        % With a control, give a random deviation in the angular velocity.
        % Deviation is in degrees/sec.
        deviation = 300;
        thetadot = deg2rad(2 * deviation * rand(3, 1) - deviation);
    end

    ind = 0;
    for t = ts
        ind = ind + 1;

        % Get input from built-in input or controller.
        if nargin == 0
            i = input(t);
        else
            [i, controller_params] = controller(controller_params, thetadot);
        end

        % Compute forces, torques, and accelerations.
        omega = thetadot2omega(thetadot, theta);
        a = acceleration(i, theta, xdot, m, g, k, kd);
        omegadot = angular_acceleration(i, omega, I, L, b, k);

        % Advance system state.
        omega = omega + dt * omegadot;
        thetadot = omega2thetadot(omega, theta); 
        theta = theta + dt * thetadot;
        xdot = xdot + dt * a;
        x = x + dt * xdot;

        % Store simulation state for output.
        xout(:, ind) = x;
        xdotout(:, ind) = xdot;
        thetaout(:, ind) = theta;
        thetadotout(:, ind) = thetadot;
        inputout(:, ind) = i;
    end

    % Put all simulation variables into an output struct.
    result = struct('x', xout, 'theta', thetaout, 'vel', xdotout, ...
                    'angvel', thetadotout, 't', ts, 'dt', dt, 'input', inputout);
end

% Arbitrary test input.
function in = input(t)
    in = zeros(4, 1);
    in(:) = 700;
    in(1) = in(1) + 150;
    in(3) = in(3) + 150;
    in = in .^ 2;
end

% Compute thrust given current inputs and thrust coefficient.
function T = thrust(inputs, k)
    T = [0; 0; k * sum(inputs)];
end

% Compute torques, given current inputs, length, drag coefficient, and thrust coefficient.
function tau = torques(inputs, L, b, k)
    tau = [
        L * k * (inputs(1) - inputs(3))
        L * k * (inputs(2) - inputs(4))
        b * (inputs(1) - inputs(2) + inputs(3) - inputs(4))
    ];
end

% Compute acceleration in inertial reference frame
% Parameters:
%   g: gravity acceleration
%   m: mass of quadcopter
%   k: thrust coefficient
%   kd: global drag coefficient
function a = acceleration(inputs, angles, vels, m, g, k, kd)
    gravity = [0; 0; -g];
    R = rotation(angles);
    T = R * thrust(inputs, k);
    Fd = -kd * vels;
    a = gravity + 1 / m * T + Fd;
end

% Compute angular acceleration in body frame
% Parameters:
%   I: inertia matrix
function omegad = angular_acceleration(inputs, omega, I, L, b, k)
    tau = torques(inputs, L, b, k);
    omegad = inv(I) * (tau - cross(omega, I * omega));
end

% Convert derivatives of roll, pitch, yaw to omega.
function omega = thetadot2omega(thetadot, angles)
    phi = angles(1);
    theta = angles(2);
    psi = angles(3);
    W = [
        1, 0, -sin(theta)
        0, cos(phi), cos(theta)*sin(phi)
        0, -sin(phi), cos(theta)*cos(phi)
    ];
    omega = W * thetadot;
end

% Convert omega to roll, pitch, yaw derivatives
function thetadot = omega2thetadot(omega, angles)
    phi = angles(1);
    theta = angles(2);
    psi = angles(3);
    W = [
        1, 0, -sin(theta)
        0, cos(phi), cos(theta)*sin(phi)
        0, -sin(phi), cos(theta)*cos(phi)
    ];
    thetadot = inv(W) * omega;
end
