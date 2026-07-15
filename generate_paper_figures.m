%% GENERATE_PAPER_FIGURES - Create 7 key figures for paper
clear; close all; clc;

% Load Block A data
load('paper_final_all_blocks_v72/final_all_blocks_v72.mat', 'out_all');
blockA = out_all.blockA_severe;

snr_vec = blockA.snr_list;
ber_mat = blockA.BER;  % (Nsnr × 10 algorithms)

% Algorithm indices (based on earlier output)
idx_alg2 = 1;     % Algorithm 2 (proposed)
idx_oracle = 2;   % Oracle
idx_alg1 = 3;     % Algorithm 1
idx_nlms = 4;     % NLMS
idx_smsign = 5;   % SM-sign-NLMS
idx_vss = 6;      % VSS

fprintf('Generating 7 figures for paper...\n');

%% ========================================================================
% FIGURE 3: BER Curves (SNR vs BER for multiple algorithms)
%========================================================================

fig = figure('Position', [100 100 900 600]);
semilogy(snr_vec, ber_mat(:, idx_alg2), 'o-', 'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [0 0.7 0], 'DisplayName', 'Algorithm 2 (Proposed)');
hold on;
semilogy(snr_vec, ber_mat(:, idx_alg1), 's-', 'LineWidth', 2.5, 'MarkerSize', 7, 'Color', [1 0 0], 'DisplayName', 'Algorithm 1 (Single-Bank)');
semilogy(snr_vec, ber_mat(:, idx_nlms), '^-', 'LineWidth', 2, 'MarkerSize', 6, 'Color', [0 0 1], 'DisplayName', 'NLMS');
semilogy(snr_vec, ber_mat(:, idx_smsign), 'v-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0.7 0 0.7], 'DisplayName', 'SM-sign-NLMS');
semilogy(snr_vec, ber_mat(:, idx_vss), 'd--', 'LineWidth', 2, 'MarkerSize', 6, 'Color', [1 0.5 0], 'DisplayName', 'VSS (Anti-waterfall proof)');

% KP4 threshold line
yline(2.4e-4, 'k--', 'LineWidth', 2, 'DisplayName', 'KP4 FEC Threshold');

xlabel('SNR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('BER', 'FontSize', 12, 'FontWeight', 'bold');
title('Figure 3: Block A BER Curves (Severe Markov Stress Test)', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'southwest', 'FontSize', 10);
grid on; grid minor;
set(gca, 'FontSize', 10);
xlim([14.5 30.5]);
ylim([1e-7 1e-1]);

savefig('FIGURE_3_BlockA_BER_Curves.fig');
print('FIGURE_3_BlockA_BER_Curves.png', '-dpng', '-r300');
close(fig);
fprintf('✓ Figure 3 saved: BlockA BER Curves\n');

%% ========================================================================
% FIGURE 4: Gap Growth vs SNR
%========================================================================

fig = figure('Position', [100 100 900 600]);

% Compute gap ratio (Alg1 / Alg2)
gap_vec = ber_mat(:, idx_alg1) ./ ber_mat(:, idx_alg2);
gap_vec(isinf(gap_vec) | isnan(gap_vec)) = [];
snr_vec_gap = snr_vec(1:length(gap_vec));

semilogy(snr_vec_gap, gap_vec, 'ro-', 'LineWidth', 3, 'MarkerSize', 10, 'DisplayName', 'Gap = Alg1 BER / Alg2 BER');
hold on;

% Highlight key regions
fill([14.5 20.5 20.5 14.5], [0.5 0.5 200 200], [0.9 1 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'DisplayName', 'Diffusion region');
fill([20.5 30.5 30.5 20.5], [0.5 0.5 200 200], [1 0.9 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'DisplayName', 'Burden dominance');

xlabel('SNR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Improvement Factor (×)', 'FontSize', 12, 'FontWeight', 'bold');
title('Figure 4: BER Gap Growth vs SNR - Signature of Burden Dominance', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northwest', 'FontSize', 10);
grid on; grid minor;
set(gca, 'FontSize', 10);
xlim([14.5 22.5]);
ylim([0.5 200]);
text(17, 3, 'Diffusion + Burden', 'FontSize', 11);
text(21.5, 80, 'Burden Dominates', 'FontSize', 11, 'Color', 'red', 'FontWeight', 'bold');

savefig('FIGURE_4_Gap_vs_SNR.fig');
print('FIGURE_4_Gap_vs_SNR.png', '-dpng', '-r300');
close(fig);
fprintf('✓ Figure 4 saved: Gap Growth vs SNR\n');

%% ========================================================================
% FIGURE 5: Floor Decomposition (Conceptual Stacked Area)
%========================================================================

fig = figure('Position', [100 100 900 600]);

% Conceptual decomposition: Diffusion, Burden, Drift
% Scaled to show behavior with SNR
snr_plot = 15:25;
diffusion = 1e-4 * 10.^((20 - snr_plot) / 10);  % Decreases with SNR
burden = 1e-4 * ones(size(snr_plot));             % Constant with SNR
drift = 1e-5 * (1 + 0.1 * (20 - snr_plot).^2);   % Small, varies with SNR

% Total floor
total_floor = diffusion + burden + drift;

% Stacked area
x_fill = [snr_plot, fliplr(snr_plot)];

area1 = diffusion;
area2 = diffusion + burden;
area3 = total_floor;

fill(x_fill, [area1, fliplr(area1*0)], [0.3 0.8 1], 'FaceAlpha', 0.6, 'EdgeColor', 'none', 'DisplayName', 'Diffusion (∝ SNR^{-1})');
hold on;
fill(x_fill, [area2, fliplr(area1)], [1 0.6 0.3], 'FaceAlpha', 0.6, 'EdgeColor', 'none', 'DisplayName', 'Burden (irreducible, constant)');
fill(x_fill, [area3, fliplr(area2)], [0.8 0.8 1], 'FaceAlpha', 0.6, 'EdgeColor', 'none', 'DisplayName', 'Drift (small, ∝ Δ)');

plot(snr_plot, total_floor, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Total Floor (Alg1)');

xlabel('SNR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Tracking Floor (dB)', 'FontSize', 12, 'FontWeight', 'bold');
title('Figure 5: Floor Decomposition - Why Burden Dominates at High SNR', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
grid on; grid minor;
set(gca, 'FontSize', 10);
xlim([15 25]);
text(16.5, 1.5e-4, 'Proposition 1: Δ* = Δ_{diff} + Δ_{burden} + Δ_{drift}', ...
    'FontSize', 10);

savefig('FIGURE_5_Floor_Decomposition.fig');
print('FIGURE_5_Floor_Decomposition.png', '-dpng', '-r300');
close(fig);
fprintf('✓ Figure 5 saved: Floor Decomposition\n');

%% ========================================================================
% FIGURE 6: Simple Comparison Bar Chart
%========================================================================

fig = figure('Position', [100 100 800 500]);

methods = {'Alg2', 'Alg1', 'NLMS', 'SM-sign', 'VSS'};
ber_22 = [ber_mat(find(snr_vec==22), [idx_alg2, idx_alg1, idx_nlms, idx_smsign, idx_vss])];

b = bar(ber_22, 'FaceColor', [0.2 0.6 1]);
b.FaceColor = 'flat';
b.CData = [0.2 0.6 1; 1 0.2 0.2; 0 0 1; 0.7 0 0.7; 1 0.5 0];
hold on;

set(gca, 'YScale', 'log');
set(gca, 'XTickLabel', methods);
ylabel('BER', 'FontSize', 12, 'FontWeight', 'bold');
title('Figure 6: Method Comparison @ SNR 22 dB', 'FontSize', 13, 'FontWeight', 'bold');
grid on; grid minor;
set(gca, 'FontSize', 10);
ylim([1e-7 1e-1]);

% Add value labels
for k = 1:length(ber_22)
    text(k, ber_22(k)*2, sprintf('%.2e', ber_22(k)), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'FontSize', 9);
end

savefig('FIGURE_6_Method_Comparison.fig');
print('FIGURE_6_Method_Comparison.png', '-dpng', '-r300');
close(fig);
fprintf('✓ Figure 6 saved: Method Comparison\n');

%% ========================================================================
% SUMMARY
%========================================================================

fprintf('\n========== FIGURE GENERATION SUMMARY ==========\n');
fprintf('✓ Figure 3: Block A BER Curves (Severe Markov)\n');
fprintf('✓ Figure 4: BER Gap Growth vs SNR (Burden Signature)\n');
fprintf('✓ Figure 5: Floor Decomposition (Stacked)\n');
fprintf('✓ Figure 6: Method Comparison Bar Chart\n');
fprintf('\nNote: Figures 1, 2, 7 require additional data sources:\n');
fprintf('  - Figure 1: Theorem 1 frozen-state trajectories (from theorem validation)\n');
fprintf('  - Figure 2: DFE contamination timeline (conceptual, can be drawn)\n');
fprintf('  - Figure 7: BlockC burden metrics (need endogenous-aware data)\n\n');

fprintf('All figures saved as:\n');
fprintf('  - .fig (MATLAB format)\n');
fprintf('  - .png (publication quality, 300 dpi)\n');
