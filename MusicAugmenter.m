% TODO: Intro comments

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
        audioBuffer
        sampleRate
        samplesPerFrame
        maxAudioLength
        midiMap
    end

    methods (Access = public)
        function src = MusicAugmenter(audio, ...
            sampleRate, ...
            maxAudioLengthSeconds, ...
            samplesPerFrame,...
            mirParams)
            
            if size(audio, 1) < size(audio, 2)
                src.a = audio';
            else 
                src.a = audio;
            end
            src.sampleRate = sampleRate;
            src.maxAudioLength = maxAudioLengthSeconds;
            src.noiseGenerator = dsp.ColoredNoise(Color="white", BoundedOutput=true, SamplesPerFrame=samplesPerFrame);
            src.augmenter = audioDataAugmenter;
            src.samplesPerFrame = samplesPerFrame;
            src.mirParams = mirParams;
        end

        function audio_out = step(src, audio)
            % This will be run fairly frequently to step the audio outuput stream. 
            % It will apply everything and return the augmented
            % audio signal


            % Append the incoming audio to the audio buffer that is used to
            % generate resampling audio
            
            % Assume we need 2 rows if we have 1 row in audio
            if size(audio, 1) < size(audio, 2)
                audio = audio';
            end
            if size(audio, 2) ~= size(src.a, 2)
                audio = [audio,audio];
            end
            appended_audio = cat(1, src.a, audio);
            
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
            audio_out = audio;
            % soundsc(audio, src.sampleRate)
        end

        function noisy_audio = addNoise(src, audio)
            % function which uses the dsp.Noise to generate noise for the
            % audio based on the mirParams.roughness parameter
            
            mapped_roughness = src.map(src.mirParams.roughness, 0, 500, 0, 1);
            % generate some noise for each channel
            
            noise = src.noiseGenerator.step();
            noise = noise * mapped_roughness;                

            noisy_audio = noise + audio;

        end


        function src = resample(src, n_resamples)
            % Divide audio into 64 parts
            if isempty(n_resamples)
            n_resamples = 64;
            end
            if ~isempty(src.a) 
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