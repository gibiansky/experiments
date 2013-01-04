import os
import sys
import logging
import numpy
import random

numpy.random.seed(100)
random.seed(100)

from neuralnetworks import *

dogs = ["Hound", "Poodle", "Boxer", "Golden Retriever", "Border Collie"]

pairs = []
for i in xrange(len(dogs)):
    for j in xrange(len(dogs)):
        if i < j:
            pairs.append((dogs[i], dogs[j]))

random.seed()

for i in [int(x) for x in sys.argv[1:]]:
    pair = pairs[i]
    directory = "pair-data/%s/%s" % pair
    try:
        os.makedirs(directory + "/cache")
        os.makedirs(directory + "/weights")
    except OSError:
        pass

    logging.basicConfig(format='%(levelname)s:\t%(message)s', level=logging.CRITICAL)

    source = DirectoryImageSource("imgs", subdirectories=pair, cache_dir=directory +"/cache", balance_classes=True, test_set_size=1000, batch=1000)

    # Create the neural network
    network = NeuralNetwork(cache_dir=directory + "/weights")
    network.layer(InputLayer(source))
    network.layer(NormalizationLayer())
    network.layer(ConvolutionalLayer((5, 5), 32))
    network.layer(MaxPoolLayer((2, 2)))
    network.layer(ConvolutionalLayer((5, 5), 16))
    network.layer(MaxPoolLayer((2, 2)))
    network.layer(ConvolutionalLayer((4, 4), 16))
    network.layer(MaxPoolLayer((2, 2)))
    network.layer(FullyConnectedLayer(100, dropout=True))
    network.layer(SoftmaxLayer(source.num_classes))
    network.create(L2=1e-4, learning_rate=0.1)

    # Test the neural network
    print 'Pair %d: %s \t %.2f' % (i, str(pair), network.test(source.test_set()[1:]))
