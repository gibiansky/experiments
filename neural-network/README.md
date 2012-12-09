This is an implementation of a feed-forward backpropogating neural network in Matlab. It achieves over 95% recognition accuracy on MNIST digit recognition data.

To train it, use the following code:
  
    s = rng; % Store random number generator state
    params = test; % Train network on random subset (and do cross-validation)
    params.iterations = 300; % Set iterations
    rng(s);
    theta = test(params); % Train final network
    rng(s);
    test(theta); % Test final network
