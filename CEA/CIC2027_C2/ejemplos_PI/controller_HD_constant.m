function [st_CtrlSignals, state] = controller_HD_constant(Timeline, obs, refs, env, future, st_CtrlSignals, state)
% Purpose:
%   Every simulation day, at a given clock time (default 09:00), start a harvest
%   phase that removes culture until the raceway depth has decreased by a fixed
%   fraction (e.g. 20% of the depth at the beginning of harvest). Then, switch to
%   a dilution phase that adds fresh medium until the target depth is reached
%   again (e.g. Depth_target = 0.15 m).
%
%   Outputs Dil_cmd and Harv_cmd are *binary* commands (0/1) that drive the
%   dilution and harvest actuators in the benchmark:
%       Qd = Dil_cmd  * p.Qd_r   (inflow / dilution)
%       Qh = Harv_cmd * p.Qh_r   (outflow / harvest)
%
% Inputs:
%   Timeline (struct) Timeline structure. Expected fields:
%                       - dt: Sample time [s]
%                       - index: Sample index [-]
%                       - time: Absolute time in seconds [s]
%                       - time_secday: Seconds of day [s]
%                       - hour: Hour of day [h]
%                       - min: Minutes of hour [min]
%
%   obs     (struct)   Measured/estimated variables at current step. Expected fields:
%                      - obs.pH: reactor pH [-]
%                      - obs.DO: dissolved oxygen [% sat]
%                      - obs.Depth: water depth [m]
%                      - obs.Xalg_gL: microalgae biomass concentration [g/L]
%                      - obs.T: reactor water temperature [°C]

%   refs    (struct)   Corresponding setpoints for controled variables. Expected fields:
%                      - refs.pH: pH reference [-]
%                      - refs.DO: Dissolved Oxygen reference [%]
%                      - refs.T: Temperature reference [°C]
%
%   env     (struct)   Environment/context for the controller. Expected fields:
%                      - env.RadGlobal: global radiation [W/m^2]
%                      - env.RadPAR: photosynthetically active radiation [µE/m^2/s]
%                      - env.Temp_ext: ambient temperature [°C]
%                      - env.RH: relative humidity [%]
%                      - env.Wind: wind speed [m/s]
%
%   future  (struct)   Optional look-ahead trajectories. Expected fields:
%                      - future.t_future: 
%                      - future.RadGlobal: global radiation [W/m^2]
%                      - future.RadPAR: photosynthetically active radiation [µE/m^2/s]
%                      - future.Temp_ext:ambient temperature [°C]
%                      - future.RH: relative humidity [%]
%                      - future.Wind: wind speed [m/s]
%
%   state   (struct)   Persistent controller state and tuning parameters.
%
% Outputs:
%   st_CtrlSignals  (struct) Structure for control signals. Expected fields:
%                      - Qco2  (double):  Commanded CO2 flow [m^3/s].
%                      - Qair  (double):  Commanded air flow [m^3/s].
%                      - Qd_bin  (double):  Commanded dilution signal [-].
%                      - Qh_bin  (double):  Commanded harvest signal [-].
%                      - Qhx  (double):  Commanded heat exchanger flow [m^3/s].
%                      - Tin_hx  (double):  Inlet temperature for heat exchanger [°C].
%
%   state (struct):  Updated state.

% ---------------- Initialization of state & parameters ----------------
if nargin < 6 || isempty(state)
    state = struct();
end

% Depth setpoint
if ~isfield(state,'depth_target')
    depth_target = obs.Depth;
    state.depth_target = depth_target; % [m]
else
    depth_target = state.depth_target;
end

% Xalg setpoint
if ~isfield(state,'Xalg_target')
    Xalg_target = obs.Xalg_gL*1000;
    %Xalg_target = 800;
    state.Xalg_target = Xalg_target; % [m]
else
    Xalg_target = state.Xalg_target;
end

% ------------------ Control -----------------------------
if obs.Xalg_gL*1000 > Xalg_target
    st_CtrlSignals.Qd_bin = 1;
else
    st_CtrlSignals.Qd_bin = 0;
end

if obs.Depth > depth_target
    st_CtrlSignals.Qh_bin = 1;
else
    st_CtrlSignals.Qh_bin = 0;
end
end
