# Aerodynamic Optimization & Design Space Analysis of a NACA 2412 Cessna Wing

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Tools](https://img.shields.io/badge/Tools-XFLR5%20%7C%20MATLAB%20%7C%20Python-orange)
![Methodology](https://img.shields.io/badge/Methodology-VLM%20%7C%203D%20Panel%20Method-green)

Automated 50-design parametric aerodynamic trade study and preliminary design optimization for a Cessna 172-class general aviation wing using **XFLR5 (VLM/LLT & 3D Panel Method)** and automated **MATLAB data extraction and visualization pipelines.

---

## 📌 Executive Summary

This project executes a constrained aerodynamic design optimization of a trapezoidal wing built around the **NACA 2412** airfoil. A 50-design Design of Experiments (DOE) grid was evaluated across sweeps of **Aspect Ratio ($AR$)**, **Taper Ratio ($TR$)**, and **Washout Twist ($TW$)**.

* **Baseline Planform (`AR6.00_TR1.00_TW0.00`):** $(L/D)_{\text{cruise}} = 26.43$, $CD_i = 0.01384$, $C_{L,\max} = 1.5012$.
* **Optimal Planform (`AR7.50_TR0.47_TW2.00`):** $(L/D)_{\text{cruise}} = 31.59$, $CD_i = 0.01075$, $C_{L,\max} = 1.5813 \ge 1.58$.
* **Key Achievements:** Achieved a **$+19.51\%$ boost in cruise efficiency** ($(L/D)_{\text{cruise}}$) and a **$-22.35\%$ reduction in induced drag ($CD_i$)** over the untapered rectangular baseline while satisfying maximum lift stall thresholds ($C_{L,\max} \ge 1.58$) and pitch stability requirements ($C_{m_\alpha} < 0$).

---

## 📐 Project Formulation & Constraints

### Operational & Design Parameters
* **Airfoil Profile:** NACA 2412
* **Flow Conditions:** Freestream velocity $V_\infty = 25.0\text{ m/s}$ ($Re \approx 2.8 \times 10^6 - 3.0 \times 10^6$), Reference wing area $S_{\text{ref}} = 20.130\text{ m}^2$
* **Target Cruise Condition:** Lift coefficient $C_{L,\text{cruise}} = 0.50$

### Design Constraints
1. **Stall Capacity Constraint:** $C_{L,\max} \ge 1.58$
2. **Static Longitudinal Stability:** Pitching moment slope $C_{m_\alpha} < 0\text{ deg}^{-1}$

### Parametric Design Space (50 Designs)
* **Aspect Ratio ($AR$):** $\{6.00, 7.50\}$
* **Taper Ratio ($TR$):** $\{0.30, 0.47, 0.65, 0.82, 1.00\}$
* **Washout Twist ($TW$):** $\{0.0^\circ, 1.0^\circ, 2.0^\circ, 3.0^\circ, 4.0^\circ\}$

---

## 📊 Performance Comparison Table

| Metric | Baseline Wing | Optimal Design | Performance Impact |
| :--- | :---: | :---: | :---: |
| **Design Designation** | `AR6.00_TR1.00_TW0.00` | **`AR7.50_TR0.47_TW2.00`** | Optimized Geometry |
| **Aspect Ratio ($AR$)** | $6.00$ | **$7.50$** | Higher Span / Aspect Ratio |
| **Taper Ratio ($TR$)** | $1.00$ (Rectangular) | **$0.47$** | Near-Elliptical Circulation |
| **Washout Twist ($TW$)** | $0.0^\circ$ | **$2.0^\circ$** | Tip Stall Mitigation |
| **Cruise Efficiency $(L/D)_{\text{cruise}}$** | $26.43$ | **$31.59$** | **$+19.51\%$ Increase** |
| **Induced Drag Coefficient ($CD_i$)** | $0.01384$ | **$0.01075$** | **$-22.35\%$ Reduction** |
| **Total Drag Coefficient ($CD$)** | $0.01893$ | **$0.01583$** | **$-16.38\%$ Drag Drop** |
| **Maximum Lift ($C_{L,\max}$)** | $1.5012$ | **$1.5813$** | **Stall Constraint Satisfied** |
| **Pitching Moment Slope ($C_{m_\alpha}$)** | $-0.01997\text{ deg}^{-1}$ | **$-0.02280\text{ deg}^{-1}$** | Enhanced Static Stability |

---

## 📈 Visualizations & Trade Study Analysis

![XFLR5 Trade Study Analysis](xflr5_50_designs_trade_study.png)[cite: 1]

1. **Top-Left (Contour Map at $AR=7.50$):** Identifies the sweet spot for cruise efficiency near $TR = 0.47$ and $TW = 2.0^\circ$.
2. **Top-Right (Parallel Coordinates):** Illustrates the multi-variable interactions across all 50 design iterations.
3. **Bottom-Left (Pareto Trade-Off Curve):** Demonstrates how $2.0^\circ$ twist pushes highly efficient $TR=0.47$ designs past the $C_{L,\max} \ge 1.58$ stall line.
4. **Bottom-Right (Sensitivity Analysis & 3D Panel Validation):** Shows high stability against manufacturing twist tolerances and validates VLM against 3D Panel method predictions ($(L/D)_{\text{3D Panel}} = 31.11$, **$<1.5\%$ delta**).

---

## 🛠️ Repository Structure & Quick Start

```text
├── polar_files/                      # Raw 50 XFLR5 export CSV polar files
├── analyze_xflr5_doe.m              # Complete MATLAB extraction & visualization script
├── generate_xflr5_trade_study.m    # Matlab analysis pipeline 
├── extracted_50_designs_metrics.csv # Structured dataset of computed aerodynamic metrics
├── xflr5_50_designs_trade_study.png # 4-panel trade study figure
└── README.md                        # Project documentation
