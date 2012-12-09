% Unroll the parameters into a cell array of weight matrices
% The cell array contains one matrix per layer transition
function unrolled = unroll(theta, num_features, num_layers, num_units, num_outputs)

% Compute total number of parameters (weights)
% We have parameters:
%   - from input layer to hidden layer 
%   - from hidden layer to hidden layer
%   - from hidden layer to output layer
% Note that we account for the bias feature we will be inserting.
num_parameters_input = (num_units * (num_features + 1));
num_parameters_output = (num_outputs * (num_units + 1));
num_parameters_hidden = (num_units * (num_units + 1));
num_parameters =  num_parameters_input + (num_layers - 1) * num_parameters_hidden + num_parameters_output;

% Unroll first matrix from inputs to hidden layer
first = reshape(theta(1:num_parameters_input), num_units, num_features + 1);
unrolled = {first};

% Unroll matrices between hidden layers
for hidden_layer = 1:num_layers-1,
    start_index = num_parameters_input + (hidden_layer - 1) * num_parameters_hidden + 1;
    end_index = start_index + num_parameters_hidden - 1;
    hidden = reshape(theta(start_index:end_index), num_units, num_units + 1);
    unrolled{hidden_layer + 1} = hidden;
end

% Unroll last matrix (from hidden layer to output layer)
last = reshape(theta(end - num_parameters_output + 1:end), num_outputs, num_units + 1);
unrolled{end + 1} = last;

end
