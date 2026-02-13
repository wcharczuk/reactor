import Foundation

/// Lumped-parameter thermal model for the CANDU-6 core.
///
/// Two thermal nodes:
///   - Fuel node: receives fission heat, transfers to coolant
///   - Coolant node: receives heat from fuel, transfers to steam generators
///
/// The fuel-to-coolant thermal resistance is modulated by coolant flow rate
/// (better cooling at higher flow).
enum ThermalHydraulics {

    // Thermal time constants and capacities
    // Fuel: M_fuel * cp_fuel ~ 300 kJ/degC -> tau_fuel ~ 5-10 s
    // Coolant: M_coolant * cp_coolant ~ 600 kJ/degC -> tau_coolant ~ 15-20 s

    static func step(state: ReactorState, dt: Double) {
        let thermalPowerKW = state.thermalPower * 1000.0 // Convert MW to kW

        // Flow fraction relative to rated
        let flowFraction = max(state.primaryFlowRate / CANDUConstants.totalRatedFlow, 0.01)

        // Effective fuel-to-coolant resistance: decreases with higher flow
        // At rated flow, R_eff = base resistance
        // At lower flow, resistance increases (worse heat transfer)
        let rEffFuel = CANDUConstants.fuelToCoolantResistance / sqrt(flowFraction)

        // Average coolant temperature (inlet-outlet average)
        let coolantAvg = (state.primaryInletTemp + state.primaryOutletTemp) / 2.0

        // --- Fuel Node ---
        // dT_fuel/dt = (Q_fission - (T_fuel - T_coolant_avg) / R_eff) / (M_fuel * cp_fuel)
        let heatFromFuel = (state.fuelTemp - coolantAvg) / rEffFuel // kW
        let dTfuelDt = (thermalPowerKW - heatFromFuel) / CANDUConstants.fuelHeatCapacity
        state.fuelTemp += dTfuelDt * dt

        // Clamp fuel temperature to physical bounds
        state.fuelTemp = max(state.fuelTemp, state.primaryInletTemp)
        // No upper clamp here - safety system handles meltdown

        // Cladding temperature is between fuel and coolant (simplified)
        state.claddingTemp = coolantAvg + 0.3 * (state.fuelTemp - coolantAvg)

        // --- Coolant Node ---
        // Heat absorbed by coolant from fuel
        let heatToCoolant = heatFromFuel // kW

        // Heat removed by steam generators
        // Use LMTD-based heat exchange
        let heatToSG = computeSGHeatRemoval(state: state) // kW

        // dT_coolant/dt = (heat_from_fuel - heat_to_SG) / (M_coolant * cp_coolant)
        let dTcoolantDt = (heatToCoolant - heatToSG) / CANDUConstants.coolantHeatCapacity

        // Update outlet temperature (inlet is set by PrimaryLoop from cold leg)
        // The outlet temp rises with heat input
        let avgTempChange = dTcoolantDt * dt
        state.primaryOutletTemp += avgTempChange

        // The temperature rise across the core depends on flow and power
        if state.primaryFlowRate > 10.0 {
            // delta_T = Q / (mdot * cp)  where cp_D2O ~ 5.15 kJ/(kg*degC)
            let cpD2O: Double = 5.15 // kJ/(kg*degC)
            let coreDeltaT = thermalPowerKW / (state.primaryFlowRate * cpD2O)
            // Blend toward the physically correct delta-T
            let targetOutlet = state.primaryInletTemp + coreDeltaT
            let blendRate = min(dt * 0.5, 1.0) // smooth transition
            state.primaryOutletTemp = state.primaryOutletTemp * (1.0 - blendRate) + targetOutlet * blendRate
        }

        // Clamp outlet temperature
        state.primaryOutletTemp = max(state.primaryOutletTemp, state.primaryInletTemp)
        state.primaryOutletTemp = min(state.primaryOutletTemp, 400.0) // physical max before things break

        // Natural cooling: if no flow and no heat, temperatures decay to ambient
        if state.primaryFlowRate < 1.0 && thermalPowerKW < 1.0 {
            let ambientDecay = 0.001 * dt // slow decay to ambient
            state.fuelTemp -= ambientDecay * (state.fuelTemp - 25.0)
            state.primaryOutletTemp -= ambientDecay * (state.primaryOutletTemp - 25.0)
        }
    }

    /// Compute heat removal by steam generators using LMTD model.
    /// Returns heat removal in kW.
    private static func computeSGHeatRemoval(state: ReactorState) -> Double {
        // If no flow through primary, very little SG heat transfer
        let flowFraction = state.primaryFlowRate / CANDUConstants.totalRatedFlow
        guard flowFraction > 0.01 else { return 0.0 }

        // Primary hot leg temperature (outlet from core, inlet to SG)
        let tPrimaryHot = state.primaryOutletTemp
        // Primary cold leg temperature (outlet from SG, inlet to core)
        let tPrimaryCold = state.primaryInletTemp
        // Secondary side temperature (steam/boiling temperature)
        let tSecondary = state.steamTemp

        // Ensure we have a meaningful temperature difference
        guard tPrimaryHot > tSecondary + 1.0 else { return 0.0 }

        // LMTD calculation for counterflow heat exchanger
        let dtHot = tPrimaryHot - tSecondary
        let dtCold = tPrimaryCold - tSecondary

        let lmtd: Double
        if abs(dtHot - dtCold) < 0.1 {
            lmtd = (dtHot + dtCold) / 2.0
        } else if dtCold > 0.1 {
            lmtd = (dtHot - dtCold) / log(dtHot / dtCold)
        } else {
            lmtd = dtHot / 2.0
        }

        // Q = UA * LMTD, scaled by flow fraction (turbulent HTC scales with flow)
        let uaEffective = CANDUConstants.sgUA * pow(flowFraction, 0.8)
        let qSG = uaEffective * max(lmtd, 0.0) // kW

        return qSG
    }
}
