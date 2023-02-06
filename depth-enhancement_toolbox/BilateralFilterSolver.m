function dst = BilateralFilterSolver(target, color, confidence, sigma_spatial, sigma_luma, sigma_chroma, lambda_w, num_iter, max_tol)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Function Name: BilateralFilterSolver
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

outputArg1 = inputArg1;
outputArg2 = inputArg2;
end

