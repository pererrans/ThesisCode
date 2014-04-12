function [ sim_openings_1, sim_Prices_1, sim_Q_1, sim_firm_Q_1, sim_V_1, sim_Vt_1, sim_CapUtil_1, sim_Faces_1, sim_diag_1] = ...
    sim_variations(varywho, Xa_1, Xb_1, Xc_1, simNum, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change, ...
    IncentiveCurveA, IncentiveCurveB, IncentiveCurveC, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, ROWIncCurve)
%Given the policy for each firm, simulate the actions based on a base
%policy but with random variations in the decisions

%probability of doing different actions
prob = ones(1,4)*0.25;

%how many years we are simulating. T only indicates the number of decision 
% periods. Market clears once a year at the end of the year
T_years = round(T/decisions_in_dt); 

%output to be recorded
sim_Prices_1 = zeros(T_years, simNum);
sim_Q_1 = zeros(T_years, simNum);
sim_CapUtil_1 = zeros(T_years, simNum);
sim_Faces_1 = zeros(T_years, simNum); %when it crossed the cliff face of supply curve
sim_V_1 = zeros(numFirms, simNum);
sim_Vt_1 = zeros(T_years, numFirms, simNum);
sim_openings_1 = zeros(numIncMines, numFirms, simNum);
sim_diag_1 = cell(T_years,simNum);    %cell array to store the diagnostics from each market clearing
sim_firm_Q_1 = zeros(numFirms, T_years, simNum);

%name of the diagnostic entries
sim_diag_names = cell(1,1);

for(sim=1:simNum)
    %initialize the state variables
    sim_m_1 = ones(1,numFirms*numIncMines);
    sim_dperm_1 = 3;
    sim_supshift_1=1; 

    for(t=1:T)
        firm = sim_orderOfFirms(t);

        %reset the capex spending to 0 if market clears every dt (hence
        %reward is calculated every dt) OR if it's the beginning of a
        %market-clearing decision period
        if(or(decisions_in_dt==1, mod(t, decisions_in_dt)==1))
            capex_1=zeros(1,numFirms);
        end        
        
        if(firm==1)
            if(varywho==1)
                choices = [1 2 3] .* (2-sim_m_1(1:3));
                choices = [0 choices];
%                 display(t);
%                 display(choices);
                rand = randsample(length(prob), 1, true, prob);
                a_1 = choices(rand);
%                 display(a_1);
            else
                a_1 = Xa_1(sim_m_1(1), sim_m_1(2), sim_m_1(3), sim_m_1(4), sim_m_1(5), sim_m_1(6), sim_m_1(7), sim_m_1(8), sim_m_1(9), firm, sim_dperm_1, sim_supshift_1, t);
            end
            sim_m_1 = sim_m_1 + [(a_1==1),(a_1==2),(a_1==3),0,0,0,0,0,0];
%             display(sim_m_1);

            %if there is a new opening, record it and add to capex
            if(a_1~=0)
                    capex_1(firm) = IncentiveCurveA(a_1,4);
                    sim_openings_1(a_1,firm, sim) = round(t/decisions_in_dt);
            end

        elseif(firm==2)
            if(varywho==2)
                choices = [1 2 3] .* (2-sim_m_1(4:6));
                choices = [0 choices];
                rand = randsample(length(prob), 1, true, prob);
                b_1 = choices(rand);
            else
                b_1 = Xb_1(sim_m_1(1), sim_m_1(2), sim_m_1(3), sim_m_1(4), sim_m_1(5), sim_m_1(6), sim_m_1(7), sim_m_1(8), sim_m_1(9), firm, sim_dperm_1, sim_supshift_1, t);
            end
            sim_m_1 = sim_m_1 + [0,0,0,(b_1==1),(b_1==2),(b_1==3),0,0,0];
            if(b_1~=0)
                    capex_1(firm) = IncentiveCurveB(b_1,4);
                    sim_openings_1(b_1,firm, sim) = round(t/decisions_in_dt);
            end
            

        elseif(firm==3)
            if(varywho==3)
                choices = [1 2 3] .* (2-sim_m_1(7:9));
                choices = [0 choices];
                rand = randsample(length(prob), 1, true, prob);
                c_1 = choices(rand);
            else
                c_1 = Xc_1(sim_m_1(1), sim_m_1(2), sim_m_1(3), sim_m_1(4), sim_m_1(5), sim_m_1(6), sim_m_1(7), sim_m_1(8), sim_m_1(9), firm, sim_dperm_1, sim_supshift_1, t);
            end
            sim_m_1 = sim_m_1 + [0,0,0,0,0,0,(c_1==1),(c_1==2),(c_1==3)];
            if(c_1~=0)
                    capex_1(firm) = IncentiveCurveC(c_1,4);
                    sim_openings_1(c_1,firm, sim) = round(t/decisions_in_dt);
            end
            
        end
        
        if(mod(t, decisions_in_dt) == 0)
            %simulate the demand perturbation
            D_index = randsample(length(sim_D_prob), 1, true, sim_D_prob);
            D_cases = sim_Demand(t).*[1/sim_D_fluct 1 sim_D_fluct];
            sim_demand = D_cases(D_index);
            [market_p_1, market_q_1, cap_util_1, rewards_1, faces_1, firms_q_1, diag_1] = findPrice_new(T, numFirms, t, sim_m_1, sim_supshift_1, sim_dperm_1, sim_DPERM_change, el, sim_D_prob, sim_D_fluct, sim_demand, D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve, ROWIncCurve);
            
            %figure out which year to store the results in
            t_yr = round(t/decisions_in_dt);
            
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
                sim_V_1(i, sim) = sim_V_1(i, sim) + r_1*(1-sim_dr)^(t_yr-1);
                sim_firm_Q_1(i,t_yr,sim) = firms_q_1(i,2);            
            end
            
            %update the states for the next period
            [sim_dperm_1] = demandPermChange(sim_dperm_1, market_p_1(2));
            [sim_supshift_1] = SupShiftChange(sim_supshift_1, market_p_1(2));
        end
        
    end
end


end

