%% Any functions you may need to set up the scanner TTL trigger    

% BBL setup (Windows, PsychToolBox, parallel port)

Parameters.Scanner_Trigger_Address = "4FF8";   % Standard LPT1 base address (0x378)
Parameters.Scanner_Trigger_Bit = 1;            % Bit corresponding to the TTL input 

try
    config_io; % Load Psychtoolbox I/O functions
catch
    error('Could not initialize parallel port I/O');
end
