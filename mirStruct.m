%   This is a structure that has properties corresponding to 
%   MIRToolbox parameters used in the MusicAugmenter
classdef mirStruct
    properties (Access=public)
        roughness {mustBeFloat}; % range [0,500]?
        inharmonicity {mustBeFloat}; % Range[0,1]
        brightness
    end
    methods
        function obj = mirStruct(opts)
            arguments
                opts.?mirStruct
            end
            for prop = string(fieldnames(opts))'
                obj.(prop) = opts.(prop);
            end
        end
    end
end