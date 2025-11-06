function [Session, Sess_name] = CurrentSession(Base_name, SubjPath)
% Returns the number and name of the current session to avoid overwriting
% already acquired runs by checking the results folder

Session = 1;
Sess_name = [Base_name num2str(Session)]; % File names in format: SubjID_Bars_SessionX.mat

while exist([SubjPath filesep Sess_name '.mat']) % We look at all the saved files in the subject folder
    Session = Session + 1;                       % To find which current session (run) we are in
    Sess_name = [Base_name num2str(Session)];
end

disp(['Running session: ' Sess_name]); disp(' ');