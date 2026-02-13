import Foundation

/// Tertiary cooling water loop (condenser cooling).
///
/// Models 2 cooling water pumps drawing from a lake/river heat sink.
/// The inlet temperature is fixed (environmental); outlet depends on
/// condenser heat rejection.
enum TertiaryLoop {

    /// Specific heat of water (kJ/(kg*degC))
    private static let cpWater: Double = 4.18

    static func step(state: ReactorState, dt: Double) {
        updatePumps(state: state, dt: dt)
        updateCoolingWater(state: state, dt: dt)
    }

    // MARK: - Cooling Water Pumps

    /// Cooling water pump ramp rate: 75 RPM/s (reaches 1500 RPM in 20s).
    private static let coolingWaterPumpRampRate: Double = 75.0

    /// Cooling water pump coastdown time constant (seconds).
    private static let coolingWaterCoastdownTau: Double = 20.0

    private static func updatePumps(state: ReactorState, dt: Double) {
        for i in 0..<2 {
            if state.coolingWaterPumps[i].tripped {
                // Coastdown from actual RPM at trip
                let timeSinceTrip = state.elapsedTime - state.coolingWaterPumps[i].tripTime
                if timeSinceTrip > 0 {
                    state.coolingWaterPumps[i].rpm = state.coolingWaterPumps[i].rpmAtTrip * exp(-timeSinceTrip / coolingWaterCoastdownTau)
                    if state.coolingWaterPumps[i].rpm < 1.0 {
                        state.coolingWaterPumps[i].rpm = 0.0
                        state.coolingWaterPumps[i].running = false
                    }
                }
            } else if state.coolingWaterPumps[i].running {
                // Ramp toward targetRPM
                let target = state.coolingWaterPumps[i].targetRPM
                if state.coolingWaterPumps[i].rpm < target {
                    state.coolingWaterPumps[i].rpm = min(state.coolingWaterPumps[i].rpm + coolingWaterPumpRampRate * dt, target)
                } else if state.coolingWaterPumps[i].rpm > target {
                    state.coolingWaterPumps[i].rpm = max(state.coolingWaterPumps[i].rpm - coolingWaterPumpRampRate * dt, target)
                }
                // Auto-stop when ramped down to zero
                if target == 0 && state.coolingWaterPumps[i].rpm == 0 {
                    state.coolingWaterPumps[i].running = false
                }
            } else {
                // Off - decay
                state.coolingWaterPumps[i].rpm = max(state.coolingWaterPumps[i].rpm - 75.0 * dt, 0.0)
            }
        }

        // Total cooling water flow
        var totalFlow: Double = 0.0
        let flowPerPump = CANDUConstants.coolingWaterFlowRated / Double(CANDUConstants.coolingWaterPumps)
        for i in 0..<2 {
            let rpmFraction = state.coolingWaterPumps[i].rpm / CANDUConstants.pumpRatedRPM
            totalFlow += flowPerPump * rpmFraction
        }
        state.coolingWaterFlow = totalFlow
    }

    // MARK: - Cooling Water Temperatures

    private static func updateCoolingWater(state: ReactorState, dt: Double) {
        // Inlet temperature is fixed (lake/river)
        state.coolingWaterInletTemp = CANDUConstants.coolingWaterInletTemp

        // Heat rejected to condenser cooling water
        // Q = steam_flow * latent_heat (all the steam that was condensed)
        // At rated: ~2064 MW_th * (1 - efficiency) ~ 1400 MW to cooling water
        let heatRejectedMW: Double
        if state.steamFlow > 0.1 {
            // Heat rejected = thermal power - electrical power generated
            heatRejectedMW = max(state.thermalPower - state.grossPower, 0.0)
        } else {
            heatRejectedMW = 0.0
        }

        let heatRejectedKW = heatRejectedMW * 1000.0

        // Outlet temperature: T_out = T_in + Q / (mdot * cp)
        if state.coolingWaterFlow > 10.0 {
            let deltaT = heatRejectedKW / (state.coolingWaterFlow * cpWater)
            let targetOutlet = state.coolingWaterInletTemp + deltaT

            // Smooth response
            let tau: Double = 15.0
            let alpha = min(dt / tau, 1.0)
            state.coolingWaterOutletTemp = state.coolingWaterOutletTemp * (1.0 - alpha) + targetOutlet * alpha
        } else {
            // No flow - outlet temperature approaches inlet (no heat exchange)
            let alpha = min(dt * 0.05, 1.0)
            state.coolingWaterOutletTemp = state.coolingWaterOutletTemp * (1.0 - alpha) + state.coolingWaterInletTemp * alpha
        }

        // Clamp
        state.coolingWaterOutletTemp = max(state.coolingWaterOutletTemp, state.coolingWaterInletTemp)
        state.coolingWaterOutletTemp = min(state.coolingWaterOutletTemp, 50.0) // environmental limit
    }
}
