% Normalize features in a dataset. 
% The data set is set to be zero-mean and unit variance. In the process,
% all variables which are zero-variance are removed.
%
% Parameters:
%   - X: dataset, with each row being a data point, and columns being variables
function X = normalize(X)
keyboard
    % Remove zero-variance elements. They add no information.
    X(:, find(range(X) == 0)) = [];

    % Find standard deviations and means of columns
    stdev = std(X);
    avg = mean(X);

    % Normalize each row by expressing the values in those rows as z-scores
    rows = size(X, 1);
    X = (X - repmat(avg, rows, 1)) ./ repmat(stdev, rows, 1);
end
