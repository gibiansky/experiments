#!/usr/bin/python

from numpy import *
from theano import *
#from theano.tensor.shared_randomstreams import RandomStreams
from theano.sandbox.rng_mrg import MRG_RandomStreams as RandomStreams
from theano.tensor.nnet.conv import conv2d
from theano.tensor.nnet import binary_crossentropy, softmax
from theano.tensor.signal.downsample import max_pool_2d
from time import sleep
import cPickle
import thread
import os
import Image
import random
import logging
import matplotlib.pyplot as plt

### Internal convenience functions and classes ###

def create_name(nametype, default = None, context = {}):
    """
    Return appropriate names for layers and networks.
    If provided with a name, simply use it; otherwise, generate
    unique numbered names in the given naming context. A name context
    is a context in which names can be repeated - for instance, a layer named
    'conv1' may appear in two different contexts, but not in the same context.

    Example Usage:
        >>> create_name('conv', 'conv-custom')
        'conv-custom'
        >>> first_context = {}
        >>> create_name('conv', context=first_context)
        'conv-1'
        >>> create_name('conv', context=first_context)
        'conv-2'
        >>> second_context = {}
        >>> create_name('conv', context=second_context)
        'conv-1'
        >>> create_name('Neural-Network')
        'Neural-Network-1'

    """
    # If we're given a name to use, return it.
    if not default is None:
        return default
    
    # If this is a new type of name, initialize the counter for it.
    if not nametype in context:
        context[nametype] = 1
    
    # Generate the name
    name = "%s-%d" % (nametype, context[nametype])
    context[nametype] += 1
    return name

def show_images(rows, columns, imgs):
    fig, axes = plt.subplots(rows, columns)
    axes = axes.reshape((rows, columns))

    for row in xrange(rows):
        for column in xrange(columns):
            plot = axes[row, column].imshow(imgs[row][column])
            axes[row, column].xaxis.set_ticklabels([None])
            axes[row, column].yaxis.set_ticklabels([None])
            axes[row, column].xaxis.set_ticks([None])
            axes[row, column].yaxis.set_ticks([None])
            plot.set_cmap("gray")
    plt.show()

def visualize_convolutions(layer_outputs, count=5):
    indices = numpy.random.permutation(layer_outputs.shape[0])[0:count]
    channels = layer_outputs.shape[1]

    images = [[0] * channels for i in xrange(count)]
    for row in xrange(count):
        for column in xrange(channels):
            images[row][column] = layer_outputs[indices[row], column, :, :]

    show_images(count, channels, images)


class DiskCacher:
    """
    Disk cacher which can be used as a key-value store which stores its data as
    files in a given directory. Uses cPickle to store generic objects, but can be
    used to store NumPy arrays in a more optimized fashion using numpy.save
    and numpy.load.

    """
    def __init__(self, directory):
        """ Initialize a disk cacher to use a given directory. """
        self.directory = directory

    def cached(self, filename):
        """ Return true if the cache file with the filename exists. """
        if self.directory is None:
            return False

        # Try the filename itself
        try:
            f = open(os.path.join(self.directory, filename), "r")
            f.close()
            return True
        except IOError:
            pass

        # Try with the .npy extension
        try:
            f = open(os.path.join(self.directory, filename + ".npy"), "r")
            f.close()
            return True
        except IOError:
            pass

        return False

    def cache(self, filename, data):
        """ Store some data in a cache file with the given filename. """
        if self.directory is None: return
        
        f = open(os.path.join(self.directory, filename), "wb")
        cPickle.dump(data, f)
        f.close()
        logging.debug("Cached " + os.path.join(self.directory, filename))

    def uncache(self, filename):
        """ Return the data stored in the cache file with the given filename. """
        if self.directory is None: return
        
        f = open(os.path.join(self.directory, filename), "rb")
        obj = cPickle.load(f)
        f.close()
        logging.debug("Uncached " + os.path.join(self.directory, filename))
        return obj

    def cache_numpy(self, filename, data):
        """ Store a NumPy array in a cache file with the given filename. """
        if self.directory is None: return
        
        if not type(data) is numpy.ndarray:
            raise ValueError("Not a NumPy array", data)
        numpy.save(os.path.join(self.directory, filename), data)
        logging.debug("Numpy cached " + os.path.join(self.directory, filename))

    def uncache_numpy(self, filename):
        """ Return the NumPy array stored in the cache file with the given filename. """
        if self.directory is None: return

        if not filename.endswith(".npy"):
            filename += ".npy"
        
        result = numpy.load(os.path.join(self.directory, filename))
        logging.debug("NumPy uncached " + os.path.join(self.directory, filename))
        return result

### Data input and output ###

class ImageSource(object):
    """
    Base input source class.

    A subclass should be implemented for each type of data source. Each subclass should
    provide the following methods and fields:
        batch(self, batchnum)   - return the batch tuple
        test_set(self)          - return the test set tuple
        self.num_batches        - batches in an epoch
        self.image_shape        - image shape, in the form (channels, width, height)
        self.batch_size         - number of examples per batch

    If the data will be used for classification, it must also provide:
        self.num_classes        - number of different classes

    """
    def encode_labels(self, labels, numclasses):
        """
        Encode a list of class labels as a matrix of binary vectors. The elements of
        these vectors are one at the index of the class label, and zero otherwise.
        
        Example:
            encode_labels([0, 1, 1, 2], 3):
              [1 0 0]
              [0 1 0]
              [0 1 0]
              [0 0 1]

        Note that the rows are examples and the columns are the features.

        """
        if len(unique(labels)) > numclasses or max(labels) > numclasses:
            raise ValueError("Incorrect number of classes passed to label encoding.")

        # Make sure the first class is a zero
        labels = numpy.asarray(labels) - numpy.min(labels)
        
        # Create the binary vector encoding
        numel = len(labels)
        encoded = numpy.zeros((numel, numclasses))
        for row in xrange(numel):
            encoded[row, labels[row]] = 1

        return encoded

    def batch(self, batchnum):
        """
        Return a tuple containing the pixels, labels, and encoded labels.
        
        The pixels should be a NumPy array of dimensions (self.batch_size,) + self.image_shape.
        The labels can be a list of integers (starting with zero) or a NumPy array.
        The encoded labels should be of dimensions (self.batch_size,) + self.num_classes.
        """
        raise NotImplementedError()

    def test_set(self):
        """
        Return the test set as a batch. The return value is a 4-tuple of test set size, 
        pixel data, labels, and encoded labels. 
        
        For a convolutional neural network, batch size is fixed, so the output size will
        be that of a batch, and not the test set. The extra examples are generated by 
        repeating elements of the test set.

        """
        raise NotImplementedError()

class DirectoryImageSource(ImageSource):
    def __init__(self, directory=".", batch=None, method="preload", subdirectories=None, exclude=[], max_batches_preload=3,
                       balance_classes=False, samples_per_class=None, cache_dir=None, test_set_size=None):
        """
        Initialize an input source which reads images from a common top-level directory.
        
        The top-level directory is specified by the directory argument. The image class for each
        image is specified by the top-level subdirectory in which it resides. A list of subdirectories
        corresponding to image classes should be provided; if subdirectories is None, it is assumed
        to be all the subdirectories of the top-level directory.
        
        Subdirectories may be excluded by putting them in the exclude list. These subdirectories'
        paths should not include the path to the top-level directory, only the path after the 
        top-level directory.
        
        Example:
          images/
            one/
            two/
            three/
        
          DirectoryImageSource("images", exclude = ["three"])
          DirectoryImageSource("images", subdirectories = ["one", "two"])
        
          Both options will select all files (recursively) inside images/one and images/two
          and assign the classes 0 and 1 to the images in images/one and images/two, respectively.
        
        The batch size must be specified at construction of the input source. If no batch size is
        given, then it is assumed that the entire data set is small enough to be loaded into memory
        and it will be used all at once instead of dividing it into minibatches.
        
        The method used for loading data must also be specified at the time of creation. The method
        is specified by a string. At the moment, the following methods are supported:
          'preload'   - Pre-load the entire data set into memory, and index into it when retrieving batches.
          'async'     - Pre-load batches in a separate thread, which can run alongside computation.
                        When using 'async', the max_batches_preload argument specifies the maximum number of
                        batches that can be preloaded into memory at a time.
          'sync'      - Synchronously load batches when they are requested.
        
        If the input classes are highly unbalanced (for instance, twice as many positive as negative classes),
        the classifier may learn to simply predict the more common class. In order to avoid this, the data
        can be balanced by artificially inflating or decreasing the number of samples in each class such that
        the number of samples per class (in the data set) is the same for all classes. Classes are balanced if
        balance_classes is set to True. By default, the number of samples per class is given by the size of the 
        largest class, but this can be changed by passing a non-None value for samples_per_class.

        Loading data from image format can be very time consuming. The result of data loading can be stored on disk
        so that repeated execution is faster. In order to enable caching on disk, set the cache_dir to to a directory
        in which the cache files can be stored. This directory must already exist.

        Some amount of images is allocated as the test set, in order to display accuracy during neural network training.
        The number of images allocated can be set with the test_set_size parameter. The test set size cannot be greater
        than the batch size, so if you pass a value greater than the batch size it will be set to the batch size instead.

        """
        # If no subdirectories are provided, use all child directories.
        if subdirectories is None:
            subdirectories = os.listdir(directory)

        # Make sure there are no duplicate directories.
        # If there were duplicates, we'd have two classes with the same data.
        if len(subdirectories) != len(set(subdirectories)):
            raise ValueError("Duplicate class directories", subdirectories)

        # Remove excluded subdirectories
        subdirectories = [subdir for subdir in subdirectories if subdir not in exclude]

        self.class_names = subdirectories
        self.cacher = DiskCacher(cache_dir)
        self.max_batches_preload = max_batches_preload

        # Compute full paths to the directory for each class
        self.class_paths = [os.path.join(directory, subdirectory) for subdirectory in subdirectories]
        self.num_classes = len(self.class_paths)

        if not self.cacher.cached("images.cache"):
            logging.info("Finding image list.")
            self.find_images()
            self.cacher.cache("images.cache", (self.image_files, self.image_classes))
        else:
            logging.info("Loading cached image list.")
            self.image_files, self.image_classes = self.cacher.uncache("images.cache")

        self.compute_image_shape()

        # Do any preloading, if necessary
        self.load_method = method
        if method == "preload":
            # Load the entire data array
            logging.info("Loading data into memory.")
            self.data = self.load_images(self.image_files)
            self.index_map = dict(zip(self.image_files, xrange(len(self.image_files))))
            logging.info("Done loading data.")

        if balance_classes:
            logging.info("Balancing classes.")
            self.balance_classes(samples_per_class)

        logging.info("Shuffling data.")
        self.shuffle(250)

        # If no batch is specified, do not use minibatches.
        # Equivalently, set the minibatch size to the data set size.
        if batch is None:
            if test_set_size is None:
                test_set_size = len(self.image_files) / 8

            batch = len(self.image_files) - test_set_size

        # Separate out the test set
        if test_set_size is None:
            test_set_size = batch
        elif test_set_size > batch:
            logging.warning("Test set size cannot be greater than batch size.")
            logging.warning("Test set size set to %d" % batch)
            test_set_size = batch

        self.batch_size = batch
        self.test_set_size = test_set_size
        self.num_batches = len(self.image_files[test_set_size:]) / self.batch_size
        logging.info("Num Batches: %d" % self.num_batches)
        logging.info("Batch Size: %d" % self.batch_size)
        logging.info("Test Set Size: %d" % self.test_set_size)

        if method == "async":
            self.preloaded = []
            self.start_async_loading()

        self.test_set_files = self.image_files[0:test_set_size]
        self.image_files = self.image_files[test_set_size:]
        self.test_set_classes = self.image_classes[0:test_set_size]
        self.image_classes = self.image_classes[test_set_size:]

    def find_images(self):
        """
        Find all images in these directories.
        Return the tuple (files, classes) where files is a list of image path names and
        classes is their respective class indices.

        """
        files = []
        classes = []

        class_index = 0
        for subdir in self.class_paths:
            for dirpath, dirnames, filenames in os.walk(subdir, followlinks=True):
                for filename in filenames:
                    files.append(os.path.join(dirpath, filename))
                    classes.append(class_index)

            class_index += 1

        self.image_files = files
        self.image_classes = classes

        return files, classes

    def balance_classes(self, samples=None):
        """
        Adjust this data source so that each class is sampled from evenly. Batches may still
        have slightly unequal distributions, simply due to random chance, but overall distribution
        will be equal among classes.

        The number of samples from each class can be specified by the samples argument. If samples is
        greater than the size of a given class, elements of that class will be randomly repeated. If 
        the size of a class is greater than the desired number of samples, random elements of the class
        will be discarded. If samples is None, then by default the number of samples per class will 
        be set to the number of elements in the largest class.

        Return a tuple of the list of image files and the list of image classes.

        """
        # Separate the data into lists by classes
        segregated = [[]  for i in xrange(self.num_classes)]
        for filename, cls in zip(self.image_files, self.image_classes):
            segregated[cls].append(filename)

        # Count number in each class
        counts = [len(filenames) for filenames in segregated]

        # By default, use largest class to determine number of samples per class
        if samples is None:
            samples = max(counts)

        # Balance the lists so they are all the same size
        balanced = []
        for elements in segregated:
            if len(elements) <= samples:
                balanced.append(elements * (samples / len(elements)) + elements[0:samples % len(elements)])
            else:
                balanced.append[elements[0:samples]]

        # Flatten list into single list
        image_files = []
        for files in balanced:
            image_files.extend(files)

        image_classes = []
        for i in xrange(self.num_classes):
            image_classes.extend([i] * len(balanced[i]))

        self.image_files = image_files
        self.image_classes = image_classes

        return image_files, image_classes

    def load_images(self, filenames):
        """ Return the specified images as a numpy array, with the first dimension equal to the number of filenames. """
        cachename = "data-%s.cache" % hex(abs(hash(str(filenames))))
        if self.cacher.cached(cachename):
            return self.cacher.uncache_numpy(cachename)

        num_images = len(filenames)
        data = numpy.zeros((num_images,) + self.image_shape, 'uint8')

        for filename, index in zip(filenames, xrange(num_images)):
            data[index, :, :, :] = numpy.asarray(Image.open(filename)).transpose((2, 0, 1))

            if index % 1000 == 0:
                logging.info("Read %d images." % index)

        self.cacher.cache_numpy(cachename, data)

        return data

    def load_indexed_batch(self, filenames):
        """
        Load and return a set of images (pixels) under the assumption that the 
        loading method is "preload", and all data is stored in memory.

        """
        # Find the indices of these images in the preloaded array
        indices = [self.index_map[filename] for filename in filenames]

        # Index into the global array to get the batch.
        # Note that since we are using advanced indexing, this creates a copy
        # of the data, not just a view into the original array.
        batch_data = self.data[indices, :, :, :]
        return batch_data

    def load_batch(self, batchnum):
        """ Load the images and labels for a batch. Return a tuple containing the pixels, labels, and encoded labels. """
        # Choose images to include in this batch
        filenames = self.image_files[batchnum * self.batch_size : (batchnum + 1) * self.batch_size]
        labels = self.image_classes[batchnum * self.batch_size : (batchnum + 1) * self.batch_size]

        batch_data = self.load_images(filenames)
        encoded_labels = self.encode_labels(labels, self.num_classes)


        return batch_data, labels, encoded_labels

    def batch(self, batchnum, flipped=False):
        """
        Returns the batch at the current index. Indexing starts at zero.

        The speed and memory usage of this function depends on the loading mechanism used to
        load the batches from disk into memory. The mechanism is set when creating the data
        source; see the constructor.

        """
        logging.info("Retrieving batch %d." % (batchnum + 1))
        if self.load_method == "sync":
            return self.load_batch(batchnum)

        elif self.load_method == "async":
            # Wait for a batch to be done pre-loading
            while len(self.preloaded) == 0:
                sleep(1)
                logging.info("Wating for batch %d." % (batchnum + 1))

            # Get the first preloaded batch
            batch_index, batch_data = self.preloaded.pop(0)

            # If this is the wrong batch, try again.
            if batch_index != batchnum:
                self.desired_batch = batchnum
                self.batch(batchnum)

        elif self.load_method == "preload":
            # Choose images to include in this batch
            filenames = self.image_files[batchnum * self.batch_size : (batchnum + 1) * self.batch_size]
            labels = self.image_classes[batchnum * self.batch_size : (batchnum + 1) * self.batch_size]
            encoded_labels = self.encode_labels(labels, self.num_classes)

            return self.load_indexed_batch(filenames), labels, encoded_labels

    def test_set(self):
        """
        Returns the test set as a batch. The return value is a 4-tuple of test set size, 
        pixel data, labels, and encoded labels. Note that since batch size is fixed, the
        output size will be that of a batch, and not the test set. The extra examples
        are generated by repeating elements of the test set.

        """
        logging.info("Retrieving test set.")

        filenames = self.test_set_files
        filenames = filenames * (self.batch_size / len(filenames)) + filenames[0:self.batch_size % len(filenames)]

        classes = self.test_set_classes
        classes = classes * (self.batch_size / len(classes)) + classes[0:self.batch_size % len(classes)]

        encoded = self.encode_labels(classes, self.num_classes)

        if self.load_method == "preload":
            data_batch = self.load_indexed_batch(filenames)
        else:
            data_batch = self.load_images(filenames)
        return self.test_set_size, data_batch, classes, encoded

    def start_async_loading(self):
        """
        Begin loading batches in the background. Batches are continually loaded until the number
        of preloaded, unused batches reaches the cap set by max_batches_preload in the constructor.
        When a batch is requested, it is removed from the preloaded list.

        Batches are loaded sequentially. When the last batch is loaded, the next batch to be preloaded
        loops around and becomes the first batch.

        """
        def preload(source):
            batchnum = 0
            while True:
                source.preloaded.append(source.load_batch(batchnum))
                batchnum = (batchnum + 1) % self.num_batch

                if not self.desired_batch is None:
                    batchnum = self.desired_batch
                    self.desired_batch = None

                while len(source.preloaded) >= source.max_batches_preload:
                    sleep(1)

        thread.start_new_thread(preload, (self,))

    def shuffle(self, seed=None):
        """
        Shuffle the order of the elements in this data set.

        A seed may be provided to the RNG in order to provide identical shuffling across multiple runs.

        """
        if seed is None:
           state = random.getstate()
           random.shuffle(self.image_files)

           random.setstate(state)
           random.shuffle(self.image_classes)
        else:
            old_state = random.getstate()

            random.seed(seed)
            random.shuffle(self.image_files)
            random.seed(seed)
            random.shuffle(self.image_classes)

            random.setstate(old_state)

    def compute_image_shape(self):
        """ Compute and return the input image shape by loading a sample image from the data set. """
        filename = self.image_files[0]
        image = numpy.asarray(Image.open(filename))
        self.image_shape = image.transpose((2, 0, 1)).shape

        return image.shape

### Neural Networks ###

class NeuralNetwork(object):
    """
    Neural network base class. Provides an interface to creating and
    operating a feed-forward back-propagating neural network.

    Creating a neural network:
        >>> network = NeuralNetwork("Network-Name", cache_dir="./weights")
        >>> network.layer(InputLayer(my_input_source))
        >>> network.layer(FullyConnectedLayer(20))
        >>> network.layer(SoftmaxLayer(num_classes))
        >>> network.create(L1=0, L2=0.01)
        >>> print network

    Training a neural network:
        >>> network.train(test_interval = 10, epochs = 5)

    """
    network_name_context = {}
    def __init__(self, name = None, cache_dir = "weights"):
        """ Initialize a neural network. """
        self.name = create_name("Neural-Network", name, context = NeuralNetwork.network_name_context)
        self.cacher = DiskCacher(cache_dir)
        self.name_context = {}
        self.layers = []
        self.initialized = False

    def layer(self, layer):
        """ Add a layer to the neural network. """
        layer.network = self
        layer.cacher = self.cacher

        self.layers.append(layer)

    def initialize(self):
        """
        Initialize internal state in the neural network. 

        This method should only be called when all the layers have already been added. It
        is called automatically before training the network.

        """
        # Initialize all layers
        self.layers[0].initialize(self, None)
        for layer, previous in zip(self.layers[1:], self.layers):
            layer.network = self
            layer.previous = previous
            layer.initialize(self, previous)

        # Load weights from the cache
        self.load()

    def load(self):
        """ Load the neural network weights from the cache. """
        self.layers[-1].load()

    def create(self, **params):
        """
        Create the neural network training functions. Create a cost 
        function to minimize, compute the gradients of the cost with respect
        to all the parameters, and compile functions for training the network,
        measuring the cost for a given data set, and predicting output values
        for a given set of inputs.

        This function must be called prior to train(), cost(), output(), or predict().

        Available parameters are:
            L1 - L1 regularization parameter. 
                 This parameter can be overridden for each layer by calling layer.regularize().
            L2 - L2 regularization parameter
                 This parameter can be overridden for each layer by calling layer.regularize().
            learning_rate - minibatch gradient descent learning rate
                 This parameter can be overridden for each layer by calling layer.regularize().

        """
        logging.info("Creating neural network %s" % self.name)

        if not self.initialized:
            self.initialize()

        for line in str(self).split("\n"):
            logging.info(line)

        # Use default values for parameters if none provided
        default_values = {
            'L1' : 0.0,
            'L2' : 0.0,
            'learning_rate' : 0.1
        }
        for key in default_values:
            if not key in params:
                params[key] = default_values[key]

        # Set regularization if it isn't set for each layer
        for layer in self.layers:
            if not hasattr(layer, 'regularization'):
                layer.regularization = {'L1': params['L1'], 'L2': params['L2']}
            if not hasattr(layer, 'learning_rate'):
                layer.learning_rate = params['learning_rate']

        # Input and output layers have symbolic variables
        input_data = self.layers[0].layer_output()
        output_data = self.layers[-1].layer_output()
        output_data_test = self.layers[-1].layer_output(test = True)

        # Create the cost function to minimize
        labels = tensor.dmatrix("labels")
        cost = binary_crossentropy(output_data, labels).mean()

        # Regularization penalty for large weights
        for layer in self.layers:
            for param in layer.params:
                param = param.flatten()
                cost += layer.regularization['L1'] * tensor.sum(abs(param))
                cost += layer.regularization['L2'] * tensor.sum(param ** 2)

        # Compute update rule
        updates = {}
        for layer in self.layers:
            gradients = grad(cost, layer.params)
            for (variable, gradient) in zip(layer.params, gradients):
                updates[variable] = variable - layer.learning_rate * gradient

        # Get outputs of all layers
        layer_outputs = [layer.layer_output(test=True) for layer in self.layers]

        # Compile all Theano functions
        mode = ProfileMode(optimizer='fast_run', linker=gof.OpWiseCLinker())
        self.mode = mode
        self.theano_train        = function(inputs=[input_data, labels],  outputs=cost, updates=updates)
        self.theano_get_cost     = function(inputs=[input_data, labels],  outputs=cost)
        self.theano_get_output   = function(inputs=[input_data],          outputs=output_data_test)
        self.theano_get_layers   = function(inputs=[input_data],          outputs=layer_outputs)

        # Ready to train
        self.initialized = True

    def learn(self, batch, labels):
        """
        Train a neural network on a single labeled batch.

        Return the cost for this batch (before training).

        """
        if not self.initialized:
            raise Exception("Neural network must be initialized prior to training.")

        return self.theano_train(batch, labels)

    def cost(self, batch, labels):
        """ Compute the neural network cost function for a labeled batch. """
        if not self.initialized:
            raise Exception("Neural network must be initialized prior to evaluation.")

        return self.theano_get_cost(batch, labels)

    def output(self, batch):
        """ Compute the neural network raw output for an input batch. """
        if not self.initialized:
            raise Exception("Neural network must be initialized prior to evaluation.")

        return self.theano_get_output(batch)

    def layer_outputs(self, batch):
        """ Compute the neural network raw output for all layers for an input batch. """
        if not self.initialized:
            raise Exception("Neural network must be initialized prior to evaluation.")

        return self.theano_get_layers(batch)

    def predict(self, batch):
        """ Compute the neural network classification prediction for an input batch. """
        output = self.output(batch)
        return numpy.argmax(output, axis = 1)

    def __str__(self):
        """ Return a human-readable representation of the neural network structure. """
        layers = "\n".join(["  " + str(l) for l in self.layers])
        return "Neural Network %s {\n%s\n}" % (self.name, layers)

    # Train the neural network with stochastic minibatch gradient descent. 
    def train(self, epochs=None, save_interval=5, test_interval=10, multithreaded_io=True, use_flipped=False):
        """
        Train a neural network.

        Parameters:
            epochs  - for how many epochs to train the network. If epochs is None, the
                network is trained indefinitely.
            test_interval - how often to evaluate the network on the test set. This is
                the number of batches that are trained between each evaluation.           
            save_interval - how often to save the network parameters to disk. This is
                the number of batches that are trained between each save point.           
            multithreaded_io - whether to use a separate thread to save layer parameters
                to disk.

        """
        source = self.layers[0].data_source

        def do_save():
            self.layers[-1].save(multithreaded_io)

        def do_test():
            test_size, test_data, test_labels, test_encoded = source.test_set()
            predictions = self.predict(test_data)

            percentage = 100 * sum(numpy.asarray(test_labels[0:test_size]) == predictions[0:test_size]) / float(test_size)
            samples = zip(predictions[0:10], test_labels[0:10])
            classes_in_prediction = len(set(predictions.tolist()))
            
            logging.info("Test Set Performance: %.1f%%" % percentage)
            logging.info("Samples (Predicted, Actual): " + str(samples))
            logging.info("Unique predicted classes: %d" % classes_in_prediction)

        epochs_trained = 0
        total_trained = 0
        while epochs is None or epochs_trained < epochs:
            batches_trained = 0
            while batches_trained < source.num_batches:
                flip = use_flipped and random.choice((True, False))
                batch, labels, encoded_labels = source.batch(batches_trained)

                if flip:
                    for img_ind in xrange(batch_data.shape[0]):
                        for channel_ind in xrange(batch_data.shape[1]):
                            batch[img_ind, channel_ind] = numpy.fliplr(batch[img_ind, channel_ind])


                logging.info("Learning from batch %d of %d." % (batches_trained + 1, source.num_batches))
                cost = self.learn(batch, encoded_labels)
                logging.info("Trained batch %d of %d." % (batches_trained + 1, source.num_batches))

                batches_trained += 1
                total_trained += 1

                if total_trained % save_interval == 0:
                    do_save()
            
                if total_trained % test_interval == 0:
                    do_test()

            epochs_trained += 1
            logging.info("Trained epoch %d." % epochs_trained)

        # Save at the end
        do_save()
        do_test()

    def test(self, batch, test_size=None):
        test_data, test_labels, test_encoded = batch
        if test_size is None:
            test_size = test_encoded.shape[0]

        predictions = self.predict(test_data)

        percentage = 100 * sum(numpy.asarray(test_labels[0:test_size]) == predictions[0:test_size]) / float(test_size)
        samples = zip(predictions[0:10], test_labels[0:10])
        classes_in_prediction = len(set(predictions.tolist()))
        
        logging.info("Performance: %.1f%%" % percentage)
        logging.info("Samples (Predicted, Actual): " + str(samples))
        logging.info("Unique predicted classes: %d" % classes_in_prediction)

        return percentage

### Neural Network Layers ###

class NeuralNetworkLayer(object):
    """
    Neural network layer base class. 

    The Neural Network Layer class provides essential methods such as
    string representation, layer saving and loading, etc. 

    Subclasses should implement an initialize(self, network, previous) method
    which sets layer.params, layer.shape, and layer.output to the list of shared
    variables representing the weights, the output shape (tuple, with implied first element as batch size),
    and the symbolic expression representing the output of the layer.

    Subclasses can use the previous layer shape and output to compute their output, via
    previous.shape and previous.output.

    """

    def save_layer(self):
        """ Save the parameters in this layer using the disk cacher. """
        for param in self.params:
            filename = "%s-%s.weights" % (self.name, param.name)
            self.cacher.cache_numpy(filename, param.get_value())

    def load_layer(self):
        """ Load the parameters in this layer using the disk cacher. """
        for param in self.params:
            filename = "%s-%s.weights" % (self.name, param.name)
            if self.cacher.cached(filename):
                param.set_value(self.cacher.uncache_numpy(filename))
                logging.info("Loaded parameter %s in layer '%s'" % (param.name, self.name))
            else:
                logging.info("Randomly initialzed parameter %s in layer '%s'" % (param.name, self.name))

    def __str__(self):
        """ Return a human-readable representation of the neural network layer. """
        
        # Pad the output shape string length to 12 characters
        shpstr = str(self.shape)
        if len(shpstr) < 12:
            shpstr += " " * (12 - len(shpstr))
        
        # Count the number of parameters
        nparams = 0
        for param in self.params:
            nparams += prod(param.get_value().shape)
        
        return "'%s'\toutput shape %s\tnparams %d\t%s" % (self.name, shpstr, nparams, self.__class__.__name__)

    def uniform_sample(self, shape, spread):
        """ Sample and return zero-mean variable with uniform spread """
        values = spread * numpy.random.random_sample(shape) - spread / 2.0
        return values

    def cumulative_parameter_list(self):
        """ Return a list of all shared parameters used by this neural network, up through this layer. """
        return self.previous.cumulative_parameter_list() + self.params

    def save(self, multithreaded = True):
        """
        Save this layer and all previous layers to the cache.
        If multithreaded is true, start a new thread for each layer.

        """
        if len(self.params) != 0:
            if multithreaded:
                thread.start_new_thread(self.save_layer, ())
            else:
                self.save_layer()

        self.previous.save(multithreaded)

    def load(self):
        """ Load this layer and all previous layers from the cache. """
        if len(self.params) != 0:
            self.load_layer()
        self.previous.load()

    def regularize(L2=0.0, L1=0.0):
        """
        Set the regularization parameters for this layer.

        The default regularization is none, and the default can be changed
        by passing it as a parameter to network.create().

        """
        self.regularization = {'L1' : L1, 'L2': L2}

    def layer_output(self, test = False):
        return self.output

class InputLayer(NeuralNetworkLayer):
    """
    Neural network input layer.

    The input layer serves as a base for the neural network and as a base case for all recursive methods.

    """

    def __init__(self, data_source, image = True, name = None):
        self.name = name
        self.shape = data_source.image_shape
        self.image = image
        self.data_source = data_source

    def initialize(self, network, previous):
        """
        Initialize the neural network.

        The output of the neural network is a symbolic variable which serves as the input for the net.

        """
        self.name = create_name("input", self.name, network.name_context)
        self.params = []
        if self.image:
            self.output = tensor.tensor4("input")
        else:
            self.output = tensor.matrix("input")
        network.batch_size = self.data_source.batch_size

    def cumulative_parameter_list(self):
        # Recursive base case: return a list with no parameters.
        return []

    def save(self, multithreaded):
        # Recursive base case: do nothing.
        pass

    def load(self):
        # Recursive base case: do nothing.
        pass

class NormalizationLayer(NeuralNetworkLayer):
    """
    Data normalization layer.

    A normalization layer is used to make the input data zero-mean and unit-variance. When created,
    it reads the entire data set from the data source and computes the mean and variance, and 
    applies a linear transformation to the data in order to make it zero mean and unit variance.

    Normalization is necessary for inputs to convolutional or fully connected layers.

    """
    def __init__(self, name = None):
        self.name = name

    def initialize(self, network, previous):
        """ Initialize the normalization layer. Scale the input by the standard deviation after subtracting the mean. """
        self.name = create_name("normalize", self.name, network.name_context)
        self.data_source = previous.data_source
        self.cacher = network.cacher
        self.params = []
        
        # Compute mean and variance
        self.compute_statistics(self.data_source)

        # Compute standard deviation and scaling.
        # Scale by 1/standard deviation, unless the standard deviation in zero, in which case just set the input to zero.
        stdev = numpy.sqrt(self.image_variance / self.image_count)
        scale = numpy.select([stdev != 0, stdev == 0], [1 / (stdev + (stdev == 0)), 0])

        # Take any input and shift and scale it.
        # The data shape remains the same.
        self.output = (previous.output - self.image_mean) * scale
        self.shape = previous.shape

    def compute_statistics(self, source):
        """
        Compute the per-pixel mean and variance of the data set. Mean and variance are
        calculated using an O(n) online algorithm, with no unnecessary memory allocation.

        Store the mean, variance, and number of samples as fields. Cache their values on disk.

        """
        if self.cacher.cached(self.name + "-mean") and self.cacher.cached(self.name + "-count"):
            mean = self.cacher.uncache_numpy(self.name + "-mean")
            variance = self.cacher.uncache_numpy(self.name + "-variance")
            n = self.cacher.uncache(self.name + "-count")
        else:
            n = 0.0
            mean = numpy.zeros(source.image_shape)
            variance = numpy.zeros(source.image_shape)
            for batchnum in xrange(source.num_batches):
                data, labels, encoded_labels = source.batch(batchnum)
                for i in xrange(data.shape[0]):
                    n = n + 1
                    delta = data[i, :, :, :] - mean
                    mean += delta / n
                    variance += delta * (data[i, :, :, :] - mean)

            self.cacher.cache_numpy(self.name + "-mean", mean)
            self.cacher.cache_numpy(self.name + "-variance", variance)
            self.cacher.cache(self.name + "-count", n)

        self.image_mean = mean
        self.image_variance = variance
        self.image_count = n

class FullyConnectedLayer(NeuralNetworkLayer):
    """
    Fully connected neural network layer.

    Perform non-linear regression using all the covariates in the input. The non-linear 
    function that is applied point-wise at the output is specified by the 'activation'
    argument, which defaults to hyperbolic tangent.

    """
    def __init__(self, neurons, name=None, activation=tensor.tanh, dropout=False):
        self.name = name
        self.dropout = dropout
        self.shape = (neurons,)
        self.activation = activation

    def initialize(self, network, previous):
        """
        Initialize the fully connected layer.

        Weights are randomly initialized from a uniform spread of 2.0 / sqrt(1.5 * fan_in), where
        fan_in is the number of inbound connections to each neuron.

        """
        self.name = create_name("fcn", self.name, network.name_context)
        
        # Weights and biases
        numel = prod(previous.shape)
        neurons = self.shape[0]
        weightshape = (neurons, numel)
        weightspread = 2.0 / sqrt(1.5 * numel)
        self.w = shared(self.uniform_sample(weightshape, weightspread), "W_" + self.name)
        self.b = shared(self.uniform_sample((neurons,), weightspread), "B_" + self.name)

        self.params = [self.w, self.b]

    def layer_output(self, test = False):
        """
        Compute and return output of the fully connected layer.

        If test is true, dropout is disabled regardless of whether it was enabled in the first place.

        """
        # Data, arranged as a vector
        x = self.previous.layer_output(test).flatten(ndim=2)

        output = self.activation(dot(self.w, x.transpose()).transpose() + self.b)

        if test:
            return output

        if self.dropout:
            rng = RandomStreams(seed=random.randint(0, 1000000))
            enabled = rng.binomial((self.network.batch_size,) + self.shape)
            output = output * enabled

        return output

    def display(self, start=0, count=10):
        """
        Display the receptive fields for this fully connected layer as an image.

        If the previous layer cannot be interpreted as an image, an error is raised.
        
        """
        shape = self.previous.shape[1:]
        weights = self.w.get_value()
        neurons = min(weights.shape[0], count)

        if len(self.previous.shape) != 3:
            raise ValueError("Previous layer is not an image", self.previous.shape)

        numfilters = self.previous.shape[0]

        images = [[0] * numfilters for i in xrange(neurons - start)]
        for row in xrange(start, neurons):
            for column in xrange(numfilters):
                img = weights[row, :].reshape((numfilters, ) + shape)
                images[row][column] = img[column, :, :]

        show_images(neurons - start, numfilters, images)

class SoftmaxLayer(FullyConnectedLayer):
    """
    Softmax neural network layer.

    The softmax layer is a commonly-used fully connected layer which applies
    the softmax function to its inputs:
       softmax(x) = exp(x) / sum(exp(x))
    where x is a vector and exp(x) is the pointwise exponential operation.

    Softmax layers are commonly the output of a classification neural network,
    so that the outputs sum to one and can be interpreted as probabilities.

    """
    def __init__(self, neurons, name=None):
        super(SoftmaxLayer, self).__init__(neurons, name, activation=softmax)

class ConvolutionalLayer(NeuralNetworkLayer):
    """
    Convolutional neural network layer.

    A convolutional layer applies filters to each channel of the incoming image. A different
    filter is applied to each image, and the result is summed. This is done many times to produce
    a many-channel output image. A bias term is also added to each filter result.

    The number of parameters is output_channels x input_channels x image_width x image_height.
    The output width and height are given by image_width - filter_width + 1 and image_height - filter_height + 1,
    due to edge considerations when performing the image convolutions.

    """
    def __init__(self, filtershape, filters, activation = tensor.tanh, name = None):
        self.name = name
        self.filtershape = filtershape
        self.filters = filters
        self.activation = activation

    def initialize(self, network, previous):
        """
        Initialize the convolutional layer.

        Weights are randomly initialized from a uniform spread of 2.0 / sqrt(fan_in), where
        fan_in is the number of inbound connections to each neuron (filter_width * filter_height).

        """
        self.name = create_name("conv", self.name, network.name_context)

        # Compute post-filter output size
        height = previous.shape[1] - self.filtershape[0] + 1
        width = previous.shape[2] - self.filtershape[1] + 1
        self.shape = (self.filters, height, width)

        # Input data, indexed by batch index, channel, row, height
        x = previous.output

        # Weights and biases. Use a heuristic uniform spread to randomly initialize weights.
        weightshape = (self.filters, previous.shape[0]) + self.filtershape
        weightspread = 2.0 / prod(self.filtershape)
        self.w = shared(self.uniform_sample(weightshape, weightspread), "W_" + self.name)
        self.b = shared(self.uniform_sample(self.filters, weightspread), "B_" + self.name)
        self.params = [self.w, self.b]
        
        datashape = (network.batch_size,) + previous.shape
        feature_maps = conv2d(x, self.w, image_shape=datashape, filter_shape=weightshape, border_mode='valid') + self.b.dimshuffle('x', 0, 'x', 'x')

        if self.activation is None:
            self.output = feature_maps
        else:
            self.output = self.activation(feature_maps)

    def display(self):
        """ Display the filters used by this convolutional layer in a new window. """

        weights = self.w.get_value()
        numfilters = self.shape[0]
        numchannels = self.previous.shape[0]

        # Display the filters in a grid, with each row being a filter
        # and each column being a channel in the previous image.
        images = [[0] * numchannels for i in xrange(numfilters)]
        for row in xrange(numfilters):
            for column in xrange(numchannels):
                img = weights[row, column, :, :].reshape(weights.shape[2:])
                images[row][column] = img

        show_images(numfilters, numchannels, images)

class MaxPoolLayer(NeuralNetworkLayer):
    """
    Max pooling layer.

    A max pooling layer takes a region and represents it by the maximum value in that region.

    The output shape is input_channels x (image_width / pool_width) x (image_height / pool_height).

    """
    def __init__(self, patchshape, activation = None, name = None):
        self.name = name
        self.params = []
        self.patch = patchshape
        self.activation = activation

    def initialize(self, network, previous):
        """ Initialize the pooling layer, checking that the input width and height are divisibile by pool width and height. """
        self.name = create_name("pool", self.name, network.name_context)

        # Check that the pooling shape fits the image size without leaving gaps
        prev_shape = previous.shape
        if prev_shape[1] % self.patch[0] != 0 or prev_shape[2] % self.patch[1] != 0:
            errval = (prev_shape[1], prev_shape[2], self.patch[0], self.patch[1])
            raise ValueError("Max pooling of image %dx%d, but badly sized patch %dx%x", errval)

        self.shape = (prev_shape[0], prev_shape[1] / self.patch[0], prev_shape[2] / self.patch[1])
        self.output = max_pool_2d(previous.layer_output(), self.patch)

        if not self.activation is None:
            self.output = self.activation(self.output)
