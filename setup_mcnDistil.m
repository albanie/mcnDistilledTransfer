function setup_mcnDistil()
%SETUP_MCNFASTERRCNN Sets up mcnDistil, by adding its folders 
% to the Matlab path
%
% Copyright (C) 2017 Samuel Albanie
% Licensed under The MIT License [see LICENSE.md for details]

  root = fileparts(mfilename('fullpath')) ;
  addpath(root, [root '/misc']) ;
