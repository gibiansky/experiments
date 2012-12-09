% Given a labeled dataset, train a multi-class neural network classifier.
% Returns the final cost and list of weights.
%
% Parameters:
%   - X is a dataset, with each example as one row and each feature as one column
%   - y is the dataset results, with each row having one column with the result. Each
%       value is an integer from 0 to K-1, indicating which class this example belongs to.
%   - layers is the number of hidden layers in the network
%   - num_units is the number of units in each hidden layer
%   - lambda is the regularization parameter (how much large parameters should be penalized)
%   - iterations is number of iterations to run minimization algorithm for
function [theta, cost, costs] = neural_network(X, y, layers, num_units, K, lambda, iterations)

% Compute number of examples (m), features (n)
[m, n] = size(X);

% Compute number of parameters in the input->hidden mapping
num_parameters_input = (num_units * (n + 1));

% Compute number of parameters in the hidden->output mapping
num_parameters_output = (K * (num_units + 1));

% Compute number of parameters in the hidden->hidden mapping
num_parameters_hidden = (num_units * (num_units + 1));

% Compute total number of parameters
num_parameters =  num_parameters_input + (layers - 1) * num_parameters_hidden + num_parameters_output;

% Randomly initialize weights into a row vector
epsilon = 0.50;
init_theta = rand(1, num_parameters) * epsilon - epsilon / 2;

% Minimize neural network cost function
[theta, costs] = minimize(@(theta) neural_network_cost(theta, X, y, layers, num_units, K, lambda), init_theta, iterations);

% Recompute cost after last iteration to return it
cost = neural_network_cost(theta, X, y, layers, num_units, K, lambda);

% For use in prediction, unroll theta
theta = unroll(theta, n, layers, num_units, K);

end
