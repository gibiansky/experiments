import os
import logging
import scipy.io as sio
import numpy

from neuralnetworks import *

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

logging.basicConfig(format='%(levelname)s:\t%(message)s', level=logging.DEBUG)
source = MNISTImageSource("mnist_all.mat", batch_size=5000, test_size=500)
source.num_batches = 10

# Create the neural network
network = NeuralNetwork()
network.layer(InputLayer(source))
network.layer(NormalizationLayer())
conv1 = ConvolutionalLayer((5, 5), 4)
network.layer(conv1)
conv2 = ConvolutionalLayer((5, 5), 4)
network.layer(conv2)
fcn = FullyConnectedLayer(25, dropout=True)
network.layer(fcn)
network.layer(SoftmaxLayer(source.num_classes))
network.create(L1=1e-8, L2=1e-5, learning_rate=0.01)

numpy.random.seed()

if True:
    for i in xrange(10):
        network.test(source.batch(i))
    outs = network.layer_outputs(source.test_set()[1])
    visualize_convolutions(outs[2])
    visualize_convolutions(outs[3])
    conv1.display()
    conv2.display()
    fcn.display()


# Train the neural network
network.train(test_interval=10)
