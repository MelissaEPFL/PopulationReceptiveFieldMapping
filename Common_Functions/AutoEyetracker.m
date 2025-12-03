% Original code from BBL
% Minimally modified by Melissa

function AutoEyetracker()
Screen('Preference', 'SkipSyncTests', 1);
subID = input('Enter participant ID (NUMBER ONLY!!): '); %Has to be a number

% total size of name cannotq
% exceed 12 characters (counting the file extension)
eyeFile_name = ['s'  num2str(subID,'%02.f') '_cal.edf'];

% initialize screen
screenData.backgroundColor = [127 127 127];
screenData = init_screen(screenData);

% initialize eyelink and calibrate
init_EyeLink(screenData, eyeFile_name);

% close screen
close_screen(screenData);

% wait till experiment is over (determined by experimenter) before closing
% eyelink
KbName('UnifyKeyNames');

inputOk = 1;
while inputOk
    % checking operator key presses
    [~, ~, keyCode] = KbCheck();
    
    if keyCode(KbName('q'))
        inputOk = 0;
    end
end

% close eyelink
close_EyeLink(eyeFile_name);

end


function [] = init_EyeLink(screenData, eyeFile_name)

% Provide Eyelink with details about the graphics environment
% and perform some initializations. The information is returned
% in a structure that also contains useful defaults
% and control codes (e.g. tracker state bit and Eyelink key values).
eye = EyelinkInitDefaults(screenData.window);

% adjust some of the defaults to my setup
eye.backgroundcolour  = screenData.backgroundColor/255;
eye.backgroundColor  = screenData.backgroundColor/255;

eye.foregroundcolour = screenData.backgroundColor/255;
eye.foregroundColor = screenData.backgroundColor/255;

eye.msgfontcolour = [0.8*255 0 0];
eye.imgtitlecolour = [0.8*255 0 0];
eye.calibrationtargetcolour = [0.8*255 0 0];

eye.calibrationtargetsize = 1.5;  % size of calibration target as percentage of screen
eye.calibrationtargetwidth = 0.5; % width of calibration target's border as percentage of screen

% you must call this function to apply the changes from above
EyelinkUpdateDefaults(eye);

% Initialization of the connection with the Eyelink Gazetracker.
% exit program if this fails.
if ~EyelinkInit(0)
    fprintf('Eyelink Init aborted.\n');
    Eyelink('Shutdown');
    
    % Close window:
    sca;
    commandwindow;
    
    % Restore keyboard output to Matlab:
    ListenChar(0);
    return;
end


% set EDF file contents using the file_sample_data and
% file-event_filter commands

% LEFT, RIGHT       Sets the intended tracking eye (usually include both LEFT and?RIGHT)
% GAZE              includes screen gaze position data
% GAZERES           includes units-per-degree screen resolution at point of gaze
% HREF              head-referenced eye position data
% HTARGET           target distance and X/Y position (EyeLink Remote only)
% PUPIL             raw pupil coordinates

% AREA              pupil size data (diameter or area)
% BUTTON            buttons 1-8 state and change flags
% STATUS            warning and error flags
% INPUT             input port data lines
Eyelink('command', 'file_sample_data  = RIGHT, GAZE, GAZERES, AREA, PUPIL'); % data that is saved line by line
Eyelink('command', 'file_event_filter = RIGHT, FIXATION, BLINK, SACCADE, VELOCITY, MESSAGE'); % data that is saved as events


% open file for recording data 
Eyelink('Openfile', eyeFile_name);
Eyelink('command', 'add_file_preamble_text ''Recorded by SNAKE''');

% Do setup and calibrate the eye tracker
EyelinkDoTrackerSetup(eye);

% do a final check of calibration using driftcorrection
% You have to hit esc before return.
EyelinkDoDriftCorrection(eye);

Eyelink('StartRecording');

end


function [] = close_EyeLink(eyeFile_name)
% finish up: stop recording eye-movements,
% close graphics window, close data file and shut down tracker
Eyelink('StopRecording');
Eyelink('CloseFile');

% download data file
try
    fprintf('Receiving data file ''%s''\n', eyeFile_name);
    status=Eyelink('ReceiveFile');
    if status > 0
        fprintf('ReceiveFile status %d\n', status);
    end
    if 2 == exist(eyeFile_name, 'file')
        fprintf('Data file ''%s'' can be found in ''%s''\n', eyeFile_name, pwd);
    end
catch rdf
    fprintf('Problem receiving data file ''%s''\n', eyeFile_name);
    rdf;
end

% Shutdown Eyelink:
Eyelink('Shutdown');
end



function screenData = init_screen(screenData)

screens_ID = Screen('Screens');
screenData.screenNumber = 2;%mean(screens_ID);

screenData.oldRes = SetResolution(screenData.screenNumber, 1920,  1080, 60);
screenData.oldLevel = Screen('Preference', 'VisualDebugLevel',3);

PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
screenData.window = PsychImaging('OpenWindow', screenData.screenNumber, screenData.backgroundColor);
Screen('ColorRange', screenData.window, 1);
Screen(screenData.window,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

HideCursor;
end

function [] = close_screen(screenData)
ShowCursor;
Screen('CloseAll')
SetResolution(screenData.screenNumber, screenData.oldRes); %set monitor's previous resolution again
Screen('Preference', 'VisualDebugLevel', screenData.oldLevel); %so that PsychToolbox Initialzation Message will appear next time
end
