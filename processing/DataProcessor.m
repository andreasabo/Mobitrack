classdef DataProcessor < handle
    
    properties        
        timeSinceLastSegment = [];
        pitchSinceLastSegment = []; % Note: this is in rad
        rollSinceLastSegment = []; % rad
        
        SVMModel;
        rawData = struct();
        smoothedData = struct(); % for debugging only for now
        smoothingWindowSize;
        
        % Segmentation Parameters
        lag;
        peakThreshold;
        influence;
        
        % Segmentation / peak finding data vectors
        filteredData = [];
        avgFilter = [];
        stdFilter = [];
        signals = [];
        lastSignalEdgeIdx = -1;
        maxSamplesToTakeTemporalMean = 1000;
        offsetAfterMaxSamplesToTakeTemporalMean = 10;
        segmentInds = [];
        segmentLabels = [];
        
        last_event_ind = 1;
        second_last_event_ind = 1;
        
        % Feature Parameters
        % Pitch
        % 1 - mean, 2 - std, 3 - skewness, 4 - kurtosis, 5 - max, 6 - min, 7 -
        % signal range, 8 - duration, 9 - 25th percentile, 10 - median, 11 - 75th
        % percentile, 12 - mean freq, 13 - energy of spectrum, 14 - entropy of
        % spectrum

        % Roll
        % 15 - mean, 16 - std, 17 - skewness, 18 - kurtosis, 19 - max, 20 - min, 21 -
        % signal range, 22 - duration, 23 - 25th percentile, 24 - median, 25 - 75th
        % percentile, 26 - mean freq, 27 - energy of spectrum, 28 - entropy of
        % spectrum
%         featureSets = [2, 7, 8, 16, 21, 22];
%         featureSets = 1:28;
        featureSets = [2, 7, 16, 21];
        featuresForLastSegment = [];
        
        firstStep;
        repDetected = 0;
        numSamplesSeen = 0;
    end
    
    methods
        function [obj] = DataProcessor(SVMModel, smoothingWindowSize, segmentationLag, segmentationThreshold, segmentationInfluence) % initialize the DataProcessor object
            obj.SVMModel = SVMModel;
            obj.smoothingWindowSize = smoothingWindowSize;
            obj.lag = segmentationLag;
            obj.peakThreshold = segmentationThreshold;
            obj.influence = segmentationInfluence;
            
            % Initialize peak finding vector sizes
            obj.filteredData = zeros(1, segmentationLag + 1);
            obj.avgFilter = zeros(1, segmentationLag + 1)';
            obj.stdFilter = zeros(1, segmentationLag + 1)';
            obj.signals = zeros(1, segmentationLag + 1)';
            
            obj.firstStep = 1;
        end
        
        function [obj] = processStep(obj, data, time)
            obj.repDetected = 0;
            
            % Estimate pitch and roll using the complimentary filter
            obj.getAngles(data, time);
            
            % Segment
            [obj, foundSeg] = segment(obj, obj.pitchSinceLastSegment(end));
            
            % If end of segment, classify
            if(foundSeg)
                fprintf('Segment found');
                % extract features from last segment
                extractFeatures(obj);
                
                % classify
                obj.repDetected = predict(obj.SVMModel, obj.featuresForLastSegment);
                obj.segmentLabels = [obj.segmentLabels; obj.repDetected(end)];
            end
            
            obj.firstStep = 0;
            obj.numSamplesSeen = obj.numSamplesSeen + 1;
            

        end
        function [obj] = plotResult(obj)
            figure, hold on
            plot(obj.timeSinceLastSegment, ...
                obj.pitchSinceLastSegment .* 180.0 ./ pi, 'Color', 'blue', 'LineWidth', 1.5)
            plot(obj.timeSinceLastSegment, ...
                obj.rollSinceLastSegment .* 180.0 ./ pi, 'Color', 'magenta', 'LineWidth', 1.5)
%             title('Exercise Repetition Detection', 'FontWeight', 'bold')
            xlabel('Time (seconds)', 'FontWeight', 'bold')
            xlim([obj.timeSinceLastSegment(1), obj.timeSinceLastSegment(end)])
            ylabel('Angle of IMU with Respect to Gravity (degrees)', 'FontWeight', 'bold')
            sigPitch = obj.pitchSinceLastSegment .* 180.0 ./ pi;
            plot(obj.timeSinceLastSegment(obj.signals~=0), ...
                sigPitch(obj.signals~=0),'k*','LineWidth',1.5);
            
            xlim([18, 150]);
            
            for i = 1:size(obj.segmentInds,1)
                
                if(obj.segmentLabels(i)) % rep detected
                    rectangle('Position', [obj.timeSinceLastSegment(obj.segmentInds(i,1)),...
                    min(obj.pitchSinceLastSegment)*180/pi, ...
                    obj.timeSinceLastSegment(obj.segmentInds(i,2)) - obj.timeSinceLastSegment(obj.segmentInds(i,1)), ...
                    max(obj.pitchSinceLastSegment)*180/pi - min(obj.pitchSinceLastSegment)*180/pi], 'EdgeColor', 'green');
                else
                    rectangle('Position', [obj.timeSinceLastSegment(obj.segmentInds(i,1)),...
                    min(obj.pitchSinceLastSegment)*180/pi, ...
                    obj.timeSinceLastSegment(obj.segmentInds(i,2)) - obj.timeSinceLastSegment(obj.segmentInds(i,1)), ...
                    max(obj.pitchSinceLastSegment)*180/pi - min(obj.pitchSinceLastSegment)*180/pi], 'EdgeColor', 'red');
                end
 
            end
            legend('Pitch', 'Roll', 'Peaks');
            
        end
    end
    
    
    methods (Access = private)
        function [obj] = extractFeatures(obj)
            % Initialize variables
%             obj.featuresForLastSegment = [];
            startIdx = obj.segmentInds(end,1);
            endIdx = obj.segmentInds(end,2);
            
            % Calculate frequency component for pitch if needed
            if( any(obj.featureSets == 12) || ...
                    any(obj.featureSets == 13) || ...
                    any(obj.featureSets == 14) )
                L = endIdx-startIdx;
                Y_pitch = abs(fft(obj.pitchSinceLastSegment(startIdx:endIdx))/L);
                Y_pitch = Y_pitch(1:round(L/2+1));
            end
            
            % Calculate frequency component for roll if needed
            if( any(obj.featureSets == 26) || ...
                    any(obj.featureSets == 27) || ...
                    any(obj.featureSets == 28) )
                L = endIdx-startIdx;
                Y_roll = abs(fft(obj.rollSinceLastSegment(startIdx:endIdx))/L);
                Y_roll = Y_roll(1:round(L/2+1));
            end
            
            currentFeature = zeros(1,length(obj.featureSets));
            
            % Compute features
            for f = 1:length(obj.featureSets)
                switch obj.featureSets(f)
                    case 1 % pitch mean
                        currentFeature(f) = mean(obj.pitchSinceLastSegment(startIdx:endIdx));
                    case 2 % pitch std
                        currentFeature(f) = std(obj.pitchSinceLastSegment(startIdx:endIdx));
                    case 3 % pitch skewness
                        currentFeature(f) = skewness(obj.pitchSinceLastSegment(startIdx:endIdx));
                    case 4 % pitch kurtosis
                        currentFeature(f) = kurtosis(obj.pitchSinceLastSegment(startIdx:endIdx));
                    case 5 % pitch max
                        currentFeature(f) = max(obj.pitchSinceLastSegment(startIdx:endIdx));
                    case 6 % pitch min
                        currentFeature(f) = min(obj.pitchSinceLastSegment(startIdx:endIdx));
                    case 7 % pitch signal range
                        currentFeature(f) = max(obj.pitchSinceLastSegment(startIdx:endIdx)) - min(obj.pitchSinceLastSegment(startIdx:endIdx));
                    case 8 % pitch duration
                        currentFeature(f) = max(obj.timeSinceLastSegment(startIdx:endIdx)) - min(obj.timeSinceLastSegment(startIdx:endIdx));
                    case 9 % pitch 25th percentile
                        currentFeature(f) = prctile(obj.pitchSinceLastSegment(startIdx:endIdx), 25);
                    case 10 % pitch median
                        currentFeature(f) = prctile(obj.pitchSinceLastSegment(startIdx:endIdx), 50);
                    case 11 % pitch 75th percentile
                        currentFeature(f) = prctile(obj.pitchSinceLastSegment(startIdx:endIdx), 75);
                    case 12 % pitch mean freq
                        currentFeature(f) = mean(Y_pitch);
                    case 13 % pitch energy of spectrum,
                        currentFeature(f) = sum(Y_pitch.^2);
                    case 14 % pitch entropy of spectrum
                        currentFeature(f) = entropy(Y_pitch);
                    case 15 % roll mean
                        currentFeature(f) = mean(obj.rollSinceLastSegment(startIdx:endIdx));
                    case 16 % roll std
                        currentFeature(f) = std(obj.rollSinceLastSegment(startIdx:endIdx));
                    case 17 % roll skewness
                        currentFeature(f) = skewness(obj.rollSinceLastSegment(startIdx:endIdx));
                    case 18 % roll kurtosis
                        currentFeature(f) = kurtosis(obj.rollSinceLastSegment(startIdx:endIdx));
                    case 19 % roll max
                        currentFeature(f) = max(obj.rollSinceLastSegment(startIdx:endIdx));
                    case 20 % roll min
                        currentFeature(f) = min(obj.rollSinceLastSegment(startIdx:endIdx));
                    case 21 % roll signal range
                        currentFeature(f) = max(obj.rollSinceLastSegment(startIdx:endIdx)) - min(obj.rollSinceLastSegment(startIdx:endIdx));
                    case 22 % roll duration
                        currentFeature(f) = max(obj.timeSinceLastSegment(startIdx:endIdx)) - min(obj.timeSinceLastSegment(startIdx:endIdx));
                    case 23 % roll 25th percentile
                        currentFeature(f) = prctile(obj.rollSinceLastSegment(startIdx:endIdx), 25);
                    case 24 % roll median
                        currentFeature(f) = prctile(obj.rollSinceLastSegment(startIdx:endIdx), 50);
                    case 25 % roll 75th percentile
                        currentFeature(f) = prctile(obj.rollSinceLastSegment(startIdx:endIdx), 75);
                    case 26 % roll mean freq
                        currentFeature(f) = mean(Y_roll);
                    case 27 % roll energy of spectrum
                        currentFeature(f) = sum(Y_roll.^2);
                    case 28 % roll entropy of spectrum
                        currentFeature(f) = entropy(Y_roll);
                    otherwise
                        currentFeature(f) = 0;
                end
            end
            % Add feature to list
            obj.featuresForLastSegment = [obj.featuresForLastSegment; currentFeature];
        end
        
        function [obj, foundSeg] = segment(obj, data)
            foundSeg = 0;
            % Haven't seen enough samples, just add to data vector
            if (obj.numSamplesSeen <= obj.lag)
                obj.filteredData(obj.numSamplesSeen+1) = data;
            elseif (obj.numSamplesSeen == obj.lag + 1)
                  % Prepare the avg and std filters
                  obj.avgFilter(obj.lag+1,1) = mean(obj.filteredData(1:obj.lag+1));
                  obj.stdFilter(obj.lag+1,1) = std(obj.filteredData(1:obj.lag+1));
            else % Process normally
                % If new value is a specified number of deviations away
                if abs(data-obj.avgFilter(end)) > obj.peakThreshold*obj.stdFilter(end)
                    if data > obj.avgFilter(end)
                        obj.signals = [obj.signals; 1]; % Positive signal
                    else
                        obj.signals = [obj.signals; -1]; % Negative signal
                    end
                    % Make influence lower
                    newFilteredData = obj.influence*data+(1-obj.influence)*obj.filteredData(end);
                    obj.filteredData = [obj.filteredData, newFilteredData];
                else
                    % No signal
                    obj.signals = [obj.signals; 0];
                    obj.filteredData = [obj.filteredData, data];
                end
                % Adjust the filters
                obj.avgFilter = [obj.avgFilter; mean(obj.filteredData(end-obj.lag:end))];
                obj.stdFilter = [obj.stdFilter; std(obj.filteredData(end-obj.lag:end))];
                
                [obj, foundSeg] = fixSegments(obj);
            end
        end
        
        function [obj, foundSeg] = fixSegments(obj)
            foundSeg = 0;
            %      0 to  1 --> rising edge --> store idx
            %      1 to  0 --> falling edge --> fix signal + reset idx
            %      0 to -1 --> falling edge --> store idx
            %     -1 to  0 --> rising edge --> fix signal + reset idx
            %     -1 to  1 --> fix signal + store idx
            %      1 to -1 --> fix signal + store idx
            %       if we haven't seen  anything in
            %       obj.maxSamplesToTakeTemporalMean, just use last edge.
        
            if((obj.signals(end-1) == 0) && (obj.signals(end) == 1))
                obj.lastSignalEdgeIdx = obj.numSamplesSeen;
                
            elseif((obj.signals(end-1) == 1) && (obj.signals(end) == 0))
                if(obj.lastSignalEdgeIdx ~= -1)
                    obj.signals(obj.lastSignalEdgeIdx:end) = 0;
                    newEventIndex = round((obj.lastSignalEdgeIdx+obj.numSamplesSeen)/2);
                    obj.signals(newEventIndex) = 1;
                    [obj, foundSeg] = checkForCompleteSegments(obj, newEventIndex);
                end
                obj.lastSignalEdgeIdx = -1;
                
                
            elseif((obj.signals(end-1) == 0) && (obj.signals(end) == -1))
                obj.lastSignalEdgeIdx = obj.numSamplesSeen;
                
                
            elseif((obj.signals(end-1) == -1) && (obj.signals(end) == 0))
                if(obj.lastSignalEdgeIdx ~= -1)
                    obj.signals(obj.lastSignalEdgeIdx:end) = 0;
                    newEventIndex = round((obj.lastSignalEdgeIdx+obj.numSamplesSeen)/2);
                    obj.signals(newEventIndex) = -1;
                    [obj, foundSeg] = checkForCompleteSegments(obj, newEventIndex);
                end
                obj.lastSignalEdgeIdx = -1;
                
                
            elseif((obj.signals(end-1) == -1) && (obj.signals(end) == 1))
                if(obj.lastSignalEdgeIdx ~= -1)
                    obj.signals(obj.lastSignalEdgeIdx:end) = 0;
                    
                    newEventIndex = round((obj.lastSignalEdgeIdx+obj.numSamplesSeen)/2);
                    obj.signals(newEventIndex) = -1;
                    [obj, foundSeg] = checkForCompleteSegments(obj, newEventIndex);
                end
                obj.lastSignalEdgeIdx = obj.numSamplesSeen;
                
            elseif((obj.signals(end-1) == 1) && (obj.signals(end) == -1))
                if(obj.lastSignalEdgeIdx ~= -1)
                    obj.signals(obj.lastSignalEdgeIdx:end) = 0;
                    newEventIndex = round((obj.lastSignalEdgeIdx+obj.numSamplesSeen)/2);
                    obj.signals(newEventIndex) = 1;
                    [obj, foundSeg] = checkForCompleteSegments(obj, newEventIndex);
                end
                obj.lastSignalEdgeIdx = obj.numSamplesSeen;
            
            elseif (obj.lastSignalEdgeIdx ~= -1 && (obj.numSamplesSeen - obj.lastSignalEdgeIdx) > obj.maxSamplesToTakeTemporalMean)
                obj.signals(obj.lastSignalEdgeIdx:end) = 0;
                newEventIndex = obj.lastSignalEdgeIdx + obj.offsetAfterMaxSamplesToTakeTemporalMean;
                obj.signals(newEventIndex) = 1;

                [obj, foundSeg] = checkForCompleteSegments(obj, newEventIndex);
                obj.lastSignalEdgeIdx = -1;
            end

        end
        
        function [obj, foundSeg] = checkForCompleteSegments(obj, indexOfCurrentEvent)
            foundSeg = 0;
            % Look for up-down-up pattern
            if (obj.signals(obj.second_last_event_ind) == 1 && ...
                obj.signals(obj.last_event_ind) == -1 && ...
                obj.signals(indexOfCurrentEvent) == 1)
            
                obj.segmentInds = [obj.segmentInds; obj.second_last_event_ind, indexOfCurrentEvent];
                foundSeg = 1;
            end
               obj.second_last_event_ind = obj.last_event_ind;
               obj.last_event_ind = indexOfCurrentEvent;
        
        end
        
        function [obj] = getAngles(obj, data, time)
            % Change to appropriate units and add data to local rawData struct
            obj.addDataToStruct(data);
            
            % Estimate from accelerometer
            ax = obj.smoothedData.ax(end);
            ay = obj.smoothedData.ay(end);
            az = obj.smoothedData.az(end);
            
            roll_est_acc  = atan2(ay, sqrt(ax .^ 2 + az .^ 2)); % range [-90, 90]
            pitch_est_acc = atan2(ax, sqrt(ay .^ 2 + az .^ 2)); % range [-90, 90]
            
            % Complimentary filter (gyro estimate is computed inside this
            % loop because it relies on the previous angle)
            alpha = 0.1;
            compRollEst = 0; compPitchEst = 0;            
            % Only use acceleration if we are at the first time stamp
            if(obj.firstStep)
                compRollEst = roll_est_acc;
                compPitchEst = pitch_est_acc;
            else
                dt = obj.timeSinceLastSegment(end) - time;
                roll_est_gyr = obj.rollSinceLastSegment(end) + dt(end) * obj.smoothedData.gx(end);
                pitch_est_gyr = obj.pitchSinceLastSegment(end) + dt(end) * obj.smoothedData.gy(end);
                
                compRollEst = (1 - alpha) * roll_est_gyr  + alpha * roll_est_acc;
                compPitchEst = (1 - alpha) * pitch_est_gyr  + alpha * pitch_est_acc;
            end

            obj.rollSinceLastSegment = [obj.rollSinceLastSegment, compRollEst];
            obj.pitchSinceLastSegment = [obj.pitchSinceLastSegment, compPitchEst];
            obj.timeSinceLastSegment = [obj.timeSinceLastSegment, time];
        end
        
        function [obj] = addDataToStruct(obj, data, time)
            % Convert units and add to the sliding window struct
            g = 9.81; % gravitational constant (m/s^2)
            A_sens = 16384; % for acceleration limit of 2g
            G_sens = 131; % for angular velocity limit of 250 degrees / second
            Ax = data(1) / A_sens * g; Ay = data(2) / A_sens * g; Az = data(3) / A_sens * g; % m/s^2
            Gx = data(4) / G_sens; Gy = data(5) / G_sens; Gz = data(6) / G_sens; % degrees/s
            Gx_rad = Gx * pi / 180.0; Gy_rad = Gy * pi / 180.0; Gz_rad = Gz * pi / 180.0; % rad/s
            
            if(obj.firstStep)
                
                obj.rawData = struct();
                obj.rawData.ax = Ax * ones(1, obj.smoothingWindowSize + 1);
                obj.rawData.ay = Ay * ones(1, obj.smoothingWindowSize + 1);
                obj.rawData.az = Az * ones(1, obj.smoothingWindowSize + 1);
                
                obj.rawData.gx = Gx_rad * ones(1, obj.smoothingWindowSize + 1);
                obj.rawData.gy = Gy_rad * ones(1, obj.smoothingWindowSize + 1);
                obj.rawData.gz = Gz_rad * ones(1, obj.smoothingWindowSize + 1);
                
                obj.smoothedData.ax = [];
                obj.smoothedData.ay = [];
                obj.smoothedData.az = [];
                obj.smoothedData.gx = [];
                obj.smoothedData.gy = [];
                obj.smoothedData.gz = [];
                
            else
                obj.rawData.ax = [obj.rawData.ax(2:end), Ax];
                obj.rawData.ay = [obj.rawData.ay(2:end), Ay];
                obj.rawData.az = [obj.rawData.az(2:end), Az];
                
                obj.rawData.gx = [obj.rawData.gx(2:end), Gx_rad];
                obj.rawData.gy = [obj.rawData.gy(2:end), Gy_rad];
                obj.rawData.gz = [obj.rawData.gz(2:end), Gz_rad];
            end
            
            obj.smoothedData.ax = [obj.smoothedData.ax, mean(obj.rawData.ax(2:end))];
            obj.smoothedData.ay = [obj.smoothedData.ay, mean(obj.rawData.ay(2:end))];
            obj.smoothedData.az = [obj.smoothedData.az, mean(obj.rawData.az(2:end))];
            obj.smoothedData.gx = [obj.smoothedData.gx, mean(obj.rawData.gx(2:end))];
            obj.smoothedData.gy = [obj.smoothedData.gy, mean(obj.rawData.gy(2:end))];
            obj.smoothedData.gz = [obj.smoothedData.gz, mean(obj.rawData.gz(2:end))];
        end
        
    end
    
end
