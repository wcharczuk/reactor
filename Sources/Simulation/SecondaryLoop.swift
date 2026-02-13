import Foundation

/// Secondary (light water) loop: steam generators, turbine, condenser, feed pumps.
enum SecondaryLoop {

    // MARK: - Constants

    /// Latent heat of vaporization for water at ~4.7 MPa (kJ/kg)
    private static let latentHeat: Double = 1850.0

    /// Specific enthalpy drop across turbine (kJ/kg)
    private static let turbineEnthalpyDrop: Double = 2090.0

    /// Specific heat of water (kJ/(kg*degC))
    private static let cpWater: Double = 4.18

    /// Steam drum mass for transient response (kg per SG)
    private static let sgWaterMass: Double = 30000.0

    // MARK: - Main Step

    static func step(state: ReactorState, dt: Double) {
        updateSteamGenerators(state: state, dt: dt)
        updateSteamConditions(state: state, dt: dt)
        updateTurbine(state: state, dt: dt)
        updateCondenser(state: state, dt: dt)
        updateFeedPumps(state: state, dt: dt)
    }

    // MARK: - Steam Generators

    private static func updateSteamGenerators(state: ReactorState, dt: Double) {
        // Heat transfer from primary to secondary via SG tubes
        // Q_SG = UA * LMTD (already computed in ThermalHydraulics for the primary side)
        // Here we handle the secondary side response

        let flowFraction = state.primaryFlowRate / CANDUConstants.totalRatedFlow

        // Steam generation rate depends on primary-to-secondary heat transfer
        let tPrimaryHot = state.primaryOutletTemp
        let tPrimaryCold = state.primaryInletTemp
        let tSecondary = state.steamTemp

        // Compute heat transfer to secondary side
        var qToSecondary: Double = 0.0 // kW total

        if tPrimaryHot > tSecondary + 2.0 && flowFraction > 0.01 {
            let dtHot = tPrimaryHot - tSecondary
            let dtCold = max(tPrimaryCold - tSecondary, 0.5)

            let lmtd: Double
            if abs(dtHot - dtCold) < 0.1 {
                lmtd = (dtHot + dtCold) / 2.0
            } else {
                lmtd = (dtHot - dtCold) / log(max(dtHot / dtCold, 0.01))
            }

            let uaEffective = CANDUConstants.sgUA * pow(flowFraction, 0.8)
            qToSecondary = uaEffective * max(lmtd, 0.0)
        }

        // Steam generation rate (kg/s) = Q / latent_heat
        let steamGenerationRate = qToSecondary / latentHeat

        // Feedwater input to SGs
        var totalFeedFlow: Double = 0.0
        for pump in state.feedPumps {
            if pump.running {
                totalFeedFlow += pump.flowRate
            }
        }

        // Distribute feedwater evenly among SGs
        let feedPerSG = totalFeedFlow / Double(CANDUConstants.sgCount)
        let steamPerSG = steamGenerationRate / Double(CANDUConstants.sgCount)

        // Update SG levels (mass balance)
        for i in 0..<CANDUConstants.sgCount {
            // Level change = (feedwater_in - steam_out) / water_mass * 100
            let massBalance = feedPerSG - steamPerSG // kg/s net into SG
            let levelChange = (massBalance / sgWaterMass) * 100.0 * dt // % change
            state.sgLevels[i] += levelChange
            state.sgLevels[i] = min(max(state.sgLevels[i], 0.0), 100.0)
        }

        // Update steam flow to turbine
        state.steamFlow = steamGenerationRate
    }

    // MARK: - Steam Conditions

    private static func updateSteamConditions(state: ReactorState, dt: Double) {
        // Steam pressure depends on the balance between steam generation and consumption
        // At steady state with turbine governor: pressure is maintained

        // Steam generation rate drives pressure up, turbine consumption drives it down
        let steamGenerationRate = state.steamFlow // kg/s produced
        let steamConsumptionRate = state.steamFlow * state.turbineGovernor // kg/s to turbine

        // Effective steam volume (m^3) - simplified
        let steamVolume: Double = 200.0 // effective volume of steam system

        // Pressure change from mass imbalance
        // Using ideal gas approximation: dP/dt ~ (R*T/V) * (dm_in/dt - dm_out/dt)
        // Simplified: pressure proportional to steam inventory
        let netSteamRate = steamGenerationRate - steamConsumptionRate
        let pressureChangeRate = netSteamRate * 0.005 // MPa per (kg/s) empirical scaling
        var targetPressure = state.steamPressure + pressureChangeRate * dt

        // If we have meaningful heat input, pressure builds toward a physical equilibrium
        if state.thermalPower > 10.0 {
            // Equilibrium steam pressure correlates with thermal power fraction
            let equilibriumPressure = CANDUConstants.steamPressureRated * min(state.thermalPowerFraction, 1.1)
            let tau: Double = 60.0 // pressure response time constant
            let alpha = min(dt / tau, 1.0)
            targetPressure = state.steamPressure * (1.0 - alpha) + equilibriumPressure * alpha
        } else {
            // System depressurizing
            let decayRate = 0.001 * dt
            targetPressure = state.steamPressure * (1.0 - decayRate)
        }

        state.steamPressure = max(targetPressure, 0.0004)
        state.steamPressure = min(state.steamPressure, 6.0) // safety relief valves

        // Steam temperature = saturation temperature at current pressure
        // Using simplified Clausius-Clapeyron / Antoine equation approximation
        state.steamTemp = saturationTemperature(pressureMPa: state.steamPressure)

        // Feedwater temperature: preheated by extraction steam (simplified)
        // At rated conditions ~187C, scales with turbine power
        if state.turbineRPM > 100.0 {
            let powerFraction = state.grossPower / CANDUConstants.ratedGrossElectrical
            let targetFeedTemp = 50.0 + (CANDUConstants.feedwaterTempRated - 50.0) * min(powerFraction, 1.0)
            let tau: Double = 120.0 // feedwater heater time constant
            let alpha = min(dt / tau, 1.0)
            state.feedwaterTemp = state.feedwaterTemp * (1.0 - alpha) + targetFeedTemp * alpha
        } else {
            // No feedwater heating
            let alpha = min(dt * 0.01, 1.0)
            state.feedwaterTemp = state.feedwaterTemp * (1.0 - alpha) + 25.0 * alpha
        }
    }

    // MARK: - Turbine

    private static func updateTurbine(state: ReactorState, dt: Double) {
        // Turbine mechanical power
        // P_mech = mdot_steam * delta_h * governor_opening
        let steamToTurbine = state.steamFlow * state.turbineGovernor // kg/s
        let mechPowerKW = steamToTurbine * turbineEnthalpyDrop * CANDUConstants.turbineEfficiency
        let mechPowerMW = mechPowerKW / 1000.0

        // Turbine RPM dynamics
        // The turbine accelerates/decelerates based on torque balance:
        //   J * d(omega)/dt = torque_steam - torque_electrical - torque_friction
        // Simplified: RPM tracks toward equilibrium based on power balance

        let targetRPM: Double
        if state.turbineGovernor > 0.01 && state.steamPressure > 0.5 {
            // Turbine should be spinning
            if state.generatorConnected {
                // Grid-connected: frequency locked to grid, RPM = 1800
                targetRPM = CANDUConstants.turbineRatedRPM
            } else {
                // Free-spinning (no generator load): RPM proportional to sqrt of
                // steam power vs friction/windage. Continuous from 0 to rated RPM.
                let frictionPower: Double = 5.0 // MW friction/windage losses
                if mechPowerMW > 0.01 {
                    targetRPM = CANDUConstants.turbineRatedRPM * min(sqrt(mechPowerMW / frictionPower), 1.0)
                } else {
                    targetRPM = 0.0
                }
            }
        } else {
            // No steam or governor closed
            targetRPM = 0.0
        }

        // RPM response
        let rpmTau: Double = 2.0 // seconds response time
        let alpha = min(dt / rpmTau, 1.0)
        state.turbineRPM = state.turbineRPM * (1.0 - alpha) + targetRPM * alpha

        // Prevent negative RPM
        state.turbineRPM = max(state.turbineRPM, 0.0)
    }

    // MARK: - Condenser

    private static func updateCondenser(state: ReactorState, dt: Double) {
        // Condenser pressure and temperature depend on cooling water
        let coolingAvailable = state.coolingWaterFlow > 100.0

        if coolingAvailable {
            // Condenser pressure set by cooling water temperature + approach delta-T
            let approachDeltaT: Double = 12.0 // degC above cooling water outlet
            let condenserTargetTemp = state.coolingWaterOutletTemp + approachDeltaT

            let tau: Double = 30.0
            let alpha = min(dt / tau, 1.0)
            state.condenserTemp = state.condenserTemp * (1.0 - alpha) + condenserTargetTemp * alpha

            // Condenser pressure = saturation pressure at condenser temp
            state.condenserPressure = saturationPressure(tempC: state.condenserTemp)
        } else {
            // No cooling water - condenser heats up
            if state.steamFlow > 1.0 {
                state.condenserTemp += 0.1 * dt // heating up
                state.condenserPressure = saturationPressure(tempC: state.condenserTemp)
            }
        }

        // Clamp
        state.condenserTemp = max(state.condenserTemp, 15.0)
        state.condenserTemp = min(state.condenserTemp, 80.0)
        state.condenserPressure = max(state.condenserPressure, 0.001)
        state.condenserPressure = min(state.condenserPressure, 0.1)
    }

    // MARK: - Feed Pumps

    private static func updateFeedPumps(state: ReactorState, dt: Double) {
        // Each running feed pump provides feedwater flow
        // Flow rate depends on differential pressure (SG pressure - feed header pressure)
        let ratedFlowPerPump = CANDUConstants.steamFlowRated / 2.0 // 2 pumps for rated flow, 3rd for margin

        // SG level feedback: increase feed when level drops, decrease when high
        let avgSGLevel = state.sgLevels.reduce(0.0, +) / Double(CANDUConstants.sgCount)
        let levelError = (CANDUConstants.sgLevelNominal - avgSGLevel) / 100.0 // -0.5 to +0.5
        let levelCorrection = 1.0 + levelError * 5.0 // ±250% adjustment for ±50% error

        // How many feed pumps are running?
        let runningFeedPumps = state.feedPumps.filter { $0.running }.count

        for i in 0..<3 {
            if state.feedPumps[i].running {
                // Feed pump flow tracks actual steam generation, split among running pumps
                let demandPerPump = runningFeedPumps > 0
                    ? state.steamFlow / Double(runningFeedPumps)
                    : 0.0
                let demandFlow = min(demandPerPump, ratedFlowPerPump)
                // Minimum flow to maintain SG level when it drifts below nominal
                let minFlow: Double = levelError > 0.01 ? ratedFlowPerPump * 0.05 : 0.0
                let targetFlow = max(demandFlow * levelCorrection, minFlow)
                let tau: Double = 10.0
                let alpha = min(dt / tau, 1.0)
                state.feedPumps[i].flowRate = state.feedPumps[i].flowRate * (1.0 - alpha) + targetFlow * alpha
                state.feedPumps[i].flowRate = max(state.feedPumps[i].flowRate, 0.0)
            } else {
                // Pump off - flow decays
                state.feedPumps[i].flowRate = max(state.feedPumps[i].flowRate - 50.0 * dt, 0.0)
            }
        }
    }

    // MARK: - Steam Tables (Simplified)

    /// Saturation temperature in degC for a given pressure in MPa.
    /// Power-law correlation: fits 0.1-10 MPa within ±5°C of real steam tables.
    ///   0.1 MPa → 100°C, 1.0 MPa → 178°C, 4.7 MPa → 262°C, 10 MPa → 316°C
    static func saturationTemperature(pressureMPa: Double) -> Double {
        let pClamped = min(max(pressureMPa, 0.0001), 22.0)
        return 100.0 * pow(pClamped / 0.1, 0.25)
    }

    /// Saturation pressure in MPa for a given temperature in degC.
    /// Inverse of the power-law saturation temperature correlation.
    static func saturationPressure(tempC: Double) -> Double {
        let tClamped = min(max(tempC, 10.0), 370.0)
        let pressure = 0.1 * pow(tClamped / 100.0, 4.0)
        return min(max(pressure, 0.0001), 22.0)
    }
}
