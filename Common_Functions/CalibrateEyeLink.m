function [] = CalibrateEyeLink(Parameters)

% Provide Eyelink with details about the graphics environment and perform some initializations.
eye = EyelinkInitDefaults(screenData.window);

% adjust some of the defaults to my setup
eye.backgroundcolour  = screenData.backgroundColor/255;
eye.foregroundcolour = screenData.backgroundColor/255;
eye.msgfontcolour = [0.8*255 0 0];
eye.imgtitlecolour = [0.8*255 0 0];
eye.calibrationtargetcolour = [0.8*255 0 0];

eye.calibrationtargetsize = 1.5;  % size of calibration target as percentage of screen
eye.calibrationtargetwidth = 0.5; % width of calibration target's border as percentage of screen

% this function is called to apply the changes from above
EyelinkUpdateDefaults(eye);

%Initialize connection, if fails exit program
if ~EyelinkInit(0)
    Eyelink('Shutdown');

    sca;
    commandwindow;
    ListenChar(0);

    error('Problem initialising the eyetracker!'); 
end
% Initialize EyeLink and perform calibration (modified from BBL code)

% CONFIGURATION COMMANDS
%-------------------------------------------------------------------------%
% SAMPLE_DATA OPTIONS
%-------------------------------------------------------------------------%
% LEFT      - sets tracking left eye
% RIGHT     - sets tracking right eye
% GAZE      - screen gaze position data
% GAZERES   - units-per-degree screen resolution at point of gaze
% HREF      - head-referenced eye position data
% HTARGET   - target distance and X/Y position (EyeLink Remote only)
% PUPIL     - raw pupil coordinates
% AREA      - pupil size diameter (diameter or area)
% BUTTON    - buttons 1-8 state and change flags
% STATUS    - warning and error flags
% INPUT     - input port data lines
%-------------------------------------------------------------------------%
% EVENT_FILTER OPTIONS
%-------------------------------------------------------------------------%
% LEFT      - sets tracking left eye
% RIGHT     - sets tracking right eye
% FIXATION  - fixation start and end events
% FIXUPDATE - fixation (pursuit) state update events
% SACCADE   - saccade start and end events
% BLINK     - blink start and end events
% MESSAGE   - messages (ALWAYS use)
% BUTTON    - buttons 1-8 press or release events
% INPUT     - changes in input port lines
%-------------------------------------------------------------------------%
% configure EDF data file contents
%tracking just one eye RIGHT here
% configure EDF data file contents
% configure EDF data file contents
Eyelink('Command', 'file_sample_data = LEFT, GAZE, GAZERES, DIAMETER, PUPIL, HREF, BUTTON, STATUS, INPUT');
Eyelink('Command', 'file_event_filter = LEFT, FIXATION, SACCADE, BLINK, MESSAGE, BUTTON, INPUT');
% configure link data (used for gaze cursor, optional)
Eyelink('Command', 'link_sample_data = LEFT, GAZE, GAZERES, DIAMETER, PUPIL, STATUS');
Eyelink('Command', 'link_event_filter = LEFT, FIXATION, SACCADE, BLINK, MESSAGE, BUTTON, INPUT');
%position on screen (GAZE), expressed in pixels 
%https://www.fieldtriptoolbox.org/getting_started/eyelink/

% configure sampling rate in Hz (250 vs. 500 vs. 1000 vs 2000)
Eyelink('Command', 'sample_rate = %d', 2000);
% configure tracking model (no=centroid, yes=ellipse)
Eyelink('Command', 'use_ellipse_fitter = yes');
% configure illumination power (1=100%, 2=75%, 3=50%)
Eyelink('Command', 'elcl_tt_power = %d', 3);
% configure pupil size data measure (AREA vs. DIAMETER)
Eyelink('Command', 'pupil_size_diameter = AREA');

% pixel
commandStr = sprintf('screen_pixel_coords = 0 0 %d %d', Parameters.screenXpixels-1, Parameters.screenYpixels-1);
disp(commandStr);
Eyelink('Command', commandStr);

% Calibrate the eye tracker
Eyelink('Command', 'calibration_type = HV9'); % Ensure 9-point calibration

% Do setup and calibrate the eye tracker
EyelinkDoTrackerSetup(eye);

% do a final check of calibration using driftcorrection
% You have to hit esc before return.
EyelinkDoDriftCorrection(eye);

% Eyelink('StartRecording');

end