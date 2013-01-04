import os
import logging
import numpy
import random
import sys

numpy.random.seed(100)
random.seed(100)

from neuralnetworks import *
logging.basicConfig(format='%(levelname)s:\t%(message)s', level=logging.DEBUG)

dogs = ["Hound", "Poodle", "Boxer", "Golden Retriever", "Border Collie"]

pairs = []
for i in xrange(len(dogs)):
    for j in xrange(len(dogs)):
        if i < j:
            pairs.append((dogs[i], dogs[j]))

source = DirectoryImageSource("imgs", subdirectories=dogs, cache_dir="pair-data", balance_classes=True, test_set_size=1000, batch=1000)

pair = pairs[int(sys.argv[1])]

directory = "pair-data/%s/%s" % pair
try:
    os.makedirs(directory)
except OSError:
    print 'directory exists', directory

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
network.create(L2=1e-4, learning_rate=1.0)

directory = "pair-output/%s/%s" % pair
try:
    os.makedirs(directory)
except OSError:
    print 'directory exists', directory

size, testdata, labels, enclabels = source.test_set()
testout = network.output(testdata)
numpy.save(directory + "/test.out", testout)
numpy.save(directory + "/test-labels.out", numpy.asarray(labels))
for i in xrange(source.num_batches):
    data, labels, enclabels = source.batch(i)
    out = network.output(data)
    numpy.save(directory + "/batch-%s.out" % i, out)
    numpy.save(directory + "/labels-%s.out" % i, numpy.asarray(labels))

