%% Tilted Antenna Array S11 Simulation with Ground Material Sensing
% 32 RX antennas in 8x4 grid (100mm x 100mm) + 1 TX at center
% Array PCB: FR4 substrate, 1.6mm thick, rotated 45 degrees facing ground
% Center height: 6cm above ground
% Ground: material plane with variable conductivity/permittivity
% Frequency: 2.45 GHz
%
% Method: Mutual impedance + image theory with Fresnel reflection
% Antennas are conjugate-matched at 2.45 GHz in free space.
% Ground reflection perturbs the input impedance → changes S11.

clear; close all; clc;

%% Physical Constants
c = 299792458;              % Speed of light (m/s)
eps0 = 8.854187817e-12;     % Permittivity of free space (F/m)
mu0 = 4*pi*1e-7;            % Permeability of free space (H/m)
eta0 = 120*pi;              % Free-space impedance (~377 ohms)

%% Simulation Parameters
freq = 2.45e9;              % 2.45 GHz
lambda = c / freq;          % Wavelength (~122.4 mm)
k = 2*pi / lambda;          % Wavenumber
omega = 2*pi*freq;          % Angular frequency

% Array physical parameters
arrayWidth = 0.100;         % 100 mm
arrayHeight = 0.100;        % 100 mm
nCols = 4;                  % 4 columns
nRows = 8;                  % 8 rows
nRX = nCols * nRows;        % 32 RX antennas
nTotal = nRX + 1;           % 33 total (1 TX + 32 RX)

% PCB parameters
pcb_thickness = 0.0016;     % 1.6 mm FR4
pcb_er = 4.4;               % FR4 relative permittivity

% Geometry
tilt_angle = 45;            % degrees from horizontal
height_center = 0.060;      % 6 cm center height above ground

% Use free-space half-wave dipole (resonant at 2.45 GHz)
dipoleLength = lambda / 2;  % ~61.2 mm (resonant in free space)

fprintf('=== Tilted Antenna Array - Ground Material Sensing ===\n');
fprintf('Frequency: %.2f GHz (lambda = %.1f mm)\n', freq/1e9, lambda*1000);
fprintf('Dipole length (half-wave): %.1f mm\n', dipoleLength*1000);
fprintf('Array: %d x %d = %d RX + 1 TX = %d elements\n', nCols, nRows, nRX, nTotal);
fprintf('Array size: %.0f mm x %.0f mm\n', arrayWidth*1000, arrayHeight*1000);
fprintf('Tilt angle: %d degrees\n', tilt_angle);
fprintf('Center height: %.0f mm above ground\n', height_center*1000);
fprintf('PCB: FR4, %.1f mm, er=%.1f\n\n', pcb_thickness*1000, pcb_er);

%% Define Materials (from original SimulationScript.m)
materials = struct();
materials(1).name  = 'ABS';           materials(1).sigma = 1e-16;   materials(1).er = 3.2;
materials(2).name  = 'Acrylic';       materials(2).sigma = 1e-13;   materials(2).er = 3.5;
materials(3).name  = 'Ceramic';       materials(3).sigma = 1e-10;   materials(3).er = 50.0;
materials(4).name  = 'Concrete';      materials(4).sigma = 1e-7;    materials(4).er = 6.0;
materials(5).name  = 'Glass';         materials(5).sigma = 1e-15;   materials(5).er = 5.0;
materials(6).name  = 'HDPE';          materials(6).sigma = 1e-19;   materials(6).er = 2.3;
materials(7).name  = 'Human';         materials(7).sigma = 0.1;     materials(7).er = 30.0;
materials(8).name  = 'Metal';         materials(8).sigma = 3.8e7;   materials(8).er = 1.0;
materials(9).name  = 'PolyCarbonate'; materials(9).sigma = 1e-18;   materials(9).er = 3.0;
materials(10).name = 'Polyethylene';  materials(10).sigma = 1e-17;  materials(10).er = 2.1;
materials(11).name = 'RubberWood';    materials(11).sigma = 1e-13;  materials(11).er = 2.7;
materials(12).name = 'Styrofoam';     materials(12).sigma = 1e-15;  materials(12).er = 1.7;
nMaterials = length(materials);

%% Generate antenna positions
% Local frame: board in XY plane, Z = normal
dx = arrayWidth / (nCols - 1);
dz = arrayHeight / (nRows - 1);

local_pos = zeros(nTotal, 3);
local_pos(1, :) = [0, 0, 0];  % TX at center

idx = 2;
for row = 1:nRows
    for col = 1:nCols
        x = -arrayWidth/2 + (col-1) * dx;
        y = -arrayHeight/2 + (row-1) * dz;
        local_pos(idx, :) = [x, y, 0];
        idx = idx + 1;
    end
end

% Rotate 45 degrees about X-axis (board tilts toward ground)
theta_rad = deg2rad(tilt_angle);
Rx = [1, 0, 0; 0, cos(theta_rad), -sin(theta_rad); 0, sin(theta_rad), cos(theta_rad)];
rotated_pos = (Rx * local_pos')';

% Translate center to 6cm height
world_pos = rotated_pos;
world_pos(:,3) = world_pos(:,3) + height_center;

fprintf('Element heights above ground: %.1f mm to %.1f mm\n', ...
    min(world_pos(:,3))*1000, max(world_pos(:,3))*1000);

%% Visualize the 3D setup
figure('Name', '3D Setup View', 'Position', [50, 50, 800, 600]);

% Ground plane with 100mm depth (z = 0 to z = -100mm)
ground_size = 0.15;
% Top surface (z=0)
patch([-1 1 1 -1]*ground_size*1000, [-1 -1 1 1]*ground_size*1000, [0 0 0 0], ...
    [0.6 0.4 0.2], 'FaceAlpha', 0.4, 'EdgeColor', [0.4 0.3 0.1]);
hold on;
% Front face (y = -ground_size)
patch([-1 1 1 -1]*ground_size*1000, [-1 -1 -1 -1]*ground_size*1000, [0 0 -100 -100], ...
    [0.5 0.35 0.15], 'FaceAlpha', 0.3, 'EdgeColor', [0.4 0.3 0.1]);
% Right face (x = ground_size)
patch([1 1 1 1]*ground_size*1000, [-1 1 1 -1]*ground_size*1000, [0 0 -100 -100], ...
    [0.5 0.35 0.15], 'FaceAlpha', 0.3, 'EdgeColor', [0.4 0.3 0.1]);
% Bottom surface (z = -100mm)
patch([-1 1 1 -1]*ground_size*1000, [-1 -1 1 1]*ground_size*1000, [-100 -100 -100 -100], ...
    [0.4 0.3 0.1], 'FaceAlpha', 0.2, 'EdgeColor', [0.4 0.3 0.1]);

% PCB board
board_corners = [-arrayWidth/2, -arrayHeight/2, 0; arrayWidth/2, -arrayHeight/2, 0;
                  arrayWidth/2, arrayHeight/2, 0; -arrayWidth/2, arrayHeight/2, 0];
bc_world = (Rx * board_corners')';
bc_world(:,3) = bc_world(:,3) + height_center;
fill3(bc_world(:,1)*1000, bc_world(:,2)*1000, bc_world(:,3)*1000, ...
    [0.1 0.6 0.1], 'FaceAlpha', 0.5, 'EdgeColor', [0 0.4 0], 'LineWidth', 2);

% Antennas
scatter3(world_pos(2:end,1)*1000, world_pos(2:end,2)*1000, world_pos(2:end,3)*1000, ...
    40, 'b', 'filled');
scatter3(world_pos(1,1)*1000, world_pos(1,2)*1000, world_pos(1,3)*1000, ...
    120, 'r', '^', 'filled');

% Array normal
normal_local = [0, 0, -1];
normal_world = (Rx * normal_local')';
quiver3(world_pos(1,1)*1000, world_pos(1,2)*1000, world_pos(1,3)*1000, ...
    normal_world(1)*40, normal_world(2)*40, normal_world(3)*40, ...
    'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);

% Height line
plot3([0 0], [0 0], [0 height_center*1000], 'k--', 'LineWidth', 1);
text(2, 2, height_center*500, '60mm', 'FontSize', 10);

% Robot STL model (already in mm)
robot_stl = stlread('3D/RhinoV2Low.stl');
robot_patch = trisurf(robot_stl, 'FaceColor', [0.75 0.75 0.8], ...
    'EdgeColor', 'none', 'FaceAlpha', 0.7, 'FaceLighting', 'gouraud');
light('Position', [200 200 300]);

xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title('Antenna Array: 45° Tilt, 60mm Above Ground');
legend('Ground', '', '', '', 'PCB (FR4)', 'RX (32)', 'TX', 'Normal', '', 'Robot', 'Location', 'best');
grid on; view([-40, 20]); axis equal;
hold off;
savefig(gcf, 'Setup_3D.fig');
exportgraphics(gcf, 'Setup_3D.png', 'Resolution', 150);

%% PCB layout view
figure('Name', 'PCB Layout', 'Position', [900, 50, 500, 500]);
scatter(local_pos(2:end,1)*1000, local_pos(2:end,2)*1000, 50, 'b', 'filled');
hold on;
scatter(0, 0, 150, 'r', '^', 'filled');
rectangle('Position', [-50, -50, 100, 100], 'EdgeColor', [0 0.5 0], 'LineWidth', 2);
xlabel('X (mm)'); ylabel('Y (mm)');
title('PCB Layout (100mm x 100mm, FR4)');
legend('RX', 'TX', 'Location', 'best');
grid on; axis equal; xlim([-60 60]); ylim([-60 60]);
for i = 1:nRX
    text(local_pos(i+1,1)*1000+1, local_pos(i+1,2)*1000+2, sprintf('%d',i), 'FontSize', 7);
end
hold off;
savefig(gcf, 'PCB_Layout.fig');
exportgraphics(gcf, 'PCB_Layout.png', 'Resolution', 150);

%% Step 1: Compute free-space Z-matrix at center frequency (for matching)
fprintf('\nComputing free-space impedance (for conjugate matching)...\n');
Z_free = compute_Z_freeSpace(world_pos, nTotal, k, dipoleLength);

% Reference impedance for each port: conjugate match at 2.45 GHz
% Z_ref(i) = real part of Z_free(i,i) (reactance tuned out by matching network)
Z_ref = real(diag(Z_free));  % Matched to resistance at center freq
fprintf('Free-space self-impedance (TX): %.1f + j%.1f ohms\n', real(Z_free(1,1)), imag(Z_free(1,1)));
fprintf('Reference impedance (matched): %.1f ohms (avg)\n', mean(Z_ref));

%% Step 2: Frequency sweep with ground for each material
freqRange = linspace(2.0e9, 3.0e9, 101);
nFreqs = length(freqRange);

% Storage
S11_results = zeros(nMaterials, nRX, nFreqs);
S11_at_2p45 = zeros(nMaterials, nRX);

fprintf('\n=== Simulating %d materials across %d frequencies ===\n', nMaterials, nFreqs);

for mi = 1:nMaterials
    mat = materials(mi);
    fprintf('  [%2d/%d] %-15s (sigma=%.2e, er=%5.1f) ... ', ...
        mi, nMaterials, mat.name, mat.sigma, mat.er);
    
    for fi = 1:nFreqs
        f = freqRange(fi);
        lam_f = c / f;
        k_f = 2*pi / lam_f;
        w_f = 2*pi * f;
        
        % Complex permittivity of ground
        eps_c = mat.er - 1j * mat.sigma / (w_f * eps0);
        
        % Z-matrix with ground reflection
        Z_gnd = compute_Z_withGround(world_pos, nTotal, k_f, dipoleLength, eps_c);
        
        % Compute input impedance at each RX port
        % (with all other ports terminated in their matched impedance)
        % Simplified: use diagonal of Z-matrix (dominant term)
        % with correction from ground image
        for rx = 1:nRX
            p = rx + 1;  % port index (1=TX, 2:33=RX)
            Z_in = Z_gnd(p, p);
            % S11 relative to conjugate-matched reference
            Gamma = (Z_in - Z_ref(p)) / (Z_in + Z_ref(p));
            S11_results(mi, rx, fi) = 20*log10(abs(Gamma));
        end
    end
    
    [~, fidx] = min(abs(freqRange - freq));
    S11_at_2p45(mi,:) = S11_results(mi, :, fidx);
    fprintf('mean S11 = %.2f dB\n', mean(S11_at_2p45(mi,:)));
end

%% Also compute free-space S11 as baseline
fprintf('\nComputing free-space baseline...\n');
S11_freespace = zeros(nRX, nFreqs);
for fi = 1:nFreqs
    f = freqRange(fi);
    k_f = 2*pi * f / c;
    Z_fs = compute_Z_freeSpace(world_pos, nTotal, k_f, dipoleLength);
    for rx = 1:nRX
        p = rx + 1;
        Gamma = (Z_fs(p,p) - Z_ref(p)) / (Z_fs(p,p) + Z_ref(p));
        S11_freespace(rx, fi) = 20*log10(abs(Gamma));
    end
end

%% Plot S11 for each material
[~, fidx] = min(abs(freqRange - freq));

for mi = 1:nMaterials
    fig = figure('Name', sprintf('S11_%s', materials(mi).name), ...
        'Position', [100, 100, 900, 450], 'Visible', 'off');
    hold on;
    colors = lines(nRX);
    
    for rx = 1:nRX
        plot(freqRange/1e9, squeeze(S11_results(mi, rx, :)), ...
            'Color', colors(rx,:), 'LineWidth', 0.8);
    end
    
    % Also plot free-space mean as reference
    plot(freqRange/1e9, mean(S11_freespace, 1), 'k--', 'LineWidth', 1.5);
    
    xlabel('Frequency (GHz)');
    ylabel('S_{11} (dB)');
    title(sprintf('S_{11} vs Freq - Ground: %s (\\sigma=%.1e, \\epsilon_r=%.1f)', ...
        materials(mi).name, materials(mi).sigma, materials(mi).er));
    grid on;
    xline(2.45, '--r', '2.45 GHz', 'LineWidth', 1);
    yline(-10, '--', '-10 dB', 'Color', [0.5 0.5 0.5]);
    ylim([-40 0]);
    hold off;
    
    savefig(fig, sprintf('S11_%s.fig', materials(mi).name));
    exportgraphics(fig, sprintf('S11_%s.png', materials(mi).name), 'Resolution', 150);
    close(fig);
end

%% Comparison bar chart: Mean S11 at 2.45 GHz per material
figure('Name', 'S11 Material Comparison', 'Position', [100, 100, 900, 450]);
mean_s11 = mean(S11_at_2p45, 2);
bar(mean_s11);
set(gca, 'XTick', 1:nMaterials, 'XTickLabel', {materials.name}, 'XTickLabelRotation', 45);
xlabel('Ground Material');
ylabel('Mean S_{11} (dB)');
title('Mean S_{11} at 2.45 GHz vs Ground Material');
grid on;
yline(-10, '--r', '-10 dB');
savefig(gcf, 'S11_Comparison.fig');
exportgraphics(gcf, 'S11_Comparison.png', 'Resolution', 150);

%% Heatmap: S11 per antenna per material
figure('Name', 'S11 Heatmap', 'Position', [100, 100, 1000, 500]);
imagesc(S11_at_2p45);
colorbar;
colormap(jet);
set(gca, 'YTick', 1:nMaterials, 'YTickLabel', {materials.name});
xlabel('RX Antenna Index');
ylabel('Ground Material');
title('S_{11} (dB) at 2.45 GHz - Heatmap');
savefig(gcf, 'S11_Heatmap.fig');
exportgraphics(gcf, 'S11_Heatmap.png', 'Resolution', 150);

%% Print results table
fprintf('\n====================================================================\n');
fprintf('S11 RESULTS AT 2.45 GHz (Conjugate Matched, 45deg Tilt, 6cm Height)\n');
fprintf('====================================================================\n');
fprintf('%-15s | %12s | %6s | %10s | %10s | %10s\n', ...
    'Material', 'Sigma (S/m)', 'Er', 'Mean(dB)', 'Min(dB)', 'Max(dB)');
fprintf('%s\n', repmat('-', 1, 72));
for mi = 1:nMaterials
    fprintf('%-15s | %12.2e | %6.1f | %10.2f | %10.2f | %10.2f\n', ...
        materials(mi).name, materials(mi).sigma, materials(mi).er, ...
        mean(S11_at_2p45(mi,:)), min(S11_at_2p45(mi,:)), max(S11_at_2p45(mi,:)));
end
fprintf('%s\n', repmat('-', 1, 72));

%% Save all data
save('SimulationResults.mat', 'S11_results', 'S11_at_2p45', 'S11_freespace', ...
    'materials', 'freqRange', 'freq', 'world_pos', 'local_pos', ...
    'Z_ref', 'Z_free', 'nRX', 'nTotal', 'nMaterials', ...
    'lambda', 'height_center', 'tilt_angle', 'dipoleLength');
fprintf('\nResults saved to SimulationResults.mat\n');
fprintf('All figures saved as .fig and .png\n');
fprintf('Done.\n');

%% ============ LOCAL FUNCTIONS ============

function Z = compute_Z_freeSpace(positions, nTotal, k, L)
    % Free-space impedance matrix (no ground)
    Z = zeros(nTotal, nTotal);
    Z_self = dipole_self_impedance(k, L);
    for i = 1:nTotal
        for j = 1:nTotal
            if i == j
                Z(i,j) = Z_self;
            else
                d = norm(positions(i,:) - positions(j,:));
                Z(i,j) = mutual_impedance_dipoles(k, d, L);
            end
        end
    end
end

function Z = compute_Z_withGround(positions, nTotal, k, L, eps_c)
    % Impedance matrix with ground plane at z=0 (image theory)
    Z = zeros(nTotal, nTotal);
    Z_self = dipole_self_impedance(k, L);
    
    for i = 1:nTotal
        for j = 1:nTotal
            % Direct coupling
            if i == j
                Z_direct = Z_self;
            else
                d_direct = norm(positions(i,:) - positions(j,:));
                Z_direct = mutual_impedance_dipoles(k, d_direct, L);
            end
            
            % Image of element j mirrored below ground (z -> -z)
            pos_img_j = [positions(j,1), positions(j,2), -positions(j,3)];
            d_image = norm(positions(i,:) - pos_img_j);
            Z_img = mutual_impedance_dipoles(k, d_image, L);
            
            % Fresnel reflection at the ground
            % Angle from vertical (normal to ground)
            dz = positions(i,3) + positions(j,3);  % vertical path to image
            d_h = sqrt((positions(i,1)-positions(j,1))^2 + (positions(i,2)-positions(j,2))^2);
            theta = atan2(d_h, dz);
            
            Gamma = fresnel_avg(theta, eps_c);
            
            Z(i,j) = Z_direct + Gamma * Z_img;
        end
    end
end

function Gamma = fresnel_avg(theta, eps_c)
    % Average Fresnel reflection (TE+TM)/2
    ct = cos(theta);
    st = sin(theta);
    sq = sqrt(eps_c - st^2);
    
    G_TE = (ct - sq) / (ct + sq);
    G_TM = (eps_c*ct - sq) / (eps_c*ct + sq);
    Gamma = (G_TE + G_TM) / 2;
end

function Z_self = dipole_self_impedance(k, L)
    kL = k * L;
    eta = 120*pi;
    C_eu = 0.5772156649;
    
    Si2 = si_func(2*kL);
    Ci2 = ci_func(2*kL);
    Si1 = si_func(kL);
    Ci1 = ci_func(kL);
    
    R = eta/(2*pi) * (C_eu + log(kL) - Ci1 + ...
        0.5*sin(kL)*(Si2 - 2*Si1) + ...
        0.5*cos(kL)*(C_eu + log(kL/2) + Ci2 - 2*Ci1));
    
    X = eta/(4*pi) * (2*Si1 + cos(kL)*(2*Si1 - Si2) - ...
        sin(kL)*(2*Ci1 - Ci2 - Ci1));
    
    Z_self = R + 1j*X;
end

function Zm = mutual_impedance_dipoles(k, d, L)
    eta = 120*pi;
    h = L/2;
    r1 = sqrt(d^2 + h^2);
    
    kr0 = k*d;
    kr1 = k*r1;
    
    % Prevent numerical issues for very small distances
    if d < L/100
        Zm = 0;
        return;
    end
    
    Rm = eta/(4*pi) * (2*ci_func(kr0) - ci_func(kr1) - ci_func(kr1));
    Xm = -eta/(4*pi) * (2*si_func(kr0) - si_func(kr1) - si_func(kr1));
    Zm = Rm + 1j*Xm;
end

function Si = si_func(x)
    if abs(x) < 1e-10, Si = 0; return; end
    if abs(x) < 6
        Si = 0;
        for n = 0:30
            term = (-1)^n * x^(2*n+1) / ((2*n+1) * factorial(2*n+1));
            Si = Si + term;
            if abs(term) < 1e-14, break; end
        end
    else
        % Asymptotic auxiliary functions
        f = (1/x) * (1 - 2/(x^2) + 24/(x^4));
        g = (1/x^2) * (1 - 6/(x^2) + 120/(x^4));
        Si = pi/2 - f*cos(x) - g*sin(x);
        if x < 0, Si = -Si + pi; end
    end
end

function Ci = ci_func(x)
    if abs(x) < 1e-10, Ci = -700; return; end
    x = abs(x);
    if x < 6
        C_eu = 0.5772156649;
        Ci = C_eu + log(x);
        for n = 1:30
            term = (-1)^n * x^(2*n) / (2*n * factorial(2*n));
            Ci = Ci + term;
            if abs(term) < 1e-14, break; end
        end
    else
        % Asymptotic
        f = (1/x) * (1 - 2/(x^2) + 24/(x^4));
        g = (1/x^2) * (1 - 6/(x^2) + 120/(x^4));
        Ci = f*sin(x) - g*cos(x);
    end
end
