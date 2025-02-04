classdef BilateralSolver < handle
%(target, color, confidence, sigma_spatial, sigma_luma, sigma_chroma, lambda_w, num_iter, max_tol)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Function Name: BilateralSolver
%Aim: Use the fast bilateral filter solver to upsample the depth map
%Output: 
%   dst      -   The output depth map after bilateral filtering
%Input: 
%   target       -   Color image
%   color 		-   Depth map
%   confidence     -   Coefficient of gaussian kernel for spatial
%   sigma_spatial     -   Coefficient of gaussian kernel for range
%   sigma_luma           -   Window size
%   sigma_chroma           -   Window size
%   lambda_w           -   Window size
%   num_iter           -   Window size
%   max_tol           -   Window size
%   Code Author:
%   ZhxJ, Harbin Institute of University
%   Version 1: Feb. 2023
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
properties(Access = public)
    grid BilateralGrid;
    Dn;
    Dm;
    lam = 128; %The strength of the smoothness parameter
    A_diag_min = 1e-5; % Clamp the diagonal of the A diagonal in the Jacobi preconditioner
    cg_tol = 1e-5; % The tolerance on the convergence in PCG
    cg_maxiter = 25; % The number of PCG iterations
end

methods(Access = public)
    function obj = BilateralSolver(grid, varargin)
        obj.grid = grid;
        [obj.Dn, obj.Dm] = bistochastize(obj, 10);
    end
    
    function [Dn, Dm] = bistochastize(obj, maxiter)
        % Compute diagonal matrices to bistochastize a bilateral grid
        m = obj.grid.splat(ones(obj.grid.npixels,1));
        n = ones(obj.grid.nvertices,1);
        for i = 1:maxiter
            n = sqrt(n.*m./obj.grid.blur(n));
        end
        % Correct m to satisfy the assumption of bistochastization
        % regardless of how many iterations have been run.
        m = n .* obj.grid.blur(n);
        Dm = spdiags(m,0,length(m),length(m));
        Dn = spdiags(n,0,length(n),length(n));
    end
    
    function [xhat, obj] = solve(obj, x, w)
        %check that w is a vector or a nx1 matrix
        assert(size(w,2) == 1);
        A_smooth = (obj.Dm - obj.Dn * obj.grid.blur(obj.Dn));
        w_splat = obj.grid.splat(w);
        A_data = spdiags(w_splat(:,1),0,length(w_splat),length(w_splat));
        A = obj.lam * A_smooth + A_data;
        xw = x .* w;
        b = obj.grid.splat(xw);
        % Use simple Jacobi preconditioner
        A_diag = diag(A);
        A_diag(A_diag < obj.A_diag_min) = obj.A_diag_min;
        M = spdiags(1./A_diag,0,length(A_diag),length(A_diag));
        % Flat initialization
        y0 = obj.grid.splat(xw) ./ w_splat;
        yhat = zeros(size(y0));
        s = size(x);
        for d = 1 : s(end)
            yhat(:,d) = pcg(A, b(:,d), obj.cg_tol, obj.cg_maxiter, M, [], y0(:,d));
        end
        xhat = obj.grid.slice(yhat);
    end
end

methods(Access = private)
    
end

end

