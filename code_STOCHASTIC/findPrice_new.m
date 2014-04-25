function [ market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened, SUPSHIFT, DPERM, DPERM_change, el, D_prob, D_fluct, D_t, D_0, SupplyCurve_t, a, IncentiveCurve, ROWIncCurve)
% Yuanjian Carla Li, January 28, 2013
% The purpose of this model is to figure out the equilibrium price and 
% quantity for each of the players, given the set of actions, the state 
% (what mines are operating), the underlying supply, and the demand (with elasticity)
% rewards are this period payoffs for the different players
% TODO: calculate reward for all firms. each row is one firm. 

%find price in the market given the demand, supplycurve, states, actions
%return a vector of prices and quantities each player for each demand
%scenario

% supplyCurve_t consists of 3 columns: owner, Q, cost. Its rows are the
% different mines operating now. SupplyCurve_0 is the first period supply
% curve and is used to calibrate the coefficient for the elastic demand
% curve so that base demand intersects with base supply at a predetermined
% value
%D_fluct is the fluctation in demand, and should be 1 or above

%Global toggles for different modes
%If true, the MODE_supplyTruncate mode cuts the operating supply where the 
%demand curve crosses the supply curve, in the case when the demand
%curve crosses supply STRICTLY between the cost levels of two mines (e.g. vertical part of a supply
%curve). If false, the mine after crossing is also included in the
%operating supply, and the utilization rate for all mines is reduced as a
%result
global MODE_supplyTruncate;
MODE_supplyTruncate = true; 

%% get variables

%initialize variables
market_p = zeros(1,length(D_prob));
market_q = zeros(1,length(D_prob));
rewards = zeros(numFirms,length(D_prob));
costs = zeros(numFirms,length(D_prob));
firms_q = zeros(numFirms, length(D_prob));
cap_util = zeros(1,length(D_prob));

%diag records the diagnostic information about this function for the 3
%demand scenarios (each row a different demand scenario)
%the info: price (by the demand function
diag = cell(length(D_prob)+1,6);
diag(1,:) = {'p_demand','q_demand','excess_q','marg_q','marg_cost','marg_firm'};

faces = zeros(1,3); %initialize the # times demand intersects supply at the supply step cliff face
excess_q = zeros(1,length(D_prob));
index = zeros(1,length(D_prob));

%% Update the supply curve to reflect current supply
%start creating the relevant updated supply curve 

%update an incentive mine of a major player if already opened
for m=1:length(MinesOpened)
    if(MinesOpened(m)==2)
        SupplyCurve_t(m,:) = IncentiveCurve(m,1:3);
    end
end

%update according to supplyshift change
start = length(MinesOpened)+1;
if(SUPSHIFT>=2)
    SupplyCurve_t(start:(start+size(ROWIncCurve{1},1)-1), :) = ROWIncCurve{1};  
end
start = start+size(ROWIncCurve{1})+1;
if(SUPSHIFT>=3)
    SupplyCurve_t(start:(start+size(ROWIncCurve{2},1)-1), :) = ROWIncCurve{2};  
end
start = start+size(ROWIncCurve{2})+1;
if(SUPSHIFT>=4)
    SupplyCurve_t(start:(start+size(ROWIncCurve{3},1)-1), :) = ROWIncCurve{3};  
end


%don't need to add the mines opened this period (because they only open 
% in the next period

%%Update demand for any permanent change to base demand
%if price ever reached a number of higher, then
%some part of demand gets permanently destroyed (or created) -- so
%there is a above normal, normal and below normal growth 
D_t = D_t*(1+(DPERM-3)*(DPERM_change)); 

%% calculate the intersection of demand (with elasticity) and updated supply
% update the supply curve
SupplyCurve_t=sortrows(SupplyCurve_t,3);    %sort supply by price
newSupply = [SupplyCurve_t cumsum(SupplyCurve_t(:,2))]; %add a column for cumulative supply

D_cases = [1/D_fluct 1 D_fluct];    %since D_fluct<1, expansion, base, contraction of demand cases respectively. MAYBE_TODO: does this loglinear perturbation scheme make sense?


%determine what the equilibrium Q is for each demand scenario (given the
%different demand shocks) 
l_supply = length(newSupply); 
for j=1:length(D_cases)
    X = D_cases(j); %specify which demand shock scenario
    for i=1:l_supply
        q = newSupply(i,4);
        if(q==0)
            continue;
        end
        p = X^(1/el)*a*q^(-1/el)*(D_t/D_0)^(1/el);
        %fprintf('demand scenario %d step %d: q=%d, p=%d\n', j, i, q, p);
        if(i>=l_supply)
            err = MException('ResultChk:SupplyOutOfRange', ...
                'RAN OUT OF SUPPLY CURVE! PLEASE ADD TO SUPPLY CURVE');
            throw(err);
            
        %if either the demand curve falls below the marginal supply's cost
        %at the cumulative q, or it crosses the supply STRICTLY below the cost of
        %the next marginal mine AND the supplyTruncate mode is on, the
        %marginal mine has been found
        elseif (newSupply(i,3)>=p || (newSupply(i+1,3)>p && MODE_supplyTruncate==true))
            if(newSupply(i,3)>=p)
                market_p(j) = newSupply(i,3);
                %fprintf('terminal demand is %d, price is %d\n', D_t, market_p(j));
                market_q(j) = ((X^(1/el)*a*(D_t/D_0)^(1/el))/market_p(j))^(el);
            
            %if in truncate mode and the demand crosses between this mine
            %and the next, truncate and set price accordingly
            else
                market_p(j) = p; %price is determined by demand in this case
                market_q(j) = q; %quantity is the entire amount
                faces(j) = faces(j)+1;
            end
            excess_q(j) = q - market_q(j);
            cap_util(j) = market_q(j) / q;
            index(j) = i;
            
            %check if the demand curve crosses cliff face of supply step.
            %this would only activate if the MODE_supplyTruncate is off
            if(i>1)
                if(market_q(j)<=newSupply(i-1,4))
                    faces(j) = faces(j)+1;
                end
            end 
            
            %store the diagostic data
            diag{j+1,1} = p; %demand function's price from the full output level
            diag{j+1,2} = q;  %quantity used to generate the price from the demand function. essentially the full q of all operating units
            diag{j+1,3} = excess_q(j);    %excess quantity (all operating firms at full capacity - demand
            diag{j+1,4} = newSupply(i,2); %quantity of marginal mine
            diag{j+1,5} = newSupply(i,3); %cost of marginal mine
            diag{j+1,6} = newSupply(i,1); %owner of the marginal mine
            
            %track the costs of operating mines
            owner = newSupply(i,1);
            if(owner<=numFirms) %only track costs for firms we care about            
                costs(owner, j) = costs(owner, j) + newSupply(i,3)*newSupply(i,2);
                firms_q(owner,j) = firms_q(owner,j) + newSupply(i,2);
            end
            
            %calculate rewards of the firms (excluding capex)
            for(firm = 1:numFirms)
                rewards(firm,j) = cap_util(j)*((market_p(j)*firms_q(firm,j)) - costs(firm,j));
            end
            
            %adjust the firm_q for capacity utilization 
            firms_q(:,j) = firms_q(:,j).*cap_util(j);
            
            break;
        
        else
            %track the costs of operating mines
            owner = newSupply(i,1);
            if(owner<=numFirms) %only track costs for firms we care about
                costs(owner, j) = costs(owner, j) + newSupply(i,3)*newSupply(i,2);
                firms_q(owner,j) = firms_q(owner,j) + newSupply(i,2);
            end
        end
        
    end
end

%Clear the MODE variables to avoid declaring them twice
clear MODE_supplyTruncate;

end

