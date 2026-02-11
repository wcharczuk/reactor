import Foundation

/// Point kinetics solver using implicit Euler method for 6-group delayed neutrons.
///
/// Solves the coupled ODEs:
///   dn/dt = [(rho - beta) / Lambda] * n + sum(lambda_i * C_i)
///   dC_i/dt = (beta_i / Lambda) * n - lambda_i * C_i
///
/// Using implicit Euler discretization:
///   n_new = (n_old + dt * sum(lambda_i * C_i_old)) / (1 - dt * (rho - beta) / Lambda)
///   C_i_new = (C_i_old + dt * (beta_i / Lambda) * n_new) / (1 + dt * lambda_i)
enum Neutronics {

    static func step(state: ReactorState, dt: Double) {
        let Lambda = CANDUConstants.promptNeutronLifetime
        let beta = CANDUConstants.totalBeta
        let groups = CANDUConstants.delayedGroups

        // Convert total reactivity from mk to dk/k
        let rho = state.totalReactivity / 1000.0

        let nOld = state.neutronDensity

        // Compute sum of lambda_i * C_i using old precursor values
        var precursorSource: Double = 0.0
        for i in 0..<6 {
            precursorSource += groups[i].lambda * state.precursorConcentrations[i]
        }

        // Implicit Euler for neutron density
        let denominator = 1.0 - dt * (rho - beta) / Lambda
        var nNew: Double
        if abs(denominator) < 1e-15 {
            // Avoid division by zero - use forward Euler as fallback
            nNew = nOld + dt * ((rho - beta) / Lambda * nOld + precursorSource)
        } else {
            nNew = (nOld + dt * precursorSource) / denominator
        }

        // Clamp neutron density to minimum (never truly zero due to source neutrons)
        nNew = max(nNew, 1e-12)

        // Update precursor concentrations using implicit Euler with new n
        for i in 0..<6 {
            let betaI = groups[i].beta
            let lambdaI = groups[i].lambda
            let cOld = state.precursorConcentrations[i]
            let cNew = (cOld + dt * (betaI / Lambda) * nNew) / (1.0 + dt * lambdaI)
            state.precursorConcentrations[i] = max(cNew, 0.0)
        }

        state.neutronDensity = nNew

        // Compute decay heat
        let decayHeat = computeDecayHeat(state: state)
        state.decayHeatPower = decayHeat

        // Track when reactor was last at significant power for decay heat
        if state.neutronDensity > 0.01 {
            state.lastFullPowerTime = state.elapsedTime
        }

        // Thermal power = fission power + decay heat
        let fissionPower = state.neutronDensity * CANDUConstants.ratedThermalPower
        state.thermalPower = fissionPower + decayHeat
        state.thermalPowerFraction = state.thermalPower / CANDUConstants.ratedThermalPower
    }

    /// Compute decay heat using the Todreas-Kazimi / ANS-5.1 approximation:
    ///   Q_decay = Q_rated * 0.066 * t^(-0.2)
    /// where t is time since shutdown in seconds.
    private static func computeDecayHeat(state: ReactorState) -> Double {
        guard state.scramActive || state.shutdownTime > 0 else {
            // If no shutdown has occurred, decay heat is negligible at low power
            // At meaningful power levels, decay heat is lumped into the fission term
            if state.neutronDensity > 0.001 {
                // Approximate steady-state decay heat as ~7% of fission power
                return 0.07 * state.neutronDensity * CANDUConstants.ratedThermalPower
            }
            return 0.0
        }

        let timeSinceShutdown = state.elapsedTime - state.shutdownTime
        guard timeSinceShutdown > 0.1 else {
            // Immediately after scram, decay heat is ~7% of pre-trip power
            return 0.07 * CANDUConstants.ratedThermalPower * max(state.thermalPowerFraction, 0.01)
        }

        // Use the power level at time of shutdown (approximate from thermal fraction)
        // Q_decay = Q0 * 0.066 * t^(-0.2)
        let q0 = CANDUConstants.ratedThermalPower // conservative: use rated power
        let decay = q0 * 0.066 * pow(timeSinceShutdown, -0.2)

        // Decay heat cannot exceed ~7% of rated and must be non-negative
        return min(max(decay, 0.0), 0.07 * CANDUConstants.ratedThermalPower)
    }
}
