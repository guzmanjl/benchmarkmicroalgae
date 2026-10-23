function [st_CtrlSignals, state] = controller_Temp_HX(Timeline, obs, refs, env, future, st_CtrlSignals, state)
%CONTROLLER_TEMP_HX  Controlador de referencia de temperatura (CIC2027).
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
% Controlador de referencia CR (CIC2027): sin control de temperatura.
%   El intercambiador permanece inactivo (Qhx = 0) y la temperatura del
%   cultivo evoluciona libremente.

st_CtrlSignals.Qhx    = 0.0;
st_CtrlSignals.Tin_hx = obs.T;
end
