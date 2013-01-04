__Convolutional Neural Networks for Dog Breed Identification__

Using convolutional neural networks, this project aims to be able to distinguish what breed a dog is given its photograph.  Using five different breeds with a total of approximately
25,000 training images, the neural network classifier achieves a classification rate of approximately 90%. 

The current implementation learns to distinguish 5 breeds of dogs (Hound, Golden Retriever, Poodle, Boxer, and Border Collie). It does
so by creating a pairwise classifier for each pair of breeds, and training it until convergence. The recognition rates for the pairwise classifiers
are in the range of 70% to 95%. 

After training N(N-1)/2 classifiers (one per pair), every image is put through every classifier. Note that every image goes through every classifier,
which means that each classifier ends up operating on data that it was never meant to be used on. The Boxer vs Poodle classifier will be used on Golden Retrievers
as well as Boxers. This yields a vector of "probabilities" for each image - since we have 10 classifiers, and each classifier will output a yes and no probability (which sum to one),
each image is converted into a string of 10\*2 = 20 numbers between zero and one. A small fully connected neural network is then trained on this data in order
to give a final multi-class prediction. The classification rate on an independent test set is approximately 90%.

__Files:__
* neuralnetworks.py - implementation of neural networks and data processing using Theano
* mnist/            - example use of neuralnetworks.py library to recognize MNIST digits (reaches 98% recognition rate)
* all\_dogs.py      - train a multi-class classifier for different breeds
* dogs.py           - trains pairwise comparison networks
* pairs.py          - run pairwise comparison networks on all input data
* pairtrain.py      - train a post-processing step to convert the output of the pairwise networks into a multi-class prediction

__Data:__
* imgs.tar.gz       - dog photos sorted by breed. Each photo was resized to a 64x64 3-color image (losing aspect ratio). Data were obtained using Petfinder.com API.
