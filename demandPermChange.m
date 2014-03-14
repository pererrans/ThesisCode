function [ nextDPerm ] = demandPermChange(DPERM, price)
%Transition function for DPerm according to the price level
%DPERM values are 1 through 5.  Values 4 and 5 are when demand is
%expanded because of low price. Values 1 and 2 are when demand is reduced
%because of high price. Capped on both ends.

%the boundaries for price, by looking at the supply curve at the different
%quantile quantity points
% P_high_10 = 200;    %ONLY FOR DUMMY SUPPLY MODE
% P_high_25 = 160;    %ONLY FOR DUMMY SUPPLY MODE
P_high_10 = 115; %price at this level or higher should add 2 to the perm change
P_high_25 = 85;
P_low_10 = 40;
P_low_25 = 46;

temp_DPERM = DPERM + (price>=P_high_10) + (price>=P_high_25) - (price<=P_low_10) - (price<=P_low_25);
nextDPerm = min(max(temp_DPERM, 1),5);

end

