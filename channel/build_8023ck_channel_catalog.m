function catalog = build_8023ck_channel_catalog(varargin)
%BUILD_8023CK_CHANNEL_CATALOG  Find/load public 802.3ck-style channels.
%
% Put downloaded IEEE 802.3ck Touchstone files under:
%   data/8023ck_channels/
%
% Optional manifest:
%   data/8023ck_channels/channel_manifest.csv
%
% Required/recognized columns:
%   case_id, group, role, file, baud, loss_db, include

p = inputParser;
addParameter(p, 'root_dir', fullfile('data','8023ck_channels'), @ischar);
addParameter(p, 'allow_synthetic', true, @islogical);
addParameter(p, 'baud', 26.5625e9, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'sps', 16, @(x)isnumeric(x) && isscalar(x) && x >= 2);
addParameter(p, 'ntaps', 9, @(x)isnumeric(x) && isscalar(x) && x >= 2);
addParameter(p, 'port_order', '12_34', @ischar);
addParameter(p, 'override_manifest_baud', false, @islogical);
parse(p, varargin{:});
opt = p.Results;

rows = local_manifest_rows(opt.root_dir);
if isempty(rows)
    rows = local_discover_rows(opt.root_dir, opt.baud);
elseif opt.override_manifest_baud
    for i = 1:numel(rows)
        rows(i).baud = opt.baud;
    end
end

catalog = struct([]);
for i = 1:numel(rows)
    if isfield(rows(i),'include') && ~rows(i).include
        continue;
    end
    fp = rows(i).file;
    if ~isabsolute_path(fp)
        fp = fullfile(opt.root_dir, fp);
    end
    try
        sp = load_touchstone_sparam(fp);
        ch = sparam_to_symbol_impulse(sp, ...
            'baud', rows(i).baud, 'sps', opt.sps, 'ntaps', opt.ntaps, ...
            'port_order', opt.port_order, 'normalize_main', false);
        ch.case_id = rows(i).case_id;
        ch.group = rows(i).group;
        ch.role = rows(i).role;
        ch.measured_insertion_loss_db = ch.insertion_loss_db;
        if isfinite(rows(i).loss_db)
            ch.nominal_loss_db = rows(i).loss_db;
            ch.insertion_loss_db = rows(i).loss_db;
        else
            ch.nominal_loss_db = ch.insertion_loss_db;
        end
        if isempty(catalog)
            catalog = ch;
        else
            catalog(end+1) = ch; %#ok<AGROW>
        end
    catch ME
        warning('build_8023ck_channel_catalog:skipFile', ...
            'Skipping %s: %s', fp, ME.message);
    end
end

if isempty(catalog) && opt.allow_synthetic
    catalog = local_synthetic_catalog(opt.baud, opt.sps, opt.ntaps);
end
end

function rows = local_manifest_rows(root_dir)
manifest = fullfile(root_dir, 'channel_manifest.csv');
rows = struct([]);
if exist(manifest, 'file') ~= 2
    return;
end
T = readtable(manifest, 'TextType', 'string');
for i = 1:height(T)
    r = struct();
    r.case_id = local_get_table_string(T, i, 'case_id', sprintf('CH%d', i));
    r.group = local_get_table_string(T, i, 'group', 'custom');
    r.role = local_get_table_string(T, i, 'role', 'benchmark');
    r.file = local_get_table_string(T, i, 'file', '');
    r.baud = local_get_table_number(T, i, 'baud', 26.5625e9);
    r.loss_db = local_get_table_number(T, i, 'loss_db', NaN);
    r.include = logical(local_get_table_number(T, i, 'include', 1));
    if ~isempty(r.file)
        if isempty(rows)
            rows = r;
        else
            rows(end+1) = r; %#ok<AGROW>
        end
    end
end
end

function rows = local_discover_rows(root_dir, baud)
rows = struct([]);
if exist(root_dir, 'dir') ~= 7
    return;
end
dd = dir(fullfile(root_dir, '**', '*.s*p'));
for i = 1:numel(dd)
    r = struct();
    [~,name,~] = fileparts(dd(i).name);
    r.case_id = matlab.lang.makeValidName(name);
    r.group = local_guess_group(lower(dd(i).folder));
    r.role = local_guess_role(dd(i).Name);
    r.file = fullfile(dd(i).folder, dd(i).name);
    r.baud = baud;
    r.loss_db = local_guess_loss_db(fullfile(dd(i).folder, name));
    r.include = true;
    if isempty(rows)
        rows = r;
    else
        rows(end+1) = r; %#ok<AGROW>
    end
end
end

function s = local_get_table_string(T, i, name, def)
if any(strcmp(T.Properties.VariableNames, name))
    v = T.(name)(i);
    s = char(v);
else
    s = def;
end
end

function x = local_get_table_number(T, i, name, def)
if any(strcmp(T.Properties.VariableNames, name))
    x = T.(name)(i);
    if iscell(x), x = x{1}; end
    if isstring(x) || ischar(x), x = str2double(x); end
    if isempty(x) || ~isfinite(x), x = def; end
else
    x = def;
end
end

function g = local_guess_group(path_text)
if contains(path_text,'c2m') || contains(path_text,'module')
    g = 'C2M';
elseif contains(path_text,'c2c') || contains(path_text,'chip')
    g = 'C2C';
elseif contains(path_text,'backplane') || contains(path_text,'bp')
    g = 'Backplane';
elseif contains(path_text,'cable') || contains(path_text,'cr')
    g = 'Cable';
else
    g = 'Custom';
end
end

function x = local_guess_loss_db(name)
tok = regexp(name, '(\d+(?:\.\d+)?)\s*dB', 'tokens', 'once', 'ignorecase');
if isempty(tok)
    x = NaN;
else
    x = str2double(tok{1});
end

function role = local_guess_role(name)
if ~isempty(regexp(name, '(?i)thru', 'once'))
    role = 'thru';
elseif ~isempty(regexp(name, '(?i)fext|fen', 'once'))
    role = 'fext';
elseif ~isempty(regexp(name, '(?i)next|nen', 'once'))
    role = 'next';
else
    role = 'other';
end
end
end

function tf = isabsolute_path(p)
tf = startsWith(p, filesep) || ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once'));
end

function catalog = local_synthetic_catalog(baud, sps, ntaps)
defs = {
    'C2M_10dB_fallback','C2M','fallback',10,[1 0.18 0.08 -0.035 0.018]
    'C2M_14dB_fallback','C2M','fallback',14,[1 0.28 0.12 -0.055 0.025]
    'C2M_16dB_fallback','C2M','fallback',16,[1 0.36 0.17 -0.070 0.035]
    'C2C_20dB_fallback','C2C','fallback',20,[1 0.46 0.23 -0.095 0.040]
    'BP_24dB_fallback','Backplane','fallback',24,[1 0.55 0.31 -0.130 0.070]
    'Cable_2m_XTALK_fallback','Cable','fallback',28,[1 0.62 0.38 -0.160 0.090]
    };
catalog = struct([]);
for i = 1:size(defs,1)
    taps = defs{i,5}(:);
    if numel(taps) < ntaps
        taps(end+1:ntaps) = 0;
    else
        taps = taps(1:ntaps);
    end
    ch = struct();
    ch.file = '';
    ch.case_id = defs{i,1};
    ch.group = defs{i,2};
    ch.role = defs{i,3};
    ch.symbol_taps = taps;
    ch.h2_proxy = taps(2);
    ch.insertion_loss_db = defs{i,4};
    ch.nominal_loss_db = defs{i,4};
    ch.baud = baud;
    ch.sps = sps;
    ch.is_public_sparameter = false;
    ch.note = ['Synthetic fallback for smoke tests only. Download public ' ...
               'IEEE 802.3ck Touchstone channels before producing paper figures.'];
    if isempty(catalog)
        catalog = ch;
    else
        catalog(end+1) = ch; %#ok<AGROW>
    end
end
end
