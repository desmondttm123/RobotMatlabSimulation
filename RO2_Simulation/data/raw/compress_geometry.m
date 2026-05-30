%% compress_geometry.m
% Converts ro2_geometry.mat into smaller part-files:
%   ro2_geometry_part1.mat ... ro2_geometry_partN.mat
%   ro2_geometry_meta.mat  (scalars + cfg)
%
% Shrinks void_indices from double -> uint16 (lossless: max index = 60800 < 65535)
% Splits 2400 samples across 4 files (~600 each)
%
% Use load_ro2_geometry() to load everything back identically.

clear; clc;
fprintf('Loading ro2_geometry.mat...\n');
S = load('ro2_geometry.mat');

%% Save metadata (scalars + cfg)
meta.bulk_nx = S.bulk_nx;
meta.bulk_ny = S.bulk_ny;
meta.bulk_nz = S.bulk_nz;
meta.cement_solid_density = S.cement_solid_density;
meta.soil_solid_density = S.soil_solid_density;
meta.total_cells = S.total_cells;
meta.cfg = S.cfg;
meta.n_samples = numel(S.all_geometry);
meta.n_parts = 4;
save('ro2_geometry_meta.mat', '-struct', 'meta', '-v7');
fprintf('Saved ro2_geometry_meta.mat\n');

%% Convert void_indices to uint16 and split
n_samples = numel(S.all_geometry);
n_parts = 4;
chunk_size = ceil(n_samples / n_parts);

for p = 1:n_parts
    idx_start = (p-1)*chunk_size + 1;
    idx_end = min(p*chunk_size, n_samples);
    
    part_data = S.all_geometry(idx_start:idx_end);
    
    % Convert void_indices double -> uint16
    for k = 1:numel(part_data)
        part_data(k).void_indices = uint16(part_data(k).void_indices);
    end
    
    all_geometry = part_data; %#ok<NASGU>
    fname = sprintf('ro2_geometry_part%d.mat', p);
    save(fname, 'all_geometry', '-v7');
    
    finfo = dir(fname);
    fprintf('Saved %s (samples %d-%d, %.1f MB)\n', fname, idx_start, idx_end, finfo.bytes/1e6);
end

%% Report
orig = dir('ro2_geometry.mat');
new_total = 0;
for p = 1:n_parts
    finfo = dir(sprintf('ro2_geometry_part%d.mat', p));
    new_total = new_total + finfo.bytes;
end
minfo = dir('ro2_geometry_meta.mat');
new_total = new_total + minfo.bytes;

fprintf('\nOriginal:  %.1f MB\n', orig.bytes/1e6);
fprintf('New total: %.1f MB (%.0f%% reduction)\n', new_total/1e6, (1-new_total/orig.bytes)*100);
fprintf('\nDone. Use load_ro2_geometry() to load data with the same interface.\n');
