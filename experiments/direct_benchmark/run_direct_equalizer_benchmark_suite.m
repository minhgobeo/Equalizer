function pkg = run_direct_equalizer_benchmark_suite(cfg, vars, base, mc)
%RUN_DIRECT_EQUALIZER_BENCHMARK_SUITE  Direct + adapted equalizer benchmarks.
%
% v65 change: Liu et al. 2023 SS-LMS DFE (algorithmic re-implementation)
% replaces the Dolatsara SCBO Tx-FIR baseline in the main suite, because
% Liu's work is receiver-side adaptive DFE which is closer to the proposed
% Algorithm 2 receiver. Dolatsara remains accessible individually via
% run_paper('dolatsara_scbo') for readers interested in Tx-side equalizer
% optimization.
%
% Suite contents (v65):
%   * Souza SM-sign-NLMS / VSS  (direct numerical baseline)
%   * Cui-style ExtraTrees-HMM  (adapted offline classifier)
%   * Liu-style SS-LMS DFE      (NEW: receiver adaptive DFE, algorithmic)
%   * Liu-style TA-SS-LMS DFE   (NEW: same with adaptive PAM4 thresholds)
%   * Chen-style single-pulse FFE/DFE  (adapted closed-form)

pkg = struct();
pkg.tag = 'direct_equalizer_benchmark_suite_v65';

fprintf('\n=== [direct_benchmark_suite] 1/4: Souza SM-sign ===\n');
pkg.souza = run_souza_smsign_direct_baseline(cfg, vars, base, mc);

fprintf('\n=== [direct_benchmark_suite] 2/4: Cui ExtraTrees-HMM (adapted) ===\n');
pkg.cui = run_cui_extratrees_hmm_direct_adapter(cfg, vars, base, mc);

fprintf('\n=== [direct_benchmark_suite] 3/4: Liu SS-LMS DFE (algorithmic, v65 NEW) ===\n');
pkg.liu = run_liu_ss_lms_direct_adapter(cfg, vars, base, mc);

fprintf('\n=== [direct_benchmark_suite] 4/4: Chen single-pulse (adapted) ===\n');
pkg.chen = run_chen_single_pulse_direct_adapter(cfg, vars, base, mc);

% Compose unified table at SNR=22 dB, both regimes (if available).
fprintf('\n========================================================\n');
fprintf('TABLE X. Direct & adapted equalizer benchmark @ SNR=22 dB\n');
fprintf('Method                                Severe BER   Realistic BER\n');
fprintf('--------------------------------------------------------\n');

snr_target = 22;
[bs_sev, bs_real] = pick_at_snr(pkg.souza.BER_smsign_fix, pkg.souza.snr_list, snr_target);
[bv_sev, bv_real] = pick_at_snr(pkg.souza.BER_smsign_vss, pkg.souza.snr_list, snr_target);
[ba_sev, ba_real] = pick_at_snr(pkg.souza.BER_alg2,        pkg.souza.snr_list, snr_target);
[bc_sev, bc_real] = pick_at_snr(pkg.cui.ber_grid,          pkg.cui.snr_list, snr_target);
[bL1_sev,bL1_real]= pick_at_snr(pkg.liu.BER_sslms,         pkg.liu.snr_list, snr_target);
[bL2_sev,bL2_real]= pick_at_snr(pkg.liu.BER_tasslms,       pkg.liu.snr_list, snr_target);
[bch_sev,bch_real]= pick_at_snr(pkg.chen.ber_grid,         pkg.chen.snr_list, snr_target);

print_row('SM-sign-NLMS (Souza, direct)',     bs_sev,  bs_real);
print_row('SM-sign-NLMS-VSS (Souza, direct)', bv_sev,  bv_real);
print_row('ExtraTrees-HMM adapted (Cui)',     bc_sev,  bc_real);
print_row('SS-LMS DFE (Liu, alg.)',           bL1_sev, bL1_real);
print_row('TA-SS-LMS DFE (Liu, alg.)',        bL2_sev, bL2_real);
print_row('Single-pulse FFE/DFE (Chen, ad.)', bch_sev, bch_real);
print_row('*Algorithm 2 (proposed HMM-MSB)*',         ba_sev,  ba_real);
fprintf('--------------------------------------------------------\n');

pkg.summary_table = struct();
pkg.summary_table.snr_target = snr_target;
pkg.summary_table.method = {'SM-sign-NLMS', 'SM-sign-NLMS-VSS', ...
    'ExtraTrees-HMM adapted', 'SS-LMS DFE (Liu)', 'TA-SS-LMS DFE (Liu)', ...
    'Single-pulse FFE/DFE adapted', 'Algorithm 2 proposed'};
pkg.summary_table.severe_BER    = [bs_sev, bv_sev, bc_sev, bL1_sev, bL2_sev, bch_sev, ba_sev];
pkg.summary_table.realistic_BER = [bs_real, bv_real, bc_real, bL1_real, bL2_real, bch_real, ba_real];
end

% =====================================================================
function [v_sev, v_real] = pick_at_snr(grid, snr_list, snr_target)
[~, idx] = min(abs(snr_list - snr_target));
if size(grid,2) >= 2
    v_sev  = grid(idx,1);
    v_real = grid(idx,2);
else
    v_sev  = grid(idx);
    v_real = NaN;
end
end

function print_row(name, v1, v2)
if isnan(v1), s1 = '   --   '; else, s1 = sprintf('%.3e', v1); end
if isnan(v2), s2 = '   --   '; else, s2 = sprintf('%.3e', v2); end
fprintf('%-37s  %-10s   %-10s\n', name, s1, s2);
end
