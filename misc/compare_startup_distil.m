% reload paths etc.
% NOTE!
% The mex lock has been removed from caffe_.cpp! 
%munlock('caffe_') ;
clear all ; %#ok
%caffeType = 'ssd-caffe' ;
caffeType = 'py-faster-rcnn' ;
%caffeType = 'official-caffe' ;

switch caffeType
  case 'ssd-caffe'
    caffeRoot = '~/coding/libs/caffes/ssd-caffe' ;
  case 'official-caffe'
    caffeRoot = '~/coding/libs/caffes/official-caffe' ;
  case 'py-faster-rcnn'
    caffeRoot = '/users/albanie/coding/libs/py-faster-rcnn/caffe-fast-rcnn' ;
end
%caffePath = '/users/albanie/coding/libs/py-faster-rcnn/caffe-fast-rcnn/matlab' ;
caffePath = [caffeRoot '/matlab'] ;
%munlock('caffe_') ;
%clear caffe_.mexa64 ;
%clear caffe_ ;
rehash path ;

% hack to avoid cuda errors
a = gpuArray(1) ; clear a ; %#ok

% refresh/set up ssd-caffe
addpath(caffePath) ;

%caffeRoot = '/users/albanie/coding/libs/py-faster-rcnn/caffe-fast-rcnn' ;
%caffeRoot = '/users/albanie/coding/libs/py-faster-rcnn/caffe-fast-rcnn' ;

% set paths and load caffe ssd-model
modelDir = '/users/albanie/data/models/caffe/distillation/alexnet_rgb_alexnet_hha/nyud2_images+hha_2015_trainval' ;
dataDir = '/users/albanie/data/models/caffe/distillation/alexnet_rgb_alexnet_hha/nyud2_images+hha_2015_trainval' ;

model = fullfile(modelDir, 'test.prototxt') ;
weights = fullfile(dataDir, 'fast_rcnn_iter_40000.caffemodel') ;
caffe.set_mode_cpu() ;

% to use the relative paths defined in the prototxt, we change into the 
% caffe root to load the network
cd(caffeRoot) ;

% load model
caffeNet = caffe.Net(model, weights, 'test') ;

% load mcn model for comparison

% set path to trunk model (VGG-VD-16)
opts.trunkModelPath = fullfile(vl_rootnn, 'data', 'models-import', ...
                                'alexnet-rgb-hha.mat') ;
opts.imageSize = [224 224] ;
net = load(opts.trunkModelPath) ; net = dagnn.DagNN.loadobj(net) ;
