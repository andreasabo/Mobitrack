function [] = runClassificationTests( svmOptions, trainingData, testingData, supplementaryInfo, window_size, dataForVisualization, dataForVisualization_formatted, dimReduct)
% Run the suite of classification tests according to the SVM parameters
% defined by the calling function.
%
% Parameters:
%   svmOptions: a struct containing the collection of parameters that
%               should be tested. See classificationWorkflow.m for an
%               example of how to define these.
%   trainingData: an n by m matrix of training data where the first column 
%                 contains the class label and the rest contain the
%                 features.
%   testingData: an p by m matrix of training data where the first column
%                 contains the class label and the rest contain the
%                 features. Note: the testingData should have the same
%                 number of features as the trainingData.
%   supplementaryInfo: a struct containing some supplementary information
%                       such as where to save the data
%

% Extract the class labels and features
trainingClassLabels = trainingData(:,1);
trainingFeatures = trainingData(:, 2:end);

testingClassLabels = testingData(:,1);
testingFeatures = testingData(:, 2:end);

% =========================== Classifier 1 ================================
% Loop through all possible combinations of svmOptions and feature sets
testingFeatures = testingFeatures;
trainingFeatures = trainingFeatures;

% Standardization
for standardID = 1:length(svmOptions.standardize)
    standardize = svmOptions.standardize{standardID};

    % Kernel type
    for kernelID = 1:length(svmOptions.kernel)
        kernel = svmOptions.kernel{kernelID};

        % Kernel scale
        for kernelScaleID = 1:length(svmOptions.kernelScale)
            kernelScale = svmOptions.kernelScale{kernelScaleID};

            % Solver type
            for solverID = 1:length(svmOptions.solver)
                solver = svmOptions.solver{solverID};

                % Box Constraint - https://www.mathworks.com/help/stats/fitcsvm.html#bt8v_z4-1
                for boxConstraintID = 1:length(svmOptions.boxConstraint)
                    boxConstraint = svmOptions.boxConstraint{boxConstraintID};

                    for polynomialOrderID = 1:length(svmOptions.polynomialOrder)
                        polynomialOrder = svmOptions.polynomialOrder{polynomialOrderID};

                        currentSVMOptions.standardize = standardize;
                        currentSVMOptions.kernel = kernel;
                        currentSVMOptions.kernelScale = kernelScale;
                        currentSVMOptions.solver = solver;
                        currentSVMOptions.boxConstraint = boxConstraint;
                        currentSVMOptions.polynomialOrder = polynomialOrder;
                        currentSVMOptions.window_size = window_size;

                        % Avoid running the non-polynomial kernels with
                        % different polynomial orders
                        if(~strcmp(kernel, 'polynomial') && polynomialOrderID > 1)
                            continue;
                        end

                        % Train the SVM classifier
                        tic;
                        mdl = trainClassifier(currentSVMOptions, trainingFeatures, trainingClassLabels);
                        trainingTime = toc;

                        % Predict class label and calculate performance
                        % metrics
                        tic;
                        trainPredict = predict(mdl, trainingFeatures);
                        trainPredictTime = toc;

                        tic;
                        testPredict = predict(mdl, testingFeatures);
                        testPredictTime = toc;

                        trainCP = classperf(trainingClassLabels, trainPredict, 'Positive', [1], 'Negative', [0]);
                        testCP = classperf(testingClassLabels, testPredict, 'Positive', [1], 'Negative', [0]);

                        timeStruct.trainPredictTime = trainPredictTime;
                        timeStruct.testPredictTime = testPredictTime;
                        timeStruct.trainingTime = trainingTime;

                       
                        

                        % Save the classifier performance results to a CSV
                        commonName = saveClassifierPerformanceToCSV(currentSVMOptions, trainCP, testCP, supplementaryInfo.outputCSV, supplementaryInfo.filepaths.full, timeStruct, mdl, dimReduct); 

                        % Test on the visual data 
                        testAndPlotVisualResults(supplementaryInfo.filepaths.full, commonName, mdl, dataForVisualization, dataForVisualization_formatted, window_size )
                        
                    end % end polynomialOrder                
                end % end boxConstraint
            end % end solver    
        end % end kernelScale
    end % end kernel      
end % end standardization

