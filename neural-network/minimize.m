% Iteratively find a local minimum for a function. Return the final parameters at minimum 
% and the value of the function after each iteration of the minimization algorithm.
%
% Parameters:
%   - cost_function: function which takes a parameter vector and returns [value, vector_gradient]
%   - initial_theta: starting parameters to function (starting location)
%   - max_iterations: maximum number of allowed iterations
function [theta, costs] = minimize(cost_function, initial_theta, max_iterations)

% Store values after each iteration
costs = zeros(1, max_iterations);

% Run gradient descent for the given number of iterations

% Tune learning rate alpha to change how fast algorithm learns
alpha = 2.5;

% Set parameters to intial values
theta = initial_theta;
gradient = zeros(size(theta));

% Iterate the algorithm
for iteration = 1:max_iterations,
    if iteration == 1
        old_cost = 1e9;
    else
        old_cost = costs(iteration - 1);
    end

    cost = 1e10;
    while cost > old_cost
        % Move towards minimum (direction opposite of gradient)
        old_theta = theta;
        theta = theta - alpha * gradient;

        % Find cost and gradient
        [cost, gradient] = cost_function(theta);

        % Record cost
        costs(iteration) = cost;

        if cost > old_cost
            disp(sprintf('Scaling alpha from %.2f to %.2f', alpha, 0.9 * alpha));
            alpha = alpha * 0.6;
            theta = old_theta;
        end
    end

    disp(sprintf('Iteration %d... (cost %.1f)', iteration, cost));
end
end
