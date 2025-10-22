classdef MusicAugmenter

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
    end

    methods (Access = public)
        function src = MusicAugmenter(audio, ...
            sampleRate, ...
            maxAudioLengthSeconds, ...
            samplesPerFrame,...
            mirParams)

            src.a = audio;
            src.sampleRate = sampleRate;
            src.maxAudioLength = maxAudioLengthSeconds;
            src.noiseGenerator = dsp.ColoredNoise(color="white", BoundedOutput=true, SamplesPerFrame=samplesPerFrame);
            src.augmenter = audioDataAugmenter;
            src.samplesPerFrame = samplesPerFrame;
            src.mirParams = mirParams;
        end

        function src = step(src, audio)
            % This will be run fairly frequently to step the audio outuput stream. 
            % It will apply everything and return the augmented
            % audio signal


            % Append the incoming audio to the audio buffer that is used to
            % generate resampling audio
            appended_audio = cat(1, src.a, audio);
            
            if size(appended_audio, 1) > src.sampleRate * src.maxAudioLength
                src.a = [];
            else
                src.a = appended_audio;
            end
            
            src.addNoise(audio);


        end

        function noisy_audio = addNoise(src, audio)
            % create an array of zeros for the noisy audio to be stored in
            noisy_audio = zeros(size(audio));
            
            mapped_roughness = src.map(src.mirParams("roughness"), 0, 500, 0, 1);
            % generate some noise for each channel
            for i = 1:size(audio, 1)
                noise = src.noiseGenerator.step();
                noise = noise * mapped_roughness;                

                noisy_audio(i,:) = noise + audio;
            end

        end


        function src = resample(src)
           % Divide audio into 64 parts
           if ~isempty(src.a) 
               tempMusicMarker = linspace(1,src.a, ...
                    64);
           

                % Get the part of the audio track between hexagram 1
                % and hexagram 2
                tempMusicMarker = tempMusicMarker(hexagrams(1):hexagrams(2));
                
                % Divides our segment into 128 frames then multiply by
                % samplesperframe
           end
            src.midiMap = linspace(tempMusicMarker(1), ...
                tempMusicMarker(2), ...
                128) * src.samplesPerFrame;
        end

        function getMidi()
            if ~isempty(src.midiBank)

                sampleSlct = app.midiMap([msg.Note]);

                sampleSlct = sampleSlct(1:2:end);

                for keysPressed = 1:numel(sampleSlct)

                    % extract frame from audio
                    tempAudio = audioread(app.fileReader.Filename, ...
                        [round(sampleSlct(keysPressed)), ...
                        round(sampleSlct(keysPressed))+...
                        app.fileReader.SamplesPerFrame-1]);

                    % store wavetable synthesizer output
                    app.audioOut(:, ...
                        keysPressed) = ...
                        sum(tempAudio,2);

                end

                if numel(sampleSlct) < 16

                    temp_idx = numel(sampleSlct);
                    app.audioOut(:,temp_idx+1:end) = zeros(app.fileReader.SamplesPerFrame, ...
                        16-temp_idx);

                end

            midiOut = normalize(sum(app.audioOut,2),'range');
        
        else

            app.audioOut = zeros(app.fileReader.SamplesPerFrame,16);
            midiOut = sum(app.audioOut,2);

            end

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
            mapped = new_min + ((input - minIn) / (maxIn - minIn)) * (maxOut - minOut);
        end
    end
end