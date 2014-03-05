% New version of the exact DP to accomodate multiple players
% Yuanjian Carla Li, January 31, 2014

%Testing of the market clearing function
%Initialize variables by running the market_DP_new program once

%dummy curves
%DUMMY Supply Curve
SupplyCurve = zeros(12,3,T);
SupplyCurve(:,:,1) = [  1	200	50
                        1	200	100
                        1	200	150
                        1	200	200
                        2	200	50
                        2	200	100
                        2	200	150
                        2	200	200
                        3	200	50
                        3	200	100
                        3	200	150
                        3	200	200];
SupplyCurve(:,:,1) = sortrows(SupplyCurve(:,:,1),3);


%Assume a base supply curve that is constant over the time periods
%Populate the supply curve for the future
for t=2:T
    SupplyCurve(:,:,t) = SupplyCurve(:,:,1);
end

%Dummy Incentive Curves
IncentiveCurveA = [1	5	9	10
                    1	5	10	10
                    1	5	11	10];

IncentiveCurveB = [2	5	9	10
                    2	5	10	10
                    2	5	11	10];

IncentiveCurveC = [3	5	9	10
                    3	5	10	10
                    3	5	11	10];

                
                
TotalIncentiveCurve = [IncentiveCurveA(1:numIncMines, :); 
                        IncentiveCurveB(1:numIncMines, :);
                        IncentiveCurveC(1:numIncMines, :)];


%Change some variable initialization

t=1;
DPERM=3;

%test base case to see if the diagnostics and market_p, market_q make sense
MinesOpened_updated = ones(1,9);
[market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);

%test when one mine is open
MinesOpened_updated(1) = 2;
[market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);

%test symmetry
MinesOpened_updated = ones(1,9);
MinesOpened_updated(4) = 2;
[market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);

MinesOpened_updated = ones(1,9);
MinesOpened_updated(9) = 2;
[market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);

%test if demand in the correct period is used
%make demand grow first
D_0 = 1600;   %base demand

D_growth = 0.1;   %demand growth rate
%populate the demand series 
Demand = ones(1,T)*D_0;
for i=2:T
    Demand(i) = round(Demand(i-1)*(1+D_growth));
end

t=1;
MinesOpened_updated = ones(1,9);
[market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);
Demand(t)
market_q
firms_q
market_p
diag
cap_util
rewards


%Great test case to see whether the supplyTruncate mode is working or not.
%The 3 demand cases here include one that crosses supply at the start of the
%next-higher-cost mine, and one that crosses supply below the cost of the
%next higher cost mine
t=T;
Demand(t)=2400;
[market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);
Demand(t)


%test what happens if elasticity changes. we should see less demand loss at
%high demand/high price
el = 1;
Demand(t)=2000;

[market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);
Demand(t)

[market_p_1, market_q_1, cap_util_1, rewards_1, faces_1, firms_q_1, diag_1] = findPrice_new(T, numFirms, t, sim_m_1, sim_dperm_1, sim_DPERM_change, el, D_prob, sim_D_fluct, sim_demand, D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);


