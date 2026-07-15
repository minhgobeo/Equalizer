function ch = sparam_to_symbol_impulse(sp, varargin)
%SPARAM_TO_SYMBOL_IMPULSE  Convert Touchstone S-parameters to symbol taps.
%
% This is a lightweight COM-style simulation helper, not a COM
% implementation. It extracts a through response, interpolates it onto a
% uniform positive-frequency grid, builds a real impulse response by IFFT,
% and samples symbol-spaced taps around the main cursor.

p = inputParser;
addParameter(p, 'baud', 26.5625e9, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'sps', 16, @(x)isnumeric(x) && isscalar(x) && x >= 2);
addParameter(p, 'ntaps', 9, @(x)isnumeric(x) && isscalar(x) && x >= 2);
addParameter(p, 'port_order', '12_34', @ischar);
addParameter(p, 'normalize_main', true, @islogical);
addParameter(p, 'high_freq_fill', 'zero', @(x)ischar(x) || isstring(x));
parse(p, varargin{:});
opt = p.Results;

[H, label] = local_through_response(sp, opt.port_order);
f = sp.freq_hz(:);
H = H(:);

good = isfinite(f) & isfinite(real(H)) & isfinite(imag(H));
f = f(good);
H = H(good);
[f, ia] = unique(f, 'stable');
H = H(ia);
if numel(f) < 4
    error('sparam_to_symbol_impulse:notEnoughData', ...
        'Need at least four frequency samples in %s.', sp.file);
end

fs = opt.baud * opt.sps;
fmax_measured = max(f);
fmax = fs/2;
nfft_half = 4096;
fu = linspace(0, fmax, nfft_half).';

if min(f) > 0
    f = [0; f];
    H = [H(1); H];
end
Hu = interp1(f, H, min(fu, fmax_measured), 'pchip', 'extrap');
switch lower(char(opt.high_freq_fill))
    case 'zero'
        Hu(fu > fmax_measured) = 0;
    case 'hold'
        Hu(fu > fmax_measured) = H(end);
    case 'extrap'
        Hu = interp1(f, H, fu, 'pchip', 'extrap');
    otherwise
        error('sparam_to_symbol_impulse:badHighFreqFill', ...
            'Unsupported high_freq_fill: %s', char(opt.high_freq_fill));
end

spec = [Hu; conj(Hu(end-1:-1:2))];
h_os = real(ifft(spec));

[~, peak] = max(abs(h_os));
max_sym = floor((numel(h_os)-peak) / opt.sps);
nt = min(opt.ntaps, max_sym + 1);
if nt < 2
    nt = min(opt.ntaps, numel(h_os)-peak+1);
    taps = h_os(peak:peak+nt-1);
else
    taps = h_os(peak + (0:nt-1)*opt.sps);
end
taps = taps(:);
if opt.normalize_main && abs(taps(1)) > eps
    taps = taps / taps(1);
end

nyq = opt.baud / 2;
Hnyq = interp1(f, H, min(nyq, max(f)), 'pchip', 'extrap');
Hdc = interp1(f, H, 0, 'pchip', 'extrap');
il_db = -20*log10(abs(Hnyq) / max(abs(Hdc), eps));

ch = struct();
ch.file = sp.file;
ch.label = label;
ch.freq_hz = fu;
ch.H = Hu;
ch.h_oversampled = h_os(:);
ch.main_sample = peak;
ch.symbol_taps = taps;
ch.h2_proxy = local_h2_proxy(taps);
ch.insertion_loss_db = il_db;
ch.measured_freq_max_hz = fmax_measured;
ch.ifft_freq_max_hz = fmax;
ch.baud = opt.baud;
ch.sps = opt.sps;
ch.is_public_sparameter = true;
ch.note = ['Touchstone-derived symbol taps for simulation; not a full ' ...
           'IEEE COM compliance calculation.'];
end

function h2 = local_h2_proxy(taps)
if numel(taps) >= 2
    h2 = taps(2);
else
    h2 = 0;
end
end

function [H, label] = local_through_response(sp, port_order)
S = sp.S;
n = sp.nport;
if n < 2
    error('sparam_to_symbol_impulse:badPortCount', 'Need at least 2 ports.');
end

if n >= 4
    switch lower(port_order)
        case '13_24'
            % Differential input pair 1/3, output pair 2/4.
            H = 0.5 * squeeze(S(2,1,:) - S(2,3,:) - S(4,1,:) + S(4,3,:));
            label = 'Sdd21 ports in/out = 1-3 / 2-4';
        case '12_34'
            % Differential input pair 1/2, output pair 3/4.
            H = 0.5 * squeeze(S(3,1,:) - S(3,2,:) - S(4,1,:) + S(4,2,:));
            label = 'Sdd21 ports in/out = 1-2 / 3-4';
        otherwise
            error('sparam_to_symbol_impulse:badPortOrder', ...
                'Unsupported port_order: %s', port_order);
    end
else
    H = squeeze(S(2,1,:));
    label = 'single-ended S21';
end
end
