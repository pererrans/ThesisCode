
%dummy base policy of not opening no matter what the conditions are
Xa_1 = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1);
Xb_1 = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1);
Xc_1 = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1);

%simulate settings
sim_dr = 0.1;
sim_orderOfFirms = orderOfFirms;

%demand fluctuation range and prob
sim_D_fluct = 0.9;
sim_D_prob = [0,1,0];
sim_Demand = Demand;

%the change associated with a state variable on whether demand has been permanently changed due to a
%high demand/low demand event (demand never fully recovers from large
%swings because of semi-permanent substitution (DPERM)
sim_DPERM_change = 0.1; % +10% change in non-shocked demand if DPERM is 1, and 20% if it's 2. 




%plottings -- maybe should be a function too

%compare the price
fig = figure;
time = 1:T;
plot(time, sim_Prices_1, time, sim_Prices_2);

leg1 = legend('base policy', 'best policy');
set(leg1, 'Box', 'off');
set(leg1, 'Color', 'none');


title('Price Path');
xlabel('Period (t)');
ylabel('Real price');

saveas(fig, 'price path.jpg'); 

%compare the market quantity over time
fig = figure(2);
plot(time, sim_Q_1, time, sim_Q_2);

leg1 = legend('base policy', 'best policy');
set(leg1, 'Box', 'off');
set(leg1, 'Color', 'none');

title('Market Clearing Quantity');
xlabel('Period (t)');
ylabel('Quantity');
hold off

%compare individual firm production quantity over time
display('policy 1 openings (row = mine #, column = firm #)');
sim_openings_1
display('policy 2 openings (row = mine #, column = firm #)');
sim_openings_2
sim_V_1
sim_V_2

saveas(fig, 'production path.jpg'); 

%compare the value (NPV) of the firms in the two scenarios
fig = figure(3);
x = 1:numFirms;
width1 = 0.5;
bar(x, sim_V_1, width1, 'FaceColor',[0.2,0.2,0.5],....
                     'EdgeColor','none');
hold on
width2 = width1/2;
bar(x, sim_V_2, width2,'FaceColor',[0,0.7,0.7],...
                     'EdgeColor',[0,0.7,0.7]);
legend('Policy 1', 'Policy 2');
title('NPV Comparison');
xlabel('Firm');
ylabel('NPV');
hold off
saveas(fig, 'NPV comparison.jpg'); 
