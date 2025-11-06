function s = n2s(n,d)
%s = n2s(n, [d = NaN])
%
% Short-cut version for num2str. Optional second input d determines the
% number of decimals to which the number is rounded. This defaults to NaN
% which means no rounding is done.
%

if nargin < 2
    d = NaN;
end

% Rounding?
if ~isnan(d)
    n = round(n,d);
end

% Convert to string
s = num2str(n);