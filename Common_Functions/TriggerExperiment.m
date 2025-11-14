%% Wait on first scanner trigger to start

% BBL setup (Windows, PsychToolBox, parallel port)

disp('Waiting for first scanner trigger (TTL)...');

% Wait for rising edge on input line
while true

    [keyIsDown,secs,keyCode] = KbCheck;

    if keyCode(KeyCodes.Five)==1 %In BBL the scanner pulse is detected as keypress 5
        disp('Scanner trigger received!');
        break;
    end

    %1 ms polling interval
    WaitSecs(0.001); 
end