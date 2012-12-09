% Compute neural network cost and gradient. This function can be passed to the minimizer to learn neural network parameters.
%
% Parameters:
%   - theta: current neural network weights
%   - X: dataset, with each row being a separate data point, each column being a variable. Do not include a bias.
%   - y: output values for each data point, with each row being a separate data point, each column being an output unit.
%   - num_layers: number of hidden layers (layers not including input and output) to use
%   - num_units: number of units per hidden layer
%   - num_outputs: how many output units there are (should match number of cols in y)
%   - lambda: regularization parameters, changes how harshly large weights are penalized
function [cost, gradient] = neural_network_cost(theta, X, y, num_layers, num_units, num_outputs, lambda)
    % m is number of data points
    % num_features is number of input variables
    [m, num_features] = size(X);

    % unroll the parameters into a cell array
    % each element of the cell array is a matrix which maps from the ith layer to the i+1th layer of the network
    weights = unroll(theta, num_features, num_layers, num_units, num_outputs);

    % Pre-allocate cell arrays we use for computation
    biased_values{num_layers+1} = [];
    layer_values{num_layers+1} = [];
    gradients{num_layers+1} = [];

    % Compute forward propogation, starting values being the inputs
    layer_values{1} = X;

    for i = 1:num_layers + 1,
        % Add in bias column
        [rows, cols] = size(layer_values{i});
        biased_values{i} = [ones(rows, 1) layer_values{i}]';
        
        % Compute next layer and store values
        sums{i} = (weights{i} * biased_values{i})';
        layer_values{i + 1} = sigmoid(sums{i});

    end

    % Collect output at output layer
    output = layer_values{end};

    % Compute cost without regularization
    % Add small amount to logarithm to avoid taking the logarithm of zero
    cost = -1 / m * sum(sum(y .* log(output + 1e-50) + (1 - y) .* log(1 - output + 1e-50)));

    % Compute regularization cost and add it up
    regularization_cost = 0;
    for weight_matrix = weights,
        % Extract weights for all but the bias parameter, sum and square them
        regularization_cost = regularization_cost + lambda / (2 * m) * sum(sum(weight_matrix{1}(:, 2:end) .^ 2));
    end
    cost = cost + regularization_cost;
    
    % Compute gradient via backpropogation
    delta{num_layers + 1} = output - y;
    for i = num_layers:-1:1,
        % For back propogation, use weights without the bias parameter
        weights_no_bias = weights{i + 1}(:, 2:end);
        
        % Compute previous weight deltas
        delta{i} = delta{i + 1} * weights_no_bias  .* sigmoidGradient(sums{i});
    end

    % Compute gradients
    for i = 1:num_layers + 1,
        % Compute unregularized gradients
        gradients{i} = 1/ m * (biased_values{i} * delta{i})';

        % Add in gradient regularization, but don't regularize bias weight
        regularization_gradient = lambda / m * weights {i};
        regularization_gradient(:, 1) = 0;

        % Add regularization to unregularized gradient
        gradients{i} = gradients{i} + regularization_gradient;
    end

    % Roll gradient into one vector, so that the minimizer can just pretend the parameters are a single vector
    gradient = roll(gradients);
end
