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
        pulseClarity
        tempo
        brightness
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

                A1 = get(newValue1,"Data"); A1 = cellReveal(src,A1);
                A1 = movingAverageFilter(src,cat(1,src.pulseClarity,A1));
                src.pulseClarity = cat(1,src.pulseClarity,A1(end));

                A2 = get(newValue2,"Data"); A2 = cellReveal(src,A2);
                A2 = movingAverageFilter(src,cat(1,src.tempo,A2));
                src.tempo = cat(1,src.tempo,A2(end));

                A3 = get(newValue3,"Data"); A3 = cellReveal(src,A3);
                A3 = movingAverageFilter(src,cat(1,src.brightness,A3));
                src.tempo = cat(1,src.tempo,A3(end));
                

            catch 

            end

        end

        function [pulseClarity,tempo,brightness] = gatherJudgements(src,~)

            try

                tempMIRObject = miraudio(sum(src.a,2));
                pulseClarity = mirpulseclarity(tempMIRObject);
                tempo = mirtempo(tempMIRObject);
                brightness = mirbrightness(tempMIRObject);

            catch

                pulseClarity = NaN;
                tempo = NaN;
                brightness  = [];

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
