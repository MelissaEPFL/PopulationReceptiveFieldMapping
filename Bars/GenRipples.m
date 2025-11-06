addpath('..\Common_Functions');

%Setup
width = 1072;  % Height of the screen 
fringe = 12;  % Width of the ramped fringe
width = width - fringe;
Phases = 0:5:355; %Ripple movie is composed of 72 different images with ripples shifted in phase (0, 5,10 degrees...)

%Create 3D array to store the movie
Stimulus = zeros(width, width, length(Phases));
[X Y] = meshgrid([-width/2:-1 1:width/2], [-width/2:-1 1:width/2]); %Builds square grid, odd/even numbr of pixel handled
[T R] = cart2pol(X,Y); %Converts to polar coordinates

%Create circular aperture with smooth edge in which the ripples live
circap = ones(width, width);
circap(R > width/2-fringe) = 1;
alphas = linspace(1, 0, fringe);

for f = 1:fringe
    circap(R > width/2-fringe+f) = alphas(f);
end
circap(R > width/2) = 0;

%Generate ripple pattern
f = 1;
for pha = Phases 
    %PrettyPattern generates one ripples frame per phase
    img = double(PrettyPattern(sin(pha/180*pi)/4+1/2, 4, pha, width));
    
    %Post-processing: 
    img(img > 0) = 255;
    img = img - 127;
    img = uint8(img .* circap + 127);
    Stimulus(:,:,f) = img; %Saves stimulus frame
    f = f + 1;
end

%Save resulting movie
StimFrames = 2;

save('Ripples', 'Stimulus', 'StimFrames');