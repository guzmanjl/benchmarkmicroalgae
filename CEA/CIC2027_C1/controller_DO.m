function [st_CtrlSignals, state] = controller_DO(Timeline, obs, refs, env, future, st_CtrlSignals, state)
%CONTROLLER_DO  Controlador de referencia de oxigeno disuelto (CIC2027).
%   Contiene el controlador de referencia (CR) y sirve como plantilla:
%   sustituya su contenido por el controlador propuesto, manteniendo la
%   interfaz y el nombre de la funcion.
%
% Interfaz comun (NO modificar):
%   [st_CtrlSignals, state] = f(Timeline, obs, refs, env, future, st_CtrlSignals, state)
%
% Entradas:
%   Timeline (struct): dt [s], index [-], time [s], time_secday [s], hour [h], min [min]
%   obs      (struct): pH [-], DO [% sat], Depth [m], Xalg_gL [g/L], T [degC]
%   refs     (struct): pH [-], DO [% sat], T [degC]
%   env      (struct): RadGlobal [W/m^2], RadPAR [umol/m^2/s], Temp_ext [degC],
%                      RH [%], Wind [m/s]
%   future   (struct): t_future [s], RadGlobal, RadPAR, Temp_ext, RH, Wind
%                      (prediccion perfecta; VACIA en la Categoria 1)
%   st_CtrlSignals (struct): Qco2 [m^3/s], Qair [m^3/s], Qd_bin [0/1],
%                      Qh_bin [0/1], Qhx [m^3/s], Tin_hx [degC]
%   state    (struct): estado persistente propio del controlador (inicialmente vacio)
%
% Salidas:
%   st_CtrlSignals: estructura actualizada (solo los campos que manipula)
%   state         : estado actualizado

%
% Controlador de referencia CR (CIC2027): todo/nada con histeresis.
%   Inyecta aire a u_on [m^3/s] cuando DO > setpoint + deadband/2 y lo
%   detiene cuando DO < setpoint - deadband/2. Tiempos minimos On/Off de 60 s.

if nargin < 7 || isempty(state), state = struct(); end
if ~isfield(state,'init')
    state.init      = true;
    state.setpoint  = refs.DO;          % [% sat]
    state.deadband  = 10;               % [% sat]
    state.u_on      = 500/1000/60;      % 500 L/min -> m^3/s
    state.min_on_s  = 60;  state.min_off_s = 60;
    state.on        = false;
    state.last_switch = -inf;
end

DOhi = state.setpoint + state.deadband/2;
DOlo = state.setpoint - state.deadband/2;

desired = state.on;
if obs.DO > DOhi
    desired = true;
elseif obs.DO < DOlo
    desired = false;
end

elapsed = Timeline.time - state.last_switch;
if desired ~= state.on
    if ( state.on && elapsed >= state.min_on_s) || (~state.on && elapsed >= state.min_off_s)
        state.on = desired;
        state.last_switch = Timeline.time;
    end
end

st_CtrlSignals.Qair = state.u_on * double(state.on);
end
