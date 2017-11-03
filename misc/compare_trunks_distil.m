% dev_script  
%steps = [8, 16, 32, 64, 100, 300]
%priorLayers = ...
    %find(cellfun(@(x) ~isempty(x), strfind({net.layers.name}, 'priorbox'))) ;

  %USE THE GPU!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  %(otherwise normalization layer is inaccurate)
  useGpu = 1 ;
  %useDebugProto = 1 ; % prevents in-place caffe ops
  if useGpu, net.move('gpu') ; end

  imPath = [vl_rootnn '/data/nyud2/data/images/img_5001.png'] ;
  hhaPath = [vl_rootnn '/data/nyud2/data/hha/img_5001.png'] ;
  depthPath = [vl_rootnn '/data/nyud2/data/depth/img_5001.png'] ;

  rois = single([0 1 1 20 20]) ;

  % create sample image
  sz = [227 227] ;
  batchSize = 1 ;
  im = single(imresize(imread(imPath), sz)) ;
  hha = single(imresize(imread(hhaPath), sz)) ;
  depth = single(imresize(imread(depthPath), sz)) ;

  im_ = permute(im, [2 1 3 4]) ;
  im_ = im_(:,:,[3 2 1],:) ;
  %hha_ = hha ;
  %keyboard
  hha_ = permute(hha, [2 1 3 4]) ;
  %hha_ = hha_(:,:,[3 2 1],:) ;
  %rois_ = rois' ;

  res_ = caffeNet.forward({im_, hha_, rois'}) ;

  pairs = [] ;
  names_ = caffeNet.blob_names() ;
  names = cellfun(@(x) {strrep(x, '/', '_')}, names_) ; % clean
  
  for p = 1:numel(names)
    name = names{p} ;

    % handle special cases first
    %switch name
      %case 'conv1_7x7_s2'
        %q = find(strcmp(name, {net.vars.name})) ;
        %pairs(end+1,:) = [q,p] ; %#ok
        %continue ;
      %case 'conv1_7x7_s2_bn1'
        %q = find(strcmp('conv1_7x7_s2x', {net.vars.name})) ;
        %pairs(end+1,:) = [q,p] ; %#ok
        %continue ;
      %case 'conv1_7x7_s2_bn2'
        %q = find(strcmp('conv1_7x7_s2xx', {net.vars.name})) ;
        %pairs(end+1,:) = [q,p] ; %#ok
        %continue ;
      %case 'conv1_7x7_s2_relu'
        %q = find(strcmp('conv1_7x7_s2xxx', {net.vars.name})) ;
        %pairs(end+1,:) = [q,p] ; %#ok
        %continue ;
    %end

    q = find(strcmp([name 'xxx'], {net.vars.name})) ;
    if ~isempty(q)
      pairs(end+1,:) = [q,p] ; %#ok
      continue;
    end
    q = find(strcmp([name 'xx'], {net.vars.name})) ;
    if ~isempty(q)
      pairs(end+1,:) = [q,p] ; %#ok
      continue;
    end
    q = find(strcmp([name 'x'], {net.vars.name})) ;
    if ~isempty(q)
      pairs(end+1,:) = [q,p] ; %#ok
      continue;
    end
    q = find(strcmp(name, {net.vars.name})) ;
    if ~isempty(q)
      pairs(end+1,:) = [q,p] ; %#ok
      continue;
    end
  end

  if useGpu, 
    im = gpuArray(im) ; hha = gpuArray(hha) ; 
    rois = rois + 1 ; % fix offset
    rois = gpuArray(rois) ; 
  end

  net.conserveMemory = false ;
  net.mode = 'test' ;
  net.eval({'data', im, 'rois', rois, 'data_1', hha}) ;

  for p = 1:size(pairs,1)
    i = pairs(p,1) ;
    i_ = pairs(p,2) ;

    xiName = net.vars(i).name;
    xi = net.vars(i).value ; % after relu, caffe shortcut

    %--------------------------------------------------
    % handle unusual matcaffe layer/blob shpae behaviour 
    % with reduced dimensions for specific layers, and other 
    % special cases
    %--------------------------------------------------
    blobData = caffeNet.blob_vec(i_).get_data() ;

    xiNameTokens = strsplit(xiName, '_') ;
    layerType = xiNameTokens{end} ;
    switch layerType
      case 'data'
        % flip BGR -> RGB for input comparison
        tmp = permute(blobData, [2 1 3 4]) ;
        xi_ = tmp(:,:,[3 2 1],:) ; 
      case 'perm'
        % to avoid repeated major/column major re-ordering,
        % the permutations are done slightly differently in 
        % MCN (described in layers.py) - this mapping is dependent
        % on the permutation used, so we skip the comparison on 
        % this layer
        xi_ = xi ; %  skip comparison 
      case 'priorbox'
        % handle missing dim on priorbox layers
        xi_ = permute(blobData, [1 3 2]) ;
      case 'flat'
      case 'out'
        % the matcaffe SSD detection output layer has an extra
        % column which describes the image identity - this 
        % isn't present in the MCN output 
        xi_ = blobData(2:end, :)' ;

        % add one to labels of caffeNet preds 
        xi_(:, 1) = xi_(:, 1) + 1 ;

      otherwise
        % standard switch from matcaffe (W x H x C x N) 
        % to matconvnet (H x W x C x N) 
      xi_ = permute(blobData, [2 1 3 4]) ; 
    end 
    namei = net.vars(i).name ;
    namei_ = char(caffeNet.blob_names(i_)) ;

    layerToInspect = 78 ;
    %if i == layerToInspect
      %keyboard
      %% prevs
      %%prevPair = [ 48 50 ] ;
      %%prevBlob = caffeNet.blob_vec(prevPair(2)).get_data() ;
      %%prevVar = net.vars(prevPair(1)).value ;
      %figure(1) ; clf ;
      %a=vl_imarray(xi) ;
      %b=vl_imarray(xi_) ;
      %imagesc(vl_imsc([a,b,a-b])) ;
      %title(str) ;
      %drawnow ;
      %zv_dispFig() ; % inline visualization
    %end

    try
      diff = norm(xi(:)-xi_(:))/norm(xi(:)) ;
      fprintf('x%d %s vs x%d %s: %g\n', i, namei, i_, namei_, diff) ;
    catch
      fprintf('x%d %s vs x%d %s: dimension error\n', i, namei, i_, namei_) ;
      disp(size(xi))
      disp(size(xi_))
    end
  end

  %layerToInspect = 105 ;
  %layerToInspect = 109;
  if i == layerToInspect
      fprintf('xi %.2f\n', xi) ;
      fprintf('xi_ %.2f\n', xi_) ;
  end

  if useGpu, net.move('cpu') ; end
