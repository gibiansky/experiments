function h = cumulative_plot(X, y, predictor, guesses)
    % Do prediction.
    samples = size(X, 1);
    preds = predictor(X);

    % For each next guess, compute the number correct chosen by this guess.
    cumulative = zeros(1, guesses);
    for i = 1:guesses
        % Convert the predictions into an output binary vector
        z = preds == repmat(max(preds, [], 2), 1, size(y, 2));

        % Compute what proportion of these output binary vectors are correct over all samples
        c = 100 * sum(all(z == y, 2)) / samples;

        % Accumulate percentages
        if i == 1
            cumulative(i) = c;
        else
            cumulative(i) = cumulative(i - 1) + c;
        end

        % Remove the maximal elements from consideration, so that for the next guess
        % we only consider the next worst choices.
        preds(z) = 0;
    end
    cumulative

    h = plot(1:guesses, cumulative);
end
