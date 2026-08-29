function generate_xflr5_doe(method, n_points, seed, outdir)
    % GENERATE_XFLR5_DOE
    % Programmatically builds a Design-of-Experiments (DOE) table and
    % writes XFLR5-compatible plane XML files complete with Polar v1.0 analysis definitions.
    %
    % Usage:
    %   generate_xflr5_doe()
    %   generate_xflr5_doe('lhs', 60, 7, 'doe_planes')

    if nargin < 1, method = 'full_factorial'; end
    if nargin < 2, n_points = 50; end
    if nargin < 3, seed = 42; end
    if nargin < 4, outdir = 'doe_planes'; end

    % ---------------------------------------------------------------------
    % Reference conditions & Design variable ranges
    % ---------------------------------------------------------------------
    S_REF = 20.130;       % m^2, reference planform area
    AIRFOIL = 'NACA 2412';
    SWEEP_LE_DEG = 0.0;   % leading-edge sweep (deg)
    DIHEDRAL_DEG = 0.0;

    AR_MIN = 6.0;  AR_MAX = 12.0;
    TR_MIN = 0.3;  TR_MAX = 1.0;
    TW_MIN = 0.0;  TW_MAX = 4.0;  % washout magnitude (deg)

    % Polar Analysis Settings (Type 1 - Fixed Velocity)
    ANALYSIS_VELOCITY = 15.0;  % m/s
    ALPHA_MIN = -4.0;          % deg
    ALPHA_MAX = 10.0;          % deg
    ALPHA_STEP = 0.5;          % deg

    % ---------------------------------------------------------------------
    % 1. DOE Table Generation
    % ---------------------------------------------------------------------
    if strcmp(method, 'full_factorial')
        % 5 x 5 x 5 = 125 points
        ar_vals = linspace(AR_MIN, AR_MAX, 5);
        tr_vals = linspace(TR_MIN, TR_MAX, 5);
        tw_vals = linspace(TW_MIN, TW_MAX, 5);

        [AR_grid, TR_grid, TW_grid] = ndgrid(ar_vals, tr_vals, tw_vals);
        AR = AR_grid(:);
        TR = TR_grid(:);
        Twist = TW_grid(:);
    elseif strcmp(method, 'lhs')
        rng(seed);
        unit_samples = lhsdesign(n_points, 3);
        AR = AR_MIN + unit_samples(:,1) * (AR_MAX - AR_MIN);
        TR = TR_MIN + unit_samples(:,2) * (TR_MAX - TR_MIN);
        Twist = TW_MIN + unit_samples(:,3) * (TW_MAX - TW_MIN);
    else
        error("method must be 'full_factorial' or 'lhs'");
    end

    % Derived planform geometry from AR, TR at fixed S_REF
    span_m = sqrt(AR .* S_REF);
    root_chord_m = (2 * S_REF) ./ (span_m .* (1 + TR));
    tip_chord_m = TR .* root_chord_m;
    MAC_m = (2.0 / 3.0) .* root_chord_m .* ((1 + TR + TR.^2) ./ (1 + TR));
    semi_span_m = span_m / 2.0;

    n_rows = length(AR);
    design_id = cell(n_rows, 1);
    xml_filename = cell(n_rows, 1);

    for i = 1:n_rows
        design_id{i} = sprintf('AR%.2f_TR%.2f_TW%.2f', AR(i), TR(i), Twist(i));
        xml_filename{i} = [design_id{i}, '.xml'];
    end

    % Construct table
    doe_table = table(AR, TR, Twist, span_m, root_chord_m, tip_chord_m, ...
                      MAC_m, semi_span_m, design_id, xml_filename);

    % ---------------------------------------------------------------------
    % 2. XML Generation & Writing
    % ---------------------------------------------------------------------
    if ~exist(outdir, 'dir')
        mkdir(outdir);
    end

    polar_params = struct(...
        'velocity', ANALYSIS_VELOCITY, ...
        'alpha_min', ALPHA_MIN, ...
        'alpha_max', ALPHA_MAX, ...
        'alpha_step', ALPHA_STEP);

    for i = 1:height(doe_table)
        xml_doc = make_plane_xml( ...
            doe_table.design_id{i}, ...
            doe_table.root_chord_m(i), ...
            doe_table.tip_chord_m(i), ...
            doe_table.semi_span_m(i), ...
            doe_table.Twist(i), ...
            S_REF, AIRFOIL, SWEEP_LE_DEG, DIHEDRAL_DEG, polar_params);

        filepath = fullfile(outdir, doe_table.xml_filename{i});
        xmlwrite(filepath, xml_doc);
    end

    % Save CSV table
    table_path = 'doe_table.csv';
    writetable(doe_table, table_path);

    fprintf('Generated %d design points (%s).\n', height(doe_table), method);
    disp(head(doe_table, 10));
    fprintf('\nPlane XMLs  -> %s  (%d files)\n', outdir, height(doe_table));
    fprintf('DOE table   -> %s\n', table_path);
end


% =========================================================================
% HELPER FUNCTIONS
% =========================================================================

function doc = make_plane_xml(design_id, root_chord, tip_chord, semi_span, ...
                              twist_deg, S_REF, airfoil, sweep_le_deg, ...
                              dihedral_deg, polar_params)

    doc = com.mathworks.xml.XMLUtils.createDocument('explane');
    explane = doc.getDocumentElement();
    explane.setAttribute('version', '1.0');

    % Units
    units = doc.createElement('Units');
    add_text_element(doc, units, 'length_unit_to_meter', '1');
    add_text_element(doc, units, 'mass_unit_to_kg', '1');
    explane.appendChild(units);

    % Plane
    plane = doc.createElement('Plane');
    add_text_element(doc, plane, 'Name', design_id);
    add_text_element(doc, plane, 'Description', ...
        sprintf('Auto-generated DOE point: AR/TR/Twist swept, S_ref=%.3f m^2', S_REF));
    
    plane.appendChild(doc.createElement('Inertia'));
    add_text_element(doc, plane, 'has_body', 'false');

    % Wing
    wing = doc.createElement('wing');
    add_text_element(doc, wing, 'Name', 'Main Wing');
    add_text_element(doc, wing, 'Type', 'MAINWING');

    color = doc.createElement('Color');
    add_text_element(doc, color, 'red', '135');
    add_text_element(doc, color, 'green', '135');
    add_text_element(doc, color, 'blue', '232');
    add_text_element(doc, color, 'alpha', '255');
    wing.appendChild(color);

    wing.appendChild(doc.createElement('Description'));
    add_text_element(doc, wing, 'Position', '0, 0, 0');
    add_text_element(doc, wing, 'Tilt_angle', '0.000');
    add_text_element(doc, wing, 'Symetric', 'true');
    add_text_element(doc, wing, 'isFin', 'false');
    add_text_element(doc, wing, 'isDoubleFin', 'false');
    add_text_element(doc, wing, 'isSymFin', 'false');

    w_inertia = doc.createElement('Inertia');
    add_text_element(doc, w_inertia, 'Volume_Mass', '0.000');
    wing.appendChild(w_inertia);

    % Sections
    sections_el = doc.createElement('Sections');
    x_offset_tip = semi_span * tand(sweep_le_deg);

    % Root section
    s1 = doc.createElement('Section');
    add_section_params(doc, s1, 0.0, root_chord, 0.0, 0.0, 0.0, airfoil);
    sections_el.appendChild(s1);

    % Tip section (washout = negative twist)
    s2 = doc.createElement('Section');
    add_section_params(doc, s2, semi_span, tip_chord, x_offset_tip, ...
                       dihedral_deg, -abs(twist_deg), airfoil);
    sections_el.appendChild(s2);

    wing.appendChild(sections_el);
    plane.appendChild(wing);

    % ---------------------------------------------------------------------
    % Embedded Polar Block (Version 1.0)
    % ---------------------------------------------------------------------
    polar = doc.createElement('Polar');
    polar.setAttribute('version', '1.0');
    
    add_text_element(doc, polar, 'Name', sprintf('%s_Polar', design_id));
    add_text_element(doc, polar, 'Type', '1');                  % Type 1: Fixed speed
    add_text_element(doc, polar, 'AnalysisMethod', 'VLM2');      % VLM2 formulation
    add_text_element(doc, polar, 'Speed', sprintf('%.2f', polar_params.velocity));
    add_text_element(doc, polar, 'AlphaMin', sprintf('%.2f', polar_params.alpha_min));
    add_text_element(doc, polar, 'AlphaMax', sprintf('%.2f', polar_params.alpha_max));
    add_text_element(doc, polar, 'AlphaStep', sprintf('%.2f', polar_params.alpha_step));
    add_text_element(doc, polar, 'Viscous', 'true');
    add_text_element(doc, polar, 'TiltAngle', '0.000');

    plane.appendChild(polar);
    explane.appendChild(plane);
end


function add_section_params(doc, sec, y_pos, chord, x_offset, dihedral, twist, airfoil)
    add_text_element(doc, sec, 'y_position', sprintf('%.4f', y_pos));
    add_text_element(doc, sec, 'Chord', sprintf('%.4f', chord));
    add_text_element(doc, sec, 'xOffset', sprintf('%.4f', x_offset));
    add_text_element(doc, sec, 'Dihedral', sprintf('%.4f', dihedral));
    add_text_element(doc, sec, 'Twist', sprintf('%.4f', twist));
    add_text_element(doc, sec, 'x_number_of_panels', '13');
    add_text_element(doc, sec, 'x_panel_distribution', 'COSINE');
    add_text_element(doc, sec, 'y_number_of_panels', '19');
    add_text_element(doc, sec, 'y_panel_distribution', 'INVERSE SINE');
    add_text_element(doc, sec, 'Left_Side_FoilName', airfoil);
    add_text_element(doc, sec, 'Right_Side_FoilName', airfoil);
end


function add_text_element(doc, parent, tag_name, value)
    elem = doc.createElement(tag_name);
    elem.appendChild(doc.createTextNode(value));
    parent.appendChild(elem);
end
