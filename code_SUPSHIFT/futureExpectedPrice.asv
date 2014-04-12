function [exp_price_path all_price_paths all_util_paths counter] = futureExpectedPrice( MinesOpened, sim_dr, currentFirm, currentMine, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change, sim_supshift, sim_dperm,...
    t, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, TotalIncCurve_byFirm, numYearsNPV, sim_orderOfFirms, ROWIncCurve)
%For the positive mine NPV decision criteria, calculate the expected future
%price (NOT weighted by utilization rate) by averaging over several possible scenarios and possible demand
%fluctuations
%return the expected price path from the current time period t_yr till T_years

%calculate the current and total number of years
t_yr = ceil(t/decisions_in_dt);
T_years = ceil(T/decisions_in_dt);

%convergence criteria for scenario 2 and 3. Right now it's set to be 2 dollars difference (on a price of about 60-100)
conv_criteria = 2;  

%Initiatlized vars. number of scenarios for price is 3. 1st scenario is capacity growth
%keeping step with demand growth (no real price change from current period).
%2nd scenario 
numScenario = 3;
weight_scenarios = [0 1 0];  %weighting assigned to each scenario for the final averaging
all_price_paths = zeros(numScenario, T_years); 
all_util_paths = zeros(numScenario*3, T_years); 


%if the production capacity of this incentive mine is zero, then return
%price and everything being zero
currentIncCurve = TotalIncCurve_byFirm{currentFirm};     
if(currentIncCurve(currentMine, 2)==0)
    exp_price_path = zeros(1, T_year-t_yr);
    all_price_paths = zeros(numScenario, T_year-t_yr);
    all_util_paths = zeros(numScenario*3, T_year-t_yr);
    return;
end


%update the MinesOpened with the mine we are looking at
MinesOpened = MinesOpened + [and(currentFirm==1,currentMine==1),and(currentFirm==1,currentMine==2),and(currentFirm==1,currentMine==3)...
                            ,and(currentFirm==2,currentMine==1),and(currentFirm==2,currentMine==2),and(currentFirm==2,currentMine==3)...
                            ,and(currentFirm==3,currentMine==1),and(currentFirm==3,currentMine==2),and(currentFirm==3,currentMine==3)];

%%                        
%scenario 1 - current price will persist (conservative scenario) -- 3
%possible demand fluctuations and take weighted average of the 3
%note that scenario 1 clears the market immediately after
%it hence tends to overestimate price for any t that is not a market-clearing period
%because it doesn't take into account other firms potentially opening in
%this period before price clears. 

[market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened, sim_supshift, sim_dperm, sim_DPERM_change, el, sim_D_prob, sim_D_fluct, sim_Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve, ROWIncCurve);
all_price_paths(1, :) = sum(sim_D_prob .* market_p);
all_util_paths(1,:) = cap_util(1);
all_util_paths(2,:) = cap_util(2);
all_util_paths(3,:) = cap_util(3);

[sim_dperm_sc1] = demandPermChange(sim_dperm, market_p(2));
[sim_supshift_sc1] = SupShiftChange(sim_supshift, market_p(2));

%figure out if sim_dperm should actually have been changed in period t
%(because market doesn't necessarily clear in every period
if(mod(t, decisions_in_dt) == 0)
    sim_dperm_updated = sim_dperm_sc1; 
    sim_supshift_updated = sim_supshift_sc1; 
    %since t is the market clearing period, then the price for the other
    %two scenarios are also the same as the one calculated for scenario 1
    all_price_paths(2, t_yr) = all_price_paths(1, t_yr); 
    all_price_paths(3, t_yr) = all_price_paths(1, t_yr); 
    
    all_util_paths(4,t_yr) = all_util_paths(1,t_yr); 
    all_util_paths(5,t_yr) = all_util_paths(2,t_yr); 
    all_util_paths(6,t_yr) = all_util_paths(3,t_yr); 

    all_util_paths(7,t_yr) = all_util_paths(1,t_yr); 
    all_util_paths(8,t_yr) = all_util_paths(2,t_yr); 
    all_util_paths(9,t_yr) = all_util_paths(3,t_yr); 
    
else
    sim_dperm_updated = sim_dperm; 
    sim_supshift_updated = sim_supshift; 
end


%%
%scenario 3 - incentive mines with opex + amortized capex (over the NPVyears period)
%in the current period (after taking into account itself opening)
%run this in a loop until the expected price path converges or after
%running it 5 times

counter = [0 0];

diff = conv_criteria+1; 
ante_price = all_price_paths(1, :); 

while(and(and(t<T, diff>conv_criteria), counter(1)<3))
    %initialize the minesopened list
    MinesOpened_sc2 = MinesOpened; 
    sim_dperm_sc2 = sim_dperm_updated; 
    sim_supshift_sc2 = sim_supshift_updated; 
    
    %for the time periods remaining, figure out which mine opens in each
    %period and what the price path is like
    for(period = (t+1):T)
        %see which year it is
        period_yr = ceil(period/decisions_in_dt);
        
        %see whose turn it is
        firm = sim_orderOfFirms(period);
        %calculate which mine would enter based on the expected price
        lowest_inc_price = 1000; 
        mine_to_open = 0; 
        for(mine=1:numIncMines)
            %check to see if mine is already open. if so then skip. 
            if(MinesOpened_sc2((firm-1)*numIncMines+mine) == 2)
                continue;
            end
            
            %Calculate the incentive price -- essentially, what fixed price would need to be
            %there for numYearsNPV periods for the firm to have zero NPV.
            %Sum(dr^t*(inc_price-opex)*production) - capex = 0
            incCurve = TotalIncCurve_byFirm{firm};     
            prod = ones(1,numYearsNPV) * incCurve(mine, 2); 
            opex = ones(1, numYearsNPV) * incCurve(mine, 3);
            capex = incCurve(mine, 4);
            disc_prod = pvvar(prod, sim_dr); 
            inc_price = capex / disc_prod + opex; 

            %since mine is not yet open, check to see if inc_price is lower than
            %the expected price, and if it's also lower than the current
            %lowest incentive price, this is the mine to open in this period. 
            if(inc_price<= ante_price(period_yr))
                if(inc_price<lowest_inc_price)
                    lowest_inc_price = inc_price; 
                    mine_to_open = mine; 
                end
            end 
        end
        
        
        %update the mines opened in this period
        MinesOpened_sc2 = MinesOpened_sc2 + [and(firm==1,mine_to_open==1),and(firm==1,mine_to_open==2),and(firm==1,mine_to_open==3)...
                            ,and(firm==2,mine_to_open==1),and(firm==2,mine_to_open==2),and(firm==2,mine_to_open==3)...
                            ,and(firm==3,mine_to_open==1),and(firm==3,mine_to_open==2),and(firm==3,mine_to_open==3)];

        %if it's time to clear price, figure out what the price is and
        %store it
        if(mod(period, decisions_in_dt) == 0)
            [market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, period, MinesOpened_sc2, sim_supshift_sc2, sim_dperm_sc2, sim_DPERM_change, el, sim_D_prob, sim_D_fluct, sim_Demand(period), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve, ROWIncCurve);
            all_price_paths(2, period_yr) = sum(sim_D_prob .* market_p);
            all_util_paths(4,period_yr) = cap_util(1);
            all_util_paths(5,period_yr) = cap_util(2);
            all_util_paths(6,period_yr) = cap_util(3);
            [sim_dperm_sc2] = demandPermChange(sim_dperm_sc2, market_p(2));
            [sim_supshift_sc2] = SupShiftChange(sim_supshift_sc2, market_p(2));
        end
    
    end
    
    %calculate the convergence criteria
    diff = sqrt(sum((all_price_paths(2,t_yr:T_years) - ante_price(t_yr:T_years)).^2)/(T_years-t_yr+1));     
    counter(1)=counter(1)+1;

%     counter(2)
%     ante_price
%     all_price_paths(3, :)

    
    ante_price = all_price_paths(2, :); 

end


 %% %%
%scenario 3 - incentive mines with opex that is equal or less than the price in the
%current period will enter (after taking into account itself)
%run this in a loop until the expected price path converges or after
%running it 5 times

diff = conv_criteria+1; 
ante_price = all_price_paths(1, :); 

while(and(and(t<T, diff>conv_criteria),counter(2)<3))
    %initialize the minesopened list
    MinesOpened_sc3 = MinesOpened; 
    sim_dperm_sc3 = sim_dperm_updated; 
    sim_supshift_sc3 = sim_supshift_updated; 
    
    %for the time periods remaining, figure out which mine opens in each
    %period and what the price path is like
    for(period = t+1:T)
        %see which year it is
        period_yr = ceil(period/decisions_in_dt);
        
        %see whose turn it is
        firm = sim_orderOfFirms(period);
        incCurve = TotalIncCurve_byFirm{firm};     
        %calculate which mine would enter based on the expected price
        lowest_opex = 1000; 
        mine_to_open = 0; 
        for(mine=1:numIncMines)
            %check to see if mine is already open. if so then skip. 
            if(MinesOpened_sc3((firm-1)*numIncMines+mine) == 2)
                continue;
            end
            
            %since mine is not yet open, check to see if opex is lower than
            %the expected price, and if it's also lower than the current
            %opex, this is the mine to open in this period. 
            if(incCurve(mine,3)<= ante_price(period_yr))
                if(incCurve(mine,3)<lowest_opex)
                    lowest_opex = incCurve(mine,3); 
                    mine_to_open = mine; 
                end
            end 
        end
        
        %update the mines opened in this period
        MinesOpened_sc3 = MinesOpened_sc3 + [and(firm==1,mine_to_open==1),and(firm==1,mine_to_open==2),and(firm==1,mine_to_open==3)...
                            ,and(firm==2,mine_to_open==1),and(firm==2,mine_to_open==2),and(firm==2,mine_to_open==3)...
                            ,and(firm==3,mine_to_open==1),and(firm==3,mine_to_open==2),and(firm==3,mine_to_open==3)];

        %if it's time to clear price, figure out what the price is and
        %store it
        if(mod(period, decisions_in_dt) == 0)
            [market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, period, MinesOpened_sc3, sim_supshift_sc3, sim_dperm_sc3, sim_DPERM_change, el, sim_D_prob, sim_D_fluct, sim_Demand(period), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve, ROWIncCurve);
            all_price_paths(3, period_yr) = sum(sim_D_prob .* market_p);
            all_util_paths(7,period_yr) = cap_util(1);
            all_util_paths(8,period_yr) = cap_util(2);
            all_util_paths(9,period_yr) = cap_util(3);
            [sim_dperm_sc3] = demandPermChange(sim_dperm_sc3, market_p(2));
            [sim_supshift_sc3] = SupShiftChange(sim_supshift_sc3, market_p(2));

        end
    
    end
    
    %calculate the convergence criteria and update the price expectations
    diff = sqrt(sum((all_price_paths(3,t_yr:T_years) - ante_price(t_yr:T_years)).^2)/(T_years-t_yr+1));     
    counter(2)=counter(2)+1;
    
%     counter(1)
%     ante_price
%     all_price_paths(2, :)
    
    ante_price = all_price_paths(3, :); 

    
end



%%
%there could also be the ultra-optimistic scenario where nothing else
%opens, but we won't include it here

all_price_paths = all_price_paths(:, t_yr:T_years);  
all_util_paths = all_util_paths(:, t_yr:T_years); 

exp_price_path = weight_scenarios * all_price_paths; 

end

