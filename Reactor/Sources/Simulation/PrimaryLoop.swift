import Foundation

/// Primary heavy water (D2O) heat transport loop.
///
/// Models 4 primary coolant pumps with coastdown, flow calculation,
/// and pressure response to temperature changes.
enum PrimaryLoop {

    static func step(state: ReactorState, dt: Double) {
        updatePumps(state: state, dt: dt)
        updateFlow(state: state)
        updatePressure(state: state, dt: dt)
        updateInletTemperature(state: state, dt: dt)
    }

    // MARK: - Pump Dynamics

    /// Primary pump ramp rate: 50 RPM/s (reaches 1500 RPM in 30s).
    private static let primaryPumpRampRate: Double = 50.0

    private static func updatePumps(state: ReactorState, dt: Double) {
        for i in 0..<4 {
            if state.primaryPumps[i].tripped {
                // Pump is coasting down - exponential decay from actual RPM at trip
                let timeSinceTrip = state.elapsedTime - state.primaryPumps[i].tripTime
                if timeSinceTrip > 0 {
                    state.primaryPumps[i].rpm = state.primaryPumps[i].rpmAtTrip * exp(-timeSinceTrip / CANDUConstants.pumpCoastdownTau)
                    if state.primaryPumps[i].rpm < 1.0 {
                        state.primaryPumps[i].rpm = 0.0
                        state.primaryPumps[i].running = false
                    }
                }
            } else if state.primaryPumps[i].running {
                // Ramp toward targetRPM
                let target = state.primaryPumps[i].targetRPM
                if state.primaryPumps[i].rpm < target {
                    state.primaryPumps[i].rpm = min(state.primaryPumps[i].rpm + primaryPumpRampRate * dt, target)
                } else if state.primaryPumps[i].rpm > target {
                    state.primaryPumps[i].rpm = max(state.primaryPumps[i].rpm - primaryPumpRampRate * dt, target)
                }
                // Auto-stop when ramped down to zero
                if target == 0 && state.primaryPumps[i].rpm == 0 {
                    state.primaryPumps[i].running = false
                }
            } else {
                // Pump is off - rpm decays
                if state.primaryPumps[i].rpm > 0.0 {
                    state.primaryPumps[i].rpm = max(state.primaryPumps[i].rpm - 50.0 * dt, 0.0)
                }
            }
        }
    }

    // MARK: - Flow Calculation

    private static func updateFlow(state: ReactorState) {
        // Total flow = sum of individual pump flows
        // Flow is proportional to RPM (affinity law: Q proportional to N)
        var totalFlow: Double = 0.0
        for i in 0..<4 {
            let rpmFraction = state.primaryPumps[i].rpm / CANDUConstants.pumpRatedRPM
            let pumpFlow = CANDUConstants.pumpRatedFlow * rpmFraction
            totalFlow += pumpFlow
        }
        state.primaryFlowRate = totalFlow
    }

    // MARK: - Pressure Model

    private static func updatePressure(state: ReactorState, dt: Double) {
        // Primary pressure depends on average coolant temperature
        // At cold conditions (~25C), pressure is low
        // At operating conditions (~287C avg), pressure is ~10 MPa

        let tAvg = (state.primaryInletTemp + state.primaryOutletTemp) / 2.0

        // Base pressure accounts for pressurizer setpoint
        // Linear model: P = P_ref + alpha * (T_avg - T_ref)
        // At T_ref = 287C, P = 10 MPa
        let tRef: Double = 287.0 // reference average temperature at rated conditions
        let pRef: Double = CANDUConstants.primaryPressureRated

        // Below ~100C, the system is essentially depressurized
        // Above 100C, pressure builds up
        let targetPressure: Double
        if tAvg < 100.0 {
            targetPressure = 0.1 + (tAvg - 25.0) * 0.001 // very low pressure
        } else {
            // Pressurizer maintains setpoint with temperature compensation
            targetPressure = pRef + CANDUConstants.primaryPressureCoeff * (tAvg - tRef)
        }

        // Pressure responds with a time constant (pressurizer dynamics)
        let pressureTau: Double = 5.0 // seconds
        let alpha = min(dt / pressureTau, 1.0)
        state.primaryPressure = state.primaryPressure * (1.0 - alpha) + targetPressure * alpha

        // Clamp pressure to physical bounds
        state.primaryPressure = max(state.primaryPressure, 0.05)
        state.primaryPressure = min(state.primaryPressure, 15.0)
    }

    // MARK: - Inlet Temperature (Cold Leg)

    private static func updateInletTemperature(state: ReactorState, dt: Double) {
        // Inlet temperature = outlet of SG (cold leg)
        // When SGs are transferring heat, inlet temp drops below outlet temp
        // The SG cools the primary coolant toward the secondary side temperature

        let flowFraction = state.primaryFlowRate / CANDUConstants.totalRatedFlow

        if flowFraction > 0.01 {
            // Heat removed by SGs determines the temperature drop
            // At rated conditions: inlet ~265C, outlet ~310C -> delta_T = 45C
            // The inlet temp is outlet temp minus the core delta-T
            // But it's also the SG outlet, which depends on SG heat transfer

            // Simple model: inlet approaches a target based on secondary side temp
            // At rated conditions, cold leg is about 5-10C above steam temp
            let sgApproach: Double = 8.0 // degC approach temperature above secondary
            let targetInlet: Double

            if state.steamTemp > 50.0 {
                targetInlet = state.steamTemp + sgApproach / max(flowFraction, 0.1)
            } else {
                // No steam generation, SGs aren't effective heat sinks
                // Inlet temperature slowly approaches outlet temperature (no cooling)
                targetInlet = state.primaryOutletTemp
            }

            let inletTau: Double = 20.0 // thermal transport delay
            let alpha = min(dt / inletTau, 1.0)
            state.primaryInletTemp = state.primaryInletTemp * (1.0 - alpha) + targetInlet * alpha
        } else {
            // No flow - temperatures equalize slowly (natural convection)
            let natConvRate = 0.002 * dt
            let avgTemp = (state.primaryInletTemp + state.primaryOutletTemp) / 2.0
            state.primaryInletTemp = state.primaryInletTemp + natConvRate * (avgTemp - state.primaryInletTemp)
        }

        // Inlet cannot be higher than outlet in normal operation
        // (but might transiently during unusual conditions)
        state.primaryInletTemp = max(state.primaryInletTemp, 20.0)
        state.primaryInletTemp = min(state.primaryInletTemp, state.primaryOutletTemp + 5.0)
    }
}
