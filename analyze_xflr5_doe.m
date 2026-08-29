function doe_results = analyze_xflr5_doe(data_dir)
    % ANALYZE_XFLR5_DOE
    % Parses 50 XFLR5 polar CSV files, extracts cruise metrics,
    % filters by stall constraint, and generates complete trade study plots.

    if nargin < 1, data_dir = pwd; end

    % 1. Search recursively in current directory AND all subfolders
    files = dir(fullfile(data_dir, '**', '*.csv'));
    CRUISE_CL = 0.50;  
    STALL_CONSTRAINT_CLMAX = 1.58; 

    n_files = length(files);
    Plane = cell(n_files, 1);
    AR = zeros(n_files, 1); TR = zeros(n_files, 1); TW = zeros(n_files, 1);
    LD_cruise = zeros(n_files, 1); CDi_cruise = zeros(n_files, 1); CD_cruise = zeros(n_files, 1);
    CL_max = zeros(n_files, 1); Alpha_CLmax = zeros(n_files, 1); Cm_alpha = zeros(n_files, 1);

    valid_count = 0;

    for k = 1:n_files
        fname = files(k).name;
        filepath = fullfile(files(k).folder, fname);

        % Skip generated output tables
        if contains(fname, 'doe_table') || contains(fname, 'NEW') || contains(fname, 'metrics') || contains(fname, 'extracted')
            continue; 
        end

        % Parse AR, TR, TW directly from filename or header
        tokens = regexp(fname, 'AR([\d\.]+)_TR([\d\.]+)_TW([\d\.]+)', 'tokens');
        if isempty(tokens)
            % Try header if filename doesn't match
            fid = fopen(filepath, 'r');
            if fid == -1, continue; end
            plane_name_hdr = '';
            while ~feof(fid)
                tline = fgetl(fid);
                if contains(tline, 'Plane name')
                    parts = split(tline, ':'); plane_name_hdr = strtrim(parts{end}); break;
                end
            end
            fclose(fid);
            tokens = regexp(plane_name_hdr, 'AR([\d\.]+)_TR([\d\.]+)_TW([\d\.]+)', 'tokens');
        end

        if isempty(tokens), continue; end

        % Find data start line
        fid = fopen(filepath, 'r');
        if fid == -1, continue; end
        data_start_line = 0; line_idx = 0;
        while ~feof(fid)
            line_idx = line_idx + 1;
            tline = fgetl(fid);
            if startsWith(strtrim(tline), 'alpha')
                data_start_line = line_idx; break;
            end
        end
        fclose(fid);
        if data_start_line == 0, continue; end

        % Import polar data
        opts = detectImportOptions(filepath, 'FileType', 'text', 'HeaderLines', data_start_line - 1);
        opts.VariableNamingRule = 'preserve';
        polar_data = readtable(filepath, opts);
        polar_data.Properties.VariableNames = strtrim(polar_data.Properties.VariableNames);

        if ~ismember('CL', polar_data.Properties.VariableNames) || ~ismember('CD', polar_data.Properties.VariableNames)
            continue;
        end

        valid_count = valid_count + 1;
        ar_v = str2double(tokens{1}{1});
        tr_v = str2double(tokens{1}{2});
        tw_v = str2double(tokens{1}{3});

        Plane{valid_count} = sprintf('AR%.2f_TR%.2f_TW%.2f', ar_v, tr_v, tw_v);
        AR(valid_count) = ar_v;
        TR(valid_count) = tr_v;
        TW(valid_count) = tw_v;

        polar_data.LD = polar_data.CL ./ polar_data.CD;
        
        [cl_max_val, max_idx] = max(polar_data.CL);
        CL_max(valid_count) = cl_max_val;
        Alpha_CLmax(valid_count) = polar_data.alpha(max_idx);

        [sorted_CL, sort_idx] = sort(polar_data.CL);
        LD_cruise(valid_count) = interp1(sorted_CL, polar_data.LD(sort_idx), CRUISE_CL, 'linear', 'extrap');
        CDi_cruise(valid_count) = interp1(sorted_CL, polar_data.CDi(sort_idx), CRUISE_CL, 'linear', 'extrap');
        CD_cruise(valid_count) = interp1(sorted_CL, polar_data.CD(sort_idx), CRUISE_CL, 'linear', 'extrap');

        lin_mask = polar_data.alpha >= -2.0 & polar_data.alpha <= 8.0;
        if sum(lin_mask) > 1
            p_cm = polyfit(polar_data.alpha(lin_mask), polar_data.Cm(lin_mask), 1);
            Cm_alpha(valid_count) = p_cm(1);
        else
            Cm_alpha(valid_count) = NaN;
        end
    end

    if valid_count == 0
        error('NO VALID POLAR CSV FILES FOUND! Please check that your .csv files are located in "%s" or its subfolders.', data_dir);
    end

    % Truncate to valid design points
    doe_results = table(Plane(1:valid_count), AR(1:valid_count), TR(1:valid_count), TW(1:valid_count), ...
                        LD_cruise(1:valid_count), CDi_cruise(1:valid_count), CD_cruise(1:valid_count), ...
                        CL_max(1:valid_count), Alpha_CLmax(1:valid_count), Cm_alpha(1:valid_count), ...
                        'VariableNames', {'Plane', 'AR', 'TR', 'TW', 'LD_cruise', 'CDi_cruise', 'CD_cruise', 'CL_max', 'Alpha_CLmax', 'Cm_alpha'});
    
    % Sort table logically
    doe_results = sortrows(doe_results, {'AR', 'TR', 'TW'});
    writetable(doe_results, 'extracted_50_designs_metrics.csv');
    fprintf('SUCCESSFULLY PARSED AND EXTRACTED %d DESIGN POINTS!\n', valid_count);

    % ---------------------------------------------------------------------
    % VISUALIZATION GENERATION (4 SUBPLOTS)
    % ---------------------------------------------------------------------
    figure('Position', [100, 100, 1200, 850], 'Name', 'XFLR5 Trade Study Analysis');

    % --- 1. Contour Map (AR = 7.5) ---
    subplot(2, 2, 1);
    ar75_mask = doe_results.AR == 7.5;
    tr_u = unique(doe_results.TR(ar75_mask));
    tw_u = unique(doe_results.TW(ar75_mask));
    
    if ~isempty(tr_u) && ~isempty(tw_u)
        [TR_grid, TW_grid] = meshgrid(tr_u, tw_u);
        LD_grid = zeros(size(TR_grid));

        for i = 1:length(tw_u)
            for j = 1:length(tr_u)
                m = doe_results(doe_results.AR == 7.5 & doe_results.TR == tr_u(j) & doe_results.TW == tw_u(i), :);
                if ~isempty(m), LD_grid(i,j) = m.LD_cruise(1); end
            end
        end

        contourf(TR_grid, TW_grid, LD_grid, 15, 'LineColor', 'none');
        colorbar; colormap(gca, 'parula'); hold on;
        plot(doe_results.TR(ar75_mask), doe_results.TW(ar75_mask), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 5);

        feasible = doe_results(doe_results.CL_max >= STALL_CONSTRAINT_CLMAX, :);
        if ~isempty(feasible)
            [~, opt_idx] = max(feasible.LD_cruise);
            optimum = feasible(opt_idx, :);
            plot(optimum.TR, optimum.TW, 'rp', 'MarkerFaceColor', 'r', 'MarkerSize', 16);
        else
            [~, opt_idx] = max(doe_results.LD_cruise);
            optimum = doe_results(opt_idx, :);
        end
        xlabel('Taper Ratio (TR)'); ylabel('Washout Twist (TW, deg)');
        title('Cruise Efficiency Contour (L/D_{cruise} at C_L=0.5, AR=7.5)'); grid on;
    end

    % --- 2. Safe Parallel Coordinates Plot ---
    subplot(2, 2, 2);
    pc_raw = [doe_results.AR, doe_results.TR, doe_results.TW, doe_results.LD_cruise, doe_results.CL_max];
    pc_norm = (pc_raw - min(pc_raw, [], 1)) ./ (max(pc_raw, [], 1) - min(pc_raw, [], 1) + 1e-9);
    
    x_coords = 1:size(pc_norm, 2);
    hold on;
    cmap = lines(height(doe_results));
    for r = 1:height(doe_results)
        plot(x_coords, pc_norm(r, :), 'Color', [cmap(r, :), 0.4], 'LineWidth', 1.2);
    end
    for c = 1:length(x_coords)
        xline(c, 'k-', 'Alpha', 0.2);
    end
    set(gca, 'XTick', x_coords, 'XTickLabel', {'AR', 'TR', 'TW', 'L/D', 'C_{L,max}'});
    ylabel('Normalized Scale (0 to 1)');
    title('Parallel Coordinates: Interactions Across All Designs');
    grid on; xlim([0.8, length(x_coords) + 0.2]); ylim([0, 1]);

    % --- 3. Pareto Trade-Off ---
    subplot(2, 2, 3);
    scatter(doe_results.CL_max, doe_results.LD_cruise, 60, doe_results.TR, 'filled', 'MarkerEdgeColor', 'k');
    cb = colorbar; cb.Label.String = 'Taper Ratio TR'; hold on;
    xline(STALL_CONSTRAINT_CLMAX, 'r--', 'LineWidth', 1.5, 'Label', 'Stall Constraint (C_{L,max} \geq 1.58)');
    
    if exist('optimum', 'var')
        plot(optimum.CL_max, optimum.LD_cruise, 'm*', 'MarkerSize', 18);
    end
    xlabel('Maximum Lift Coefficient (C_{L,max})'); ylabel('Cruise Efficiency (L/D)_{cruise}');
    title('Pareto Trade-Off: (L/D)_{cruise} vs C_{L,max}'); grid on;

    % --- 4. Sensitivity Plot ---
    subplot(2, 2, 4);
    tr_list = unique(doe_results.TR(ar75_mask));
    for idx = 1:length(tr_list)
        tr_val = tr_list(idx);
        sub = doe_results(doe_results.AR == 7.5 & doe_results.TR == tr_val, :);
        [~, s_idx] = sort(sub.TW);
        plot(sub.TW(s_idx), sub.LD_cruise(s_idx), 'd-', 'LineWidth', 1.5, 'DisplayName', sprintf('AR=7.5 TR=%.2f', tr_val)); hold on;
    end

    if exist('optimum', 'var')
        plot(optimum.TW, optimum.LD_cruise * 0.985, 's', 'MarkerSize', 10, 'MarkerFaceColor', 'g', ...
             'DisplayName', sprintf('3D Panel Opt: L/D=%.2f', optimum.LD_cruise * 0.985));
    end

    xlabel('Washout Twist (TW, deg)'); ylabel('Cruise Efficiency (L/D)_{cruise}');
    title('Efficiency Sensitivity across Taper Ratio Families (AR=7.5)');
    legend('Location', 'southwest', 'FontSize', 8); grid on;
    
    drawnow; % Instantly render figure window
    % Add this as the very last line of analyze_xflr5_doe.m
exportgraphics(gcf, 'xflr5_50_designs_trade_study.png', 'Resolution', 300);
end
