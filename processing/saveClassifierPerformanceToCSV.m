function [common_name] = saveClassifierPerformanceToCSV(currentSVMOptions, trainCP, testCP, filename, fullFilePath, timeStruct, mdl, dimReduct)
% This function accepts the current SVM parameters and the classifier
% performance for the training and testing sets and then saves the
% performance statistics to a CSV.
%
% Parameters: 
%   currentSVMOptions: a struct containing the parameters for the
%                      classifier that produced the observed results.
%   trainCP: a classifier performance object that has been created using
%            the training data. 
%   testCP: a classifier performance object that has been created using the
%           testing data. 
%   filename: the full file path of the location where the CSV is located.
%   timeStruct: a struct containing the training time, classification of
%               the testing set time, and classification of training set
%               time.
%

% ======= For these statistics, the rep class is taken as the 'positive' class =======

fileExist = exist(filename);
if(~fileExist)
    header = ['Time, Window Size, Id,', ...
    'Training Time (s), Testing Set Classification Time (s), Training Set Classification Time (s),',...
    'Testing - CorrectRate, Testing - Sensitivity, Testing - Specificity, Testing - SampleSize, '...
    'Training - CorrectRate, Training - Sensitivity, Training - Specificity, Training - SampleSize, '...
    'Kernel, PolynomialOrder, KernelScale, Standardize, Solver, BoxConstraint'...
    '\n'];
    f = fopen(filename, 'w');
    fprintf(f, header);
    fclose(f);

end

classifierOptions = sprintf('%s_%d_%s_%s_%s_%s', currentSVMOptions.kernel, currentSVMOptions.polynomialOrder, num2str(currentSVMOptions.kernelScale), num2str(currentSVMOptions.standardize),currentSVMOptions.solver, num2str(currentSVMOptions.boxConstraint));

timeArray = fix(clock);
time = '';
for i = 1:length(timeArray) % concatentate and format timestamp
    time = strcat(time, num2str(timeArray(i)),'_');
end
time = time(1:end-1);


basicInfo = sprintf('%s, %f, %s', time, currentSVMOptions.window_size, classifierOptions);

timeInfo = sprintf('%0.4f, %0.4f, %0.4f', timeStruct.trainingTime, timeStruct.testPredictTime, timeStruct.trainPredictTime);

testingPerformanceInfo = sprintf('%0.4f, %0.4f, %0.4f, %d',  testCP.CorrectRate, testCP.Sensitivity, testCP.Specificity, testCP.NumberOfObservations);

trainingPerformanceInfo = sprintf('%0.4f, %0.4f, %0.4f, %d',  trainCP.CorrectRate, trainCP.Sensitivity, trainCP.Specificity, trainCP.NumberOfObservations);

classifierDetails = sprintf('%s, %d, %s, %s, %s, %d',currentSVMOptions.kernel, currentSVMOptions.polynomialOrder, num2str(currentSVMOptions.kernelScale), num2str(currentSVMOptions.standardize),currentSVMOptions.solver, currentSVMOptions.boxConstraint);


% Concatenate and save data
allData = strcat(basicInfo, ', ', timeInfo, ', ', testingPerformanceInfo, ', ', trainingPerformanceInfo , ', ', classifierDetails, '\n');
f = fopen(filename, 'a'); % append to file
fprintf(f, allData);
fclose(f);

% Save model and dim reduction
common_name = sprintf('%f, %s', currentSVMOptions.window_size, classifierOptions);
saveName = strcat(fullFilePath, filesep, common_name, '.mat');
save(saveName, 'mdl', 'dimReduct');

end

