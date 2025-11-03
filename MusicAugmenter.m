    % MusicAugmenter is a class that can implement real-time audio
    % augmentation with noise and resampling.
    %{
        MusicAugmenter
        Copyright 2025 (c) Nikolas Varga
        MUST5510
        Northeastern University
       

    %}


classdef MusicAugmenter
% Use sound or soundsc to read out a certain number of frames
% Buffer object, could play buffers of zeros
    properties (Access = public)
        a % MIRToolbox audio object
        noiseGenerator % dsp.ColoredNoise object
        augmenter % audioDataAugmenter object
        mirParams 
    end
    
    properties (Access = private)
        sampleRate % audio sample rate
        samplesPerFrame % audio samples per frame (processing step size pretty much)
        maxAudioLength % The maximal length of src.a in seconds
        midiMap % unused rn
        tempAudio % basically a buffer to hold our processed audio
    end

    methods (Access = public)
        function src = MusicAugmenter(audio, ...
            sampleRate, ...
            maxAudioLengthSeconds, ...
            samplesPerFrame,...
            mirParams)
            
            % make sure the audio passed to the object is the right orientation
            if size(audio, 1) < size(audio, 2)
                src.a = audio';
            else 
                src.a = audio;
            end
            src.sampleRate = sampleRate;
            src.maxAudioLength = maxAudioLengthSeconds;
            src.noiseGenerator = dsp.ColoredNoise(Color="custom", BoundedOutput=true, SamplesPerFrame=samplesPerFrame, InverseFrequencyPower=0);
            src.augmenter = audioDataAugmenter;
            src.samplesPerFrame = samplesPerFrame;
            src.mirParams = mirParams;
        end

        function [src, audio_out] = step(src, audio)
            % This will be run fairly frequently to step the audio outuput stream. 
            % It will apply everything and return the augmented
            % audio signal
            

            
            % Put audio row-wise
            [audio_rows, audio_columns] = size(audio);
            if audio_rows < audio_columns
                audio = audio';
            end
            
            [audio_rows, ~] = size(audio);

            % Ensure the size of the audio input is the same as
            % samplesPerFrame
            if audio_rows < src.samplesPerFrame
                disp('size of audio input is less than frame size!')
                padding = zeros([src.samplesPerFrame - audio_rows,1]);
                audio = [padding; audio]; % Pad the audio with zeros
            elseif audio_rows > src.samplesPerFrame
                disp('size of audio input is greater than frame size!')
                audio = audio(1:src.samplesPerFrame);            
            end
            


            % if input audio is not stereo and audio buffer is stereo,
            % make input audio stereo
            if size(audio, 2) == 1 && size(src.a, 2) == 2
                audio = [audio,audio];
            end

            % Append the incoming audio to the audio buffer that is used to
            % generate resampling audio
            appended_audio = cat(1, src.a, audio);
            
            % This will gradually overwrite the stuff in the stored audio
            % array src.a, which holds on to recorded audio

            if size(appended_audio, 1) > src.sampleRate * src.maxAudioLength
                src.a = appended_audio(...
                    1+max(size(audio)):end);
            else
                src.a = appended_audio;
            end
            
            if (src.mirParams.novelty > 0.5) && (randi(10) == 1)
                src.resample(64);
            end
            % add noise
            audio = src.addNoise(audio);
            % set the output buffer value
            src.tempAudio = audio;

            % return the audio_out
            audio_out = audio;
        end

        function noisy_audio = addNoise(src, audio)
            % function which uses the dsp.Noise to generate noise for the
            % audio based on the mirParams.roughness parameter
            
            % TODO: NO MORE CONST
            brightness = 0;
            
            
            % maps roughness from its input range to [0,1]
            mapped_roughness = src.map(src.mirParams.roughness, 0, 500, 0, 1);
            % generate some noise for each channel
            
            noise = src.noiseGenerator.step();
            % scale noise by mapped roughness
            noise = noise * mapped_roughness;                

            % add noise to audio signal
            % TODO: might be fun to multiply it
            noisy_audio = noise + audio;

        end


        function src = resample(src, n_resamples, max_resample_len)
            % Divide audio into 64 parts
            if isempty(n_resamples)
            n_resamples = 64;
            end

            % make sure audio memory isn't empty
            if ~isempty(src.a) 
                % Divide the sample indices into n_resamples
                tempMusicMarker = linspace(1, max(size(src.a)), ...
                    n_resamples);
               
      
                % tempMarkers = rand(2)/src.mirParams.inharmonicity*src.samplesPerFrame;
                resampleIndex = sort(randi(n_resamples,2));
                resampleIndex = resampleIndex(:,1);
                randomness = rand(1) * src.mirParams.inharmonicity;
                resampleIndices = sort(ceil(randomness.*resampleIndex));
                
                audioIndices = sort([tempMusicMarker(resampleIndices(1)),...
                    tempMusicMarker(resampleIndices(2))]);
                resampledAudio = src.a(audioIndices(1):audioIndices(2));
                soundsc(resampledAudio,src.sampleRate)
               
           end
            src.midiMap = linspace(tempMusicMarker(1), ...
                tempMusicMarker(2), ...
                128) * src.samplesPerFrame;
        end

        function src = getMidi(src)
            % As an option I can play audio out directly from the getMidi function


            midiOut = normalize(sum(src.audioOut,2),'range');
            soundsc(resampledAudio, src.sampleRate)

        

        end

        function src = updateMIRParams(src, mirParams)
        % update the MIRParams object
            if ~isa(mirParams,'mirStruct')
                raise('mirParams is not type mirStruct!')
            end
            src.mirParams = mirParams; % Update the MIR parameters
        end

        function audio_out = getAudioOut(src)
            audio_out = src.audioBuffer;
        end
    end

    methods (Access = private)
        function mapped = map(~, input, minIn, maxIn, minOut, maxOut)
            mapped = minOut + ((input - minIn) / (maxIn - minIn)) * (maxOut - minOut);
        end
    end
end