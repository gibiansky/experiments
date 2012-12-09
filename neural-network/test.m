function value = test(v1)

if nargin == 1
    if strcmp(class(v1), 'struct')
        params = v1;
        test = 0;
    else if strcmp(class(v1), 'cell')
        theta = v1;
        test = 1;
    end
end

% Load MNIST data
disp('Loading data...');
mnist = load('mnist_all.mat');
X = [
    mnist.train0; mnist.test0 
    mnist.train1; mnist.test1 
    mnist.train2; mnist.test2 
    mnist.train3; mnist.test3 
    mnist.train4; mnist.test4 
    mnist.train5; mnist.test5 
    mnist.train6; mnist.test6 
    mnist.train7; mnist.test7 
    mnist.train8; mnist.test8 
    mnist.train9; mnist.test9 
];
y = [
    0 * ones(size(mnist.train0, 1) + size(mnist.test0, 1), 1)
    1 * ones(size(mnist.train1, 1) + size(mnist.test1, 1), 1)
    2 * ones(size(mnist.train2, 1) + size(mnist.test2, 1), 1)
    3 * ones(size(mnist.train3, 1) + size(mnist.test3, 1), 1)
    4 * ones(size(mnist.train4, 1) + size(mnist.test4, 1), 1)
    5 * ones(size(mnist.train5, 1) + size(mnist.test5, 1), 1)
    6 * ones(size(mnist.train6, 1) + size(mnist.test6, 1), 1)
    7 * ones(size(mnist.train7, 1) + size(mnist.test7, 1), 1)
    8 * ones(size(mnist.train8, 1) + size(mnist.test8, 1), 1)
    9 * ones(size(mnist.train9, 1) + size(mnist.test9, 1), 1)
];

% Make sure we're using floating point values
X = double(X);
y = double(y);
    
% Compute encoding for results
disp('Encoding labels...');
K = max(y) + 1;
y = encode_labels(y, K);

% Normalize data to be zero-mean and unit variance
disp('Doing feature scaling...');
X = normalize(X);

% Shuffle data. Note that if two different calls are used
% to generate the theta values and to test them, the random
% number generator should be reset to the same state.
disp('Shuffling data...');
[X, y] = shuffle_data(X, y);

% Divide data into training, validation, and test
disp('Dividing datasets...');
m = size(X, 1);
m_validation = 10000;
m_test = 3000;
m_training = m - m_validation - m_test;

X_training = X(1:m_training, :);
X_validation = X(m_training + 1:m_training + m_validation, :);
X_test = X(end - m_validation + 1:end, :);

y_training = y(1:m_training, :);
y_validation = y(m_training + 1:m_training + m_validation, :);
y_test = y(end - m_validation + 1:end, :);

% Free memory
X = [];
y = [];

if nargin == 1
    if test
        X = X_test;
        y = y_test;
        evaluate(X, y, theta);
    else
        X = [X_training; X_validation];
        y = [y_training; y_validation];

        lambda = params.lambda;
        count = params.neuron_count;
        layers = params.layers;
        iterations = params.iterations;

        theta = neural_network(X, y, layers, count, K, lambda, iterations);
        value = theta;
    end
else
    disp('Grid-searching over hyperparameters...');
    disp('Test Values:');
    lambda_values = [0.5 0.7 1 1.3 1.5 2 2.5]
    layer_values = [1]
    count_values = [20 25 30 35 40 50]
    [lambdas layers counts] = meshgrid(lambda_values, layer_values, count_values);
    disp(sprintf('Configurations: %d', numel(lambdas)));

    % Try different values for lambda
    min_cost = 1e10;
    min_layer = 0;
    min_lambda = 0;
    min_count = 0;
    for i = 1:numel(lambdas)
        disp(sprintf('Trying configuration %d', i));
        lambda = lambdas(i);
        layer = layers(i);
        count = counts(i);
        theta = neural_network(X_training, y_training, layer, count, K, lambda, 30);
        [pred, cost] = predict(theta, X_validation, lambda, y_validation);

        if cost < min_cost
            min_cost = cost;
            min_layer = layer;
            min_count = count;
            min_lambda = lambda;
        end
    end
    value = struct('lambda', min_lambda, 'neuron_count', min_count, ...
        'layers', min_layer, 'iterations', 100);
end

end
