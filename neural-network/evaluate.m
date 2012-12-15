function evaluate(X, y, theta)
    figure;
    cumulative_plot(X, y, @(X) neural_network_tester(X, theta), 5);
    title('Neural Network Evaluation');
    xlabel('Guess Number');
    ylabel('Cumulative Percentage Correct');
    axis([1 5 0 100]);

    figure;
    cumulative_plot(X, y, @guesser, 5);
    title('Random Guessing');
    xlabel('Guess Number');
    ylabel('Cumulative Percentage Correct');
    axis([1 5 0 100]);
end

function y = neural_network_tester(X, theta)
    y = predict(theta, X);
end

function y = guesser(X)
    K = 10;
    samples = size(X, 1);
    y = zeros(samples, K);
    for i = 1:samples
        y(i, :) = randperm(K);
    end
end
