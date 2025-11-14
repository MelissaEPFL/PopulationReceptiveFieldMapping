%% Any functions you may need to set up the scanner TTL trigger    

% BBL setup (Windows, PsychToolBox, parallel port)

Parameters.Scanner_Trigger_Address = hex2dec("4FD8");   % Standard LPT1 base address (0x378)

try
    config_io; % Load Psychtoolbox I/O functions
catch
    error('Could not initialize parallel port I/O');
end

outp(Parameters.Scanner_Trigger_Address, 0);
