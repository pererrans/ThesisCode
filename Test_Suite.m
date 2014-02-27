% New version of the exact DP to accomodate multiple players
% Yuanjian Carla Li, January 31, 2014

%Testing of the market clearing function
t=1;
DPERM=3;
[market_p, market_q, cap_util, rewards, faces, firms_q, diag] = findPrice_new(T, numFirms, t, MinesOpened_updated, DPERM, DPERM_change, el, D_prob, D_fluct, Demand(t), D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);
                
[market_p_1, market_q_1, cap_util_1, rewards_1, faces_1, firms_q_1, diag_1] = findPrice_new(T, numFirms, t, sim_m_1, sim_dperm_1, sim_DPERM_change, el, D_prob, sim_D_fluct, sim_demand, D_0, SupplyCurve(:,:,t), rich_a, TotalIncentiveCurve);


