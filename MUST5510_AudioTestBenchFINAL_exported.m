classdef MUST5510_AudioTestBenchFINAL_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        Menu                          matlab.ui.container.Menu
        ImportAudioFileMenu           matlab.ui.container.Menu
        AudioSettingsMenu             matlab.ui.container.Menu
        BackendAppStatusLamp          matlab.ui.control.Lamp
        BackendAppStatusLampLabel     matlab.ui.control.Label
        VirtualListenerTextArea       matlab.ui.control.TextArea
        VirtualListenerTextAreaLabel  matlab.ui.control.Label
        SamplesdroppedframeEditField  matlab.ui.control.NumericEditField
        SamplesdroppedframeEditFieldLabel  matlab.ui.control.Label
        SystemStatusLamp              matlab.ui.control.Lamp
        SystemStatusLabel             matlab.ui.control.Label
        AudioPlaybackSwitch           matlab.ui.control.RockerSwitch
        AudioPlaybackSwitchLabel      matlab.ui.control.Label
        AudioMeter                    audio.ui.control.Meter
        MUST5510AudioTestBenchLabel   matlab.ui.control.Label
    end


    properties (Access = private)

        delayObj = audioexample.Echo; % delay effect
        bboxWidth = 0; % the bbox width from the backend

        fileReader % Audio file reader

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

        scopeVisualizeTime = timescope('TimeSpan',2, ...
            'YLimits',[-1,1], ...
            'TimeSpanOverrunAction',"Scroll",...
            "LayoutDimensions",[1 1]);

        peakMeter = audioLevelMeter() % Audio level meter object

        fs % temporoary sampling rate

        reverbObject = reverberator % reverberator object

        % user-defined class using MIRToolbox
        mirWiz = mirtoolboxWizard(zeros(44100,2))

        % mirWiz timer object
        mirWizTimer

        midiMsgBank  % midi message array

        wvSynth = wavetableSynthesizer('SampleRate',44.1e3,'Amplitude',8) 

        startTime % App start time

        midiMap % a mapping of midi notes to keyboard values

        soundShareObj % create object to connect to Backend application

        audioSettingsApp

        audioAugmenter
       
    end
    
    properties (Access = public)
        deviceWriter = audioDeviceWriter( ...
            'SampleRate',44100, ... %
            'SupportVariableSizeInput',true,'BufferSize',65536); % max buffer size 65536

        deviceReader = audioDeviceReader('SampleRate',44100,'SamplesPerFrame',65536)
    end

    

    methods (Access = private)

        function [] = streamAudio(app)

            % set all audio variables as persistent variables
            persistent signal blendAudio midiOut aug_signal

            % stream audio from file
            

            playbackSwitchStatus = app.AudioPlaybackSwitch.Value;

            while ~isDone(app.fileReader) && ...
                    strcmp(playbackSwitchStatus,"Play")

                drawnow
                playbackSwitchStatus = app.AudioPlaybackSwitch.Value;

                signal = app.fileReader();

                % augment audio
                app.audioAugmenter, aug_signal = app.audioAugmenter.step(signal);

                % get backend augmented audio and/or midi
                try
                    midiOut = app.soundShareObj.Value;
                catch
                    midiOut = 0;
                end

                % get bbox width from backend
                try
                    app.bboxWidth = app.soundShareObj.BBoxWidth;
                catch
                    app.bboxWidth = 0;
                end

                blendAudio = signal + midiOut;

                % apply the delay based on the bbox width
                if app.bboxWidth > 0.6 % if the bbox width is greater that 0.6, add the delay below
                    
                    % maximum length of the delay in samples, 2000 samples = 45ms at 44.1kHz
                    maxDelaySamples = 2000;
                    
                    % for the delay time to be smooth, we need to normalize
                    % the range. subtracting the min/max delay from the
                    % bbox width and then dividing by 0.4 to normalize the
                    % range to 0-1 (cuz 1.0-0.6=0.1)
                    scaled = (app.bboxWidth - 0.6) / 0.4; % maps 0.6–1 → 0–1
                    
                    % convert to delay time in seconds using the actual fs
                    maxDelaySec = maxDelaySamples / app.fs; % ~0.045 s at 44.1 kHz
                    delaySec = maxDelaySec * scaled;
                    
                    % configure echo parameters
                    app.delayObj.Delay = delaySec; % seconds
                    app.delayObj.Gain = 1.0; % gain of delayed signal
                    app.delayObj.FeedbackLevel = 0.0; % no feedback (simple echo)
                    app.delayObj.WetDryMix = 0.8; % how much delay is heard

                else 
                    % if the bbox is < 0.6 turn the delay off, essentially
                    % bypass the delay
                    app.delayObj.WetDryMix = 0.0;
                    app.delayObj.Delay = 0.0;
                   
                    % use the dry signal if bbox < 0.6 and ignore the above
                    % code
                    outAudio = blendAudio;

                end

                % update virtual listener with new audio data
                step(app.mirWiz,outAudio);

                dropped = app.deviceWriter(outAudio);
                app.SamplesdroppedframeEditField.UserData = double(dropped);
                app.AudioMeter.Value = app.peakMeter(outAudio);

                if double(dropped) ~= 0
                    app.SamplesdroppedframeEditField.Value = double(dropped);
                    drawnow
                end

            end

            release(app.fileReader)
            release(app.deviceWriter)
            release(app.scopeVisualizeTime)

            % stop timer
            stop(app.mirWizTimer);
            set(app.AudioPlaybackSwitch,"Value",'Stop')

        end

        function transformed_signal = augmentAudio(app,orig_signal)
            % apply augmentation to streaming audio signal

            % Apply augmentation
            transformed_signal = augment(app.augmenter,orig_signal,app.fs);

            if istable(transformed_signal)
                transformed_signal = cell2mat(transformed_signal.Audio);
            end

        end

        function audioOut = reverbApply(app,audio,preDelay,wetDryMix,sampleRate)
            
            % custom augmentation method: Reverb
            app.reverbObject.SampleRate = sampleRate;
            app.reverbObject.PreDelay = preDelay;
            app.reverbObject.WetDryMix = wetDryMix;

            audioOut = app.reverbObject(audio);

        end

        function mirWizTimerFcn(app,~,~)

            query(app.mirWiz)

            % send request for information from
            % virtual listener every 6 s
            virtualListenerUpdatePeriod = 6; % seconds

            if numel(app.mirWiz.roughness) >= virtualListenerUpdatePeriod

                try
                    % print to GUI
                    formatSpec = ['Roughness = %g \n' ...
                        'brightness = %g bpm\n' ...
                        'inharmonicity = %g\n' ];

                    A1 = app.mirWiz.roughness(end);

                    A2 = app.mirWiz.brightness(end);

                    A3 = app.mirWiz.inharmonicity{end};
                   
                    tempMirStruct = mirStruct("brightness", A2, ...
                        "inharmonicity",A3, ...
                        "roughness", A1);

                    % updates the MIR parameters of our MusicAugmenter
                    % using the values from the mirWiz
                    app.audioAugmenter = app.audioAugmenter.updateMIRParams(tempMirStruct);

                    str = sprintf(formatSpec,round(A1), ...
                        round(A2), ...
                        A3);

                    app.VirtualListenerTextArea.Value = str;

                catch

                end

            else

                app.VirtualListenerTextArea.Value = ...
                    ['Listening. Please wait. . . ',char(datetime("now"))];

            end

            app.SamplesdroppedframeEditField.Value = ...
                app.SamplesdroppedframeEditField.UserData;

            drawnow

        end

        function updatebboxWidth(app, widthValue)
            % width value must be on the scale of 0 to 1
            app.bboxWidth = max(0, min(1, widthValue));

        end

    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)


            % initialize paralell pool, if not running
            gcp;

            % reset audio devices
            audiodevreset

            % set slider UI component ranges

            % % pitch
            % app.PitchSlider.Limits = [-2 2];
            % app.PitchSlider.Value = 0;
            % 
            % % volume
            % app.VolumeSlider.Limits = [-20 10];
            % app.VolumeSlider.Value = 0;
            % 
            % % reverb: wet/dry mix
            % app.ReverbWetDryMixSlider.Limits = [0 1];
            % app.ReverbWetDryMixSlider.Value = 0;


            % add MIRToolbox to Audio App
            d = dir('**/*');
            d = d(matches({d.name},'MIRToolbox'));

            addpath(genpath(fullfile(d.folder,d.name)))

            % setup MIRToolbox objects
            % assign to empty properties

            app.mirWizTimer = timer("ExecutionMode","fixedRate","Period",6, ...
                "BusyMode","drop","TimerFcn",@app.mirWizTimerFcn);

            app.SamplesdroppedframeEditField.UserData = 0; % set default value

            % set audio augmenter paramters
            % define augmenter parameters for ShiftPitch
            setAugmenterParams(app.augmenter,'shiftPitch','LockPhase',true, ...
                'PreserveFormants',true);

            % define augmenter parameters for StretchAudio
            setAugmenterParams(app.augmenter,'stretchAudio','LockPhase',true);

            % log app start time
            app.startTime = datetime("now");

            % setup midiMap
            app.midiMap = [[113 50 119 51 101 114 53 116 54 121 55 117 105]' ...
                (60:72)'];

           % check that Backend instance is running
           if exist('SoundApp_BakendDAT.mat','file')
               % instance is running
               app.BackendAppStatusLamp.Color = 'g';
               app.soundShareObj = matfile('SoundApp_BakendDAT.mat');
               
           else
               % instance is not running
               app.BackendAppStatusLamp.Color = 'r';
               app.soundShareObj = 0;
           end

        end

        % Menu selected function: ImportAudioFileMenu
        function ImportAudioFileMenuSelected(app, event)


            try

                % User input: select audio file
                [filename,pathname] = uigetfile('*.*','Select Audio File');
                [fileAudio,app.fs] = audioread(fullfile(pathname,filename));

                % set frame length equal to 2x synthesizer
                frameLength = app.wvSynth.SamplesPerFrame * 10;
                app.wvSynth.SamplesPerFrame = frameLength;

                % initialize audio file reader
                app.fileReader = dsp.AudioFileReader( ...
                    fullfile(pathname,filename), ...
                    'SamplesPerFrame',frameLength);

                % Add reverb as parameter to audio data augmenter
                if sum(contains(cellstr(properties(app.augmenter)), ...
                        'ApplyReverb'))==1

                    removeAugmentationMethod(app.augmenter,'Reverb')

                end

                % create reverberator system object
                algorithmName = 'Reverb';
                algorithmHandle = @(x,preDelay,wetDryMix)reverbApply(app,x,preDelay,wetDryMix,app.fs);
                parameters = {'PreDelay','WetDryMix'};
                parameterRanges = {[0,1],[0,1]};
                parameterValues = {0,0};

                addAugmentationMethod(app.augmenter,algorithmName,algorithmHandle, ...
                    'AugmentationParameter',parameters, ...
                    'ParameterRange',parameterRanges, ...
                    'ParameterValue',parameterValues)
                app.augmenter.ApplyReverb = false;

                % update timescope parameters
                app.scopeVisualizeTime.SampleRate = app.fileReader.SampleRate;
                app.scopeVisualizeTime.BufferLength = ...
                    app.fileReader.SampleRate*2*2;

                % update sample rate
                app.deviceWriter.SampleRate = app.fs;
                app.deviceWriter.BufferSize = 1024;

                % initialize audioAugmenter
                app.audioAugmenter = MusicAugmenter(fileAudio(1:app.fs*3), app.fs, 10, app.deviceWriter.BufferSize);

                % % set sample rate for delay/echo effect
                % setSampleRate(app.delayObj, app.fs);

                % update audio level parameters
                app.peakMeter.SampleRate = app.fileReader.SampleRate;
                app.peakMeter.WindowLength = app.fileReader.SamplesPerFrame;

                % update status lamp
                app.SystemStatusLamp.Color = 'g';

                % update access to playback switch
                app.AudioPlaybackSwitch.Enable = true;

                % update audio oscillator samples per frame
                app.wvSynth.SamplesPerFrame = frameLength;

            catch ME

                % update status lamp
                app.SystemStatusLamp.Color = 'y';

                % update access to playback switch
                app.AudioPlaybackSwitch.Enable = false;

            end


        end

        % Value changed function: AudioPlaybackSwitch
        function AudioPlaybackSwitchValueChanged(app, event)
            value = app.AudioPlaybackSwitch.Value;

            switch value

                case 'Play'

                    if strcmp(app.mirWizTimer.Running,"off")
                        start(app.mirWizTimer);
                    end
                    streamAudio(app)

                case 'Stop'

                    stop(app.mirWizTimer);

            end
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
           
            if exist('app.fileReader')

            if ~isempty(app.fileReader)
                release(app.fileReader)
            end

            end

            release(app.deviceWriter)
            release(app.scopeVisualizeTime)

            stop(app.mirWizTimer);
            delete(app.mirWizTimer);

            delete(app)

        end

        % Menu selected function: AudioSettingsMenu
        function AudioSettingsMenuSelected(app, event)
            app.audioSettingsApp = audiosettings(app);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create Menu
            app.Menu = uimenu(app.UIFigure);
            app.Menu.Text = 'Menu';

            % Create ImportAudioFileMenu
            app.ImportAudioFileMenu = uimenu(app.Menu);
            app.ImportAudioFileMenu.MenuSelectedFcn = createCallbackFcn(app, @ImportAudioFileMenuSelected, true);
            app.ImportAudioFileMenu.Text = 'Import Audio File';

            % Create AudioSettingsMenu
            app.AudioSettingsMenu = uimenu(app.Menu);
            app.AudioSettingsMenu.MenuSelectedFcn = createCallbackFcn(app, @AudioSettingsMenuSelected, true);
            app.AudioSettingsMenu.Text = 'Audio Settings';

            % Create MUST5510AudioTestBenchLabel
            app.MUST5510AudioTestBenchLabel = uilabel(app.UIFigure);
            app.MUST5510AudioTestBenchLabel.FontWeight = 'bold';
            app.MUST5510AudioTestBenchLabel.Position = [238 451 173 22];
            app.MUST5510AudioTestBenchLabel.Text = 'MUST 5510 Audio Test Bench';

            % Create AudioMeter
            app.AudioMeter = uiaudiometer(app.UIFigure);
            app.AudioMeter.Orientation = 'horizontal';
            app.AudioMeter.Position = [22 37 606 80];

            % Create AudioPlaybackSwitchLabel
            app.AudioPlaybackSwitchLabel = uilabel(app.UIFigure);
            app.AudioPlaybackSwitchLabel.HorizontalAlignment = 'center';
            app.AudioPlaybackSwitchLabel.FontWeight = 'bold';
            app.AudioPlaybackSwitchLabel.Enable = 'off';
            app.AudioPlaybackSwitchLabel.Position = [13 362 94 22];
            app.AudioPlaybackSwitchLabel.Text = 'Audio Playback';

            % Create AudioPlaybackSwitch
            app.AudioPlaybackSwitch = uiswitch(app.UIFigure, 'rocker');
            app.AudioPlaybackSwitch.Items = {'Play', 'Stop'};
            app.AudioPlaybackSwitch.Orientation = 'horizontal';
            app.AudioPlaybackSwitch.ValueChangedFcn = createCallbackFcn(app, @AudioPlaybackSwitchValueChanged, true);
            app.AudioPlaybackSwitch.Enable = 'off';
            app.AudioPlaybackSwitch.Position = [58 307 81 36];
            app.AudioPlaybackSwitch.Value = 'Stop';

            % Create SystemStatusLabel
            app.SystemStatusLabel = uilabel(app.UIFigure);
            app.SystemStatusLabel.HorizontalAlignment = 'right';
            app.SystemStatusLabel.FontWeight = 'bold';
            app.SystemStatusLabel.Position = [13 400 87 22];
            app.SystemStatusLabel.Text = 'System Status';

            % Create SystemStatusLamp
            app.SystemStatusLamp = uilamp(app.UIFigure);
            app.SystemStatusLamp.Position = [115 401 20 20];
            app.SystemStatusLamp.Color = [1 1 0];

            % Create SamplesdroppedframeEditFieldLabel
            app.SamplesdroppedframeEditFieldLabel = uilabel(app.UIFigure);
            app.SamplesdroppedframeEditFieldLabel.HorizontalAlignment = 'right';
            app.SamplesdroppedframeEditFieldLabel.Position = [438 5 133 22];
            app.SamplesdroppedframeEditFieldLabel.Text = 'Samples dropped/frame';

            % Create SamplesdroppedframeEditField
            app.SamplesdroppedframeEditField = uieditfield(app.UIFigure, 'numeric');
            app.SamplesdroppedframeEditField.FontColor = [0.149 0.149 0.149];
            app.SamplesdroppedframeEditField.BackgroundColor = [0.9412 0.9412 0.9412];
            app.SamplesdroppedframeEditField.Position = [583 5 54 22];

            % Create VirtualListenerTextAreaLabel
            app.VirtualListenerTextAreaLabel = uilabel(app.UIFigure);
            app.VirtualListenerTextAreaLabel.HorizontalAlignment = 'right';
            app.VirtualListenerTextAreaLabel.Position = [8 240 84 22];
            app.VirtualListenerTextAreaLabel.Text = 'Virtual Listener';

            % Create VirtualListenerTextArea
            app.VirtualListenerTextArea = uitextarea(app.UIFigure);
            app.VirtualListenerTextArea.Position = [107 132 173 132];

            % Create BackendAppStatusLampLabel
            app.BackendAppStatusLampLabel = uilabel(app.UIFigure);
            app.BackendAppStatusLampLabel.HorizontalAlignment = 'right';
            app.BackendAppStatusLampLabel.Position = [343 328 116 22];
            app.BackendAppStatusLampLabel.Text = 'Backend App Status';

            % Create BackendAppStatusLamp
            app.BackendAppStatusLamp = uilamp(app.UIFigure);
            app.BackendAppStatusLamp.Position = [474 328 20 20];
            app.BackendAppStatusLamp.Color = [1 0 0];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = MUST5510_AudioTestBenchFINAL_exported

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)

                % Execute the startup function
                runStartupFcn(app, @startupFcn)
            else

                % Focus the running singleton app
                figure(runningApp.UIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end