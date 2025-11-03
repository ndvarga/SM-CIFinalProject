clearvars; clc; audiodevreset;
close all
try
    release(audio_out);
catch

end
% consts
sr = 44100;
samplesPerFrame = 1024;

% get audio device info
info = audiodevinfo;
input_info = info.input;
output_info = info.output;
myAudio = audioread("being a girl [2044987124].mp3");

% hardcoded fo today
audio_out = audioDeviceWriter("SampleRate",sr,...
    "BufferSize",samplesPerFrame, "Device","Speakers (Realtek(R) Audio)",...
    "Driver","DirectSound");

if contains(input_info(2).Name, "Windows DirectSound")
    audioReader = audioDeviceReader("SampleRate",sr, "Device", "Microphone Array (Intel® Smart Sound Technology for Digital Microphones)",...
        "Driver","DirectSound", "SamplesPerFrame",samplesPerFrame);
end


mirParams = mirStruct('roughness', 10.0, 'novelty', 0.8, 'inharmonicity', 0.4);
augment = MusicAugmenter(myAudio(sr*10:sr*12),sr,8,samplesPerFrame, mirParams);

% myFig = figure;

% Create a figure with a stop button
fig = figure;

pause(1)
i = 0;
while ishandle(fig)
    someAudio = audioReader.step;
    [augment, moreAudio] = augment.step(someAudio);
    % moreAudio = augment.getAudioOut;
    audio_out.step(moreAudio);
    drawnow;
    i = i+1;
end
release(audio_out);
release(audioReader);
delete(audio_out)
delete(audioReader)
clearvars;