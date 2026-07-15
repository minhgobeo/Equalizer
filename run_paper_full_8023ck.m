function out = run_paper_full_8023ck(varargin)
%RUN_PAPER_FULL_8023CK  Final 802.3ck paper simulation pack.
%
% Example:
%   out = run_paper_full_8023ck('trials', 10, ...
%       'snr', 16:2:30, ...
%       'save_dir', 'paper_final_results');
%
% The runner creates:
%   save_dir/tables/   CSV tables for paper
%   save_dir/figures/  paper figures
%   save_dir/mat/      MATLAB result bundles

p = inputParser;
addParameter(p, 'trials', 5, @(x)isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'snr', [18 22 26 30], @isnumeric);
addParameter(p, 'save_dir', 'paper_final_results', @ischar);
addParameter(p, 'channel_dir', fullfile('data','8023ck_channels'), @ischar);
addParameter(p, 'format', 'png', @ischar);
addParameter(p, 'fig_visible', 'off', @ischar);
addParameter(p, 'run_markov_sweep', true, @islogical);
addParameter(p, 'p_stay', [0.995 0.985 0.970 0.930], @isnumeric);
addParameter(p, 'make_figures', true, @islogical);
addParameter(p, 'make_eye', true, @islogical);
addParameter(p, 'allow_synthetic', false, @islogical);
parse(p, varargin{:});
opt = p.Results;

root = fileparts(mfilename('fullpath'));
addpath(genpath(root));

dirs.root = opt.save_dir;
dirs.tables = fullfile(opt.save_dir, 'tables');
dirs.figures = fullfile(opt.save_dir, 'figures');
dirs.mat = fullfile(opt.save_dir, 'mat');
local_mkdirs(dirs);

fprintf('\n[paper_full_8023ck] Running final static + Markov benchmark pack.\n');
fprintf('[paper_full_8023ck] trials=%d, SNR=[%s]\n', opt.trials, num2str(opt.snr));

bench = run_paper('8023ck_sparam', ...
    'trials', opt.trials, ...
    'snr', opt.snr, ...
    'max_cases', 6, ...
    'run_static', true, ...
    'run_markov', true, ...
    'run_markov_sweep', opt.run_markov_sweep, ...
    'p_stay', opt.p_stay, ...
    'plot', false, ...
    'fig_visible', opt.fig_visible, ...
    'save_dir', dirs.figures, ...
    'channel_dir', opt.channel_dir, ...
    'allow_synthetic', opt.allow_synthetic, ...
    'format', opt.format);

out = struct();
out.benchmark = bench;
out.options = opt;
out.dirs = dirs;

out.tables.channel_cases = local_write_channel_table(bench, dirs.tables);
out.tables.snr30 = local_write_snr30_table(bench, dirs.tables);
out.tables.markov = local_write_markov_table(bench, dirs.tables);
out.tables.markov_sweep = local_write_markov_sweep_table(bench, dirs.tables);
out.tables.second_best = local_write_second_best_summary(bench, dirs.tables);
out.tables.aware_family = local_write_aware_family_table(bench, dirs.tables);
out.tables.protocol = local_write_protocol_table(opt, dirs.tables);
out.tables.claim_ready = local_write_claim_ready_summary(bench, opt, dirs.tables);
out.figures = struct();
if opt.make_figures
    out.figures.system_flow = local_plot_system_flow(dirs.figures, opt);
    out.figures.static_c2m = local_plot_static_ber(bench, 'C2M', dirs.figures, opt);
    out.figures.static_c2c = local_plot_static_ber(bench, 'C2C', dirs.figures, opt);
    out.figures.il_summary = local_plot_il_summary(bench, dirs.figures, opt);
    out.figures.markov_summary = local_plot_markov_summary(bench, dirs.figures, opt);
    out.figures.markov_transition = local_plot_markov_transition(bench, dirs.figures, opt);
    out.figures.markov_sweep_all = local_plot_markov_sweep_all_methods(bench, dirs.figures, opt);
    out.figures.second_best = local_plot_second_best_summary(bench, dirs.figures, opt);
    out.figures.aware_family = local_plot_aware_family(bench, dirs.figures, opt);
end

function T = local_write_protocol_table(opt, table_dir)
simulation_id = [ ...
    "S1_static_C2M_BER"; ...
    "S2_static_C2C_BER"; ...
    "S3_channel_severity_IL"; ...
    "S4_markov_C2M_modes"; ...
    "S5_markov_dwell_sweep"; ...
    "S6_eye_snapshots"; ...
    "S7_aware_SMNLMS_ablation"; ...
    "S8_complexity_margin"];
role = [ ...
    "Main realistic C2M waterfall"; ...
    "Electrical on-board stress waterfall"; ...
    "Insertion-loss severity trend"; ...
    "Proposed-specific Markov tracking"; ...
    "Switching severity / dwell-length stress"; ...
    "Visual eye opening evidence"; ...
    "Endogenous-aware SMNLMS justification"; ...
    "Paper table for second-best margin"];
channels = [ ...
    "C2M_10dB,C2M_14dB,C2M_16dB"; ...
    "C2C_10dB,C2C_18dB,C2C_20dB"; ...
    "All selected static C2M/C2C cases"; ...
    "C2M_10dB|C2M_14dB|C2M_16dB"; ...
    "C2M_10dB|C2M_14dB|C2M_16dB"; ...
    "C2M_16dB,C2C_20dB,Markov_slow_C2M"; ...
    "NLMS,SMNLMS,SM-sign-NLMS,Proposed"; ...
    "All method tables"];
snr = repmat(string(mat2str(opt.snr)), numel(simulation_id), 1);
trials = repmat(opt.trials, numel(simulation_id), 1);
Nsym = repmat(40000, numel(simulation_id), 1);
trainLen = repmat(8000, numel(simulation_id), 1);
Nsym(4:5) = 80000;
trainLen(4:5) = 12000;
Nsym(6) = 40000;
trainLen(6) = 8000;
rationale = [ ...
    "Liu-style PAM4 lossy-channel BER/eye evaluation; static channel"; ...
    "802.3ck electrical-link stress beyond C2M"; ...
    "Chen-style pulse/channel severity reporting using eye and SER"; ...
    "Tests stale decision-directed updates and endogenous cross-state memory"; ...
    "Souza/Cui-inspired Markov switching severity and temporal routing stress"; ...
    "Liu/Chen-style eye-height/eye-width reporting, all compared recursions"; ...
    "Directly supports proposed endogenous-aware SMNLMS claim"; ...
    "Cui-style complexity/performance and second-best comparison summary"];
T = table(simulation_id, role, channels, snr, trials, Nsym, trainLen, rationale);
writetable(T, fullfile(table_dir, 'Table_0_final_simulation_protocol.csv'));
end

if opt.make_eye
    out.eye = local_run_eye_snapshots(opt, dirs);
else
    out.eye = [];
end

save(fullfile(dirs.mat, 'paper_full_8023ck_out.mat'), 'out', '-v7.3');
local_write_readme(opt, dirs);
fprintf('[paper_full_8023ck] Done. Results under %s\n', opt.save_dir);
end

function local_mkdirs(dirs)
names = fieldnames(dirs);
for i = 1:numel(names)
    if exist(dirs.(names{i}), 'dir') ~= 7
        mkdir(dirs.(names{i}));
    end
end
end

function T = local_write_channel_table(bench, table_dir)
cases = bench.cases(:);
case_id = string({cases.case_id}.');
group = string({cases.group}.');
role = string({cases.role}.');
insertion_loss_db = [cases.insertion_loss_db].';
is_public_sparameter = [cases.is_public_sparameter].';
file = string({cases.file}.');
T = table(case_id, group, role, insertion_loss_db, is_public_sparameter, file);
writetable(T, fullfile(table_dir, 'Table_I_channel_cases.csv'));
end

function T = local_write_snr30_table(bench, table_dir)
rows = bench.table(:);
if isempty(rows)
    T = table();
    return;
end
snr_vals = [rows.SNRdB];
snr_ref = max(snr_vals);
rows = rows(abs(snr_vals - snr_ref) < 1e-9);
methods = rows(1).methods(:);
keep = ~strcmp(methods, 'Chen pulse-ref');
methods = methods(keep);

case_id = strings(0,1); group = strings(0,1); method = strings(0,1);
SNRdB = []; BER = []; SER = []; EyeHeight = []; EyeWidth = [];
for i = 1:numel(rows)
    for m = 1:numel(rows(i).methods)
        if strcmp(rows(i).methods{m}, 'Chen pulse-ref'), continue; end
        case_id(end+1,1) = string(rows(i).case_id); %#ok<AGROW>
        group(end+1,1) = string(rows(i).group); %#ok<AGROW>
        method(end+1,1) = string(rows(i).methods{m}); %#ok<AGROW>
        SNRdB(end+1,1) = rows(i).SNRdB; %#ok<AGROW>
        BER(end+1,1) = rows(i).BER(m); %#ok<AGROW>
        SER(end+1,1) = rows(i).SER(m); %#ok<AGROW>
        EyeHeight(end+1,1) = rows(i).EyeHeight(m); %#ok<AGROW>
        EyeWidth(end+1,1) = rows(i).EyeWidth(m); %#ok<AGROW>
    end
end
T = table(case_id, group, SNRdB, method, BER, SER, EyeHeight, EyeWidth);
writetable(T, fullfile(table_dir, 'Table_II_static_snr30.csv'));

idx_prop = find(strcmp(methods, 'Proposed MSB'), 1);
if ~isempty(idx_prop)
    avg = local_static_average_table(rows, methods);
    writetable(avg, fullfile(table_dir, 'Table_IIb_static_average_snr30.csv'));
end
end

function T = local_static_average_table(rows, methods)
method = string(methods(:));
BER_mean = nan(numel(methods),1);
SER_mean = nan(numel(methods),1);
EyeHeight_mean = nan(numel(methods),1);
EyeWidth_mean = nan(numel(methods),1);
for m = 1:numel(methods)
    idx = find(strcmp(rows(1).methods, methods{m}), 1);
    BER_mean(m) = mean(arrayfun(@(r) r.BER(idx), rows), 'omitnan');
    SER_mean(m) = mean(arrayfun(@(r) r.SER(idx), rows), 'omitnan');
    EyeHeight_mean(m) = mean(arrayfun(@(r) r.EyeHeight(idx), rows), 'omitnan');
    EyeWidth_mean(m) = mean(arrayfun(@(r) r.EyeWidth(idx), rows), 'omitnan');
end
T = table(method, BER_mean, SER_mean, EyeHeight_mean, EyeWidth_mean);
end

function T = local_write_markov_table(bench, table_dir)
mk = bench.markov(:);
if isempty(mk)
    T = table();
    return;
end
case_id = string({mk.case_id}.');
SNRdB = [mk.SNRdB].';
BER_proposed = [mk.BER_algorithm6].';
BER_alg1 = [mk.BER_algorithm1].';
BER_chen = [mk.BER_chen_pulse_ref].';
improvement_vs_alg1_pct = [mk.improvement_pct].';
improvement_vs_chen_pct = [mk.improvement_vs_chen_pct].';
transition_window_BER_proposed = [mk.transition_window_BER_algorithm6].';
transition_window_BER_alg1 = [mk.transition_window_BER_algorithm1].';
recovery_time_proposed = [mk.recovery_time_algorithm6].';
recovery_time_alg1 = [mk.recovery_time_algorithm1].';
state_accuracy = [mk.state_accuracy].';
T = table(case_id, SNRdB, BER_proposed, BER_alg1, BER_chen, ...
    improvement_vs_alg1_pct, improvement_vs_chen_pct, ...
    transition_window_BER_proposed, transition_window_BER_alg1, ...
    recovery_time_proposed, recovery_time_alg1, state_accuracy);
writetable(T, fullfile(table_dir, 'Table_III_markov_tracking.csv'));
end

function T = local_write_markov_sweep_table(bench, table_dir)
if ~isfield(bench, 'markov_sweep') || isempty(bench.markov_sweep)
    T = table();
    return;
end
sw = bench.markov_sweep(:);
case_id = strings(0,1); Pstay = []; mean_dwell_symbols = []; SNRdB = [];
method = strings(0,1); BER = []; SER = []; state_accuracy = [];
for i = 1:numel(sw)
    for m = 1:numel(sw(i).methods)
        case_id(end+1,1) = string(sw(i).case_id); %#ok<AGROW>
        Pstay(end+1,1) = sw(i).Pstay; %#ok<AGROW>
        mean_dwell_symbols(end+1,1) = sw(i).mean_dwell_symbols; %#ok<AGROW>
        SNRdB(end+1,1) = sw(i).SNRdB; %#ok<AGROW>
        method(end+1,1) = string(sw(i).methods{m}); %#ok<AGROW>
        BER(end+1,1) = sw(i).BER(m); %#ok<AGROW>
        SER(end+1,1) = sw(i).SER(m); %#ok<AGROW>
        state_accuracy(end+1,1) = sw(i).state_accuracy; %#ok<AGROW>
    end
end
T = table(case_id, Pstay, mean_dwell_symbols, SNRdB, method, BER, SER, state_accuracy);
writetable(T, fullfile(table_dir, 'Table_IV_markov_sweep_all_methods.csv'));
end

function T = local_write_second_best_summary(bench, table_dir)
block = strings(0,1); case_id = strings(0,1); SNRdB = [];
proposed_BER = []; second_best_BER = []; second_best_method = strings(0,1);
improvement_vs_second_best_pct = [];

rows = bench.table(:);
if ~isempty(rows)
    for i = 1:numel(rows)
        methods = rows(i).methods;
        scopes = {'all_methods','adaptive_recursions'};
        excludes = {{'No EQ'}, {'No EQ','Chen pulse-ref'}};
        for sc = 1:numel(scopes)
            [sb, sb_name, imp, prop] = local_second_best(methods, rows(i).BER, excludes{sc});
            block(end+1,1) = "static_" + string(scopes{sc}); %#ok<AGROW>
            case_id(end+1,1) = string(rows(i).case_id); %#ok<AGROW>
            SNRdB(end+1,1) = rows(i).SNRdB; %#ok<AGROW>
            proposed_BER(end+1,1) = prop; %#ok<AGROW>
            second_best_BER(end+1,1) = sb; %#ok<AGROW>
            second_best_method(end+1,1) = string(sb_name); %#ok<AGROW>
            improvement_vs_second_best_pct(end+1,1) = imp; %#ok<AGROW>
        end
    end
end

if isfield(bench, 'markov_sweep') && ~isempty(bench.markov_sweep)
    sw = bench.markov_sweep(:);
    for i = 1:numel(sw)
        scopes = {'all_methods','adaptive_recursions'};
        excludes = {{}, {'Chen pulse-ref'}};
        for sc = 1:numel(scopes)
            [sb, sb_name, imp, prop] = local_second_best(sw(i).methods, sw(i).BER, excludes{sc});
            block(end+1,1) = "markov_sweep_" + string(scopes{sc}); %#ok<AGROW>
            case_id(end+1,1) = string(sw(i).case_id); %#ok<AGROW>
            SNRdB(end+1,1) = sw(i).SNRdB; %#ok<AGROW>
            proposed_BER(end+1,1) = prop; %#ok<AGROW>
            second_best_BER(end+1,1) = sb; %#ok<AGROW>
            second_best_method(end+1,1) = string(sb_name); %#ok<AGROW>
            improvement_vs_second_best_pct(end+1,1) = imp; %#ok<AGROW>
        end
    end
end

T = table(block, case_id, SNRdB, proposed_BER, second_best_BER, ...
    second_best_method, improvement_vs_second_best_pct);
writetable(T, fullfile(table_dir, 'Second_best_improvement_summary.csv'));
end

function T = local_write_claim_ready_summary(bench, opt, table_dir)
block = strings(0,1); case_id = strings(0,1); SNRdB = [];
proposed_BER = []; comparator_BER = []; comparator = strings(0,1);
improvement_pct = []; effective_bits = []; delta_error_count = [];
ci95_proposed = []; ci95_comparator = []; verdict = strings(0,1);
main_claim_use = strings(0,1);

rows = bench.table(:);
for i = 1:numel(rows)
    methods = rows(i).methods;
    [sb, sb_name, imp, prop] = local_second_best(methods, rows(i).BER, {'No EQ','Chen pulse-ref'});
    bits = local_effective_bits('static', opt.trials);
    [vp, vsb, dec] = local_ber_verdict(prop, sb, bits);
    block(end+1,1) = "static_adaptive_noninferiority"; %#ok<AGROW>
    case_id(end+1,1) = string(rows(i).case_id); %#ok<AGROW>
    SNRdB(end+1,1) = rows(i).SNRdB; %#ok<AGROW>
    proposed_BER(end+1,1) = prop; %#ok<AGROW>
    comparator_BER(end+1,1) = sb; %#ok<AGROW>
    comparator(end+1,1) = string(sb_name); %#ok<AGROW>
    improvement_pct(end+1,1) = imp; %#ok<AGROW>
    effective_bits(end+1,1) = bits; %#ok<AGROW>
    delta_error_count(end+1,1) = (sb - prop) * bits; %#ok<AGROW>
    ci95_proposed(end+1,1) = vp; %#ok<AGROW>
    ci95_comparator(end+1,1) = vsb; %#ok<AGROW>
    verdict(end+1,1) = dec; %#ok<AGROW>
    main_claim_use(end+1,1) = "sanity/non-inferiority only"; %#ok<AGROW>
end

if isfield(bench, 'markov_sweep') && ~isempty(bench.markov_sweep)
    sw = bench.markov_sweep(:);
    for i = 1:numel(sw)
        [sb, sb_name, imp, prop] = local_second_best(sw(i).methods, sw(i).BER, {'Chen pulse-ref'});
        bits = local_effective_bits('markov', opt.trials);
        [vp, vsb, dec] = local_ber_verdict(prop, sb, bits);
        block(end+1,1) = "markov_sweep_adaptive_claim"; %#ok<AGROW>
        case_id(end+1,1) = string(sw(i).case_id); %#ok<AGROW>
        SNRD = sw(i).SNRdB; SNRdB(end+1,1) = SNRD; %#ok<AGROW>
        proposed_BER(end+1,1) = prop; %#ok<AGROW>
        comparator_BER(end+1,1) = sb; %#ok<AGROW>
        comparator(end+1,1) = string(sb_name); %#ok<AGROW>
        improvement_pct(end+1,1) = imp; %#ok<AGROW>
        effective_bits(end+1,1) = bits; %#ok<AGROW>
        delta_error_count(end+1,1) = (sb - prop) * bits; %#ok<AGROW>
        ci95_proposed(end+1,1) = vp; %#ok<AGROW>
        ci95_comparator(end+1,1) = vsb; %#ok<AGROW>
        verdict(end+1,1) = dec; %#ok<AGROW>
        if imp >= 20
            main_claim_use(end+1,1) = "main hero claim"; %#ok<AGROW>
        elseif imp >= 10
            main_claim_use(end+1,1) = "supporting Markov claim"; %#ok<AGROW>
        else
            main_claim_use(end+1,1) = "non-inferiority/support"; %#ok<AGROW>
        end
    end
end

T = table(block, case_id, SNRdB, proposed_BER, comparator_BER, comparator, ...
    improvement_pct, effective_bits, delta_error_count, ci95_proposed, ...
    ci95_comparator, verdict, main_claim_use);
writetable(T, fullfile(table_dir, 'Table_V_claim_ready_summary.csv'));
end

function bits = local_effective_bits(kind, trials)
switch lower(kind)
    case 'markov'
        n_sym = 80000; n_train = 12000;
    otherwise
        n_sym = 40000; n_train = 8000;
end
bits = max(1, (n_sym - n_train) * 2 * trials);
end

function [ci_p, ci_q, verdict] = local_ber_verdict(p, q, bits)
ci_p = 1.96 * sqrt(max(p,0) * max(1-p,0) / max(bits,1));
ci_q = 1.96 * sqrt(max(q,0) * max(1-q,0) / max(bits,1));
delta = q - p;
err_delta = delta * bits;
overlap = abs(delta) <= (ci_p + ci_q);
if p <= q && (~overlap || err_delta >= 10)
    verdict = "win";
elseif overlap || abs(err_delta) < 10
    verdict = "statistical tie";
else
    verdict = "loss";
end
end

function T = local_write_aware_family_table(bench, table_dir)
family = local_aware_family_methods();
block = strings(0,1); case_id = strings(0,1); sweep_x = []; sweep_label = strings(0,1);
method = strings(0,1); BER = []; SER = []; improvement_vs_best_classical_pct = [];

rows = bench.table(:);
if ~isempty(rows)
    snrs = unique([rows.SNRdB], 'stable');
    methods = rows(1).methods;
    for si = 1:numel(snrs)
        r_snr = rows(abs([rows.SNRdB] - snrs(si)) < 1e-9);
        ber_mean = nan(1, numel(family.source));
        ser_mean = nan(1, numel(family.source));
        for mi = 1:numel(family.source)
            idx = find(strcmp(methods, family.source{mi}), 1);
            ber_mean(mi) = mean(arrayfun(@(r) r.BER(idx), r_snr), 'omitnan');
            ser_mean(mi) = mean(arrayfun(@(r) r.SER(idx), r_snr), 'omitnan');
        end
        imp = local_family_improvement(ber_mean);
        for mi = 1:numel(family.source)
            block(end+1,1) = "static_snr_avg"; %#ok<AGROW>
            case_id(end+1,1) = "C2M+C2C average"; %#ok<AGROW>
            sweep_x(end+1,1) = snrs(si); %#ok<AGROW>
            sweep_label(end+1,1) = "SNRdB"; %#ok<AGROW>
            method(end+1,1) = string(family.label{mi}); %#ok<AGROW>
            BER(end+1,1) = ber_mean(mi); %#ok<AGROW>
            SER(end+1,1) = ser_mean(mi); %#ok<AGROW>
            improvement_vs_best_classical_pct(end+1,1) = imp; %#ok<AGROW>
        end
    end
end

if isfield(bench, 'markov_sweep') && ~isempty(bench.markov_sweep)
    sw = bench.markov_sweep(:);
    methods = sw(1).methods;
    for i = 1:numel(sw)
        ber_vals = nan(1, numel(family.source));
        ser_vals = nan(1, numel(family.source));
        for mi = 1:numel(family.source)
            idx = find(strcmp(methods, family.source{mi}), 1);
            ber_vals(mi) = sw(i).BER(idx);
            ser_vals(mi) = sw(i).SER(idx);
        end
        imp = local_family_improvement(ber_vals);
        for mi = 1:numel(family.source)
            block(end+1,1) = "markov_dwell"; %#ok<AGROW>
            case_id(end+1,1) = string(sw(i).case_id); %#ok<AGROW>
            sweep_x(end+1,1) = sw(i).mean_dwell_symbols; %#ok<AGROW>
            sweep_label(end+1,1) = "mean_dwell_symbols"; %#ok<AGROW>
            method(end+1,1) = string(family.label{mi}); %#ok<AGROW>
            BER(end+1,1) = ber_vals(mi); %#ok<AGROW>
            SER(end+1,1) = ser_vals(mi); %#ok<AGROW>
            improvement_vs_best_classical_pct(end+1,1) = imp; %#ok<AGROW>
        end
    end
end

T = table(block, case_id, sweep_x, sweep_label, method, BER, SER, ...
    improvement_vs_best_classical_pct);
writetable(T, fullfile(table_dir, 'Aware_endogenous_SMNLMS_family.csv'));
end

function family = local_aware_family_methods()
family.source = {'NLMS-DFE','SMNLMS-DFE','SM-sign-NLMS','Proposed MSB'};
family.label = {'NLMS','SMNLMS','SM-sign-NLMS','Endogenous-aware SMNLMS'};
end

function imp = local_family_improvement(ber_vals)
prop = ber_vals(end);
best_classical = min(ber_vals(1:end-1));
if best_classical <= eps
    if prop <= eps
        imp = NaN;
    else
        imp = -Inf;
    end
else
    imp = 100 * (1 - prop / best_classical);
end
end

function [second_best, second_name, improvement, prop] = local_second_best(methods, ber, exclude)
idx_prop = find(strcmp(methods, 'Proposed MSB'), 1);
prop = ber(idx_prop);
mask = true(size(ber));
mask(idx_prop) = false;
for i = 1:numel(exclude)
    mask(strcmp(methods, exclude{i})) = false;
end
vals = ber;
vals(~mask) = inf;
[second_best, idx] = min(vals);
second_name = methods{idx};
if second_best <= eps
    if prop <= eps
        improvement = NaN;
    else
        improvement = -Inf;
    end
else
    improvement = 100 * (1 - prop / second_best);
end
end

function fname = local_plot_system_flow(fig_dir, opt)
fig = figure('Name','system_flow','Color','w','Visible',opt.fig_visible, ...
    'Position',[100 100 1300 420]);
ax = axes(fig);
axis(ax, [0 1 0 1]);
axis(ax, 'off');
hold(ax, 'on');

boxes = { ...
    'PAM4 PRBS\newline symbols', ...
    'Tx FFE\newline 3 taps', ...
    '802.3ck S-parameter\newline channel FIR', ...
    'AWGN / XTALK\newline rx gain', ...
    'FIR likelihood\newline + HMM router', ...
    'State-bank DFE\newline bank-local SMNLMS', ...
    'Endogenous-aware\newline update gate', ...
    'PAM4 decisions\newline BER / SER / Eye'};
x = linspace(0.07, 0.93, numel(boxes));
y = 0.56 * ones(size(x));
w = 0.105; h = 0.20;
colors = [ ...
    0.86 0.93 1.00; ...
    0.90 0.96 0.88; ...
    1.00 0.94 0.82; ...
    1.00 0.88 0.86; ...
    0.91 0.89 1.00; ...
    0.88 0.95 0.96; ...
    0.97 0.90 0.97; ...
    0.92 0.92 0.92];
for i = 1:numel(boxes)
    rectangle(ax, 'Position',[x(i)-w/2 y(i)-h/2 w h], ...
        'Curvature',0.04, 'FaceColor',colors(i,:), ...
        'EdgeColor',[0.15 0.15 0.15], 'LineWidth',1.1);
    text(ax, x(i), y(i), boxes{i}, 'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', 'FontName','Times New Roman', ...
        'FontSize',10, 'Interpreter','tex');
    if i < numel(boxes)
        annotation(fig, 'arrow', [x(i)+w/2+0.005 x(i+1)-w/2-0.005], ...
            [y(i) y(i)], 'LineWidth',1.0, 'Color',[0.2 0.2 0.2]);
    end
end

% Feedback and Markov-state annotations.
annotation(fig, 'textarrow', [0.78 0.63], [0.33 0.46], ...
    'String','bank-local feedback memory', 'FontName','Times New Roman', ...
    'FontSize',9, 'Color',[0.10 0.35 0.35], 'LineWidth',1.0);
annotation(fig, 'textarrow', [0.62 0.56], [0.83 0.68], ...
    'String','posterior entropy / confidence', 'FontName','Times New Roman', ...
    'FontSize',9, 'Color',[0.30 0.20 0.55], 'LineWidth',1.0);
annotation(fig, 'textarrow', [0.74 0.70], [0.83 0.68], ...
    'String','cross-state memory', 'FontName','Times New Roman', ...
    'FontSize',9, 'Color',[0.55 0.20 0.45], 'LineWidth',1.0);
text(ax, 0.5, 0.17, ...
    'Final proposed path: hard HMM/FIR routing + bank-local SMNLMS + endogenous-bias-aware gate. Soft output/adaptive tau are disabled in the main BER configuration after ablation.', ...
    'HorizontalAlignment','center', 'FontName','Times New Roman', ...
    'FontSize',10, 'Color',[0.12 0.12 0.12]);
local_ieee_style(fig);
fname = local_save_fig(fig, fig_dir, 'Fig_System_Flow_Proposed_Receiver', opt);
end

function fname = local_plot_static_ber(bench, group_name, fig_dir, opt)
rows = bench.table(:);
rows = rows(strcmpi({rows.group}, group_name));
if isempty(rows), fname = ''; return; end
methods = rows(1).methods;
plot_methods = {'NLMS-DFE','SMNLMS-DFE','SM-sign-NLMS','Liu SS-LMS', ...
    'ExtraTrees-HMM','Algorithm 1','Proposed MSB'};
case_ids = unique(string({rows.case_id}), 'stable');

fig = figure('Name', ['static_ber_' lower(group_name)], 'Color', 'w', 'Visible', opt.fig_visible);
tl = tiledlayout(1, numel(case_ids), 'Padding','compact', 'TileSpacing','compact');
for ci = 1:numel(case_ids)
    nexttile;
    rcase = rows(strcmp(string({rows.case_id}), case_ids(ci)));
    [~, ord] = sort([rcase.SNRdB]);
    rcase = rcase(ord);
    hold on;
    for mi = 1:numel(plot_methods)
        idx = find(strcmp(methods, plot_methods{mi}), 1);
        if isempty(idx), continue; end
        y = arrayfun(@(r) r.BER(idx), rcase);
        st = local_style(plot_methods{mi});
        semilogy([rcase.SNRdB], max(y,1e-12), st.marker, ...
            'Color', st.color, 'LineWidth', st.lw, 'MarkerSize', st.ms, ...
            'MarkerFaceColor', st.color);
    end
    grid on;
    xlabel('SNR (dB)');
    ylabel('Pre-FEC BER');
    title(strrep(case_ids(ci), '_', '\_'));
end
legend(plot_methods, 'Location','southoutside', 'Orientation','horizontal', 'Interpreter','none');
title(tl, sprintf('Static %s BER vs SNR', group_name));
local_ieee_style(fig);
fname = local_save_fig(fig, fig_dir, ['Fig_static_' lower(group_name) '_ber'], opt);
end

function fname = local_plot_il_summary(bench, fig_dir, opt)
rows = bench.table(:);
if isempty(rows), fname = ''; return; end
snr_ref = max([rows.SNRdB]);
rows = rows(abs([rows.SNRdB] - snr_ref) < 1e-9);
methods = rows(1).methods;
idx_prop = find(strcmp(methods, 'Proposed MSB'), 1);
plot_methods = {'NLMS-DFE','SMNLMS-DFE','SM-sign-NLMS','Liu SS-LMS', ...
    'ExtraTrees-HMM','Algorithm 1','Proposed MSB'};
il = [rows.insertion_loss_db];
if any(isnan(il))
    il(isnan(il)) = 0;
end
[il, ord] = sort(il);
rows = rows(ord);

fig = figure('Name','il_summary','Color','w','Visible',opt.fig_visible);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;
hold on;
for mi = 1:numel(plot_methods)
    idx = find(strcmp(methods, plot_methods{mi}), 1);
    if isempty(idx), continue; end
    st = local_style(plot_methods{mi});
    semilogy(il, max(arrayfun(@(r) r.SER(idx), rows),1e-12), st.marker, ...
        'LineWidth', st.lw, 'MarkerSize', st.ms, ...
        'MarkerFaceColor', st.color, 'Color', st.color);
end
grid on; xlabel('Insertion loss (dB)'); ylabel('SER');
title(sprintf('SER vs insertion loss, SNR=%g dB', snr_ref));
legend(plot_methods, 'Location','best', 'Interpreter','none');

nexttile;
hold on;
for mi = 1:numel(plot_methods)
    idx = find(strcmp(methods, plot_methods{mi}), 1);
    if isempty(idx), continue; end
    st = local_style(plot_methods{mi});
    plot(il, arrayfun(@(r) r.EyeHeight(idx), rows), st.marker, ...
        'LineWidth', st.lw, 'MarkerSize', st.ms, ...
        'MarkerFaceColor', st.color, 'Color', st.color);
end
grid on; xlabel('Insertion loss (dB)'); ylabel('Eye height');
title('Eye height vs insertion loss');
legend(plot_methods, 'Location','best', 'Interpreter','none');
local_ieee_style(fig);
fname = local_save_fig(fig, fig_dir, 'Fig_IL_SER_EyeHeight', opt);
end

function fname = local_plot_markov_summary(bench, fig_dir, opt)
mk = bench.markov(:);
if isempty(mk), fname = ''; return; end
labels = strrep(string({mk.case_id}), '_', '\_');
x = 1:numel(mk);
fig = figure('Name','markov_summary','Color','w','Visible',opt.fig_visible);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;
semilogy(x, max([mk.BER_algorithm6],1e-12), '-o', 'LineWidth', 2, ...
    'Color', local_style('Proposed MSB').color, 'MarkerFaceColor', local_style('Proposed MSB').color);
hold on;
semilogy(x, max([mk.BER_algorithm1],1e-12), '-s', 'LineWidth', 1.6, ...
    'Color', local_style('Algorithm 1').color, 'MarkerFaceColor', local_style('Algorithm 1').color);
semilogy(x, max([mk.BER_chen_pulse_ref],1e-12), '-x', 'LineWidth', 1.3, ...
    'Color', [0.25 0.25 0.25]);
grid on; set(gca,'XTick',x,'XTickLabel',labels); xtickangle(25);
ylabel('Pre-FEC BER'); title('Markov C2M BER');
legend({'Proposed MSB','Algorithm 1','Chen ref'}, 'Location','best');

nexttile;
bar(x, 100*[mk.state_accuracy], 'FaceColor', local_style('Proposed MSB').color);
grid on; set(gca,'XTick',x,'XTickLabel',labels); xtickangle(25);
ylabel('State accuracy (%)'); ylim([0 100]); title('HMM/MSB state tracking');
local_ieee_style(fig);
fname = local_save_fig(fig, fig_dir, 'Fig_Markov_BER_StateAccuracy', opt);
end

function fname = local_plot_markov_transition(bench, fig_dir, opt)
mk = bench.markov(:);
if isempty(mk), fname = ''; return; end
labels = strrep(string({mk.case_id}), '_', '\_');
x = 1:numel(mk);
fig = figure('Name','markov_transition','Color','w','Visible',opt.fig_visible);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;
semilogy(x, max([mk.transition_window_BER_algorithm6],1e-12), '-o', 'LineWidth', 2, ...
    'Color', local_style('Proposed MSB').color, 'MarkerFaceColor', local_style('Proposed MSB').color);
hold on;
semilogy(x, max([mk.transition_window_BER_algorithm1],1e-12), '-s', 'LineWidth', 1.6, ...
    'Color', local_style('Algorithm 1').color, 'MarkerFaceColor', local_style('Algorithm 1').color);
grid on; set(gca,'XTick',x,'XTickLabel',labels); xtickangle(25);
ylabel('Transition-window BER'); title('Post-transition BER');
legend({'Proposed MSB','Algorithm 1'}, 'Location','best');

nexttile;
plot(x, [mk.recovery_time_algorithm6], '-o', 'LineWidth', 2, ...
    'Color', local_style('Proposed MSB').color, 'MarkerFaceColor', local_style('Proposed MSB').color);
hold on;
plot(x, [mk.recovery_time_algorithm1], '-s', 'LineWidth', 1.6, ...
    'Color', local_style('Algorithm 1').color, 'MarkerFaceColor', local_style('Algorithm 1').color);
grid on; set(gca,'XTick',x,'XTickLabel',labels); xtickangle(25);
ylabel('Recovery time (symbols)'); title('Recovery after channel jump');
legend({'Proposed MSB','Algorithm 1'}, 'Location','best');
local_ieee_style(fig);
fname = local_save_fig(fig, fig_dir, 'Fig_Markov_Transition_Recovery', opt);
end

function fname = local_plot_markov_sweep_all_methods(bench, fig_dir, opt)
if ~isfield(bench, 'markov_sweep') || isempty(bench.markov_sweep)
    fname = '';
    return;
end
sw = bench.markov_sweep(:);
methods = sw(1).methods;
plot_methods = {'NLMS-DFE','SMNLMS-DFE','SM-sign-NLMS','Liu SS-LMS', ...
    'Chen pulse-ref','ExtraTrees-HMM','Algorithm 1','Proposed MSB'};
[x, ord] = sort([sw.mean_dwell_symbols], 'ascend');
sw = sw(ord);

fig = figure('Name','markov_sweep_all_methods','Color','w','Visible',opt.fig_visible);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;
hold on;
for mi = 1:numel(plot_methods)
    idx = find(strcmp(methods, plot_methods{mi}), 1);
    if isempty(idx), continue; end
    y = arrayfun(@(r) r.BER(idx), sw);
    st = local_style(plot_methods{mi});
    semilogy(x, max(y, 1e-12), st.marker, 'Color', st.color, ...
        'LineWidth', st.lw, 'MarkerSize', st.ms, 'MarkerFaceColor', st.color);
end
grid on;
xlabel('Mean dwell length (symbols)');
ylabel('Pre-FEC BER');
title('Markov dwell sweep: all recursions');
legend(plot_methods, 'Location','best', 'Interpreter','none');

nexttile;
imps = zeros(numel(sw),1);
for i = 1:numel(sw)
    [~, ~, imps(i)] = local_second_best(sw(i).methods, sw(i).BER, {'Chen pulse-ref'});
end
plot(x, imps, '-o', 'Color', local_style('Proposed MSB').color, ...
    'LineWidth', 2.2, 'MarkerFaceColor', local_style('Proposed MSB').color);
yline(30, '--', '30% target', 'Color', [0.4 0.4 0.4]);
grid on;
xlabel('Mean dwell length (symbols)');
ylabel('Improvement vs second-best adaptive recursion (%)');
title('Proposed margin over strongest online recursion');
local_ieee_style(fig);
fname = local_save_fig(fig, fig_dir, 'Fig_Markov_Sweep_All_Methods', opt);
end

function fname = local_plot_second_best_summary(bench, fig_dir, opt)
if ~isfield(bench, 'markov_sweep') || isempty(bench.markov_sweep)
    fname = '';
    return;
end
sw = bench.markov_sweep(:);
[x, ord] = sort([sw.mean_dwell_symbols], 'ascend');
sw = sw(ord);
imp = zeros(numel(sw),1);
for i = 1:numel(sw)
    [~, ~, imp(i)] = local_second_best(sw(i).methods, sw(i).BER, {'Chen pulse-ref'});
end
fig = figure('Name','second_best_margin','Color','w','Visible',opt.fig_visible);
bar(x, imp, 'FaceColor', local_style('Proposed MSB').color);
hold on;
yline(30, '--', '30% target', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
grid on;
xlabel('Mean dwell length (symbols)');
ylabel('Improvement vs second-best adaptive recursion (%)');
title('Second-best adaptive-recursion improvement check');
local_ieee_style(fig);
fname = local_save_fig(fig, fig_dir, 'Fig_Second_Best_Improvement', opt);
end

function fname = local_plot_aware_family(bench, fig_dir, opt)
family = local_aware_family_methods();
fig = figure('Name','aware_endogenous_smnlms_family','Color','w','Visible',opt.fig_visible);
has_sweep = isfield(bench, 'markov_sweep') && ~isempty(bench.markov_sweep);
if has_sweep
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    nexttile;
    sw = bench.markov_sweep(:);
    methods = sw(1).methods;
    [x, ord] = sort([sw.mean_dwell_symbols], 'ascend');
    sw = sw(ord);
    hold on;
    for mi = 1:numel(family.source)
        idx = find(strcmp(methods, family.source{mi}), 1);
        y = arrayfun(@(r) r.BER(idx), sw);
        st = local_style(family.source{mi});
        semilogy(x, max(y, 1e-12), st.marker, 'Color', st.color, ...
            'LineWidth', st.lw, 'MarkerSize', st.ms, 'MarkerFaceColor', st.color);
    end
    grid on;
    xlabel('Mean dwell length (symbols)');
    ylabel('Pre-FEC BER');
    title('Markov dwell sweep: endogenous-aware gate');
    legend(family.label, 'Location','best', 'Interpreter','none');

    nexttile;
    imp = zeros(numel(sw),1);
    for i = 1:numel(sw)
        vals = nan(1, numel(family.source));
        for mi = 1:numel(family.source)
            idx = find(strcmp(methods, family.source{mi}), 1);
            vals(mi) = sw(i).BER(idx);
        end
        imp(i) = local_family_improvement(vals);
    end
    plot(x, imp(ord), '-o', 'Color', local_style('Proposed MSB').color, ...
        'LineWidth', 2.2, 'MarkerFaceColor', local_style('Proposed MSB').color);
    yline(10, '--', '10% support', 'Color', [0.45 0.45 0.45]);
    yline(30, ':', '30% hero', 'Color', [0.25 0.25 0.25]);
    grid on;
    xlabel('Mean dwell length (symbols)');
    ylabel('Gain over best NLMS/SMNLMS/sign-NLMS (%)');
    title('Endogenous-aware SMNLMS margin');
else
    tiledlayout(1,1,'Padding','compact','TileSpacing','compact');
    text(0.5,0.5,'Run with run\_markov\_sweep=true to generate this figure.', ...
        'HorizontalAlignment','center');
end
local_ieee_style(fig);
fname = local_save_fig(fig, fig_dir, 'Fig_Aware_Endogenous_SMNLMS_Family', opt);
end

function eye = local_run_eye_snapshots(opt, dirs)
fprintf('[paper_full_8023ck] Running eye snapshots.\n');
cfg = build_main_config();
base = build_baselines();
vars = build_variants(cfg);
cfgp = local_receiver_cfg_full(cfg);
cfgp.SNRdB = max(opt.snr);
v_base = local_v_base_full(vars, cfgp);
msb_params = default_msb_params_v69();
msb_params.train_all_prefix = cfgp.trainLen;
msb_params.score_mode = 'channel_likelihood';
msb_params.init_from_hbank = true;
msb_params.bank_update_rule = 'smnlms';
msb_params.smnlms = base.smnlms;
msb_params.eb_gate = local_default_eb_gate_full();
msb_params.use_soft_output = false;
msb_params.use_adaptive_tau = false;
msb_params.use_beta_anneal = true;
msb_params.anneal_halflife = 6000;
msb_params.anneal_floor = 0.4;

catalog = build_8023ck_channel_catalog('root_dir', opt.channel_dir, ...
    'allow_synthetic', opt.allow_synthetic, 'baud', 26.5625e9, ...
    'sps', 16, 'ntaps', 9);
ids = {'C2M_16dB','C2C_20dB'};
records = {};
for i = 1:numel(ids)
    ch = local_pick_catalog_case(catalog, ids{i});
    records{end+1} = local_eye_static_case(ch, cfgp, base, v_base, msb_params, dirs, opt); %#ok<AGROW>
end
records{end+1} = local_eye_markov_slow(catalog, cfgp, base, v_base, msb_params, dirs, opt); %#ok<AGROW>
T = vertcat(records{:});
eye = T;
writetable(T, fullfile(dirs.tables, 'Eye_snapshot_metrics.csv'));
writetable(T, fullfile(dirs.tables, 'Eye_snapshot_metrics_all_methods.csv'));
end

function rec = local_eye_static_case(ch, cfg, base, v_base, msb_params, dirs, opt)
rng(2400000 + sum(double(ch.case_id)));
tx_ffe = local_tx_ffe_taps_full();
h_eff = local_effective_channel_full(ch.symbol_taps, tx_ffe);
h_bank = local_static_h_bank_full(h_eff);
d = local_pam4_full(cfg);
tx = local_apply_tx_ffe_full(d, tx_ffe);
r_clean = filter(ch.symbol_taps, 1, tx);
[r, sigma2, rx_gain] = local_add_receiver_noise_full(r_clean, tx, cfg);
h_bank_rx = cellfun(@(h) rx_gain*h, h_bank, 'UniformOutput', false);

[names, dhs, ys] = local_run_eye_methods(r, d, cfg, base, v_base, ...
    msb_params, h_bank_rx, [], sigma2, rx_gain);
idx_no = find(strcmp(names, 'No EQ'), 1);
idx_alg1 = find(strcmp(names, 'Algorithm 1'), 1);
idx_prop = find(strcmp(names, 'Proposed MSB'), 1);
fname = local_plot_eye_triplet(ys{idx_no}, ys{idx_alg1}, ys{idx_prop}, d, cfg, ...
    sprintf('Eye_%s_SNR%d', ch.case_id, round(cfg.SNRdB)), dirs.figures, opt);
rec = local_eye_record(ch.case_id, 'static', cfg.SNRdB, ...
    ch.insertion_loss_db, string(sprintf('%.3g dB', ch.insertion_loss_db)), ...
    fname, d, names, dhs, ys, cfg);
end

function rec = local_eye_markov_slow(catalog, cfg, base, v_base, msb_params, dirs, opt)
sel = [local_pick_catalog_case(catalog, 'C2M_10dB'), ...
       local_pick_catalog_case(catalog, 'C2M_14dB'), ...
       local_pick_catalog_case(catalog, 'C2M_16dB')];
rng(2500000);
tx_ffe = local_tx_ffe_taps_full();
h_phys = cellfun(@(c)c.symbol_taps(:), num2cell(sel), 'UniformOutput', false);
h_bank = cellfun(@(h)local_effective_channel_full(h, tx_ffe), h_phys, 'UniformOutput', false);
d = local_pam4_full(cfg);
tx = local_apply_tx_ffe_full(d, tx_ffe);
P = [0.985 0.015 0; 0.0075 0.985 0.0075; 0 0.015 0.985];
state_seq = local_balanced_markov_state_seq_full(cfg.Nsym, cfg.trainLen, P);
[r_clean, ch_state] = local_channel_out_fir_state_seq_full(tx, h_phys, state_seq);
[r, sigma2, rx_gain] = local_add_receiver_noise_full(r_clean, tx, cfg);
h_bank_rx = cellfun(@(h) rx_gain*h, h_bank, 'UniformOutput', false);
msb_params.train_all_prefix = 0;
msb_params.oracle_train_only = true;
msb_params.use_beta_anneal = false;
[names, dhs, ys] = local_run_eye_methods(r, d, cfg, base, v_base, ...
    msb_params, h_bank_rx, ch_state.state, sigma2, rx_gain);
idx_no = find(strcmp(names, 'No EQ'), 1);
idx_alg1 = find(strcmp(names, 'Algorithm 1'), 1);
idx_prop = find(strcmp(names, 'Proposed MSB'), 1);
fname = local_plot_eye_triplet(ys{idx_no}, ys{idx_alg1}, ys{idx_prop}, d, cfg, ...
    sprintf('Eye_Markov_slow_C2M_SNR%d', round(cfg.SNRdB)), dirs.figures, opt);
losses = [sel.insertion_loss_db];
rec = local_eye_record('Markov_slow_C2M', 'markov', cfg.SNRdB, ...
    mean(losses, 'omitnan'), "C2M 10|14|16 dB", ...
    fname, d, names, dhs, ys, cfg);
end

function [names, dhs, ys] = local_run_eye_methods(r, d, cfg, base, v_base, msb_params, h_bank_rx, oracle_state, sigma2, rx_gain)
names = {'No EQ','NLMS-DFE','SMNLMS-DFE','SM-sign-NLMS', ...
    'Liu SS-LMS','ExtraTrees-HMM','Algorithm 1','Proposed MSB'};
dhs = cell(size(names));
ys = cell(size(names));

dhs{1} = local_noeq_full(r, cfg);
ys{1} = r(:);

[ys{2}, dhs{2}] = dfe_nlms_unified_x(r, d, cfg, base);
[ys{3}, dhs{3}] = dfe_smnlms_unified_x(r, d, cfg, base, sigma2);
[ys{4}, dhs{4}] = dfe_smsign_nlms_unified_x(r, d, cfg, base, sigma2);

cfg_liu = cfg;
cfg_liu.Nb = max(cfg.Nb, 4);
v_liu = v_base;
if numel(v_liu.theta_min) ~= cfg_liu.Nf + cfg_liu.Nb
    v_liu.theta_min = [v_base.theta_min(1:cfg.Nf); -3.5*ones(cfg_liu.Nb,1)];
    v_liu.theta_max = [v_base.theta_max(1:cfg.Nf);  3.5*ones(cfg_liu.Nb,1)];
end
opts_liu = struct('adaptive_threshold', true, 'update_ffe', false, ...
    'update_dfe', true, 'mu_f', 2e-3, 'mu_thr', 2e-3, ...
    'use_projection', true);
[~, dhs{5}, diag_liu] = dfe_ss_lms_pam4(r, d, cfg_liu, v_liu, opts_liu);
ys{5} = local_diag_output_full(diag_liu, r, cfg);

[dhs{6}, diag_cui] = local_extratrees_hmm_reference_full(r, d, cfg);
ys{6} = local_diag_output_full(diag_cui, r, cfg);

[dhs{7}, diag_alg1] = algorithm5_singlebank(r, d, cfg, v_base);
ys{7} = local_diag_output_full(diag_alg1, r, cfg);

msb_params.sigma2 = sigma2 * rx_gain^2;
[dhs{8}, diag_prop] = algorithm6_msb_firbank(r, d, cfg, v_base, msb_params, h_bank_rx, oracle_state);
ys{8} = local_diag_output_full(diag_prop, r, cfg);
end

function T = local_eye_record(case_id, kind, snr, channel_loss_db, channel_loss_label, fname, d, names, dhs, ys, cfg)
n = numel(names);
case_id = repmat(string(case_id), n, 1);
kind = repmat(string(kind), n, 1);
SNRdB = repmat(snr, n, 1);
supply_condition = repmat(string(sprintf('AWGN SNR %.3g dB, rx gain normalized', snr)), n, 1);
channel_loss_db = repmat(channel_loss_db, n, 1);
channel_loss_label = repmat(string(channel_loss_label), n, 1);
method = string(names(:));
BER = nan(n,1);
SER = nan(n,1);
EyeHeight = nan(n,1);
EyeWidth = nan(n,1);
figure = repmat(string(fname), n, 1);
for i = 1:n
    SER(i) = ser_after_training_aligned(d, dhs{i}, cfg);
    BER(i) = SER(i) / log2(cfg.M);
    met = compute_eye_height_width_metrics(ys{i}, d, cfg);
    EyeHeight(i) = met.eye_height_5_95;
    EyeWidth(i) = met.eye_width_ui;
end
T = table(case_id, kind, SNRdB, supply_condition, channel_loss_db, ...
    channel_loss_label, method, BER, SER, EyeHeight, EyeWidth, figure);
end

function fname = local_plot_eye_triplet(y_no, y_alg1, y_prop, d, cfg, base_name, fig_dir, opt)
fig = figure('Name', base_name, 'Color', 'w', 'Visible', opt.fig_visible);
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');
ys = {y_no, y_alg1, y_prop};
names = {'No EQ','Algorithm 1','Proposed MSB'};
for k = 1:3
    nexttile;
    local_eye_scatter(ys{k}, d, cfg);
    title(names{k});
end
local_ieee_style(fig);
fname = local_save_fig(fig, fig_dir, base_name, opt);
end

function local_eye_scatter(y, d, cfg)
y = y(:);
N = min(numel(y), numel(d));
idx = (cfg.trainLen+1):min(N, cfg.trainLen+6000);
if isempty(idx), idx = 1:min(N,6000); end
phase = mod(idx(:)-1, 2);
plot(phase, y(idx), '.', 'MarkerSize', 2, 'Color', [0.05 0.25 0.65]);
hold on;
plot(phase+1, y(idx), '.', 'MarkerSize', 2, 'Color', [0.05 0.25 0.65]);
yline([-2 0 2], ':', 'Color', [0.4 0.4 0.4]);
grid on;
xlim([0 2]);
xlabel('UI');
ylabel('Equalizer output');
end

function cfgp = local_receiver_cfg_full(cfg)
cfgp = cfg;
cfgp.Nsym = 40000;
cfgp.trainLen = 8000;
cfgp.Nf = 7;
cfgp.Nb = 3;
cfgp.D = 3;
cfgp.chan_mode = 'external_fir';
if isfield(cfgp,'std8023'), cfgp.std8023.enable = false; end
end

function v = local_v_base_full(vars, cfgp)
v = make_v_alg5(vars.theorem);
K = cfgp.Nf; L = cfgp.Nb;
main_idx = round((K+1)/2);
v.main_idx = main_idx;
ffe_min = -v.w2_max*ones(K,1);
ffe_max =  v.w2_max*ones(K,1);
ffe_min(main_idx) = -Inf;
ffe_max(main_idx) =  Inf;
v.theta_min = [ffe_min; -3.5*ones(L,1)];
v.theta_max = [ffe_max;  3.5*ones(L,1)];
end

function g = local_default_eb_gate_full()
g = struct('enabled', true, 'lambda_entropy', 1.0, ...
    'lambda_cross', 3.0, 'lambda_confidence', 0.5, ...
    'gamma_max_scale', 3.0, 'beta_min_scale', 0.35, ...
    'use_fast_reroute', true, 'reroute_entropy', 0.33, ...
    'reroute_conf_gap', 0.55, 'reroute_pi_reset', 0.75, ...
    'use_decision_reliability_route', false, ...
    'decision_reliability_weight', 0.15, ...
    'use_output_reliability_select', false, ...
    'output_select_entropy', 0.25, 'output_select_margin', 0.0, ...
    'use_nominal_fallback_output', false, ...
    'nominal_fallback_entropy', 0.32, 'nominal_state', 2);
end

function ch = local_pick_catalog_case(catalog, case_id)
idx = find(strcmp({catalog.case_id}, case_id), 1);
if isempty(idx)
    error('run_paper_full_8023ck:missingCase', 'Missing channel case "%s".', case_id);
end
ch = catalog(idx);
end

function d = local_pam4_full(cfg)
sym_idx = randi([1 cfg.M], cfg.Nsym, 1);
d = cfg.A(sym_idx).';
d = d(:);
end

function taps = local_tx_ffe_taps_full()
taps = [1; -0.08; 0.03];
end

function h_eff = local_effective_channel_full(h, tx_ffe)
h_eff = conv(tx_ffe(:), h(:));
end

function h_bank = local_static_h_bank_full(h)
h = h(:);
scale = [0.92 1.00 1.08];
h_bank = cell(1,3);
for s = 1:3
    hs = h;
    if numel(hs) >= 2
        hs(2:end) = scale(s) * hs(2:end);
    end
    h_bank{s} = hs;
end
end

function y = local_apply_tx_ffe_full(d, taps)
y = filter(taps(:), 1, d(:));
pow_in = rms(d);
pow_out = rms(y);
if pow_out > eps
    y = y * (pow_in / pow_out);
end
end

function [r, sigma2, rx_gain] = local_add_receiver_noise_full(r_clean, tx_ref, cfg)
ref_pow = mean(tx_ref(:).^2);
sigma2 = ref_pow / (10^(cfg.SNRdB/10));
r = r_clean(:) + sqrt(sigma2) * randn(size(r_clean(:)));
target_rms = rms(tx_ref(:));
obs_rms = rms(r);
rx_gain = 1;
if obs_rms > eps
    rx_gain = target_rms / obs_rms;
    r = r * rx_gain;
end
end

function dh = local_noeq_full(r, cfg)
dh = zeros(cfg.Nsym,1);
for n = 1:min(numel(r), cfg.Nsym)
    m = n - cfg.D;
    if m >= 1 && m <= cfg.Nsym
        dh(m) = pam_slice_scalar(r(n), cfg.A);
    end
end
end

function y = local_diag_output_full(diag, r, cfg)
if isstruct(diag) && isfield(diag, 'y_hist')
    y = diag.y_hist(:);
elseif isstruct(diag) && isfield(diag, 'z_hist')
    y = diag.z_hist(:);
else
    y = r(:);
end
if numel(y) < cfg.Nsym
    y(end+1:cfg.Nsym) = 0;
end
end

function [dh, diag] = local_extratrees_hmm_reference_full(r, d, cfg)
X = local_cui_features_full(r);
y = local_aligned_labels_full(d, cfg, numel(r));
train_mask = y.valid & y.m <= cfg.trainLen;

try
    if exist('fitcensemble','file') == 2 && nnz(train_mask) > 100
        mdl = fitcensemble(X(train_mask,:), y.cls(train_mask), ...
            'Method','Bag', 'NumLearningCycles',30);
        [~, score] = predict(mdl, X);
        cls = mdl.ClassNames;
        Pemit = local_scores_to_emit_full(score, cls, cfg.M);
        kind = 'fitcensemble_bag';
    else
        [Pemit, kind] = local_centroid_emit_full(X, y.cls, train_mask, cfg.M);
    end
catch
    [Pemit, kind] = local_centroid_emit_full(X, y.cls, train_mask, cfg.M);
end

[logA, log_pi0] = hmm_train_pam4(y.cls(train_mask), cfg.M, 1.0);
test_classes = hmm_viterbi_pam4(Pemit, logA, log_pi0);
A = cfg.A(:);
sample_hat = A(max(1,min(cfg.M,test_classes)));
dh = zeros(numel(d),1);
for n = 1:numel(sample_hat)
    m = n - cfg.D;
    if m >= 1 && m <= numel(d)
        dh(m) = sample_hat(n);
    end
end
diag = struct('z_hist', sample_hat(:), 'classifier_kind', kind);
end

function X = local_cui_features_full(r)
r = r(:);
N = numel(r);
X = zeros(N,5);
for n = 1:N
    rn = r(n);
    rm1 = 0; if n >= 2, rm1 = r(n-1); end
    rm2 = 0; if n >= 3, rm2 = r(n-2); end
    rm3 = 0; if n >= 4, rm3 = r(n-3); end
    X(n,:) = [rn rm1 rm2 rm3 rn-rm1];
end
end

function y = local_aligned_labels_full(d, cfg, Nr)
m = (1:Nr).' - cfg.D;
valid = m >= 1 & m <= numel(d);
cls = ones(Nr,1);
A = cfg.A(:).';
for n = find(valid).'
    [~, cls(n)] = min(abs(d(m(n)) - A));
end
y = struct('m', m, 'valid', valid, 'cls', cls);
end

function P = local_scores_to_emit_full(score, cls, M)
P = zeros(size(score,1), M);
if iscell(cls), cls = str2double(cls); end
for k = 1:numel(cls)
    mi = round(cls(k));
    if mi >= 1 && mi <= M
        P(:,mi) = score(:,k);
    end
end
P = max(P, 1e-12);
P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);
end

function [P, kind] = local_centroid_emit_full(X, cls, train_mask, M)
kind = 'nearest_centroid';
C = zeros(M, size(X,2));
for m = 1:M
    idx = train_mask & cls == m;
    if any(idx)
        C(m,:) = mean(X(idx,:),1);
    else
        C(m,:) = mean(X(train_mask,:),1);
    end
end
D = zeros(size(X,1), M);
for m = 1:M
    E = X - C(m,:);
    D(:,m) = sum(E.*E,2);
end
sig2 = max(mean(D(:))/4, 1e-6);
P = exp(-D/(2*sig2));
P = bsxfun(@rdivide, P, sum(P,2) + 1e-12);
end

function state_seq = local_balanced_markov_state_seq_full(N, trainLen, P)
S = size(P,1);
state_seq = ones(N,1);
seg = floor(trainLen / S);
for s = 1:S
    a = (s-1)*seg + 1;
    b = min(trainLen, s*seg);
    state_seq(a:b) = s;
end
if S*seg < trainLen
    state_seq(S*seg+1:trainLen) = S;
end
state_seq(trainLen+1) = min(2,S);
for n = trainLen+2:N
    prev = state_seq(n-1);
    state_seq(n) = sample_discrete(P(prev,:));
end
end

function [r_clean, ch_state] = local_channel_out_fir_state_seq_full(d, h_bank, state_seq)
N = numel(d);
r_clean = zeros(N,1);
maxL = max(cellfun(@numel, h_bank));
H = zeros(N, maxL);
for n = 1:N
    h = h_bank{state_seq(n)}(:);
    H(n,1:numel(h)) = h(:).';
    acc = 0;
    for k = 1:numel(h)
        m = n-k+1;
        if m >= 1
            acc = acc + h(k)*d(m);
        end
    end
    r_clean(n) = acc;
end
ch_state = struct('state', state_seq(:), 'h', H, 'h_bank', {h_bank});
end

function st = local_style(name)
st = struct('color',[0 0 0], 'marker','-o', 'lw',1.4, 'ms',6);
switch name
    case 'Proposed MSB'
        st.color = [0.00 0.45 0.74]; st.marker = '-o'; st.lw = 2.2; st.ms = 7;
    case 'Algorithm 1'
        st.color = [0.85 0.33 0.10]; st.marker = '-s'; st.lw = 1.8; st.ms = 6;
    case 'NLMS-DFE'
        st.color = [0.47 0.67 0.19]; st.marker = '-d';
    case 'SMNLMS-DFE'
        st.color = [0.49 0.18 0.56]; st.marker = '-^';
    case 'SM-sign-NLMS'
        st.color = [0.30 0.75 0.93]; st.marker = '-v';
    case 'Liu SS-LMS'
        st.color = [0.64 0.08 0.18]; st.marker = '-p';
    case 'ExtraTrees-HMM'
        st.color = [0.25 0.25 0.25]; st.marker = '-x';
end
end

function local_ieee_style(fig)
set(findall(fig,'-property','FontName'), 'FontName', 'Times New Roman');
set(findall(fig,'-property','FontSize'), 'FontSize', 10);
set(findall(fig,'Type','axes'), 'LineWidth', 0.8, 'Box', 'on');
end

function fname = local_save_fig(fig, fig_dir, base_name, opt)
if exist(fig_dir, 'dir') ~= 7, mkdir(fig_dir); end
fmt = lower(opt.format);
fname = fullfile(fig_dir, [base_name '.' fmt]);
switch fmt
    case 'png'
        exportgraphics(fig, fname, 'Resolution', 300);
    case 'pdf'
        exportgraphics(fig, fname, 'ContentType', 'vector');
    case 'fig'
        savefig(fig, fname);
    otherwise
        saveas(fig, fname);
end
fprintf('[paper_full_8023ck] saved %s\n', fname);
end

function local_write_readme(opt, dirs)
fid = fopen(fullfile(dirs.root, 'README_run.txt'), 'w');
if fid < 0, return; end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'run_paper_full_8023ck final pack\n');
fprintf(fid, 'Date: %s\n', datestr(now));
fprintf(fid, 'Trials: %d\n', opt.trials);
fprintf(fid, 'SNR: %s\n', mat2str(opt.snr));
fprintf(fid, 'Channel dir: %s\n', opt.channel_dir);
fprintf(fid, 'Static cases: C2M_10dB, C2M_14dB, C2M_16dB, C2C_10dB, C2C_18dB, C2C_20dB\n');
fprintf(fid, 'Markov states: C2M_10dB | C2M_14dB | C2M_16dB\n');
fprintf(fid, 'Proposed: algorithm6_msb_firbank with bank-local SMNLMS and endogenous-bias-aware gate.\n');
end
