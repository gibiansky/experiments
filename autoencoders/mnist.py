#!/usr/bin/env python
import os
import logging
import scipy.io as sio
import numpy
from theano.tensor.nnet import softmax

from neuralnetworks import *

# Use constant seed to always choose the same test set on source.init
numpy.random.seed(100)

class MNISTImageSource(ImageSource):
    def __init__(self, mat_filename, batch_size, test_size):
        mat = sio.loadmat(mat_filename)

        classes = []
        for cls in xrange(10):
            train = mat['train%d' % cls]
            test = mat['test%d' % cls]
            classes.append(numpy.concatenate((train, test)))

        data = classes.pop(0)
        labels = [0] * data.shape[0]
        for ind, cls in zip(xrange(len(classes)), classes):
            data = numpy.concatenate((data, cls))
            labels.extend([ind + 1] * len(cls))

        num_imgs = data.shape[0]
        self.image_data = data.reshape((num_imgs, 1, 28, 28))
        self.image_labels = numpy.asarray(labels)

        self.image_shape = (1, 28, 28)
        self.batch_size = batch_size
        self.num_classes = 10
        self.num_batches = (num_imgs - test_size) / batch_size

        rand_indices = numpy.random.permutation(num_imgs)
        self.test_set_indices = rand_indices[0:test_size]
        self.indices = rand_indices[test_size:]


    def batch(self, batchnum):
        batch_indices = self.indices[batchnum * self.batch_size : (batchnum + 1) * self.batch_size]

        data = self.image_data[batch_indices, :, :, :]
        labels = self.image_labels[batch_indices]
        encoded = self.encode_labels(labels, self.num_classes)

        return data, labels, encoded

    def test_set(self):
        batch_indices = self.test_set_indices.tolist()
        batch_indices = batch_indices * (self.batch_size / len(batch_indices)) + batch_indices[0:self.batch_size % len(batch_indices)]

        data = self.image_data[batch_indices, :, :, :]
        labels = self.image_labels[batch_indices]
        encoded = self.encode_labels(labels, self.num_classes)

        return self.test_set_indices.shape[0], data, labels, encoded

class AutoencoderImageSource(ImageSource):
    def __init__(self, previous_source, previous_autoencoder):
        self.autoencoder = previous_autoencoder 
        self.source = previous_source

        self.image_shape = self.autoencoder.layers[-2].shape
        self.batch_size = self.source.batch_size
        self.num_batches = self.source.num_batches

    def batch(self, batchnum):
        batch = self.source.batch(batchnum)
        outputs = self.autoencoder.layer_outputs(batch[0])
        latent = array(outputs[-2], dtype=float32)
        return latent, latent, latent

    def test_set(self):
        batch = self.source.test_set()
        outputs = self.autoencoder.layer_outputs(batch[1])
        latent = array(outputs[-2], dtype=float32)
        return latent.shape[0], latent, latent, latent

logging.basicConfig(format='%(levelname)s:\t%(message)s', level=logging.DEBUG)
source = MNISTImageSource("mnist_all.mat", batch_size=5000, test_size=500)
source.num_batches = 10

# Create the autoencoder first layer
network = NeuralNetworkAutoencoder(denoising=True)

first = InputLayer(source)
network.layer(first)

normalizer = NormalizationLayer()
network.layer(normalizer)

fcn = FullyConnectedLayer(50, activation='tanh')
network.layer(fcn)

pixel_shape = source.image_shape
first_pixel_shape = pixel_shape
output = FullyConnectedLayer(numpy.prod(pixel_shape), shape=pixel_shape, activation=lambda x: x)
output.learning_rate = 0.5
network.layer(output)

network.create(learning_rate=0.03)

# Create the second autoencoder
wrap_source = AutoencoderImageSource(source, network)
second = NeuralNetworkAutoencoder()
second.layer(InputLayer(wrap_source))
second.layer(FullyConnectedLayer(20, activation='tanh'))
pixel_shape = wrap_source.image_shape
output = FullyConnectedLayer(numpy.prod(pixel_shape), shape=pixel_shape, activation=lambda x: x)
second.layer(output)
second.create(learning_rate=0.3)

# Create the joint network
wrap_source2 = AutoencoderImageSource(source, network)
third = NeuralNetworkAutoencoder()
third.layer(InputLayer(wrap_source2))
a = FullyConnectedLayer(20, activation='tanh')
b = FullyConnectedLayer(numpy.prod(pixel_shape), shape=pixel_shape, activation=lambda x: x)
c = FullyConnectedLayer(numpy.prod(first_pixel_shape), shape=first_pixel_shape, activation=lambda x: x)
third.layer(a)
third.layer(b)
third.layer(c)
third.create(learning_rate=0.3)

a.copy_weights(second.layers[1])
b.copy_weights(second.layers[-1])
c.copy_weights(network.layers[-1])

numpy.random.seed()

# Train the neural network
# second.train(test_interval=10)
