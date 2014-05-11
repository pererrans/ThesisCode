function [ exp_NPV ] = expectedNPV(exp_price_path, mine, currentIncCurve, sim_dr, numYearsNPV)
%Calculate the mine NPV for a mine given an expected price path
%exp_price_path is a vector of the expected prices from t_yr to T_years
%this NPV calculation assumes full utilization (arguable optimistic, hence
%can overrate the NPV of a mine)

%stretch out/cut the exp_price_path to 25 periods
if (length(exp_price_path) < numYearsNPV)
    price_cont = ones(1,numYearsNPV-length(exp_price_path)) * exp_price_path(end);
    exp_price_path = [exp_price_path price_cont]; 
elseif(length(exp_price_path) > numYearsNPV)
    exp_price_path = exp_price_path(1:numYearsNPV); 
end

%calculate cashflow vector for the numYearsNPV years    
prod = ones(1,numYearsNPV) * currentIncCurve(mine, 2); 
opex = ones(1, numYearsNPV) * currentIncCurve(mine, 3);
capex = currentIncCurve(mine, 4);
cashflow =  (exp_price_path - opex) .* prod; 
cashflow(1) = cashflow(1) - capex;  


exp_NPV = pvvar(cashflow, sim_dr); 

end

