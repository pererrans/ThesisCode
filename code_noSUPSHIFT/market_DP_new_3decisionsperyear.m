% Exact DP solution and simulation to a 3-player game in the mineral market
% Yuanjian Carla Li, version April 1, 2014

%naming for the output in terms of firm decision ordering
ordering = 'CBA'; 

switch ordering
    case 'ABC'
        decision_order = [1 2 3];
    case 'ACB' 
        decision_order = [1 3 2];
    case 'BAC' 
        decision_order = [2 1 3];
    case 'BCA' 
        decision_order = [2 3 1];
    case 'CAB' 
        decision_order = [3 1 2];
    case 'CBA' 
        decision_order = [3 2 1];
end

%record the profile for performance enhancement
profile on %-detail builtin -history
diary([ordering '_output_log']);
diary on;

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%INITIALIZE VARIABLES AND SET THE MODES FOR THIS OPTIMIZATION AND
%%SIMULATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%initialize variables
rng(1); %set seed for random number
dr = 0.1;
numFirms = 3; %number of firms
numIncMines = 3; %number of incentive mines per firm

%DIFFERENT MODES FOR THE PROGRAM
%SUPPLYCURVE_MODE controls which supply curve is used. 0 is for the scrambled Rio
%Tinto one. 1 is for the real Rio Tinto one. 2 is for the real Rio Tinto
%one with exogenous supply growth at the low end of the supply curve
% 3 is for the real Rio Tinto one with exogenous supply growth at realistic
% quantity and opex (from data)
%-1 is for the real Rio Tinto one except the 
%capex is reduced 10x so that shorter time horizon can still yield mine opening.
% -2 is for the dummy one for testing purpose. -3 is for the Rio Tinto one with more aggregation (testing purpose) 
SUPPLYCURVE_MODE = 1;

%MODE_MKT_CLEAR_AFTER_ALL_DECIDE controls whether we have all the mines make a decision before the
%market clears (1), or whether the market clears after each one (0). It 
%affects the interpretation of dt as well. T is 1/3 of a year in the first
%case, and a year in the second case
MODE_MKT_CLEAR_AFTER_ALL_DECIDE = 1;

if(MODE_MKT_CLEAR_AFTER_ALL_DECIDE ==0)
    decisions_in_dt = 1;
else
    decisions_in_dt = numFirms;
end

%Time setup
T_years = 27;  %number of years in T (market clears at the end of each year)
T = decisions_in_dt*T_years; %T is the number of decision periods and is equal to the number of decisions in each year * number of years

%MODE_END_PERIOD_VALUE controls what value we assign to the mines at the
%end of the 25-year period over which we have an accurate projection for
%the underlying demand
% 0 = no value for any mining property
% 1 = same value as the last period (this is assuming the same production
% and price level, i.e. capacity growth is keeping pace with demand growth
% 2 = The incentive mines not already opened will open at the end of period
% T if the opex of the mine is less or equal to the price in this period
% 3 = The incentive mines not already opened will open at the end of period
% T if the opex of the mine is less or equal to the price in this period
% with a minimum return rate on investment of 10% (or whatever discount rate we are using)
% (industry is more like 11-16%, according to the article Bhappa and Guzman 1995. 
MODE_END_PERIOD_VALUE = 0;

%specify the order that the firms will make decision in. 2 in period t
%indicates that firm 2 will make a decision in t=2
orderOfFirms = repmat(decision_order,1,ceil((T+1)/numFirms));  %HARDCODE ALERT
orderOfFirms = orderOfFirms(1:T+1);

%there are 3 incentive mines per player, 3 players,  a variable that
%indicates which player is making decision in a period, and 5 levels of
%permanent demand change
%For the value vector for each state-action pair, the numIncMines+1 dimension 
% refers to whcih action is taken. Since the action could be to open none 
% of the mines or any of the incentive mines, the length of the dimension 
% is numIncMines+1
Va_actions = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,numIncMines+1, T+1); 
Vb_actions = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,numIncMines+1, T+1);
Vc_actions = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,numIncMines+1, T+1);
% Va etc store the optimal value
Va = zeros(2,2,2,2,2,2,2,2,2,numFirms,5, T+1); 
Vb = zeros(2,2,2,2,2,2,2,2,2,numFirms,5, T+1);
Vc = zeros(2,2,2,2,2,2,2,2,2,numFirms,5, T+1);
%optimal actions built as a cell array, because each cell could have more
%than 1 action that is optimal
Xa = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1); 
Xb = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1);
Xc = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1);
Prices = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T);
Quantities = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T);
CapUtils = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T);
Faces = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T);

%%
%%Demand settings
%demand elasticity
el = 1; 
%demand level and growth
%D_0 = 1100;   %base demand
D_0 = 1400;   %base demand
D_growth = 0.02;   %demand growth rate

%populate the demand series 
Demand = ones(1,T)*D_0;
Demand_yr = ones(1,T_years)*D_0; 
for t_yr=2:T_years
    Demand_yr(t_yr) = Demand_yr(t_yr-1)*(1+D_growth);
end

if(T==T_years)
    Demand = Demand_yr; 
else
    for t=1:T
        if(mod(t,decisions_in_dt)==1)
            Demand(t) = Demand_yr(ceil(t/decisions_in_dt));
        else
            Demand(t) = Demand(t-1);
        end
    end 
end

%demand fluctuation range and prob
D_fluct = 0.97;  %TODO: THIS CANNOT BE ZERO AT THE MOMENT. NEED TO SAFETY CHECK
D_prob = [0,1,0];

%the change associated with a state variable on whether demand has been permanently changed due to a
%high demand/low demand event (demand never fully recovers from large
%swings because of semi-permanent substitution (DPERM)
DPERM_change = 0.05; % +5% change in non-shocked demand if DPERM is 1, and 10% if it's 2. 

%%
%%Supply curve - assume it doesn't change over time
% structure is owner, quantity, cost
SupplyCurve = zeros(96,3,T);
if(SUPPLYCURVE_MODE==1 || SUPPLYCURVE_MODE==2 || SUPPLYCURVE_MODE==3)
%first mine is the placeholder for increasing supply
%inflated highest price Q to never run out of supply
    SupplyCurve(:,:,1) = [4 0   1
                        4	16	15
                        4	9	25
                        4	15	35
                        2	74	39
                        3	46	40
                        3	2	40
                        3	50	42
                        3	9	43
                        4	14	43
                        3	3	44
                        2	40	46
                        3	102	46
                        3	24	47
                        2	42	47
                        2	24	48
                        4	36	48
                        2	25	49
                        1	289	49
                        4	48	51
                        4	36	54
                        3	5	54
                        3	4	55
                        4	47	56
                        4	37	59
                        4	71	61
                        4	21	64
                        1	12	65
                        4	29	66
                        3	2	66
                        4	88	69
                        4	28	71
                        4	26	74
                        3	21	76
                        3	6	76
                        4	80	76
                        4	16	79
                        4	16	81
                        4	30	84
                        4	33	86
                        1	5	86
                        4	16	89
                        4	22	91
                        4	17	94
                        3	9	96
                        4	19	96
                        4	14	99
                        4	19	101
                        4	16	104
                        4	25	106
                        4	11	109
                        4	11	111
                        4	9	114
                        4	17	116
                        4	12	119
                        4	10	123
                        4	5	128
                        4	14	133
                        4	8	138
                        4	6	143
                        4	21	148
                        4	4	153
                        4	2	163
                        4	2	168
                        4	2	175
                        4	1	185
                        4	3	195
                        4	3	205
                        4	3	225
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245];
elseif(SUPPLYCURVE_MODE==-3)
    SupplyCurve(1:44,:,1) = [1	289	49
            1	12	65
            1	5	86
            2	74	39
            2	40	46
            2	42	47
            2	24	48
            2	25	49
            3	46	40
            3	2	40
            3	50	42
            3	9	43
            3	3	44
            3	102	46
            3	24	47
            3	5	54
            3	4	55
            3	2	66
            3	6	76
            3	21	76
            3	9	96
            4	0	5
            4	16	15
            4	9	25
            4	15	35
            4	49	45
            4	169	55
            4	209	65
            4	150	75
            4	95	85
            4	72	95
            4	70	105
            4	48	115
            4	15	125
            4	22	135
            4	27	145
            4	4	155
            4	4	165
            4	2	175
            4	1	185
            4	3	195
            4	3	205
            4	3	225
            4	10	245];  
    %inflate highest price Q to never run out of supply
    highcostQ = repmat([4 2 245], (95-44),1);
    SupplyCurve(45:95,:,1) = highcostQ;
end
%sort the supply to reduce later sorting time
SupplyCurve(:,:,1) = sortrows(SupplyCurve(:,:,1),3);

% %DUMMY Supply Curve
% SupplyCurve = zeros(12,3,T);
% SupplyCurve(:,:,1) = [  1	200	50
%                         1	200	100
%                         1	200	150
%                         1	200	200
%                         2	200	50
%                         2	200	100
%                         2	200	150
%                         2	200	200
%                         3	200	50
%                         3	200	100
%                         3	200	150
%                         3	200	200];
% SupplyCurve(:,:,1) = sortrows(SupplyCurve(:,:,1),3);
%
% %END OF DUMMY SUPPLY CURVE 


%Assume a base supply curve that is constant over the time periods
%Populate the supply curve for the future
for t=2:T
    SupplyCurve(:,:,t) = SupplyCurve(:,:,1);
end 
if(SUPPLYCURVE_MODE==2)
    for t=2:T
        SupplyCurve(1,2,t) = SupplyCurve(1,2,t-1)+13; %%HARDCODE ALERT: 13 is 1% of the existing ROW supply)
    end
elseif(SUPPLYCURVE_MODE==3)
    for t=2:T
        SupplyCurve(1,2,t) = SupplyCurve(1,2,t-1) + (1300+SupplyCurve(1,2,t-1)) * 0.01; %%HARDCODE ALERT: 1300 is the existing ROW supply, and we are assuming 1% compound growth
    end
end    

%%
%Settings for new mines, ie incentive curves. The columns are ownerID, capacity, opex, and
%capex respectively
if(SUPPLYCURVE_MODE==0)
    IncentiveCurveA = [1	70	43	5600
                        1	50	47	10247
                        1	50	49	10417];

    IncentiveCurveB = [2	50	52	9629
                        2	110	57	28211
                        2	55	49	10754];

    IncentiveCurveC = [3	90	54	16700
                        3	45	54	5445
                        3	45	67	11354];
    
elseif(SUPPLYCURVE_MODE==1 || SUPPLYCURVE_MODE==2 || SUPPLYCURVE_MODE==3)
    IncentiveCurveA = [1	70	43	5600
                        1	50	47	10247
                        1	50	49	10417];

    IncentiveCurveB = [2	50	52	9629
                        2	110	57	28211
                        2	55	49	10754];

    IncentiveCurveC = [3	90	54	16700
                        3	45	54	5445
                        3	45	67	11354];
elseif(SUPPLYCURVE_MODE==-1)

    % Reduced capex incentive curve (so that shorter periods would still have
    % mine openings)
    IncentiveCurveA = [1	70	43	560
                        1	50	47	1025
                        1	50	49	1042];

    IncentiveCurveB = [2	50	52	963
                        2	110	57	2821
                        2	55	49	1075];

    IncentiveCurveC = [3	90	54	1670
                        3	45	54	544
                        3	45	67	1135];
elseif(SUPPLYCURVE_MODE==-2)
% %Dummy Incentive Curves
IncentiveCurveA = [1	5	9	10
                    1	5	10	10
                    1	5	11	10];

IncentiveCurveB = [2	5	9	10
                    2	5	10	10
                    2	5	11	10];

IncentiveCurveC = [3	5	9	10
                    3	5	10	10
                    3	5	11	10];
% %END OF DUMMY INCENTIVE CURVE
end

%Put all the incentive curves together into master incentive curve                
TotalIncentiveCurve = [IncentiveCurveA(1:numIncMines, :); 
                        IncentiveCurveB(1:numIncMines, :);
                        IncentiveCurveC(1:numIncMines, :)];
TotalIncCurve_byFirm = cell(3,1);
TotalIncCurve_byFirm{1} = IncentiveCurveA(1:numIncMines, :);
TotalIncCurve_byFirm{2} = IncentiveCurveB(1:numIncMines, :);
TotalIncCurve_byFirm{3} = IncentiveCurveC(1:numIncMines, :);

                    
%calculate the coefficient a for the demand function
%P=X^(1/elasticity)*a*Q^(-1/elasticity)*(1+g)^(1/elasticity)
%a will remain the same throughout the time periods
baseQ = D_0; %where base demand and supply should meet
SupplyCurve_0=sortrows(SupplyCurve(:,:,1),3);    %sort supply by price
baseSupply = [SupplyCurve_0 cumsum(SupplyCurve_0(:,2))]; %add a column for cumulative supply
for i=1:length(baseSupply)
    if (baseSupply(i,4)>=baseQ)
        P = baseSupply(i,3);
        break;
    end
end
rich_a = P*(baseQ)^(1/el);

%%
%Output the key to control window and diary
fprintf('**************PARAMETERS USED********************\n');
fprintf('****BASIC SETUP***\n');
MODE_MKT_CLEAR_AFTER_ALL_DECIDE
MODE_END_PERIOD_VALUE
SUPPLYCURVE_MODE
fprintf('The order of firms making decisions is:  ');
disp(orderOfFirms(1:numFirms));
disp(T);
disp(decisions_in_dt);
fprintf('Number of years in simulation: %d\n', ceil(T/decisions_in_dt));

fprintf('****DEMAND SETUP***\n');
el
D_0
D_growth
Demand
D_fluct
D_prob
DPERM_change
fprintf('Where base demand and supply should meet: %d\n', baseQ);
rich_a

fprintf('****SUPPLY SETUP***\n');
SupplyCurve(:,:,1)
fprintf('Supply curve is constant over time\n');

fprintf('****INCENTIVE CURVE***\n');
TotalIncentiveCurve


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%SOLVING FOR THE OPTIMAL POLICY USING FIRM NPV + GAME THEORY DECISION
%%CRITERIA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%value for terminal period
%MAYBETODO: terminal state do not need to be everything shut down
Va(:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Vb(:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Vc(:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Xa(:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Xb(:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Xc(:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;

%Solve for the best
for t=T:-1:1
%    fprintf('period is %d , total time %d\n', t, T);
    %for each combination of mines already opened
    for A1=1:2
    for A2=1:2
    for A3=1:2
    for B1=1:2
    for B2=1:2
    for B3=1:2
    for C1=1:2
    for C2=1:2
    for C3=1:2
        MinesOpened = [A1, A2, A3, B1, B2, B3, C1, C2, C3];
    for DPERM = 1:5
    %identify of the player who is currently making an expansion decision
    for currentFirm=1:numFirms
        %right now, have a deterministic sequence of firms who are deciding
        %if not this firm's turn, don't do the rest
        %MIGHT TODO: if order if not fixed, might need to calculate the
        %reward and store it even when a firm doesn't decide on a turn (right now the correct V is not
        %stored when a firm doesn't decide in a turn)
        if(currentFirm ~= orderOfFirms(t))
            continue;
        end

        %fill the value matrix with the default action that no
        %one is opening anything
        bestVa = 0;
        bestVb = 0;
        bestVc = 0;
        bestXa = 0;
        bestXb = 0;
        bestXc = 0;
        bestP = 0;
        bestQ = 0;
        bestCapUtil=0;

        %loop through the possible actions of the firm who can act
        if (currentFirm==1)
            b=0;
            c=0;
            for a=0:numIncMines     %Problem assumes that a firm can only open 1 mine per period
                %skip this loop if a is not feasible
                %given the states
                if(a==1 && A1==2)
                    continue;  %DEBUG: SHOULD THIS BE CONTINUE?
                elseif(a==2 && A2==2)
                    continue;
                elseif(a==3 && A3==2)
                    continue;
                end
                %calculate the relevant outcome for A given this action
                %TODO: could incorporate delay in opening (currently no
                %delay)
                MinesOpened_updated = MinesOpened + [(a==1),(a==2),(a==3),0,0,0,0,0,0];
                
                if(or(MODE_MKT_CLEAR_AFTER_ALL_DECIDE == 0, mod(t,decisions_in_dt)==0)) 
                    %market clearing and reward calculation 
                    [market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);
                    %return   %DEBUG this break is just to run the findPrice function once
                    %display('As turn - prices');

                    %record the total number of times the intersection hit the
                    %face of a supply step cliff for a given set of state vars
                    Faces(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = sum(faces) + Faces(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t);

                    %Calculate this period expected reward for A
                    rewardA = sum(rewards(1,:).*D_prob);
                    if(a~=0)
                        rewardA = rewardA - IncentiveCurveA(a,4);
                    end
                    rewardB = sum(rewards(2,:).*D_prob);
                    rewardC = sum(rewards(3,:).*D_prob);
                
                    %calculate next mine opening states after the new mine
                    %opening this period (if any)
                    nextS = [A1+(a==1),A2+(a==2),A3+(a==3),B1+(b==1),B2+(b==2),B3+(b==3),C1+(c==1),C2+(c==2),C3+(c==3)]; %next state of openings
                    %Calculate expected future periods rewards (using state transitions) for each of the players  
                    v_a = zeros(1,length(D_prob));
                    v_b = zeros(1,length(D_prob));
                    v_c = zeros(1,length(D_prob));
                    for d = 1:length(D_prob)
                        [nextDPerm] = demandPermChange(DPERM, market_p(d));
                        v_a(d) = D_prob(d)*Va(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                        v_b(d) = D_prob(d)*Vb(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                        v_c(d) = D_prob(d)*Vc(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                    end
                
                    totalVa = rewardA + (1-dr)*sum(v_a);
                    totalVb = rewardB + (1-dr)*sum(v_b);
                    totalVc = rewardC + (1-dr)*sum(v_c);

                else %for intermediate periods where market doesn't clear
                    %figure out where you would go next
                    nextS = [A1+(a==1),A2+(a==2),A3+(a==3),B1+(b==1),B2+(b==2),B3+(b==3),C1+(c==1),C2+(c==2),C3+(c==3)]; %next state of openings
                    nextDPerm = DPERM;
                    
                    %adjust for any capex incurred by the decision to open
                    capex = 0;
                    if(a~=0)
                        capex = IncentiveCurveA(a,4);
                    end
              
                    totalVa = Va(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1)-capex;
                    totalVb = Vb(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                    totalVc = Vc(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                end 

                    %If it is the best V so far, replace the current best V
                    %TODO: what if they tie?
                    if(totalVa>bestVa)
                        bestVa = totalVa;
                        bestVb = totalVb;
                        bestVc = totalVc;
                        bestXa = a;
                        bestXb = b;
                        bestXc = c;
                        if(or(MODE_MKT_CLEAR_AFTER_ALL_DECIDE == 0, mod(t,decisions_in_dt)==0)) 
                            bestP = sum(D_prob.*market_p);
                            bestQ = sum(D_prob.*market_q);
                            bestCapUtil = sum(D_prob.*cap_util);
                        end
                    end
            end            

        elseif(currentFirm==2)
            a=0;
            c=0;
            for b=0:numIncMines
                %skip this loop if b is not feasible
                %given the states
                if(b==1 && B1==2)
                    continue;
                elseif(b==2 && B2==2)
                    continue;
                elseif(b==3 && B3==2)
                    continue;
                end
                if(or(MODE_MKT_CLEAR_AFTER_ALL_DECIDE == 0, mod(t,decisions_in_dt)==0)) 
                    %calculate the relevant outcome for A given this action
                    MinesOpened_updated = MinesOpened + [0,0,0,(b==1),(b==2),(b==3),0,0,0];
                    [market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);
                    %display('Bs turn - prices');
                    %display(market_p);
                    %Calculate this period expected reward for A
                    rewardA = sum(rewards(1,:).*D_prob);
                    rewardB = sum(rewards(2,:).*D_prob);
                    if(b~=0)
                        rewardB = rewardB - IncentiveCurveB(b,4);
                    end
                    rewardC = sum(rewards(3,:).*D_prob);
                    %calculate next mine opening states after the new mine
                    %opening this period (if any)
                    nextS = [A1+(a==1),A2+(a==2),A3+(a==3),B1+(b==1),B2+(b==2),B3+(b==3),C1+(c==1),C2+(c==2),C3+(c==3)]; %next state of openings
                    %Calculate expected future periods rewards (using state transitions) for each of the players  
                    v_a = zeros(1,length(D_prob));
                    v_b = zeros(1,length(D_prob));
                    v_c = zeros(1,length(D_prob));
                    for d = 1:length(D_prob)
                        [nextDPerm] = demandPermChange(DPERM, market_p(d));
                        v_a(d) = D_prob(d)*Va(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                        v_b(d) = D_prob(d)*Vb(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                        v_c(d) = D_prob(d)*Vc(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                    end

                    totalVa = rewardA + (1-dr)*sum(v_a);
                    totalVb = rewardB + (1-dr)*sum(v_b);
                    totalVc = rewardC + (1-dr)*sum(v_c);

                    %record the total number of times the intersection hit the
                    %face of a supply step cliff for a given set of state vars
                    Faces(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = sum(faces) + Faces(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t);
                else %for intermediate periods where market doesn't clear
                    %figure out where you would go next
                    nextS = [A1+(a==1),A2+(a==2),A3+(a==3),B1+(b==1),B2+(b==2),B3+(b==3),C1+(c==1),C2+(c==2),C3+(c==3)]; %next state of openings
                    nextDPerm = DPERM;

                    %adjust for any capex incurred by the decision to open
                    capex = 0;
                    if(b~=0)
                        capex = IncentiveCurveB(b,4);
                    end
                    totalVa = Va(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                    totalVb = Vb(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1)-capex;
                    totalVc = Vc(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                end
                
                %If it is the best V so far, replace the current best V
                %TODO: what if they tie?
                if(totalVb>bestVb)
                    bestVa = totalVa;
                    bestVb = totalVb;
                    bestVc = totalVc;
                    bestXa = a;
                    bestXb = b;
                    bestXc = c;
                    if(or(MODE_MKT_CLEAR_AFTER_ALL_DECIDE == 0, mod(t,decisions_in_dt)==0)) 
                        bestP = sum(D_prob.*market_p);
                        bestQ = sum(D_prob.*market_q);
                        bestCapUtil = sum(D_prob.*cap_util);                    
                    end
                end
                
            end
            
        elseif(currentFirm==3)
            a=0;
            b=0;
            for c=0:numIncMines
                %skip this loop if c is not feasible
                %given the states
                if(c==1 && C1==2)
                    continue;
                elseif(c==2 && C2==2)
                    continue;
                elseif(c==3 && C3==2)
                    continue;
                end
                if(or(MODE_MKT_CLEAR_AFTER_ALL_DECIDE == 0, mod(t,decisions_in_dt)==0)) 
                    %calculate the relevant outcome for A given this action
                    MinesOpened_updated = MinesOpened + [0,0,0,0,0,0,(c==1),(c==2),(c==3)];
                    [market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);
                    %display('Cs turn - prices');
                    %display(market_p);
                    %Calculate this period expected reward for A
                    rewardA = sum(rewards(1,:).*D_prob);
                    rewardB = sum(rewards(2,:).*D_prob);
                    rewardC = sum(rewards(3,:).*D_prob);
                    if(c~=0)
                        rewardC = rewardC - IncentiveCurveC(c,4);
                    end
                    %calculate next mine opening states after the new mine
                    %opening this period (if any)
                    nextS = MinesOpened_updated; %next state of openings
                    %Calculate expected future periods rewards (using state transitions) for each of the players  
                    v_a = zeros(1,length(D_prob));
                    v_b = zeros(1,length(D_prob));
                    v_c = zeros(1,length(D_prob));
                    for d = 1:length(D_prob)
                        [nextDPerm] = demandPermChange(DPERM, market_p(d));
    %                     fprintf('nextDPerm=%d\n',nextDPerm);
    %                     disp(MinesOpened)
    %                     disp(nextS);
                        v_a(d) = D_prob(d)*Va(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                        v_b(d) = D_prob(d)*Vb(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                        v_c(d) = D_prob(d)*Vc(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                    end

                    totalVa = rewardA + (1-dr)*sum(v_a);
                    totalVb = rewardB + (1-dr)*sum(v_b);
                    totalVc = rewardC + (1-dr)*sum(v_c);

                    %record the total number of times the intersection hit the
                    %face of a supply step cliff for a given set of state vars
                    Faces(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = sum(faces) + Faces(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t);

                else %for intermediate periods where market doesn't clear
                    %figure out where you would go next
                    nextS = [A1+(a==1),A2+(a==2),A3+(a==3),B1+(b==1),B2+(b==2),B3+(b==3),C1+(c==1),C2+(c==2),C3+(c==3)]; %next state of openings
                    nextDPerm = DPERM;

                    %adjust for any capex incurred by the decision to open
                    capex = 0;
                    if(c~=0)
                        capex = IncentiveCurveC(c,4);
                    end
                    totalVa = Va(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                    totalVb = Vb(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1);
                    totalVc = Vc(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,t+1)-capex;
                end
                
                %If it is the best V so far, replace the current best V
                %TODO: what if they tie?
                if(totalVc>bestVc)
                    bestVa = totalVa;
                    bestVb = totalVb;
                    bestVc = totalVc;
                    bestXa = a;
                    bestXb = b;
                    bestXc = c;
                    if(or(MODE_MKT_CLEAR_AFTER_ALL_DECIDE == 0, mod(t,decisions_in_dt)==0)) 
                        bestP = sum(D_prob.*market_p);
                        bestQ = sum(D_prob.*market_q);
                        bestCapUtil = sum(D_prob.*cap_util);                    
                    end                    
                end
                
            end
            
        end
        
        %Store the best actions and values etc
        Va(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = bestVa;
        Vb(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = bestVb;
        Vc(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = bestVc;
        Xa(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = bestXa;
        Xb(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = bestXb;
        Xc(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = bestXc;
        
        if(or(MODE_MKT_CLEAR_AFTER_ALL_DECIDE == 0, mod(t,decisions_in_dt)==0)) 
            Prices(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = bestP;
            Quantities(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = bestQ;
            CapUtils(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = bestCapUtil;
%         fprintf('period %d price is %.2f, q is %d, demand is %d\n',t, bestP,bestQ,Demand(t));
        end
    end        
    end    
    end
    end
    end
    end
    end
    end
    end
    end
    end
    
    
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%CALC OPTIMAL POLICY FOR MAXING FIRM NPV, NO GAME THEORY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%
%parameters of the simulations
simNum = 1;   %number of simulation
sim_dr = dr;
sim_orderOfFirms = orderOfFirms;

%demand fluctuation range and prob
sim_D_fluct = D_fluct;
sim_D_prob = D_prob;
sim_Demand = Demand;

%the change associated with a state variable on whether demand has been permanently changed due to a
%high demand/low demand event (demand never fully recovers from large
%swings because of semi-permanent substitution (DPERM)
sim_DPERM_change = DPERM_change; % +10% change in non-shocked demand if DPERM is 1, and 20% if it's 2. 


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%SIMULATION OF THE FIRM NPV BASED POLICIES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Simulate the game with the demand uncertainty. See how the price path
% unfolds using the optimal policy. Compare against a dummy policy and
% compare. 

%dummy base policy of not opening no matter what the conditions are
Xa_1 = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1);
Xb_1 = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1);
Xc_1 = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1);

%"smarter" policy to test
Xa_2 = Xa;
Xb_2 = Xb;
Xc_2 = Xc;


%output to be recorded
sim_Prices_1 = zeros(T_years, simNum);
sim_Q_1 = zeros(T_years, simNum);
sim_CapUtil_1 = zeros(T_years, simNum);
sim_Faces_1 = zeros(T_years, simNum); %when it crossed the cliff face of supply curve
sim_V_1 = zeros(numFirms, simNum);
sim_openings_1 = zeros(numIncMines, numFirms, simNum);
sim_diag_1 = cell(T_years,simNum);    %cell array to store the diagnostics from each market clearing
sim_firm_Q_1 = zeros(numFirms, T_years, simNum);

sim_Prices_2 = zeros(T_years, simNum);
sim_Q_2 = zeros(T_years, simNum);
sim_CapUtil_2 = zeros(T_years, simNum);
sim_Faces_2 = zeros(T_years, simNum);
sim_V_2 = zeros(numFirms, simNum);
%record the time period each mine opened (if they did at all)
sim_openings_2 = zeros(numIncMines, numFirms, simNum);
sim_diag_2 = cell(T_years,simNum);    %cell array to store the diagnostics from each market clearing
sim_firm_Q_2 = zeros(numFirms, T_years, simNum);

%name of the diagnostic entries
sim_diag_names = cell(1,1);

%simulate for policy 1 and policy 2
[sim_openings_1, sim_Prices_1, sim_Q_1, sim_firm_Q_1, sim_V_1, sim_Vt_1, sim_CapUtil_1, sim_Faces_1, sim_diag_1, sim_diag_names] ...
    = simulation(Xa_1, Xb_1, Xc_1, simNum, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change,...
    IncentiveCurveA, IncentiveCurveB, IncentiveCurveC, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve);

[sim_openings_2, sim_Prices_2, sim_Q_2, sim_firm_Q_2, sim_V_2, sim_Vt_2, sim_CapUtil_2, sim_Faces_2, sim_diag_2, sim_diag_names] ...
    = simulation(Xa_2, Xb_2, Xc_2, simNum, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change,...
    IncentiveCurveA, IncentiveCurveB, IncentiveCurveC, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve);

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%POSITIVE MINE NPV CRITERIA OPTIMAL DECISION CALC AND SIMULATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%parameters of the simulations
simNum3 = 1; 

[sim_openings_3, sim_Prices_3, sim_Q_3, sim_firm_Q_3, sim_V_3, sim_Vt_3, sim_CapUtil_3, sim_Faces_3, sim_diag_3] = ...
    mine_NPV_DPandSim(simNum3, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change, ...
    T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, TotalIncCurve_byFirm);


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%SIMULATION: What happens if one or more firms use firm-NPV maximizing
%%strategy, but against competitors who use the mine NPV maximizing
%%paradigm? 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%PLOTTING OF THE RESULTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%Plots for comparison the price, quantity and NPV outcomes under policy 1 and 2
%FIGURE 1 compare the price
colormap(lines(10)); 
fig = figure(1);
clf('reset');
set(fig, 'units','normalized','position',[0.1 0.1 0.5 0.4]); 
time = 1:T_years;
plot(time, sim_Prices_1, time, sim_Prices_2, time, sim_Prices_3);
axis([min(time) 30 min(min([sim_Prices_1 sim_Prices_2 sim_Prices_3]))-5, max(max([sim_Prices_1 sim_Prices_2 sim_Prices_3]))+5])
fprintf('Price path of different policies, order(%s)\n', ordering);
sim_Prices_1
sim_Prices_2
sim_Prices_3

leg1 = legend('no new opening', 'best firm-NPV policy', 'positive-mine-NPV policy');
set(leg1, 'Box', 'off');
set(leg1, 'Color', 'none');


title(['Price Path (' ordering ')']);
xlabel('Year');
ylabel('Real price');

saveas(fig, [ordering '_price path.jpg']); 

%FIGURE 2 compare the market quantity over time
fig = figure(2);
clf('reset');
set(fig, 'units','normalized','position',[0.1 0.1 0.5 0.4]); 

plot(time, sim_Q_1, time, sim_Q_2, time, sim_Q_3, time, Demand_yr');
axis([min(time) 30 min(min([sim_Q_1 sim_Q_2 sim_Q_3 Demand_yr']))-50, max(max([sim_Q_1 sim_Q_2 sim_Q_3 Demand_yr']))+50])

fprintf('Quantity path of different policies: dummy, firm_NPV with game, postive mine NPV\n');
sim_Q_1
sim_Q_2
sim_Q_3

leg1 = legend('no new opening', 'best firm-NPV policy', 'positive-mine-NPV policy', 'Underlying demand');
set(leg1, 'Box', 'off');
set(leg1, 'Color', 'none');


title(['Market Clearing Quantity (' ordering ')']);
xlabel('Year');
ylabel('Quantity');
saveas(fig, [ordering '_production path.jpg']); 


%%
%plot the new mine openings

%get the new mine opening data into shape

sim_open_1 = zeros(T_years, 3, numFirms); 
sim_open_2 = zeros(T_years, 3, numFirms); 
sim_open_3 = zeros(T_years, 3, numFirms); 

for(c=1:numFirms)
    currentIncCurve = TotalIncCurve_byFirm{c};
    for(r=1:numIncMines)
        t = sim_openings_1(r,c);
        if(t~=0)
            sim_open_1(t,1,c) = currentIncCurve(r,2); %production
            sim_open_1(t,2,c) = currentIncCurve(r,3); %opex
            sim_open_1(t,3,c) = currentIncCurve(r,4); %capex
        end
        
        t = sim_openings_2(r,c);
        if(t~=0)
            sim_open_2(t,1,c) = currentIncCurve(r,2); %production
            sim_open_2(t,2,c) = currentIncCurve(r,3); %opex
            sim_open_2(t,3,c) = currentIncCurve(r,4); %capex
        end
        
        t = sim_openings_3(r,c);
        if(t~=0)
            sim_open_3(t,1,c) = currentIncCurve(r,2); %production
            sim_open_3(t,2,c) = currentIncCurve(r,3); %opex
            sim_open_3(t,3,c) = currentIncCurve(r,4); %capex
        end
    end
end


%plot the new openings
fig = figure(3);
% clf('reset');
set(fig, 'units','normalized','position',[0.1 0.1 0.5 0.8]); 
colormap(lines(10));

subplot(3,1,1)
h = bar(time, squeeze(sim_open_1(:,1,:)), 'stacked', 'EdgeColor','none'); 
set(gca, 'YLim',[0 max(TotalIncentiveCurve(:,2))*2])
l = cell(1,3); 
l{1} = 'Firm A'; l{2} = 'Firm B'; l{3} = 'Firm C'; 
legend(h, l);
title('No new opening');
ylabel('Capacity');

subplot(3,1,2)
bar(time, squeeze(sim_open_2(:,1,:)), 'stacked', 'EdgeColor','none');
set(gca, 'YLim',[0 max(TotalIncentiveCurve(:,2))*2])
y = squeeze(sim_open_2(:,2,:)); 
y_positions = squeeze(sim_open_2(:,1,:));
for(c=1:numFirms)
    ypos = sum(y_positions(:,1:c), 2);
    for(r=1:T_years)
        if(y(r,c)~=0)
            text(time(r),ypos(r),['\fontsize{9}\color{white}' num2str(y(r,c),'%0.0f')],...
            'HorizontalAlignment','center',...
            'VerticalAlignment','top')
        end
    end
end
title('best firm-NPV policy');
ylabel('Capacity');

subplot(3,1,3)
bar(time, squeeze(sim_open_3(:,1,:)), 'stacked', 'EdgeColor','none'); 
set(gca, 'YLim',[0 max(TotalIncentiveCurve(:,2))*2])
y = squeeze(sim_open_3(:,2,:)); 
y_positions = squeeze(sim_open_3(:,1,:));
for(c=1:numFirms)
    ypos = sum(y_positions(:,1:c), 2);
    ypos
    for(r=1:T_years)
        if(y(r,c)~=0)
            text(time(r),ypos(r),['\fontsize{9}\color{white}' num2str(y(r,c),'%0.0f')],...
            'HorizontalAlignment','center',...
            'VerticalAlignment','top')
        end
    end
end
title('positive-mine-NPV policy');
ylabel('Capacity');
xlabel('Year');


annotation('textbox', [0 0.9 1 0.1], ...
'String', ['New Mine Openings, with opex as label (' ordering ')'], ...
'EdgeColor', 'none', ...
'HorizontalAlignment', 'center')

saveas(fig, [ordering '_new mines openings.jpg']); 

%display summary of new openings over time
display('policy 1 openings (row = mine #, column = firm #)');
sim_openings_1
display('policy 2 openings (row = mine #, column = firm #)');
sim_openings_2
display('policy 3 openings (row = mine #, column = firm #)');
sim_openings_3


%compare the value (NPV) of the firms in the two scenarios
fig = figure(4);
clf('reset');
colormap(lines(10));
h = bar([sim_V_1 sim_V_2 sim_V_3], 'group', 'EdgeColor','none');
set(gca, 'YLim',[0 max(max([sim_V_1 sim_V_2 sim_V_3]))+10^4])
leg1 = legend('no new opening', 'best firm-NPV policy', 'positive-mine-NPV policy', 'Underlying demand');
set(leg1, 'Box', 'off');
set(leg1, 'Color', 'none');
set(gca, 'XTick', 1:numFirms, 'XTickLabel', {'Firm A', 'Firm B', 'Firm C'}); 
title(['NPV Comparison (' ordering ')']);
ylabel('NPV');
saveas(fig, [ordering '_NPV comparison.jpg']); 

%display NPV of the different players under diff scenarios
fprintf('Total NPV of the three players under base policy is %d \n', sum(sim_V_1));
sim_V_1
fprintf('Total NPV of the three players under the firm-optimal policy is %d \n', sum(sim_V_2));
sim_V_2
fprintf('Total NPV of the three players under mine-optimal policy is %d \n', sum(sim_V_3));
sim_V_3


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%DEMONSTRATION THAT THE GAME THEORY OPTIMAL POLICY IS INDEED NASH
%%EQUILIBRIUM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%1. when the other firms adopt other policies, they won't have better
%payoff
%simulate settings
numOtherPolicies = 20;   %number of simulation
sim_dr = dr;
sim_orderOfFirms = orderOfFirms;

%demand fluctuation range and prob
sim_D_fluct = D_fluct;
sim_D_prob = D_prob;
sim_Demand = Demand;

%the change associated with a state variable on whether demand has been permanently changed due to a
%high demand/low demand event (demand never fully recovers from large
%swings because of semi-permanent substitution (DPERM)
sim_DPERM_change = DPERM_change; % +10% change in non-shocked demand if DPERM is 1, and 20% if it's 2. 

%simulate a number of random policies for each firm in turn to see if they
%can get a better value by diverging from the optimal policy
firmNames = ['A' 'B' 'C' 'D'];
for varywho = 1:numFirms
    [sim_openings_4, sim_Prices_4, sim_Q_4, sim_firm_Q_4, sim_V_4, sim_Vt_4, sim_CapUtil_4, sim_Faces_4, sim_diag_4] ...
        = sim_variations(varywho, Xa_2, Xb_2, Xc_2, numOtherPolicies, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change,...
        IncentiveCurveA, IncentiveCurveB, IncentiveCurveC, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve);
    sim_openings_4;

    %Graph the different NPV 
    %overall NPV bar graph
    fig = figure(4+varywho);
    clf('reset');
    %graph for A
    subplot(3,1,1);
    width1 = 0.5;
    bar(1, sim_V_2(1), width1, 'FaceColor',[0.2,0.2,0.5],....
                         'EdgeColor','none');
    hold on
    width2 = width1/2;
    bar(2:numOtherPolicies+1, sim_V_4(1,:), width2,'FaceColor',[0,0.7,0.7],...
                         'EdgeColor',[0,0.7,0.7]);
    %legend('Optimal Policy for A', 'Other Policies for A');
    title('NPV Comparison for A');
    ylabel('NPV');
    hold off

    %graph for B
    subplot(3,1,2);
    width1 = 0.5;
    bar(1, sim_V_2(2), width1, 'FaceColor',[0.2,0.2,0.5],....
                         'EdgeColor','none');
    hold on
    width2 = width1/2;
    bar(2:numOtherPolicies+1, sim_V_4(2,:), width2,'FaceColor',[0,0.7,0.7],...
                         'EdgeColor',[0,0.7,0.7]);
    %legend('Optimal Policy for A', 'Other Policies for A');
    title('NPV Comparison for B');
    ylabel('NPV');
    hold off

    %graph for C
    subplot(3,1,3);
    width1 = 0.5;
    bar(1, sim_V_2(3), width1, 'FaceColor',[0.2,0.2,0.5],....
                         'EdgeColor','none');
    hold on
    width2 = width1/2;
    bar(2:numOtherPolicies+1, sim_V_4(3,:), width2,'FaceColor',[0,0.7,0.7],...
                         'EdgeColor',[0,0.7,0.7]);
    %legend('Optimal Policy for A', 'Other Policies for A');
    title('NPV Comparison for C');
    ylabel('NPV');
    hold off

    annotation('textbox', [0 0.9 1 0.1], ...
    'String', sprintf( 'NPV Variations %s (%s)', firmNames(varywho), ordering), ...
    'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center')
    
    saveas(fig,  sprintf( '%s_NPV_variations %s.jpg', ordering, firmNames(varywho)) ); 
end

%%
%Report the recorded performance diagnostic profile
profile report
diary off