%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Function Name: Layered BilateralFilter
%Aim: Use the bilateral filter to upsample the depth map
%Output: 
%   Result        -   The output depth map after bilateral filtering
%Input: 
%   color         -   Color image
%   depth 		  -   Depth map
%   sigma_w       -   Coefficient of gaussian kernel for spatial
%   sigma_c       -   Coefficient of gaussian kernel for range
%   w             -   Window size
%   DepthInteval  -   
%   IterativeTime -
%Code Author:
%   Liu Junyi, Zhejiang University
%   Version 1: June 2012
%   Version 2: May 2013
%Ref:
%   Yang, Q., et al. Spatial-depth super resolution for range images. 
%                    Computer Vision and Pattern Recognition, 2007.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function Result = LayeredBilateralFilter(color,depth,sigma_w,sigma_c,w,DepthInteval,IterativeTime)
    %% Initialization
    L=10000;
    k=1;
    D(:,:,1) = double(depth);
    CandidateD = 0:DepthInteval:255;
    height = size(color,1);
    width = size(color,2);
    color = double(color);
    CostVolume=zeros(height,width,length(CandidateD));
    CostCW=zeros(height,width,length(CandidateD));

    %% Iterative Module
    while 1
        for i=1:length(CandidateD)
            CostVolume(:,:,i) = min(L,(CandidateD(i)-D(:,:,k)).^2);                   %Cost Volume C(i)
            CostCW(:,:,i) = BilateralFilter(color,CostVolume(:,:,i),sigma_w,sigma_c,w);   %A bilateral filtering is performed throughout each slice of the cost volume to produce the new cost volume 
            % Compare with the reference, the color space is different  
        end
        [BestCost,BestDepthLocation] = min(CostCW,[],3);                          %Selecting the depth hypothesis with the minimal cost

        % Sub-pixel estimation
        CostUpper = zeros(height,width);
        CostLower = zeros(height,width);
        for i = 1:length(CandidateD) 
            CostUpper = CostUpper + CostCW(:,:,i).*((BestDepthLocation+1)==i);
            CostLower = CostLower + CostCW(:,:,i).*((BestDepthLocation-1)==i);
        end
        k = k + 1;
        D(:,:,k) = CandidateD(BestDepthLocation) - DepthInteval * (CostUpper-CostLower) ./ (2*(CostUpper+CostLower-2*BestCost));  
        % end of sub-pixel estimation   

        if IterativeTime==k
            break;
        end
    end
    Result = D(:,:,IterativeTime);
end