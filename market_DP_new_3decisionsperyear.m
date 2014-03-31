% Exact DP solution and simulation to a 3-player game in the mineral market
% Yuanjian Carla Li, January 31, 2014

%record the profile for performance enhancement
profile on %-detail builtin -history
diary('output_log_11.18');
diary on;

%%initialize variables
rng(1); %set seed for random number
dr = 0.1;
numFirms = 3; %number of firms
numIncMines = 3; %number of incentive mines per firm

%DIFFERENT MODES FOR THE PROGRAM
%SUPPLYCURVE_MODE controls which supply curve is used. 0 is for the scrambled Rio
%Tinto one. 1 is for the real Rio Tinto one. -1 is for the real Rio Tinto one except the 
%capex is reduced 10x so that shorter time horizon can still yield mine opening.
% -2 is for the dummy one for testing purpose. 
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
orderOfFirms = repmat([1 2 3],1,ceil((T+1)/numFirms));  %HARDCODE ALERT
orderOfFirms = orderOfFirms(1:T+1);

%there are 3 incentive mines per player, 3 players,  a variable that
%indicates which player is making decision in a period, and 5 levels of
%permanent demand change
%For the value vector for each state-action pair, the numIncMines+1 dimension 
% refers to whcih action is taken. Since the action could be to open none 
% of the mines or any of the incentive mines, the length of the dimension 
% is numIncMines+1
%TODO: implement the state-action pair value saving and the ability for the
% optimal policy matrices to accomodate more than 1 optimal actions for a
% state
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

%%Demand settings
%demand elasticity
el = 1; 
%demand level and growth
%D_0 = 1100;   %base demand
D_0 = 1300;   %base demand
D_growth = 0.01;   %demand growth rate

%populate the demand series 
Demand = ones(1,T)*D_0;
for t=2:T
    if(or(decisions_in_dt==1, mod(t,decisions_in_dt)==1))
        Demand(t) = Demand(t-1)*(1+D_growth);
    else
        Demand(t) = Demand(t-1);
    end
end 

%demand fluctuation range and prob
D_fluct = 0.9;  %TODO: THIS CANNOT BE ZERO AT THE MOMENT. NEED TO SAFETY CHECK
D_prob = [0,1,0];

%the change associated with a state variable on whether demand has been permanently changed due to a
%high demand/low demand event (demand never fully recovers from large
%swings because of semi-permanent substitution (DPERM)
DPERM_change = 0.05; % +5% change in non-shocked demand if DPERM is 1, and 10% if it's 2. 


%%Supply curve - assume it doesn't change over time
% structure is owner, quantity, cost
SupplyCurve = zeros(94,3,T);
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
highcostQ = repmat([4 2 245], 50,1);
SupplyCurve(45:94,:,1) = highcostQ;
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

%Settings for new mines. The columns are ownerID, capacity, opex, and
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
    
elseif(SUPPLYCURVE_MODE==1)
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

%%CALCULATE OPTIMAL POLICY FOR POSITIVE MINE NPV DECISION CRITERIA
%%CODE GOES HERE



%%SIMULATION
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

%simulate settings
simNum = 1;   %number of simulation
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

%Plots for comparison the price, quantity and NPV outcomes under policy 1 and 2
%compare the price
fig = figure(1);
time = 1:T_years;
plot(time, sim_Prices_1, time, sim_Prices_2);
axis([min(time) max(time) min(min(sim_Prices_1),min(sim_Prices_2))-5, max(max(sim_Prices_1),max(sim_Prices_2))+5])
fprintf('Price path of base vs best policy\n');
sim_Prices_1
sim_Prices_2

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
axis([min(time) max(time) min(min(sim_Q_1),min(sim_Q_2))-50, max(max(sim_Q_1),max(sim_Q_2))+50])

fprintf('Quantity path of base vs best policy\n');
sim_Q_1
sim_Q_2

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
fprintf('Total NPV of the three players under base policy is %d \n', sum(sim_V_1));
sim_V_1
fprintf('Total NPV of the three players under optimal policy is %d \n', sum(sim_V_2));
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
legend('Base Policy', 'Best Policy');
title('NPV Comparison');
xlabel('Firm');
ylabel('NPV');
hold off
saveas(fig, 'NPV comparison.jpg'); 


%%DEMONSTRATION THAT THE POLICY IS OPTIMAL
%1. when the other firms adopt other policies, they won't have better
%payoff
%simulate settings
numOtherPolicies = 20;   %number of simulation
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

%simulate a number of random policies for each firm in turn to see if they
%can get a better value by diverging from the optimal policy
firmNames = ['A' 'B' 'C' 'D'];
for varywho = 1:numFirms
    [sim_openings_1, sim_Prices_1, sim_Q_1, sim_firm_Q_1, sim_V_1, sim_Vt_1, sim_CapUtil_1, sim_Faces_1, sim_diag_1] ...
        = sim_variations(varywho, Xa_2, Xb_2, Xc_2, numOtherPolicies, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change,...
        IncentiveCurveA, IncentiveCurveB, IncentiveCurveC, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve);
    sim_openings_1;

    %Graph the different NPV 
    %overall NPV bar graph
    fig = figure(3+varywho);

    %graph for A
    subplot(3,1,1);
    width1 = 0.5;
    bar(1, sim_V_2(1), width1, 'FaceColor',[0.2,0.2,0.5],....
                         'EdgeColor','none');
    hold on
    width2 = width1/2;
    bar(2:numOtherPolicies+1, sim_V_1(1,:), width2,'FaceColor',[0,0.7,0.7],...
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
    bar(2:numOtherPolicies+1, sim_V_1(2,:), width2,'FaceColor',[0,0.7,0.7],...
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
    bar(2:numOtherPolicies+1, sim_V_1(3,:), width2,'FaceColor',[0,0.7,0.7],...
                         'EdgeColor',[0,0.7,0.7]);
    %legend('Optimal Policy for A', 'Other Policies for A');
    title('NPV Comparison for C');
    ylabel('NPV');
    hold off

    annotation('textbox', [0 0.9 1 0.1], ...
    'String', sprintf( 'NPV Variations %s', firmNames(varywho)), ...
    'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center')
    
    saveas(fig,  sprintf( 'NPV_variations %s.jpg', firmNames(varywho)) ); 
end


%Report the recorded performance diagnostic profile
profile report
diary off