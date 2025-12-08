classdef MUST5510_VideoApp_exported < matlab.apps.AppBase
    %MUST5510_VIDEOAPP_EXPORTED Computer Vision-based Audio Controller
    %   Child application for MUST 5973 Audio Test Bench Week 10

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        MotionDetectionThresholdMenu  matlab.ui.container.Menu
        CalibrationMenu               matlab.ui.container.Menu
        Launch2DCalibrationMenu       matlab.ui.container.Menu
        UploadCalibrationFrameMenu    matlab.ui.container.Menu
        OptionsMenu                   matlab.ui.container.Menu
        KeypointDetectionMenu         matlab.ui.container.Menu
        CorrectDistortionSwitch       matlab.ui.control.Switch
        CorrectDistortionSwitchLabel  matlab.ui.control.Label
        EditField                     matlab.ui.control.NumericEditField
        MotionSensitivitySlider       matlab.ui.control.Slider
        MotionSensitivitySliderLabel  matlab.ui.control.Label
        MotionDetectionSwitch         matlab.ui.control.Switch
        MotionDetectionSwitchLabel    matlab.ui.control.Label
        MUST5510VideoTestBenchLabel   matlab.ui.control.Label
        DeviceDropDown                matlab.ui.control.DropDown
        DeviceDropDownLabel           matlab.ui.control.Label
        AdaptorDropDown               matlab.ui.control.DropDown
        AdaptorDropDownLabel          matlab.ui.control.Label
        StreamSwitch                  matlab.ui.control.ToggleSwitch
        StreamSwitchLabel             matlab.ui.control.Label
        StatusLamp                    matlab.ui.control.Lamp
        StatusLampLabel               matlab.ui.control.Label
    end

%{

Revised Version

MUST 5510 Video Test Bench Week 10
Copyright 2025 (c) Aston K McCullough, PhD, MS, MA
Northeastern University

Orignal Version

MUST 5973 Video Test Bench Week 10
Northeastern University

NOTE: 

To use this code, you will need to download:

'Computer Vision Toolbox Model for YOLO v4 Object Detection'

Using the Get and Manage Add-Ons tab in MATLAB.

%}
    properties (Access = private)

        depVideoPlayer = vision.DeployableVideoPlayer; % VideoPlayer
        vidObj = imaq.VideoDevice; % image acquisition object

        % initialize object detector
        personDetect = yolov4ObjectDetector("tiny-yolov4-coco" );

        % initialize blob detector
        blobDetect = vision.BlobAnalysis('MinimumBlobArea',500);

        personTracker % object for holding person tracker

        personTimer %

        calibrationParameters % calibration file

        BackendApp % create object to connect to Backend Application

        keypointDetector = hrnetObjectKeypointDetector("human-full-body-w32")

    end

    properties (Access = public)

         previousFrame = [] % last observed frame for motion detection
         postProcessedFrame = []; % processed video frame
         allMotionDAT = struct('obsTime',[],'Value',[],'boxWidth',[]) % store all motion data

    end

    methods (Access = private)

        function [] = streamVideo(app)

            % set lamp status in use
            app.StatusLamp.Color = 'r';

            % get initial switch status
            switchStatus = app.StreamSwitch.Value;

            if ~exist('app.depVideoPlayer','var')

                    app.depVideoPlayer = vision.DeployableVideoPlayer;
            end


            while ~strcmp(switchStatus,'Off')
                
                drawnow

                % get switch status
                switchStatus = app.StreamSwitch.Value;

                mySignal = step(app.vidObj); % grab frame

                % remove image distortion
                if ~isempty(app.calibrationParameters) && ...
                        strcmp(app.CorrectDistortionSwitch.Value,'On')

                    mySignal = undistortImage(mySignal, ...
                        app.calibrationParameters.camParam);

                end

                newFrameRead(app.BackendApp); % pass notification to Backend
                                
                switch app.MotionDetectionSwitch.Value

                    case 'Off'

                        app.depVideoPlayer(double(mySignal)) % visualize frame


                    case 'On'

                        processedFrame = motionDetector(app,mySignal);
                        app.depVideoPlayer(double(processedFrame));

                end


            end

            release(app.depVideoPlayer)
            release(app.vidObj)
            delete(app.depVideoPlayer)

            % set lamp status to ready
            app.StatusLamp.Color = 'g';

        end


        function processedFrame = motionDetector(app,videoFrame)

            obsTime = posixtime(datetime('now'));

            
            bbox = zeros(1,4); % preallocate empty bbox
            % bboxes = zeros(1,4);

            % centroid = [];
            % allCentroids = [];

            drawnow

            if ~isempty(app.previousFrame)

                % calculate the difference image
                diffImage = double(abs(videoFrame-app.previousFrame)) > ...
                    get(app.MotionSensitivitySlider,'Value');

                % create bounding box

                % find non-zero elements along x-dimension
                xbbox = sum(diffImage,1);

                if any(xbbox > 0) % motion detected

                    % determine if tracker has been initialized
                    if isempty(app.personTracker) % tracker not initialized

                        [bboxes, ~, labels] = ...
                            detect(app.personDetect, ...
                            cat(3,videoFrame,videoFrame,videoFrame), ...
                            Threshold=0.4);

                        personBoxes = bboxes(labels=="person", :);
                        app.personTimer = tic;

                        % if person is detected
                        if ~isempty(personBoxes)

                            % calculate centroid
                            centroid = round([sum([personBoxes(1) personBoxes(3)/2]) ...
                                sum([personBoxes(2) personBoxes(4)/2])]);

                            app.personTracker = trackingKF('MotionModel','2D Constant Acceleration',...
                                'EnableSmoothing',true);
                            correct(app.personTracker,centroid);

                            bbox = personBoxes;
                        
                            % annnotate frame with centroid
                            videoFrameKeypoints = insertObjectKeypoints(videoFrame,centroid,...
                                KeypointColor="white",KeypointSize = 10);


                            % track motion over time (store data)
                            app.allMotionDAT.obsTime = obsTime;
                            app.allMotionDAT.Value = centroid;
                            app.allMotionDAT.boxWidth = bbox(3);

                        else

                            videoFrameKeypoints = videoFrame;
                            app.allMotionDAT.obsTime = obsTime;
                            app.allMotionDAT.Value = [];
                            app.allMotionDAT.boxWidth = 0;


                        end

                    else


                        clear bbox

                        % set bounding box x-dim starting location
                        bbox(1) = find(xbbox>0,1,'first');

                        % set bounding x-dim length
                        bbox(3) = find(xbbox(:,:,1)>0,1,'last') - bbox(1);
                        

                        % find non-zero elements along y-dimension
                        ybbox = sum(diffImage(:,:,1),2);

                        % set bounding box y-dim starting location
                        bbox(2) = find(ybbox>0,1,'first');

                        % set bounding y-dim length
                        bbox(4) = find(ybbox>0,1,'last') - bbox(2);

                        % calculate centroid
                        centroid = round([sum([bbox(1) bbox(3)/2]) ...
                            sum([bbox(2) bbox(4)/2])]);

                        predict(app.personTracker,obsTime);
                        correctedState = correct(app.personTracker,centroid);
                        

                        if ~any(correctedState([1 4]) < 1) && ...
                                correctedState(1) <= app.vidObj.ROI(3) && ...
                                correctedState(4) <= app.vidObj.ROI(4)

                            centroid = correctedState([1 4])';


                        

                            % annnotate frame with centroid
                            videoFrameKeypoints = insertObjectKeypoints(videoFrame,centroid,...
                                KeypointColor="green",KeypointSize = 10);

                            % track motion over time (store data)
                            app.allMotionDAT.obsTime = obsTime;
                            app.allMotionDAT.Value = centroid;
                            app.allMotionDAT.boxWidth = bbox(3);


                        else

                            if toc(app.personTimer) > 1

                                [bboxes, ~, labels] = ...
                                    detect(app.personDetect,cat(3,videoFrame,videoFrame,videoFrame),Threshold=0.4);
                                personBoxes = bboxes(labels=="person", :);
                                app.personTimer = tic;

                            else
                                personBoxes = [];
                                % bboxes = zeros(1,4);
                            end

                            if ~isempty(personBoxes)

                                bbox = personBoxes;

                                % calculate centroid
                                centroid = round([sum([bbox(1) bbox(3)/2]) ...
                                    sum([bbox(2) bbox(4)/2])]);

                                videoFrameKeypoints = insertObjectKeypoints(videoFrame,centroid,...
                                    KeypointColor="blue",KeypointSize = 10);

                                % track motion over time (store data)
                                app.allMotionDAT.obsTime = obsTime;
                                app.allMotionDAT.Value = centroid;
                                app.allMotionDAT.boxWidth = bbox(3);

                            end


                        end

                    end

                    % annnotate frame with bounding box
                    processedFrame = insertObjectAnnotation(videoFrameKeypoints, ...
                        "Rectangle", bbox,"");
                    
                    % keypoint detection
                    if ~isempty(bbox) & sum(bbox) ~= 0 ...
                            && app.KeypointDetectionMenu.Checked == true

                        [keypoints,~,~] = detect(app.keypointDetector,processedFrame,bbox);

                        processedFrame = insertObjectKeypoints(processedFrame,keypoints, ...
                            KeypointColor="yellow",KeypointSize=10);
                    end

                    processedFrame = processedFrame(:,:,1);

                else

                    processedFrame = videoFrame;

                    % track motion over time (store data)
                      app.allMotionDAT.obsTime = obsTime;
                      app.allMotionDAT.Value = [];
                      app.allMotionDAT.boxWidth = [];


                end

            else

                processedFrame = videoFrame;

                % track motion over time (store data)
                app.allMotionDAT.obsTime = obsTime;
                app.allMotionDAT.Value = [];
                app.allMotionDAT.boxWidth = [];

            end

            app.previousFrame = videoFrame;
            app.postProcessedFrame = processedFrame;

        end

    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, parentapp, frame, data)
            
            imaqreset % reset all image acquistion devices

            % display available devices
            imaqInfo = imaqhwinfo;
            availableAdaptors = imaqInfo.InstalledAdaptors;

            % default select first adaptor
            tempSlctAdaptor = imaqhwinfo(availableAdaptors{1});

            % display list of adpators
            app.AdaptorDropDown.Items = availableAdaptors;

            % View available devices associated with adaptor

            alldevices = {};

            for i = 1:numel(tempSlctAdaptor.DeviceInfo)

                alldevices = cat(2,alldevices, ...
                    tempSlctAdaptor.DeviceInfo(i).DeviceName);

            end




            if ~isempty(alldevices)

                % default select first device
                deviceName = alldevices{1};

                % display list of devices
                app.DeviceDropDown.Items = alldevices;

                % Update image acquistion object parameters
                % select image acquisition device
                try

                    app.vidObj.Device = deviceName;  % specify camera if multiple inputs
                    app.vidObj.ReturnedColorSpace = "grayscale"; % specify grayscale or color

                catch
                    release(app.vidObj)
                    app.vidObj.Device = deviceName;  % specify camera if multiple inputs
                    app.vidObj.ReturnedColorSpace = "grayscale"; % specify grayscale or color
                end

                % system ready status lamp
                app.StatusLamp.Color = 'g';
 
            else

                % display list of devices
                app.DeviceDropDown.Items = {};

            end

            % reset distortion correction switch
            app.CorrectDistortionSwitch.Enable = 'off';
            app.CorrectDistortionSwitch.Value = 'Off';

            % store name of parent app as parameter in
            % child application

            app.BackendApp = parentapp;

            app.previousFrame = [];

        end

        % Value changed function: StreamSwitch
        function StreamSwitchValueChanged(app, event)
            value = app.StreamSwitch.Value;

            switch value

                case 'On'

                    %warning('off','all')
                    streamVideo(app)

                case 'Off'

                    %warning('on')
                    app.MotionDetectionSwitch.Value = 'Off';
                    drawnow

            end

        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            imaqreset

            delete(app)
        end

        % Value changed function: AdaptorDropDown
        function AdaptorDropDownValueChanged(app, event)
            value = app.AdaptorDropDown.Value;

            % display available devices
            imaqInfo = imaqhwinfo;
            availableAdaptors = imaqInfo.InstalledAdaptors;

            % available items in dropdown
            tempAvailableAdpators = app.AdaptorDropDown.Items;

            % match available adpators to user selection
            idx = find(contains(tempAvailableAdpators,value)==1);

            % select user adaptor
            tempSlctAdaptor = imaqhwinfo(availableAdaptors{idx});

            % View available devices associated with adaptor

            alldevices = {};

            for i = 1:numel(tempSlctAdaptor.DeviceInfo)

                alldevices = cat(2,alldevices, ...
                    tempSlctAdaptor.DeviceInfo(i).DeviceName);

            end


            if ~isempty(alldevices)

                % default select first device
                deviceName = alldevices{1};

                % display list of devices
                app.DeviceDropDown.Items = alldevices;

                % Update image acquistion object parameters
                % select image acquisition device
                app.vidObj.Device = deviceName;  % specify camera if multiple inputs
                app.vidObj.ReturnedColorSpace = "grayscale"; % specify grayscale or color

                % system ready status lamp
                app.StatusLamp.Color = 'g';

            else

                % display list of devices
                app.DeviceDropDown.Items = {};

                % system ready status lamp
                app.StatusLamp.Color = 'y';

            end


        end

        % Value changing function: MotionSensitivitySlider
        function MotionSensitivitySliderValueChanging(app, event)
            changingValue = event.Value;

            app.EditField.Value = changingValue;

            drawnow
        end

        % Value changed function: DeviceDropDown
        function DeviceDropDownValueChanged(app, event)
            deviceName = app.DeviceDropDown.Value;

            % Update image acquistion object parameters
            % select image acquisition device
            app.vidObj.Device = deviceName;  % specify camera if multiple inputs
            app.vidObj.ReturnedColorSpace = "grayscale"; % specify grayscale or color

            % system ready status lamp
            app.StatusLamp.Color = 'g';
        end

        % Menu selected function: MotionDetectionThresholdMenu
        function MotionDetectionThresholdMenuSelected(app, event)


            app.StatusLamp.Color = 'yellow';

            message = ['Ensure scene is empty. Do not move sensor.' ...
                ' Motion detection will begin in T-5 seconds'];
            uiconfirm(app.UIFigure,message,"Detecting motion", ...
                "Icon","warning");
            pause(5)

            app.StatusLamp.Color = 'red';

            frame_t_1 = step(app.vidObj); % grab frame
            imgNoise = 1;
            threshold = 0;
            tempEval = NaN;

            while imgNoise > 0

                app.MotionSensitivitySlider.Value = threshold;
                app.EditField.Value = round(threshold,2);
                drawnow

                while numel(tempEval) < 200 || ...
                        (var(tempEval) > 1 || isnan(tempEval(1)))

                    frame_t0 = step(app.vidObj); % grab frame

                    tempDiff = abs(frame_t_1 - frame_t0);
                    tempEst = max(tempDiff(tempDiff>threshold),[],'all');

                    if isnan(tempEval(1))
                        tempEval = tempEst;
                    else
                        tempEval = cat(1,tempEval,tempEst);
                    end

                    frame_t_1 = frame_t0;

                end

                snrIter = 0;
                tempNoiseVec = [];

                while snrIter < 30

                    frame_t_1 = step(app.vidObj); % grab frame
                    frame_t0 = step(app.vidObj); % grab frame
                    tempDAT = abs(frame_t_1 - frame_t0)>median(tempEval);
                    tempNoiseVec = cat(1,tempNoiseVec, ...
                        sum(tempDAT,'all')/sum(~tempDAT,'all'));
                    snrIter = snrIter + 1;

                end

                imgNoise = mode(tempNoiseVec);

                if imgNoise > 0

                    threshold = threshold + 0.1;
                    tempEval = NaN;

                else

                    app.MotionSensitivitySlider.Value = double(median(tempEval));
                    app.EditField.Value = round(double(median(tempEval)),2);
                    drawnow

                end

            end

            app.StatusLamp.Color = 'green';

            message = 'Motion detection complete!';
            uiconfirm(app.UIFigure,message,"Motion threshold set", ...
                "Icon","success");


        end

        % Menu selected function: Launch2DCalibrationMenu
        function Launch2DCalibrationMenuSelected(app, event)

            Single2DCameraCalibration_exported

        end

        % Menu selected function: UploadCalibrationFrameMenu
        function UploadCalibrationFrameMenuSelected(app, event)

            [filename,pathname] = uigetfile('*.*', ...
                'Select Calibration File');

            tempCalibration = load(fullfile(pathname,filename));
            app.calibrationParameters = tempCalibration.camCalibrdat;

            app.CorrectDistortionSwitch.Enable = "on";
        end

        % Menu selected function: KeypointDetectionMenu
        function KeypointDetectionMenuSelected(app, event)
            
            switch app.KeypointDetectionMenu.Checked

                case true

                    app.KeypointDetectionMenu.Checked = "off";

                case false

                    app.KeypointDetectionMenu.Checked = "on";

            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 467 421];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create MotionDetectionThresholdMenu
            app.MotionDetectionThresholdMenu = uimenu(app.UIFigure);
            app.MotionDetectionThresholdMenu.MenuSelectedFcn = createCallbackFcn(app, @MotionDetectionThresholdMenuSelected, true);
            app.MotionDetectionThresholdMenu.Text = 'Motion Detection Threshold';

            % Create CalibrationMenu
            app.CalibrationMenu = uimenu(app.UIFigure);
            app.CalibrationMenu.Text = 'Calibration';

            % Create Launch2DCalibrationMenu
            app.Launch2DCalibrationMenu = uimenu(app.CalibrationMenu);
            app.Launch2DCalibrationMenu.MenuSelectedFcn = createCallbackFcn(app, @Launch2DCalibrationMenuSelected, true);
            app.Launch2DCalibrationMenu.Text = 'Launch 2D Calibration';

            % Create UploadCalibrationFrameMenu
            app.UploadCalibrationFrameMenu = uimenu(app.CalibrationMenu);
            app.UploadCalibrationFrameMenu.MenuSelectedFcn = createCallbackFcn(app, @UploadCalibrationFrameMenuSelected, true);
            app.UploadCalibrationFrameMenu.Text = 'Upload Calibration Frame';

            % Create OptionsMenu
            app.OptionsMenu = uimenu(app.UIFigure);
            app.OptionsMenu.Text = 'Options';

            % Create KeypointDetectionMenu
            app.KeypointDetectionMenu = uimenu(app.OptionsMenu);
            app.KeypointDetectionMenu.MenuSelectedFcn = createCallbackFcn(app, @KeypointDetectionMenuSelected, true);
            app.KeypointDetectionMenu.Checked = 'on';
            app.KeypointDetectionMenu.Text = 'Keypoint Detection';

            % Create StatusLampLabel
            app.StatusLampLabel = uilabel(app.UIFigure);
            app.StatusLampLabel.HorizontalAlignment = 'right';
            app.StatusLampLabel.Position = [58 174 39 22];
            app.StatusLampLabel.Text = 'Status';

            % Create StatusLamp
            app.StatusLamp = uilamp(app.UIFigure);
            app.StatusLamp.Position = [112 174 20 20];
            app.StatusLamp.Color = [1 1 0];

            % Create StreamSwitchLabel
            app.StreamSwitchLabel = uilabel(app.UIFigure);
            app.StreamSwitchLabel.HorizontalAlignment = 'center';
            app.StreamSwitchLabel.Position = [72 49 43 22];
            app.StreamSwitchLabel.Text = 'Stream';

            % Create StreamSwitch
            app.StreamSwitch = uiswitch(app.UIFigure, 'toggle');
            app.StreamSwitch.ValueChangedFcn = createCallbackFcn(app, @StreamSwitchValueChanged, true);
            app.StreamSwitch.Position = [86 107 16 36];

            % Create AdaptorDropDownLabel
            app.AdaptorDropDownLabel = uilabel(app.UIFigure);
            app.AdaptorDropDownLabel.HorizontalAlignment = 'right';
            app.AdaptorDropDownLabel.Position = [46 285 48 22];
            app.AdaptorDropDownLabel.Text = 'Adaptor';

            % Create AdaptorDropDown
            app.AdaptorDropDown = uidropdown(app.UIFigure);
            app.AdaptorDropDown.ValueChangedFcn = createCallbackFcn(app, @AdaptorDropDownValueChanged, true);
            app.AdaptorDropDown.Position = [109 285 212 22];

            % Create DeviceDropDownLabel
            app.DeviceDropDownLabel = uilabel(app.UIFigure);
            app.DeviceDropDownLabel.HorizontalAlignment = 'right';
            app.DeviceDropDownLabel.Position = [47 232 41 22];
            app.DeviceDropDownLabel.Text = 'Device';

            % Create DeviceDropDown
            app.DeviceDropDown = uidropdown(app.UIFigure);
            app.DeviceDropDown.ValueChangedFcn = createCallbackFcn(app, @DeviceDropDownValueChanged, true);
            app.DeviceDropDown.Position = [109 232 213 22];

            % Create MUST5510VideoTestBenchLabel
            app.MUST5510VideoTestBenchLabel = uilabel(app.UIFigure);
            app.MUST5510VideoTestBenchLabel.HorizontalAlignment = 'center';
            app.MUST5510VideoTestBenchLabel.FontWeight = 'bold';
            app.MUST5510VideoTestBenchLabel.Position = [23 387 410 22];
            app.MUST5510VideoTestBenchLabel.Text = 'MUST 5510 Video Test Bench';

            % Create MotionDetectionSwitchLabel
            app.MotionDetectionSwitchLabel = uilabel(app.UIFigure);
            app.MotionDetectionSwitchLabel.HorizontalAlignment = 'center';
            app.MotionDetectionSwitchLabel.Position = [234 189 97 22];
            app.MotionDetectionSwitchLabel.Text = 'Motion Detection';

            % Create MotionDetectionSwitch
            app.MotionDetectionSwitch = uiswitch(app.UIFigure, 'slider');
            app.MotionDetectionSwitch.Position = [261 157 45 20];

            % Create MotionSensitivitySliderLabel
            app.MotionSensitivitySliderLabel = uilabel(app.UIFigure);
            app.MotionSensitivitySliderLabel.HorizontalAlignment = 'right';
            app.MotionSensitivitySliderLabel.Position = [166 103 59 30];
            app.MotionSensitivitySliderLabel.Text = {'Motion '; 'Sensitivity'};

            % Create MotionSensitivitySlider
            app.MotionSensitivitySlider = uislider(app.UIFigure);
            app.MotionSensitivitySlider.Limits = [0 1];
            app.MotionSensitivitySlider.ValueChangingFcn = createCallbackFcn(app, @MotionSensitivitySliderValueChanging, true);
            app.MotionSensitivitySlider.Position = [246 120 115 3];
            app.MotionSensitivitySlider.Value = 0.3;

            % Create EditField
            app.EditField = uieditfield(app.UIFigure, 'numeric');
            app.EditField.Editable = 'off';
            app.EditField.Position = [392 100 41 22];
            app.EditField.Value = 0.3;

            % Create CorrectDistortionSwitchLabel
            app.CorrectDistortionSwitchLabel = uilabel(app.UIFigure);
            app.CorrectDistortionSwitchLabel.HorizontalAlignment = 'center';
            app.CorrectDistortionSwitchLabel.Position = [233 52 100 22];
            app.CorrectDistortionSwitchLabel.Text = 'Correct Distortion';

            % Create CorrectDistortionSwitch
            app.CorrectDistortionSwitch = uiswitch(app.UIFigure, 'slider');
            app.CorrectDistortionSwitch.Position = [261 20 45 20];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = MUST5510_VideoApp_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

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