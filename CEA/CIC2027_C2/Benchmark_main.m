%% ===== CIC2027 - Categoria 2 =====
% Concurso en Ingenieria de Control 2027 (CEA)
% Control de un reactor raceway para la produccion de biomasa de microalgas
%
% Script principal. Solo deben modificarse, si se cambia el nombre de las
% funciones de control, las lineas de la seccion "Controllers".
% Categoria 2: incluye el cosechado/dilucion, sujeto a las restricciones de operacion.

clear; clc; close all;
addpath('sources');

%% ---------------- Data load ----------------
try
    S = load('Data_Benchmark_ext','Data');
    Data = S.Data;
catch
    error('Data_Benchmark_ext.mat not found or missing variable "Data".');
end

%% ------- Controllers (one per actuator) -------
ctrl = struct();
ctrl.fn_pH_CO2  = @controller_pH;
ctrl.fn_DO_air  = @controller_DO;
ctrl.fn_HD      = @controller_HD;
ctrl.fn_Temp_HX = @controller_Temp_HX;

%% ---------------- Simulation ----------------
fprintf('\nCIC2027 - Categoria 2: running simulation...\n');
results = simulate_benchmark_model(Data, ctrl);

%% ---------------- Results ----------------
showResults
