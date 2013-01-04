import os
import logging
import theano

from neuralnetworks import *

dogs = ["Hound", "Poodle", "Boxer", "Golden Retriever", "Border Collie"]
logging.basicConfig(format='%(levelname)s:\t%(message)s', level=logging.DEBUG)
source = DirectoryImageSource("imgs", subdirectories=dogs, cache_dir="cache", balance_classes=True, test_set_size=1000, batch=1000)

# Create the neural network
network = NeuralNetwork()
network.layer(InputLayer(source))
network.layer(NormalizationLayer())
network.layer(ConvolutionalLayer((5, 5), 16, activation=None))
network.layer(MaxPoolLayer((2, 2), activation=theano.tensor.tanh))
network.layer(ConvolutionalLayer((5, 5), 32, activation=None))
network.layer(MaxPoolLayer((2, 2), activation=theano.tensor.tanh))
network.layer(ConvolutionalLayer((4, 4), 64, activation=None))
network.layer(MaxPoolLayer((2, 2), activation=theano.tensor.tanh))
network.layer(FullyConnectedLayer(100, dropout=True))
network.layer(SoftmaxLayer(source.num_classes))
network.create(learning_rate=0.1)

# Train the neural network
network.train(test_interval=15, save_interval=10)
