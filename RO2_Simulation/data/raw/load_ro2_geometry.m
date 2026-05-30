function S = load_ro2_geometry()
%LOAD_RO2_GEOMETRY Load split geometry files with the same interface as the original.
%
%   S = load_ro2_geometry();
%
%   Returns a struct identical to:  S = load('ro2_geometry.mat');
%   Fields: all_geometry, bulk_nx, bulk_ny, bulk_nz, cement_solid_density,
%           soil_solid_density, total_cells, cfg
%
%   void_indices are returned as double (converted back from uint16).

    data_dir = fileparts(mfilename('fullpath'));
    
    % Load metadata
    meta = load(fullfile(data_dir, 'ro2_geometry_meta.mat'));
    S.bulk_nx = meta.bulk_nx;
    S.bulk_ny = meta.bulk_ny;
    S.bulk_nz = meta.bulk_nz;
    S.cement_solid_density = meta.cement_solid_density;
    S.soil_solid_density = meta.soil_solid_density;
    S.total_cells = meta.total_cells;
    S.cfg = meta.cfg;
    
    % Load and concatenate parts
    parts = cell(1, meta.n_parts);
    for p = 1:meta.n_parts
        fname = fullfile(data_dir, sprintf('ro2_geometry_part%d.mat', p));
        tmp = load(fname, 'all_geometry');
        % Convert uint16 back to double for compatibility
        for k = 1:numel(tmp.all_geometry)
            tmp.all_geometry(k).void_indices = double(tmp.all_geometry(k).void_indices);
        end
        parts{p} = tmp.all_geometry;
    end
    S.all_geometry = [parts{:}];
end
