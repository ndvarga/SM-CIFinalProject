classdef mirStruct
    properties (Access=public)
        roughness {mustBeFloat}; % range [0,500]?
        inharmonicity {mustBeFloat}; % Range[0,1]
        novelty {mustBeFloat}; % not sure of range
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