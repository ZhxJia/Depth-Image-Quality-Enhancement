%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%The Comparison Between Different Methods for Depth Upampling 
%   Description:
%       The code compares different depth upsampling methods. More information can be found in Readme.txt
%Code Author:
%   Liu Junyi, Zhejiang University
%   version 1: June 2012
%   version 2: May 2013
%Modified Code Author:
%   Jia Zhixiang, Harbin Insistute of Technology
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all;
close all;
clc;

%% Read data

% Depth = imread('.\data\Teddy\GroundTruth.png');
% Depth = imresize(Depth,1/2,'nearest');
% Color = imread('.\data\Teddy\Color.png');
Depth = pfmread('.\data\IC\depth.pfm');
Color = imread('.\data\IC\colorImg.bmp');
Confidence = imread('.\data\LED\maskImg0.bmp');
% Confidence = pfmread('.\data\LED\reliability0.pfm');
% Color = imresize(Color,1/2,'nearest');
% Depth = imread('.\data\synthetic\depth3.png');
% Color = imread('.\data\synthetic\color3.png');
% Depth = imread('.\data\depth_superres\target.png');
% Color = imread('.\data\depth_superres\reference.png');
% Confidence = imread('.\data\depth_superres\confidence.png');

%% Trim data if needed
ColorSection = Color(1240:1734, 1590:2100,:);
DepthSection = Depth(1240:1734, 1590:2100,:);  % rgb2gray if needed
ConfidenceSection = Confidence(1240:1734, 1590:2100,:);
% ColorSection = Color;
% DepthSection = Depth;  % rgb2gray if needed
% ConfidenceSection = Confidence;
% for i = 1:150
%     DepthSection(i,:) = i;
% end

%% assert 
if((size(DepthSection,1)~=size(ColorSection,1))||size(DepthSection,2)~=size(ColorSection,2))
    error('The depth section size must be the same as the color section');
end

Height = size(DepthSection,1);
Width = size(DepthSection,2);

%% Set Parameters

% Scaling Factor
Interval = 1;             % Down-sample factor
view_3d = 1;              % View the 3D depth or not

% BilateralFilter 
BF_sigma_w = 3;      % range sigma
BF_sigma_c = 10;	 % spatial sigma
BF_window = 10;	   	 % window size - radius
BF_method = 1;		 % The method of bilateral filter  1: original bilateral filter 2: fast bilateral filter

% BilateralUpsample
BU_sigma_w = 0.2;
BU_sigma_c = 10;
BU_window = 3;
% Noise-ware Filter
NAU_sigma_d = 2;

% Anisotropic Diffusion Parameter
AD_sigma = 15;


% MRF Parameters
MRF_sigma = 15;       % The parameter for the gaussion kernel in the smoothness term: exp(-D^2/(2*MRF_sigma^2))
MRF_alpha = 1;        % The balance factor between data term and smoothness term: DataEnergy+alpha*smoothnessEnergy
MRF_method = 3;	   	  % The method to solve MRF


% MRF Parameters based on second order
MRF_second_sigma = 15;       % The parameter for the gaussion kernel in the smoothness term: exp(-D^2/(2*MRF_sigma^2))
MRF_second_lambda1 = 0.1;       % The balance factor between data term and first order smoothness term: 
MRF_second_lambda2 = 1;       % The balance factor between data term and second order smoothness term: 

% MRF Parameters based on second order
MRF_kernelData_smoothSigma = 15;       % The parameter for the gaussion kernel in the smoothness term: exp(-D^2/(2*MRF_sigma^2))
MRF_kernelData_dataSigma = 1;
MRF_kernelData_dataWindow = 3;
MRF_kernelData_alpha = 1;    % The balance factor between data term and smoothness term: DataEnergy+alpha*smoothnessEnergy


% MRF Parameters based on Tensor
MRF_tensor_lamda = 1;         % The balance factor between IxIy and RGB in tensor: [Ix Iy lamda*R lamda*G lamda*B]'
MRF_tensor_sigma = 0.2;       % The parameter for the gaussion kernel in the smoothness term: exp(-D^2/(2*LSLSTensor_sigma^2))
MRF_tensor_alpha = 1;         % The balance factor between data term and smoothness term: DataEnergy+alpha*smoothnessEnergy

% Layered Bilateral Filter
LBF_sigma_w = 3;
LBF_sigma_c = 10;
LBF_window = 10;
LBF_depth_inteval = 50;          % Depth slice interal
LBF_iterative_number = 3;

% Fast Bilateral Solver
FBS_sigma_luma = 4;
FBS_sigma_chroma = 4;
FBS_sigma_spatial = 8;
FBS_lam = 128;
FBS_A_diag_min = 1e-5;
FBS_cg_tol = 1e-5;
FBS_cg_maxiter = 25;
%

%% Generate the kinds of depth map
SamplePoints = zeros(Height,Width);
StartPoint = Interval; % It should be set to 'Interval' for the Joint Bilateral Upsample model to work
SamplePoints(StartPoint:Interval:end,StartPoint:Interval:end) = 1;                 
% SampleDepth = SamplePoints.*double(DepthSection);
SampleDepth = double(DepthSection);
LowResDepth = DepthSection(StartPoint:Interval:end,StartPoint:Interval:end);      %Sample the low resolution Depth Map
HighResDepth = double(imresize(LowResDepth,size(DepthSection)));                  %Interpolating to the Normal size

%% Show the ground truth and input data
figure;
subplot(2,2,1);imshow(uint8(ColorSection));title('Color Image');axis off
subplot(2,2,2);imagesc(DepthSection);title('Ground Truth');axis off
subplot(2,2,3);imagesc(SampleDepth);title('Downsampled Depth Map');axis off
subplot(2,2,4);imagesc(HighResDepth);title('Upsampled Depth Map(Interpolation)');axis off
if(view_3d)
    [mu,mv] = meshgrid(1:Width,1:Height);
    figure;
    surf(mu,mv,double(DepthSection),'EdgeColor','flat');
    title('GroundTruth','Color',[1,1,1]);
    view(30,30);
    light('Posi',[1,0,1]);shading interp;axis off;set(gcf,'color',[0 0 0]);
end
%% Choose models
s = [struct('string','Bilateral Filter','run',true)
     struct('string','Bilateral Upsampling','run',false)
     struct('string','Bilateral Solver','run',true)
     struct('string','Noise-aware Filter','run',true)
     struct('string','Weight Mode Filter','run',false)
     struct('string','Anisotropic Diffusion','run',true)
     struct('string','Original Markov Random Field','run',false)
     struct('string','Markov Random Field(Second Order Smoothness)','run',true)
     struct('string','Markov Random Field(Kernel Data Term)','run',true)
     struct('string','Markov Random Field(Tensor)','run',false)
     struct('string','Layered Bilateral Filter','run',false)
    ];

%% Let us begin!
for i = 1:length(s)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%   Bilateral Filter                
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(isequal(s(i).string,'Bilateral Filter') && s(i).run)
	fprintf([s(i).string ' begin...\n'])
    tic
    if(BF_method == 1)
		Result = BilateralFilter(ColorSection,SampleDepth,...
                                        BF_sigma_w,BF_sigma_c,BF_window);
	elseif(BF_method == 2)
		Result = FastBilateralFilter(SampleDepth,double(rgb2gray(ColorSection)),...
                                        0,255,BF_sigma_w,BF_sigma_c);
	end
	fprintf([s(i).string ': total running time is %.5f s\n'],toc)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%   Bilateral Upsampling       
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% In this model, the start point of sampling must be the 'Interval'
if(isequal(s(i).string,'Bilateral Upsampling') && s(i).run)
	fprintf([s(i).string ' begin...\n'])
    tic
    Result = JointBilateralUpsample(ColorSection,DepthSection,Interval,BU_sigma_w,BU_sigma_c,BU_window);
	fprintf([s(i).string ': total running time is %.5f s\n'],toc)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%   Fast Bilateral Solver       
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(isequal(s(i).string,'Bilateral Solver') && s(i).run)
	fprintf([s(i).string ' begin...\n'])
    tic
%     r = im2double(ColorSection);
    r = ColorSection;
    grid = BilateralGrid(r, FBS_sigma_spatial,FBS_sigma_luma,FBS_sigma_chroma);
    fbs_solver = BilateralSolver(grid);
    t = double(reshape(DepthSection,[],1));
    c = double(reshape(ConfidenceSection,[], 1));
    output = fbs_solver.solve(t,c);
    Result = reshape(output, size(DepthSection));
	fprintf([s(i).string ': total running time is %.5f s\n'],toc)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%   Anisotropic Diffusion         
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(isequal(s(i).string,'Anisotropic Diffusion') && s(i).run)
	fprintf([s(i).string ' begin...\n'])
    tic
    Result = AnisotropicDiffusion(ColorSection,SampleDepth,AD_sigma);
    fprintf([s(i).string ': total running time is %.5f s\n'],toc)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%   Noise-aware Filter     
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(isequal(s(i).string,'Noise-aware Filter') && s(i).run)
	fprintf([s(i).string ' begin...\n'])
    tic
    Result = NoiseAwareFilter(ColorSection,DepthSection,Interval,BU_sigma_w,BU_sigma_c,NAU_sigma_d,BU_window);
	fprintf([s(i).string ': total running time is %.5f s\n'],toc)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%   Weight Mode Filter 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(isequal(s(i).string,'Weight Mode Filter') && s(i).run)
	fprintf([s(i).string ' begin...\n'])
    tic
    Result = WeightedModeFilter(ColorSection,SampleDepth,BF_sigma_w,BF_sigma_c,BF_window);
	fprintf([s(i).string ': total running time is %.5f s\n'],toc)
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Original MRF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(isequal(s(i).string,'Original Markov Random Field') && s(i).run)
    fprintf([s(i).string ' begin...\n'])
    tic
    if(MRF_method == 1)
        Result = MRFUpsamplingEq(ColorSection,SampleDepth,MRF_sigma,MRF_alpha);
    elseif (MRF_method == 2)
        Result = MRFUpsamplingCG(ColorSection,SampleDepth,MRF_sigma,MRF_alpha);
    elseif (MRF_method == 3)
        Result = MRFUpsamplingGC(ColorSection,SampleDepth,MRF_sigma,MRF_alpha);
    end
    fprintf([s(i).string ': total running time is %.5f s\n'],toc)
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%       Yang's Iterative Depth Refinement           
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(isequal(s(i).string,'Layered Bilateral Filter') && s(i).run)
    fprintf([s(i).string ' begin...\n'])
    tic
    Result = LayeredBilateralFilter(ColorSection,HighResDepth,LBF_sigma_w,LBF_sigma_c,LBF_window,LBF_depth_inteval,LBF_iterative_number);
    fprintf([s(i).string ': total running time is %.5f s\n'],toc)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Second Order MRF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(isequal(s(i).string,'Markov Random Field(Second Order Smoothness)') && s(i).run)
    fprintf([s(i).string ' begin...\n'])
    tic
    Result = MRFUpsamplingEqO2(ColorSection,SampleDepth,MRF_second_sigma,MRF_second_lambda1,MRF_second_lambda2);
    fprintf([s(i).string ': total running time is %.5f s\n'],toc)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Kernel Data Term MRF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(isequal(s(i).string,'Markov Random Field(Kernel Data Term)') && s(i).run)
    fprintf([s(i).string ' begin...\n'])
    tic
    Result = MRFUpsamplingEqKernelData(ColorSection,SampleDepth,MRF_kernelData_smoothSigma,MRF_kernelData_alpha,MRF_kernelData_dataSigma,MRF_kernelData_dataWindow);
    fprintf([s(i).string ': total running time is %.5f s\n'],toc)
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% MRF + Tensor; Solve a Large Sparse Linear System  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(isequal(s(i).string,'Markov Random Field(Tensor)') && s(i).run)
    fprintf([s(i).string ' begin...\n'])
    tic
    T = Tensor(ColorSection,MRF_tensor_lamda);  % Tip: the correction diag matrix in the tensor has effects on the result
    Result = MRFUpsamplingTensor(T,SampleDepth,MRF_tensor_sigma,MRF_tensor_alpha);
    fprintf([s(i).string ': total running time is %.5f s\n'],toc)
end

%% Show results
if(s(i).run)
figure;
imagesc(Result);axis off
title(s(i).string)
% imwrite(Result,['./result/' s(i).string '.png'],'png')
pfmwrite(Result, ['./result/' s(i).string '.pfm'], -1);
end
%% Quantative evaluation
if(s(i).run)
rmse = sqrt(sum(sum((double(Result(DepthSection>0)) - double(DepthSection(DepthSection>0))).^2))/sum(sum((DepthSection>0))));
fprintf(['��RMSE of <' s(i).string '> is %.5f ��\n'],rmse);
end
%% synthetic surf show
if(view_3d && s(i).run)
    figure;
    surf(mu,mv,Result);
    title(s(i).string,'Color',[1,1,1]);
    view(30,30);
    light('Posi',[1,0,1]);shading interp;axis off;set(gcf,'color',[0 0 0]);
end
end

