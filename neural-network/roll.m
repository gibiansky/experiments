% Roll the parameters from a cell array into a single row vector for storage convenience
function rolled = roll(unrolled)
    rolled = [];
    for matrix = unrolled,
        rolled = [rolled reshape(matrix{1}, 1, numel(matrix{1}))];
    end
end
