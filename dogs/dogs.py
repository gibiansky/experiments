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
        print 'subdirectories exist', directory

    logging.basicConfig(format=str(pair) + '\t%(levelname)s:\t%(message)s', level=logging.DEBUG)

    source = DirectoryImageSource("imgs", subdirectories=pair, cache_dir=directory +"/cache", balance_classes=True, test_set_size=1000, batch=1000)

    # Create the neural network
    network = NeuralNetwork(cache_dir=directory + "/weights")
    network.layer(InputLayer(source))
    network.layer(NormalizationLayer())

    conv1 = ConvolutionalLayer((5, 5), 32)
    network.layer(conv1)
    network.layer(MaxPoolLayer((2, 2)))

    conv2 = ConvolutionalLayer((5, 5), 16)
    network.layer(conv2)
    network.layer(MaxPoolLayer((2, 2)))

    conv3 = ConvolutionalLayer((4, 4), 16)
    network.layer(conv3)
    network.layer(MaxPoolLayer((2, 2)))

    fcn = FullyConnectedLayer(100, dropout=True)
    network.layer(fcn)

    network.layer(SoftmaxLayer(source.num_classes))
    network.create(learning_rate=0.03, L2=1e-4)

    if True:
        outs = network.layer_outputs(source.test_set()[1])
        visualize_convolutions(outs[2])
        visualize_convolutions(outs[3])
        visualize_convolutions(outs[4])
        conv1.display()
        conv2.display()
        conv3.display()
        fcn.display()
    else:
        # Train the neural network
        print 'Training'
        train_batches = 100
        epochs = train_batches / source.num_batches
        network.train(test_interval=source.num_batches, epochs=epochs)
