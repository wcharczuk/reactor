import Foundation

/// Generates power maneuvering orders for the player.
///
/// Uses a state machine to issue sequential power orders based on
/// elapsed time and current reactor power level.
final class OrdersGenerator {

    // MARK: - Order State Machine

    enum OrderPhase: Int, CaseIterable {
        case prepareForStartup = 0
        case waitingForCriticality
        case achieve25Percent
        case achieve50Percent
        case achieve75Percent
        case achieve85Percent
        case achieve100Percent
        case steadyState
        case powerReduction
        case shutdown
    }

    private var currentPhase: OrderPhase = .prepareForStartup
    private var phaseEntryTime: Double = 0.0
    private var orderIssued: Bool = false

    /// Minimum time at a power level before the next order (seconds)
    private let holdTime: Double = 300.0 // 5 minutes at each level

    /// Power tolerance for order completion (fraction)
    private let powerTolerance: Double = 0.03 // 3% tolerance

    /// Time at current power before order is considered complete
    private var timeAtTargetPower: Double = 0.0
    private let requiredStableTime: Double = 60.0 // must hold for 60s

    // MARK: - Initialization

    init() {
        currentPhase = .waitingForCriticality
        phaseEntryTime = 0.0
        orderIssued = false
        timeAtTargetPower = 0.0
    }

    // MARK: - Update

    /// Check current conditions and potentially issue new orders.
    func update(state: ReactorState, dt: Double) {
        // Don't issue new orders during SCRAM
        if state.scramActive {
            state.currentOrder = "*** SCRAM ACTIVE - STABILIZE PLANT ***"
            return
        }

        switch currentPhase {
        case .prepareForStartup:
            handlePrepareForStartup(state: state, dt: dt)

        case .waitingForCriticality:
            handleWaitingForCriticality(state: state, dt: dt)

        case .achieve25Percent:
            handlePowerOrder(state: state, dt: dt, targetFraction: 0.25, orderText: "ACHIEVE 25% FULL POWER", nextPhase: .achieve50Percent)

        case .achieve50Percent:
            handlePowerOrder(state: state, dt: dt, targetFraction: 0.50, orderText: "ACHIEVE 50% FULL POWER", nextPhase: .achieve75Percent)

        case .achieve75Percent:
            handlePowerOrder(state: state, dt: dt, targetFraction: 0.75, orderText: "ACHIEVE 75% FULL POWER", nextPhase: .achieve85Percent)

        case .achieve85Percent:
            handlePowerOrder(state: state, dt: dt, targetFraction: 0.85, orderText: "ACHIEVE 85% FULL POWER", nextPhase: .achieve100Percent)

        case .achieve100Percent:
            handlePowerOrder(state: state, dt: dt, targetFraction: 1.00, orderText: "ACHIEVE 100% FULL POWER", nextPhase: .steadyState)

        case .steadyState:
            handleSteadyState(state: state, dt: dt)

        case .powerReduction:
            handlePowerReduction(state: state, dt: dt)

        case .shutdown:
            handleShutdown(state: state, dt: dt)
        }
    }

    // MARK: - Phase Handlers

    private func handlePrepareForStartup(state: ReactorState, dt: Double) {
        if !orderIssued {
            state.currentOrder = "COMMENCE REACTOR STARTUP"
            orderIssued = true
            phaseEntryTime = state.elapsedTime
        }

        // Advance once the operator has prepared the plant:
        // - At least 2 primary pumps running
        // - Shutoff rods withdrawn
        let runningPrimary = state.primaryPumps.filter { $0.running }.count
        if runningPrimary >= 2 && !state.shutoffRodsInserted {
            advancePhase(state: state, to: .waitingForCriticality)
        }
    }

    private func handleWaitingForCriticality(state: ReactorState, dt: Double) {
        if !orderIssued {
            state.currentOrder = "ACHIEVE CRITICALITY"
            orderIssued = true
            phaseEntryTime = state.elapsedTime
        }

        // Check if reactor has reached criticality (neutron density rising above source range)
        if state.neutronDensity > 0.001 {
            // Reactor is critical / supercritical
            advancePhase(state: state, to: .achieve25Percent)
        }
    }

    private func handlePowerOrder(state: ReactorState, dt: Double, targetFraction: Double, orderText: String, nextPhase: OrderPhase) {
        if !orderIssued {
            state.currentOrder = orderText
            orderIssued = true
            phaseEntryTime = state.elapsedTime
            timeAtTargetPower = 0.0
        }

        // Check if power is at target
        let currentFraction = state.thermalPowerFraction
        if abs(currentFraction - targetFraction) < powerTolerance {
            timeAtTargetPower += dt
        } else {
            timeAtTargetPower = max(timeAtTargetPower - dt * 0.5, 0.0)
        }

        // Order complete when at target for required stable time
        if timeAtTargetPower >= requiredStableTime {
            // Ensure minimum hold time has passed
            let timeInPhase = state.elapsedTime - phaseEntryTime
            if timeInPhase >= holdTime {
                advancePhase(state: state, to: nextPhase)
            }
        }
    }

    private func handleSteadyState(state: ReactorState, dt: Double) {
        if !orderIssued {
            state.currentOrder = "MAINTAIN 100% FULL POWER"
            orderIssued = true
            phaseEntryTime = state.elapsedTime
        }

        // After extended operation, might order power reduction
        let timeInPhase = state.elapsedTime - phaseEntryTime
        if timeInPhase > 1800.0 { // 30 minutes at full power
            advancePhase(state: state, to: .powerReduction)
        }
    }

    private func handlePowerReduction(state: ReactorState, dt: Double) {
        if !orderIssued {
            state.currentOrder = "REDUCE POWER TO 60% FP"
            orderIssued = true
            phaseEntryTime = state.elapsedTime
            timeAtTargetPower = 0.0
        }

        // Check if power reduction is complete
        let currentFraction = state.thermalPowerFraction
        if abs(currentFraction - 0.60) < powerTolerance {
            timeAtTargetPower += dt
        } else {
            timeAtTargetPower = max(timeAtTargetPower - dt * 0.5, 0.0)
        }

        if timeAtTargetPower >= requiredStableTime {
            let timeInPhase = state.elapsedTime - phaseEntryTime
            if timeInPhase >= holdTime {
                advancePhase(state: state, to: .shutdown)
            }
        }
    }

    private func handleShutdown(state: ReactorState, dt: Double) {
        if !orderIssued {
            state.currentOrder = "PERFORM ORDERLY SHUTDOWN"
            orderIssued = true
            phaseEntryTime = state.elapsedTime
        }

        // Check if shutdown is complete
        if state.neutronDensity < 1e-5 && state.scramActive {
            state.currentOrder = "SHUTDOWN COMPLETE - MAINTAIN COOLING"
        }
    }

    // MARK: - Phase Transitions

    private func advancePhase(state: ReactorState, to nextPhase: OrderPhase) {
        currentPhase = nextPhase
        orderIssued = false
        timeAtTargetPower = 0.0

        // Add notification alarm for new order
        let alarm = Alarm(
            time: state.elapsedTime,
            message: "NEW ORDER RECEIVED",
            acknowledged: false
        )
        state.alarms.append(alarm)
    }

    /// Reset the orders generator to initial state.
    func reset() {
        currentPhase = .prepareForStartup
        phaseEntryTime = 0.0
        orderIssued = false
        timeAtTargetPower = 0.0
    }

    /// Get current phase for external queries.
    var phase: OrderPhase {
        return currentPhase
    }
}
