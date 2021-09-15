clear variables
clear global
clc
close all
warning off %#ok<*WNOFF>

% % height variation of the quadcopter in meters
h = 1:500;

% % cell radius variaion and fixed height
% h = 500; % 100 200 300 500 700

% % horizontal distance of user
R = 500; % cell radius in meters

% % transmit power
Pt = 25;

% % reference distance from quadcopter
R0 = 0;

% generating a pseudo random number which is unformly distributed in [0,1]
u = rand;
% u = rand(1, length(h));

% user horizontal distance this is pseudo random
r = R.*sqrt(u);

% bandwidth
B = 5 * 10^6; % MHz

% angle of elevation
theta_rad = atan(h./r);

% convert to degree
theta = rad2deg(theta_rad);

%% % Probablity of LOS and NLOS
% % various simulation scenarios
% % suburban % wood and empty space % thumbs up pogchamp
s=101.6; t=0; u=0; v=3.25; w=1.241; pathloss_exp=2.2; n_los=0.1; n_nlos=21;

% % urban % concrete % more blockage % meh
% s=120; t=0; u=0; v=24.30; w=1.229; pathloss_exp=3.1; n_los=1; n_nlos=20;

% % dense urban % concrete and glass % bad performance
% s=187.3; t=0; u=0; v=82.10; w=1.478; pathloss_exp=4.58; n_los=1.6; n_nlos=23;

% % urban high-rise % glass and metal % holy shit wtf performance
% s=352; t=-1.37; u=-53; v=173.80; w=4.670; pathloss_exp=5.5; n_los=2.3; n_nlos=34;

% % probability of line of sight calculation
num_1 = s - t;
den_1 = 1 + ((theta-u)./v).^w;
prob = s - (num_1./den_1);
% % line of sight probability
prob_los = prob./100;

% % non line of sight probability as bernouli dist
prob_nlos = 1- prob_los;


%% % Capacity in Pathloss and shadowing environment
% % Free space pathloss
% % line of sight distance (path length)
d = sqrt(r.^2 + h.^2);

% % transmit frequency
f = 2.4 * 10^9; % wifi

c = 3*10^8;

% wavelength
lambda = c/f;

% k_attenuation = 20.*log10(lambda./(2.*pi.*d0));

% angular frequency
% ang_freq = 2*pi*f;

%% Rain attenuation
% rain rate
% http://wiki.sandaysoft.com/a/Rain_measurement
% R1 < 0.25; % very light rain mm/hr
R1 = linspace(0.25,1, length(h)); % light rain
% R1 = linspace(1,4, length(h)); % moderate rain
% R1 = linspace(4,16, length(h)); % heavy rain
% R1 = linspace(16,50, length(h)); % very heavy rain
% R1 > 50; % extreme rain

% parameter values at 2.5 GHz
kh = 0.0001321; ah= 1.1209; kv= 0.0001264; av= 1.0085;

% parameter values at 1 GHz
% kh = 0.0000259; ah= 0.9691; kv= 0.0000308; av= 0.8592;
k = (kh + kv + ((kh - kv) .* (cos(theta)).^2 .* cos(2*45)) )./2;
alpha = (kh * ah + kv * av + (kh*ah - kv*av) * (cos(theta)).^2 .* cos(2*45))./(2.*k);

rain_attenuation_dB = k .* (R1.^(alpha));

%% Gaseous absorption attenuation - oxygen and water vapour
p = 1013; % dry air pressue hPa
temp = 25; % deg C
row = 10; % water vapour density
e = (row*temp)/216.7;
p_tot= p + e;
rt= 288/(273 + temp);
rp= p_tot/1013;

a=0.0717; b=-1.8132; c=0.0156; d11=-1.6515;
psy = rp^a * rt^b * exp( c*(1-rp) + d11*(1-rt) );
e1= psy;

a1=0.5146; b1=-4.6368; c1=-0.1921; d1=-5.7416;
psy1 = rp^a1 * rt^b1 * exp( c1*(1-rp) + d1*(1-rt) );
e2= psy1;

a2=0.3414; b2=-6.5851; c2=0.2130; d2=-8.5854;
psy2 = rp^a2 * rt^b2 * exp( c2*(1-rp) + d2*(1-rt) );
e3= psy2;

ter1 = ( 7.2 * rt^(2.8) )/( f.^2 + 0.34 * rp^2 * rt^(1.6) );
ter2 = ( 0.62 * e3 )/( (54*10^9-f).^(1.16*e1) + 0.83*e2 );

% attenuation of oxygen
gammaO = (ter1 + ter2) .* ( f.^2 * rp^2 * 10^(-3));

% attenuation of water vapour
neta_1 = 0.955 * rp * rt^(0.68) + 0.006*row;

g_f = 1 + ((f - 22)/(f + 22)).^2;
t1 = ( 3.98 * neta_1 * exp(2.238*(1-rt)) * g_f )/( (f - 22.235)^2 + 9.42*neta_1^2 );
t2 = ( 11.96 * neta_1 * exp(0.7*(1-rt)) )/( (f-183.31)^2 + 11.14 * neta_1^2 );
t3 = ( 0.081 * neta_1 * exp(6.44 * (1-rt)) )/( (f-321.226)^2 + 6.29 * neta_1^2 );
t4 = ( 3.66 * neta_1 * exp(1.6 * (1-rt)) )/( (f-325.153)^2 + 9.22 * neta_1^2 );
t5 = ( 25.37 * neta_1 * exp(1.09 * (1-rt)) )/( (f-380)^2 );
t6 = ( 17.4 * neta_1 * exp(1.46 * (1-rt)) )/( (f-448)^2 );
g_f1 = 1 + ((f - 557)/(f + 557))^2;
t7 = ( 844.6 * neta_1 * exp(0.17 * (1-rt)) * g_f1 )/( (f-557)^2 );
g_f2 = 1 + ((f - 752)/(f + 752))^2;
t8 = ( 290 * neta_1 * exp(0.41 * (1-rt)) * g_f2)/( (f-752)^2 );  
neta_2 = 0.735 * rp * rt^(0.5) + 0.0353 * rt^4 * row;
g_f3 = 1 + ((f - 1780)/(f + 1780))^2;
t9 = ( 8.3328*10^(4) * neta_2 * exp(0.99 * (1-rt)) * g_f3)/( (f-1780)^2 );

gammaW = (t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9) * ( f^2 * rt^(2.5) * row * 10^(-4) );

% oxygen attenuation
% gamma0_dB = 20*log10(gamma0);

% water vapour attenuation
% gammaW_dB = 20*log10(gammaW);

% total gas attenuation for both oxygen and water vapour
gas_attenuation_dB = gammaO + gammaW;


%% Height modification for shadowing 
% Random part of shadowing
shadowing_los = normrnd(0,4);

xx = (-94.2 + theta)./(-3.44 + 0.0318.*theta);
yy = (-90 + theta)./(-8.87 + 0.0927.*theta);
shadowing_nlos = normrnd(xx,yy) + normrnd(0,10);

%% Doppler spread due to high rotation of propellers
% Doppler shift due to multipath
% iterr = 10000;
% doppler_shift_dB = 0;
% for vic = 1:iterr
%     doppler_shift = velocity_user .* cos(theta)./lambda;
%     doppler_shift_dB = doppler_shift_dB + mean(20*log10(doppler_shift));
% end

velocity_drone = 0; % drone as a fixed base station case
velocity_user = 10*rand(1,1); % km/hr
max_doppler_shift = (velocity_drone + velocity_user)/lambda;
max_doppler_dB = 20*log10(max_doppler_shift);

% doppler_shift = velocity_user .* cos(theta)./lambda;

%% Small scale fading
a=212.3; b=-2.221; c=1.289;
sig_var = mean(a .* h.^b + c);
mean_rice = 6.041;

rice_los = makedist('Rician', mean_rice, sig_var);
rice_pdf = pdf(rice_los, theta);

ray_nlos = makedist('Rayleigh', sig_var);
ray_pdf = pdf(ray_nlos, theta);


%% % free space path loss in LOS and NLOS conditions
fspl_los_dB = 20*log10(d) + 20*log10(f) + shadowing_los + max_doppler_dB + ...
    20*log10(4*pi/c) + rain_attenuation_dB + gas_attenuation_dB + n_los;

fspl_nlos_dB = 10.*pathloss_exp.*log10(d) + 20*log10(f) + shadowing_nlos + ...
    max_doppler_dB + 20*log10(4*pi/c) + rain_attenuation_dB + ...
    gas_attenuation_dB + n_nlos;

% without rain
% fspl_los_dB = 20*log10(d) + 20*log10(f) + shadowing_los + max_doppler_dB + ...
%     20*log10(4*pi/c) + gas_attenuation_dB + n_los;
% 
% fspl_nlos_dB = 10.*pathloss_exp.*log10(d) + 20*log10(f) + shadowing_nlos + ...
%     max_doppler_dB + 20*log10(4*pi/c) + ...
%     gas_attenuation_dB + n_nlos;

% % aggregate path loss in accordance with its probability of occurence
aggregate_pathloss = fspl_los_dB .* prob_los + fspl_nlos_dB .* prob_nlos;

% convert to dB
aggregate_pathloss_dB = 20*log10(aggregate_pathloss);

% % received signal power in dB
Pr_dB = Pt - aggregate_pathloss_dB;

% % received signal power in dbW
Pr = 10.^(Pr_dB./10);

% % % noise power
N0_dB = 3;
N0 = 10.^(N0_dB./10);

% Signal to Noise Ratio
snr = Pr./(N0.*B);

figure (1)
plot(h, snr)
grid on