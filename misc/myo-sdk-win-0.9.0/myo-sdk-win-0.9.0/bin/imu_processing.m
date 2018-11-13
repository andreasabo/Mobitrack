%%
close all, clear all, clc
cd ('C:\Users\Jason\Desktop\Waterloo Classwork\Year 4\4A Fall\BME 461 Biomedical Engineering Design Workshop 2\FYDP\Mobitrack\misc\myo-sdk-win-0.9.0\myo-sdk-win-0.9.0\bin')

%% Load data
timestamp = 1541872381;
acceleration = csvread(strcat('accelerometer-',int2str(timestamp),'.csv'), 1, 0);
gyroscope = csvread(strcat('gyro-',int2str(timestamp),'.csv'), 1, 0);
orientation = csvread(strcat('orientation-',int2str(timestamp),'.csv'), 1, 0);
orientationEuler = csvread(strcat('orientationEuler-',int2str(timestamp),'.csv'), 1, 0);

%% Plot raw data
figure, plot(acceleration(:,1) - acceleration(1,1), acceleration(:,2:4)), title('Acceleration'), legend('x','y','z');
figure, plot(gyroscope(:,1) - gyroscope(1,1), gyroscope(:,2:4)), title('Gyroscope'), legend('x','y','z');
figure, plot(orientation(:,1) - orientation(1,1), orientation(:,2:4)), title('Orientation'), legend('x','y','z');
figure, plot(orientationEuler(:,1) - orientationEuler(1,1), orientationEuler(:,2:4)), title('Orientation (Euler)'), legend('x','y','z');

%%