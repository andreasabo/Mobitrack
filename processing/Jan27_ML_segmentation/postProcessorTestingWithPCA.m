close all, clear all, clc

%% Load the model to use
path_to_model = 'D:\OneDrive\School\4A\BME 461\Mobitrack\data\Feb6ClassifierResults\test\';
path_to_data = 'D:\OneDrive\School\4A\BME 461\Mobitrack\data\MetaMotion\Jan25_SOP';
model_names = {'40.000000, rbf_2_1_1_SMO_100', '40.000000, polynomial_3_1_1_SMO_1'};
model_names = {'30.000000, rbf_2_1_1_SMO_100', '30.000000, polynomial_4_1_1_SMO_100', '25.000000, rbf_2_1_1_SMO_100', '25.000000, rbf_2_1_1_SMO_10', '25.000000, polynomial_3_auto_1_SMO_100', '25.000000, polynomial_3_1_1_SMO_500'};

cd(path_to_data)
for i = 1:length(model_names)
    model_name = model_names{i};
    c = strsplit(model_name, ',');
    window_size = str2num(c{1});
    
    path_to_model_and_pca = strcat(path_to_model, model_name, '.mat');
    load(path_to_model_and_pca)
    
    %% Load all files
    files = dir('data*.txt');
    for file_ind = 1:length(files)
        file_ind
        % Load and format raw data
        data_file = files(file_ind).name;
        testing_data = loadDataFromTxtFile(data_file);
        [t, roll, pitch] = preprocessData(testing_data);
        t = t / 1000;
        [pitch_for_classifier] = formatDataForClassifier(pitch, window_size);
        pitch_for_classifier = dimReduct.apply(pitch_for_classifier)
        
        %% Label
        labels = predict(mdl, pitch_for_classifier);
        padding = zeros(window_size,1);
        labels = [0; padding; labels; padding];
        %% Post-Process in real-time
        pp = PostProcessor(window_size, 100);
        
        for i = 1:length(labels)
            label = labels(i);
            pp.step(label, pitch_for_classifier(i));
            i
            
        end
        
        pp.fixSegments();
        all_labels = pp.all_labels;
        segments = pp.segments;
        figure, plot(t, all_labels), hold on, plot(t, pitch, 'LineWidth', 1.5)
        

        
        %% Plot and save
        for i = 1:size(segments,1)
            
            rectangle('Position', [t(segments(i,1)),...
                min(pitch), ...
                t(segments(i,2)) - t(segments(i,1)), ...
                max(pitch) - min(pitch)], 'EdgeColor', 'green');
        end
        
        set(gcf,'Position',[1 1 2000 1500])
        
        
        save_folder = strcat(path_to_model, model_name);
        mkdir(save_folder)
        saveLocation = strcat(save_folder, filesep, data_file, '_out_.png');
        print(saveLocation,'-dpng','-r600')
        close(gcf);
        
    end
    
    
    
    
end






