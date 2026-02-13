import Foundation

/// Reactor safety system: automatic SCRAM triggers, shutoff rod insertion, decay heat.
enum SafetySystem {

    // MARK: - SCRAM Setpoints

    private static let highNeutronPowerSetpoint: Double = 1.03     // 103% of full power
    private static let highPowerRateSetpoint: Double = 0.15        // 15%/s
    private static let lowPrimaryPressureSetpoint: Double = 7.0    // MPa
    private static let highPrimaryPressureSetpoint: Double = 11.5  // MPa
    private static let lowPrimaryFlowSetpoint: Double = 0.50       // 50% of rated
    private static let lowSGLevelSetpoint: Double = 20.0           // %
    private static let highFuelTempSetpoint: Double = 2500.0       // degC

    // Smoothed power rate (exponential moving average over ~1 second)
    private static var smoothedRate: Double = 0.0
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

        // 2. High power rate (log rate) — smoothed over ~1s, bypassed below 30% FP
        if dt > 1e-6 {
            let instantRate = (state.neutronDensity - previousNeutronDensity) / dt
            // Exponential moving average with ~1 second time constant
            let rateTau: Double = 1.0
            let rateAlpha = min(dt / rateTau, 1.0)
            smoothedRate = smoothedRate * (1.0 - rateAlpha) + instantRate * rateAlpha

            if state.thermalPowerFraction > 0.30 && smoothedRate > highPowerRateSetpoint {
                initiateScram(state: state, reason: "HIGH LOG RATE (>\(Int(highPowerRateSetpoint * 100))%/s)")
                return
            }
        }
        previousNeutronDensity = state.neutronDensity
        previousTime = state.elapsedTime

        // 3. Low primary pressure (bypassed during startup — only above 30% power)
        if state.thermalPowerFraction > 0.30 && state.primaryPressure < lowPrimaryPressureSetpoint {
            initiateScram(state: state, reason: "LOW PHT PRESSURE (<\(lowPrimaryPressureSetpoint) MPa)")
            return
        }

        // 4. High primary pressure
        if state.primaryPressure > highPrimaryPressureSetpoint {
            initiateScram(state: state, reason: "HIGH PHT PRESSURE (>\(highPrimaryPressureSetpoint) MPa)")
            return
        }

        // 5. Low primary flow (bypassed during startup — only above 50% power)
        if state.thermalPowerFraction > 0.50 {
            let flowFraction = state.primaryFlowRate / CANDUConstants.totalRatedFlow
            if flowFraction < lowPrimaryFlowSetpoint {
                initiateScram(state: state, reason: "LOW PHT FLOW (<\(Int(lowPrimaryFlowSetpoint * 100))%)")
                return
            }
        }

        // 6. Low SG level (any SG)
        for i in 0..<CANDUConstants.sgCount {
            if state.sgLevels[i] < lowSGLevelSetpoint && state.thermalPowerFraction > 0.30 {
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

    // MARK: - Process Alarms (non-SCRAM warnings)

    /// Check process conditions and raise warning/alarm level alerts.
    /// Called periodically (not every substep) to avoid spam.
    static func checkProcessAlarms(state: ReactorState) {
        // SG level alarms
        let sgAvg = state.sgLevels.reduce(0.0, +) / Double(state.sgLevels.count)
        raiseOnCondition(state: state, key: "SG_LEVEL_LOW",
                         condition: sgAvg < 15 && state.thermalPower > 1.0,
                         message: "SG LEVEL LOW (<15%)", severity: .alarm)
        raiseOnCondition(state: state, key: "SG_LEVEL_WARN",
                         condition: sgAvg < 30 && sgAvg >= 15 && state.thermalPower > 1.0,
                         message: "SG LEVEL DECREASING (<30%)", severity: .warning)

        // High fuel temperature warning (before SCRAM)
        raiseOnCondition(state: state, key: "FUEL_TEMP_HIGH",
                         condition: state.fuelTemp > 2200 && state.fuelTemp <= 2500,
                         message: "FUEL TEMP HIGH (>\(Int(state.fuelTemp)) DEG C)", severity: .warning)

        // High fuel temperature alarm
        raiseOnCondition(state: state, key: "FUEL_TEMP_ALARM",
                         condition: state.fuelTemp > 2500,
                         message: "FUEL TEMP VERY HIGH (>\(Int(state.fuelTemp)) DEG C)", severity: .alarm)
    }

    /// Raise a process alarm once when condition becomes true; clear when false.
    private static func raiseOnCondition(state: ReactorState, key: String,
                                          condition: Bool, message: String,
                                          severity: AlarmEntry.AlarmSeverity) {
        if condition {
            if !state.raisedProcessAlarms.contains(key) {
                state.addAlarm(message: message, severity: severity)
                state.raisedProcessAlarms.insert(key)
            }
        } else {
            state.raisedProcessAlarms.remove(key)
        }
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
