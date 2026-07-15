%REPLOT_BLOCKB_FIGURES_V72  Regenerate Block B figures from existing CSV data.
%
% Crash-safe: each baud is wrapped in try-catch and writes a .done marker
% file on success.  Re-running skips bauds whose marker already exists.
% Delete the marker file to force a specific baud to re-run.
%
% Marker files:
%   paper_final_BlockB_26p5625GBd_*/baud26p5625GBd/replot_v72.done
%   paper_final_BlockB_53p125GBd_*/baud53p125GBd/replot_v72.done

addpath(genpath(pwd));

LOG_FILE = 'replot_blockB_figures_v72.log';
configs = { ...
    'paper_final_BlockB_26p5625GBd_10trials_80000samples_cleanSNR_v72', 26.5625e9; ...
    'paper_final_BlockB_53p125GBd_10trials_80000samples_cleanSNR_v72',  53.125e9; ...
};

local_log(LOG_FILE, 'START replot_blockB_figures_v72');

for ci = 1:size(configs,1)
    top_dir  = configs{ci,1};
    baud_hz  = configs{ci,2};
    baud_gbd = baud_hz / 1e9;
    baud_tag = strrep(sprintf('baud%gGBd', baud_gbd), '.', 'p');
    baud_dir = fullfile(top_dir, baud_tag);
    marker   = fullfile(baud_dir, 'replot_v72.done');

    % --- skip if already completed in a previous run ---
    if exist(marker, 'file')
        local_log(LOG_FILE, 'SKIP %.4g GBd — marker exists: %s', baud_gbd, marker);
        fprintf('SKIP %.4g GBd (already done, delete %s to force re-run)\n', baud_gbd, marker);
        continue;
    end

    fprintf('\n=== Replotting %s (%.4g GBd) ===\n', top_dir, baud_gbd);
    local_log(LOG_FILE, 'START %.4g GBd', baud_gbd);

    try
        run_blockB_tracking_stress_all_recursions_v72( ...
            'snr',        15:30, ...
            'profiles',   {'slow','medium','fast'}, ...
            'trials',     10, ...
            'samples',    80000, ...
            'trainLen',   12000, ...
            'baud',       baud_hz, ...
            'save_dir',   baud_dir, ...
            'fig_visible','off', ...
            'resume',     true);

        % Verify all 3 PNGs were actually written
        profiles_check = {'slow','medium','fast'};
        all_ok = true;
        for p = 1:numel(profiles_check)
            png = fullfile(baud_dir, ...
                sprintf('BlockB_TrackingStress_AllRecursions_%s.png', profiles_check{p}));
            if ~exist(png, 'file')
                local_log(LOG_FILE, 'MISSING PNG: %s', png);
                all_ok = false;
            end
        end

        if all_ok
            % Write marker so next crash-restart skips this baud
            fid = fopen(marker, 'w');
            fprintf(fid, '%s\n', datestr(now, 31));
            fclose(fid);
            local_log(LOG_FILE, 'DONE %.4g GBd — marker written', baud_gbd);
            fprintf('Done: %s\n', baud_dir);
        else
            local_log(LOG_FILE, 'WARN %.4g GBd — some PNGs missing, NOT marking done', baud_gbd);
            warning('Some PNGs missing for %.4g GBd, not writing done marker.', baud_gbd);
        end

    catch ME
        local_log(LOG_FILE, 'ERROR %.4g GBd: %s\n%s', baud_gbd, ME.message, ...
            getReport(ME, 'basic'));
        fprintf('[ERROR] %.4g GBd failed: %s\n', baud_gbd, ME.message);
        % Do NOT write marker — next run will retry this baud
    end
end

local_log(LOG_FILE, 'END replot_blockB_figures_v72');
fprintf('\nAll done. Log: %s\n', LOG_FILE);

% -------------------------------------------------------------------------
function local_log(log_file, fmt, varargin)
msg  = sprintf(fmt, varargin{:});
line = sprintf('[%s] %s\n', datestr(now, 31), msg);
fprintf('%s', line);
fid = fopen(log_file, 'a');
if fid > 0
    fprintf(fid, '%s', line);
    fclose(fid);
end
end
