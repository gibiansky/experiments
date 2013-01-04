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
network.layer(FullyConnectedLayer(30, dropout=True))
network.layer(SoftmaxLayer(source.num_classes))
network.create(learning_rate=0.005, L2=1e-7)

# Test the neural network
print 'Testing:'
for i in xrange(source.num_batches):
    network.test(source.batch(i))

print 'Test Set'
network.test(source.test_set()[1:])

# Get top two guesses
test_size, test_data, test_labels, test_encoded = source.test_set()
outputs = network.output(test_data)
first_guess = numpy.argmax(outputs, axis = 1)
for i in xrange(outputs.shape[0]):
    outputs[i, first_guess[i]] = 0
second_guess = numpy.argmax(outputs, axis = 1)

first_percentage = 100 * sum(numpy.asarray(test_labels[0:test_size]) == first_guess[0:test_size]) / float(test_size)
second_percentage = 100 * sum(numpy.asarray(test_labels[0:test_size]) == second_guess[0:test_size]) / float(test_size)
first_samples = zip(first_guess[0:10], test_labels[0:10])
second_samples = zip(second_guess[0:10], test_labels[0:10])
print 'First Guess: %.1f%%' % first_percentage
print 'Example:', first_samples
print 'Second Guess: %.1f%%' % second_percentage
print 'Example:', second_samples
print 'First or Second Guess: %.1f%%' % (second_percentage + first_percentage)
