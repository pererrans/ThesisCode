function [ exp_price_path DPERM_updated ] = futureExpectedPrice( T_years )
%For the positive mine NPV decision criteria, calculate the expected future
%price by average over several possible scenarios and possible demand
%fluctuations
numScenario = 3;
all_paths = zeros(numScenario, T_years); 



exp_price_path = mean(all_paths); 

end

