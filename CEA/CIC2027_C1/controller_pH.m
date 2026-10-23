function [st_CtrlSignals, state] = controller_pH(Timeline, obs, refs, env, future, st_CtrlSignals, state)
%CONTROLLER_PH  Controlador de referencia de pH (CIC2027).
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
%   Inyecta CO2 a u_on [m^3/s] cuando pH > setpoint + deadband/2 y hay
%   radiacion solar (RadGlobal > 10 W/m^2); deja de inyectar cuando
%   pH < setpoint - deadband/2 o de noche. Tiempos minimos On/Off de 60 s.

if nargin < 7 || isempty(state), state = struct(); end
if ~isfield(state,'init')
    state.init      = true;
    state.setpoint  = refs.pH;          % [-]
    state.deadband  = 0.10;             % [-]
    state.u_on      = 20/1000/60;       % 20 L/min -> m^3/s
    state.min_on_s  = 60;  state.min_off_s = 60;
    state.on        = false;
    state.last_switch = -inf;
end

pHhi = state.setpoint + state.deadband/2;
pHlo = state.setpoint - state.deadband/2;
day  = env.RadGlobal > 10;

desired = state.on;
if obs.pH > pHhi && day
    desired = true;
elseif obs.pH < pHlo || ~day
    desired = false;
end

elapsed = Timeline.time - state.last_switch;
if desired ~= state.on
    if ( state.on && elapsed >= state.min_on_s) || (~state.on && elapsed >= state.min_off_s)
        state.on = desired;
        state.last_switch = Timeline.time;
    end
end

st_CtrlSignals.Qco2 = state.u_on * double(state.on);
end
