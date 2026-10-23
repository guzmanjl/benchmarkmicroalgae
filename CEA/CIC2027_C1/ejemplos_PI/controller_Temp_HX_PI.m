function [st_CtrlSignals, state] = controller_Temp_HX_PI( ...
    Timeline, obs, refs, env, future, st_CtrlSignals, state)
%CONTROLLER_TEMP_HX_PI  PI de temperatura con dos suministros (25/50 ºC).
%
%   [st_CtrlSignals, state] = controller_Temp_HX_PI( ...
%       Timeline, obs, refs, env, future, st_CtrlSignals, state)
%
% Comportamiento:
%   - Modula el caudal del HX Qhx con un PI (0 ... Qmax).
%   - Selecciona Tin_hx = 25 ºC (cool) o 50 ºC (heat) según el error.
%   - Histéresis en temperatura + tiempo mínimo entre cambios de Tin_hx.
%
% Estados esperados en 'state' (tú los puedes fijar antes de simular):
%   -- Modelos FOPDT --
%   state.proc_Kp_heat,  state.proc_tau_heat,  state.proc_theta_heat
%   state.proc_Kp_cool,  state.proc_tau_cool,  state.proc_theta_cool
%     * Si NO defines los de 'cool', se asumen:
%         proc_Kp_cool = -abs(proc_Kp_heat)
%         tau_cool     = tau_heat
%         theta_cool   = theta_heat
%
%   -- Tiempos de lazo --
%   state.tau_c_heat        (opcional, por defecto = tau_heat)
%   state.tau_c_cool        (opcional, por defecto = tau_c_heat)
%
%   -- Límites --
%   state.u_min, state.u_max    (Qhx en m^3/s, por defecto [0, 3e-4])
%
%   -- Setpoint y suministros --
%   state.Tsp                  (setpoint T, si no se coge de refs.T)
%   state.Tin_cool = 25
%   state.Tin_heat = 50
%
%   -- Lógica de modos --
%   state.db_enter      (histéresis exterior, p.ej. 0.5 ºC)
%   state.db_exit       (histéresis interior, p.ej. 0.2 ºC)
%   state.min_switch_time (s, p.ej. 60 s entre cambios de Tin)
%   state.mode          ('idle'|'cool'|'heat')
%   state.last_switch   (tiempo absoluto de último cambio de modo)
%
%   -- Integradores PI --
%   state.I_cool, state.I_heat
%
%   -- Limitación de pendiente en Qhx --
%   state.dQmax         (m^3/s por muestra)
%   state.Q_prev        (último caudal aplicado)
%
% Salidas:
%   st_CtrlSignals.Qhx    -> caudal HX [m^3/s]
%   st_CtrlSignals.Tin_hx -> temperatura entrada HX [ºC]

%% ---------- Init de estado ----------

if nargin < 7 || isempty(state)
    state = struct();
end

dt = Timeline.dt;

%% ---------- Setpoint de temperatura ----------

if isfield(refs,'T') && ~isempty(refs.T)
    Tsp_default = refs.T;
else
    Tsp_default = 30;  % fallback
end
if ~isfield(state,'Tsp') || isempty(state.Tsp)
    state.Tsp = Tsp_default;
end
Tsp = state.Tsp;

%% ---------- Límites de caudal HX ----------

if ~isfield(state,'u_min') || isempty(state.u_min)
    state.u_min = 0.0;           % [m^3/s]
end
if ~isfield(state,'u_max') || isempty(state.u_max)
    state.u_max = 6.0e-4;        % [m^3/s]  (tu HX.Qw_max)
end
Qmin = state.u_min;
Qmax = state.u_max;

%% ---------- Temperaturas de suministro ----------

if ~isfield(state,'Tin_cool') || isempty(state.Tin_cool)
    state.Tin_cool = 20.0;       % [ºC] suministro “frío”
end
if ~isfield(state,'Tin_heat') || isempty(state.Tin_heat)
    state.Tin_heat = 50.0;       % [ºC] suministro “caliente”
end

%% ---------- Histéresis y dwell-time para el modo ----------

if ~isfield(state,'db_enter') || isempty(state.db_enter)
    state.db_enter = 0.5;        % [ºC] para entrar en cool/heat
end
if ~isfield(state,'db_exit') || isempty(state.db_exit)
    state.db_exit  = 0.2;        % [ºC] para volver a idle
end

if ~isfield(state,'min_switch_time') || isempty(state.min_switch_time)
    state.min_switch_time = 60;  % [s] tiempo mínimo entre cambios Tin
end
if ~isfield(state,'mode') || isempty(state.mode)
    state.mode = 'idle';         % 'idle' | 'cool' | 'heat'
end
if ~isfield(state,'last_switch') || isempty(state.last_switch)
    state.last_switch = Timeline.time;  % inicializar en t actual
end

%% ---------- Integradores PI y Q_prev ----------

if ~isfield(state,'I_cool') || isempty(state.I_cool)
    state.I_cool = 0.0;
end
if ~isfield(state,'I_heat') || isempty(state.I_heat)
    state.I_heat = 0.0;
end

if ~isfield(state,'dQmax') || isempty(state.dQmax)
    state.dQmax = 5.0e-6;        % [m^3/s por muestra] suave
end
if ~isfield(state,'Q_prev') || isempty(state.Q_prev)
    state.Q_prev = 0.0;
end

%% ---------- Medida y error ----------

T = obs.T;
e = Tsp - T;    % error estándar (sp - y)

%% ---------- Lógica de modos con histéresis + dwell ----------

mode_old    = state.mode;
mode_cand   = mode_old;
db_enter    = state.db_enter;
db_exit     = state.db_exit;
elapsed     = Timeline.time - state.last_switch;

switch mode_old
    case 'idle'
        if (T >= Tsp + db_enter)
            mode_cand = 'cool';
        elseif (T <= Tsp - db_enter)
            mode_cand = 'heat';
        end

    case 'cool'
        if abs(T - Tsp) <= db_exit
            mode_cand = 'idle';
        elseif T <= Tsp - db_exit
            mode_cand = 'heat';
        end

    case 'heat'
        if abs(T - Tsp) <= db_exit
            mode_cand = 'idle';
        elseif T >= Tsp + db_exit
            mode_cand = 'cool';
        end
end

% Aplicar dwell-time: sólo cambiamos si ha pasado suficiente tiempo
if ~strcmp(mode_cand, mode_old) && elapsed >= state.min_switch_time
    state.mode        = mode_cand;
    state.last_switch = Timeline.time;
else
    mode_cand = mode_old;   % nos quedamos como estábamos
end

mode = mode_cand;

%% ---------- Parámetros FOPDT y SIMC por modo ----------

% --- Primero definimos modelos 'heat' y 'cool' ---

% Modelo para HEATING (Tin = 50ºC)  -> Kp_heat > 0
if ~isfield(state,'proc_Kp_heat') || isempty(state.proc_Kp_heat)
    % Si no te los han pasado explícitamente, intentamos usar genéricos:
    if isfield(state,'proc_Kp')
        state.proc_Kp_heat = abs(state.proc_Kp);
    else
        % Placeholder: sustituye por TU modelo identificado de heating
        state.proc_Kp_heat = 1.96e4;   % [ºC/(m^3/s)]
    end
end
if ~isfield(state,'proc_tau_heat') || isempty(state.proc_tau_heat)
    if isfield(state,'proc_tau')
        state.proc_tau_heat = state.proc_tau;
    else
        state.proc_tau_heat = 2.85e3;  % [s]
    end
end
if ~isfield(state,'proc_theta_heat') || isempty(state.proc_theta_heat)
    if isfield(state,'proc_theta')
        state.proc_theta_heat = state.proc_theta;
    else
        state.proc_theta_heat = 468; % [s]
    end
end

% Modelo para COOLING (Tin = 25ºC)  -> Kp_cool < 0
if ~isfield(state,'proc_Kp_cool') || isempty(state.proc_Kp_cool)
    % Por defecto asumimos simetría aproximada con signo opuesto
    state.proc_Kp_cool = -abs(state.proc_Kp_heat);
end
if ~isfield(state,'proc_tau_cool') || isempty(state.proc_tau_cool)
    state.proc_tau_cool = state.proc_tau_heat;
end
if ~isfield(state,'proc_theta_cool') || isempty(state.proc_theta_cool)
    state.proc_theta_cool = state.proc_theta_heat;
end

% Constantes de lazo deseadas
if ~isfield(state,'tau_c_heat') || isempty(state.tau_c_heat)
    state.tau_c_heat = 0.2*state.proc_tau_heat;  % razonable: ~tau_proc
end
if ~isfield(state,'tau_c_cool') || isempty(state.tau_c_cool)
    state.tau_c_cool = 0.2*state.proc_tau_cool;  % similar
end

%% ---------- PI por modo + anti-windup ----------

Q_cmd  = 0.0;
Tin_hx = state.Tin_cool;  % por defecto

switch mode
    case 'heat'
        % === HEATING MODE: Tin = 50ºC, modelo con Kp_heat > 0 ===
        Tin_hx = state.Tin_heat;

        Kp   = state.proc_Kp_heat;
        taup = max(state.proc_tau_heat,   1e-3);
        th   = max(state.proc_theta_heat, 0);
        tauc = max(state.tau_c_heat,      1e-3);

        den_simc = tauc + th;
        if abs(Kp) < 1e-8 || den_simc <= 0
            Kc = 0; Ti = 1e6;
        else
            Kc = taup / (Kp * den_simc);
            Ti = min(taup, 4*den_simc);
            Ti = max(Ti, 1e-3);
        end
        Ki = Kc / Ti;

        % PI heating
        u_unsat = Kc * e + state.I_heat;
        Q_cmd   = min(max(u_unsat, Qmin), Qmax);

        % Anti-windup heating
        sat_low  = (Q_cmd <= Qmin + eps);
        sat_high = (Q_cmd >= Qmax - eps);
        if (~sat_low && ~sat_high) || (sat_low && e > 0) || (sat_high && e < 0)
            state.I_heat = state.I_heat + Ki * dt * e;
        end

    case 'cool'
        % === COOLING MODE: Tin = 25ºC, modelo con Kp_cool < 0 ===
        Tin_hx = state.Tin_cool;

        Kp   = state.proc_Kp_cool;
        taup = max(state.proc_tau_cool,   1e-3);
        th   = max(state.proc_theta_cool, 0);
        tauc = max(state.tau_c_cool,      1e-3);

        den_simc = tauc + th;
        if abs(Kp) < 1e-8 || den_simc <= 0
            Kc = 0; Ti = 1e6;
        else
            Kc = taup / (Kp * den_simc);
            Ti = min(taup, 4*den_simc);
            Ti = max(Ti, 1e-3);
        end
        Ki = Kc / Ti;

        % PI cooling (mismo error e = Tsp - T, pero Kp<0)
        u_unsat = Kc * e + state.I_cool;
        Q_cmd   = min(max(u_unsat, Qmin), Qmax);

        % Anti-windup cooling
        sat_low  = (Q_cmd <= Qmin + eps);
        sat_high = (Q_cmd >= Qmax - eps);
        if (~sat_low && ~sat_high) || (sat_low && e > 0) || (sat_high && e < 0)
            state.I_cool = state.I_cool + Ki * dt * e;
        end

    otherwise  % 'idle'
        Tin_hx = state.Tin_cool;  % por ejemplo
        Q_cmd  = 0.0;
        % Integradores congelados en idle
end

%% ---------- Limitación de pendiente en Qhx ----------

Q_des = Q_cmd;
dQ    = Q_des - state.Q_prev;
if abs(dQ) > state.dQmax
    dQ = sign(dQ) * state.dQmax;
end
Qhx = min(max(state.Q_prev + dQ, Qmin), Qmax);
state.Q_prev = Qhx;

%% ---------- Salidas ----------

st_CtrlSignals.Qhx    = Qhx;
st_CtrlSignals.Tin_hx = Tin_hx;

end
