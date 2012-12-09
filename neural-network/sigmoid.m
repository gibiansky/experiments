% Compute the sigmoid function
function [sigmoid] = sigmoid(X)
    sigmoid = 1 ./ (1 + exp(-X));
end
