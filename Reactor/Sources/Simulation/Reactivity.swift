import Foundation

/// Reactivity calculation for all control devices, feedback, and xenon poisoning.
///
/// All reactivity values are in mk (milli-k). The total is stored in state.totalReactivity.
///
/// Also contains the Xe-135 / I-135 dynamics (two coupled ODEs).
enum Reactivity {

    // MARK: - S-Curve Rod Worth

    /// Rod worth as a function of position using the standard S-curve model.
    ///
    /// rho(z) = rho_total * 0.5 * [z - sin(2*pi*z) / (2*pi)]
    ///
    /// where z is the withdrawal fraction (0 = fully inserted, 1 = fully withdrawn).
    /// Returns positive reactivity when withdrawn (adding reactivity).
    static func rodWorthFraction(_ z: Double) -> Double {
        let zClamped = min(max(z, 0.0), 1.0)
        let twoPi = 2.0 * Double.pi
        return 0.5 * (zClamped - sin(twoPi * zClamped) / twoPi)
        // Note: This gives 0 at z=0 and 0.5 at z=1; we normalize so full
        // withdrawal gives the full worth. The integral shape means:
        // At z=0 -> 0, at z=0.5 -> 0.5, at z=1 -> 0.5
        // Actually let's verify: z=1 -> 0.5*(1 - sin(2pi)/2pi) = 0.5*(1-0) = 0.5
        // We want z=1 to give fraction=1.0 (full worth), so multiply by 2.
    }

    /// Corrected rod worth: returns fraction of total worth extracted at position z.
    /// z=0 (fully inserted) -> 0, z=1 (fully withdrawn) -> 1.0
    static func rodWorthExtracted(_ z: Double) -> Double {
        let zClamped = min(max(z, 0.0), 1.0)
        let twoPi = 2.0 * Double.pi
        // The integral rod worth S-curve: symmetric, with inflection at z=0.5
        // Normalized so it maps [0,1] -> [0,1]
        let raw = zClamped - sin(twoPi * zClamped) / twoPi
        // raw at z=0 is 0, at z=1 is 1.0 (since sin(2pi)=0)
        return raw
    }

    // MARK: - Rod Movement

    /// Ramp adjuster rods and MCAs toward their target positions at realistic motor-driven speeds.
    static func rampRods(state: ReactorState, dt: Double) {
        // Adjuster rods: ~60s full stroke
        for i in 0..<4 {
            let target = state.adjusterTargetPositions[i]
            let current = state.adjusterPositions[i]
            if current != target {
                let maxMove = CANDUConstants.adjusterRodSpeed * dt
                if target > current {
                    state.adjusterPositions[i] = min(current + maxMove, target)
                } else {
                    state.adjusterPositions[i] = max(current - maxMove, target)
                }
            }
        }
        // MCAs: ~30s full stroke
        for i in 0..<2 {
            let target = state.mcaTargetPositions[i]
            let current = state.mcaPositions[i]
            if current != target {
                let maxMove = CANDUConstants.mcaRodSpeed * dt
                if target > current {
                    state.mcaPositions[i] = min(current + maxMove, target)
                } else {
                    state.mcaPositions[i] = max(current - maxMove, target)
                }
            }
        }
    }

    // MARK: - Update All Reactivity Components

    static func update(state: ReactorState) {
        // 1. Adjuster rods (positive reactivity when withdrawn)
        var adjusterReactivity: Double = 0.0
        for i in 0..<4 {
            let worthExtracted = rodWorthExtracted(state.adjusterPositions[i])
            adjusterReactivity += CANDUConstants.adjusterBankWorth * worthExtracted
        }

        // 2. MCA - Mechanical Control Absorbers (positive reactivity when withdrawn)
        var mcaReactivity: Double = 0.0
        for i in 0..<2 {
            let worthExtracted = rodWorthExtracted(state.mcaPositions[i])
            mcaReactivity += CANDUConstants.mcaWorth * worthExtracted
        }

        // 3. Zone controllers: fill level 0-100%, where 50% = neutral
        //    Higher fill = more absorption = negative reactivity
        //    Total range is +/- zoneControlTotalWorth/2 = +/- 1.5 mk
        var zoneReactivity: Double = 0.0
        let zoneWorthPerUnit = CANDUConstants.zoneControlTotalWorth / 6.0
        for i in 0..<6 {
            // fill=0% -> +zoneWorthPerUnit/2, fill=50% -> 0, fill=100% -> -zoneWorthPerUnit/2
            let deviation = (50.0 - state.zoneControllerFills[i]) / 50.0
            zoneReactivity += zoneWorthPerUnit * deviation * 0.5
        }

        // 4. Shutoff rods (large negative reactivity when inserted)
        var shutoffReactivity: Double = 0.0
        if state.shutoffRodInsertionFraction > 0.0 {
            let worthInserted = rodWorthExtracted(state.shutoffRodInsertionFraction)
            shutoffReactivity = -CANDUConstants.shutoffRodWorth * worthInserted
        }

        // Total rod reactivity
        state.rodReactivity = adjusterReactivity + mcaReactivity + zoneReactivity + shutoffReactivity

        // 5. Temperature feedback
        let dopplerFeedback = CANDUConstants.dopplerCoefficient * (state.fuelTemp - CANDUConstants.fuelTempReference)
        let averageCoolantTemp = (state.primaryInletTemp + state.primaryOutletTemp) / 2.0
        let coolantFeedback = CANDUConstants.coolantTempCoefficient * (averageCoolantTemp - CANDUConstants.coolantTempReference)
        state.feedbackReactivity = dopplerFeedback + coolantFeedback

        // 6. Xenon reactivity (already computed in xenon dynamics, just reference it)
        // state.xenonReactivity is set by updateXenonIodine()

        // Total reactivity (mk)
        state.totalReactivity = state.rodReactivity + state.feedbackReactivity + state.xenonReactivity
    }

    // MARK: - Xenon / Iodine Dynamics

    /// Update Iodine-135 and Xenon-135 concentrations.
    ///
    /// The ODEs (using normalized concentrations):
    ///
    ///   dI/dt = gamma_I * Sigma_f * phi - lambda_I * I
    ///   dXe/dt = gamma_Xe * Sigma_f * phi + lambda_I * I - lambda_Xe * Xe - sigma_Xe * phi * Xe
    ///
    /// We use neutron density n (normalized to 1.0 = full power) as a proxy for
    /// the fission rate Sigma_f * phi. Concentrations are in arbitrary units
    /// normalized so that equilibrium full-power xenon reactivity matches
    /// the expected ~28 mk.
    ///
    /// We define a fission rate proxy: F = n * CANDUConstants.ratedThermalPower / ratedThermalPower = n
    /// and scale yields so equilibrium Xe at n=1 gives xenonReactivity = -28 mk.
    static func updateXenonIodine(state: ReactorState, dt: Double) {
        let n = state.neutronDensity
        let lambdaI = CANDUConstants.lambdaIodine
        let lambdaXe = CANDUConstants.lambdaXenon
        let gammaI = CANDUConstants.gammaIodine
        let gammaXe = CANDUConstants.gammaXenon
        let sigmaXePhi = CANDUConstants.sigmaXenonPhi

        // Fission rate proxy (proportional to neutron density)
        let fissionRate = n

        // Forward Euler for I-135
        let dIdt = gammaI * fissionRate - lambdaI * state.iodineConcentration
        var newIodine = state.iodineConcentration + dt * dIdt
        newIodine = max(newIodine, 0.0)

        // Forward Euler for Xe-135
        let dXedt = gammaXe * fissionRate
                  + lambdaI * state.iodineConcentration
                  - lambdaXe * state.xenonConcentration
                  - sigmaXePhi * n * state.xenonConcentration
        var newXenon = state.xenonConcentration + dt * dXedt
        newXenon = max(newXenon, 0.0)

        state.iodineConcentration = newIodine
        state.xenonConcentration = newXenon

        // Convert xenon concentration to reactivity
        // At equilibrium full power (n=1):
        //   I_eq = gammaI / lambdaI
        //   Xe_eq = (gammaXe + gammaI) / (lambdaXe + sigmaXePhi)
        // We want Xe_eq to map to xenonReactivityCoeff (-28 mk)
        let xeEquilibrium = (gammaXe + gammaI) / (lambdaXe + sigmaXePhi)
        if xeEquilibrium > 1e-15 {
            state.xenonReactivity = CANDUConstants.xenonReactivityCoeff * (state.xenonConcentration / xeEquilibrium)
        } else {
            state.xenonReactivity = 0.0
        }
    }
}
