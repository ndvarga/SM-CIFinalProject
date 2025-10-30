%% Live Recording Set up
Fs = 44100;         % Sampling rate
frameSize = 2048;   % Samples per frame
bufferSec = 3;      % seconds of rolling buffer for MIR analysis
runTime = 90;       % total runtime (sec)
%%
% Rolling buffer to hold last few seconds of audio
Buffer = zeros(bufferSec*Fs,1);

% Create audio device reader and writer
deviceReader = audioDeviceReader('SampleRate', Fs, ...
                                 'SamplesPerFrame', frameSize);
deviceWriter = audioDeviceWriter('SampleRate', Fs);

disp('Stream started');
%%
tic;
lastAnalysisTime = 0;

while toc < runTime
    %Read and play live audio
    audioChunk = deviceReader();
    deviceWriter(audioChunk);

    %Update rolling buffer, takes the length of audio chunk which is 2048
    %samples, then skips the first 2048 samples, and concanates the new
    %2048 samples from audio chunk to the end. This updates the buffer.
    Buffer = [Buffer(length(audioChunk)+1:end); audioChunk];

    %Run MIR analysis every 1 second
    if toc - lastAnalysisTime >= 1
        try
            a = miraudio(Buffer);
            tempo = mirtempo(a);
            pulseClarity = mirpulseclarity(a);
            lowEnergy = mirlowenergy(a);
            

            % Extract pulse clarity
            pulseClarityValue = get(pulseClarity, 'Data');
            while iscell(pulseClarityValue)
                pulseClarityValue = pulseClarityValue{:};
            end

            % Extract low-energy ratio
            lowEnergyValue = get(lowEnergy, 'Data');
            while iscell(lowEnergyValue)
                lowEnergyValue = lowEnergyValue{:};
            end

            %Extract tempo
            tempoValue = get(tempo, 'Data');
            while iscell(tempoValue)
                tempoValue = tempoValue{:};
            end

            fprintf('Pulse Clarity: %.2f | Low-Energy Ratio: %.2f\n | Tempo: %.2f',...
                pulseClarityValue, lowEnergyValue, tempoValue);

        catch ME
            disp(['Analysis not ready yet (' ME.message ')']);
        end
        lastAnalysisTime = toc;
    end

    pause(0.001);  % tiny pause
end

% Release devices
release(deviceReader);
release(deviceWriter);
disp('Streaming ended.');
