function [ sim_openings_1, sim_Prices_1, sim_Q_1,  sim_D_1, sim_firm_Q_1, sim_V_1, sim_Vt_1, sim_ProfitCF_1, sim_Turnovers_1, sim_CapUtil_1, sim_Faces_1, sim_diag_1, sim_diag_names] = ...
    simulation(Xa_1, Xb_1, Xc_1, simNum, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change, ...
    IncentiveCurveA, IncentiveCurveB, IncentiveCurveC, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, ROWIncCurve)
%Given the policy for each firm, simulate the actions
%%SIMULATION
% Simulate the game with the demand uncertainty. See how the price path
% unfolds using the optimal policy. Compare against a dummy policy and
% compare. 

%how many years we are simulating. T only indicates the number of decision 
% periods. Market clears once a year at the end of the year
T_years = ceil(T/decisions_in_dt); 

%create holder of the real D fluctuation probability, so that we can always
%run the no fluctuation case as the first one (for graphing purposes)
sim_D_prob_holder = sim_D_prob; 

%output to be recorded
sim_Prices_1 = zeros(T_years, simNum);
sim_Q_1 = zeros(T_years, simNum);
sim_D_1 = zeros(T_years, simNum);
sim_CapUtil_1 = zeros(T_years, simNum);
sim_Faces_1 = zeros(T_years, simNum); %when it crossed the cliff face of supply curve
sim_V_1 = zeros(numFirms, simNum);
sim_Vt_1 = zeros(T_years, numFirms, simNum);
sim_ProfitCF_1 = zeros(T_years, numFirms, simNum);
sim_Turnovers_1 = zeros(T_years, numFirms+1, simNum);
sim_openings_1 = zeros(numIncMines, numFirms, simNum);
sim_diag_1 = cell(T_years,simNum);    %cell array to store the diagnostics from each market clearing
sim_firm_Q_1 = zeros(T_years, numFirms, simNum);

%name of the diagnostic entries
sim_diag_names = cell(1,1);

for(sim=1:simNum)
    
    if(sim==1) 
        sim_D_prob=[0 1 0];
    elseif(sim==2)
        sim_D_prob=[1 0 0];
    elseif(sim==3)
        sim_D_prob=[0 0 1];
    else
        sim_D_prob = sim_D_prob_holder;
    end

    %initialize the state variables
    sim_m_1 = ones(1,numFirms*numIncMines);
    sim_dperm_1 = 3;
    sim_supshift_1=1; 

    for(t=1:T)
        %figure out which year to store the results in
        t_yr = ceil(t/decisions_in_dt);

        %firm that is making the decision
        firm = sim_orderOfFirms(t);
        
        %reset the capex spending to 0 if market clears every dt (hence
        %reward is calculated every dt) OR if it's the beginning of a
        %market-clearing decision period
        if(or(decisions_in_dt==1, mod(t, decisions_in_dt)==1))
            capex_1=zeros(1,numFirms);
        end
        
        if(firm==1)
            a_1 = Xa_1(sim_m_1(1), sim_m_1(2), sim_m_1(3), sim_m_1(4), sim_m_1(5), sim_m_1(6), sim_m_1(7), sim_m_1(8), sim_m_1(9), firm, sim_dperm_1, sim_supshift_1, t);
            
            sim_m_1 = sim_m_1 + [(a_1==1),(a_1==2),(a_1==3),0,0,0,0,0,0];
            
            %if there is a new opening, record it and add to capex
            if(a_1~=0)
                    capex_1(firm) = IncentiveCurveA(a_1,4);
                    sim_openings_1(a_1,firm, sim) = ceil(t/decisions_in_dt);
                    
%                     fprintf('Sim %d, period %d.  ', sim, t_yr)
%                     fprintf('Mine opened: %d from firm %d\n', a_1, firm)

            end
            

        elseif(firm==2)
            b_1 = Xb_1(sim_m_1(1), sim_m_1(2), sim_m_1(3), sim_m_1(4), sim_m_1(5), sim_m_1(6), sim_m_1(7), sim_m_1(8), sim_m_1(9), firm, sim_dperm_1, sim_supshift_1, t);
            sim_m_1 = sim_m_1 + [0,0,0,(b_1==1),(b_1==2),(b_1==3),0,0,0];
            if(b_1~=0)
                    capex_1(firm) = IncentiveCurveB(b_1,4);
                    sim_openings_1(b_1,firm, sim) = ceil(t/decisions_in_dt);

%                     fprintf('Sim %d, period %d.  ', sim, t_yr)
%                     fprintf('Mine opened: %d from firm %d\n', b_1, firm)
                    
            end
            

        elseif(firm==3)
            c_1 = Xc_1(sim_m_1(1), sim_m_1(2), sim_m_1(3), sim_m_1(4), sim_m_1(5), sim_m_1(6), sim_m_1(7), sim_m_1(8), sim_m_1(9), firm, sim_dperm_1, sim_supshift_1, t);
            sim_m_1 = sim_m_1 + [0,0,0,0,0,0,(c_1==1),(c_1==2),(c_1==3)];
            if(c_1~=0)
                    capex_1(firm) = IncentiveCurveC(c_1,4);
                    sim_openings_1(c_1,firm, sim) = ceil(t/decisions_in_dt);

%                     fprintf('Sim %d, period %d.  ', sim, t_yr)
%                     fprintf('Mine opened: %d from firm %d\n', c_1, firm)

            end
            
        end
        
        if(mod(t, decisions_in_dt) == 0)

            %simulate the demand perturbation
            D_index = randsample(length(sim_D_prob), 1, true, sim_D_prob);
            D_cases = sim_Demand(t).*[1/sim_D_fluct 1 sim_D_fluct];
            sim_demand = D_cases(D_index);
            sim_D_1(t_yr, sim) = sim_demand; 
            [market_p_1, market_q_1, cap_util_1, rewards_1, turnovers_1, faces_1, firms_q_1, diag_1] = findPrice_new(T, numFirms, t, sim_m_1, sim_supshift_1, sim_dperm_1, sim_DPERM_change, el, sim_D_prob, sim_D_fluct, sim_demand, D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve, ROWIncCurve);
            
%             t
%             sim_demand
%             [market_p_1(2), market_q_1(2), cap_util_1(2), faces_1(2)]
                        
            %store the function diagnostics
            sim_diag_1{t_yr,sim} = diag_1(3,:);	%HARDCODE ALERT. getting the middle case
            sim_diag_names{1,1} = diag_1(1,:);  %get the names of the variables for the function diagnostics
        
            %record down the results 
            sim_Prices_1(t_yr, sim) = market_p_1(2);
            sim_Q_1(t_yr, sim) = market_q_1(2);
            sim_CapUtil_1(t_yr, sim) = cap_util_1(2);
            sim_Faces_1(t_yr, sim) = faces_1(2);
        
            for(i=1:numFirms)
                r_1 = rewards_1(i,2) - capex_1(i);
                sim_Vt_1(t_yr,i,sim) = r_1;            
                sim_ProfitCF_1(t_yr,i,sim) = rewards_1(i,2); 
                sim_V_1(i, sim) = sim_V_1(i, sim) + r_1/(1+sim_dr)^(t_yr-1);
                sim_Turnovers_1(t_yr,i,sim) = turnovers_1(i,2); 
                sim_firm_Q_1(t_yr,i,sim) = firms_q_1(i,2);            
            end
            
            %the numFirms+1 position is for the Rest of the World Turnover
            %volume (for later graphing of the market share split in the world)
            sim_Turnovers_1(t_yr,numFirms+1,sim) = sim_Prices_1(t_yr,sim)*sim_Q_1(t_yr,sim)*sim_CapUtil_1(t_yr, sim) - sum(sim_Turnovers_1(t_yr,1:numFirms,sim));
            
            %update the states for the next period
            [sim_dperm_1] = demandPermChange(sim_dperm_1, market_p_1(2));
            [sim_supshift_1] = SupShiftChange(sim_supshift_1, market_p_1(2)); 
        end        

    end
end



end

