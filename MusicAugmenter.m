%   MusicAugmenter is a class that can implement real-time audio
%   augmentation with noise and resampling.

%{
    MusicAugmenter
    Copyright 2025 (c) Nikolas Varga
    MUST5510
    Northeastern University

%}

% removed mirparams in constructor 11/20/2025
% TODO: stereo processing?

classdef MusicAugmenter
% Use sound or soundsc to read out a certain number of frames
% Buffer object, could play buffers of zeros
    properties (Access = public)
        a % audio object
        noiseGenerator % dsp.ColoredNoise object
        augmenter % audioDataAugmenter object
        delayEffect % audioexample delay
        mirParams = mirStruct("brightness",[],"roughness",[],"inharmonicity",[])
        
    end
    
    properties (Access = private)
        sampleRate % audio sample rate
        samplesPerFrame % audio samples per frame (processing step size pretty much)
        maxAudioLength % The maximal length of src.a in seconds
        midiMap % unused rn
        tempAudio % basically a buffer to hold our processed audio

        mirMax = mirStruct("brightness",[],"roughness",[],"inharmonicity",[])
        mirMin = mirStruct("brightness",[],"roughness",[],"inharmonicity",[])
    end

    methods (Access = public)
        function src = MusicAugmenter(audio, ...
            sampleRate, ...
            maxAudioLengthSeconds, ...
            samplesPerFrame...
            )
            
            % make sure the audio passed to the object is the right orientation
            if size(audio, 1) < size(audio, 2)
                audio = audio';
            end
            
            % also just make it mono
            if size(audio, 2) > 1
                audio = mean(audio,2);
            end

            src.a = audio;

            src.sampleRate = sampleRate;
            src.maxAudioLength = maxAudioLengthSeconds;
            src.noiseGenerator = dsp.ColoredNoise(Color="custom", BoundedOutput=true, SamplesPerFrame=samplesPerFrame, InverseFrequencyPower=0.1);
            src.augmenter = audioDataAugmenter;
            delayEffect = audioexample.Echo;
            delayEffect.Delay = 1.0;
            delayEffect.SampleRate = sampleRate;
            delayEffect.WetDryMix = 0.4;
            src.delayEffect = delayEffect;
            src.samplesPerFrame = samplesPerFrame;
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
            
            [audio_rows, audio_columns] = size(audio);
            
            % Ensure the size of the audio input is the same as
            % samplesPerFrame
            if audio_rows < src.samplesPerFrame
                disp('size of audio input is less than frame size!')
                % make padding size of audio
                padding = zeros([src.samplesPerFrame - audio_rows,audio_columns]);
                audio = [padding(:,audio_columns); audio]; % Pad the audio with zeros
            elseif audio_rows > src.samplesPerFrame
                disp('size of audio input is greater than frame size!')
                audio = audio(1:src.samplesPerFrame);            
            end
            
            if audio_columns > 1
                audio = mean(audio,2);
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
            
            % TODO: use historical maximum
            % resample based on roughness and time
            if ~isempty(src.mirParams.inharmonicity) & ~isempty(src.mirMax.inharmonicity)
                if (src.mirParams.inharmonicity > src.mirMax.inharmonicity) && (randi(10) == 1)
                    src.resample(64,0.8,2);
                end
            end
            % add noise
            noiseScale = 1;
            audio = src.addNoise(audio, noiseScale);
            % set the output buffer value
            src.tempAudio = audio;

            % return the audio_out
            audio_out = audio;
        end

        function noisy_audio = addNoise(src, audio, noiseScale)
            % function which uses the dsp.Noise to generate noise for the
            % audio based on the mirParams.roughness parameter
            
            
          
            
            % maps roughness from its input range to [0,1]
            if ~isempty(src.mirParams.roughness) && ~isempty(src.mirMax.roughness)
                if src.mirParams.roughness > 10
                    mapped_roughness = src.map(src.mirParams.roughness, ...
                    src.mirMin.roughness, src.mirMax.roughness, 0, 1);
                else
                    mapped_roughness = 0;
                end
            else
                mapped_roughness = 0;
            end
            
            % generate some noise
            noise = src.noiseGenerator.step();

            % scale noise by mapped roughness
            noise = noise * mapped_roughness * noiseScale;             

            % add noise to audio signal
            
            noisy_audio = noise.*audio;
  
            % normalize noisy audio 
            if max(noisy_audio) > 1
                noisy_audio = noisy_audio ./ max(noisy_audio);
            end

        end


        function src = resample(src, n_resamples, base_delay_len, max_resample_len)
            % This function resamples the audio in src.a
            % by dividing it into 64 parts and picking a random stop and
            % start index out of those.You can also pass it
            % max_resample_len in seconds, which will limit the length of
            % the resampled audio
            % 
            arguments
                src 
                n_resamples {mustBeInteger}
                base_delay_len {mustBeLessThan(base_delay_len, 1)}
                max_resample_len = 0
            end

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
                % get indices to pick from tempMusicMarker.
                % resampleIndex in the range (1,64)
                resampleIndex = randi(n_resamples,2);
                resampleIndex = resampleIndex(:,1);
                
                % pick a random float, and scale it by the inharmonicity
                % This "penalizes" inharmonicity by making the resampling
                % more chaotic with an increase in inharmonicity

                if isa(src.mirParams, "mirStruct")
                    randomness = rand(1) * src.mirParams.brightness*3;
                else
                    randomness = rand(1);
                end
                
                % We will add one to make sure our index is still in the
                % correct MATLAB indexing range. We also multiply our
                % randomness value by the resample indices, round to make
                % sure it's a valid index, and sort so the lower one is
                % first

                resampleIndices = sort(round((randomness.*resampleIndex)+1));

                if resampleIndices(2) > n_resamples
                    resampleIndices(2) = n_resamples;
                end
                
                if resampleIndices(1) < 1
                    resampleIndices(1) = 1;
                end
                
                % not sure if we need to sort here, but these are the
                % actual sample indices for the audio stream
                audioIndices = sort([round(tempMusicMarker(resampleIndices(1))) + 1,...
                    ceil(tempMusicMarker(resampleIndices(2)))]);

                % If the indicies result in something llonger than the
                % specified maximum length, take those samples away from
                % the end
                if max_resample_len > 0
                    if audioIndices(2) - audioIndices(1) > src.sampleRate * max_resample_len 
                        audioIndices(2) = audioIndices(1) + floor(src.sampleRate * max_resample_len);
                    end
                elseif max_resample_len < 0
                    error('Resample len must be positive!')
                end


                % play the resampled audio using nonblocking soundsc
                % This means the resampling can occur in parallel with the other stuff
                resampledAudio = src.a(audioIndices(1):audioIndices(2));
                
                % apply delay to the audio up to 8 times depending on the
                % 8 biased coin flips
                
                nHeads = 0;
                for i = 1:8
                    coinFlip = rand(1);
                    if coinFlip > 0.6
                        nHeads = nHeads + 1;
                    end
                end
                fprintf('resampling, delaying %d times\n', nHeads);
                release(src.delayEffect);
                % set the feedback on the delay to be mapped to the
                % numberof heads
                src.delayEffect.FeedbackLevel = src.map(nHeads,0,8,0,0.5);
                
                % set the delay time in s
                src.delayEffect.Delay = base_delay_len;
                y = resampledAudio;
                for i = 1:nHeads
                   y = src.delayEffect(resampledAudio); 
                end
                y = normalize(y, 'range') * 2 - 1;
                sound(y,src.sampleRate)
                % player = audioplayer(y,src.sampleRate,16);
                % playblocking(player)
               
            end
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

            if isempty(src.mirMax.roughness)
                % just set max to current
                src.mirMax = mirParams;

                src.mirMin.roughness = 1;
                src.mirMin.brightness = 1;
                src.mirMin.inharmonicity = 1;
            else
                % unpack mirParams
                new_roughness = mirParams.roughness;
                new_inharmonicity = mirParams.inharmonicity;
                new_brightness = mirParams.brightness;


                src.mirMax.roughness = max(src.mirMax.roughness, new_roughness);
                src.mirMax.inharmonicity = max(src.mirMax.inharmonicity, new_inharmonicity);
                src.mirMax.brightness = max(src.mirMax.brightness, new_brightness);
                
                src.mirMin.roughness = min(src.mirMin.roughness, new_roughness);
                src.mirMin.inharmonicity = min(src.mirMin.inharmonicity, new_inharmonicity);
                src.mirMin.brightness = min(src.mirMin.brightness, new_brightness);
            end
                         
            src.mirParams = mirParams; % Update the MIR parameters


        end



        function audio_out = getAudioOut(src)
            audio_out = src.tempAudio;
        end
    end

    methods (Access = protected)
        function mapped = map(~, input, minIn, maxIn, minOut, maxOut)
            mapped = minOut + ((input - minIn) / (maxIn - minIn)) * (maxOut - minOut);
        end
    end
end