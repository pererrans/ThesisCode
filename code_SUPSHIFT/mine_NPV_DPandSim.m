function [ sim_openings_3, sim_Prices_3, sim_Q_3, sim_firm_Q_3, sim_V_3, sim_Vt_3, sim_CapUtil_3, sim_Faces_3, sim_diag_3] = ...
    mine_NPV_DPandSim(simNum3, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change, ...
    T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, TotalIncCurve_byFirm, ROWIncCurve)

%number of years considered in mine NPV calculations
numYearsNPV = 27; 

%number of years in the model
T_years = ceil(T/decisions_in_dt);


%output to be recorded
sim_Prices_3 = zeros(T_years, simNum3);
sim_Q_3 = zeros(T_years, simNum3);
sim_CapUtil_3 = zeros(T_years, simNum3);
sim_Faces_3 = zeros(T_years, simNum3); %when it crossed the cliff face of supply curve
sim_V_3 = zeros(numFirms, simNum3);
sim_Vt_3 = zeros(T_years, numFirms, simNum3);
sim_openings_3 = zeros(numIncMines, numFirms, simNum3);
sim_diag_3 = cell(T_years,simNum3);    %cell array to store the diagnostics from each market clearing
sim_firm_Q_3 = zeros(numFirms, T_years, simNum3);
exp_NPV_record = ones(numIncMines, numFirms, T_years, simNum3)*-1; %what the NPV calculated for making the optimal opening choice were, for later reference

for(sim=1:simNum3)
    
    %Initialize the important state variables
    MinesOpened = ones(1,numFirms*numIncMines);  %1 indicates not open. 2 indicates open. 
    sim_dperm = 3; 
    sim_supshift =1; 
    
    %figure out the policy and simulate at the same time
    for t = 1:T
        %figure out which year to store the results in
        t_yr = ceil(t/decisions_in_dt);

        %reset the capex spending to 0 if market clears every dt (hence
        %reward is calculated every dt) OR if it's the beginning of a
        %market-clearing decision period
        if(or(decisions_in_dt==1, mod(t, decisions_in_dt)==1))
            capex_3=zeros(1,numFirms);
        end

        %     Determine which firm is to make expansion decision in this period
        currentFirm = sim_orderOfFirms(t);
        currentIncCurve = TotalIncCurve_byFirm{currentFirm};     
        % 	For each of the incentive mine of this firm that is not open already
        highestNPV = 0;
        bestMine = 0;
        bestCapex = 0;
        for(mine=1:numIncMines)
            %check to see if mine is already open. if so then skip. 
            if(MinesOpened((currentFirm-1)*numIncMines+mine) == 2)
                continue;
            end

            %Calculate the expected NPV of opening this mine over 25 years over the 
            %possible demand fluctuations and main opening scenarios
            [exp_price_path all_price_paths all_util_paths counter] = ...
                futureExpectedPrice( MinesOpened, sim_dr, currentFirm, mine, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change, sim_supshift, sim_dperm,...
                    t, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, TotalIncCurve_byFirm, numYearsNPV, sim_orderOfFirms, ROWIncCurve);

            [exp_NPV] = expectedNPV(exp_price_path, mine, currentIncCurve, sim_dr, numYearsNPV); 
            exp_NPV_record(mine, currentFirm, t_yr, sim) = exp_NPV; 
            
            %If the mine is NPV positive, see if the NPV is the most positive OR highest NPV/capex out of the potential incentive mines to open for this firm so far.
            %If so, record this mine as the mine to open
            if (and(exp_NPV>highestNPV, exp_NPV>0))
                highestNPV = exp_NPV;
                bestMine = mine; 
                bestCapex = currentIncCurve(mine,4); 
            elseif(and(exp_NPV==highestNPV, exp_NPV>0))
                %tiebreaking based on best NPV/capex ratio if the NPVs are the same and is not 0
                if(currentIncCurve(mine,4)<bestCapex)
                    highestNPV = exp_NPV;
                    bestMine = mine; 
                    bestCapex = currentIncCurve(mine,4);
                end
            end
        end

        % Open the highest NPV OR highest NPV/capex mine that’s also NPV-positive, if any
        % and record the opening decision and update the mines opened
        if(highestNPV >0)
            sim_openings_3(bestMine,currentFirm, sim) = t_yr;
            MinesOpened = MinesOpened + [and(currentFirm==1,bestMine==1),and(currentFirm==1,bestMine==2),and(currentFirm==1,bestMine==3)...
                                        ,and(currentFirm==2,bestMine==1),and(currentFirm==2,bestMine==2),and(currentFirm==2,bestMine==3)...
                                        ,and(currentFirm==3,bestMine==1),and(currentFirm==3,bestMine==2),and(currentFirm==3,bestMine==3)];
            capex_3(currentFirm) = currentIncCurve(bestMine,4);
        end
        
        %if time to clear price, clear the market and realize the demand perturbation
        if(mod(t, decisions_in_dt) == 0)
            %simulate the demand perturbation
            D_index = randsample(length(sim_D_prob), 1, true, sim_D_prob);
            D_cases = sim_Demand(t).*[1/sim_D_fluct 1 sim_D_fluct];
            sim_demand = D_cases(D_index);
            [market_p_3, market_q_3, cap_util_3, rewards_3, faces_3, firms_q_3, diag_3] = findPrice_new(T, numFirms, t, MinesOpened, sim_supshift, sim_dperm, sim_DPERM_change, el, sim_D_prob, sim_D_fluct, sim_demand, D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve, ROWIncCurve);

            %store the function diagnostics
            sim_diag_3{t_yr,sim} = diag_3(3,:);	%HARDCODE ALERT. getting the middle case

            %record down the results 
            sim_Prices_3(t_yr, sim) = market_p_3(2);
            sim_Q_3(t_yr, sim) = market_q_3(2);
            sim_CapUtil_3(t_yr, sim) = cap_util_3(2);
            sim_Faces_3(t_yr, sim) = faces_3(2);
        
            for(i=1:numFirms)
                r_3 = rewards_3(i,2) - capex_3(i);
                sim_Vt_3(t_yr,i,sim) = r_3;            
                sim_V_3(i, sim) = sim_V_3(i, sim) + r_3*(1-sim_dr)^(t_yr-1);
                sim_firm_Q_3(i,t_yr,sim) = firms_q_3(i,2);            
            end
            
            %update the states for the next period
            [sim_dperm] = demandPermChange(sim_dperm, market_p_3(2));
            [sim_supshift] = SupShiftChange(sim_supshift, market_p_3(2));
            
        end
    end
end


end

