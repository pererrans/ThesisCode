function [ reward ] = rewardCalc( player, price, capex, minesOpened)
%rewardCalc calculates the reward according to the market price and the
%list of mines opened and the capex spent per player, for the specified player
%the most direct way of calculating reward is just the profit in this
%period minus the capex, which is what is implemented here. 
%One can create other rewardCalc functions that calculate reward differently,
%for instance according to market share changes

%calculate capex
capex = 0;
for m=1:length(newOpenings)
    if(MinesOpened(m)==1)
        newSupply(l+m,:) = IncentiveCurve(m, 1:3);
        capex = capex + IncentiveCurve(m, 4);
    end
end


end

