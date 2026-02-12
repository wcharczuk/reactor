import Foundation

/// Electrical system: generator, grid connection, station service, diesels.
enum Electrical {

    static func step(state: ReactorState, dt: Double) {
        updateGenerator(state: state, dt: dt)
        updateStationService(state: state)
        updateNetPower(state: state)
    }

    // MARK: - Generator

    private static func updateGenerator(state: ReactorState, dt: Double) {
        // Generator frequency from turbine RPM
        // f = RPM * poles / (2 * 60) = RPM / 30 for 4-pole machine
        let poles = Double(CANDUConstants.generatorPoles)
        state.generatorFrequency = state.turbineRPM * poles / (2.0 * 60.0)

        // Gross electrical power from turbine
        if state.turbineRPM > 100.0 && state.generatorConnected {
            // Mechanical power to electrical
            // P_mech from steam: mdot * delta_h * eta_turbine
            let steamToTurbine = state.steamFlow * state.turbineGovernor
            let enthalpyDrop: Double = 800.0 // kJ/kg
            let mechPowerMW = steamToTurbine * enthalpyDrop * CANDUConstants.turbineEfficiency / 1000.0
            let grossElectrical = mechPowerMW * CANDUConstants.generatorEfficiency

            // Smooth response
            let tau: Double = 2.0
            let alpha = min(dt / tau, 1.0)
            state.grossPower = state.grossPower * (1.0 - alpha) + grossElectrical * alpha

            // Clamp
            state.grossPower = max(state.grossPower, 0.0)
            state.grossPower = min(state.grossPower, CANDUConstants.ratedGrossElectrical * 1.05)
        } else if state.turbineRPM > 100.0 && !state.generatorConnected {
            // Turbine spinning but not connected - no power output
            let tau: Double = 1.0
            let alpha = min(dt / tau, 1.0)
            state.grossPower = state.grossPower * (1.0 - alpha)
        } else {
            // Turbine not spinning meaningfully
            let tau: Double = 1.0
            let alpha = min(dt / tau, 1.0)
            state.grossPower = state.grossPower * (1.0 - alpha)
        }

        // Generator can only connect to grid when frequency is close to 60 Hz
        // (This is a constraint for the connect command, not enforced here)
    }

    // MARK: - Station Service

    private static func updateStationService(state: ReactorState) {
        // Station service load: base + pumps + auxiliaries
        var load = CANDUConstants.stationServiceBase // 70 MW base

        // Primary pump power
        for pump in state.primaryPumps {
            if pump.running {
                let rpmFraction = pump.rpm / CANDUConstants.pumpRatedRPM
                // Pump power scales with cube of speed (affinity laws)
                load += CANDUConstants.pumpMotorPower * pow(rpmFraction, 3.0)
            }
        }

        // Cooling water pump power
        for pump in state.coolingWaterPumps {
            if pump.running {
                let rpmFraction = pump.rpm / CANDUConstants.pumpRatedRPM
                load += CANDUConstants.coolingWaterPumpPower * pow(rpmFraction, 3.0)
            }
        }

        // Feed pump power (simplified - proportional to flow)
        for feedPump in state.feedPumps {
            if feedPump.running {
                load += 3.0 // ~3 MW per feed pump
            }
        }

        state.stationServiceLoad = load
    }

    // MARK: - Net Power

    private static func updateNetPower(state: ReactorState) {
        // Net power = power exported to the grid (never negative)
        if state.generatorConnected {
            // Main generator online: net = gross - station service
            state.netPower = max(state.grossPower - state.stationServiceLoad, 0.0)
        } else {
            // Generator not connected: plant is consuming from diesels, not exporting
            state.netPower = 0.0
        }
    }
}
