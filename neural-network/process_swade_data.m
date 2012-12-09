% Preprocess the data and convert it into a format that we can feed the neural network.
% This does things like feature scaling, shuffling rows, etc.
% 
% Parameters:
%   - in: swade input data
%   - out: swade output data
function [in, out] = process_swade_data(in, out)
    % Apply feature scaling
    % in = normalize(in);

    % Convert swade output data into ranges from 0 to 1
    out_range = max(out) - min(out);

    [rows, cols] = size(out);
    out_new = out - (ones(rows, 1) * min(out));
    out_new = out_new ./ (ones(rows, 1) * out_range);

    disp('To revert, multiply by:');
    disp(out_range);
    disp('and then add');
    disp(min(out));

    out = out_new;

    % Shuffle rows around
    [in, out] = shuffle_data(in, out);
end
