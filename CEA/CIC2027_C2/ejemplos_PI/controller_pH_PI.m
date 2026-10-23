function [st_CtrlSignals, state] = controller_pH_PI(Timeline, obs, refs, env, future, st_CtrlSignals, state)
%CONTROLLER_PH_PI  PI controller for pH with SIMC tuning and anti-windup.
%
%   [st_CtrlSignals, state] = controller_pH_PI(Timeline, obs, refs, env, future, st_CtrlSignals, state)
%
% Purpose:
%   Drive the reactor pH toward a setpoint by manipulating the CO2 flow
%   using a discrete PI controller. The PI gains are computed using the
%   SIMC tuning rules from a first-order-plus-dead-time (FOPDT) model.
%
% Process model (FOPDT):
%   G(s) = Kp_proc * exp(-theta * s) / (tau_proc * s + 1)
%
% SIMC PI tuning (self-regulating process):
%   Kc = (tau_proc) / (Kp_proc * (tau_c + theta))
%   Ti = min(tau_proc, 4*(tau_c + theta))
%   Ki = Kc / Ti
%
%   where:
%     Kp_proc   : process gain (include sign)
%     tau_proc  : process time constant [s]
%     theta     : process dead time [s]
%     tau_c     : desired closed-loop time constant [s]
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
%
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
%   st_CtrlSignals (struct) Structure for control signals. Expected fields:
%                      - Qco2  (double):  Commanded CO2 flow [m^3/s].
%                      - Qair  (double):  Commanded air flow [m^3/s].
%                      - Qd_bin  (double):  Commanded dilution signal [-].
%                      - Qh_bin  (double):  Commanded harvest signal [-].
%                      - Qhx  (double):  Commanded heat exchanger flow [m^3/s].
%                      - Tin_hx  (double):  Inlet temperature for heat exchanger [°C].
%
%   state   (struct)   Persistent controller state and tuning parameters.
%                      Required / optional fields to set from outside:
%                      - state.proc_Kp    : process gain Kp_proc
%                      - state.proc_tau   : process time constant tau_proc [s]
%                      - state.proc_theta : process dead time theta [s]
%                      - state.tau_c      : desired closed-loop time constant [s]
%                      - state.u_min      : min CO2 flow [m^3/s]
%                      - state.u_max      : max CO2 flow [m^3/s]
%                      - state.setpoint   : pH setpoint (overrides refs.pH if set)
%
% Outputs:
%   st_CtrlSignals  (struct): Updated control signal structure (Qco2 modified).
%   state           (struct): Updated controller state (including integrator).

% ----------- Basic checks / state init -----------
if nargin < 7 || isempty(state)
    state = struct();
end

dt = Timeline.dt;

% ----- Setpoint -----
if isfield(refs, 'pH') && ~isempty(refs.pH)
    sp = refs.pH;
else
    sp = 8.0;  % default pH setpoint
end

% ----- Process model parameters (FOPDT) -----
% Use your identified parameters as defaults if not provided from outside
if ~isfield(state, 'proc_Kp') || isempty(state.proc_Kp)
    % Negative gain: more CO2 → lower pH
    state.proc_Kp =   -2.7987e+03;    % [pH / (m^3/s)]
end
if ~isfield(state, 'proc_tau') || isempty(state.proc_tau)
    state.proc_tau = 1.0510e+03;     % [s]
end
if ~isfield(state, 'proc_theta') || isempty(state.proc_theta)
    state.proc_theta = 400;      % [s]
end
if ~isfield(state, 'tau_c') || isempty(state.tau_c)
    % For dt = 60 s, a tau_c much larger than dt is safer.
    % You can adjust this from outside.
    state.tau_c = 0.2*state.proc_tau;   % [s]
end

Kp_proc   = state.proc_Kp;
tau_proc  = max(state.proc_tau, 1e-3);
theta     = max(state.proc_theta, 0);
tau_c     = max(state.tau_c, 1e-3);

% ----- PI gains via SIMC -----
%   Kc = tau_proc / (Kp_proc * (tau_c + theta))
%   Ti = min(tau_proc, 4*(tau_c + theta))
den_simc = (tau_c + theta);
Kc = tau_proc / (Kp_proc * den_simc);
Ti = min(tau_proc, 4*den_simc);
Ti = max(Ti, 1e-3);

Ki = Kc / Ti;

state.Kc = Kc;
state.Ki = Ki;
state.Ti = Ti;

% ----- CO2 flow limits -----
if ~isfield(state, 'u_min') || isempty(state.u_min)
    state.u_min = 0.0;            % [m^3/s]
end
if ~isfield(state, 'u_max') || isempty(state.u_max)
    % 12 L/min = 12/1000 m^3/min = 12/1000/60 m^3/s
    state.u_max = 20/1000/60;     % [m^3/s]
end
u_min = state.u_min;
u_max = state.u_max;

% ----- Integrator state -----
if ~isfield(state, 'I') || isempty(state.I)
    state.I = 0.0;
end

% ----------- PI control law with simple anti-windup -----------
pH = obs.pH;
e  = sp - pH;        % setpoint - measurement

% Proportional term
u_P = Kc * e;

% Unsaturated output
u_unsat = u_P + state.I;

% Saturation
u_sat = min(max(u_unsat, u_min), u_max);

% Simple clamping anti-windup:
% Integrate only when there is no saturation.
if u_sat == u_unsat
    state.I = state.I + Ki * dt * e;
end

% Final CO2 flow command
qco2 = u_sat;

% ----------- Output assignment -----------
st_CtrlSignals.Qco2 = qco2;

end