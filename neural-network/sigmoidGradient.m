% Compute the sigmoid function's derivative
function [derivative] = sigmoidGradient(X)
    derivative = sigmoid(X) .* (1 - sigmoid(X));
end
