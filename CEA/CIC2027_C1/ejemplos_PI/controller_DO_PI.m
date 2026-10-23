function [st_CtrlSignals, state] = controller_DO_PI(Timeline, obs, refs, env, future, st_CtrlSignals, state)
%CONTROLLER_DO_PI  PI controller for dissolved oxygen with SIMC tuning and anti-windup.
%
%   [st_CtrlSignals, state] = controller_DO_PI(Timeline, obs, refs, env, future, st_CtrlSignals, state)
%
% Purpose:
%   Control dissolved oxygen (DO) by manipulating the air flow using a
%   discrete PI controller. The PI gains are computed using the SIMC tuning
%   rules from a first-order-plus-dead-time (FOPDT) model.
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
%     Kp_proc   : process gain (include sign; for "air ON → DO DOWN" it is usually negative)
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
%   refs    (struct)   Corresponding setpoints for controlled variables. Expected fields:
%                      - refs.DO: Dissolved Oxygen reference [% sat]
%
%   env     (struct)   Environment/context for the controller. (Unused here,
%                      kept for interface compatibility.)
%
%   future  (struct)   Optional look-ahead trajectories. (Unused here.)
%
%   st_CtrlSignals (struct) Structure for control signals. Expected fields:
%                      - Qco2  (double):  Commanded CO2 flow [m^3/s].
%                      - Qair  (double):  Commanded air flow [m^3/s]. (Modified here)
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
%                      - state.u_min      : min air flow [m^3/s]
%                      - state.u_max      : max air flow [m^3/s]
%                      - state.setpoint   : DO setpoint (overrides refs.DO if set)
%
% Outputs:
%   st_CtrlSignals  (struct): Updated control signal structure (Qair modified).
%   state           (struct): Updated controller state (including integrator).

% ----------- Basic checks / state init -----------
if nargin < 7 || isempty(state)
    state = struct();
end

dt = Timeline.dt;

% ----- Setpoint -----
if isfield(refs, 'DO') && ~isempty(refs.DO)
    sp_DO = refs.DO;
else
    sp_DO = 150.0;  % [% sat] default DO setpoint
end

if ~isfield(state, 'setpoint') || isempty(state.setpoint)
    state.setpoint = sp_DO;
else
    % Permitir actualización dinámica desde refs
    state.setpoint = sp_DO;
end

% ----- Process model parameters (FOPDT) -----
% Defaults basados en tu identificación (puedes sobrescribirlos desde fuera)
if ~isfield(state, 'proc_Kp') || isempty(state.proc_Kp)
    % Ganancia del proceso (incluye signo). Suele ser negativa si el aire baja el DO.
    state.proc_Kp = -1.4460e+04;   % [% sat / (m^3/s)]
end
if ~isfield(state, 'proc_tau') || isempty(state.proc_tau)
    state.proc_tau = 3.7736e+03;   % [s]
end
if ~isfield(state, 'proc_theta') || isempty(state.proc_theta)
    state.proc_theta = 400;        % [s]
end

Kp_proc   = state.proc_Kp;
tau_proc  = max(state.proc_tau, 1e-3);
theta     = max(state.proc_theta, 0);

% ----- Desired closed-loop time constant (tau_c) -----
if ~isfield(state, 'tau_c') || isempty(state.tau_c)
    % Un tau_c no demasiado agresivo respecto a tau_proc y dt
    state.tau_c = 0.1*tau_proc;   % [s]
end
tau_c = max(state.tau_c, 1e-3);

% ----- Compute PI gains via SIMC -----
den_simc = (tau_c + theta);
Kc = tau_proc / (Kp_proc * den_simc);
Ti = min(tau_proc, 4*den_simc);
Ti = max(Ti, 1e-3);
Ki = Kc / Ti;

state.Kc = Kc;
state.Ki = Ki;
state.Ti = Ti;

% ----- Air flow limits -----
if ~isfield(state, 'u_min') || isempty(state.u_min)
    state.u_min = 0.0;            % [m^3/s]
end
if ~isfield(state, 'u_max') || isempty(state.u_max)
    % 500 L/min = 500/1000 m^3/min = 500/1000/60 m^3/s
    state.u_max = 500/1000/60;    % [m^3/s]
end
u_min = state.u_min;
u_max = state.u_max;

% ----- Integrator state -----
if ~isfield(state, 'I') || isempty(state.I)
    state.I = 0.0;
end

% ----------- PI control law with simple anti-windup -----------
DO = obs.DO;                       % [% sat]
e  = (state.setpoint) - DO;          % error = SP - PV

% Proportional action
u_P = Kc * e;

% Unsaturated output
u_unsat = u_P + state.I;

% Saturation
u_sat = min(max(u_unsat, u_min), u_max);

% Simple clamping anti-windup:
% Solo integramos cuando NO hay saturación.
if u_sat == u_unsat
    state.I = state.I + Ki * dt * e;
end

% Final saturated air flow command
qair = u_sat;

% ----------- Output assignment -----------
st_CtrlSignals.Qair = qair;

end

