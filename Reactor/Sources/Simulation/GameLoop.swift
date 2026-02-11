import Foundation

/// Main game loop manager for the CANDU-6 reactor simulation.
///
/// Uses a fixed base timestep of 1/60 s. Time acceleration is achieved
/// by running multiple substeps per frame. Different subsystems are
/// updated at different rates to balance accuracy and performance.
final class GameLoop {

    // MARK: - Properties

    /// The reactor state being simulated.
    let state: ReactorState

    /// Orders generator.
    let ordersGenerator: OrdersGenerator

    /// Base timestep (seconds) - 1/60th of a second.
    private let baseTimestep: Double = 1.0 / 60.0

    /// Substep counter for scheduling subsystem updates.
    private var substepCounter: Int = 0

    // MARK: - Update Intervals (in substeps)

    /// Neutronics + Thermal: every substep (~16.7ms)
    private let neutronicsInterval: Int = 1

    /// Primary loop: every 3 substeps (~50ms)
    private let primaryLoopInterval: Int = 3

    /// Secondary loop + condenser: every 6 substeps (~100ms)
    private let secondaryLoopInterval: Int = 6

    /// Xenon/Iodine dynamics: every 60 substeps (~1s)
    private let xenonInterval: Int = 60

    /// Orders check: every 60 substeps (~1s)
    private let ordersInterval: Int = 60

    // MARK: - Initialization

    init(state: ReactorState) {
        self.state = state
        self.ordersGenerator = OrdersGenerator()
    }

    /// Create a game loop initialized to cold shutdown.
    static func newGame() -> GameLoop {
        let state = ReactorState.coldShutdown()
        return GameLoop(state: state)
    }

    // MARK: - Main Update

    /// Called each frame with the real-time delta.
    /// Runs the appropriate number of substeps based on time acceleration.
    ///
    /// - Parameter dt: Real-time delta since last frame (typically ~1/60s).
    func update(dt: Double) {
        let accelerationFactor = state.timeAcceleration
        let substepsThisFrame = max(accelerationFactor, 1)

        for _ in 0..<substepsThisFrame {
            performSubstep()
        }
    }

    // MARK: - Substep Execution

    /// Execute a single simulation substep at the base timestep.
    private func performSubstep() {
        let dt = baseTimestep

        // --- Reactivity update (every substep, before neutronics) ---
        Reactivity.update(state: state)

        // --- Neutronics + Thermal Hydraulics (every substep) ---
        if substepCounter % neutronicsInterval == 0 {
            Neutronics.step(state: state, dt: dt)
            ThermalHydraulics.step(state: state, dt: dt)
        }

        // --- Primary Loop (every 3 substeps) ---
        if substepCounter % primaryLoopInterval == 0 {
            let primaryDt = dt * Double(primaryLoopInterval)
            PrimaryLoop.step(state: state, dt: primaryDt)
        }

        // --- Secondary Loop + Tertiary (every 6 substeps) ---
        if substepCounter % secondaryLoopInterval == 0 {
            let secondaryDt = dt * Double(secondaryLoopInterval)
            SecondaryLoop.step(state: state, dt: secondaryDt)
            TertiaryLoop.step(state: state, dt: secondaryDt)
            Electrical.step(state: state, dt: secondaryDt)
        }

        // --- Xenon/Iodine dynamics (every 60 substeps, ~1s) ---
        if substepCounter % xenonInterval == 0 {
            let xenonDt = dt * Double(xenonInterval)
            Reactivity.updateXenonIodine(state: state, dt: xenonDt)
        }

        // --- Safety system (every substep) ---
        SafetySystem.step(state: state, dt: dt)

        // --- Auxiliary systems (every 6 substeps) ---
        if substepCounter % secondaryLoopInterval == 0 {
            let auxDt = dt * Double(secondaryLoopInterval)
            AuxiliarySystems.step(state: state, dt: auxDt)
        }

        // --- Orders (every 60 substeps, ~1s) ---
        if substepCounter % ordersInterval == 0 {
            let ordersDt = dt * Double(ordersInterval)
            ordersGenerator.update(state: state, dt: ordersDt)
        }

        // Update elapsed time
        state.elapsedTime += dt

        // Advance substep counter (wrap to avoid overflow)
        substepCounter += 1
        if substepCounter >= 3600 { // wrap every 60 seconds of sim time
            substepCounter = 0
        }
    }

    // MARK: - Time Acceleration Control

    /// Set time acceleration factor. Valid values: 1, 2, 5, 10.
    func setTimeAcceleration(_ factor: Int) {
        let validFactors = [1, 2, 5, 10]
        if validFactors.contains(factor) {
            state.timeAcceleration = factor
        }
    }

    /// Increase time acceleration to the next level.
    func increaseTimeAcceleration() {
        let levels = [1, 2, 5, 10]
        if let currentIndex = levels.firstIndex(of: state.timeAcceleration) {
            if currentIndex < levels.count - 1 {
                state.timeAcceleration = levels[currentIndex + 1]
            }
        } else {
            state.timeAcceleration = 1
        }
    }

    /// Decrease time acceleration to the previous level.
    func decreaseTimeAcceleration() {
        let levels = [1, 2, 5, 10]
        if let currentIndex = levels.firstIndex(of: state.timeAcceleration) {
            if currentIndex > 0 {
                state.timeAcceleration = levels[currentIndex - 1]
            }
        } else {
            state.timeAcceleration = 1
        }
    }

    // MARK: - Manual SCRAM

    /// Operator-initiated emergency shutdown.
    func manualScram() {
        SafetySystem.initiateScram(state: state, reason: "MANUAL SCRAM")
    }

    /// Reset SCRAM condition (if safe to do so).
    func resetScram() {
        SafetySystem.resetScram(state: state)
    }

    // MARK: - Operator Actions

    /// Start a primary coolant pump.
    func startPrimaryPump(_ index: Int) {
        guard index >= 0 && index < 4 else { return }
        state.primaryPumps[index].running = true
        state.primaryPumps[index].tripped = false
    }

    /// Trip (emergency stop) a primary coolant pump.
    func tripPrimaryPump(_ index: Int) {
        guard index >= 0 && index < 4 else { return }
        state.primaryPumps[index].tripped = true
        state.primaryPumps[index].tripTime = state.elapsedTime
    }

    /// Stop a primary coolant pump (graceful).
    func stopPrimaryPump(_ index: Int) {
        guard index >= 0 && index < 4 else { return }
        state.primaryPumps[index].running = false
        state.primaryPumps[index].tripped = false
    }

    /// Set adjuster rod bank position (0 = fully inserted, 1 = fully withdrawn).
    func setAdjusterPosition(bank: Int, position: Double) {
        guard bank >= 0 && bank < 4 else { return }
        state.adjusterPositions[bank] = min(max(position, 0.0), 1.0)
    }

    /// Set MCA position (0 = fully inserted, 1 = fully withdrawn).
    func setMCAPosition(device: Int, position: Double) {
        guard device >= 0 && device < 2 else { return }
        state.mcaPositions[device] = min(max(position, 0.0), 1.0)
    }

    /// Set zone controller fill level (0-100%).
    func setZoneControllerFill(zone: Int, fill: Double) {
        guard zone >= 0 && zone < 6 else { return }
        state.zoneControllerFills[zone] = min(max(fill, 0.0), 100.0)
    }

    /// Withdraw shutoff rods (must not be in SCRAM).
    func withdrawShutoffRods() {
        guard !state.scramActive else { return }
        state.shutoffRodsInserted = false
        state.shutoffRodInsertionFraction = 0.0
    }

    /// Set turbine governor valve position (0-1).
    func setTurbineGovernor(_ position: Double) {
        state.turbineGovernor = min(max(position, 0.0), 1.0)
    }

    /// Connect/disconnect generator to grid.
    func setGeneratorConnected(_ connected: Bool) {
        if connected {
            // Can only connect when frequency is close to 60 Hz
            let freqError = abs(state.generatorFrequency - 60.0)
            if freqError < 0.5 {
                state.generatorConnected = true
            }
        } else {
            state.generatorConnected = false
        }
    }

    /// Start a feed pump.
    func startFeedPump(_ index: Int) {
        guard index >= 0 && index < 3 else { return }
        state.feedPumps[index].running = true
    }

    /// Stop a feed pump.
    func stopFeedPump(_ index: Int) {
        guard index >= 0 && index < 3 else { return }
        state.feedPumps[index].running = false
    }

    /// Start a cooling water pump.
    func startCoolingWaterPump(_ index: Int) {
        guard index >= 0 && index < 2 else { return }
        state.coolingWaterPumps[index].running = true
        state.coolingWaterPumps[index].tripped = false
    }

    /// Stop a cooling water pump.
    func stopCoolingWaterPump(_ index: Int) {
        guard index >= 0 && index < 2 else { return }
        state.coolingWaterPumps[index].running = false
    }

    /// Start a diesel generator.
    func startDiesel(_ index: Int) {
        AuxiliarySystems.startDiesel(state: state, index: index)
    }

    /// Stop a diesel generator.
    func stopDiesel(_ index: Int) {
        AuxiliarySystems.stopDiesel(state: state, index: index)
    }

    /// Load/unload a diesel generator.
    func loadDiesel(_ index: Int, load: Bool) {
        AuxiliarySystems.loadDiesel(state: state, index: index, load: load)
    }

    /// Toggle moderator circulation.
    func setModeratorCirculation(_ running: Bool) {
        AuxiliarySystems.setModeratorCirculation(state: state, running: running)
    }

    /// Acknowledge the most recent unacknowledged alarm.
    func acknowledgeAlarm() {
        for i in stride(from: state.alarms.count - 1, through: 0, by: -1) {
            if !state.alarms[i].acknowledged {
                state.alarms[i].acknowledged = true
                break
            }
        }
    }

    /// Acknowledge all alarms.
    func acknowledgeAllAlarms() {
        for i in 0..<state.alarms.count {
            state.alarms[i].acknowledged = true
        }
    }

    // MARK: - Query Helpers

    /// Formatted elapsed time string (HH:MM:SS).
    var elapsedTimeString: String {
        let totalSeconds = Int(state.elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Count of unacknowledged alarms.
    var unacknowledgedAlarmCount: Int {
        return state.alarms.filter { !$0.acknowledged }.count
    }
}
