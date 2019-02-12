classdef PostProcessor < handle
    
    properties
        labels = [];
        all_labels = [];         % Stream of all classifier labels (as seen by this class)
        segments = [];          % Segments as seen from this class
        abscount;               % absolute count of samples processed
        all_pitch = [];
        
        max_length_of_turning_point = 2.5;
        max_samples_in_section;
        
        current_section = 0;
        start = 0;
        
        window_size;
        sampling_rate;
        pointsInNewSection = 0;
        pointsInCurrentSection = 0;
        curLabelLength = 0;
        inTransition = 0;
        
        minp1Threshold = 25;
        minp0Threshold = 25;
        
        inLongErrorneousSection = 0;
        numPointsToKeepAtErrorneousSection = 100;
        
        doneSection = 0;
        segmentData = struct();
        corr_for_merge_segments = 0.80; % If the magnitude of two adjacent segments is greater than this, they will be merged
        
    end
    
    methods
        function [obj] = PostProcessor(window_size, sampling_rate) % initialize the PostProcess object
            obj.window_size = window_size;
            obj.sampling_rate = sampling_rate;
            obj.start = 0;
            obj.abscount = window_size;
            
            obj.max_samples_in_section = obj.max_length_of_turning_point * obj.sampling_rate;
            
            
            obj.segmentData.haveFirstSection = 0;
            obj.segmentData.firstSectionMiddle = 0;
            obj.segmentData.haveSecondSection = 0;
        end
        
        
        function [obj] = step(obj, new_label, new_pitch)
            obj.all_pitch = [obj.all_pitch, new_pitch];
            % initialize current section/segment
            if(obj.start == 0) % want to start at a p1 point
                if(new_label ~= 1)
                    obj.abscount = obj.abscount+1;
                    obj.all_labels = [obj.all_labels new_label];
                    return;
                else %new_label == 1
                    obj.start = 1;
                    obj.current_section = 1;
                    obj.labels = [obj.labels, new_label];
                    obj.all_labels = [obj.all_labels new_label];
                end
                return;
            end
            obj.labels = [obj.labels, new_label];
            obj.all_labels = [obj.all_labels new_label];
            
            % in long errorneous section being ignored
            if(obj.inLongErrorneousSection && new_label == obj.current_section)
                obj.labels(end) = ~new_label;
                obj.all_labels(end) = ~new_label; 
                return;
            end
            
            % in processing section
            if(obj.current_section ~= new_label) %label has changed -> now determine whether this is an errorneous label or the actual start of the next section
                obj.inTransition = 1;
                obj.pointsInNewSection = obj.pointsInNewSection+1;
                
                % Check if there are enough points in the new section
                % to declare a new section.
                if(obj.current_section == 0 && (obj.pointsInNewSection >= obj.minp1Threshold)) % Moving from p0 to p1 sections
                    obj.current_section = 1;
                    obj.curLabelLength = obj.pointsInNewSection;
                    obj.pointsInNewSection = 0;
                    
                elseif(obj.current_section == 1 && (obj.pointsInNewSection >= obj.minp0Threshold)) %Moving from p1 to p0 sections
                    obj.current_section = 0;
                    obj.curLabelLength = obj.pointsInNewSection;
                    obj.pointsInNewSection = 0;
                    obj.doneSection = 1;
                    
                end
                
                if (obj.inLongErrorneousSection) % end of errorneous section
                    try
                       obj.labels(end - obj.curLabelLength - obj.numPointsToKeepAtErrorneousSection:end - obj.curLabelLength) = ~obj.current_section;
                    catch
                    end
                    obj.inLongErrorneousSection = 0;
                end
                
                
                
            elseif(obj.labels(end-1) ~= new_label) % End of erroneous section, reset transition section counters
                obj.curLabelLength = obj.curLabelLength + obj.pointsInNewSection + 1;
                
                obj.pointsInNewSection = 0;
                obj.inTransition = 0;
                
                % Clean up the labels
                % Find last index of current index before transition
                % section and set all points after to that label
                inds = find(obj.labels == obj.current_section,2,'last');
                inds2 = find(obj.all_labels == obj.current_section,2,'last'); % For all labels array
                
                lastBeforeTransition = min(inds);
                lastBeforeTransition2 = min(inds2);
                
                obj.labels(lastBeforeTransition:end) = obj.current_section;
                obj.all_labels(lastBeforeTransition2:end) = obj.current_section;
                
                
            else % Label is the same as the previous one
                obj.curLabelLength = obj.curLabelLength+1;
                obj.pointsInNewSection = 0; 
            end
            
            
            
            % Check if the segment length is getting too long and if we
            % need to terminate prematurely
            if (obj.curLabelLength > obj.max_samples_in_section)
                num_samples_to_revert = obj.max_samples_in_section - obj.numPointsToKeepAtErrorneousSection;
                if(new_label == 1)
                    obj.labels(end-num_samples_to_revert:end) = 0;
                    obj.all_labels(end-num_samples_to_revert:end) = 0;
                else
                    obj.labels(end-num_samples_to_revert:end) = 1;
                    obj.all_labels(end-num_samples_to_revert:end) = 1;
                end

                if (~obj.inLongErrorneousSection && new_label)
                    obj.doneSection = 1;
                end
                obj.inLongErrorneousSection = 1;
            end
            
            
            
            if(obj.doneSection)
                obj.checkIfEndOfSegment();
                obj.doneSection = 0;
            end
            
        end
        
        function [obj, labels] = getLabels(obj)
            labels = obj.all_labels;
        end
        
        
        function [obj] = fixSegments(obj)
            % use the pitch signal to combine segments if necessary
            
            % Step 1: remove all segments that have no length
            i = 1;
            while i <= size(obj.segments,1)
                if (obj.segments(i, 1) == obj.segments(i, 2))
                    obj.segments(i, :) = [];
                    continue;
                end
                i = i + 1;
            end
            
            % Step 2: Split up any segments with overlap
            i = 2;
            while i <= size(obj.segments,1)
                if (obj.segments(i, 2) == obj.segments(i-1, 2))
                    obj.segments(i-1, 2) = obj.segments(i, 1);
                end
                i = i + 1;
            end
            
            % Step 3: Combine segments

            last_small_seg_ind = -1;
            i = 1;
            while i <= size(obj.segments,1)
                seg_size = obj.segments(i, 2) - obj.segments(i, 1) + 1;
                x_labels = 1:seg_size;
                y_labels = obj.all_pitch(obj.segments(i, 1): obj.segments(i, 2));
               
                rho = corrcoef(x_labels, y_labels);
                
                if(abs(rho(1,2)) > obj.corr_for_merge_segments)
                    if (last_small_seg_ind == (i -1)) % if the last segment was also a half
                        % combine segments
                        obj.segments(last_small_seg_ind, 2) = obj.segments(i, 2);
                        obj.segments(i, :) = [];
                        continue;
                    end
                    
                    last_small_seg_ind = i;
                end
                i = i + 1;
            end
            
            
            
        end
        
        
        function [obj] = checkIfEndOfSegment(obj)
            
            if(~obj.segmentData.haveFirstSection)
                stop1 = find(obj.labels ~= obj.current_section,1,'last');
                stop2 = find(obj.all_labels ~= obj.current_section,1,'last'); % For all labels array
                start1 = find(obj.all_labels(1:stop1) == obj.current_section,1,'last'); 
                start2 = find(obj.all_labels(1:stop2) == obj.current_section,1,'last'); % For all labels array
                
                obj.segmentData.firstSectionMiddle = round(start2 + (stop2 - start2) / 2); 
                obj.segmentData.haveFirstSection = 1;
                return;
            end
            
            if(~obj.segmentData.haveSecondSection)
                obj.segmentData.haveSecondSection = 1;
                return;
            end
            
            % Now seeing the third section
            stop1 = find(obj.labels ~= obj.current_section,1,'last');
            stop2 = find(obj.all_labels ~= obj.current_section,1,'last'); % For all labels array
            start1 = find(obj.all_labels(1:stop1) == obj.current_section,1,'last'); 
            start2 = find(obj.all_labels(1:stop2) == obj.current_section,1,'last'); % For all labels array
            
            newMiddle =  round(start2 + (stop2 - start2) / 2);
            obj.segments = [obj.segments; obj.segmentData.firstSectionMiddle, newMiddle];
                
            obj.segmentData.firstSectionMiddle = newMiddle;
            obj.segmentData.haveSecondSection = 0;
           
          
        end
        
    end
    
end