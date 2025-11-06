%% pRF Mapping
% This script allows to acquire population receptive field (pRF) mapping data and is based on 
% Sam Schwarzkopf's stimulus code (in files preview go to “Stimulus Presentation Code”): 
% Schwarzkopf, D. (2025, October 9). SamSrf X - Matlab toolbox for pRF & CF analysis. https://doi.org/10.17605/OSF.IO/2RGSM
% Modified by Melissa Faggella

% Requires Psychtoolbox 3

clear all; clc;

%% Input info

% Ask experimenter basic info
info = inputdlg({'Subject ID','N runs'});  
[Subject, NRuns] = info{[1,2]};  
NRuns = str2num(NRuns);

EyeTracking = false; %Use eyetracking ?
Emulation = true; %Emulate scanner trigger ?

%Define and if required create SaveFolder
SavePath = 'L:\Experimental Data\Melissa Faggella\4_fMRI_EEG_Forward_modelling\Results';
SubjPath = [SavePath filesep Subject];
if ~exist(SubjPath, 'dir')
    mkdir(SubjPath);           
end

%% pRF mapping runs

for run = 1:NRuns
    
    Bars(Subject, EyeTracking, Emulation, SubjPath);

    %MRI operator-supervised pause: press key to continue
    % if run < NRuns 
    %     disp(['OPERATOR MUST PRESS ANY KEY TO PROCEED - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -']);
    %     KbWait; % Wait for any keypress 
    % end
end


