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
% For linear regression testing, use 0.0005
% For neural networks on swade data, use 0.02
% For others, experiment with different values to determine appropriate alpha
alpha = 0.5;

% Set parameters to intial values
theta = initial_theta;

% Iterate the algorithm
for iteration = 1:max_iterations,
    % Find cost and gradient
    [cost, gradient] = cost_function(theta);

    % Move towards minimum (direction opposite of gradient)
    theta = theta - alpha * gradient;

    % Record cost
    costs(iteration) = cost;

    disp(sprintf('Iteration %d...', iteration));
end

% To use fminunc, remove this return
return

costs = [];

% Create function handle which records cost with every iteration
function [j grad] = record_cost_with_function(x)
    [j grad] = cost_function(x);
    costs = [costs j];
end

options = optimset('GradObj', 'on', 'MaxIter', max_iterations);
[theta, final_cost] = fminunc(@record_cost_with_function, initial_theta, options)

return 

end
