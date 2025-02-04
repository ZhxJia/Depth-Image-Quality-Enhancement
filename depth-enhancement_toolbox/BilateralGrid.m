classdef BilateralGrid < handle
    
properties(Access = public)
    npixels;
    dim;
    nvertices;
    hash_vec;
    S;
    blurs = {};
    
    MAX_VAL = 255.0;
end

methods(Access=public, Static)
    function [valid_idx, locs] = get_valid_idx(valid, candidates)
       % Find which values are present in a list and where they are
       % located.
       [~,locs] = ismember(candidates,valid);
       valid_idx = find(locs~=0);
       locs = locs(valid_idx);
    end
end

methods(Access = public)
    function obj = BilateralGrid(im,sigma_spatial,sigma_luma,sigma_chroma)
        %BilateralGrid Construct Bilateral Grid.
        %Output
        %   grid - bilateral grid with splat,slice,blur matrix
        %Input:
        %   im - reference color image
        %   sigma_spatial - sample ratio of spatial
        %   sigma_luma - sample ratio of luma
        %   sima_chroma- sample ratio of chroma
        im_yuv = double(rgb2ycbcr(im));
        im_h = size(im_yuv,1);
        im_w = size(im_yuv,2);
        %compute 5-dimensional XYLUV bilateral-space coordinates
        [Ix, Iy] = meshgrid(1:im_w, 1:im_h);
        x_coords = floor(Ix / sigma_spatial);
        y_coords = floor(Iy / sigma_spatial);
        luma_coords = floor(im_yuv(:,:,1) / sigma_luma);
        chroma_coords = floor(im_yuv(:,:,2:3) / sigma_chroma);
        coords = cat(3, x_coords, y_coords, luma_coords, chroma_coords);
        coords_flat = double(reshape(coords,[],size(coords,3)));
        
        [obj.npixels, obj.dim] = size(coords_flat);
        obj.hash_vec = obj.MAX_VAL .^ (0:obj.dim-1)';
        
        %construct S and B matrix
        compute_factorization(obj, coords_flat);
    end
    function y = splat(obj, x)
        y = obj.S * x;
    end
    
    function x = slice(obj, y)
        x = obj.S' * y;
    end
    
    function out = blur(obj, x)
        % Blur a bilateral-space vector with a 1 2 1 kernel in each
        % dimension
        out = 2 * obj.dim * x;
        for blur = obj.blurs
            out = out + blur{1} * x;
        end
    end
    
    function y = filter(obj, x)
        % Apply bilateral filter to an input x
         y = obj.slice(obj.blur(obj.splat(x)))... 
         / obj.slice(obj.blur(obj.splat(ones(size(x)))));
    end
end

methods(Access = private)
    function obj = compute_factorization(obj, coords_flat)
        % Construct S and B matrix
        % Hash each coordiante i ngrid to a unique value
        hashed_coords = obj.hash_coords(coords_flat);
        [unique_hashes, unique_idx, idx] = unique(hashed_coords);
        
        % Identify unique set of vertices
        unique_coords = coords_flat(unique_idx,:);
        obj.nvertices = length(unique_coords);
        % Construct sparse splat matrix that maps from pixels to vertices.
        obj.S = sparse(idx, double(1:obj.npixels), ones(obj.npixels,1));
        % Construct sparse blur matrices. blur kernel [1 2 1]
        % Note that these represent [1 0 1],excluding the central element
        obj.blurs = {};
        for d = (1 : obj.dim)
            blur = sparse(obj.nvertices, obj.nvertices);
            for offset = [-1,1]
                offset_vec = zeros(1, obj.dim);
                offset_vec(:,d) = offset;
                neighbor_hash = hash_coords(obj,unique_coords + offset_vec);
                [valid_coord, idx] = obj.get_valid_idx(unique_hashes, neighbor_hash);
                blur = blur + sparse(valid_coord, idx,... 
                    ones(length(valid_coord),1), obj.nvertices, obj.nvertices);
            end
            obj.blurs{end+1} = blur;
        end
    end
    
    function result = hash_coords(obj, coord)
        % Hacky function to turn a coordinate into a unique value
        result = reshape(coord,[], obj.dim) * obj.hash_vec;
    end

end

end

