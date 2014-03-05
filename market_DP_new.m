% Exact DP solution and simulation to a 3-player game in the mineral market
% Yuanjian Carla Li, January 31, 2014


%%initialize variables
dr = 0.1;
T = 9; 
numFirms = 3; %number of firms
numIncMines = 3; %number of incentive mines per firm
%specify the order that the firms will make decision in. 2 in period t
%indicates that firm 2 will make a decision in t=2
orderOfFirms = repmat([1:numFirms],1,ceil((T+1)/numFirms)); 
orderOfFirms = orderOfFirms(1:T+1);
%the number of dimensions is the number of state variables + 1
%the length of each dimension is the number of states available to a state
%variable
%there are 3 incentive mines per player, 3 players,  a variable that
%indicates which player is making decision in a period, and 5 levels of
%permanent demand change
Va = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1);
Vb = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1);
Vc = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,T+1);
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
D_0 = 1600;   %base demand

D_growth = 0;   %demand growth rate
%populate the demand series 
Demand = ones(1,T)*D_0;
for i=2:T
    Demand(i) = round(Demand(i-1)*(1+D_growth));
end 

%demand fluctuation range and prob
D_fluct = 0.9;  %TODO: THIS CANNOT BE ZERO AT THE MOMENT. NEED TO SAFETY CHECK
D_prob = [0,1,0];

%the change associated with a state variable on whether demand has been permanently changed due to a
%high demand/low demand event (demand never fully recovers from large
%swings because of semi-permanent substitution (DPERM)
DPERM_change = 0.1; % +10% change in non-shocked demand if DPERM is 1, and 20% if it's 2. 


% %%Supply curve - assume it doesn't change over time
% % structure is owner, quantity, cost
% SupplyCurve = zeros(94,3,T);
% SupplyCurve(1:44,:,1) = [1	289	49
%             1	12	65
%             1	5	86
%             2	74	39
%             2	40	46
%             2	42	47
%             2	24	48
%             2	25	49
%             3	46	40
%             3	2	40
%             3	50	42
%             3	9	43
%             3	3	44
%             3	102	46
%             3	24	47
%             3	5	54
%             3	4	55
%             3	2	66
%             3	6	76
%             3	21	76
%             3	9	96
%             4	0	5
%             4	16	15
%             4	9	25
%             4	15	35
%             4	49	45
%             4	169	55
%             4	209	65
%             4	150	75
%             4	95	85
%             4	72	95
%             4	70	105
%             4	48	115
%             4	15	125
%             4	22	135
%             4	27	145
%             4	4	155
%             4	4	165
%             4	2	175
%             4	1	185
%             4	3	195
%             4	3	205
%             4	3	225
%             4	10	245];  
% %inflate highest price Q to never run out of supply
% highcostQ = repmat([4 2 245], 50,1);
% SupplyCurve(45:94,:,1) = highcostQ;
% SupplyCurve(:,:,1) = sortrows(SupplyCurve(:,:,1),3);

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

%%Settings for new mines. The columns are ownerID, capacity, opex, and
%%capex respectively

% IncentiveCurveA = [1	70	43	560
%                     1	50	47	1025
%                     1	50	49	1042];
% 
% IncentiveCurveB = [2	50	52	963
%                     2	110	57	2821
%                     2	55	49	1075];
% 
% IncentiveCurveC = [3	90	54	1670
%                     3	45	54	544
%                     3	45	67	1135];

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

                
%Put all the incentive curves together into master incentive curve                
TotalIncentiveCurve = [IncentiveCurveA(1:numIncMines, :); 
                        IncentiveCurveB(1:numIncMines, :);
                        IncentiveCurveC(1:numIncMines, :)];

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
                [market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);
                %return   %DEBUG this break is just to run the findPrice function once
                %display('As turn - prices');
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
                
                %record the total number of times the intersection hit the
                %face of a supply step cliff for a given set of state vars
                Faces(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t) = sum(faces) + Faces(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,t);
                
                %If it is the best V so far, replace the current best V
                %TODO: what if they tie?
                if(totalVa>bestVa)
                    bestVa = totalVa;
                    bestVb = totalVb;
                    bestVc = totalVc;
                    bestXa = a;
                    bestXb = b;
                    bestXc = c;
                    bestP = sum(D_prob.*market_p);
                    bestQ = sum(D_prob.*market_q);
                    bestCapUtil = sum(D_prob.*cap_util);
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

                %If it is the best V so far, replace the current best V
                %TODO: what if they tie?
                if(totalVb>bestVb)
                    bestVa = totalVa;
                    bestVb = totalVb;
                    bestVc = totalVc;
                    bestXa = a;
                    bestXb = b;
                    bestXc = c;
                    bestP = sum(D_prob.*market_p);
                    bestQ = sum(D_prob.*market_q);
                    bestCapUtil = sum(D_prob.*cap_util);                    
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

                %If it is the best V so far, replace the current best V
                %TODO: what if they tie?
                if(totalVc>bestVc)
                    bestVa = totalVa;
                    bestVb = totalVb;
                    bestVc = totalVc;
                    bestXa = a;
                    bestXb = b;
                    bestXc = c;
                    bestP = sum(D_prob.*market_p);
                    bestQ = sum(D_prob.*market_q);
                    bestCapUtil = sum(D_prob.*cap_util);                    
                    
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
sim_Prices_1 = zeros(T, simNum);
sim_Q_1 = zeros(T, simNum);
sim_CapUtil_1 = zeros(T, simNum);
sim_Faces_1 = zeros(T, simNum); %when it crossed the cliff face of supply curve
sim_V_1 = zeros(numFirms, simNum);
sim_openings_1 = zeros(numIncMines, numFirms, simNum);
sim_diag_1 = cell(T,simNum);    %cell array to store the diagnostics from each market clearing
sim_firm_Q_1 = zeros(numFirms, T, simNum);

cliffCount_2 = zeros(T, simNum); %when it crossed the cliff face of supply curve
sim_Prices_2 = zeros(T, simNum);
sim_Q_2 = zeros(T, simNum);
sim_CapUtil_2 = zeros(T, simNum);
sim_Faces_2 = zeros(T, simNum);
sim_V_2 = zeros(numFirms, simNum);
%record the time period each mine opened (if they did at all)
sim_openings_2 = zeros(numIncMines, numFirms, simNum);
sim_diag_2 = cell(T,simNum);    %cell array to store the diagnostics from each market clearing
sim_firm_Q_2 = zeros(numFirms, T, simNum);

%name of the diagnostic entries
sim_diag_names = cell(1,1);

for(sim=1:simNum)
    %initialize the state variables
    sim_m_1 = ones(1,numFirms*numIncMines);
    sim_m_2 = ones(1,numFirms*numIncMines);
    sim_dperm_1 = 3;
    sim_dperm_2 = 3;


    for(t=1:T)
        firm = sim_orderOfFirms(t);
        capex_1=zeros(1,numFirms);
        capex_2=zeros(1,numFirms);
        
        if(firm==1)
            a_1 = Xa_1(sim_m_1(1), sim_m_1(2), sim_m_1(3), sim_m_1(4), sim_m_1(5), sim_m_1(6), sim_m_1(7), sim_m_1(8), sim_m_1(9), firm, sim_dperm_1, t);
            a_2 = Xa_2(sim_m_2(1), sim_m_2(2), sim_m_2(3), sim_m_2(4), sim_m_2(5), sim_m_2(6), sim_m_2(7), sim_m_2(8), sim_m_2(9), firm, sim_dperm_2, t);
            
            sim_m_1 = sim_m_1 + [(a_1==1),(a_1==2),(a_1==3),0,0,0,0,0,0];
            sim_m_2 = sim_m_2 + [(a_2==1),(a_2==2),(a_2==3),0,0,0,0,0,0];
            
            %if there is a new opening, record it and add to capex
            if(a_1~=0)
                    capex_1(firm) = IncentiveCurveA(a_1,4);
                    sim_openings_1(a_1,firm, sim) = t;
            end
            
            if(a_2~=0)
                    capex_2(firm) = IncentiveCurveA(a_2,4);
                    sim_openings_2(a_2,firm, sim) = t;
            end

        elseif(firm==2)
            b_1 = Xb_1(sim_m_1(1), sim_m_1(2), sim_m_1(3), sim_m_1(4), sim_m_1(5), sim_m_1(6), sim_m_1(7), sim_m_1(8), sim_m_1(9), firm, sim_dperm_1, t);
            b_2 = Xb_2(sim_m_2(1), sim_m_2(2), sim_m_2(3), sim_m_2(4), sim_m_2(5), sim_m_2(6), sim_m_2(7), sim_m_2(8), sim_m_2(9), firm, sim_dperm_2, t);
            sim_m_1 = sim_m_1 + [0,0,0,(b_1==1),(b_1==2),(b_1==3),0,0,0];
            sim_m_2 = sim_m_2 + [0,0,0,(b_2==1),(b_2==2),(b_2==3),0,0,0];
            if(b_1~=0)
                    capex_1(firm) = IncentiveCurveB(b_1,4);
                    sim_openings_1(b_1,firm, sim) = t;
            end
            
            if(b_2~=0)
                    capex_2(firm) = IncentiveCurveB(b_2,4);
                    sim_openings_2(b_2,firm, sim) = t;
            end

        elseif(firm==3)
            c_1 = Xc_1(sim_m_1(1), sim_m_1(2), sim_m_1(3), sim_m_1(4), sim_m_1(5), sim_m_1(6), sim_m_1(7), sim_m_1(8), sim_m_1(9), firm, sim_dperm_1, t);
            c_2 = Xc_2(sim_m_2(1), sim_m_2(2), sim_m_2(3), sim_m_2(4), sim_m_2(5), sim_m_2(6), sim_m_2(7), sim_m_2(8), sim_m_2(9), firm, sim_dperm_2, t);
            sim_m_1 = sim_m_1 + [0,0,0,0,0,0,(c_1==1),(c_1==2),(c_1==3)];
            sim_m_2 = sim_m_2 + [0,0,0,0,0,0,(c_2==1),(c_2==2),(c_2==3)];
            if(c_1~=0)
                    capex_1(firm) = IncentiveCurveC(a_1,4);
                    sim_openings_1(c_1,firm, sim) = t;
            end
            
            if(c_2~=0)
                    capex_2(firm) = IncentiveCurveC(a_2,4);
                    sim_openings_2(a_2,firm, sim) = t;
            end

        end
        
        %simulate the demand perturbation
        D_index = randsample(length(sim_D_prob), 1, true, sim_D_prob);
        D_cases = sim_Demand(t).*[1/sim_D_fluct 1 sim_D_fluct];
        sim_demand = D_cases(D_index);
        [market_p_1, market_q_1, cap_util_1, rewards_1, faces_1, firms_q_1, diag_1] = findPrice_new(T, numFirms, t, sim_m_1, sim_dperm_1, sim_DPERM_change, el, sim_D_prob, sim_D_fluct, sim_demand, D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);
        [market_p_2, market_q_2, cap_util_2, rewards_2, faces_2, firms_q_2, diag_2] = findPrice_new(T, numFirms, t, sim_m_2, sim_dperm_2, sim_DPERM_change, el, sim_D_prob, sim_D_fluct, sim_demand, D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);
        %store the function diagnostics
        sim_diag_1{t,sim} = diag_1(3,:);	%HARDCODE ALERT. getting the middle case
        sim_diag_2{t,sim} = diag_2(3,:);    %HARDCODE ALERT. getting the middle case
        sim_diag_names{1,1} = diag_1(1,:);  %get the names of the variables for the function diagnostics
        
        %record down the results 
        %TODO: the correct # faces is brute-forced instead of adjusted for in findPrice function. Fix this.
        sim_Prices_1(t, sim) = market_p_1(2);
        sim_Prices_2(t, sim) = market_p_2(2);
        sim_Q_1(t, sim) = market_q_1(2);
        sim_Q_2(t, sim) = market_q_2(2);
        sim_CapUtil_1(t, sim) = cap_util_1(2);
        sim_CapUtil_2(t, sim) = cap_util_2(2);
        sim_Faces_1(t, sim) = faces_1(2);
        sim_Faces_2(t, sim) = faces_2(2);
        
        for(i=1:numFirms)
            r_1 = rewards_1(i,2) - capex_1(i);
            r_2 = rewards_2(i,2) - capex_2(i);
            sim_V_1(i, sim) = sim_V_1(i, sim) + r_1*(1-sim_dr)*(t-1);
            sim_V_2(i, sim) = sim_V_2(i, sim) + r_2*(1-sim_dr)*(t-1);
            sim_firm_Q_1(i,t,sim) = firms_q_1(i,2);
            sim_firm_Q_2(i,t,sim) = firms_q_2(i,2);
            
        end
        %update the states for the next period
        [sim_dperm_1] = demandPermChange(sim_dperm_1, market_p_1(2));
        [sim_dperm_2] = demandPermChange(sim_dperm_2, market_p_2(2));

    end
end


%plottings
