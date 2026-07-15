function sp = load_touchstone_sparam(file_path)
%LOAD_TOUCHSTONE_SPARAM  Minimal Touchstone reader for .sNp channel files.
%
% Supports S-parameter data in RI, MA, or DB format with Hz/kHz/MHz/GHz
% frequency units. This avoids requiring RF Toolbox for paper benchmark
% scripts. Mixed-mode conversion is handled by sparam_to_symbol_impulse.

if exist(file_path, 'file') ~= 2
    error('load_touchstone_sparam:notFound', 'File not found: %s', file_path);
end

[~,~,ext] = fileparts(file_path);
tok = regexp(lower(ext), '\.s(\d+)p', 'tokens', 'once');
if isempty(tok)
    error('load_touchstone_sparam:badExtension', ...
        'Expected a Touchstone extension like .s4p, got: %s', ext);
end
nport = str2double(tok{1});

fid = fopen(file_path, 'r');
if fid < 0
    error('load_touchstone_sparam:openFailed', 'Cannot open: %s', file_path);
end
cleanup = onCleanup(@() fclose(fid));

unit = 'ghz';
fmt = 'ma';
z0 = 50;
rows = {};

while true
    line = fgetl(fid);
    if ~ischar(line), break; end
    line = strtrim(regexprep(line, '!.*$', ''));
    if isempty(line), continue; end
    if startsWith(line, '#')
        parts = lower(strsplit(strtrim(line(2:end))));
        if numel(parts) >= 1, unit = parts{1}; end
        if numel(parts) >= 3, fmt = parts{3}; end
        ridx = find(strcmp(parts, 'r'), 1, 'first');
        if ~isempty(ridx) && ridx < numel(parts)
            z0 = str2double(parts{ridx+1});
        end
        continue;
    end
    vals = sscanf(line, '%f').';
    if ~isempty(vals), rows{end+1} = vals; end %#ok<AGROW>
end

flat = [rows{:}];
n_per_freq = 1 + 2*nport*nport;
if mod(numel(flat), n_per_freq) ~= 0
    error('load_touchstone_sparam:parseFailed', ...
        'Cannot parse %s: expected %d numeric values per frequency row.', ...
        file_path, n_per_freq);
end

mat = reshape(flat, n_per_freq, []).';
freq = mat(:,1) * local_freq_scale(unit);
raw = mat(:,2:end);
nf = numel(freq);
S = zeros(nport, nport, nf);

for k = 1:nf
    c = raw(k,:);
    vals = zeros(nport*nport, 1);
    for q = 1:numel(vals)
        a = c(2*q-1);
        b = c(2*q);
        switch lower(fmt)
            case 'ri'
                vals(q) = complex(a, b);
            case 'ma'
                vals(q) = a .* exp(1j*pi*b/180);
            case 'db'
                vals(q) = 10.^(a/20) .* exp(1j*pi*b/180);
            otherwise
                error('load_touchstone_sparam:badFormat', ...
                    'Unsupported Touchstone format: %s', fmt);
        end
    end
    S(:,:,k) = reshape(vals, nport, nport).';
end

sp = struct();
sp.file = file_path;
sp.nport = nport;
sp.freq_hz = freq(:);
sp.S = S;
sp.format = fmt;
sp.z0 = z0;
end

function sc = local_freq_scale(unit)
switch lower(unit)
    case 'hz',  sc = 1;
    case 'khz', sc = 1e3;
    case 'mhz', sc = 1e6;
    case 'ghz', sc = 1e9;
    otherwise
        error('load_touchstone_sparam:badUnit', 'Unsupported frequency unit: %s', unit);
end
end
