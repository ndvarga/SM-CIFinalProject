classdef AudioSettingsappFINAL_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        DeviceOutputDropDownLabel  matlab.ui.control.Label
        DeviceInputDropDownLabel   matlab.ui.control.Label
        AudioDriverDropDown        matlab.ui.control.DropDown
        AudioDriverDropDownLabel   matlab.ui.control.Label
        DeviceInputDropDown        matlab.ui.control.DropDown
        DeviceOutputDropDown       matlab.ui.control.DropDown
        SampleRateDropDown         matlab.ui.control.DropDown
        BufferSizeDropDown         matlab.ui.control.DropDown
        AsioSettingsButton         matlab.ui.control.Button
        BufferSizeDropDownLabel    matlab.ui.control.Label
        SampleRateDropDownLabel    matlab.ui.control.Label
    end


    properties (Access = private)
        hostAudioWriter
        hostAudioReader
    end


    methods (Access = private)

        function [inputs,outputs] = getDeviceIO(app)

            allDevices = audiostreamer.getAudioDevices;

            % make empty arrays for audio inputs and outputs
            inputs = {'Default'};
            outputs = {'Default'};
            
            % loop over all audio inputs and outputs and add to array if
            % corresponds to active driver
            for i=1:numel(allDevices)
                if allDevices(i).Driver == app.hostAudioWriter.Driver 
                    if allDevices(i).MaxRecorderChannels > 0
                        inputs{end+1} = allDevices(i).Name;
                    end
                    
                    if allDevices(i).MaxPlayerChannels > 0
                        outputs{end+1} = allDevices(i).Name;
                    end
                end
            end
            
            % convert array to array type UI likes
            inputs = cell2mat(inputs);
            outputs = cell2mat(outputs);
        end
      

    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, hostApp)
            % get audio host
            app.hostAudioReader = hostApp.deviceReader;
            app.hostAudioWriter = hostApp.deviceWriter;

            % setup device options
            app.AudioDriverDropDown.Items = audiostreamer.getDrivers;

            % set sample rate and buffer size menu to value
            app.SampleRateDropDown.Value = string(app.hostAudioWriter.SampleRate);
            
            try 
                app.BufferSizeDropDown.Value = string(app.hostAudioWriter.BufferSize);
            catch
                app.BufferSizeDropDown.Items = [app.BufferSizeDropDown.Items,num2str(app.hostAudioWriter.BufferSize)];
                app.BufferSizeDropDown.Value = string(app.hostAudioWriter.BufferSize);
            end 
            
            % device option callback to update IO options
            app.AudioDriverDropDownValueChanged;

            app.DeviceInputDropDown.Value = app.hostAudioReader.Device;
            app.DeviceOutputDropDown.Value = app.hostAudioWriter.Device;

        end

        % Value changed function: AudioDriverDropDown
        function AudioDriverDropDownValueChanged(app, event)
            % Change the input and output devices first so it doesn't error

            if ~strcmp(app.AudioDriverDropDown.Value,app.hostAudioWriter.Driver)
                app.hostAudioWriter.Driver = app.AudioDriverDropDown.Value;
            end

            % app.hostApp.audioDevice = app.AudioDriverDropDown.Value;
            % % change driver here instead
            % app.hostApp.audioStreamer.Driver = app.hostApp.audioDevice;
         
            % enable asio settings button if using asio
            if strcmp(app.hostAudioWriter.Driver,'ASIO')
                app.AsioSettingsButton.Enable = "on";

            else 
                app.AsioSettingsButton.Enable = "off";

            end

            % change audio device input and output options based on device
            [inputs, outputs] = getDeviceIO(app);
            app.DeviceInputDropDown.Items = inputs;
            app.DeviceOutputDropDown.Items = outputs;

        end

        % Value changed function: DeviceInputDropDown
        function DeviceInputDropDownValueChanged(app, event)
            app.hostAudioReader.Device = app.DeviceInputDropDown.Value;     
        end

        % Value changed function: DeviceOutputDropDown
        function DeviceOutputDropDownValueChanged(app, event)
            app.hostAudioWriter.Device = app.DeviceOutputDropDown.Value;     
        end

        % Value changed function: SampleRateDropDown
        function SampleRateDropDownValueChanged(app, event)

            app.hostAudioWriter.SampleRate = str2double(app.SampleRateDropDown.Value);
            app.hostAudioReader.SampleRate = app.hostAudioWriter.SampleRate;

        end

        % Value changed function: BufferSizeDropDown
        function BufferSizeDropDownValueChanged(app, event)
            
            app.hostAudioWriter.BufferSize = str2double(app.BufferSizeDropDown.Value);
            app.hostAudioReader.SamplesPerFrame = app.hostAudioWriter.BufferSize;

        end

        % Button pushed function: AsioSettingsButton
        function AsioSettingsButtonPushed(app, event)
            if strcmp(app.hostApp.audioDevice,'ASIO')
                asiosettings
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 641 437];
            app.UIFigure.Name = 'MATLAB App';

            % Create SampleRateDropDownLabel
            app.SampleRateDropDownLabel = uilabel(app.UIFigure);
            app.SampleRateDropDownLabel.HorizontalAlignment = 'right';
            app.SampleRateDropDownLabel.Position = [222 212 74 22];
            app.SampleRateDropDownLabel.Text = 'Sample Rate';

            % Create BufferSizeDropDownLabel
            app.BufferSizeDropDownLabel = uilabel(app.UIFigure);
            app.BufferSizeDropDownLabel.HorizontalAlignment = 'right';
            app.BufferSizeDropDownLabel.Position = [233 172 63 22];
            app.BufferSizeDropDownLabel.Text = 'Buffer Size';

            % Create AsioSettingsButton
            app.AsioSettingsButton = uibutton(app.UIFigure, 'push');
            app.AsioSettingsButton.ButtonPushedFcn = createCallbackFcn(app, @AsioSettingsButtonPushed, true);
            app.AsioSettingsButton.Enable = 'off';
            app.AsioSettingsButton.Position = [267 134 100 23];
            app.AsioSettingsButton.Text = 'ASIO Settings';

            % Create BufferSizeDropDown
            app.BufferSizeDropDown = uidropdown(app.UIFigure);
            app.BufferSizeDropDown.Items = {'32', '64', '128', '256', '512', '1024', '2048', '4096', '32768', '65536'};
            app.BufferSizeDropDown.ValueChangedFcn = createCallbackFcn(app, @BufferSizeDropDownValueChanged, true);
            app.BufferSizeDropDown.Position = [311 171 100 22];
            app.BufferSizeDropDown.Value = '512';

            % Create SampleRateDropDown
            app.SampleRateDropDown = uidropdown(app.UIFigure);
            app.SampleRateDropDown.Items = {'44.1 kHz', '48.0 kHz'};
            app.SampleRateDropDown.ItemsData = {'44100', '48000'};
            app.SampleRateDropDown.ValueChangedFcn = createCallbackFcn(app, @SampleRateDropDownValueChanged, true);
            app.SampleRateDropDown.Position = [311 211 100 22];
            app.SampleRateDropDown.Value = '48000';

            % Create DeviceOutputDropDown
            app.DeviceOutputDropDown = uidropdown(app.UIFigure);
            app.DeviceOutputDropDown.Items = {};
            app.DeviceOutputDropDown.ValueChangedFcn = createCallbackFcn(app, @DeviceOutputDropDownValueChanged, true);
            app.DeviceOutputDropDown.Placeholder = 'Select';
            app.DeviceOutputDropDown.Position = [429 246 100 22];
            app.DeviceOutputDropDown.Value = {};

            % Create DeviceInputDropDown
            app.DeviceInputDropDown = uidropdown(app.UIFigure);
            app.DeviceInputDropDown.Items = {};
            app.DeviceInputDropDown.ValueChangedFcn = createCallbackFcn(app, @DeviceInputDropDownValueChanged, true);
            app.DeviceInputDropDown.Placeholder = 'Select';
            app.DeviceInputDropDown.Position = [212 245 100 22];
            app.DeviceInputDropDown.Value = {};

            % Create AudioDriverDropDownLabel
            app.AudioDriverDropDownLabel = uilabel(app.UIFigure);
            app.AudioDriverDropDownLabel.HorizontalAlignment = 'right';
            app.AudioDriverDropDownLabel.Position = [224 279 71 22];
            app.AudioDriverDropDownLabel.Text = 'Audio Driver';

            % Create AudioDriverDropDown
            app.AudioDriverDropDown = uidropdown(app.UIFigure);
            app.AudioDriverDropDown.Items = {};
            app.AudioDriverDropDown.ValueChangedFcn = createCallbackFcn(app, @AudioDriverDropDownValueChanged, true);
            app.AudioDriverDropDown.Placeholder = 'Select';
            app.AudioDriverDropDown.Position = [310 279 100 22];
            app.AudioDriverDropDown.Value = {};

            % Create DeviceInputDropDownLabel
            app.DeviceInputDropDownLabel = uilabel(app.UIFigure);
            app.DeviceInputDropDownLabel.HorizontalAlignment = 'center';
            app.DeviceInputDropDownLabel.Position = [125 245 72 22];
            app.DeviceInputDropDownLabel.Text = 'Device Input';

            % Create DeviceOutputDropDownLabel
            app.DeviceOutputDropDownLabel = uilabel(app.UIFigure);
            app.DeviceOutputDropDownLabel.HorizontalAlignment = 'center';
            app.DeviceOutputDropDownLabel.Position = [332 246 82 22];
            app.DeviceOutputDropDownLabel.Text = 'Device Output';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = AudioSettingsappFINAL_exported(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
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