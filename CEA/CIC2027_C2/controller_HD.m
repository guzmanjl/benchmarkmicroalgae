function [st_CtrlSignals, state] = controller_HD(Timeline, obs, refs, env, future, st_CtrlSignals, state)
%CONTROLLER_HD  Estrategia de referencia de cosechado y dilucion (CIC2027).
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
% Estrategia de referencia de cosechado y dilucion (CIC2027):
%   Cada dia, a la hora harvest_hour:harvest_min (09:00 por defecto), se
%   cosecha hasta que la profundidad disminuye un depth_drop_frac (20 %) y,
%   a continuacion, se diluye con medio fresco hasta recuperar depth_target
%   (0.15 m). Las ordenes Qd_bin y Qh_bin son binarias (0/1).
%   En la Categoria 1 esta estrategia es fija (la aplica el simulador).

if nargin < 7 || isempty(state), state = struct(); end
if ~isfield(state,'init')
    state.init            = true;
    state.harvest_hour    = 9;
    state.harvest_min     = 0;
    state.depth_target    = 0.15;   % [m]
    state.depth_drop_frac = 0.20;   % [-]
    state.min_depth       = 0.05;   % [m] seguridad
    state.mode            = 'idle'; % 'idle' | 'harvest' | 'dilute'
    state.current_day     = -1;
    state.done_today      = false;
    state.depth_start     = NaN;
end

day_index = floor(Timeline.time/86400);
if day_index ~= state.current_day
    state.current_day = day_index;
    state.done_today  = false;
    state.mode        = 'idle';
end

Depth = max(obs.Depth, 1e-6);
switch state.mode
    case 'idle'
        if ~state.done_today && Timeline.hour == state.harvest_hour && Timeline.min >= state.harvest_min
            state.mode = 'harvest';
            state.depth_start = Depth;
        end
    case 'harvest'
        target = max((1 - state.depth_drop_frac)*state.depth_start, state.min_depth);
        if Depth <= target
            state.mode = 'dilute';
        end
    case 'dilute'
        if Depth >= state.depth_target
            state.mode = 'idle';
            state.done_today = true;
        end
end

st_CtrlSignals.Qh_bin = double(strcmp(state.mode,'harvest'));
st_CtrlSignals.Qd_bin = double(strcmp(state.mode,'dilute'));
end
