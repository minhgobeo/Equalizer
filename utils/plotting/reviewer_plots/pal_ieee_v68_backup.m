function p = pal_ieee()
%PAL_IEEE  Colorblind-friendly palette for IEEE Access figures.
% Adapted from Wong's "Points of view" colorblind-safe palette.
% Print-safe and distinguishable in greyscale by lightness.

p = struct();
p.proposed   = [0.000 0.447 0.741];   % strong blue
p.oracle     = [0.000 0.620 0.451];   % bluish green (upper bound reference)
p.alg5       = [0.835 0.369 0.000];   % vermilion (single-bank baseline)
p.nlms       = [0.494 0.184 0.557];   % purple
p.smsign     = [0.929 0.694 0.125];   % yellow / amber
p.smsign_vss = [0.466 0.674 0.188];   % olive green
p.cui        = [0.300 0.745 0.933];   % sky blue
p.liu_ss     = [0.635 0.078 0.184];   % dark red
p.liu_ta     = [0.850 0.325 0.098];   % orange (lighter than alg5)
p.chen       = [0.400 0.400 0.400];   % gray
p.dolatsara  = [0.500 0.500 0.700];   % muted blue (appendix)
p.fec_line   = [0.150 0.150 0.150];   % near-black for FEC reference
end
