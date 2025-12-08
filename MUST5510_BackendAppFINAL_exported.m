classdef MUST5510_BackendAppFINAL_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        BackendTestBenchUIFigure       matlab.ui.Figure
        Controller2Gauge               matlab.ui.control.LinearGauge
        Controller2GaugeLabel          matlab.ui.control.Label
        Controller1Gauge               matlab.ui.control.LinearGauge
        Controller1GaugeLabel          matlab.ui.control.Label
        MUST5510BackendTestBenchLabel  matlab.ui.control.Label
    end

    
    properties (Access = private)
        
        SoundApp % create object to connect to sound application

        ActionApp % create object to connect to computer vision application
       
        currentFrame % store temporary frame from child computer vision app

        currentObsTime % store temporary frame observation timestamp

        opticalFlow = opticalFlowHS % create optical flow object

        flow % flow object results for currentFrame

        allMotionDAT = struct('obsTime',[],'Magnitude',[],'boxWidth',[]) % store all motion data

        controllerStatus % create object to hold controller status

        startTime % accept start time from parent app: inter-app time sync

        midiMsgBank  % midi message array
        
        % audio augmentation object
        augmenter = audioDataAugmenter( ...
            "AugmentationMode","sequential", ...
            "AugmentationParameterSource",'specify',...
            "NumAugmentations",1, ...
            ...
            "ApplyTimeStretch",false, ...
            "SpeedupFactor", 0, ...
            ...
            "ApplyPitchShift",false, ...
            "SemitoneShift",0, ...
            ...
            "ApplyVolumeControl",false, ...
            "VolumeGain",0, ...
            ...
            "ApplyAddNoise",false, ...
            "SNR",0,...
            ...
            "ApplyTimeShift",false, ...
            "TimeShift", 0);

    end

    properties (Access = public)

        midiOut = 0 % real-time MIDI out feed
        soundShareObj
        

    end

    events

        currentFrameChanged
        newDataArrived

    end
    
    methods (Access = private)
        
        
        function [] = updateMIDIOut(app)
            persistent ScreenWidth;

            if isempty(ScreenWidth)
               ScreenWidth = size(app.currentFrame,2);
            end

            % prune older messages
            if ~isempty(app.midiMsgBank)

                app.midiMsgBank([app.midiMsgBank.Timestamp] < ...
                    seconds(time(between(app.startTime,datetime("now"))))-1) = [];

            end

            % use centroid x-dim location
            controllerValue = app.controllerStatus.Value(1);
            % use width of bounding box normalized to width of video frame
            controller2Value = app.controllerStatus.boxWidth/ScreenWidth;

           % update UI
           app.Controller1Gauge.Value = controllerValue;

           app.Controller2Gauge.Value =  controller2Value; 

           
           % 
           % % rescale input value (controllerValue) to MIDI range
           % tempNote = round(rescale(controllerValue,1,128, ...
           %     "InputMin",10,"InputMax",ScreenWidth));
           % 
           % if ~isempty(app.midiMsgBank)
           % 
           %     tempMSGs = midimsg('Note',1,tempNote,35,0.1, ...
           %         seconds(time(between(app.startTime,datetime("now")))));
           % 
           %     app.midiMsgBank = cat(1,app.midiMsgBank,tempMSGs);
           % 
           % else
           % 
           %     tempMSGs = midimsg('Note',1,tempNote,35,0.1, ...
           %         seconds(time(between(app.startTime,datetime("now")))));
           % 
           %     app.midiMsgBank = tempMSGs;
           % 
           % end

           % if ~isempty(app.midiMsgBank)
           % 
           %      try
           % 
           %          msg = app.midiMsgBank(1);
           % 
           %          app.wvSynth.Frequency = note2freq(app,msg.Note);
           %          app.wvSynth.Amplitude = msg.Velocity/127;
           % 
           %          app.midiOut = app.wvSynth();
           % 
           %          app.midiMsgBank(1:2) = [];
           % 
           %      catch
           % 
           %          app.midiOut = 0;
           % 
           %      end
           % 
           %  else
           % 
           %      app.midiOut = 0;
           % 
           %  end

            try
                % % update sound app shareable data
                % app.soundShareObj.Value = app.midiOut;
                % % bbox width number is stored to use for changing parameters in the audio app
                % app.soundShareObj.Width = controller2Value;
                fileID = fopen('SoundApp_Shared.bin', 'w');
                fwrite(fileID, double(app.Controller2Gauge.Value), 'double');
                fclose(fileID);
            catch

            end

        end

        function [] = monitorOpticalFlow(app,~)

           persistent GaugeSize
            if isempty(GaugeSize)
                GaugeSize = size(app.currentFrame(2));
                app.Controller1Gauge.Limits = [1 GaugeSize];
            end
         % run optical flow on frame
            if ~isempty(app.currentFrame)
                % store optical flow object
                app.flow = estimateFlow(app.opticalFlow,app.currentFrame);
            end
            
        end

        function [] = updateFrame(app)
            % updates the video frame in the parent app using updated frame
            % from child video acquisition app

            % read in current frame from child app
            app.currentFrame = app.ActionApp.previousFrame; 

            % start event: currentFrameChanged (run optical flow)
            notify(app,'currentFrameChanged')

            % update current observed time in the backend application
            app.currentObsTime = app.ActionApp.allMotionDAT.obsTime;
            
            % update controller with new data 
            updateController(app);
            
        end

        function [] = updateController(app)
            % updates midi out function with new data

            % update controller status
            app.controllerStatus = app.ActionApp.allMotionDAT;
            
            if ~isempty(app.controllerStatus.Value)
                % controller is running & data availabile
                updateMIDIOut(app)
            else
                % no data available from controller
                app.soundShareObj.Value = 0;
            end

        end

    end

    methods (Access = public)

        function [] = newFrameRead(app)
            % notifies app of new frame read in video app

            % run update frame private function
            updateFrame(app);

        end
        


    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            
            % launch computer vision app
            app.ActionApp = MUST5510_VideoTestBench_Week10(app, ...
                0,0);

            % % create accessible matfile for sound app
            % app.soundShareObj = matfile('SoundApp_BakendDAT.mat',"Writable",true);
            % app.soundShareObj.Value = 0;

            % create listener to monitor change in frame
            addlistener(app,'currentFrameChanged',...
                @monitorOpticalFlow);

             % create listener to monitor change motion data
            addlistener(app,'newDataArrived',...
                @updateMIDIOut);
           
            app.startTime = datetime('now');

            % update gauge range based upon paramter of interst
            app.Controller1Gauge.Limits = [1 1920];

            % % set frame length equal to 2x synthesizer
            % frameLength = app.wvSynth.SamplesPerFrame * 10;
            % app.wvSynth.SamplesPerFrame = frameLength;
        end

        % Close request function: BackendTestBenchUIFigure
        function BackendTestBenchUIFigureCloseRequest(app, event)
            % delete sound app shared bin
            fclose('all'); 
            delete(app.SoundApp)

            delete(app.ActionApp) % close video app
            imaqreset
            
            delete(app)
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create BackendTestBenchUIFigure and hide until all components are created
            app.BackendTestBenchUIFigure = uifigure('Visible', 'off');
            app.BackendTestBenchUIFigure.Position = [100 100 409 236];
            app.BackendTestBenchUIFigure.Name = 'BackendTestBench';
            app.BackendTestBenchUIFigure.CloseRequestFcn = createCallbackFcn(app, @BackendTestBenchUIFigureCloseRequest, true);

            % Create MUST5510BackendTestBenchLabel
            app.MUST5510BackendTestBenchLabel = uilabel(app.BackendTestBenchUIFigure);
            app.MUST5510BackendTestBenchLabel.FontWeight = 'bold';
            app.MUST5510BackendTestBenchLabel.Position = [106 197 191 22];
            app.MUST5510BackendTestBenchLabel.Text = 'MUST 5510 Backend Test Bench';

            % Create Controller1GaugeLabel
            app.Controller1GaugeLabel = uilabel(app.BackendTestBenchUIFigure);
            app.Controller1GaugeLabel.HorizontalAlignment = 'center';
            app.Controller1GaugeLabel.Position = [169 99 67 22];
            app.Controller1GaugeLabel.Text = 'Controller 1';

            % Create Controller1Gauge
            app.Controller1Gauge = uigauge(app.BackendTestBenchUIFigure, 'linear');
            app.Controller1Gauge.Position = [107 136 191 41];

            % Create Controller2GaugeLabel
            app.Controller2GaugeLabel = uilabel(app.BackendTestBenchUIFigure);
            app.Controller2GaugeLabel.HorizontalAlignment = 'center';
            app.Controller2GaugeLabel.Position = [169 13 67 22];
            app.Controller2GaugeLabel.Text = 'Controller 2';

            % Create Controller2Gauge
            app.Controller2Gauge = uigauge(app.BackendTestBenchUIFigure, 'linear');
            app.Controller2Gauge.Limits = [0 1];
            app.Controller2Gauge.Position = [107 50 191 41];

            % Show the figure after all components are created
            app.BackendTestBenchUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = MUST5510_BackendAppFINAL_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.BackendTestBenchUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.BackendTestBenchUIFigure)
        end
    end
end