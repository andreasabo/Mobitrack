function [outputArg1,outputArg2] = testAllClassifierCombos(allData, allLabels, window_size, dataForVisualization, dataForVisualizationFormated, dimReduct)
    % Divide data into testing and training
    s = RandStream('mlfg6331_64');
    testing_fraction = 0.2;
    num_samples = length(allLabels);
    testing_ind = false(1,num_samples); % create logical index vector
    testing_ind(1:round(testing_fraction*num_samples)) = true;   
    testing_ind = testing_ind(randperm(num_samples));   % randomise order
    
    testingData = allData(testing_ind, :);
    testingLabels = allLabels(testing_ind, :);
    testingData = [testingLabels, testingData];
    
    trainingData = allData(~testing_ind, :);
    trainingLabels = allLabels(~testing_ind, :);
    trainingData = [trainingLabels, trainingData];


    %% Set up testing parameters - key-value pairs from https://www.mathworks.com/help/stats/fitcsvm.html
    svmOptions.standardize = {true};
    svmOptions.kernel = {'rbf', 'linear', 'polynomial'};
    svmOptions.polynomialOrder = {2, 3, 4};

    svmOptions.solver = {'SMO'};
    svmOptions.kernelScale = {1, 'auto'}; % TODO: test different kernel scales 
    svmOptions.boxConstraint = {1, 10, 100, 500}; % 1 is Matlab default
    

    % Set the location where the results should be saved
    filepaths.root = 'D:\OneDrive\School\4A\BME 461\Mobitrack\data\';
    subFolder1 = 'Feb6ClassifierResults\';
    subFolder2 = 'test';

    %% Load in the supplementary information

    filepaths.testRoot = strcat(filepaths.root, subFolder1);
    filepaths.full = strcat(filepaths.testRoot, subFolder2);

    supplementaryInfo.filepaths = filepaths;
    supplementaryInfo.outputCSV = strcat(filepaths.full, filesep, 'classifier_metric.txt'); % Where the metrics will be exported

    % Create the directory where the results will be saved
    if(exist(filepaths.full, 'dir') ~= 7)
        mkdir(filepaths.full);
    end    
    
    
    tic
    runClassificationTests(svmOptions, trainingData, testingData, supplementaryInfo, window_size, dataForVisualization, dataForVisualizationFormated, dimReduct);
    toc
    
end


