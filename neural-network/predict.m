% Given a set of learned parameters and a matrix of feature vectors, output the predictions and cost
% 
% Parameters:
%   - weights: neural network parameters, as given by the learning function
%   - X: row vectors of variable values
%   - (optional) lambda: regularization parameter, used for computing cost 
%   - (optional) y: expected outputs for values
function [predictions, cost] = predict(weights, X, varargin)
    % Compute forward propogation, starting values being the inputs
    layers = length(weights) - 1;
    layer_values{1} = X;
    for i = 1:layers + 1,
        % Add in bias column
        [rows, cols] = size(layer_values{i});
        biased_values = [ones(rows, 1) layer_values{i}]';
        
        % Compute next layer and store values
        sums{i} = (weights{i} * biased_values)';
        layer_values{i + 1} = sigmoid(sums{i});
    end

    % Collect output at output layer
    output = layer_values{end};

    % Compute cost with regularization if we need to
    if nargout > 1,
        lambda = varargin{1};
        y = varargin{2};
        [m, n] = size(X);

        % Compute cost without regularization
        cost = -1 / m * sum(sum(y .* log(output) + (1 - y) .* log(1 - output)));

        % Compute regularization cost and add it up
        regularization_cost = 0;
        for weight_matrix = weights,
            % Extract weights for all but the bias parameter, sum and square them
            regularization_cost = regularization_cost + lambda / (2 * m) * sum(sum(weight_matrix{1}(:, 2:end) .^ 2));
        end
        cost = cost + regularization_cost;
    end

    predictions = output;

    % Convert output into classes (indices)
%    [rows, cols] = size(output);
%    repeated_maxes = max(output')' * ones(1, cols);
%    is_max = (output == repeated_maxes);
%    predictions = mod(find(is_max') - 1, cols);
end
