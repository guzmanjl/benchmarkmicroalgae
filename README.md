# Microalgae Raceway Reactor Control Benchmark

This repository provides an open and reproducible **control benchmark for outdoor microalgae raceway reactors**, designed to evaluate and compare regulatory and advanced control strategies under realistic environmental disturbances and actuator constraints.

The benchmark integrates **four coupled control problems**:

- pH regulation via CO₂ injection  
- Dissolved oxygen (DO) regulation via air bubbling  
- Culture volume regulation through coordinated harvest–dilution actions  
- Temperature regulation using a sump-mounted spiral heat exchanger  

It is built upon a **high-fidelity, experimentally calibrated dynamic model** capturing the thermal, physicochemical, and biological processes governing industrial-scale open raceway ponds.

A closed-loop simulation environment is provided, including realistic actuator constraints, gas transport delays, stiff integration, and a fully specified multi-day outdoor disturbance scenario (irradiance, temperature, wind, and humidity).

A paper describing the bechmark and process equations can be found in open access at [https://doi.org/10.1016/j.conengprac.2026.107027](https://doi.org/10.1016/j.conengprac.2026.107027)

---
## IFAC World Congress 2026 - Bechmark competition

The [IFAC World Congress 2026](https://ifac2026.org/) will feature a collection of benchmark problems addressing representative challenges in control systems. These problems aim to support standardized evaluation, stimulate methodological advances, and encourage collaboration across the research community.

Our **Benchmark Control Problem on microalgae production systems** is one of the challenges selected for IFAC WC 2026. Important information about deadlines and registration is available on the Benchmark Challenge website:

https://ifac2026.org/fairContents.do?FAIRMENU_IDX=21707&hl=ENG#scroll-2

Participants are invited to read the benchmark challenge instructions in [Handbook_Benchmark_IFACWC.pdf](IFAC_WC_player/Handbook_Benchmark_IFACWC.pdf) and use the files in the `IFAC_WC_player/` folder that can be downloaded from this [link](https://downgit.github.io/#/home?url=https://github.com/guzmanjl/benchmarkmicroalgae/tree/main/IFAC_WC_player).

*IMPORTANT: Only solutions derived from a systematic, control-oriented methodology will be accepted. Solutions relying on trial-and-error approaches or hidden optimization procedures will not be considered.*

---

## Repository Structure

The main entry point for users is the `player/` folder. 

For users participating in the IFAC World Congress bechmark problem, is `IFAC_WC_player/` folder ([download](https://downgit.github.io/#/home?url=https://github.com/guzmanjl/benchmarkmicroalgae/tree/main/IFAC_WC_player)):

```text
benchmarkmicroalgae/
│
├── player/
│   ├── Benchmark_main.m                % Main simulation launcher
│   ├── controller_pH_OnOff.m           % Example pH controller
│   ├── controller_DO_OnOff.m           % Example DO controller
│   ├── controller_HD_fixed.m           % Example harvest/dilution strategy
│   ├── controller_Temp_HX_no_control.m % Example temperature controller
│   └── ...
│
├── IFAC_WC_player/
│   ├── Benchmark_main.m                % Main simulation launcher
│   ├── controller_pH.m                 % Example pH controller
│   ├── controller_DO.m                 % Example DO controller
│   ├── controller_Temp_HX.m            % Example temperature controller
│   ├── Handbook_Benchmark_IFACWC.pdf   % Instructions for IFAC WC Benchmark competition 
│   └── ...
│
├── simulate_benchmark_model.p          % Dynamic process model
├── Data_Benchmark.mat                  % Disturbance scenarios and parameters
├── load_data.m                         % Auxiliary script to load data and parameters
├── show_results.m                      % Auxiliary script to show the results
└── README.md
```


## Requirements

* MATLAB (tested with stiff ODE solvers)
* No additional toolboxes are required beyond standard MATLAB functionality

---

## How to Run the Benchmark

1. Clone or download this repository.
2. Open MATLAB and add the repository to the MATLAB path.
3. Navigate to the `player/` folder.
4. Run the main simulation script:

```matlab
Benchmark_main
```

The script:

* Loads the dynamic process model and disturbance scenarios
* Executes a closed-loop simulation over a multi-day horizon
* Calls the user-defined control strategies
* Generates time-series plots of key process variables
* Computes control and performance metrics

---

## Control Architecture

The benchmark is structured around **four independent controller functions**, each responsible for a specific regulation task:

| Control Task | Manipulated Variable | Default Controller                |
| ------------ | -------------------- | --------------------------------- |
| pH           | CO₂ injection        | `controller_pH_OnOff.m`           |
| DO           | Air bubbling         | `controller_DO_OnOff.m`           |
| Volume       | Harvest/Dilution     | `controller_HD_fixed.m`           |
| Temperature  | Heat exchanger       | `controller_Temp_HX_no_control.m` |

The controller functions are specified in **lines 10–13 of `Benchmark_main.m`**.

---

## Implementing Your Own Controllers

Users are encouraged to:

* Modify the provided controller files, or
* Implement custom control algorithms (PI, PID, MPC, EMPC, rule-based, etc.)

Controller function names may be freely changed, **provided the corresponding function calls in `Benchmark_main.m` are updated accordingly**.

This modular design enables rapid prototyping and fair comparison of alternative control strategies under identical operating conditions.

---

## Simulation Outputs

After execution, the simulator:

* Displays graphical results of the simulations
* Computes individual and global performance indices
* Stores all simulation data in a structured MATLAB variable named `results`

---

## Results Data Structure

### Time and References

* `results.t`
  Time vector of the simulation horizon [s]

* `results.refs`
  Structure or matrix collecting the reference trajectories used by the controllers (e.g., pH, DO, temperature setpoints)

---

### Measured and Reported Process Variables

* `results.pH`
  pH signal (dimensionless)

* `results.DO`
  Dissolved oxygen [% saturation]

* `results.T`
  Bulk reactor temperature [°C]

* `results.X_gL`
  Biomass concentration [g·L⁻¹]

* `results.Depth`
  Culture depth [m]

---

### Control Commands and Effective Flow Rates

* `results.Qair_cmd`
  Air injection command (controller output, before actuator saturation)

* `results.QCO2_cmd`
  CO₂ injection command

* `results.Qair_del`
  Delivered air flow rate after actuator limits [m³·s⁻¹]

* `results.QCO2_del`
  Delivered CO₂ flow rate [m³·s⁻¹]

* `results.Qd`
  Effective dilution inflow [m³·s⁻¹]

* `results.Qh`
  Effective harvesting outflow [m³·s⁻¹]

---

### Cumulative Gas Usage and Biomass Metrics

* `results.cum_air_L`
  Cumulative injected air volume [L]

* `results.cum_CO2_L`
  Cumulative injected CO₂ volume [L]

* `results.cum_harv_g`
  Cumulative harvested biomass [g]

* `results.total_air_L`
  Total air consumption over the entire horizon [L]

* `results.total_CO2_L`
  Total CO₂ consumption over the entire horizon [L]

---

### Key Performance Indicators (KPIs)

* `results.gain_g`
  Net biomass gain between initial and final time [g]

* `results.acumm_rel`
  Relative biomass accumulation index (dimensionless)

* `results.prod_g`
  Total (gross) biomass production [g]

* `results.prod_areal_gm2_day`
  Areal productivity [g·m⁻²·day⁻¹]

* `results.harv_total_g`
  Total harvested biomass [g]

* `results.harv_frac`
  Fraction of produced biomass that is effectively harvested

* `results.harv_prod_areal_gm2_day`
  Areal productivity associated with harvested biomass [g·m⁻²·day⁻¹]

---

### Biological Rates and Limitation Factors

* `results.mu_I`
  Light limitation factor

* `results.mu_T`
  Temperature limitation factor

* `results.mu_pH`
  pH limitation factor

* `results.mu_DO`
  Dissolved oxygen inhibition term

* `results.P`
  Gross photosynthetic rate

* `results.mu`
  Net specific growth rate

* `results.m`
  Maintenance / respiration rate

---

### Carbonate System and Cations

* `results.DIC`
  Dissolved inorganic carbon concentration [mol·m⁻³]

* `results.Cat`
  Strong cation concentration [mol·m⁻³]

* `results.HCO3`
  Bicarbonate concentration [mol·m⁻³]

* `results.CO3`
  Carbonate concentration [mol·m⁻³]

* `results.CO2`
  Dissolved CO₂ concentration [mol·m⁻³]

---

### Heat Exchanger Substructure

* `results.HX.Qw_m3s`
  Water flow rate through the spiral heat exchanger [m³·s⁻¹]

* `results.HX.Tin_C`
  Inlet water temperature [°C]

* `results.HX.Tout_C`
  Outlet water temperature [°C]

* `results.HX.UA_WK`
  Overall heat-transfer coefficient × area [W·K⁻¹]

* `results.HX.Q_W`
  Instantaneous heat flux exchanged with the culture [W]

* `results.HX.limits`
  Structure containing actuator limits:
  `Qw_min`, `Qw_max`, `Tin_min`, `Tin_max`

---

## Purpose of the Benchmark

This benchmark is intended to:

* Enable **consistent and quantitative comparison** of control strategies
* Bridge **control methodology** and **outdoor algal bioprocess engineering**
* Support the development of **multivariable control approaches** for disturbance-rich environmental systems

Baseline regulatory architectures (On/Off, PI/PID, and Economic MPC) are included to illustrate the use of the platform for both classical and advanced control methods.

---

## License and Citation

Please cite the associated publication if you use this benchmark in academic or industrial work.
Licensing information is provided in the repository.

---

## Contact

For questions, suggestions, or contributions, please open an issue or contact the repository developers from the Automatic Control, Robotics and Mechatronics research group (https://arm.ual.es) at the University of Almeria (Spain):

* Enrique Rodriguez Miranda (erm969@ual.es)
* Pablo Otalora Berenguel (p.otalora@ual.es)
* Jose Gonzalez Hernandez (j.gonzalez@ual.es)
* Jose Luis Guzman Sanchez (joseluis.guzman@ual.es)

---
