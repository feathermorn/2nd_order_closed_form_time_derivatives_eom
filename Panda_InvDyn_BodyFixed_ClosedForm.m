% author: Shivesh Kumar
% last modified: October 18, 2020

% Franke Emika Panda example demonstrating application of the recursive
% second-order inverse dynamics algorithm presented in the RA-L submission
% "A Spatial O(n)-Algorithm for the Second-Order Inverse Dynamics and the 
% Fourth-order Forward and Inverse Kinematics of Serial Manipulators"

clear all
close all
clc

global Param; % Structure with all geoemtric and dynamic robot parameters
global Chain; % Structure with all temporal data

global n; % DOF, number of joints
n = 7;

global g; % gravity vector
g = [0; 0; 9.80665];

%% Joint screw coordinates in spatial representation
Param(1).Y = [0, 0, 1, 0., 0., 0]';
Param(2).Y = [0, 1, 0, -0.333, 0., 0]';
Param(3).Y = [0, 0, 1, 0., 0., 0]';
Param(4).Y = [0, -1, 0, 0.649, 0., -0.0825]';
Param(5).Y = [0, 0, 1, 0, 0., 0]';
Param(6).Y = [0, -1, 0, 1.033, 0., 0]';
Param(7).Y = [0, 0, -1, 0., 0.088, 0]';

%% Reference configurations of bodies (i.e. of bdoy-fixed reference frames)
Param(1).A = [eye(3),[0,0,0.333]';[0,0,0],[1]];
Param(2).A = [SO3Exp([1,0,0],-pi/2),[0,0,0.333]';[0,0,0],[1]];
Param(3).A = [eye(3),[0,0,0.649]';[0,0,0],[1]];
Param(4).A = [SO3Exp([1,0,0],pi/2),[0.0825,0,0.649]';[0,0,0],[1]];
Param(5).A = [eye(3),[0,0,1.033]';[0,0,0],[1]];
Param(6).A = [SO3Exp([1,0,0],pi/2),[0.0,0,1.033]';[0,0,0],[1]];
Param(7).A = [SO3Exp([1,0,0],pi),[0.088,0,1.033]';[0,0,0],[1]];

%% Joint screw coordinates in body-fixed representation
Param(1).X = SE3AdjInvMatrix(Param(1).A)*Param(1).Y;
Param(2).X = SE3AdjInvMatrix(Param(2).A)*Param(2).Y;
Param(3).X = SE3AdjInvMatrix(Param(3).A)*Param(3).Y;
Param(4).X = SE3AdjInvMatrix(Param(4).A)*Param(4).Y;
Param(5).X = SE3AdjInvMatrix(Param(5).A)*Param(5).Y;
Param(6).X = SE3AdjInvMatrix(Param(6).A)*Param(6).Y;
Param(7).X = SE3AdjInvMatrix(Param(7).A)*Param(7).Y;

%% Intertia paramater as reported in [C. Gaz, 2019]
Param(1).Mb = MassMatrixMixedData(4.970684, ...
    [0.70337,-1.39e-04,6.772e-03;
    -1.39e-04,0.70661,1.9169e-02;
    6.772e-03,1.9169e-02,9.117e-03], ...
    [3.875e-03, 2.081e-03, -0.1750]);
Param(2).Mb = MassMatrixMixedData(0.646926, ...
    [7.962e-03, -3.925e-03, 1.0254e-02;
     -3.925e-03, 2.811e-02, 7.04e-04;
     1.0254e-02, 7.04e-04, 2.5995e-02], ...
    [-3.141e-03, -2.872e-02, 3.495e-03]);
Param(3).Mb = MassMatrixMixedData(3.228604, ...
    [3.7242e-02, -4.761e-03, -1.1396e-02;
     -4.761e-03, 3.6155e-02, -1.2805e-02;
     -1.1396e-02, -1.2805e-02, 1.083e-02], ...
    [2.7518e-02, 3.9252e-02, -6.6502e-02]);
Param(4).Mb = MassMatrixMixedData(3.587895, ...
    [2.5853e-02, 7.796e-03, -1.332e-03;
     7.796e-03, 1.9552e-02, 8.641e-03;
     -1.332e-03, 8.641e-03, 2.8323e-02], ...
    [-5.317e-02, 0.104419, 2.7454e-02]);
Param(5).Mb = MassMatrixMixedData(1.225946, ...
    [3.5549e-02, -2.117e-03, -4.037e-03;
     -2.117e-03, 2.9474e-02, 2.29e-04;
     -4.037e-03, 2.29e-04, 8.627e-03], ...
    [-1.1953e-02, 4.1065e-02, -3.8437e-02]);
Param(6).Mb = MassMatrixMixedData(1.666555, ...
    [1.964e-03, 1.09e-04, -1.158e-03;
     1.09e-04, 4.354e-03, 3.41e-04;
     -1.158e-03, 3.41e-04, 5.433e-03], ...
    [6.0149e-02, -1.4117e-02, -1.0517e-02]);
Param(7).Mb = MassMatrixMixedData(0.735522, ...
    [1.2516e-02, -4.28e-04, -1.196e-03;
     -4.28e-04, 1.0027e-02, -7.41e-04;
     -1.196e-03, 7.41e-04, 4.815e-03], ...
    [1.0517e-02, -4.252e-03, 6.1597e-02]);


for i=1:n 
    Chain(i).V = zeros(n,1);
    Chain(i).Vd = zeros(n,1);
    Chain(i).V2d = zeros(n,1);
    Chain(i).V3d = zeros(n,1);
    Chain(i).f = zeros(4,4);
    Chain(i).C = zeros(4,4);
    Chain(i).Crel = zeros(4,4); % C_i,i-1
    Chain(i).AdCrel = zeros(6,6);
    Chain(i).adX = zeros(6,6);
    Chain(i).W = zeros(6,1);   % interbody wrench
    Chain(i).Wd = zeros(6,1);
    Chain(i).W2d = zeros(6,1);
    Chain(i).Q = 0;
    Chain(i).Qd = 0;
    Chain(i).Q2d = 0;
 end;

N=10000;  % number of samples
T=5;    % simulation time
dt=T/N; % time step size

q = zeros(N,n);
qd = zeros(N,n);
q2d = zeros(N,n);
q3d = zeros(N,n);
q4d = zeros(N,n);
Q = zeros(N,n);

%% 2nd-order inverse dynamics run
% Test trajectory according to equation (31) and table I in [C. Gaz et al., RAL, Vol. 4, No. 4, 2019]
for k=1:6
%     tic
for i=1:N+1
    t = (i-1)*dt;
    q(i,:) = [-1.2943753211777664*cos(1.7073873117335832*t), 0.7175341454355011* cos(3.079992797637052*t), -0.5691380764966176* cos(2.1084514453622774*t),   0.5848944158627155*cos(3.5903916041026207*t), 1.6216297151633214* cos(1.4183262544423447*t), -0.9187855709752027*cos(2.285625793808507*t), 0.4217605991935227*cos(5.927533308659986*t)];
    qd(i,:) =[2.21*sin(1.7073873117335832*t),-2.21*sin(3.079992797637052*t),1.2*sin(2.1084514453622774*t),-2.1*sin(3.5903916041026207*t),-2.3*sin(1.4183262544423447*t),2.1*sin(2.285625793808507*t),-2.5*sin(5.927533308659986*t)];
    q2d(i,:) = [3.7733259589312187*cos(1.7073873117335832*t), -6.8067840827778845* cos(3.079992797637052*t), 2.5301417344347326* cos(2.1084514453622774*t),   -7.5398223686155035*cos(3.5903916041026207*t), -3.2621503852173928* cos(1.4183262544423447*t), 4.799814166997865*cos(2.285625793808507*t),   -14.818833271649964*cos(5.927533308659986*t)];
    q3d(i,:) = [-6.442528865314118*sin(1.7073873117335832*t), 20.96484595002641* sin(3.079992797637052*t), -5.334680996940331* sin(2.1084514453622774*t), 27.070914928702237* sin(3.5903916041026207*t),   4.626793537293037*sin(1.4183262544423447*t), -10.970579065577812*sin(2.285625793808507*t), 87.83912781318399*sin(5.927533308659986*t)];
    q4d(i,:) = [-10.999892040114684*cos(1.7073873117335832*t), 64.57157452965167* cos(3.079992797637052*t), -11.247915858545515* cos(2.1084514453622774*t), 97.19518567538881* cos(3.5903916041026207*t),   6.562302747826879*cos(1.4183262544423447*t), -25.074638485300277*cos(2.285625793808507*t), 520.6693559162899*cos(5.927533308659986*t)];
%     WEE = 10*sin(pi*t)*ones(6,1);
%     WDEE = 10*pi*cos(pi*t)*ones(6,1);
%     W2DEE = -10*pi*pi*sin(pi*t)*ones(6,1);
%     [Q(i,:),Qd(i,:),Q2d(i,:)] = InvDyn_BodyFixed(q(i,:),qd(i,:),q2d(i,:),q3d(i,:),q4d(i,:));
%     [Q_closedform(i,:), Qd_closedform(i,:), Q2d_closedform(i,:)] = ClosedFormInvDyn_BodyFixed(q(i,:)',qd(i,:)',q2d(i,:)',q3d(i,:)',q4d(i,:)', WEE, WDEE, W2DEE);
% [Q_closedform(i,:), Qd_closedform(i,:), Q2d_closedform(i,:), V(i,:), Vd(i,:), V2d(i,:)] = ClosedFormInvDyn_BodyFixed(q(i,:)',qd(i,:)',q2d(i,:)',q3d(i,:)',q4d(i,:)');
end;
% toc
end;

tic
[Q,Qd,Q2d] = InvDyn_BodyFixed(q(i,:),qd(i,:),q2d(i,:),q3d(i,:),q4d(i,:));
toc
tic
[Q_closedform, Qd_closedform, Q2d_closedform] = ClosedFormInvDyn_BodyFixed(q(i,:)',qd(i,:)',q2d(i,:)',q3d(i,:)',q4d(i,:)');
toc
% tic
% [Q_Spatial,Qd_Spatial,Q2d_Spatial] = InvDyn(q(i,:),qd(i,:), q2d(i,:),q3d(i,:),q4d(i,:));
% toc
% 
% figure;
% hold on
% plot(Q);
% plot(Q_closedform,'--');
% xlabel('Time (s)');
% ylabel('Generalized Forces (Nm)');
% legend('Q1', 'Q2', 'Q3', 'Q4', 'Q5', 'Q6','Q7', 'Q1c', 'Q2c','Q3c', 'Q4c', 'Q5c','Q6c','Q7c');
% title('Closed Form vs Recursive Form: Generalized Forces Q');
% 
% figure;
% hold on
% plot(Qd);
% plot(Qd_closedform,'--');
% xlabel('Time (s)');
% ylabel('Generalized Forces (Nm)');
% legend('Q1d', 'Q2d', 'Q3d', 'Q4d', 'Q5d', 'Q6d','Q7d', 'Q1dc', 'Q2dc','Q3dc', 'Q4dc', 'Q5dc','Q6dc','Q7dc');
% title('Closed Form vs Recursive Form: 1st order Generalized Forces Qdot');
% 
% figure;
% hold on
% plot(Q2d);
% plot(Q2d_closedform,'--');
% xlabel('Time (s)');
% ylabel('Generalized Forces (Nm)');
% legend('Q1dd', 'Q2dd', 'Q3dd', 'Q4dd', 'Q5dd', 'Q6dd','Q7dd', 'Q1ddc', 'Q2ddc','Q3ddc', 'Q4ddc', 'Q5ddc','Q6ddc','Q7ddc');
% title('Closed Form vs Recursive Form: 2nd order Generalized Forces Qddot');
% 
% Qdc_num = diff(Q_closedform)/dt;
% 
% figure;
% hold on
% plot(Qdc_num);
% plot(Qd_closedform,'--');
% xlabel('Time (s)');
% ylabel('Generalized Forces (Nm/s)');
% legend('Q1d_num', 'Q2d_num', 'Q3d_num', 'Q4d_num', 'Q5d_num', 'Q6d_num','Q7d_num', 'Q1dc', 'Q2dc','Q3dc', 'Q4dc', 'Q5dc','Q6dc','Q7dc');
% title('Closed Form vs Numerical: 1st order Generalized Forces Qdot');
% 
% Qddc_num = diff(Qd_closedform)/dt;
% 
% figure;
% hold on
% plot(Qddc_num);
% plot(Q2d_closedform,'--');
% xlabel('Time (s)');
% ylabel('Generalized Forces (Nm/s^2)');
% legend('Q1dd_num', 'Q2dd_num', 'Q3dd_num', 'Q4dd_num', 'Q5dd_num', 'Q6dd_num','Q7dd_num', 'Q1ddc', 'Q2ddc','Q3ddc', 'Q4ddc', 'Q5ddc','Q6ddc','Q7ddc');
% title('Closed Form vs Numerical: 2nd order Generalized Forces Qddot');

Q_body = Q;
Qd_body = Qd;
Q2d_body = Q2d;

return

% store results
save('q_body.txt','q','-ascii')
save('qd_body.txt','qd','-ascii')
save('q2d_body.txt','q2d','-ascii')
save('QQ_body.txt','Q','-ascii')
save('QQd_body.txt','Qd','-ascii')
save('QQ2d_body.txt','Q2d','-ascii')

%%% Visualize results %%%%%%%%%%%%%%

%% Plots of joint coordinates and their derivatives

time=0:dt:T;

figure(1)
for j=1:n
    subplot(4,2,j);
    plot(time,q(:,j))
    xlabel('time [s]');
    ylabeltext = sprintf('_%i [rad]',j);
    ylabel(['q' ylabeltext]);
    grid;
end

figure(2)
for j=1:n
    subplot(4,2,j);
    plot(time,qd(:,j))
    xlabel('time [s]');
    ylabeltext = sprintf('_%i [rad/s]',j);
    ylabel(['qd' ylabeltext]);
    grid;
end

figure(3)
for j=1:n
    subplot(4,2,j);
    plot(time,q2d(:,j))
    xlabel('time [s]');
    ylabeltext = sprintf('_%i [rad/s^2]',j);
    ylabel(['q2d' ylabeltext]);
    grid;
end

figure(4)
for j=1:n
    subplot(4,2,j);
    plot(time,q3d(:,j))
    xlabel('time [s]');
    ylabeltext = sprintf('_%i [rad/s^3]',j);
    ylabel(['q3d' ylabeltext]);
    grid;
end

figure(5)
for j=1:n
    subplot(4,2,j);
    plot(time,q4d(:,j))
    xlabel('time [s]');
    ylabeltext = sprintf('_%i [rad/s^4]',j);
    ylabel(['q4d' ylabeltext]);
    grid;
end


%% Plots of drive torques and their derivatives

PlotOption = 1;

if PlotOption == 1
% Option 1 : Plot all torques in one plot

figure(6)
plot(time,[Q(:,1),Q(:,2),Q(:,3),Q(:,4),Q(:,5),Q(:,6),Q(:,7)])
figure(7)
plot(time,[Qd(:,1),Qd(:,2),Qd(:,3),Qd(:,4),Qd(:,5),Qd(:,6),Qd(:,7)])
figure(8)
plot(time,[Q2d(:,1),Q2d(:,2),Q2d(:,3),Q2d(:,4),Q2d(:,5),Q2d(:,6),Q2d(:,7)])

else

% Option 2 : Plot each torques in one figure of a pannel plot
figure(6)
for j=1:n
    subplot(4,2,j);
    plot(Q(:,j))
    xlabel('time [s]');
    ylabeltext = sprintf('_%i [Nm]',j);
    ylabel(['Q' ylabeltext]);
    grid;
end
figure(7)
for j=1:n
    subplot(4,2,j);
    plot(Qd(:,j))
    xlabel('time [s]');
    ylabeltext = sprintf('_%i [Nm/s]',j);
    ylabel(['Qd' ylabeltext]);
    grid;
end
figure(8)
for j=1:n
    subplot(4,2,j);
    plot(Q2d(:,j))
    xlabel('time [s]');
    ylabeltext = sprintf('_%i [Nm/s^2]',j);
    ylabel(['Qdd' ylabeltext]);
    grid;
end
end

return;

%% Tests

% Check first derivatives

time=0:dt:T;

figure(1);
plot(time,Q_spat,'b',time,Q_body,'r--');
Q_Diff=Q_body-Q_spat;
figure(2);
plot(time,Q_Diff);

figure(1);
plot(time,Qd_spat,'b',time,Qd_body,'r--');
Qd_Diff=Qd_body-Qd_spat;
figure(2);
plot(time,Qd_Diff);

Qd_bodyappr=gradient(Q_body') ./ gradient(time);
Qd_bodyappr=Qd_bodyappr';
figure(3);
plot(time,Qd_body,'b',time,Qd_bodyappr,'r--');
Qd_bodyDiff=Qd_bodyappr-Qd_body;
figure(4);
plot(time,Qd_bodyDiff)

% Check second derivatives

figure(1);
plot(time,Q2d_spat,'b',time,Q2d_body,'r--');
Q2d_Diff=Q2d_body-Q2d_spat;
figure(2);
plot(time,Q2d_Diff);

%Q2d_spatappr=gradient(Qd_body') ./ gradient(time);
Q2d_bodyappr=gradient(Qd_bodyappr') ./ gradient(time);
Q2d_bodyappr=Q2d_bodyappr';
figure(3);
plot(time,Q2d_body,'b',time,Q2d_bodyappr,'r--');
Q2d_bodyDiff=Q2d_bodyappr-Q2d_body;
figure(4);
plot(time,Q2d_bodyDiff)
