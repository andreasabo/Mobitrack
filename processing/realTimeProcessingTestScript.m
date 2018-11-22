close all, clear all, clc
% Load data
%cd ('C:\Users\andre\OneDrive\School\4A\BME 461\Mobitrack\data\Nov17');
filename = 'D:\OneDrive\School\4A\BME 461\Mobitrack\data\Nov17\LA_flx_small.mat';
data = load(filename);

% Load Classifier
classifier = load('classifier_simple.mat');
SVMModel = classifier.SVMModel;

dataMatrix = [data.ax; data.ay; data.az; data.gx; data.gy; data.gz];
time = data.time;

windowSize = 10;
lag = 1000; % samples
threshold = 0.8; % standard deviations
influence = 1;

processor = DataProcessor(SVMModel, windowSize, lag, threshold, influence);

for i = 1:length(time)
    processor.processStep(dataMatrix(:,i), time(i));
    
    if(processor.repDetected)
        fprintf('Andrea');
    end
    
end


%%
figure, hold on
plot(processor.pitchSinceLastSegment * 180.0 / pi), title('Real-time processing pitch')
stairs(processor.signals * 5,'r','LineWidth',1.5);
    for i = 1:size(processor.segmentInds,1)
        rectangle('Position', [processor.segmentInds(i,1), min(processor.pitchSinceLastSegment), processor.segmentInds(i,2) - processor.segmentInds(i,1), max(processor.pitchSinceLastSegment) - min(processor.pitchSinceLastSegment)], 'EdgeColor', 'r');
    end
%segments = extractSegments(data.time, processor.rollSinceLastSegment, processor.pitchSinceLastSegment, processor.segmentInds);


