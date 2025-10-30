classdef mirStruct
    properties (Access=public)
        roughness {mustBeFloat}; % Placeholder for data property
        inharmonicity {mustBeFloat}; % Placeholder for metadata property
        novelty {mustBeFloat};
    end
    methods
        function obj = mirStruct(roughness, inharmonicity, novelty)
            obj.roughness = roughness;
            obj.inharmonicity = inharmonicity;
            obj.novelty = novelty;
        end
    end
end