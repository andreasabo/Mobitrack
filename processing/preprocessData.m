function [t, roll_est_comp, pitch_est_comp] = preprocessData(data, createPlots)

if nargin < 2
    createPlots = 0;
end

t = (data.time - data.time(1))/1000;
Ax = data.ax; Ay = data.ay; Az = data.az;
Gx = data.gx; Gy = data.gy; Gz = data.gz;
dt = diff(t);

% Pre-processing: remove high frequency component
% fc = exp(-1); % normalized frequency
% fs = 1/mean(dt); % sampling frequency [Hz]

% Butterworth filter
% [b,a] = butter(1, 0.1);

% Moving average filter
% filter_size = 50;
% a = 1;
% b = ones(1,filter_size);
% b = b/filter_size;
% 
% Ax = filter(b,a,Ax); Ay = filter(b,a,Ay); Az = filter(b,a,Az);
% Gx = filter(b,a,Gx); Gy = filter(b,a,Gy); Gz = filter(b,a,Gz);
window_size = 50;
Ax_out = [];
Ay_out = [];
Az_out = [];
Gx_out = [];
Gy_out = [];
Gz_out = [];
for i = 1:length(Ax)
    if(i <= window_size)
        Ax_out = [Ax_out; mean(Ax(1:i))];
        Ay_out = [Ay_out; mean(Ay(1:i))];
        Az_out = [Az_out; mean(Az(1:i))];
        Gx_out = [Gx_out; mean(Gx(1:i))];
        Gy_out = [Gy_out; mean(Gy(1:i))];
        Gz_out = [Gz_out; mean(Gz(1:i))];
    else
        Ax_out = [Ax_out; mean(Ax(i-window_size:i))];
        Ay_out = [Ay_out; mean(Ay(i-window_size:i))];
        Az_out = [Az_out; mean(Az(i-window_size:i))];
        Gx_out = [Gx_out; mean(Gx(i-window_size:i))];
        Gy_out = [Gy_out; mean(Gy(i-window_size:i))];
        Gz_out = [Gz_out; mean(Gz(i-window_size:i))];
    end
end

Ax = Ax_out;
Ay = Ay_out;
Az = Az_out;
Gx = Gx_out;
Gy = Gy_out;
Gz = Gz_out;



%% Convert data to proper units
g = 9.81; % gravitational constant (m/s^2)
A_sens = 16384; % for acceleration limit of 2g
G_sens = 131; % for angular velocity limit of 250 degrees / second
A_sens = 1; % for acceleration limit of 2g
G_sens = 1; % for angular velocity limit of 250 degrees / second
Ax = Ax / A_sens * g; Ay = Ay / A_sens * g; Az = Az / A_sens * g; % m/s^2
Gx = Gx / G_sens; Gy = Gy / G_sens; Gz = Gz / G_sens; % degrees/s
% Gx_rad = Gx * pi / 180.0; Gy_rad = Gy * pi / 180.0; Gz_rad = Gz * pi / 180.0; % rad/s

Gx_rad = Gx; Gy_rad = Gy; Gz_rad = Gz; % deg/s


%% Estimation based on accelerometer or gyroscope only
% roll = X; pitch = Y
epsilon = 0.1; % magnitude threshold from actual g

% Accelerometer only
roll_est_acc  = atan2(Ay, sqrt(Ax .^ 2 + Az .^ 2)); % range [-pi, pi]
pitch_est_acc = atan2(Ax, sqrt(Ay .^ 2 + Az .^ 2)); % range [-pi, pi]

roll_est_acc = rad2deg(roll_est_acc);
pitch_est_acc = rad2deg(pitch_est_acc);

% Gyroscope only
roll_est_gyr = zeros(1, length(t));
pitch_est_gyr = zeros(1, length(t));
yaw_est_gyr = zeros(1, length(t));
for i = 2:length(t)
   if (abs(sqrt(Ax(i).^2 + Ay(i).^2 + Az(i).^2)- 9.81) < epsilon)
       yaw_est_gyr(i) = yaw_est_gyr(i-1);
       roll_est_gyr(i) = roll_est_gyr(i-1);
       pitch_est_gyr(i) = pitch_est_gyr(i-1);
       
   else
       roll_est_gyr(i) = roll_est_gyr(i-1) + dt(i-1) * Gx_rad(i);
       pitch_est_gyr(i) = pitch_est_gyr(i-1) + dt(i-1) * Gy_rad(i);
       yaw_est_gyr(i) = yaw_est_gyr(i-1) + dt(i-1) * Gz_rad(i);
   end
end

%% 3) Complimentary Filter
alpha = 0.1; % parameter to tune (higher alpha = more acceleration, lower alpha = more gyro)

roll_est_comp = zeros(1, length(t));
pitch_est_comp = zeros(1, length(t));
roll_est_gyr_comp = zeros(1, length(t));
pitch_est_gyr_comp = zeros(1, length(t));

for i=2:length(t)
   roll_est_gyr_comp(i)  = roll_est_comp(i-1) + dt(i-1) * Gx_rad(i);
   pitch_est_gyr_comp(i) = pitch_est_comp(i-1) + dt(i-1) * Gy_rad(i);
       
   roll_est_comp(i)  = (1 - alpha) * roll_est_gyr_comp(i)  + alpha * roll_est_acc(i);
   pitch_est_comp(i) = (1 - alpha) * pitch_est_gyr_comp(i) + alpha * pitch_est_acc(i);    
end

%% Convert all estimates to degrees and save
% roll_est_acc = roll_est_acc * 180.0 / pi; pitch_est_acc = pitch_est_acc * 180.0 / pi;
% roll_est_gyr = roll_est_gyr * 180.0 / pi; pitch_est_gyr = pitch_est_gyr * 180.0 / pi;
% yaw_est_gyr = yaw_est_gyr * 180.0 / pi;
% roll_est_comp = roll_est_comp * 180.0 / pi; pitch_est_comp = pitch_est_comp * 180.0 / pi;
%save (strcat(filename, '_comp.mat'), 't', 'roll_est_comp', 'pitch_est_comp')

if (createPlots)
    
    % Plot raw data
    % Acceleration
    figure, plot(t, [Ax, Ay, Az])
    title('Acceleration','fontweight','bold')
    legend('x','y','z')
    xlabel('Time (s)');
    ylabel('Acceleration (m/s^2)');

    % Angular Velocity
    figure, plot(t, [Gx, Gy, Gz])
    title('Angular Velocity','fontweight','bold')
    legend('x','y','z')
    xlabel('Time (s)');
    ylabel('Angular Velocity (degrees/s)');
    
    figure,
    subplot(3, 1, 1);
    plot(t, roll_est_comp, t, roll_est_acc, t, roll_est_gyr)
    legend('Complimentary', 'Accelerometer', 'Gyro')
    xlabel('Time (s)')
    ylabel('Angle (Degrees)')
    title('Roll')

    subplot(3, 1, 2);
    plot(t, pitch_est_comp, t, pitch_est_acc, t, pitch_est_gyr )
    legend('Complimentary', 'Accelerometer', 'Gyro')
    xlabel('Time (s)')
    ylabel('Angle (Degrees)')
    title('Pitch')

    subplot(3, 1, 3);
    plot(t, yaw_est_gyr)
    legend('Gyro')
    xlabel('Time (s)')
    ylabel('Angle (Degrees)')
    title('Yaw')
end
end

