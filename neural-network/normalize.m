% Normalize features in a dataset. Return the same dataset, normalized.
%
% Parameters:
%   - X: dataset, with each row being a data point, and columns being variables
function X = normalize(X)
    % Find standard deviations and means of columns
    stdev = std(X);
    avg = mean(X);

    % Normalize each row by expressing the values in those rows as z-scores
    [rows, cols] = size(X);
    for i = 1:rows,
        X(i, :) = (X(i, :) - avg) / stdev;
    end
end
