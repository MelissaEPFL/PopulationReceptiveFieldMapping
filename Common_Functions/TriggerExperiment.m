%% Wait on first scanner trigger to start

% BBL setup (Windows, PsychToolBox, parallel port)

disp('Waiting for first scanner trigger (TTL)...');

% Wait for rising edge on input line
prev = io32(io32, Parameters.Scanner_Trigger_Address);

while true
    val = io32(io32, Parameters.Scanner_Trigger_Address);

    if bitand(val, Parameters.Scanner_Trigger_Bit) && ~bitand(prev, Parameters.Scanner_Trigger_Bit)

        disp('Scanner trigger received!');
        break;
    end
    prev = val;
    WaitSecs(0.001); %1 ms polling interval
end