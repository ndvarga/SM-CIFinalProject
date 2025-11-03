%{ 
edited by Zoe Mumford
Uses code/ideas from:
MUST5510_Week2_1
MUST5510_Week1_1

A.K. McCullough, PhD, MS, MA
MUST 5973
Spring 2025
Northeastern University
%}

%% prepare workspace and audiostreamer object
clear; clc; close all;
audiodevreset

%set up audiostreamer object in full duplex mode, enabling both recording and
%playback.
SampleRate = 44100;
as = audiostreamer("full-duplex",SampleRate);
as.DeviceBufferSize = 512;

%configure the minimum amount of samples for recorder and player
%callback
%recorder is 1024 by default, player is 16384
numSamples = 512;
as.RecorderMinSamples = numSamples; 
as.PlayerMinSamples = numSamples;

%this has to be set to a number instead of the default "auto" in order to test loopback latency.
as.PlayerChannels = 1;

%Hard code selecting ASIO as the audio driver.
as.Driver = "ASIO";

%% configure audiostreamer I/O via command window

% get all available OUTPUT devices:
playernames = audiostreamer.getPlayerNames;
% display each device name in command window
for i = 1:numel(playernames) 
    disp(playernames(i))
end

%let user select device and set audiostreamer accordingly
userChoice = input('\n Enter which audio Output you would like to use: ')
as.Player = playernames(userChoice);

%get all available INPUT devices:
recordernames = as.getRecorderNames;
%display in command window
for i = 1:numel(recordernames)
    disp(recordernames(i))
end

%let user select device and set audiostreamer accordingly
userChoice = input('\n Enter which audio Input you would like to use: ')
as.Recorder = recordernames(userChoice);

%% check and store latency in milliseconds
latencyinMs = measureLoopbackLatency(as)*1000/as.SampleRate;

%% record and play audio with audiostreamer - play fcn

%set up scope to see if signal is being inputted
% scope = timescope('SampleRate', as.SampleRate, ...
%     'YLimits', [-1, 1], ...
%     'TimeSpan',0.75,...
%     'TimeSpanOverrunAction',"scroll");

disp('Recording Now.... ');

% start recording
 record(as);
% pause briefly to avoid "flushed previously recorded signal" Warning
 pause(1)

while true
   
    if as.NumRecorderSamples > 0    %if there are samples in the recorder buffer,
        audio = read(as,numSamples);    % read in the recorded audio (same as audioDeviceReader)
        play(as,audio);                 % play audio (same functionality as audioDeviceWriter)
        underruns = as.getUnderrunCount;% check for underruns
        
    end

end

%% using playrec fcn to start play and record simultaneously

%record enough samples to call the next functions
record(as,numSamples);
pause(1)

while true
    
     if as.NumRecorderSamples > 0   %if there are samples in the recorder buffer,
        audio = read(as,numSamples);    %read in recorded audio
        playrec(as,audio,numSamples);   %play and record simultaneously
        underruns = as.getUnderrunCount; % check for underruns
     end

end

%% stop recording/playback and release object

stop(as);
release(as);

%% old code using audioDeviceReader and audioDeviceWriter to record/play

% reader = audioDeviceReader;
% deviceWriter = audioDeviceWriter("BufferSize",1024,"SampleRate",44100,"Device","Speakers (Realtek(R) Audio)"); % setup writer, not used yet
% deviceWriter.Driver = "ASIO";
% 
% getAudioDevices(deviceWriter)
% 
% disp('Recording.... Speak into microphone now');
% tic;
% while toc < recordinglength
%     audio = reader(); %data from audioreader
%     scope(audio)
%     deviceWriter(audio) %write to device audio output (how to manage the delay?)
% 
% end
% disp('Recording complete');
% release(reader);             % release device reader
% release(deviceWriter);       %release device writer (not yet used) 