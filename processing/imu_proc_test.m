%%
close all, clear all, clc
cd ('C:\Users\Jason\Desktop')

%% Load data
% filename = '1.mat';
% filename = '2.mat';
% filename = '3.mat';
filename = '4.mat';
data = load(filename);
t = data.time - data.time(1);
dt = diff(t);
Ax = data.ax;
Ay = data.ay;
Az = data.az;
Gx = data.gx;
Gy = data.gy;
Gz = data.gz;

%% Plot FFT
% X = data.ax;
% L = length(X);
% Fs = 1/dt;
% Y = fft(X);
% P2 = abs(Y/L);
% P1 = P2(1:L/2+1);
% P1(2:end-1) = 2*P1(2:end-1);
% f = Fs*(0:(L/2))/L;
% 
% figure,
% plot(f,P1) 
% title('Single-Sided Amplitude Spectrum of X(t)')
% xlabel('f (Hz)')
% ylabel('|P1(f)|')

%% Pre-processing: remove high frequency component
fc = 1; % cutoff frequency [Hz]
fs = 1/mean(dt); % sampling frequency [Hz]

% Butterworth filter
[b,a] = butter(1, fc/(fs/2));
Ax = filter(b,a,Ax);
Ay = filter(b,a,Ay);
Az = filter(b,a,Az);
Gx = filter(b,a,Gx);
Gy = filter(b,a,Gy);
Gz = filter(b,a,Gz);

%% Convert data to proper units
g = 9.81; % gravitational constant (m/s^2)
A_sens = 16384; % for acceleration limit of 2g
G_sens = 131; % for angular velocity limit of 250 degrees / second
Ax = Ax / A_sens * g; % m/s^2
Ay = Ay / A_sens * g; % m/s^2
Az = Az / A_sens * g; % m/s^2
Gx = Gx / G_sens; % degrees/s
Gy = Gy / G_sens; % degrees/s
Gz = Gz / G_sens; % degrees/s
Gx_rad = Gx * pi / 180.0; % rad/s
Gy_rad = Gy * pi / 180.0; % rad/s
Gz_rad = Gz * pi / 180.0; % rad/s

%% Plot raw data
figure, plot(t, [Ax; Ay; Az])
title('Acceleration')
legend('x','y','z')
xlabel('Time (s)');
ylabel('Acceleration (m/s^2)');

figure, plot(t, [Gx; Gy; Gz])
title('Angular Velocity')
legend('x','y','z')
xlabel('Time (s)');
ylabel('Angular Velocity (degrees/s)');

%% Estimation based on accelerometer or gyroscope only
% 1) Accelerometer only
phi_hat_acc   = atan2(Ay, sqrt(Ax .^ 2 + Az .^ 2)); %roll
theta_hat_acc = atan2(-Ax, sqrt(Ay .^ 2 + Az .^ 2)); %pitch

% 2) Gyroscope only
phi_hat_gyr   = zeros(1, length(t));
theta_hat_gyr = zeros(1, length(t));

for i = 2:length(t)
   p = Gx_rad(i);
   q = Gy_rad(i);
   r = Gz_rad(i);
   
   phi_hat   = phi_hat_gyr(i - 1);
   theta_hat = theta_hat_gyr(i - 1);
    
   phi_hat_gyr(i)   = phi_hat   + dt(i-1) * (p + sin(phi_hat) * tan(theta_hat) * q + cos(phi_hat) * tan(theta_hat) * r);
   theta_hat_gyr(i) = theta_hat + dt(i-1) * (cos(phi_hat) * q - sin(phi_hat) * r);
end

%% 3) Complimentary Filter
alpha = 0.1; % parameter to tune (higher alpha = more acceleration, lower alpha = more gyro)

phi_hat_complimentary   = zeros(1, length(t));
theta_hat_complimentary = zeros(1, length(t));

for i=2:length(t)
    p = Gx_rad(i);
    q = Gy_rad(i);
    r = Gz_rad(i);
   
    phi_hat   = phi_hat_complimentary(i - 1);
    theta_hat = theta_hat_complimentary(i - 1);
    
    phi_hat_gyr_comp   = phi_hat   + dt(i-1) * (p + sin(phi_hat) * tan(theta_hat) * q + cos(phi_hat) * tan(theta_hat) * r);
    theta_hat_gyr_comp = theta_hat + dt(i-1) * (cos(phi_hat) * q - sin(phi_hat) * r);
       
    phi_hat_complimentary(i)   = (1 - alpha) * phi_hat_gyr_comp   + alpha * phi_hat_acc(i);
    theta_hat_complimentary(i) = (1 - alpha) * theta_hat_gyr_comp + alpha * theta_hat_acc(i);    
end

%% 4) Kalman Filter
% A = [1 -dt 0 0; 0 1 0 0; 0 0 1 -dt; 0 0 0 1];
% B = [dt 0 0 0; 0 0 dt 0]';
C = [1 0 0 0; 0 0 1 0];
P = eye(4);
Q = eye(4) * 0.01;
R = eye(2) * 10;
state_estimate = [0 0 0 0]';

phi_hat_kalman    = zeros(1, length(t));
bias_phi_kalman   = zeros(1, length(t));
theta_hat_kalman  = zeros(1, length(t));
bias_theta_kalman = zeros(1, length(t));

for i=2:length(t)
    
    A = [1 -dt(i-1) 0 0; 0 1 0 0; 0 0 1 -dt(i-1); 0 0 0 1];
    B = [dt(i-1) 0 0 0; 0 0 dt(i-1) 0]';
    
    p = Gx_rad(i);
    q = Gy_rad(i);
    r = Gz_rad(i);
   
    phi_hat   = phi_hat_kalman(i - 1);
    theta_hat = theta_hat_kalman(i - 1);
    
    phi_dot   = p + sin(phi_hat) * tan(theta_hat) * q + cos(phi_hat) * tan(theta_hat) * r;
    theta_dot = cos(phi_hat) * q - sin(phi_hat) * r;
          
    % Predict
    state_estimate = A * state_estimate + B * [phi_dot, theta_dot]';
    P = A * P * A' + Q;
    
    % Update
    measurement = [phi_hat_acc(i) theta_hat_acc(i)]';
    y_tilde = measurement - C * state_estimate;
    S = R + C * P * C';
    K = P * C' * (S^-1);
    state_estimate = state_estimate + K * y_tilde;
    P = (eye(4) - K * C) * P;
    
    phi_hat_kalman(i)    = state_estimate(1);
    bias_phi_kalman(i)   = state_estimate(2);
    theta_hat_kalman(i)  = state_estimate(3);
    bias_theta_kalman(i) = state_estimate(4);
    
end

% Convert all estimates to degrees
phi_hat_acc = phi_hat_acc * 180.0 / pi; theta_hat_acc = theta_hat_acc * 180.0 / pi;
phi_hat_gyr = phi_hat_gyr * 180.0 / pi; theta_hat_gyr = theta_hat_gyr * 180.0 / pi;
phi_hat_complimentary = phi_hat_complimentary * 180.0 / pi; theta_hat_complimentary = theta_hat_complimentary * 180.0 / pi;
phi_hat_kalman = phi_hat_kalman * 180.0 / pi; theta_hat_kalman = theta_hat_kalman * 180.0 / pi;

%% Plots
figure,
subplot(2, 1, 1);
plot(t, phi_hat_complimentary, t, phi_hat_acc, t, phi_hat_gyr, t, phi_hat_kalman)
legend('Complimentary', 'Accelerometer', 'Gyro', 'Kalman')
xlabel('Time (s)')
ylabel('Angle (Degrees)')
title('Roll')

subplot(2, 1, 2);
plot(t, theta_hat_complimentary, t, theta_hat_acc, t, theta_hat_gyr, t, theta_hat_kalman)
legend('Complementary', 'Accelerometer', 'Gyro', 'Kalman')
xlabel('Time (s)')
ylabel('Angle (Degrees)')
title('Pitch')
