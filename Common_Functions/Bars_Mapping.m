function Bars_Mapping(Parameters, Emulate, SaveAps, SubjPath)
% Runs the drifting bar protocol for mapping population receptive fields.

%% Initialize randomness & keycodes
SetupRand; % Set up the randomizers for uniform and normal distributions. 
SetupKeyCodes;

%% Behavioural data
Behaviour = struct;
Behaviour.EventTime = []; % timestamps when color changes (events) occur
Behaviour.Response = []; % the subject’s response (e.g., key press)
Behaviour.ResponseTime = []; % timestamps of response after event
KeyTime = -Inf;   % First key press was before the Big Bang

%% Event timings 
Events = [];
%Color changes occur randomly every every 200 ms with a probability of 0.01
for e = Parameters.TR : Parameters.Event_Duration : (length(Parameters.Conditions) * Parameters.Volumes_per_Trial * Parameters.TR)
    if rand < Parameters.Prob_of_Event
        Events = [Events; e];
    end
end
% Add a dummy event at the end of the Universe
Events = [Events; Inf];

%% Configure events
if ~isfield(Parameters, 'Event_Colour')
    Parameters.Event_Colour = [127 0 255; 0 0 255]; %color change to purple
end

%% Configure scanner 
if Emulate 
    % Emulate scanner
    TrigStr = 'Appuyez sur un bouton pour commencer...';    % Trigger string
    %TrigStr = 'Press key to start...';    % Trigger string
else
    % Real scanner
    TrigStr = 'Le scan va commencer...';    % Trigger string
    %TrigStr = 'Stand by for scan...';    % Trigger string
end

%% Initialize PTB
if ~isfield(Parameters, 'Gamma') %luminance correction of the display
    Parameters.Gamma = 1; % If gamma undefined, we don't use correction
end

%Gamma correction
PsychImaging('PrepareConfiguration'); %starts the setup for PsychImaging
PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'SimpleGamma'); % gamma-corrected display  

%Open display window
[Win, Rect] = PsychImaging('OpenWindow', Parameters.Screen, Parameters.Background, Parameters.Resolution, 32); 

%Apply gamma correction
PsychColorCorrection('SetEncodingGamma', Win, Parameters.Gamma); % Apply desired gamma correction
disp(['Applying gamma correction = ' n2s(Parameters.Gamma)]);

%Set font and blending (transparent graphics)
Screen('TextFont', Win, Parameters.FontName);
Screen('TextSize', Win, Parameters.FontSize);
Screen('BlendFunction', Win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
HideCursor;

%Manage timing considering screen refresh rate
RefreshDur = Screen('GetFlipInterval',Win);
Frames_per_Sec = 1 / RefreshDur;
Slack = RefreshDur / 2;

%% Initialize Eyelink eyetracker 
if Parameters.Eye_tracker 
    %Initialize connection
    if Eyelink('Initialize') ~= 0	
        error('Problem initialising the eyetracker!'); 
    end

    %Set default parameters
    Eye_params = EyelinkInitDefaults(Win);

    %Save Eyelink data to
    EyetrackingFile = [SubjPath filesep 'EL' num2str(Parameters.Session) '.edf'];
    Eyelink('Openfile', EyetrackingFile);  % Open a file on the eyetracker

    %Starts recording and check status
    Eyelink('StartRecording');  % Start recording to the file
    Eye_error = Eyelink('CheckRecording');

    %Identify which eye is tracked
    if Eyelink('NewFloatSampleAvailable') > 0
        Eye_used = Eyelink('EyeAvailable'); % Get eye that's tracked
        if Eye_used == Eye_params.BINOCULAR 
            % If both eyes are tracked use left
            Eye_used = Eye_params.LEFT_EYE;         
        end
    end
end

%% Initialize various variables
Results = [];

% Spiderweb overlay coordinates
[Ix Iy] = pol2cart([0:30:330]/180*pi, Parameters.Fixation_Width(1));
[Ox Oy] = pol2cart([0:30:330]/180*pi, Rect(3)/2);
Rc = Rect(3) - Parameters.Fixation_Width(2); %concentric rings radii
Sc = round(Rc / 10);
Wc = Parameters.Fixation_Width(2) : Sc : Rect(3);
Wa = round(Parameters.Spider_Web * 255); %spideweb alpha

% Is the image being scaled?
if isfield(Parameters, 'Image_Length') % Image_Length: rectangle defining stimulus size in pixels
    FrameRect = [0 0 repmat(Parameters.Image_Length, 1, 2)]; %If Parameters.Image_Length exists → use that size
else
    FrameRect = [0 0 repmat(Rect(4), 1, 2)]; %else default full screen
end

% Is the image shifted from centre?
if ~isfield(Parameters, 'Image_Position')
    Parameters.Image_Position = [0 0]; %If not specified, screen center is [0, 0]
end

% Is the fixation shifted from centre?
if ~isfield(Parameters, 'Fixation_Position')
    Parameters.Fixation_Position = [0 0]; %If not specified, fixation cross is centered [0, 0]
end

% Invert vertical positions because Psychtoolbox from Y-down to Y-up (positive upward).
Parameters.Image_Position(2) = -Parameters.Image_Position(2);
Parameters.Fixation_Position(2) = -Parameters.Fixation_Position(2);

% Load background movie (stimulus frames)
StimRect = [0 0 repmat(size(Parameters.Stimulus,1), 1, 2)]; %one single frame of the movie
BgdTextures = [];

if length(size(Parameters.Stimulus)) < 4 %If movie in format rows x cols x frames
    for f = 1:size(Parameters.Stimulus, 3) % It loops over frames and preloads them to prepare for smooth playback
        BgdTextures(f) = Screen('MakeTexture', Win, Parameters.Stimulus(:,:,f));
    end
else %If movie in format rows x cols x color_channels x frames
    for f = 1:size(Parameters.Stimulus, 4)
        BgdTextures(f) = Screen('MakeTexture', Win, Parameters.Stimulus(:,:,:,f));
    end
end

%% Background variables
CurrFrame = 0; %Current frame of the texture
CurrStim = 1; %Current condition (e.g. 0, 45, ... degrees)
Drift_per_Vol = StimRect(3) / Parameters.Volumes_per_Trial; %How much the bar moves per TR
BarPos = [0 : Drift_per_Vol : StimRect(3)-Drift_per_Vol] + Drift_per_Vol/2; % Pixel position of the bar

%% Initialize circular Aperture
CircAperture = Screen('MakeTexture', Win, 127 * ones(StimRect([3 3]))); % circular aperture mask

%Do we save a movie of the stimulus or not
if SaveAps
    if abs(SaveAps) == 1 % If SaveAps is 1 it saves the aperture for each volume.
        ApFrm = zeros(100, 100, Parameters.Volumes_per_Trial * length(Parameters.Conditions));
    elseif SaveAps == 2 % If it is 2 it saves a frame of the actual stimulus movie. 
        ApFrm = zeros(270, 480, 3);
        sf = 0;
    end
    SavWin = Screen('MakeTexture', Win, 127 * ones(StimRect([3 3])));
end

%% MRI scanner triggers

% If we are scanning, define MRI triggers to know when each volume is acquired 
if Emulate == 0
    SetupTrigger;
end

%% Standby screen

%Welcome screen with instructions
Screen('FillRect', Win, Parameters.Background, Rect); %Screen filled with background gray
DrawFormattedText(Win, [Parameters.Welcome '\n \n' Parameters.Instruction '\n \n' TrigStr], 'center', 'center', Parameters.Foreground); %Welcome and instructions text
Screen('Flip', Win); %Shows the text

%Same message is printed in console
disp('***************************************************************************************');
disp(strrep([Parameters.Welcome '\n' Parameters.Instruction '\n' TrigStr], '\n', newline));
disp(' ');

%Wait for the start
if Emulate %Wait for keypress if in debug
    WaitSecs(0.1);
    KbWait; % Wait for any keypress
    [bkp bkt bk] = KbCheck;  %Returns which key, timestamp       
else %Otherwise wait on the scanner TTL pulse (trigger)
    TriggerExperiment;
    bk = zeros(1,256);
end
Start_of_Expmt = GetSecs; %records the start time of the experiment

if bk(KeyCodes.Escape) % Abort if Escape is pressed during standby phase
   
    % Abort screen with abort message
    Screen('FillRect', Win, Parameters.Background, Rect); 
    DrawFormattedText(Win, 'Experiment was aborted!', 'center', 'center', Parameters.Foreground); 
    Screen('Flip', Win);
    WaitSecs(0.5);

    %Restore system 
    ShowCursor;
    Screen('CloseAll');

    %Log message
    disp(' ');
    disp('Experiment aborted by user!'); 
    disp(' ');

    % Experiment duration
    End_of_Expmt = GetSecs;
    disp(' ');
    ExpmtDur = End_of_Expmt - Start_of_Expmt;
    ExpmtDurMin = floor(ExpmtDur/60);
    ExpmtDurSec = mod(ExpmtDur, 60);
    disp(['Experiment lasted ' n2s(ExpmtDurMin) ' minutes, ' n2s(ExpmtDurSec) ' seconds']);
    disp(' ');

    %If in MRI mode, we might need to close connection to scanner's trigger
    if Emulate == 0
        CleanUpTrigger;
    end

    % Shutdown eye tracker if used
    if Parameters.Eye_tracker
        Eyelink('StopRecording');
        Eyelink('CloseFile');
        Eyelink('ShutDown');
    end

    assignin('base', 'ESCAPE_ABORT', true); %Used to exit the main loop and properly exit the script

    return %Exit script
end

%% Dummy volumes (done pre-scan to allow the scanner to reach steady-state)

%Some images are acquired with just background colour and spiderweb
Screen('FillRect', CircAperture, Parameters.Background); 

% Draw overlay spiderweb if alpha is not zero
if Wa > 0 
    for s = 1:length(Ix)
        Screen('DrawLines', Win, [[Ix(s);Iy(s)] [Ox(s);Oy(s)]], 1, [0 0 0 Wa], Rect(3:4)/2);
    end
    for s = Wc
        Screen('FrameOval', Win, [0 0 0 Wa], CenterRect([0 0 s s], Rect));
    end
end

% Draw fixation dot
Screen('FillOval', Win, Parameters.Event_Colour(2,:), CenterRect([0 0 Parameters.Fixation_Width(1) Parameters.Fixation_Width(1)], Rect));
Screen('Flip', Win);

%Wait for dummy scans
WaitSecs(Parameters.Dummies * Parameters.TR);
Start_of_Expmt = GetSecs;

%% Behaviour structure
Behaviour.EventTime = Events; %list of precomputed event timings when color changes will occur
k = 0;  % Toggle this when key was pressed recently

%% Run stimulus sequence (Main loop)
for Trial = 1 : length(Parameters.Conditions) %For each sweep (orientation, condition)
    
    % Trial setup
    TrialOutput = struct;
    TrialOutput.TrialOnset = GetSecs; %Trial start timestamp
    TrialOutput.TrialOffset = NaN; 

    %If using Eyetracker, this will store gaze data
    if Parameters.Eye_tracker
        TrialOutput.Eye = [];
    end
    
    if Emulate == false
        %Send a trigger to eyelink at the beggining of every sweep
        outp(Parameters.Scanner_Trigger_Address, 16);
    end

    %% Stimulation sequence

    %Condition setup
    CurrCondit = Parameters.Conditions(Trial); %Which orientation
    disp(' '); disp([Trial CurrCondit]); %Logs condition in console
    CurrVolume = 1; PrevVolume = 0; %Used to track acquired volumes

    if Emulate == false
        %Close trigger eyelink
        outp(Parameters.Scanner_Trigger_Address, 0);
    end

    %Each sweep we acquire 25 volumes (one volume per step)
    while CurrVolume <= Parameters.Volumes_per_Trial  

        % Determine which frame to show
        CurrFrame = CurrFrame + 1;
        if CurrFrame > Parameters.Refreshs_per_Stim 
            CurrFrame = 1;
            CurrStim = CurrStim + 1;
        end

        %When all frames are shown, it loops back to the start
        if CurrStim > size(Parameters.Stimulus, length(size(Parameters.Stimulus)))
            CurrStim = 1;
        end

        % Create Aperture mask
        Screen('FillRect', CircAperture, [Parameters.Background 0]);    
        if isnan(CurrCondit) %If we are not in a valid condition: background
            Screen('FillRect', CircAperture, Parameters.Background);    
        else %If we are in a normal condition, get bar position
            BarRect = [0 0 BarPos(CurrVolume)-Parameters.Bar_Width/2 StimRect(4)];
            BarRect(BarRect <= 0) = 1;
            Screen('FillRect', CircAperture, Parameters.Background, BarRect); 
            BarRect = [BarPos(CurrVolume)+Parameters.Bar_Width/2 0 StimRect(3) StimRect(4)];
            BarRect(BarRect >= StimRect(3)) = StimRect(3);
            Screen('FillRect', CircAperture, Parameters.Background, BarRect); 
        end

        % Rotate background spiderweb (by default we don't but can update Sine_Rotation)
        BgdAngle = cos((GetSecs-TrialOutput.TrialOnset)/Parameters.TR * 2*pi) * Parameters.Sine_Rotation;

        % Draw stimulus frame (Texture) and mask (aperture)
        Screen('DrawTexture', Win, BgdTextures(CurrStim), StimRect, CenterRect(FrameRect, Rect) + [Parameters.Image_Position Parameters.Image_Position], BgdAngle+CurrCondit-90);
        Screen('DrawTexture', Win, CircAperture, StimRect, CenterRect(FrameRect, Rect) + [Parameters.Image_Position Parameters.Image_Position], CurrCondit-90);  
       
        %Computes when is the next event
        CurrEvents = (GetSecs - Start_of_Expmt) - Events; 

        % Draw hole around fixation
        Screen('FillOval', Win, Parameters.Background, CenterRect([0 0 Parameters.Fixation_Width(2) Parameters.Fixation_Width(2)], Rect) + [Parameters.Fixation_Position Parameters.Fixation_Position]);    

        % If saving movie
        if abs(SaveAps) == 1 && PrevVolume ~= CurrVolume
            PrevVolume = CurrVolume;
            CurApImg = Screen('GetImage', Win, [], 'backbuffer');     
            CurApImg = rgb2gray(CurApImg);
            CurApImg = double(abs(double(CurApImg)-127)>1);
            if SaveAps == 1
                % Save square aperture
                Fxy = round(CenterRect(FrameRect, Rect) + [Parameters.Image_Position Parameters.Image_Position]);
                Fxy(Fxy <= 0) = 1;
                if Fxy(3) > Rect(3)
                    Fxy(3) = Rect(3);
                end
                if Fxy(4) > Rect(4)
                    Fxy(4) = Rect(4);
                end
                CurApImg = CurApImg(Fxy(2):Fxy(4), Fxy(1):Fxy(3));
                CurApImg = imresize(CurApImg, [100 100]);
            elseif SaveAps == -1
                % Embed rectangular full screen window in square aperture
                CurApImg = imresize(CurApImg, 100/Rect(3)); % Width is 100
                Padding = (100-size(CurApImg,1))/2; % Pixels needed for padding
                CurApImg = [zeros(floor(Padding),100); CurApImg; zeros(ceil(Padding),100)];
            end
            ApFrm(:,:,Parameters.Volumes_per_Trial*(Trial-1)+CurrVolume) = CurApImg;
        elseif SaveAps == 2
            CurApImg = Screen('GetImage', Win, [], 'backbuffer');     
            CurApImg = imresize(CurApImg, [270 480]);
            sf = sf + 1;
            ApFrm(:,:,:,sf) = CurApImg; %Stimulus movie is stored there
        end



        %  Handles fixation dot color changes
        if sum(CurrEvents > 0 & CurrEvents < Parameters.Event_Duration) % When there is an event
            %Fixation dot changes color to pink
            Screen('FillOval', Win, Parameters.Event_Colour(1,:), CenterRect([0 0 Parameters.Fixation_Width(1) Parameters.Fixation_Width(1)], Rect) + [Parameters.Fixation_Position Parameters.Fixation_Position]);
        else %When there is no event
            %Fixation dot has baseline color
            Screen('FillOval', Win, Parameters.Event_Colour(2,:), CenterRect([0 0 Parameters.Fixation_Width(1) Parameters.Fixation_Width(1)], Rect) + [Parameters.Fixation_Position Parameters.Fixation_Position]);    
        end

        % Check whether the refractory period of key press has passed
        if k ~= 0 && GetSecs-KeyTime >= 2*Parameters.Event_Duration %Prevents double counting during the same event
            k = 0;
        end

        % Draw overlay spiderweb
        if Wa > 0
            for s = 1:length(Ix)
                Screen('DrawLines', Win, [[Ix(s);Iy(s)] [Ox(s);Oy(s)]] + [Parameters.Fixation_Position' Parameters.Fixation_Position'], 1, [0 0 0 Wa], Rect(3:4)/2);
            end
            for s = Wc
                Screen('FrameOval', Win, [0 0 0 Wa], CenterRect([0 0 s s], Rect) + [Parameters.Fixation_Position Parameters.Fixation_Position]);
            end
        end
        Screen('Flip', Win); % Update screen

        % Behavioural response (Button press in response to color change)
        if k == 0  % When we are not in a refractory period
            [Keypr KeyTime Key] = KbCheck;

            if Keypr % When a key is pressed
                if Key(KeyCodes.One)==1
                    k = 1; % Starts a refractory period of 2 x Event_Duration
                    Behaviour.Response = [Behaviour.Response; find(Key,1)]; %We store key 
                    Behaviour.ResponseTime = [Behaviour.ResponseTime; KeyTime - Start_of_Expmt]; % We store RT
                end
            end
        end
        TrialOutput.Key = Key; %Stores which key was pressed 

        % Abort if Escape was pressed during trial
        if find(TrialOutput.Key) == KeyCodes.Escape
            % Abort screen
            Screen('FillRect', Win, Parameters.Background, Rect);
            DrawFormattedText(Win, 'Experiment was aborted mid-block!', 'center', 'center', Parameters.Foreground); 
            WaitSecs(0.5);

            %Restore system
            ShowCursor;
            Screen('CloseAll');
            disp(' ');

            %Display log message
            disp('Experiment aborted by user mid-block!'); 
            disp(' ');

            % Experiment duration
            End_of_Expmt = GetSecs;
            disp(' ');
            ExpmtDur = End_of_Expmt - Start_of_Expmt;
            ExpmtDurMin = floor(ExpmtDur/60);
            ExpmtDurSec = mod(ExpmtDur, 60);
            disp(['Experiment lasted ' n2s(ExpmtDurMin) ' minutes, ' n2s(ExpmtDurSec) ' seconds']);
            disp(' ');

            %If in MRI mode, we might need to close connection to scanner's trigger
            if Emulate == 0
                CleanUpTrigger;
            end

            % Shutdown eye tracker if used
            if Parameters.Eye_tracker
                Eyelink('StopRecording');
                Eyelink('CloseFile');
                Eyelink('ShutDown');
            end

            assignin('base', 'ESCAPE_ABORT', true); %Used to exit the main loop and properly exit the script

            return %quit the script
        end
    
        % Determine current volume to synchronize visual stimulus with fMRI
        CurrVolume = floor((GetSecs-TrialOutput.TrialOnset-Slack) / Parameters.TR) + 1;

        % Record eye data
        if Parameters.Eye_tracker %If we use the eyetracker
            if Eyelink( 'NewFloatSampleAvailable') > 0 %Check if a new sample is available
                Eye = Eyelink( 'NewestFloatSample');
                ex = Eye.gx(Eye_used+1); % If so extract gaze coordinates 
                ey = Eye.gy(Eye_used+1);
                ep = Eye.pa(Eye_used+1);

                % Store if data is valid 
                if ex ~= Eye_params.MISSING_DATA && ey ~= Eye_params.MISSING_DATA && ep > 0
                    TrialOutput.Eye = [TrialOutput.Eye; GetSecs-TrialOutput.TrialOnset ex ey ep];
                end
            end
        end
    end
    
    % Trial end time (Sweep is over)
    TrialOutput.TrialOffset = GetSecs;

    % Record trial results   
    Results = [Results; TrialOutput];
end

% All trials are over, get experiment duration
End_of_Expmt = GetSecs;

%% Save results of current block
Parameters = rmfield(Parameters, 'Stimulus');  %We ignore the stimulus field because it is very heavy

%Display a saving in progress screen 
Screen('FillRect', Win, Parameters.Background, Rect);
DrawFormattedText(Win, 'Sauvegarde des données en cours...', 'center', 'center', Parameters.Foreground); 
Screen('Flip', Win);

%Saves all workspace variables in a .mat file
save([SubjPath filesep Parameters.Session_name]);

%% Shut down processes

%Shut down trigger of the scanner
if Emulate == 0
    CleanUpTrigger;
end

% Shutdown eye tracker if used
if Parameters.Eye_tracker
    Eyelink('StopRecording');
    Eyelink('CloseFile');
    Eyelink('ShutDown');
end

%% Display Farewell screen
Screen('FillRect', Win, Parameters.Background, Rect);
DrawFormattedText(Win, 'Merci pour ta participation :) !', 'center', 'center', Parameters.Foreground); 
Screen('Flip', Win);
WaitSecs(Parameters.TR * Parameters.Overrun);
ShowCursor;
Screen('CloseAll');

%% Experiment duration

%Compute total duration in minutes
disp(' ');
ExpmtDur = End_of_Expmt - Start_of_Expmt;
ExpmtDurMin = floor(ExpmtDur/60);
ExpmtDurSec = mod(ExpmtDur, 60);

%Display logs
disp(['Experiment lasted ' n2s(ExpmtDurMin) ' minutes, ' n2s(ExpmtDurSec) ' seconds']);
disp(['There were ' n2s(length(Behaviour.EventTime)-1) ' dimming events.']);
disp(['There were ' n2s(length(Behaviour.ResponseTime)) ' button presses.']);
disp(' ');

%% Save stimulus movie
if SaveAps == 2
    ApFrm = uint8(ApFrm);
    save([SubjPath filesep Parameters.Session_name '_stimulus'], 'ApFrm');
end
