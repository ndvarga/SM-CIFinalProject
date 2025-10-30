clearvars; clc; audiodevreset;
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
    "BufferSize",samplesPerFrame, "Device","Focusrite USB ASIO",...
    "Driver","ASIO");

if contains(input_info(2).Name, "Windows DirectSound")
    audioReader = audioDeviceReader("SampleRate",sr, "Device", "Microphone Array (Intel® Smart Sound Technology for Digital Microphones)",...
        "Driver","DirectSound", "SamplesPerFrame",samplesPerFrame);
end


mirParams = mirStruct('roughness', 10.0, 'novelty', 0.8, 'inharmonicity', 0.4);
augment = MusicAugmenter(myAudio(sr*10:sr*12),sr,2,samplesPerFrame, mirParams);

myFig = figure;

while true
    someAudio = audioReader.step;
    moreAudio = augment.step(someAudio);
    audio_out.step(moreAudio);

end
release(audio_out);
release(audioReader);