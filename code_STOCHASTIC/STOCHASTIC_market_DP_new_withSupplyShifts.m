% Exact DP solution and simulation to a 3-player game in the mineral market
% Yuanjian Carla Li, version April 1, 2014

%record the profile for performance enhancement
profile on %-detail builtin -history

%Set a repeatble stream of random scenarios
s = RandStream('mt19937ar','Seed',1);
RandStream.setGlobalStream(s);

% criteria2vary = 'el'; 
criteria2vary = 'supplyStr';

%for demand
dgrowth_list = cell(5,1); 
dgrowth_list{1} = [0.01, 0.02]
dgrowth_list{2} = [0.02, 0.01]
dgrowth_list{3} = [0.02, 0.02]
dgrowth_list{4} = [0.01, -0.01]
dgrowth_list{5} = [-0.01, 0.01]

%for ordering
ordering_list = {'ABC', 'CBA', 'BAC', 'BCA', 'ACB', 'CAB'}; 

%for supply structure
supplymode_list = {'base','equalIncPrice','equalSupply','equalS_moreMajor','base_moreMajor','base_moreMajor_noIncVChange'}

%for el
el_list = cell(4,1); 
el_list{1} = 0.5; 
el_list{2} = 1; 
el_list{3} = 2; 
el_list{4} = 0.75; 
el_list{5} = 0.6; 
el_list{6} = 0.1; 

%for perturbation 
perturb_list = cell(4,1); 
perturb_list{1} = 0.8; 
perturb_list{2} = 0.85; 
perturb_list{3} = 0.9; 
perturb_list{4} = 0.95; 

%for prob distribution
pprob_list = cell(3,1); 
pprob_list{1} = [0.2, 0.6, 0.2]; 
pprob_list{2} = [0.1, 0.6, 0.3]; 
pprob_list{3} = [0.3, 0.6, 0.1]; 
pprob_list{4} = [0.3, 0.4, 0.3]; 

for(order_num=1:2)
for(list_num=3:3)
    
%reset the random stream to start at the beginning for repeatability
stream = RandStream.getGlobalStream;
reset(stream);

%naming for the output in terms of firm decision ordering
ordering = ordering_list{order_num}; 

switch ordering
    case 'ABC'
        decision_order = [1 2 3];
    case 'ACB' 
        decision_order = [1 3 2];
    case 'BAC' 
        decision_order = [2 1 3];
    case 'BCA' 
        decision_order = [2 3 1];
    case 'CAB' 
        decision_order = [3 1 2];
    case 'CBA' 
        decision_order = [3 2 1];
end

%record log
diary([ordering '_output_log_' criteria2vary '_' num2str(list_num)]);
diary on;

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%INITIALIZE VARIABLES AND SET THE MODES FOR THIS OPTIMIZATION AND
%%SIMULATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%initialize variables
dr = 0.1;
numFirms = 3; %number of firms
numIncMines = 3; %number of incentive mines per firm

%DIFFERENT MODES FOR THE PROGRAM
%SUPPLYCURVE_MODE controls which supply curve is used. 0 is for the scrambled Rio
%Tinto one. 1 is for the real Rio Tinto one. -1 is for the real Rio Tinto one except the 
%capex is reduced 10x so that shorter time horizon can still yield mine opening.
% -2 is for the dummy one for testing purpose. -3 is for the Rio Tinto one with more aggregation (testing purpose) 
SUPPLYCURVE_MODE = supplymode_list{list_num};

%ROWINCCURVE_MODE: 1 is for ROW Incentive curve being mines that will
%always operate. 2 is for ROW curve with mines that have specified opex
ROWINCCURVE_MODE=1; 

%MODE_MKT_CLEAR_AFTER_ALL_DECIDE controls whether we have all the mines make a decision before the
%market clears (1), or whether the market clears after each one (0). It 
%affects the interpretation of dt as well. T is 1/3 of a year in the first
%case, and a year in the second case
MODE_MKT_CLEAR_AFTER_ALL_DECIDE = 1;

if(MODE_MKT_CLEAR_AFTER_ALL_DECIDE ==0)
    decisions_in_dt = 1;
else
    decisions_in_dt = numFirms;
end

%Time setup
T_years = 27;  %number of years in T (market clears at the end of each year)
T = decisions_in_dt*T_years; %T is the number of decision periods and is equal to the number of decisions in each year * number of years

%MODE_END_PERIOD_VALUE controls what value we assign to the mines at the
%end of the 25-year period over which we have an accurate projection for
%the underlying demand
% 0 = no value for any mining property
% 1 = same value as the last period (this is assuming the same production
% and price level, i.e. capacity growth is keeping pace with demand growth
% 2 = The incentive mines not already opened will open at the end of period
% T if the opex of the mine is less or equal to the price in this period
% 3 = The incentive mines not already opened will open at the end of period
% T if the opex of the mine is less or equal to the price in this period
% with a minimum return rate on investment of 10% (or whatever discount rate we are using)
% (industry is more like 11-16%, according to the article Bhappa and Guzman 1995. 
MODE_END_PERIOD_VALUE = 0;

%specify the order that the firms will make decision in. 2 in period t
%indicates that firm 2 will make a decision in t=2
orderOfFirms = repmat(decision_order,1,ceil((T+1)/numFirms));  %HARDCODE ALERT
orderOfFirms = orderOfFirms(1:T+1);

%there are 3 incentive mines per player, 3 players,  a variable that
%indicates which player is making decision in a period,  5 levels of
%permanent demand change, and 5 levels of ROW supply expansions
% Va etc store the optimal value
Va = zeros(2,2,2,2,2,2,2,2,2,numFirms,5, 4,T+1); 
Vb = zeros(2,2,2,2,2,2,2,2,2,numFirms,5, 4,T+1);
Vc = zeros(2,2,2,2,2,2,2,2,2,numFirms,5, 4,T+1);
%optimal actions built as a cell array, because each cell could have more
%than 1 action that is optimal
Xa = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T+1); 
Xb = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T+1);
Xc = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T+1);
Prices = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T);
Quantities = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T);
CapUtils = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T);
% Faces = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T);

%MONOPOLY NPV of profit -- where the results are stored
V_mono = zeros(2,2,2,2,2,2,2,2,2,numFirms,5, 4,T+1); 
%optimal actions built as a cell array, because each cell could have more
%than 1 action that is optimal
Xa_mono = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T+1); 
Xb_mono = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T+1);
Xc_mono = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T+1);
Prices_mono = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T);
Quantities_mono = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T);
CapUtils_mono = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T);
% Faces_mono = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T);


%%
%%Demand settings
%demand elasticity
el = 0.5; 
%demand level and growth
%D_0 = 1100;   %base demand
D_0 = 2800;   %base demand
%D_growth = dgrowth_list{list_num};   %demand growth rate
D_growth = [0.01, 0.01];

%populate the demand series 
Demand = ones(1,T)*D_0;
Demand_yr = ones(1,T_years)*D_0; 
for t_yr=2:14
    Demand_yr(t_yr) = Demand_yr(t_yr-1)*(1+D_growth(1));
end

for t_yr=15:T_years
    Demand_yr(t_yr) = Demand_yr(t_yr-1)*(1+D_growth(2));
end


if(T==T_years)
    Demand = Demand_yr; 
else
    for t=1:T
        if(mod(t,decisions_in_dt)==1)
            Demand(t) = Demand_yr(ceil(t/decisions_in_dt));
        else
            Demand(t) = Demand(t-1);
        end
    end 
end

%demand perturbation range and prob
% D_fluct = perturb_list{list_num};  %TODO: THIS CANNOT BE ZERO AT THE MOMENT. NEED TO SAFETY CHECK
D_fluct = 0.95;
D_prob = [0.1, 0.8, 0.1];

%the change associated with a state variable on whether demand has been permanently changed due to a
%high demand/low demand event (demand never fully recovers from large
%swings because of semi-permanent substitution (DPERM)
DPERM_change = 0.05; % +5% change in non-shocked demand if DPERM is 1, and 10% if it's 2. 


%%
%Settings for new mines belonging to the big 3 players, ie incentive curves. The columns are ownerID, capacity, opex, and
%capex respectively
if(strcmp(SUPPLYCURVE_MODE,'base'))
    IncentiveCurveA = [1	140	26	6956
                        1	107	29	12853
                        1	97	30	13119];

    IncentiveCurveB = [2	113	32	13233
                        2	104	33	12349
                        2	229	34	35345];

    IncentiveCurveC = [3	178	33	21474
                        3	94	35	7444
                        3	90	40	15603];

elseif(strcmp(SUPPLYCURVE_MODE,'equalIncPrice'))
    IncentiveCurveA = [1	140	26	6956
                        1	107	33	8473
                        1	97	40	13119];

    IncentiveCurveB = [2	113	26	5614
                        2	104	33	8236
                        2	229	40	30972];

    IncentiveCurveC = [3	178	26	8844
                        3	94	33	7444
                        3	90	40	12172];

elseif(strcmp(SUPPLYCURVE_MODE,'equalSupply'))
    IncentiveCurveA = [1	185	26	9191.9
                        1	101	33	7998.3
                        1	98	40	13254.2];

    IncentiveCurveB = [2	185	26	9191.9
                        2	101	33	7998.3
                        2	98	40	13254.2];

    IncentiveCurveC = [3	185	26	9191.9
                        3	101	33	7998.3
                        3	98	40	13254.2];    
                    
elseif(strcmp(SUPPLYCURVE_MODE,'equalS_moreMajor'))
    IncentiveCurveA = [1	261.6	26	12999.9
                        1	142.8	33	11311.9
                        1	138.6	40	18745.3];

    IncentiveCurveB = [2	261.6	26	12999.9
                        2	142.8	33	11311.9
                        2	138.6	40	18745.3];

    IncentiveCurveC = [3	261.6	26	12999.9
                        3	142.8	33	11311.9
                        3	138.6	40	18745.3];  
                    
elseif(strcmp(SUPPLYCURVE_MODE,'base_moreMajor'))
    IncentiveCurveA = [1	198.0	26	9837.8
                        1	151.3	29	18177.8
                        1	137.2	30	18554.0];

    IncentiveCurveB = [2	159.8	32	18715.2
                        2	147.1	33	17465.0
                        2	323.9	34	49987.9];

    IncentiveCurveC = [3	251.7	33	30370.4
                        3	132.9	35	10527.9
                        3	127.3	40	22067.1];  

elseif(strcmp(SUPPLYCURVE_MODE,'base_moreMajor_noIncVChange'))
    IncentiveCurveA = [1	140.0	26	6956
                        1	107.0	29	12853
                        1	97.0	30	13119];

    IncentiveCurveB = [2	113.0	32	13233
                        2	104.0	33	12349
                        2	229.0	34	35345];

    IncentiveCurveC = [3	178.0	33	21474
                        3	94.0	35	7444
                        3	90.0	40	15603];  
                    
elseif(SUPPLYCURVE_MODE==1)
    IncentiveCurveA = [1	70	43	5600
                        1	50	47	10247
                        1	50	49	10417];

    IncentiveCurveB = [2	50	52	9629
                        2	110	57	28211
                        2	55	49	10754];

    IncentiveCurveC = [3	90	54	16700
                        3	45	54	5445
                        3	45	67	11354];
elseif(SUPPLYCURVE_MODE==-1)

    % Reduced capex incentive curve (so that shorter periods would still have
    % mine openings)
    IncentiveCurveA = [1	70	43	560
                        1	50	47	1025
                        1	50	49	1042];

    IncentiveCurveB = [2	50	52	963
                        2	110	57	2821
                        2	55	49	1075];

    IncentiveCurveC = [3	90	54	1670
                        3	45	54	544
                        3	45	67	1135];
elseif(SUPPLYCURVE_MODE==-2)
    % %Dummy Incentive Curves
    IncentiveCurveA = [1	5	9	10
                        1	5	10	10
                        1	5	11	10];

    IncentiveCurveB = [2	5	9	10
                        2	5	10	10
                        2	5	11	10];

    IncentiveCurveC = [3	5	9	10
                        3	5	10	10
                        3	5	11	10];
    % %END OF DUMMY INCENTIVE CURVE
end

%Put all the incentive curves together into master incentive curve                
TotalIncentiveCurve = [IncentiveCurveA(1:numIncMines, :); 
                        IncentiveCurveB(1:numIncMines, :);
                        IncentiveCurveC(1:numIncMines, :)];
TotalIncCurve_byFirm = cell(3,1);
TotalIncCurve_byFirm{1} = IncentiveCurveA(1:numIncMines, :);
TotalIncCurve_byFirm{2} = IncentiveCurveB(1:numIncMines, :);
TotalIncCurve_byFirm{3} = IncentiveCurveC(1:numIncMines, :);

%%
%%Construct the rest of the world incentive curve, which will be start
%%production at certain price thresholds defined in the findPrice_new function. 
%%TODO: FILL OUT THE Rest of the World INCENTIVE CURVE WITH A REASONABLE
%%NUMBER OF MINES, EACH OF REASONABLE SIZE (compared to the 
ROWIncCurve =  cell(3,1); 

if(ROWINCCURVE_MODE==1)
    ROWIncCurve{1} =   [4	20	1
                        4	20	1
                        4	20	1
                        4	20	1
                        4	20	1
                        4	20	1];
    ROWIncCurve{2} =   [4	20	1
                        4	20	1
                        4	20	1
                        4	20	1
                        4	20	1
                        4	20	1];
    ROWIncCurve{3} =   [4	20	1
                        4	20	1
                        4	20	1
                        4	20	1
                        4	20	1
                        4	20	1];    
    
else
    ROWIncCurve{1} =   [4	20	60.5
                        4	20	61
                        4	20	61.5
                        4	20	62
                        4	20	62.5
                        4	20	63];
    ROWIncCurve{2} =   [4	20	72.5
                        4	20	73
                        4	20	73.5
                        4	20	74
                        4	20	74.5
                        4	20	75];
    ROWIncCurve{3} =   [4	20	90.5
                        4	20	91
                        4	20	91.5
                        4	20	92
                        4	20	92.5
                        4	20	93];
end 

%%
%%Supply curve - assume it doesn't change over time
% structure is owner, quantity, cost
% the supply curve has places held for the incentive elements, so that it
% doesn't need to be resized and slow down the code in findprice_new
incSupLength = size(TotalIncentiveCurve,1) + size(ROWIncCurve{1},1) + size(ROWIncCurve{2},1) + size(ROWIncCurve{3},1); 
SupplyCurve = zeros(95+incSupLength,3,T);
if(or(strcmp(SUPPLYCURVE_MODE,'base'), strcmp(SUPPLYCURVE_MODE,'equalIncPrice')))
    %fill the owner of the placeholders for the potential incentive mines with 
    % 4 to prevent index 0 in a later part of the program for a mine not opened
    SupplyCurve(1:incSupLength,1,1) = 4; 
    %inflated highest price Q to never run out of supply
    SupplyCurve(incSupLength+1:end,:,1) = [4	32	9.7
                        4	19	15.6
                        4	32	21.8
                        3	5	24.1
                        3	95	24.5
                        4	30	24.9
                        2	157	25.5
                        3	18	26.2
                        3	98	26.4
                        3	6	27.4
                        3	49	29.6
                        2	50	29.7
                        2	77	29.8
                        2	89	29.9
                        3	187	30
                        2	53	30.2
                        1	611	30.2
                        4	67	30.4
                        4	97	30.6
                        3	9	33.8
                        4	73	34.7
                        3	9	35.2
                        4	95	37
                        4	140	38.5
                        4	76	39.5
                        1	24	40.3
                        4	60	41.2
                        4	41	41.4
                        4	179	41.4
                        3	4	42
                        4	57	42.8
                        3	43	45.3
                        3	12	46
                        4	164	46.9
                        4	53	47.2
                        4	30	48
                        4	33	49
                        1	9	51.1
                        4	59	52.9
                        4	66	52.9
                        4	34	53.5
                        4	38	56.3
                        4	46	56.7
                        4	34	57.9
                        3	19	60.7
                        4	27	61.6
                        4	31	62.5
                        4	38	66.2
                        4	54	66.2
                        4	22	70.1
                        4	36	72
                        4	21	73
                        4	19	73.8
                        4	10	77.5
                        4	19	79.4
                        4	24	80.2
                        4	26	83.2
                        4	16	85.6
                        4	42	92.2
                        4	11	97.1
                        4	8	97.2
                        4	4	104.3
                        4	4	105.9
                        4	4	107.5
                        4	2	112.7
                        4	5	126
                        4	6	130.2
                        4	7	138.7
                        4	9	143.2
                        4	8	144.8
                        4	8	146.1
                        4	6	147.4
                        4	8	150.2
                        4	8	150.3
                        4	8	150.3
                        4	8	150.7
                        4	8	152.3
                        4	8	152.8
                        4	8	153
                        4	8	153.2
                        4	8	153.2
                        4	8	154.4
                        4	7	155.2
                        4	8	155.6
                        4	9	155.7
                        4	8	156.1
                        4	8	157.2
                        4	8	157.6
                        4	8	157.7
                        4	8	158.3
                        4	8	159.8
                        4	8	160
                        4	8	162.8
                        4	7	167.6
                        4	7	168.6];
    
elseif(strcmp(SUPPLYCURVE_MODE,'equalSupply'))
    %fill the owner of the placeholders for the potential incentive mines with 
    % 4 to prevent index 0 in a later part of the program for a mine not opened
    SupplyCurve(1:incSupLength,1,1) = 4; 
    %inflated highest price Q to never run out of supply
    SupplyCurve(incSupLength+1:end,:,1) = [4	32	9.7
4	19	15.6
4	32	21.8
1	95	24.5
2	95	24.5
3	95	24.5
4	30	24.9
1	116	26.4
2	116	26.4
3	116	26.4
1	236	30
2	236	30
3	236	30
4	67	30.4
4	97	30.6
4	73	34.7
1	19	35.2
2	19	35.2
3	19	35.2
4	95	37
4	140	38.5
4	76	39.5
4	60	41.2
4	41	41.4
4	179	41.4
4	57	42.8
1	44.3	45.3
2	44.3	45.3
3	44.3	45.3
1	12	46
2	12	46
3	12	46
4	164	46.9
4	53	47.2
4	30	48
4	33	49
4	59	52.9
4	66	52.9
4	34	53.5
4	38	56.3
4	46	56.7
4	34	57.9
1	19	60.7
2	19	60.7
3	19	60.7
4	27	61.6
4	31	62.5
4	38	66.2
4	54	66.2
4	22	70.1
4	36	72
4	21	73
4	19	73.8
4	10	77.5
4	19	79.4
4	24	80.2
4	26	83.2
4	16	85.6
4	42	92.2
4	11	97.1
4	8	97.2
4	4	104.3
4	4	105.9
4	4	107.5
4	2	112.7
4	5	126
4	6	130.2
4	7	138.7
4	9	143.2
4	8	144.8
4	8	146.1
4	6	147.4
4	8	150.2
4	8	150.3
4	8	150.3
4	8	150.7
4	8	152.3
4	8	152.8
4	8	153
4	8	153.2
4	8	153.2
4	8	154.4
4	7	155.2
4	8	155.6
4	9	155.7
4	8	156.1
4	8	157.2
4	8	157.6
4	8	157.7
4	8	158.3
4	8	159.8
4	8	160
4	8	162.8
4	7	167.6
4	7	168.6];

elseif(strcmp(SUPPLYCURVE_MODE,'equalS_moreMajor'))
    %fill the owner of the placeholders for the potential incentive mines with 
    % 4 to prevent index 0 in a later part of the program for a mine not opened
    SupplyCurve(1:incSupLength,1,1) = 4; 
    %inflated highest price Q to never run out of supply
    SupplyCurve(incSupLength+1:end,:,1) = [4	22.2	9.7
4	13.2	15.6
4	22.2	21.8
1	134.4	24.5
2	134.4	24.5
3	134.4	24.5
4	20.8	24.9
1	164.1	26.4
2	164.1	26.4
3	164.1	26.4
1	333.8	30
2	333.8	30
3	333.8	30
4	46.5	30.4
4	67.4	30.6
4	50.7	34.7
1	26.9	35.2
2	26.9	35.2
3	26.9	35.2
4	66.0	37
4	97.3	38.5
4	52.8	39.5
4	41.7	41.2
4	28.5	41.4
4	124.4	41.4
4	39.6	42.8
1	62.7	45.3
2	62.7	45.3
3	62.7	45.3
1	17.0	46
2	17.0	46
3	17.0	46
4	113.9	46.9
4	36.8	47.2
4	20.8	48
4	22.9	49
4	41.0	52.9
4	45.9	52.9
4	23.6	53.5
4	26.4	56.3
4	32.0	56.7
4	23.6	57.9
1	26.9	60.7
2	26.9	60.7
3	26.9	60.7
4	18.8	61.6
4	21.5	62.5
4	26.4	66.2
4	37.5	66.2
4	15.3	70.1
4	25.0	72
4	14.6	73
4	13.2	73.8
4	6.9	77.5
4	13.2	79.4
4	16.7	80.2
4	18.1	83.2
4	11.1	85.6
4	29.2	92.2
4	7.6	97.1
4	5.6	97.2
4	2.8	104.3
4	2.8	105.9
4	2.8	107.5
4	1.4	112.7
4	3.5	126
4	4.2	130.2
4	4.9	138.7
4	6.3	143.2
4	5.6	144.8
4	5.6	146.1
4	4.2	147.4
4	5.6	150.2
4	5.6	150.3
4	5.6	150.3
4	5.6	150.7
4	5.6	152.3
4	5.6	152.8
4	5.6	153
4	5.6	153.2
4	5.6	153.2
4	5.6	154.4
4	4.9	155.2
4	5.6	155.6
4	6.3	155.7
4	5.6	156.1
4	5.6	157.2
4	5.6	157.6
4	5.6	157.7
4	5.6	158.3
4	5.6	159.8
4	5.6	160
4	5.6	162.8
4	4.9	167.6
4	4.9	168.6];

elseif(or(strcmp(SUPPLYCURVE_MODE,'base_moreMajor'),strcmp(SUPPLYCURVE_MODE,'base_moreMajor_noIncVChange')))
    %fill the owner of the placeholders for the potential incentive mines with 
    % 4 to prevent index 0 in a later part of the program for a mine not opened
    SupplyCurve(1:incSupLength,1,1) = 4; 
    %inflated highest price Q to never run out of supply
    SupplyCurve(incSupLength+1:end,:,1) = [4	22.2	9.7
4	13.2	15.6
4	22.2	21.8
3	7.1	24.1
3	134.4	24.5
4	20.8	24.9
2	222.0	25.5
3	25.5	26.2
3	138.6	26.4
3	8.5	27.4
3	69.3	29.6
2	70.7	29.7
2	108.9	29.8
2	125.9	29.9
3	264.5	30
1	864.1	30.2
2	75.0	30.2
4	46.5	30.4
4	67.4	30.6
3	12.7	33.8
4	50.7	34.7
3	12.7	35.2
4	66.0	37
4	97.3	38.5
4	52.8	39.5
1	33.9	40.3
4	41.7	41.2
4	28.5	41.4
4	124.4	41.4
3	5.7	42
4	39.6	42.8
3	60.8	45.3
3	17.0	46
4	113.9	46.9
4	36.8	47.2
4	20.8	48
4	22.9	49
1	12.7	51.1
4	41.0	52.9
4	45.9	52.9
4	23.6	53.5
4	26.4	56.3
4	32.0	56.7
4	23.6	57.9
3	26.9	60.7
4	18.8	61.6
4	21.5	62.5
4	26.4	66.2
4	37.5	66.2
4	15.3	70.1
4	25.0	72
4	14.6	73
4	13.2	73.8
4	6.9	77.5
4	13.2	79.4
4	16.7	80.2
4	18.1	83.2
4	11.1	85.6
4	29.2	92.2
4	7.6	97.1
4	5.6	97.2
4	2.8	104.3
4	2.8	105.9
4	2.8	107.5
4	1.4	112.7
4	3.5	126
4	4.2	130.2
4	4.9	138.7
4	6.3	143.2
4	5.6	144.8
4	5.6	146.1
4	4.2	147.4
4	5.6	150.2
4	5.6	150.3
4	5.6	150.3
4	5.6	150.7
4	5.6	152.3
4	5.6	152.8
4	5.6	153
4	5.6	153.2
4	5.6	153.2
4	5.6	154.4
4	4.9	155.2
4	5.6	155.6
4	6.3	155.7
4	5.6	156.1
4	5.6	157.2
4	5.6	157.6
4	5.6	157.7
4	5.6	158.3
4	5.6	159.8
4	5.6	160
4	5.6	162.8
4	4.9	167.6
4	4.9	168.6];


elseif(SUPPLYCURVE_MODE==1)
    %fill the owner of the placeholders for the potential incentive mines with 
    % 4 to prevent index 0 in a later part of the program for a mine not opened
    SupplyCurve(1:incSupLength,1,1) = 4; 
    %inflated highest price Q to never run out of supply
    SupplyCurve(incSupLength+1:end,:,1) = [4	16	15
                        4	9	25
                        4	15	35
                        2	74	39
                        3	46	40
                        3	2	40
                        3	50	42
                        3	9	43
                        4	14	43
                        3	3	44
                        2	40	46
                        3	102	46
                        3	24	47
                        2	42	47
                        2	24	48
                        4	36	48
                        2	25	49
                        1	289	49
                        4	48	51
                        4	36	54
                        3	5	54
                        3	4	55
                        4	47	56
                        4	37	59
                        4	71	61
                        4	21	64
                        1	12	65
                        4	29	66
                        3	2	66
                        4	88	69
                        4	28	71
                        4	26	74
                        3	21	76
                        3	6	76
                        4	80	76
                        4	16	79
                        4	16	81
                        4	30	84
                        4	33	86
                        1	5	86
                        4	16	89
                        4	22	91
                        4	17	94
                        3	9	96
                        4	19	96
                        4	14	99
                        4	19	101
                        4	16	104
                        4	25	106
                        4	11	109
                        4	11	111
                        4	9	114
                        4	17	116
                        4	12	119
                        4	10	123
                        4	5	128
                        4	14	133
                        4	8	138
                        4	6	143
                        4	21	148
                        4	4	153
                        4	2	163
                        4	2	168
                        4	2	175
                        4	1	185
                        4	3	195
                        4	3	205
                        4	3	225
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245
                        4	4	245];
elseif(SUPPLYCURVE_MODE==-3)
    SupplyCurve(1:44,:,1) = [1	289	49
            1	12	65
            1	5	86
            2	74	39
            2	40	46
            2	42	47
            2	24	48
            2	25	49
            3	46	40
            3	2	40
            3	50	42
            3	9	43
            3	3	44
            3	102	46
            3	24	47
            3	5	54
            3	4	55
            3	2	66
            3	6	76
            3	21	76
            3	9	96
            4	0	5
            4	16	15
            4	9	25
            4	15	35
            4	49	45
            4	169	55
            4	209	65
            4	150	75
            4	95	85
            4	72	95
            4	70	105
            4	48	115
            4	15	125
            4	22	135
            4	27	145
            4	4	155
            4	4	165
            4	2	175
            4	1	185
            4	3	195
            4	3	205
            4	3	225
            4	10	245];  
    %inflate highest price Q to never run out of supply
    highcostQ = repmat([4 2 245], (95-44),1);
    SupplyCurve(45:95,:,1) = highcostQ;
end
%sort the supply by opex to reduce later sorting time
SupplyCurve(:,:,1) = sortrows(SupplyCurve(:,:,1),3);

% %DUMMY Supply Curve
% SupplyCurve = zeros(12,3,T);
% SupplyCurve(:,:,1) = [  1	200	50
%                         1	200	100
%                         1	200	150
%                         1	200	200
%                         2	200	50
%                         2	200	100
%                         2	200	150
%                         2	200	200
%                         3	200	50
%                         3	200	100
%                         3	200	150
%                         3	200	200];
% SupplyCurve(:,:,1) = sortrows(SupplyCurve(:,:,1),3);
%
% %END OF DUMMY SUPPLY CURVE 


%Assume a base supply curve that is constant over the time periods
%Populate the supply curve for the future
for t=2:T
    SupplyCurve(:,:,t) = SupplyCurve(:,:,1);
end

                
%%                    
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

%%
%Output the key to control window and diary
fprintf('**************PARAMETERS USED********************\n');
fprintf('****BASIC SETUP***\n');
MODE_MKT_CLEAR_AFTER_ALL_DECIDE
MODE_END_PERIOD_VALUE
SUPPLYCURVE_MODE
ROWINCCURVE_MODE
fprintf('The order of firms making decisions is:  ');
disp(orderOfFirms(1:numFirms));
disp(T);
disp(decisions_in_dt);
fprintf('Number of years in simulation: %d\n', ceil(T/decisions_in_dt));

fprintf('****DEMAND SETUP***\n');
el
D_0
D_growth
Demand
D_fluct
D_prob
DPERM_change
fprintf('Where base demand and supply should meet: %d\n', baseQ);
rich_a

fprintf('****SUPPLY SETUP***\n');
SupplyCurve(:,:,1)
fprintf('Supply curve is constant over time\n');

fprintf('****INCENTIVE CURVE***\n');
TotalIncentiveCurve
ROWIncCurve{1}
ROWIncCurve{2}
ROWIncCurve{3}


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%SOLVING FOR THE OPTIMAL POLICY USING FIRM NPV + GAME THEORY DECISION
%%CRITERIA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%value for terminal period
%MAYBETODO: terminal state do not need to be everything shut down
Va(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Vb(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Vc(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Xa(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Xb(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Xc(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;

%MONOPOLY value and action variables initiation 
Va_mono(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Vb_mono(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Vc_mono(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Xa_mono(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Xb_mono(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;
Xc_mono(:,:,:,:,:,:,:,:,:,:,:,:,T+1) = 0;


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
    for SUPSHIFT = 1:(size(ROWIncCurve, 1)+1)
        
        %identify of the player who is currently making an expansion decision
        currentFirm = orderOfFirms(t); 
        currentIncCurve = TotalIncCurve_byFirm{currentFirm};     

        %fill the value matrix with the default action that no
        %one is opening anything
        bestVabc = zeros(3,1);
        bestXabc = zeros(3,1);
        bestP = 0;
        bestQ = 0;
        bestCapUtil=0;

        bestV_mono=0; 
        bestXabc_mono = zeros(3,1);
        bestP_mono = 0;
        bestQ_mono = 0;
        bestCapUtil_mono=0;
        
        for mine=0:numIncMines     %Problem assumes that a firm can only open 1 mine per period
            %check to see if mine is already open. if so then skip. 
            if(mine~=0 && MinesOpened((currentFirm-1)*numIncMines+mine) == 2)
                continue;
            end

            capexABC = zeros(3,1); 


            %calculate the relevant outcome for A given this action
            %TODO: could incorporate delay in opening (currently no
            %delay)
            MinesOpened_updated = MinesOpened + [and(currentFirm==1,mine==1),and(currentFirm==1,mine==2),and(currentFirm==1,mine==3)...
                                    ,and(currentFirm==2,mine==1),and(currentFirm==2,mine==2),and(currentFirm==2,mine==3)...
                                    ,and(currentFirm==3,mine==1),and(currentFirm==3,mine==2),and(currentFirm==3,mine==3)];

            if(or(MODE_MKT_CLEAR_AFTER_ALL_DECIDE == 0, mod(t,decisions_in_dt)==0)) 
                %market clearing and reward calculation 
                [market_p, market_q, cap_util, rewards, ~, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, SUPSHIFT, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve, ROWIncCurve);
                %return   %DEBUG this break is just to run the findPrice function once
                %display('As turn - prices');

                %record the total number of times the intersection hit the
                %face of a supply step cliff for a given set of state vars
%                 Faces(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = sum(faces) + Faces(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t);

                %Calculate this period expected reward for A
                rewardABC = zeros(3,1); 
                rewardABC(1) = sum(rewards(1,:).*D_prob);
                rewardABC(2) = sum(rewards(2,:).*D_prob);
                rewardABC(3) = sum(rewards(3,:).*D_prob);
                if(mine~=0)
                    capexABC(currentFirm) = currentIncCurve(mine,4); 
                end

                %calculate next mine opening states after the new mine
                %opening this period (if any)
                nextS = MinesOpened_updated; %next state of openings
                %Calculate expected future periods rewards (using state transitions) for each of the players  
                v_a = zeros(1,length(D_prob));
                v_b = zeros(1,length(D_prob));
                v_c = zeros(1,length(D_prob));
                v_mono = zeros(1,length(D_prob));
                for d = 1:length(D_prob)
                    [nextDPerm] = demandPermChange(DPERM, market_p(d));
                    [nextSUPSHIFT] = SupShiftChange(SUPSHIFT, market_p(d));
                    v_a(d) = D_prob(d)*Va(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,nextSUPSHIFT,t+1);
                    v_b(d) = D_prob(d)*Vb(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,nextSUPSHIFT,t+1);
                    v_c(d) = D_prob(d)*Vc(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,nextSUPSHIFT,t+1);
                    v_mono(d) = D_prob(d)*V_mono(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,nextSUPSHIFT,t+1);
                end

                v_abc = [(1-dr)*sum(v_a); (1-dr)*sum(v_b); (1-dr)*sum(v_c)];
                totalVabc = rewardABC + v_abc - capexABC;
                totalV_mono = sum(rewardABC - capexABC) + (1-dr)*sum(v_mono); 

            else %for intermediate periods where market doesn't clear
                %figure out where you would go next
                %nextS = [A1+(a==1),A2+(a==2),A3+(a==3),B1+(b==1),B2+(b==2),B3+(b==3),C1+(c==1),C2+(c==2),C3+(c==3)]; %next state of openings
                nextS = MinesOpened_updated; 
                nextDPerm = DPERM;
                nextSUPSHIFT = SUPSHIFT; 

                %adjust for any capex incurred by the decision to open
                if(mine~=0)
                    capexABC(currentFirm) = currentIncCurve(mine,4);
                end

                totalVa = Va(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,nextSUPSHIFT,t+1)-capexABC(1);
                totalVb = Vb(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,nextSUPSHIFT,t+1)-capexABC(2);
                totalVc = Vc(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,nextSUPSHIFT,t+1)-capexABC(3);
                totalVabc = [totalVa; totalVb; totalVc];
                totalV_mono = V_mono(nextS(1),nextS(2),nextS(3),nextS(4),nextS(5),nextS(6),nextS(7),nextS(8),nextS(9),orderOfFirms(t+1),nextDPerm,nextSUPSHIFT,t+1) - sum(capexABC); 
            end 

            %If it is the best V so far, replace the current best V
            %TODO: what if they tie?
            if(totalVabc(currentFirm)>bestVabc(currentFirm))
                bestVabc = totalVabc;
                bestXabc(currentFirm) = mine;
                if(or(MODE_MKT_CLEAR_AFTER_ALL_DECIDE == 0, mod(t,decisions_in_dt)==0)) 
                    bestP = sum(D_prob.*market_p);
                    bestQ = sum(D_prob.*market_q);
                    bestCapUtil = sum(D_prob.*cap_util);
                end
            end

            if(totalV_mono>bestV_mono)
                bestV_mono = totalV_mono;
                bestXabc_mono(currentFirm) = mine; 
                if(or(MODE_MKT_CLEAR_AFTER_ALL_DECIDE == 0, mod(t,decisions_in_dt)==0)) 
                    bestP_mono = sum(D_prob.*market_p);
                    bestQ_mono = sum(D_prob.*market_q);
                    bestCapUtil_mono = sum(D_prob.*cap_util);
                end
            end

        end            

        %Store the best actions and values etc
        Va(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestVabc(1);
        Vb(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestVabc(2);
        Vc(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestVabc(3);
        Xa(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestXabc(1); 
        Xb(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestXabc(2);
        Xc(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestXabc(3);
        
        V_mono(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestV_mono;
        Xa_mono(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestXabc_mono(1);
        Xb_mono(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestXabc_mono(2);
        Xc_mono(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestXabc_mono(3);
        
        if(or(MODE_MKT_CLEAR_AFTER_ALL_DECIDE == 0, mod(t,decisions_in_dt)==0)) 
            Prices(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestP;
            Quantities(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestQ;
            CapUtils(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestCapUtil;

            Prices_mono(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestP_mono;
            Quantities_mono(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestQ_mono;
            CapUtils_mono(A1,A2,A3,B1,B2,B3,C1,C2,C3,currentFirm,DPERM,SUPSHIFT,t) = bestCapUtil_mono;
            
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
end
    


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%CALC OPTIMAL POLICY FOR MAXING FIRM NPV, NO GAME THEORY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%
%parameters of the simulations
simNum = 10;   %number of simulation
sim_dr = dr;
sim_orderOfFirms = orderOfFirms;

%demand fluctuation range and prob
sim_D_fluct = D_fluct;
sim_D_prob = D_prob;
sim_Demand = Demand;

%the change associated with a state variable on whether demand has been permanently changed due to a
%high demand/low demand event (demand never fully recovers from large
%swings because of semi-permanent substitution (DPERM)
sim_DPERM_change = DPERM_change; % +10% change in non-shocked demand if DPERM is 1, and 20% if it's 2. 


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%SIMULATION OF THE FIRM NPV BASED POLICIES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Simulate the game with the demand uncertainty. See how the price path
% unfolds using the optimal policy. Compare against a dummy policy and
% compare. 

%dummy base policy of not opening no matter what the conditions are
Xa_1 = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T+1);
Xb_1 = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T+1);
Xc_1 = zeros(2,2,2,2,2,2,2,2,2,numFirms,5,4,T+1);

%"smarter" policy to test
Xa_2 = Xa;
Xb_2 = Xb;
Xc_2 = Xc;


%output to be recorded
sim_Prices_1 = zeros(T_years, simNum);
sim_Q_1 = zeros(T_years, simNum);
sim_CapUtil_1 = zeros(T_years, simNum);
sim_Faces_1 = zeros(T_years, simNum); %when it crossed the cliff face of supply curve
sim_V_1 = zeros(numFirms, simNum);
sim_openings_1 = zeros(numIncMines, numFirms, simNum);
sim_diag_1 = cell(T_years,simNum);    %cell array to store the diagnostics from each market clearing
sim_firm_Q_1 = zeros(numFirms, T_years, simNum);

sim_Prices_2 = zeros(T_years, simNum);
sim_Q_2 = zeros(T_years, simNum);
sim_CapUtil_2 = zeros(T_years, simNum);
sim_Faces_2 = zeros(T_years, simNum);
sim_V_2 = zeros(numFirms, simNum);
%record the time period each mine opened (if they did at all)
sim_openings_2 = zeros(numIncMines, numFirms, simNum);
sim_diag_2 = cell(T_years,simNum);    %cell array to store the diagnostics from each market clearing
sim_firm_Q_2 = zeros(numFirms, T_years, simNum);

%name of the diagnostic entries
sim_diag_names = cell(1,1);

%simulate for the different policies
%reset random stream when simulate each in order to get the same demand
%conditions for each policy
stream = RandStream.getGlobalStream;
reset(stream);
[sim_openings_1, sim_Prices_1, sim_Q_1, sim_D_1, sim_firm_Q_1, sim_V_1, sim_Vt_1, sim_Turnovers_1, sim_CapUtil_1, sim_Faces_1, sim_diag_1, sim_diag_names] ...
    = simulation(Xa_1, Xb_1, Xc_1, simNum, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change,...
    IncentiveCurveA, IncentiveCurveB, IncentiveCurveC, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, ROWIncCurve);

stream = RandStream.getGlobalStream;
reset(stream);
[sim_openings_2, sim_Prices_2, sim_Q_2, sim_D_2, sim_firm_Q_2, sim_V_2, sim_Vt_2, sim_Turnovers_2, sim_CapUtil_2, sim_Faces_2, sim_diag_2, ~] ...
    = simulation(Xa_2, Xb_2, Xc_2, simNum, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change,...
    IncentiveCurveA, IncentiveCurveB, IncentiveCurveC, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, ROWIncCurve);

stream = RandStream.getGlobalStream;
reset(stream);
[sim_openings_mono, sim_Prices_mono, sim_Q_mono, sim_D_mono, sim_firm_Q_mono, sim_V_mono, sim_Vt_mono, sim_Turnovers_mono,sim_CapUtil_mono, sim_Faces_mono, sim_diag_mono, ~] ...
    = simulation(Xa_mono, Xb_mono, Xc_mono, simNum, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change,...
    IncentiveCurveA, IncentiveCurveB, IncentiveCurveC, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, ROWIncCurve);

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%POSITIVE MINE NPV CRITERIA OPTIMAL DECISION CALC AND SIMULATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%parameters of the simulations
simNum3 = simNum; 

stream = RandStream.getGlobalStream;
reset(stream);
[sim_openings_3, sim_Prices_3, sim_Q_3, sim_D_3, sim_firm_Q_3, sim_V_3, sim_Vt_3, sim_Turnovers_3, sim_CapUtil_3, sim_Faces_3, sim_diag_3] = ...
    mine_NPV_DPandSim(simNum3, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change, ...
    T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, TotalIncCurve_byFirm, ROWIncCurve);




%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%POSITIVE FIRM NPV CRITERIA OPTIMAL DECISION CALC AND SIMULATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
simNum4 = simNum; 

stream = RandStream.getGlobalStream;
reset(stream);
[sim_openings_4, sim_Prices_4, sim_Q_4, sim_D_4, sim_firm_Q_4, sim_V_4, sim_Vt_4, sim_Turnovers_4, sim_CapUtil_4, sim_Faces_4, sim_diag_4] = ...
    firm_NPV_DPandSim(simNum4, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change, ...
    T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, TotalIncCurve_byFirm, ROWIncCurve);


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%SIMULATION: What happens if one or more firms use firm-NPV maximizing
%%strategy, but against competitors who use the mine NPV maximizing
%%paradigm? 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%PLOTTING OF THE RESULTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Plots for comparison the price, quantity and NPV outcomes under policy 1 and 2
%FIGURE 1 compare the price
colormap(lines(7)); 
fig = figure(1);
clf('reset');
set(fig, 'units','normalized','position',[0.1 0.1 0.5 0.4]); 
time = 1:T_years;
plot(time, sim_Prices_1(:,1), time, sim_Prices_2(:,1), time, sim_Prices_3(:,1), time, sim_Prices_4(:,1), time, sim_Prices_mono(:,1),'LineWidth',2);
hold on
plot(time, max(sim_Prices_1,[],2), '--',time, max(sim_Prices_2,[],2), '--',time, max(sim_Prices_3,[],2), '--',time, max(sim_Prices_4,[],2), '--', time, max(sim_Prices_mono,[],2),'--', 'LineWidth',1);
hold on
plot(time, min(sim_Prices_1,[],2), '--',time, min(sim_Prices_2,[],2), '--',time, min(sim_Prices_3,[],2), '--',time, min(sim_Prices_4,[],2), '--',time, min(sim_Prices_mono,[],2),'--', 'LineWidth',1);
hold off
p_min = min(min(min([sim_Prices_1 sim_Prices_2 sim_Prices_3 sim_Prices_4 sim_Prices_mono])))-5;
p_max = max(max(max([sim_Prices_1 sim_Prices_2 sim_Prices_3 sim_Prices_4 sim_Prices_mono])))+5;
axis([min(time) 30 p_min p_max])
fprintf('Price path of different policies, order(%s)\n', ordering);
sim_Prices_1
sim_Prices_2
sim_Prices_3
sim_Prices_4
sim_Prices_mono

leg1 = legend('no new opening', 'best firm-NPV policy', 'positive-mine-NPV policy', 'positive-firm-NPV policy', 'cartel policy', 'Location', 'Best');
set(leg1, 'Box', 'off', 'Color', 'none');


title(['Price Path (' ordering ')']);
xlabel('Year');
ylabel('Real price');

saveas(fig, [ordering '_' criteria2vary '_' num2str(list_num) '_price path.jpg']); 

%FIGURE 2 compare the market quantity over time
fig = figure(2);
clf('reset');
set(fig, 'units','normalized','position',[0.1 0.1 0.5 0.4]); 

plot(time, sim_Q_1(:,1), time, sim_Q_2(:,1), time, sim_Q_3(:,1), time, sim_Q_4(:,1), time, sim_Q_mono(:,1), time, sim_D_1(:,1), 'LineWidth',2);
hold on
plot(time, max(sim_Q_1,[],2), '--',time, max(sim_Q_2,[],2), '--',time, max(sim_Q_3,[],2),'--', time, max(sim_Q_4,[],2),'--', time, max(sim_Q_mono,[],2),'--', time, max(sim_D_1,[],2),'--', 'LineWidth',1);
hold on
plot(time, min(sim_Q_1,[],2), '--',time, min(sim_Q_2,[],2), '--',time, min(sim_Q_3,[],2), '--', time, min(sim_Q_4,[],2), '--', time, min(sim_Q_mono,[],2),'--', time, min(sim_D_1,[],2),'--','LineWidth',1);
hold off
q_min = min(min(min([sim_Q_1 sim_Q_2 sim_Q_3 sim_Q_4 sim_Q_mono sim_D_1])))-50;
q_max = max(max(max([sim_Q_1 sim_Q_2 sim_Q_3 sim_Q_4 sim_Q_mono sim_D_1])))+50;

axis([min(time) 30 q_min q_max])

fprintf('Quantity path of different policies: dummy, firm_NPV with game, postive mine NPV, market optimal\n');
sim_Q_1
sim_Q_2
sim_Q_3
sim_Q_4
sim_Q_mono

leg1 = legend('no new opening', 'best firm-NPV policy', 'positive-mine-NPV policy', 'positive-firm-NPV policy', 'cartel policy', 'Location', 'Best');
set(leg1, 'Box', 'off');
set(leg1, 'Color', 'none');


title(['Market Clearing Quantity (' ordering ')']);
xlabel('Year');
ylabel('Quantity');
saveas(fig, [ordering '_' criteria2vary '_' num2str(list_num) '_production path.jpg']); 


%%%
%plot the new mine openings
%%%
%get the new mine opening data into shape

sim_open_1 = zeros(T_years, 4, numFirms); 
sim_open_2 = zeros(T_years, 4, numFirms); 
sim_open_3 = zeros(T_years, 4, numFirms); 
sim_open_4 = zeros(T_years, 4, numFirms); 
sim_open_mono = zeros(T_years, 4, numFirms); 

for(c=1:numFirms)
    currentIncCurve = TotalIncCurve_byFirm{c};
    for(r=1:numIncMines)
        prod = currentIncCurve(r,2); 
        opex = currentIncCurve(r,3);
        capex = currentIncCurve(r,4);
        capexunit = 0; 
        if(prod~=0)
            capexunit = capex / prod; 
        end
        
        t = sim_openings_1(r,c,1);
        if(t~=0)
            sim_open_1(t,1,c) = prod; %production
            sim_open_1(t,2,c) =  opex; %opex
            sim_open_1(t,3,c) =  capex; %capex
            sim_open_1(t,4,c) = capexunit; %capex / unit production
        end
        
        t = sim_openings_2(r,c,1);
        if(t~=0)
            sim_open_2(t,1,c) = prod; %production
            sim_open_2(t,2,c) = opex; %opex
            sim_open_2(t,3,c) = capex; %capex
            sim_open_2(t,4,c) = capexunit; %capex / unit production
        end
        
        t = sim_openings_3(r,c,1);
        if(t~=0)
            sim_open_3(t,1,c) = prod; %production
            sim_open_3(t,2,c) = opex; %opex
            sim_open_3(t,3,c) = capex; %capex
            sim_open_3(t,4,c) = capexunit; %capex / unit production
        end
        
        t = sim_openings_4(r,c,1);
        if(t~=0)
            sim_open_4(t,1,c) = prod; %production
            sim_open_4(t,2,c) = opex; %opex
            sim_open_4(t,3,c) = capex; %capex
            sim_open_4(t,4,c) = capexunit; %capex / unit production
        end
        
        t = sim_openings_mono(r,c,1);
        if(t~=0)
            sim_open_mono(t,1,c) = prod; %production
            sim_open_mono(t,2,c) = opex; %opex
            sim_open_mono(t,3,c) = capex; %capex
            sim_open_mono(t,4,c) = capexunit; %capex / unit production
        end

    end
end


%plot the new openings - quantity versus overall market quantity
fig = figure(3);
clf('reset');
set(fig, 'units','normalized','position',[0.1 0.1 0.5 1]); 
colormap(lines(7));

stackedbar = @(x, A) bar(x, A, 'stack');
prettyline = @(x, y) plot(x, y, 'k', 'LineWidth', 1);

subplot(5,1,1)

[ax, h1, h2] = plotyy(time, squeeze(sim_open_1(:,1,:)), time, sim_Q_1(:,1), stackedbar, prettyline);

set(ax(1), 'XLim', [0 T_years]);
set(ax(2), 'XLim', [0 T_years]);
set(ax(1), 'YLim',[0 max(TotalIncentiveCurve(:,2))*2]);
set(ax(2), 'YLim',[q_min q_max]);

linkaxes(ax, 'x'); 
set(ax(1),'Box','off')
set(ax(2),'Box','off')
set(ax(2), 'XTickLabel','','XAxisLocation','Top') 
title('No new opening');

set(ax(1), 'YTick', 0:100:(max(TotalIncentiveCurve(:,2))*2));
set(ax(2), 'YTick', 0:500:q_max);

ylabel(ax(1), 'New capacity');
ylabel(ax(2), 'Total quantity');

l = legend('Firm A openings', 'Firm B openings', 'Firm C openings', 'Market Quantity');
set(l,'PlotBoxAspectRatioMode','manual');
set(l,'PlotBoxAspectRatio',[1 0.35 1]);
set(l, 'Location', 'Best');

subplot(5,1,2)
[ax, h1, h2] = plotyy(time, squeeze(sim_open_2(:,1,:)), time, sim_Q_2(:,1), stackedbar, prettyline);

set(h1, 'EdgeColor','none'); 
set(ax(1), 'XLim', [0 T_years]);
set(ax(2), 'XLim', [0 T_years]);
set(ax(1), 'YLim',[0 max(TotalIncentiveCurve(:,2))*2]);
set(ax(2), 'YLim',[q_min q_max]);

linkaxes(ax, 'x'); 
set(ax(1),'Box','off')
set(ax(2),'Box','off')
set(ax(2), 'XTickLabel','','XAxisLocation','Top') 
title('Best firm-NPV policy');

set(ax(1), 'YTick', 0:100:(max(TotalIncentiveCurve(:,2))*2)); 
set(ax(2), 'YTick', 0:500:q_max);
ylabel(ax(1), 'New capacity');
ylabel(ax(2), 'Total quantity');

subplot(5,1,3)
[ax, h1, h2] = plotyy(time, squeeze(sim_open_3(:,1,:)), time, sim_Q_3(:,1), stackedbar, prettyline);

set(h1, 'EdgeColor','none'); 
set(ax(1), 'XLim', [0 T_years]);
set(ax(2), 'XLim', [0 T_years]);
set(ax(1), 'YLim',[0 max(TotalIncentiveCurve(:,2))*2]);
set(ax(2), 'YLim',[q_min q_max]);

linkaxes(ax, 'x'); 
set(ax(1),'Box','off')
set(ax(2),'Box','off')
set(ax(2), 'XTickLabel','','XAxisLocation','Top') 

set(ax(1), 'YTick', 0:100:(max(TotalIncentiveCurve(:,2))*2)); 
set(ax(2), 'YTick', 0:500:q_max);
ylabel(ax(1), 'New capacity');
ylabel(ax(2), 'Total quantity');
title('Positive mine-NPV policy');

subplot(5,1,4)
[ax, h1, h2] = plotyy(time, squeeze(sim_open_4(:,1,:)), time, sim_Q_4(:,1), stackedbar, prettyline);

set(h1, 'EdgeColor','none'); 
set(ax(1), 'XLim', [0 T_years]);
set(ax(2), 'XLim', [0 T_years]);
set(ax(1), 'YLim',[0 max(TotalIncentiveCurve(:,2))*2]);
set(ax(2), 'YLim',[q_min q_max]);

linkaxes(ax, 'x'); 
set(ax(1),'Box','off')
set(ax(2),'Box','off')
set(ax(2), 'XTickLabel','','XAxisLocation','Top') 

set(ax(1), 'YTick', 0:100:(max(TotalIncentiveCurve(:,2))*2)); 
set(ax(2), 'YTick', 0:500:q_max);
ylabel(ax(1), 'New capacity');
ylabel(ax(2), 'Total quantity');
title('Positive firm-NPV policy');


subplot(5,1,5)
[ax, h1, h2] = plotyy(time, squeeze(sim_open_mono(:,1,:)), time, sim_Q_mono(:,1), stackedbar, prettyline);

set(h1, 'EdgeColor','none'); 
set(ax(1), 'XLim', [0 T_years]);
set(ax(2), 'XLim', [0 T_years]);
set(ax(1), 'YLim',[0 max(TotalIncentiveCurve(:,2))*2]);
set(ax(2), 'YLim',[q_min q_max]);

linkaxes(ax, 'x'); 
set(ax(1),'Box','off')
set(ax(2),'Box','off')
set(ax(2), 'XTickLabel','','XAxisLocation','Top') 

set(ax(1), 'YTick', 0:100:(max(TotalIncentiveCurve(:,2))*2)); 
set(ax(2), 'YTick', 0:500:q_max);
ylabel(ax(1), 'New capacity');
ylabel(ax(2), 'Total quantity');
xlabel('Year');
title('cartel policy');

annotation('textbox', [0 0.9 1 0.1], ...
'String', ['New Mine Openings - Capacity Added vs Market Quantity (' ordering ')'], ...
'EdgeColor', 'none', ...
'HorizontalAlignment', 'center')

saveas(fig, [ordering '_' criteria2vary '_' num2str(list_num) '_new mines openings_Quantity.jpg']); 

%%%%
%plot the new openings - opex versus price
%%%%%
fig = figure(8);
clf('reset');
set(fig, 'units','normalized','position',[0.1 0.1 0.5 1]); 
colormap(lines(7));

groupedbar = @(x, A) bar(x, A, 'grouped', 'EdgeColor','none');

subplot(5,1,1)

[ax, h1, h2] = plotyy(time, squeeze(sim_open_1(:,2,:)), time, sim_Prices_1(:,1), groupedbar, prettyline);

set(ax(1), 'XLim', [0 T_years]);
set(ax(2), 'XLim', [0 T_years]);
set(ax(1), 'YLim',[min(TotalIncentiveCurve(:,3))-5 p_max+5]);
set(ax(2), 'YLim',[min(TotalIncentiveCurve(:,3))-5 p_max+5]);

linkaxes(ax, 'x'); 
set(ax(1),'Box','off')
set(ax(2),'Box','off')
set(ax(2), 'XTickLabel','','XAxisLocation','Top') 

set(ax(1), 'YTick', 0:10:p_max);
set(ax(2), 'YTick', 0:10:p_max);

ylabel(ax(1), 'Opex');
ylabel(ax(2), 'Price');

l = legend('Firm A openings', 'Firm B openings', 'Firm C openings', 'Market Quantity');
set(l,'PlotBoxAspectRatioMode','manual');
set(l,'PlotBoxAspectRatio',[1 0.35 1]);
set(l, 'Location', 'Best');
title('No new opening');


subplot(5,1,2)
[ax, h1, h2] = plotyy(time, squeeze(sim_open_2(:,2,:)), time, sim_Prices_2(:,1), groupedbar, prettyline);

set(ax(1), 'XLim', [0 T_years]);
set(ax(2), 'XLim', [0 T_years]);
set(ax(1), 'YLim',[min(TotalIncentiveCurve(:,3))-5 p_max+5]);
set(ax(2), 'YLim',[min(TotalIncentiveCurve(:,3))-5 p_max+5]);

linkaxes(ax, 'x'); 
set(ax(1),'Box','off')
set(ax(2),'Box','off')
set(ax(2), 'XTickLabel','','XAxisLocation','Top') 

set(ax(1), 'YTick', 0:10:p_max);
set(ax(2), 'YTick', 0:10:p_max);

ylabel(ax(1), 'Opex');
ylabel(ax(2), 'Price');
title('Best firm-NPV policy');

subplot(5,1,3)
[ax, h1, h2] = plotyy(time, squeeze(sim_open_3(:,2,:)), time, sim_Prices_3(:,1), groupedbar, prettyline);

set(ax(1), 'XLim', [0 T_years]);
set(ax(2), 'XLim', [0 T_years]);
set(ax(1), 'YLim',[min(TotalIncentiveCurve(:,3))-5 p_max+5]);
set(ax(2), 'YLim',[min(TotalIncentiveCurve(:,3))-5 p_max+5]);

linkaxes(ax, 'x'); 
set(ax(1),'Box','off')
set(ax(2),'Box','off')
set(ax(2), 'XTickLabel','','XAxisLocation','Top') 

set(ax(1), 'YTick', 0:10:p_max);
set(ax(2), 'YTick', 0:10:p_max);

ylabel(ax(1), 'Opex');
ylabel(ax(2), 'Price');
title('Positive mine-NPV policy');

subplot(5,1,4)
[ax, h1, h2] = plotyy(time, squeeze(sim_open_4(:,2,:)), time, sim_Prices_4(:,1), groupedbar, prettyline);

set(ax(1), 'XLim', [0 T_years]);
set(ax(2), 'XLim', [0 T_years]);
set(ax(1), 'YLim',[min(TotalIncentiveCurve(:,3))-5 p_max+5]);
set(ax(2), 'YLim',[min(TotalIncentiveCurve(:,3))-5 p_max+5]);

linkaxes(ax, 'x'); 
set(ax(1),'Box','off')
set(ax(2),'Box','off')
set(ax(2), 'XTickLabel','','XAxisLocation','Top') 

set(ax(1), 'YTick', 0:10:p_max);
set(ax(2), 'YTick', 0:10:p_max);

ylabel(ax(1), 'Opex');
ylabel(ax(2), 'Price');
title('Positive firm-NPV policy');


subplot(5,1,5)
[ax, h1, h2] = plotyy(time, squeeze(sim_open_mono(:,2,:)), time, sim_Prices_mono(:,1), groupedbar, prettyline);

set(ax(1), 'XLim', [0 T_years]);
set(ax(2), 'XLim', [0 T_years]);
set(ax(1), 'YLim',[min(TotalIncentiveCurve(:,3))-5 p_max+5]);
set(ax(2), 'YLim',[min(TotalIncentiveCurve(:,3))-5 p_max+5]);

linkaxes(ax, 'x'); 
set(ax(1),'Box','off')
set(ax(2),'Box','off')
set(ax(2), 'XTickLabel','','XAxisLocation','Top') 

set(ax(1), 'YTick', 0:10:p_max);
set(ax(2), 'YTick', 0:10:p_max);

ylabel(ax(1), 'Opex');
ylabel(ax(2), 'Price');

title('Market NPV optimal policy');

annotation('textbox', [0 0.9 1 0.1], ...
'String', ['New Mine Openings - Opex vs Market Price (' ordering ')'], ...
'EdgeColor', 'none', ...
'HorizontalAlignment', 'center')

saveas(fig, [ordering '_' criteria2vary '_' num2str(list_num) '_new mines openings_Opex.jpg']); 


%display summary of new openings over time
display('policy 1 openings (row = mine #, column = firm #)');
sim_openings_1(:,:,1)
display('optimal firm NPV policy openings (row = mine #, column = firm #)');
sim_openings_2(:,:,1)
display('mine positive NPV policy openings (row = mine #, column = firm #)');
sim_openings_3(:,:,1)
display('firm positive NPV policy openings (row = mine #, column = firm #)');
sim_openings_4(:,:,1)
display('cartel policy openings (row = mine #, column = firm #)');
sim_openings_mono(:,:,1)


%compare the value (NPV) of the firms in the two scenarios
fig = figure(4);
clf('reset');
colormap(lines(7));

bars = [sim_V_1(:,1) sim_V_2(:,1) sim_V_3(:,1) sim_V_4(:,1) sim_V_mono(:,1)];
errors_high = [max(sim_V_1,[],2) max(sim_V_2,[],2) max(sim_V_3,[],2) max(sim_V_4,[],2) max(sim_V_mono,[],2)] - bars; 
errors_low = bars - [min(sim_V_1,[],2) min(sim_V_2,[],2) min(sim_V_3,[],2) min(sim_V_4,[],2) min(sim_V_mono,[],2)]; 
groupnames = {'Firm A'; 'Firm B'; 'Firm C'};
bw_title = ['NPV Comparison (' ordering ')'];
bw_legend = {'no new opening', 'best firm-NPV policy', 'positive-mine-NPV policy', 'positive-firm-NPV policy', 'cartel policy'};

handles = barweb(bars, errors_high, errors_low, [], groupnames, bw_title, [], 'NPV', lines(10), 'y', bw_legend, 2, 'grid');
set(handles.bars, 'EdgeColor','none'); 

saveas(fig, [ordering '_' criteria2vary '_' num2str(list_num) '_NPV comparison.jpg']); 

%display NPV of the different players under diff scenarios
fprintf('Total NPV of the three players under base policy is %d \n', sum(sim_V_1));
sim_V_1
fprintf('Total NPV of the three players under the firm-optimal policy is %d \n', sum(sim_V_2));
sim_V_2
fprintf('Total NPV of the three players under positive-mine-NPV policy is %d \n', sum(sim_V_3));
sim_V_3
fprintf('Total NPV of the three players under positive-firm-NPV policy is %d \n', sum(sim_V_3));
sim_V_4
fprintf('Total NPV of the three players under the cartel policy is %d \n', sum(sim_V_mono));
sim_V_mono

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%DEMONSTRATION THAT THE GAME THEORY OPTIMAL POLICY IS INDEED NASH
%%EQUILIBRIUM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%1. when the other firms adopt other policies, they won't have better
%payoff
%simulate settings
numOtherPolicies = 20;   %number of simulation
sim_dr = dr;
sim_orderOfFirms = orderOfFirms;

%demand fluctuation range and prob
sim_D_fluct = D_fluct;
sim_D_prob = D_prob;
sim_Demand = Demand;

%the change associated with a state variable on whether demand has been permanently changed due to a
%high demand/low demand event (demand never fully recovers from large
%swings because of semi-permanent substitution (DPERM)
sim_DPERM_change = DPERM_change; % +10% change in non-shocked demand if DPERM is 1, and 20% if it's 2. 

%simulate a number of random policies for each firm in turn to see if they
%can get a better value by diverging from the optimal policy
firmNames = ['A' 'B' 'C' 'D'];
for varywho = 1:numFirms
    stream = RandStream.getGlobalStream;
    reset(stream);
    [sim_openings_rand, sim_Prices_rand, sim_Q_rand, sim_firm_Q_rand, sim_V_rand, sim_Vt_rand, sim_CapUtil_rand, sim_Faces_rand, sim_diag_rand] ...
        = sim_variations(varywho, Xa_2, Xb_2, Xc_2, numOtherPolicies, sim_dr, sim_orderOfFirms, sim_D_fluct, sim_D_prob, sim_Demand, sim_DPERM_change,...
        IncentiveCurveA, IncentiveCurveB, IncentiveCurveC, T, decisions_in_dt, numFirms, numIncMines, el, SupplyCurve, rich_a, D_0, TotalIncentiveCurve, ROWIncCurve);
    sim_openings_rand;

    %Graph the different NPV 
    %overall NPV bar graph
    fig = figure(4+varywho);
    clf('reset');
    %graph for A
    subplot(3,1,1);
    width1 = 0.5;
    bar(1, sim_V_2(1), width1, 'FaceColor',[0.2,0.2,0.5],....
                         'EdgeColor','none');
    hold on
    width2 = width1/2;
    bar(2:numOtherPolicies+1, sim_V_rand(1,:), width2,'FaceColor',[0,0.7,0.7],...
                         'EdgeColor',[0,0.7,0.7]);
    %legend('Optimal Policy for A', 'Other Policies for A');
    title('NPV Comparison for A');
    ylabel('NPV');
    hold off

    %graph for B
    subplot(3,1,2);
    width1 = 0.5;
    bar(1, sim_V_2(2), width1, 'FaceColor',[0.2,0.2,0.5],....
                         'EdgeColor','none');
    hold on
    width2 = width1/2;
    bar(2:numOtherPolicies+1, sim_V_rand(2,:), width2,'FaceColor',[0,0.7,0.7],...
                         'EdgeColor',[0,0.7,0.7]);
    %legend('Optimal Policy for A', 'Other Policies for A');
    title('NPV Comparison for B');
    ylabel('NPV');
    hold off

    %graph for C
    subplot(3,1,3);
    width1 = 0.5;
    bar(1, sim_V_2(3), width1, 'FaceColor',[0.2,0.2,0.5],....
                         'EdgeColor','none');
    hold on
    width2 = width1/2;
    bar(2:numOtherPolicies+1, sim_V_rand(3,:), width2,'FaceColor',[0,0.7,0.7],...
                         'EdgeColor',[0,0.7,0.7]);
    %legend('Optimal Policy for A', 'Other Policies for A');
    title('NPV Comparison for C');
    ylabel('NPV');
    hold off

    annotation('textbox', [0 0.9 1 0.1], ...
    'String', sprintf( 'NPV Variations %s (%s)', firmNames(varywho), ordering), ...
    'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center')
    
    saveas(fig,  sprintf( '%s_NPV_variations_%s_%d_%s.jpg', ordering, criteria2vary, list_num, firmNames(varywho)) ); 
end

%FIGURE 9 compare the turnover
colormap(lines(7)); 
fig = figure(9);
clf('reset');
set(fig, 'units','normalized','position',[0.1 0.1 0.5 0.4]); 
time = 1:T_years;

plot(time, sim_Prices_1(:,1).*sim_Q_1(:,1), time, sim_Prices_2(:,1).*sim_Q_2(:,1), time, sim_Prices_3(:,1).*sim_Q_3(:,1), time, sim_Prices_4(:,1).*sim_Q_4(:,1), time, sim_Prices_mono(:,1).*sim_Q_mono(:,1),'LineWidth',2);
hold on
plot(time, max(sim_Prices_1.*sim_Q_1,[],2), '--',time, max(sim_Prices_2.*sim_Q_2,[],2), '--',time, max(sim_Prices_3.*sim_Q_3,[],2),'--', time, max(sim_Prices_4.*sim_Q_4,[],2),'--', time, max(sim_Prices_mono.*sim_Q_mono,[],2),'--', 'LineWidth',1);
hold on
plot(time, min(sim_Prices_1.*sim_Q_1,[],2), '--',time, min(sim_Prices_2.*sim_Q_2,[],2), '--',time, min(sim_Prices_3.*sim_Q_3,[],2),'--', time, min(sim_Prices_4.*sim_Q_4,[],2),'--', time, min(sim_Prices_mono.*sim_Q_mono,[],2),'--', 'LineWidth',1);
hold off

leg1 = legend('no new opening', 'best firm-NPV policy', 'positive-mine-NPV policy', 'market optimal policy', 'Location', 'Best');
set(leg1, 'Box', 'off');
set(leg1, 'Color', 'none');


title(['Turnover Path (' ordering ')']);
xlabel('Year');
ylabel('Turnover');

saveas(fig, [ordering '_' criteria2vary '_' num2str(list_num) '_turnover path.jpg']); 

%Figure 10 compares the turnover of each of the 3 firms (and in total) under different policies
fig = figure(10);
clf('reset');
set(fig, 'units','normalized','position',[0.1 0.1 0.5 1]); 
colormap(lines(10)); 

graph_names = {'Firm A'; 'Firm B'; 'Firm C'; 'Firm A+B+C'}; 
for(i=1:4)
    subplot(4,1,i);
    %plot the turnover path for each firm
    plot(time, sim_Turnovers_1(:,i,1), time, sim_Turnovers_2(:,i,1), time, sim_Turnovers_3(:,i,1), time, sim_Turnovers_4(:,i,1), time, sim_Turnovers_mono(:,i,1),'LineWidth',2);
    hold on
    plot(time, max(squeeze(sim_Turnovers_1(:,i,:)),[],2), '--',time, max(squeeze(sim_Turnovers_2(:,i,:)),[],2), '--',time, max(squeeze(sim_Turnovers_3(:,i,:)),[],2),'--', time, max(squeeze(sim_Turnovers_4(:,i,:)),[],2),'--', time, max(squeeze(sim_Turnovers_mono(:,i,:)),[],2),'--', 'LineWidth',1);
    hold on
    plot(time, min(squeeze(sim_Turnovers_1(:,i,:)),[],2), '--',time, min(squeeze(sim_Turnovers_2(:,i,:)),[],2), '--',time, min(squeeze(sim_Turnovers_3(:,i,:)),[],2), '--',time, min(squeeze(sim_Turnovers_4(:,i,:)),[],2), '--',time, min(squeeze(sim_Turnovers_mono(:,i,:)),[],2),'--', 'LineWidth',1);
    hold off
    title(graph_names{i});
    ylabel('Real price');

end
xlabel('Year');
leg1 = legend('no new opening', 'best firm-NPV policy', 'positive-mine-NPV policy', 'positive-firm-NPV policy', 'cartel policy', 'Location', 'Best');
set(leg1, 'Box', 'off', 'Color', 'none');

annotation('textbox', [0 0.9 1 0.1], ...
'String', ['Turnover in each period (' ordering ')'], ...
'EdgeColor', 'none', ...
'HorizontalAlignment', 'center')

saveas(fig, [ordering '_' criteria2vary '_' num2str(list_num) '_turnover comparison.jpg']); 

%Figure 11 summarizes the price-quantity relationship for the different
%policies
colormap(lines(7)); 
fig = figure(11);
clf('reset');

plot(sim_Q_1(:,1), sim_Prices_1(:,1), sim_Q_2(:,1), sim_Prices_2(:,1), sim_Q_3(:,1), sim_Prices_3(:,1),sim_Q_4(:,1), sim_Prices_4(:,1), sim_Q_mono(:,1), sim_Prices_mono(:,1),'LineWidth',2);

title(['Price vs Quantity (' ordering ')']);
xlabel('Market Quantity');
ylabel('Price');
leg1 = legend('no new opening', 'best firm-NPV policy', 'positive-mine-NPV policy', 'positive-firm-NPV policy', 'cartel policy', 'Location', 'Best');
set(leg1, 'Box', 'off', 'Color', 'none');

saveas(fig, [ordering '_' criteria2vary '_' num2str(list_num) '_Price vs Quantity.jpg']); 

%%%%
%Figure 12 Summarize the mine openings under the different policies
%%%%

%reshape the mine opening data for display
datatable = cell(numFirms*numIncMines, simNum+2);

for(f=1:numFirms)
    for(m=1:numIncMines)
        datatable{(numIncMines*(f-1)+m),1} = firmNames(f); 
        datatable{(numIncMines*(f-1)+m),2} = [firmNames(f),'-',num2str(m)];
        for(sim=1:simNum)
            datatable{(numIncMines*(f-1)+m),2+sim} = sim_openings_1(m,f,sim); 
        end
    end
end
datatable_1 = datatable;

for(f=1:numFirms)
    for(m=1:numIncMines)
        datatable{(numIncMines*(f-1)+m),1} = firmNames(f); 
        datatable{(numIncMines*(f-1)+m),2} = [firmNames(f),'-',num2str(m)];
        for(sim=1:simNum)
            datatable{(numIncMines*(f-1)+m),2+sim} = sim_openings_2(m,f,sim); 
        end
    end
end
datatable_2 = datatable;

for(f=1:numFirms)
    for(m=1:numIncMines)
        datatable{(numIncMines*(f-1)+m),1} = firmNames(f); 
        datatable{(numIncMines*(f-1)+m),2} = [firmNames(f),'-',num2str(m)];
        for(sim=1:simNum)
            datatable{(numIncMines*(f-1)+m),2+sim} = sim_openings_3(m,f,sim); 
        end
    end
end
datatable_3 = datatable;

for(f=1:numFirms)
    for(m=1:numIncMines)
        datatable{(numIncMines*(f-1)+m),1} = firmNames(f); 
        datatable{(numIncMines*(f-1)+m),2} = [firmNames(f),'-',num2str(m)];
        for(sim=1:simNum)
            datatable{(numIncMines*(f-1)+m),2+sim} = sim_openings_4(m,f,sim); 
        end
    end
end
datatable_4 = datatable;

for(f=1:numFirms)
    for(m=1:numIncMines)
        datatable{(numIncMines*(f-1)+m),1} = firmNames(f); 
        datatable{(numIncMines*(f-1)+m),2} = [firmNames(f),'-',num2str(m)];
        for(sim=1:simNum)
            datatable{(numIncMines*(f-1)+m),2+sim} = sim_openings_mono(m,f,sim); 
        end
    end
end
datatable_mono = datatable;

%draw Figure 12
colormap(lines(7)); 
fig = figure(12);
set(fig, 'units','pixels','position',[50 50 1200 550]); 
clf('reset'); 

cnames = [{'Firm', 'Mine'}, num2cell((1:simNum))];
rnames = {}; 
width = cell(1,simNum); 
width(:) = {25}; 

annotation('textbox', [0 0.8 0.5 0.1], ...
'String', ['No new openings policy'], ...
'EdgeColor', 'none', 'FitHeightToText', 'on', ...
'HorizontalAlignment', 'center')

tab_1 = uitable('Parent',fig,'Data',datatable_1,'ColumnName',cnames,... 
            'RowName',rnames,'ColumnWidth',[{50,50},width],'Position',[20 20+250 370 200]);

annotation('textbox', [0.5 0.8 0.5 0.1], ...
'String', ['Best firm-NPV policy'], ...
'EdgeColor', 'none', 'FitHeightToText', 'on', ...
'HorizontalAlignment', 'center')

tab_2 = uitable('Parent',fig,'Data',datatable_2,'ColumnName',cnames,... 
            'RowName',rnames,'ColumnWidth',[{50,50},width],'Position',[20+400 20+250 370 200]);

annotation('textbox', [0 0.35 0.5 0.1], ...
'String', ['Positive mine-NPV policy'], ...
'EdgeColor', 'none', 'FitHeightToText', 'on', ...
'HorizontalAlignment', 'center')
tab_3 = uitable('Parent',fig,'Data',datatable_3,'ColumnName',cnames,... 
            'RowName',rnames,'ColumnWidth',[{50,50},width],'Position',[20 20 370 200]);

annotation('textbox', [0.5 0.8 0.5 0.1], ...
'String', ['Positive firm-NPV policy'], ...
'EdgeColor', 'none', 'FitHeightToText', 'on', ...
'HorizontalAlignment', 'center')
tab_4 = uitable('Parent',fig,'Data',datatable_4,'ColumnName',cnames,... 
            'RowName',rnames,'ColumnWidth',[{50,50},width],'Position',[20+400 20 370 200]);
        
        
annotation('textbox', [0 0.35 0.5 0.1], ...
'String', ['Cartel policy'], ...
'EdgeColor', 'none', 'FitHeightToText', 'on', ...
'HorizontalAlignment', 'center')
tab_mono = uitable('Parent',fig,'Data',datatable_mono,'ColumnName',cnames,... 
            'RowName',rnames,'ColumnWidth',[{50,50},width],'Position',[20+400*2 20+250 370 200]);

        
annotation('textbox', [0 0.87 1 0.1], ...
'String', ['Mine opening timing in different simulations (' ordering ')'], ...
'EdgeColor', 'none', ...
'HorizontalAlignment', 'center')


saveas(fig, [ordering '_' criteria2vary '_' num2str(list_num) '_openings summary.jpg']); 

%%%%
%Figure 13 summarizes the cashflow under the different policies
%%%%
fig = figure(13);
clf('reset');
set(fig, 'units','normalized','position',[0.1 0.1 0.5 1.3]); 
colormap(lines(10)); 

graph_names = {'Firm A'; 'Firm B'; 'Firm C'; 'Firm A+B+C'}; 
for(i=1:4)
    subplot(5,1,i);
    %plot the turnover path for each firm
    plot(time, sim_Vt_1(:,i,1), time, sim_Vt_2(:,i,1), time, sim_Vt_3(:,i,1), time, sim_Vt_4(:,i,1), time, sim_Vt_mono(:,i,1),'LineWidth',2);
    hold on
    plot(time, max(squeeze(sim_Vt_1(:,i,:)),[],2), '--',time, max(squeeze(sim_Vt_2(:,i,:)),[],2), '--',time, max(squeeze(sim_Vt_3(:,i,:)),[],2),'--', time, max(squeeze(sim_Vt_4(:,i,:)),[],2),'--', time, max(squeeze(sim_Vt_mono(:,i,:)),[],2),'--', 'LineWidth',1);
    hold on
    plot(time, min(squeeze(sim_Vt_1(:,i,:)),[],2), '--',time, min(squeeze(sim_Vt_2(:,i,:)),[],2), '--',time, min(squeeze(sim_Vt_3(:,i,:)),[],2), '--',time, min(squeeze(sim_Vt_4(:,i,:)),[],2), '--',time,  min(squeeze(sim_Vt_mono(:,i,:)),[],2),'--', 'LineWidth',1);
    hold off
    title(graph_names{i});
    ylabel('Real price');

end
xlabel('Year');

subplot(5,1,5); 
plot(time, zeros(1,T_years), time, zeros(1,T_years), time, zeros(1,T_years), time, zeros(1,T_years), time, zeros(1,T_years),'LineWidth',2);
axis([0 30 0 1])

leg1 = legend('no new opening', 'best firm-NPV policy', 'positive-mine-NPV policy', 'positive-firm-NPV policy', 'cartel policy', 'Location', 'Best');
set(leg1, 'Box', 'off', 'Color', 'none');

annotation('textbox', [0 0.9 1 0.1], ...
'String', ['Cashflow in each period (' ordering ')'], ...
'EdgeColor', 'none', ...
'HorizontalAlignment', 'center')

saveas(fig, [ordering '_' criteria2vary '_' num2str(list_num) '_undisc cashflow comparison.jpg']); 


save([criteria2vary '_' num2str(list_num) '_' ordering '_variables_list']);
diary off

end
end

%%
%Report the recorded performance diagnostic profile
profile report
