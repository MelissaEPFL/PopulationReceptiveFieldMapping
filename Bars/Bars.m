 function Bars(Subject_ID, EyeTracking, Emulation, SubjPath)
% Retinotopic (pRF) mapping using a traversing bar stimulus. 
%
% Input arguments:
%   Subject_ID :    String with subject ID
%   EyeTracking :   Eye tracking (true or false)? (Requires EyeLink setup)
%   Emulation :     Emulate trigger (true or false)? 
%

addpath('..\Common_Functions');
Stim = 'Ripples'; % Use ripple stimulus
%Stim = 'Checkerboard'; % Use checkerboard stimulus
Parameters = struct;    % Initialize the parameters variable

%% Engine & Screen parameters
Parameters.Screen = 0;    % Main screen
Parameters.Resolution = [0 0 1920 1080];   % Resolution
Parameters.Foreground = [0 0 0];  % Foreground colour
Parameters.Background = [127 127 127];    % Background colour
Parameters.FontSize = 30;   % Size of font
Parameters.FontName = 'Arial';  % Font to use
 
%% Scanner parameters
Parameters.TR = 1;   % Seconds per volume
if Emulation
    Parameters.Dummies = 0;   % No dummy volumes
else
    Parameters.Dummies = 10;   % Dummy volumes (the scanner takes time to reach baseline functioning)
end
Parameters.Overrun = 0;   % Dummy volumes at the end
Parameters.Eye_tracker = EyeTracking; % Using eye tracker?

%% Subject & session 
Parameters.Subj_ID = Subject_ID;   % Subject ID
[Parameters.Session, Parameters.Session_name] = CurrentSession([Parameters.Subj_ID '_Run'], SubjPath);   % Determines which is the current run by looking at files names

Parameters.Welcome = 'Veuillez fixer le point bleu en permanence.';   % Welcome message
Parameters.Instruction = 'Veuillez appuyer sur le bouton lorsqueil change de couleur.';  % Instruction message
%Parameters.Welcome = 'Please fixate the blue dot at all times!';   % Welcome message
%Parameters.Instruction = 'Please press a button when it changes colour!';  % Instruction message

%% Experimental stimulus Parameters
Parameters.Volumes_per_Trial = 25;  % Duration of trial (sweep) in volumes (of duration TR)
Parameters.Bar_Width = 60; % Width of bar in pixels
Parameters.Fringe = 12; % Width of ramped fringe of bar in pixels
Parameters.Conditions = [0 45 90 135 NaN 180 225 270 315 NaN];  % Bar orientation in each sweep 
Parameters.Prob_of_Event = 0.01;  % Probability of a target event (color change fixation cross)
Parameters.Event_Duration = 0.2;  % Duration of a target event
Parameters.Fixation_Width = [10 50];    % Width of fixation spot/surrounding gap in pixels
Parameters.Spider_Web = 0.1;  % Spider web in the background

%% Load stimulus movie
load(Stim); % Contains Stimulus (W x H x T) and StimFrames 2
Parameters.Stimulus = Stimulus; % Stimulus movie
Parameters.Refreshs_per_Stim = StimFrames;  % Video frames per stimulus frame (depends refresh rate) by default is 2
Parameters.Sine_Rotation = 0;  % Rotating movie back & forth by this angle

SaveAps = 1;
% If SaveAps is 1 it saves the aperture for each volume.
% If it is 2 it saves a frame of the actual stimulus movie. 
% If it is 0 (default) it doesn't save anything. 

%% Run the experiment
Bars_Mapping(Parameters, Emulation, SaveAps, SubjPath);
