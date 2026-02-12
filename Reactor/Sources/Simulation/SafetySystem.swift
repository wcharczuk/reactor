import Foundation

/// Reactor safety system: automatic SCRAM triggers, shutoff rod insertion, decay heat.
enum SafetySystem {

    // MARK: - SCRAM Setpoints

    private static let highNeutronPowerSetpoint: Double = 1.03     // 103% of full power
    private static let highPowerRateSetpoint: Double = 0.10        // 10%/s
    private static let lowPrimaryPressureSetpoint: Double = 9.0    // MPa
    private static let highPrimaryPressureSetpoint: Double = 11.5  // MPa
    private static let lowPrimaryFlowSetpoint: Double = 0.80       // 80% of rated
    private static let lowSGLevelSetpoint: Double = 20.0           // %
    private static let highFuelTempSetpoint: Double = 2500.0       // degC

    // Previous neutron density for rate calculation
    private static var previousNeutronDensity: Double = 1e-8
    private static var previousTime: Double = 0.0

    // MARK: - Main Step

    static func step(state: ReactorState, dt: Double) {
        // If SCRAM is already active, handle shutoff rod insertion
        if state.scramActive {
            handleScramInsertion(state: state, dt: dt)
            // Track shutdown time
            if state.shutdownTime < 0 {
                state.shutdownTime = state.elapsedTime
            }
            return
        }

        // Check all automatic SCRAM triggers
        checkScramConditions(state: state, dt: dt)
    }

    // MARK: - SCRAM Condition Checks

    private static func checkScramConditions(state: ReactorState, dt: Double) {
        // Only check SCRAM conditions if the reactor is above source level
        // (don't scram during initial startup from source range)
        guard state.neutronDensity > 1e-4 else {
            previousNeutronDensity = state.neutronDensity
            previousTime = state.elapsedTime
            return
        }

        // 1. High neutron power
        if state.neutronDensity > highNeutronPowerSetpoint {
            initiateScram(state: state, reason: "HIGH NEUTRON POWER (>\(Int(highNeutronPowerSetpoint * 100))% FP)")
            return
        }

        // 2. High power rate (log rate)
        if dt > 1e-6 {
            let rate = (state.neutronDensity - previousNeutronDensity) / dt
            if rate > highPowerRateSetpoint {
                initiateScram(state: state, reason: "HIGH LOG RATE (>\(Int(highPowerRateSetpoint * 100))%/s)")
                return
            }
        }
        previousNeutronDensity = state.neutronDensity
        previousTime = state.elapsedTime

        // 3. Low primary pressure (bypassed during startup — only above 15% power)
        if state.thermalPowerFraction > 0.15 && state.primaryPressure < lowPrimaryPressureSetpoint {
            initiateScram(state: state, reason: "LOW PHT PRESSURE (<\(lowPrimaryPressureSetpoint) MPa)")
            return
        }

        // 4. High primary pressure
        if state.primaryPressure > highPrimaryPressureSetpoint {
            initiateScram(state: state, reason: "HIGH PHT PRESSURE (>\(highPrimaryPressureSetpoint) MPa)")
            return
        }

        // 5. Low primary flow (bypassed during startup — only above 15% power)
        if state.thermalPowerFraction > 0.15 {
            let flowFraction = state.primaryFlowRate / CANDUConstants.totalRatedFlow
            if flowFraction < lowPrimaryFlowSetpoint {
                initiateScram(state: state, reason: "LOW PHT FLOW (<\(Int(lowPrimaryFlowSetpoint * 100))%)")
                return
            }
        }

        // 6. Low SG level (any SG)
        for i in 0..<CANDUConstants.sgCount {
            if state.sgLevels[i] < lowSGLevelSetpoint && state.thermalPowerFraction > 0.15 {
                initiateScram(state: state, reason: "LOW SG \(i + 1) LEVEL (<\(Int(lowSGLevelSetpoint))%)")
                return
            }
        }

        // 7. High fuel temperature
        if state.fuelTemp > highFuelTempSetpoint {
            initiateScram(state: state, reason: "HIGH FUEL TEMP (>\(Int(highFuelTempSetpoint)) DEG C)")
            return
        }
    }

    // MARK: - SCRAM Initiation

    static func initiateScram(state: ReactorState, reason: String) {
        guard !state.scramActive else { return } // Already scrammed

        state.scramActive = true
        state.scramTime = state.elapsedTime
        state.shutdownTime = state.elapsedTime

        // Snap time acceleration to 1x
        state.timeAcceleration = 1.0

        // Add alarm
        let alarm = Alarm(
            time: state.elapsedTime,
            message: "*** SCRAM: \(reason) ***",
            acknowledged: false
        )
        state.alarms.append(alarm)

        // Begin shutoff rod insertion (initial state)
        state.shutoffRodsInserted = true
        // shutoffRodInsertionFraction will be ramped up in handleScramInsertion
    }

    // MARK: - Shutoff Rod Insertion During SCRAM

    private static func handleScramInsertion(state: ReactorState, dt: Double) {
        let timeSinceScram = state.elapsedTime - state.scramTime
        guard timeSinceScram >= 0 else { return }

        // Shutoff rods go from 0 (withdrawn) to 1 (fully inserted)
        // Insertion time < 2 seconds (gravity-driven drop)
        // Model as rapid insertion with slight S-curve shape
        if timeSinceScram < CANDUConstants.scramInsertionTime {
            // Fast insertion - approximately linear (gravity drop)
            let fraction = timeSinceScram / CANDUConstants.scramInsertionTime
            // Use a quick ramp that gets most of the worth in fast
            // (rods accelerate under gravity)
            state.shutoffRodInsertionFraction = min(pow(fraction, 0.7), 1.0)
        } else {
            state.shutoffRodInsertionFraction = 1.0
        }
    }

    // MARK: - SCRAM Reset

    /// Reset the SCRAM state (operator action to clear scram after conditions are met).
    static func resetScram(state: ReactorState) {
        // Can only reset if neutron density is at source level
        guard state.neutronDensity < 1e-4 else { return }

        state.scramActive = false
        // Shutoff rods remain inserted - operator must withdraw them separately
        // Reset the rate monitoring
        previousNeutronDensity = state.neutronDensity
        previousTime = state.elapsedTime
    }

    // MARK: - Decay Heat (Utility)

    /// Compute decay heat power in MW using ANS-5.1 approximation.
    ///   Q_decay = Q_rated * 0.066 * t^(-0.2)
    /// where t = time since shutdown in seconds.
    static func decayHeatPower(ratedPower: Double, timeSinceShutdown: Double) -> Double {
        guard timeSinceShutdown > 0.1 else {
            return 0.07 * ratedPower // ~7% immediately after shutdown
        }
        let decay = ratedPower * 0.066 * pow(timeSinceShutdown, -0.2)
        return min(max(decay, 0.0), 0.07 * ratedPower)
    }
}
