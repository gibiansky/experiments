% Compute the softmax function given a vector of inputs.
function out = softmax(in)
    e = exp(in);
    out = e ./ repmat(sum(e, 2), 1, size(e, 2));
end
