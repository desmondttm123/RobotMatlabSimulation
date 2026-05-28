%% Antenna Array S11 Simulation (Analytical Approach)
% 32 RX antennas in 8x4 grid (100mm x 100mm) with TX at center
% Frequency: 2.45 GHz
% Method: Mutual impedance calculation for half-wave dipoles
% No toolboxes required beyond base MATLAB

clear; close all; clc;

%% Load shared configuration (for output directory)
SimConfig;

%% Parameters
freq = 2.45e9;              % 2.45 GHz
c = 299792458;              % Speed of light (m/s)
lambda = c / freq;          % Wavelength (~122.4 mm)
k = 2*pi / lambda;          % Wavenumber
Z0 = 50;                    % Reference impedance (50 ohm)

% Array dimensions
arrayWidth = 0.100;         % 100 mm in X
arrayHeight = 0.100;        % 100 mm in Z
nCols = 8;                  % 8 columns
nRows = 4;                  % 4 rows
nRX = nCols * nRows;        % 32 RX antennas
nTotal = nRX + 1;           % 33 total (1 TX + 32 RX)

% Spacing between elements
dx = arrayWidth / (nCols - 1);   % ~14.3 mm
dz = arrayHeight / (nRows - 1);  % ~33.3 mm

fprintf('=== Antenna Array S11 Simulation ===\n');
fprintf('Frequency: %.2f GHz (lambda = %.1f mm)\n', freq/1e9, lambda*1000);
fprintf('Array: %d x %d = %d RX elements + 1 TX = %d total\n', nCols, nRows, nRX, nTotal);
fprintf('Array size: %.0f mm x %.0f mm\n', arrayWidth*1000, arrayHeight*1000);
fprintf('Element spacing: dx = %.1f mm (%.3f lambda), dz = %.1f mm (%.3f lambda)\n', ...
    dx*1000, dx/lambda, dz*1000, dz/lambda);

%% Generate antenna positions
% TX at center (port 1), RX in 8x4 grid (ports 2-33)
positions = zeros(nTotal, 2);  % [x, z] positions in meters

% Port 1: TX at center
positions(1, :) = [0, 0];

% Ports 2-33: RX in 8x4 grid centered at origin
idx = 2;
for row = 1:nRows
    for col = 1:nCols
        x = -arrayWidth/2 + (col-1) * dx;
        z = -arrayHeight/2 + (row-1) * dz;
        positions(idx, :) = [x, z];
        idx = idx + 1;
    end
end

%% Compute mutual impedance matrix (Z-matrix) at center frequency
fprintf('\nComputing %dx%d impedance matrix...\n', nTotal, nTotal);

dipoleLength = lambda/2;  % Half-wave dipole at design frequency

Z = compute_Z_matrix(positions, nTotal, k, dipoleLength);

%% Convert Z-matrix to S-matrix at single frequency
% S = (Z - Z0*I) * inv(Z + Z0*I)
I_mat = eye(nTotal);
S_single = (Z - Z0*I_mat) / (Z + Z0*I_mat);

fprintf('\n--- S11 at %.2f GHz ---\n', freq/1e9);
fprintf('TX  (Port  1): S11 = %.2f dB\n', 20*log10(abs(S_single(1,1))));
fprintf('RX S11 range: %.2f dB to %.2f dB\n', ...
    20*log10(min(abs(diag(S_single(2:end,2:end))))), ...
    20*log10(max(abs(diag(S_single(2:end,2:end))))));

%% Frequency sweep for S11 plots
freqRange = linspace(1.5e9, 3.5e9, 201);  % 1.5 - 3.5 GHz
nFreqs = length(freqRange);

S11_all = zeros(nTotal, nFreqs);  % S11 in dB for each port across frequency

fprintf('Computing S-parameters across %d frequencies...\n', nFreqs);

for fi = 1:nFreqs
    f = freqRange(fi);
    lam = c / f;
    ki = 2*pi / lam;
    
    % Recompute Z-matrix at this frequency
    Zf = compute_Z_matrix(positions, nTotal, ki, dipoleLength);
    
    % S-parameters
    Sf = (Zf - Z0*I_mat) / (Zf + Z0*I_mat);
    
    % Store S11 for each port
    for p = 1:nTotal
        S11_all(p, fi) = 20*log10(abs(Sf(p,p)));
    end
    
    if mod(fi, 50) == 0
        fprintf('  Progress: %d/%d frequencies\n', fi, nFreqs);
    end
end

%% Plot S11 for all 32 RX antennas
figure('Name', 'S11 - All RX Antennas', 'Position', [100, 100, 900, 500]);
hold on;
colors = lines(nRX);

for i = 1:nRX
    portIdx = i + 1;  % RX ports are 2 through 33
    plot(freqRange/1e9, S11_all(portIdx, :), 'Color', colors(i,:), 'LineWidth', 0.8);
end

xlabel('Frequency (GHz)');
ylabel('S_{11} (dB)');
title(sprintf('S_{11} for %d RX Antennas (8x4 Grid, 100mm x 100mm) at 2.45 GHz', nRX));
grid on;
xline(2.45, '--r', '2.45 GHz', 'LineWidth', 1.5);
yline(-10, '--k', '-10 dB', 'LineWidth', 1);
legend_labels = arrayfun(@(x) sprintf('RX%d', x), 1:nRX, 'UniformOutput', false);
legend(legend_labels, 'Location', 'eastoutside', 'FontSize', 6);
hold off;

%% Plot TX S11
figure('Name', 'TX Antenna S11', 'Position', [100, 650, 700, 400]);
plot(freqRange/1e9, S11_all(1,:), 'b', 'LineWidth', 1.5);
xlabel('Frequency (GHz)');
ylabel('S_{11} (dB)');
title('S_{11} for TX Antenna (Port 1, Center of Array)');
grid on;
xline(2.45, '--r', '2.45 GHz', 'LineWidth', 1.5);
yline(-10, '--k', '-10 dB', 'LineWidth', 1);

%% Bar chart: S11 at 2.45 GHz for each RX
figure('Name', 'S11 at 2.45 GHz per RX', 'Position', [100, 400, 700, 300]);
[~, freqIdx] = min(abs(freqRange - freq));
s11_at_center = S11_all(2:end, freqIdx);

bar(1:nRX, s11_at_center);
xlabel('RX Antenna Index');
ylabel('S_{11} (dB)');
title(sprintf('S_{11} at %.2f GHz for Each RX Antenna', freq/1e9));
grid on;
yline(-10, '--r', '-10 dB threshold', 'LineWidth', 1.5);

%% Visualize array positions
figure('Name', 'Array Position Map', 'Position', [800, 400, 500, 500]);
scatter(positions(2:end,1)*1000, positions(2:end,2)*1000, 50, 'b', 'filled');
hold on;
scatter(positions(1,1)*1000, positions(1,2)*1000, 150, 'r', '^', 'filled');
xlabel('X (mm)');
ylabel('Z (mm)');
title('Antenna Array Position Map');
legend('RX', 'TX (center)', 'Location', 'best');
grid on;
axis equal;
xlim([-65 65]);
ylim([-65 65]);

% Label each RX
for i = 1:nRX
    text(positions(i+1,1)*1000 + 1.5, positions(i+1,2)*1000 + 2, ...
        sprintf('%d', i), 'FontSize', 7);
end
hold off;

%% Print final summary
fprintf('\n=== FINAL SUMMARY ===\n');
fprintf('TX (Port 1) S11 at 2.45 GHz: %.2f dB\n', S11_all(1, freqIdx));
fprintf('RX S11 at 2.45 GHz:\n');
fprintf('  Min: %.2f dB (RX%d)\n', min(s11_at_center), find(s11_at_center == min(s11_at_center), 1));
fprintf('  Max: %.2f dB (RX%d)\n', max(s11_at_center), find(s11_at_center == max(s11_at_center), 1));
fprintf('  Mean: %.2f dB\n', mean(s11_at_center));
fprintf('  Antennas with S11 < -10 dB: %d / %d\n', sum(s11_at_center < -10), nRX);

%% Save figures
savefig(1, fullfile(cfg.output_dir, 'S11_RX_All.fig'));
savefig(2, fullfile(cfg.output_dir, 'S11_TX.fig'));
savefig(3, fullfile(cfg.output_dir, 'S11_BarChart.fig'));
savefig(4, fullfile(cfg.output_dir, 'ArrayLayout.fig'));
fprintf('\nFigures saved to %s/\n', cfg.output_dir);
fprintf('Done.\n');

%% ============ LOCAL FUNCTIONS ============

function Z = compute_Z_matrix(positions, nTotal, k, L)
    % Compute the mutual impedance matrix for the array
    Z = zeros(nTotal, nTotal);
    Z_self = dipole_self_impedance(k, L);
    
    for i = 1:nTotal
        for j = 1:nTotal
            if i == j
                Z(i,j) = Z_self;
            else
                d = sqrt((positions(i,1) - positions(j,1))^2 + ...
                         (positions(i,2) - positions(j,2))^2);
                Z(i,j) = mutual_impedance_dipoles(k, d, L);
            end
        end
    end
end

function Z_self = dipole_self_impedance(k, L)
    % Self-impedance of a thin dipole of length L
    % Using Balanis formulation (Antenna Theory, Chapter 8)
    
    kL = k * L;
    eta = 120*pi;  % Free-space impedance (~377 ohms)
    C_euler = 0.5772156649;  % Euler-Mascheroni constant
    
    % Sine and cosine integrals
    Si_2kL = sine_integral(2*kL);
    Ci_2kL = cosine_integral(2*kL);
    Si_kL = sine_integral(kL);
    Ci_kL = cosine_integral(kL);
    
    % Input resistance (Balanis eq. 8-60a)
    R = eta/(2*pi) * (C_euler + log(kL) - Ci_kL + ...
        0.5*sin(kL)*(Si_2kL - 2*Si_kL) + ...
        0.5*cos(kL)*(C_euler + log(kL/2) + Ci_2kL - 2*Ci_kL));
    
    % Input reactance (Balanis eq. 8-60b)
    X = eta/(4*pi) * (2*Si_kL + cos(kL)*(2*Si_kL - Si_2kL) - ...
        sin(kL)*(2*Ci_kL - Ci_2kL - Ci_kL));
    
    Z_self = R + 1j*X;
end

function Zm = mutual_impedance_dipoles(k, d, L)
    % Mutual impedance between two parallel collinear half-wave dipoles
    % separated by distance d (side-by-side, coplanar)
    % Using the induced EMF method
    % Reference: Balanis "Antenna Theory" Chapter 8
    
    eta = 120*pi;
    
    % Geometry: two parallel dipoles of length L, separated by distance d
    % (both centered at same height, side-by-side arrangement)
    h = L/2;  % Half-length
    
    % Distances
    r0 = d;                         % center-to-center
    r1 = sqrt(d^2 + h^2);          % end-to-center  
    r2 = sqrt(d^2 + (2*h)^2);      % end-to-end
    
    % Mutual impedance for side-by-side parallel dipoles
    % Using approximation valid for half-wave dipoles
    kr0 = k*r0;
    kr1 = k*r1;
    kr2 = k*r2;
    
    % Real part (mutual resistance)
    Rm = eta/(4*pi) * (2*Ci_func(kr0) - Ci_func(kr1) - Ci_func(kr1));
    
    % Imaginary part (mutual reactance)
    Xm = -eta/(4*pi) * (2*Si_func(kr0) - Si_func(kr1) - Si_func(kr1));
    
    Zm = Rm + 1j*Xm;
end

function Si = sine_integral(x)
    % Sine integral Si(x) = integral from 0 to x of sin(t)/t dt
    if abs(x) < 1e-10
        Si = 0;
        return;
    end
    % Use series expansion for small x, quadrature for larger
    if abs(x) < 4
        % Taylor series: Si(x) = sum_{n=0}^{inf} (-1)^n * x^(2n+1) / ((2n+1)*(2n+1)!)
        Si = 0;
        for n = 0:30
            term = (-1)^n * x^(2*n+1) / ((2*n+1) * factorial(2*n+1));
            Si = Si + term;
            if abs(term) < 1e-15
                break;
            end
        end
    else
        Si = integral(@(t) sin(t)./t, 0, abs(x), 'RelTol', 1e-10);
        if x < 0
            Si = -Si;
        end
    end
end

function Ci = cosine_integral(x)
    % Cosine integral Ci(x) = gamma + ln(x) + integral_0^x (cos(t)-1)/t dt
    C_euler = 0.5772156649;
    if abs(x) < 1e-10
        Ci = -700;  % Approximate -inf
        return;
    end
    x = abs(x);
    if x < 4
        % Series: Ci(x) = gamma + ln(x) + sum_{n=1}^{inf} (-1)^n * x^(2n) / (2n*(2n)!)
        Ci = C_euler + log(x);
        for n = 1:30
            term = (-1)^n * x^(2*n) / (2*n * factorial(2*n));
            Ci = Ci + term;
            if abs(term) < 1e-15
                break;
            end
        end
    else
        Ci = C_euler + log(x) + integral(@(t) (cos(t)-1)./t, 0, x, 'RelTol', 1e-10);
    end
end

function Si = Si_func(x)
    Si = sine_integral(x);
end

function Ci = Ci_func(x)
    Ci = cosine_integral(x);
end
