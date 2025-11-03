classdef mirStruct
    properties (Access=public)
        roughness {mustBeFloat}; % Placeholder for data property
        inharmonicity {mustBeFloat}; % Placeholder for metadata property
        novelty {mustBeFloat};
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