
import os
import logging
import numpy
import random

from neuralnetworks import *

numpy.random.seed(100)
random.seed(100)

class PairSource(ImageSource):
    def __init__(self, dogs, pairs, test_set_size, batch):
        self.num_classes = len(dogs)
        self.num_batches = 25
        self.pairs = pairs
        self.test_set_size = test_set_size
        self.batch_size = batch
        self.image_shape = (len(pairs) * 2,)

    def output_dir(self, pair):
        return "pair-output/%s/%s" % pair

    def batch(self, batchnum):
        outputs = []
        for pair in self.pairs:
            filename = os.path.join(self.output_dir(pair), "batch-%d.out.npy" % batchnum)
            outputs.append(numpy.load(filename))
        labelsname = os.path.join(self.output_dir(pair), "labels-%d.out.npy" % batchnum)
        labels = numpy.load(labelsname)
        out = numpy.concatenate(outputs, axis=1)
        encoded_labels = self.encode_labels(labels, self.num_classes)
        return out, labels, encoded_labels
    
    def test_set(self):
        outputs = []
        for pair in self.pairs:
            filename = os.path.join(self.output_dir(pair), "test.out.npy")
            outputs.append(numpy.load(filename))
        filename = os.path.join(self.output_dir(pair), "test-labels.out.npy")
        labels = numpy.load(filename)

        out = numpy.concatenate(outputs, axis=1)
        encoded_labels = self.encode_labels(labels, self.num_classes)
        return self.test_set_size, out, labels, encoded_labels


dogs = ["Hound", "Poodle", "Boxer", "Golden Retriever", "Border Collie"]

pairs = []
for i in xrange(len(dogs)):
    for j in xrange(len(dogs)):
        if i < j:
            pairs.append((dogs[i], dogs[j]))

source = PairSource(dogs, pairs, test_set_size=1000, batch=1000)
    
logging.basicConfig(format='%(levelname)s:\t%(message)s', level=logging.DEBUG)

random.seed()
# Create the neural network
network = NeuralNetwork(cache_dir="pair-weights")
network.layer(InputLayer(source, image=False))
network.layer(FullyConnectedLayer(45, dropout=False))
network.layer(SoftmaxLayer(source.num_classes))
network.create(learning_rate=0.01, L2=1e-4)

# Train the neural network
network.train(epochs=50, test_interval=1000, save_interval=1000)
for i in xrange(source.num_batches):
    network.test(source.batch(i))
network.test(source.test_set()[1:])
