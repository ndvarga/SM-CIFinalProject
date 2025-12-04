classdef  mirtoolboxWizard < handle
    %mirtoolboxWizard Real-time virtual listener
    %   A real-time virtual listener that uses MIRToolbox to assess user
    %   defined musical parameters within an input audio signal

    %{
        mirtoolboxWizard
        Copyright 2025 (c) Aston K McCullough
        Updated for MUST 5510 (v09172025)
        Northeastern University


        original version:
        mirtoolboxWizard
        Copyright 2025 (c) Aston K McCullough
        MUST 5973
        Northeastern University

    %}


    properties (Access = public)
        roughness
        brightness
        inharmonicity
        a % MIRToolbox audio object

    end

    properties (Access = private)
        tempBuffer

    end

    events
        updateJudgement
    end

    methods

        function obj = mirtoolboxWizard(audio)
            %mirtoolboxWizard
            % Construct MIRToolbox object
            obj.a = audio;
            addlistener(obj,'updateJudgement',@newJudgement);
        end

        function src = step(src,audio)

            %METHOD1 Summary of this method goes here

            % concatenating audio
            if size(src.a,2) == 1 && size(audio,2) == 2
                audio = mean(audio,2);

            elseif size(src.a,2) == 2 && size(audio,2) == 1
                src.a = mean(src.a,2);
            end

            if isempty(src.a)

                src.a = audio;

            elseif size(src.a,1) <= 44100 * 15

                src.a = cat(1,src.a,audio);

            else

                src.a = audio;

            end


        end

        function [] = query(obj)

            notify(obj,'updateJudgement');

        end

        function src = newJudgement(src,event)

            F = parfeval(@gatherJudgements,3,src);

            anonFunc = @(newValue1,newValue2,newValue3) ...
                nestedAnon(src,newValue1,newValue2,newValue3);

             afterEach(F(end),anonFunc,0);

        end

        function nestedAnon(src,newValue1,newValue2,newValue3)

            try

                A1 = get(newValue1,"Data"); A1 = cellReveal(src,A1); A1 = mean(A1,2);
                A1 = movingAverageFilter(src,cat(1,src.roughness,A1));
                src.roughness = cat(1,src.roughness,A1(end));

                A2 = get(newValue2,"Data"); A2 = cellReveal(src,A2);
                A2 = movingAverageFilter(src,cat(1,src.brightness,A2));
                src.brightness = cat(1,src.brightness,A2(end));

                A3 = get(newValue3,"Data"); A3 = cellReveal(src,A3);
                A3 = movingAverageFilter(src,cat(1,src.inharmonicity,A3));
                src.inharmonicity = cat(1,src.inharmonicity,A3(end));

            catch 

            end

        end

        function [roughness,brightness,inharmonicity] = gatherJudgements(src,~)

            try

                tempMIRObject = miraudio(sum(src.a,2));
                roughness = mirroughness(tempMIRObject);
                brightness = mirbrightness(tempMIRObject);
                inharmonicity = mirinharmonicity(tempMIRObject);

            catch

                roughness = NaN;
                brightness = NaN;
                inharmonicity  = NaN;

            end

        end

        function openedCell = cellReveal(~,nestedCells)

            while iscell(nestedCells)

                nestedCells = nestedCells{:};

            end

            openedCell = nestedCells;

        end

        function outDAT = movingAverageFilter(~,inDAT)

            virtualListenerUpdatePeriod = 6; % seconds

            try

                if numel(inDAT) > virtualListenerUpdatePeriod

                    coeffperiodListen = ones(1, ...
                        virtualListenerUpdatePeriod)/virtualListenerUpdatePeriod;

                    frameSize = max([virtualListenerUpdatePeriod,numel(coeffperiodListen)])-1;
                    temp = inDAT(~ismissing(inDAT));
                    filterDAT = filter(coeffperiodListen, 1, ...
                        temp);%, ...
                        %temp(end-(frameSize-1):end));

                    outDAT = filterDAT(end);

                else

                    outDAT = inDAT(end);

                end

            catch ME

                outDAT = ME
                
            end

        end



    end


end
