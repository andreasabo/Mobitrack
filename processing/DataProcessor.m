classdef DataProcessor < handle
    
    properties
        allPitch = []; %This stores all the values seen by the class (this cannot be used in final implementation due to memory concerns
        allRoll = [];
        allTime = [];
        
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
        maxSamplesToTakeTemporalMean = 100;
        offsetAfterMaxSamplesToTakeTemporalMean = 10;
        segmentInds = [];
        
        last_event_ind = 1;
        second_last_event_ind = 1;
        
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
            % Estimate pitch and roll using the complimentary filter
            obj.getAngles(data, time);
            
            % Segment
            [obj, foundSeg] = segment(obj, obj.pitchSinceLastSegment(end));
            
            % If end of segment, classify
            if(foundSeg)
                fprintf('Found Seg\n');
            end
            
            obj.firstStep = 0;
            obj.numSamplesSeen = obj.numSamplesSeen + 1;
            

        end
    end
    
    
    methods (Access = private) 
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
                roll_est_gyr = obj.rollSinceLastSegment(end) + dt * obj.smoothedData.gx(end);
                pitch_est_gyr = obj.pitchSinceLastSegment(end) + dt * obj.smoothedData.gy(end);
                
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
