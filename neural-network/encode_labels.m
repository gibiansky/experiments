% Convert the desired results from the class index to the vector encoding
% The encoding we are using chooses a 1 for the correct class, and a 0 otherwise
function encoded = encode_labels(y, K)
    encoded = zeros(numel(y), K);

    % For each class, set the bit as necessary
    for j = 1:K,
        encoded(:, j) = (y == j - 1);
    end
end
