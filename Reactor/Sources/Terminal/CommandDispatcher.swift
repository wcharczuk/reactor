import Foundation

/// The current view displayed on the terminal.
enum ViewType: String, CaseIterable {
    case overview    = "overview"
    case core        = "core"
    case primary     = "primary"
    case secondary   = "secondary"
    case electrical  = "electrical"
    case alarms      = "alarms"
}

/// Routes parsed commands to the simulation state and returns response strings.
///
/// The dispatcher resolves glob patterns, validates values, applies changes to
/// the `ReactorState`, and produces human-readable output for the command area.
final class CommandDispatcher {

    // MARK: - Properties

    /// Reference to the simulation state.
    private let state: ReactorState

    /// Reference to the intellisense system for path validation.
    private let intellisense: Intellisense

    /// Output message log (most recent last). Shown in the command output area.
    private(set) var commandOutput: [String] = []

    /// Maximum number of output lines retained.
    private static let maxOutputLines = 50

    /// The current view being displayed.
    var currentView: ViewType = .overview

    // MARK: - Init

    init(state: ReactorState, intellisense: Intellisense) {
        self.state = state
        self.intellisense = intellisense
        appendOutput("CANDU-6 REACTOR CONTROL SYSTEM v1.0")
        appendOutput("Reactor is in COLD SHUTDOWN. Order: COMMENCE REACTOR STARTUP.")
        appendOutput("Try: start aux.diesel.*    (start both diesel generators)")
        appendOutput("Type 'help startup' for full procedure. Tab for auto-complete.")
    }

    // MARK: - Dispatch

    /// Dispatch a parsed command and return a response string.
    @discardableResult
    func dispatch(_ command: Command) -> String {
        let response: String

        switch command {
        case .set(let path, let value):
            response = handleSet(path: path, value: value)

        case .get(let path):
            response = handleGet(path: path)

        case .start(let path):
            response = handleStart(path: path)

        case .stop(let path):
            response = handleStop(path: path)

        case .scram:
            response = handleScram()

        case .view(let screen):
            response = handleView(screen: screen)

        case .speed(let multiplier):
            response = handleSpeed(multiplier: multiplier)

        case .status:
            response = handleStatus()

        case .help(let topic):
            response = handleHelp(topic: topic)

        case .quit:
            response = "QUIT"

        case .unknown(let text):
            if text.isEmpty {
                response = ""
            } else {
                response = "Unknown command: \(text)"
            }
        }

        if !response.isEmpty {
            appendOutput(response)
        }
        return response
    }

    // MARK: - SET

    private func handleSet(path: String, value: String) -> String {
        guard let numericValue = Double(value) else {
            return "ERROR: Value must be numeric. Got: \(value)"
        }

        // Resolve glob patterns to concrete paths
        let resolvedPaths = resolveGlob(path)
        if resolvedPaths.isEmpty {
            return "ERROR: Unknown path: \(path)"
        }

        var results: [String] = []

        for resolved in resolvedPaths {
            let result = applySingleSet(path: resolved, value: numericValue)
            results.append(result)
        }

        return results.joined(separator: "\n")
    }

    private func applySingleSet(path: String, value: Double) -> String {
        // Validate path and range
        if let entry = intellisense.entry(for: path) {
            if entry.valueType == .readOnly {
                return "ERROR: \(path) is read-only."
            }
            if entry.valueType == .toggle {
                return "ERROR: \(path) uses start/stop, not set."
            }
            if let range = entry.range {
                if value < range.lowerBound || value > range.upperBound {
                    return "ERROR: \(path) value \(formatValue(value)) out of range [\(formatValue(range.lowerBound))-\(formatValue(range.upperBound))]"
                }
            }
        }

        // Apply the value to the reactor state
        switch path {

        // --- Core: Adjuster Rods (motor-driven, ~60s full stroke) ---
        // User pos: 0=withdrawn(out), 100=inserted(in). Internal: 0=inserted, 1=withdrawn.
        case "core.adjuster-rods.1.pos":
            state.adjusterTargetPositions[0] = 1.0 - value / 100.0
            return "OK: adjuster-rods.1 target = \(formatValue(value))"
        case "core.adjuster-rods.2.pos":
            state.adjusterTargetPositions[1] = 1.0 - value / 100.0
            return "OK: adjuster-rods.2 target = \(formatValue(value))"
        case "core.adjuster-rods.3.pos":
            state.adjusterTargetPositions[2] = 1.0 - value / 100.0
            return "OK: adjuster-rods.3 target = \(formatValue(value))"
        case "core.adjuster-rods.4.pos":
            state.adjusterTargetPositions[3] = 1.0 - value / 100.0
            return "OK: adjuster-rods.4 target = \(formatValue(value))"

        // --- Core: Zone Controllers ---
        case "core.zone-controllers.1.fill":
            return setZoneFill(index: 0, zone: 1, value: value)
        case "core.zone-controllers.2.fill":
            return setZoneFill(index: 1, zone: 2, value: value)
        case "core.zone-controllers.3.fill":
            return setZoneFill(index: 2, zone: 3, value: value)
        case "core.zone-controllers.4.fill":
            return setZoneFill(index: 3, zone: 4, value: value)
        case "core.zone-controllers.5.fill":
            return setZoneFill(index: 4, zone: 5, value: value)
        case "core.zone-controllers.6.fill":
            return setZoneFill(index: 5, zone: 6, value: value)

        // --- Core: MCA (motor-driven, ~30s full stroke) ---
        // User pos: 0=withdrawn(out), 100=inserted(in). Internal: 0=inserted, 1=withdrawn.
        case "core.mca.1.pos":
            state.mcaTargetPositions[0] = 1.0 - value / 100.0
            return "OK: MCA-1 target = \(formatValue(value))"
        case "core.mca.2.pos":
            state.mcaTargetPositions[1] = 1.0 - value / 100.0
            return "OK: MCA-2 target = \(formatValue(value))"

        // --- Core: Shutoff Rods ---
        case "core.shutoff-rods.pos":
            let internal01 = value / 100.0
            if state.scramActive && internal01 < state.shutoffRodInsertionFraction {
                return "ERROR: Cannot withdraw shutoff rods during SCRAM."
            }
            state.shutoffRodInsertionFraction = internal01
            state.shutoffRodsInserted = internal01 > 0.5
            return "OK: Shutoff rods pos = \(formatValue(value))%"

        // --- Primary: Pumps ---
        case "primary.pump.1.rpm":
            return setPrimaryPumpRPM(pumpIndex: 0, pumpNumber: 1, value: value)
        case "primary.pump.2.rpm":
            return setPrimaryPumpRPM(pumpIndex: 1, pumpNumber: 2, value: value)
        case "primary.pump.3.rpm":
            return setPrimaryPumpRPM(pumpIndex: 2, pumpNumber: 3, value: value)
        case "primary.pump.4.rpm":
            return setPrimaryPumpRPM(pumpIndex: 3, pumpNumber: 4, value: value)

        // --- Secondary: Turbine Governor ---
        case "secondary.turbine.governor":
            state.turbineGovernor = value
            return "OK: Turbine governor = \(formatValue(value))"

        // --- Tertiary: Pumps ---
        case "tertiary.pump.1.rpm":
            return setTertiaryPumpRPM(pumpIndex: 0, pumpNumber: 1, value: value)
        case "tertiary.pump.2.rpm":
            return setTertiaryPumpRPM(pumpIndex: 1, pumpNumber: 2, value: value)

        default:
            return "ERROR: Cannot set \(path)"
        }
    }

    private func setZoneFill(index: Int, zone: Int, value: Double) -> String {
        guard index < state.zoneControllerFills.count else {
            return "ERROR: Zone \(zone) index out of range."
        }
        state.zoneControllerFills[index] = value
        return "OK: Zone-\(zone) fill = \(formatValue(value))%"
    }

    private func setPrimaryPumpRPM(pumpIndex: Int, pumpNumber: Int, value: Double) -> String {
        guard pumpIndex < state.primaryPumps.count else {
            return "ERROR: Pump \(pumpNumber) does not exist."
        }
        if state.primaryPumps[pumpIndex].tripped {
            return "ERROR: Pump \(pumpNumber) is tripped. Reset required."
        }
        if value > 0 && !state.hasPowerSource {
            return "ERROR: No power source. Start a diesel generator first."
        }
        let warning = predictOverloadWarning(additionalPumpPower: CANDUConstants.pumpMotorPower, newRPM: value, oldRPM: state.primaryPumps[pumpIndex].targetRPM, ratedRPM: CANDUConstants.pumpRatedRPM, wasRunning: state.primaryPumps[pumpIndex].running)
        state.primaryPumps[pumpIndex].targetRPM = value
        if value > 0 && !state.primaryPumps[pumpIndex].running {
            state.primaryPumps[pumpIndex].running = true
        } else if value == 0 && state.primaryPumps[pumpIndex].rpm == 0 {
            state.primaryPumps[pumpIndex].running = false
        }
        var result = "OK: Pump \(pumpNumber) target RPM = \(formatValue(value))"
        if let warning = warning {
            result += "\n\(warning)"
        }
        return result
    }

    private func setTertiaryPumpRPM(pumpIndex: Int, pumpNumber: Int, value: Double) -> String {
        guard pumpIndex < state.coolingWaterPumps.count else {
            return "ERROR: Cooling water pump \(pumpNumber) does not exist."
        }
        if state.coolingWaterPumps[pumpIndex].tripped {
            return "ERROR: Cooling water pump \(pumpNumber) is tripped."
        }
        if value > 0 && !state.hasPowerSource {
            return "ERROR: No power source. Start a diesel generator first."
        }
        let warning = predictOverloadWarning(additionalPumpPower: CANDUConstants.coolingWaterPumpPower, newRPM: value, oldRPM: state.coolingWaterPumps[pumpIndex].targetRPM, ratedRPM: CANDUConstants.pumpRatedRPM, wasRunning: state.coolingWaterPumps[pumpIndex].running)
        state.coolingWaterPumps[pumpIndex].targetRPM = value
        if value > 0 && !state.coolingWaterPumps[pumpIndex].running {
            state.coolingWaterPumps[pumpIndex].running = true
        } else if value == 0 && state.coolingWaterPumps[pumpIndex].rpm == 0 {
            state.coolingWaterPumps[pumpIndex].running = false
        }
        var result = "OK: Cooling pump \(pumpNumber) target RPM = \(formatValue(value))"
        if let warning = warning {
            result += "\n\(warning)"
        }
        return result
    }

    /// Predict whether a pump RPM change will cause an electrical overload.
    /// Returns a warning string if overload is predicted, nil otherwise.
    private func predictOverloadWarning(additionalPumpPower: Double, newRPM: Double, oldRPM: Double, ratedRPM: Double, wasRunning: Bool) -> String? {
        // Only relevant when off-grid
        guard !state.generatorConnected else { return nil }

        // Compute the change in power draw
        let newFraction = newRPM / ratedRPM
        let newPower = additionalPumpPower * pow(newFraction, 3.0)
        let oldFraction = wasRunning ? oldRPM / ratedRPM : 0.0
        let oldPower = wasRunning ? additionalPumpPower * pow(oldFraction, 3.0) : 0.0
        let delta = newPower - oldPower

        let projectedLoad = state.emergencyServiceLoad + delta
        let capacity = state.availableElectricalCapacity

        if projectedLoad > capacity {
            return "WARNING: Load \(String(format: "%.1f", projectedLoad)) MW exceeds diesel capacity \(String(format: "%.1f", capacity)) MW — overload trip in \(Int(CANDUConstants.dieselOverloadTripDelay))s!"
        }
        return nil
    }

    // MARK: - GET

    private func handleGet(path: String) -> String {
        let resolvedPaths = resolveGlob(path)
        if resolvedPaths.isEmpty {
            return "ERROR: Unknown path: \(path)"
        }

        var results: [String] = []
        for resolved in resolvedPaths {
            let result = readSingleValue(path: resolved)
            results.append(result)
        }
        return results.joined(separator: "\n")
    }

    private func readSingleValue(path: String) -> String {
        switch path {

        // --- Core: Read-only ---
        case "core.thermal-power":
            return "Thermal power = \(formatValue(state.thermalPower)) MW"
        case "core.power-fraction":
            return "Power fraction = \(formatValue(state.thermalPowerFraction * 100.0))%"
        case "core.fuel-temp":
            return "Fuel temp = \(formatValue(state.fuelTemp)) degC"
        case "core.cladding-temp":
            return "Cladding temp = \(formatValue(state.claddingTemp)) degC"
        case "core.reactivity":
            return "Total reactivity = \(formatValue(state.totalReactivity)) mk"
        case "core.xenon-reactivity":
            return "Xenon reactivity = \(formatValue(state.xenonReactivity)) mk"

        // --- Core: Adjuster Rods (user pos: 0=out, 100=in; internal: 0=in, 1=out) ---
        case "core.adjuster-rods.1.pos":
            return rodGetString("adjuster-rods.1", (1.0 - state.adjusterPositions[0]) * 100.0, (1.0 - state.adjusterTargetPositions[0]) * 100.0)
        case "core.adjuster-rods.2.pos":
            return rodGetString("adjuster-rods.2", (1.0 - state.adjusterPositions[1]) * 100.0, (1.0 - state.adjusterTargetPositions[1]) * 100.0)
        case "core.adjuster-rods.3.pos":
            return rodGetString("adjuster-rods.3", (1.0 - state.adjusterPositions[2]) * 100.0, (1.0 - state.adjusterTargetPositions[2]) * 100.0)
        case "core.adjuster-rods.4.pos":
            return rodGetString("adjuster-rods.4", (1.0 - state.adjusterPositions[3]) * 100.0, (1.0 - state.adjusterTargetPositions[3]) * 100.0)

        // --- Core: Zone Controllers ---
        case "core.zone-controllers.1.fill":
            return "zone-controllers.1 fill = \(formatValue(state.zoneControllerFills[0]))%"
        case "core.zone-controllers.2.fill":
            return "zone-controllers.2 fill = \(formatValue(state.zoneControllerFills[1]))%"
        case "core.zone-controllers.3.fill":
            return "zone-controllers.3 fill = \(formatValue(state.zoneControllerFills[2]))%"
        case "core.zone-controllers.4.fill":
            return "zone-controllers.4 fill = \(formatValue(state.zoneControllerFills[3]))%"
        case "core.zone-controllers.5.fill":
            return "zone-controllers.5 fill = \(formatValue(state.zoneControllerFills[4]))%"
        case "core.zone-controllers.6.fill":
            return "zone-controllers.6 fill = \(formatValue(state.zoneControllerFills[5]))%"

        // --- Core: MCA (user pos: 0=out, 100=in; internal: 0=in, 1=out) ---
        case "core.mca.1.pos":
            return rodGetString("MCA-1", (1.0 - state.mcaPositions[0]) * 100.0, (1.0 - state.mcaTargetPositions[0]) * 100.0)
        case "core.mca.2.pos":
            return rodGetString("MCA-2", (1.0 - state.mcaPositions[1]) * 100.0, (1.0 - state.mcaTargetPositions[1]) * 100.0)

        // --- Core: Shutoff Rods ---
        case "core.shutoff-rods.pos":
            return "Shutoff rods pos = \(formatValue(state.shutoffRodInsertionFraction * 100.0))"

        // --- Primary ---
        case "primary.pump.1.rpm":
            return "Primary pump 1 RPM = \(formatValue(state.primaryPumps[0].rpm))"
        case "primary.pump.2.rpm":
            return "Primary pump 2 RPM = \(formatValue(state.primaryPumps[1].rpm))"
        case "primary.pump.3.rpm":
            return "Primary pump 3 RPM = \(formatValue(state.primaryPumps[2].rpm))"
        case "primary.pump.4.rpm":
            return "Primary pump 4 RPM = \(formatValue(state.primaryPumps[3].rpm))"
        case "primary.pressure":
            return "Primary pressure = \(formatValue(state.primaryPressure)) MPa"
        case "primary.inlet-temp":
            return "Primary inlet temp = \(formatValue(state.primaryInletTemp)) degC"
        case "primary.outlet-temp":
            return "Primary outlet temp = \(formatValue(state.primaryOutletTemp)) degC"
        case "primary.flow-rate":
            return "Primary flow rate = \(formatValue(state.primaryFlowRate)) kg/s"

        // --- Secondary ---
        case "secondary.feed-pump.1.auto":
            return "Feed pump 1: \(state.feedPumps[0].running ? "RUNNING" : "STOPPED")"
        case "secondary.feed-pump.2.auto":
            return "Feed pump 2: \(state.feedPumps[1].running ? "RUNNING" : "STOPPED")"
        case "secondary.feed-pump.3.auto":
            return "Feed pump 3: \(state.feedPumps[2].running ? "RUNNING" : "STOPPED")"
        case "secondary.turbine.governor":
            return "Turbine governor = \(formatValue(state.turbineGovernor))"
        case "secondary.turbine.rpm":
            return "Turbine RPM = \(formatValue(state.turbineRPM))"
        case "secondary.condenser.pressure":
            return "Condenser pressure = \(formatValue(state.condenserPressure)) MPa"
        case "secondary.condenser.temp":
            return "Condenser temp = \(formatValue(state.condenserTemp)) degC"
        case "secondary.sg.1.level":
            return "SG-1 level = \(formatValue(state.sgLevels[0]))%"
        case "secondary.sg.2.level":
            return "SG-2 level = \(formatValue(state.sgLevels[1]))%"
        case "secondary.sg.3.level":
            return "SG-3 level = \(formatValue(state.sgLevels[2]))%"
        case "secondary.sg.4.level":
            return "SG-4 level = \(formatValue(state.sgLevels[3]))%"
        case "secondary.sg.1.pressure", "secondary.sg.2.pressure",
             "secondary.sg.3.pressure", "secondary.sg.4.pressure":
            return "Steam pressure = \(formatValue(state.steamPressure)) MPa"
        case "secondary.steam-pressure":
            return "Steam pressure = \(formatValue(state.steamPressure)) MPa"
        case "secondary.steam-temp":
            return "Steam temp = \(formatValue(state.steamTemp)) degC"
        case "secondary.steam-flow":
            return "Steam flow = \(formatValue(state.steamFlow)) kg/s"
        case "secondary.feedwater-temp":
            return "Feedwater temp = \(formatValue(state.feedwaterTemp)) degC"

        // --- Electrical ---
        case "electrical.gross-power":
            return "Gross power = \(formatValue(state.grossPower)) MW(e)"
        case "electrical.net-power":
            return "Net power = \(formatValue(state.netPower)) MW(e)"
        case "electrical.frequency":
            return "Generator freq = \(formatValue(state.generatorFrequency)) Hz"
        case "electrical.grid-connected":
            return "Grid connected = \(state.generatorConnected ? "YES" : "NO")"
        case "electrical.station-service":
            return "Effective electrical load = \(formatValue(state.effectiveElectricalLoad)) MW"
        case "electrical.diesel-capacity":
            return "Available diesel capacity = \(formatValue(state.availableDieselCapacity)) MW"

        // --- Tertiary ---
        case "tertiary.pump.1.rpm":
            return "Cooling pump 1 RPM = \(formatValue(state.coolingWaterPumps[0].rpm))"
        case "tertiary.pump.2.rpm":
            return "Cooling pump 2 RPM = \(formatValue(state.coolingWaterPumps[1].rpm))"
        case "tertiary.cooling-water-flow":
            return "Cooling water flow = \(formatValue(state.coolingWaterFlow)) kg/s"

        // --- Auxiliary ---
        case "aux.diesel.1.state":
            let fuelPct1 = String(format: "%.0f", state.dieselGenerators[0].fuelLevel * 100.0)
            return "Diesel 1: \(state.dieselGenerators[0].running ? "RUNNING" : "STOPPED")\(state.dieselGenerators[0].available ? " (AVAILABLE)" : "") \u{2014} Fuel: \(fuelPct1)%"
        case "aux.diesel.2.state":
            let fuelPct2 = String(format: "%.0f", state.dieselGenerators[1].fuelLevel * 100.0)
            return "Diesel 2: \(state.dieselGenerators[1].running ? "RUNNING" : "STOPPED")\(state.dieselGenerators[1].available ? " (AVAILABLE)" : "") \u{2014} Fuel: \(fuelPct2)%"
        case "aux.diesel.1.fuel":
            return "Diesel 1 fuel = \(String(format: "%.1f", state.dieselGenerators[0].fuelLevel * 100.0))%"
        case "aux.diesel.2.fuel":
            return "Diesel 2 fuel = \(String(format: "%.1f", state.dieselGenerators[1].fuelLevel * 100.0))%"

        default:
            return "ERROR: Cannot read \(path)"
        }
    }

    // MARK: - START / STOP

    private func handleStart(path: String) -> String {
        let resolvedPaths = resolveGlob(path)
        if resolvedPaths.isEmpty {
            // Try treating the path as a component (without .state or .rpm suffix)
            let withState = path + ".state"
            let withRPM = path + ".rpm"
            let resolvedState = resolveGlob(withState)
            let resolvedRPM = resolveGlob(withRPM)
            if !resolvedState.isEmpty {
                return resolvedState.map { startComponent(path: $0) }.joined(separator: "\n")
            }
            if !resolvedRPM.isEmpty {
                return resolvedRPM.map { startComponent(path: $0) }.joined(separator: "\n")
            }
            return "ERROR: Unknown component: \(path)"
        }
        return resolvedPaths.map { startComponent(path: $0) }.joined(separator: "\n")
    }

    private func startComponent(path: String) -> String {
        // Pumps require a power source (diesel or main generator)
        let needsPower = path != "aux.diesel.1.state" && path != "aux.diesel.2.state"
        if needsPower && !state.hasPowerSource {
            return "ERROR: No power source. Start a diesel generator first."
        }

        switch path {
        case "aux.diesel.1.state":
            if state.dieselGenerators[0].running {
                return "Diesel 1 already running."
            }
            state.dieselGenerators[0].running = true
            state.dieselGenerators[0].startTime = state.elapsedTime
            return "OK: Diesel generator 1 starting (warmup: \(Int(CANDUConstants.dieselStartTime))s)"

        case "aux.diesel.2.state":
            if state.dieselGenerators[1].running {
                return "Diesel 2 already running."
            }
            state.dieselGenerators[1].running = true
            state.dieselGenerators[1].startTime = state.elapsedTime
            return "OK: Diesel generator 2 starting (warmup: \(Int(CANDUConstants.dieselStartTime))s)"

        case "secondary.feed-pump.1.auto":
            state.feedPumps[0].running = true
            return "OK: Feed pump 1 started."
        case "secondary.feed-pump.2.auto":
            state.feedPumps[1].running = true
            return "OK: Feed pump 2 started."
        case "secondary.feed-pump.3.auto":
            state.feedPumps[2].running = true
            return "OK: Feed pump 3 started."

        case "electrical.grid.sync":
            let freqError = abs(state.generatorFrequency - 60.0)
            if state.generatorConnected {
                return "Generator already connected to grid."
            }
            if state.generatorFrequency < 1.0 {
                return "ERROR: Generator not spinning. Open turbine governor first."
            }
            if freqError > 0.5 {
                return "ERROR: Frequency \(String(format: "%.2f", state.generatorFrequency)) Hz — must be within 0.5 Hz of 60 Hz to sync."
            }
            state.generatorConnected = true
            return "OK: Generator synchronized to grid."

        // Pumps — redirect to 'set' command
        case "primary.pump.1.rpm", "primary.pump.2.rpm",
             "primary.pump.3.rpm", "primary.pump.4.rpm":
            return "Use 'set \(path) 1500' to start a pump."

        case "tertiary.pump.1.rpm", "tertiary.pump.2.rpm":
            return "Use 'set \(path) 1500' to start a pump."

        default:
            return "ERROR: Cannot start \(path)"
        }
    }

    private func handleStop(path: String) -> String {
        let resolvedPaths = resolveGlob(path)
        if resolvedPaths.isEmpty {
            let withState = path + ".state"
            let withRPM = path + ".rpm"
            let resolvedState = resolveGlob(withState)
            let resolvedRPM = resolveGlob(withRPM)
            if !resolvedState.isEmpty {
                return resolvedState.map { stopComponent(path: $0) }.joined(separator: "\n")
            }
            if !resolvedRPM.isEmpty {
                return resolvedRPM.map { stopComponent(path: $0) }.joined(separator: "\n")
            }
            return "ERROR: Unknown component: \(path)"
        }
        return resolvedPaths.map { stopComponent(path: $0) }.joined(separator: "\n")
    }

    private func stopComponent(path: String) -> String {
        switch path {
        case "aux.diesel.1.state":
            state.dieselGenerators[0].running = false
            state.dieselGenerators[0].available = false
            state.dieselGenerators[0].loaded = false
            state.dieselGenerators[0].power = 0.0
            state.dieselGenerators[0].startTime = -1.0
            return "OK: Diesel generator 1 stopped."

        case "aux.diesel.2.state":
            state.dieselGenerators[1].running = false
            state.dieselGenerators[1].available = false
            state.dieselGenerators[1].loaded = false
            state.dieselGenerators[1].power = 0.0
            state.dieselGenerators[1].startTime = -1.0
            return "OK: Diesel generator 2 stopped."

        case "secondary.feed-pump.1.auto":
            state.feedPumps[0].running = false
            state.feedPumps[0].flowRate = 0.0
            return "OK: Feed pump 1 stopped."
        case "secondary.feed-pump.2.auto":
            state.feedPumps[1].running = false
            state.feedPumps[1].flowRate = 0.0
            return "OK: Feed pump 2 stopped."
        case "secondary.feed-pump.3.auto":
            state.feedPumps[2].running = false
            state.feedPumps[2].flowRate = 0.0
            return "OK: Feed pump 3 stopped."

        case "electrical.grid.sync":
            if !state.generatorConnected {
                return "Generator not connected to grid."
            }
            state.generatorConnected = false
            return "OK: Generator disconnected from grid."

        case "primary.pump.1.rpm", "primary.pump.2.rpm",
             "primary.pump.3.rpm", "primary.pump.4.rpm":
            return "Use 'set \(path) 0' to stop a pump."

        case "tertiary.pump.1.rpm", "tertiary.pump.2.rpm":
            return "Use 'set \(path) 0' to stop a pump."

        default:
            return "ERROR: Cannot stop \(path)"
        }
    }

    // MARK: - SCRAM

    private func handleScram() -> String {
        if state.scramActive {
            return "SCRAM already active."
        }
        state.scramActive = true
        state.scramTime = state.elapsedTime
        state.shutdownTime = state.elapsedTime
        state.shutoffRodsInserted = true
        state.timeAcceleration = 1.0
        // Shutoff rod insertion will be animated by the simulation engine
        // but we immediately flag the scram.
        state.addAlarm(message: "SCRAM INITIATED - All shutoff rods inserting", severity: .trip)
        return "*** SCRAM INITIATED *** All shutoff rods inserting."
    }

    // MARK: - VIEW

    private func handleView(screen: String) -> String {
        guard let viewType = ViewType(rawValue: screen.lowercased()) else {
            let valid = ViewType.allCases.map { $0.rawValue }.joined(separator: ", ")
            return "ERROR: Unknown view '\(screen)'. Valid: \(valid)"
        }
        currentView = viewType
        return "View: \(viewType.rawValue.uppercased())"
    }

    // MARK: - SPEED

    private func handleSpeed(multiplier: Double) -> String {
        let validSpeeds: [Double] = [0.1, 0.25, 0.5, 1, 2, 5, 10]
        guard validSpeeds.contains(multiplier) else {
            return "ERROR: Speed must be one of: \(validSpeeds.map { formatSpeed($0) }.joined(separator: ", "))"
        }
        state.timeAcceleration = multiplier
        return "OK: Time acceleration = \(formatSpeed(multiplier))x"
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed == Double(Int(speed)) { return "\(Int(speed))" }
        return "\(speed)"
    }

    // MARK: - STATUS

    private func handleStatus() -> String {
        let power = String(format: "%.1f", state.thermalPowerFraction * 100.0)
        let thermal = String(format: "%.1f", state.thermalPower)
        let gross = String(format: "%.1f", state.grossPower)
        let net = String(format: "%.1f", state.netPower)
        let fuelT = String(format: "%.0f", state.fuelTemp)
        let pPressure = String(format: "%.2f", state.primaryPressure)
        let pFlow = String(format: "%.0f", state.primaryFlowRate)
        let scramStatus = state.scramActive ? "ACTIVE" : "Normal"

        var result = """
        Power: \(power)% | Thermal: \(thermal) MW(th) | Gross: \(gross) MW(e) | Net: \(net) MW(e)
        Fuel: \(fuelT) degC | Pressure: \(pPressure) MPa | Flow: \(pFlow) kg/s | SCRAM: \(scramStatus)
        """

        // Show diesel fuel status when any diesel is running
        let runningDiesels = state.dieselGenerators.enumerated().filter { $0.element.running }
        if !runningDiesels.isEmpty {
            let dgInfo = runningDiesels.map { (i, dg) in
                "DG-\(i+1): \(String(format: "%.0f", dg.fuelLevel * 100))%"
            }.joined(separator: " | ")
            result += "\nDiesel fuel: \(dgInfo)"
        }

        return result
    }

    // MARK: - HELP

    private func handleHelp(topic: String?) -> String {
        guard let topic = topic else {
            return """
            Commands: set, get, start, stop, scram, view, time, status, help, quit
            Pumps use 'set' to control RPM. 'start/stop' for diesels and feed pumps.
            Type 'help startup' for startup procedure. Type 'help paths' for all noun paths.
            Use Tab for auto-completion. PageUp/PageDown to scroll output.
            """
        }

        if let text = intellisense.helpText(for: topic) {
            return text
        }
        return "No help available for '\(topic)'."
    }

    // MARK: - Alarm Helper (used by ReactorState)

    private func addAlarm(message: String, severity: AlarmEntry.AlarmSeverity) {
        state.addAlarm(message: message, severity: severity)
    }

    // MARK: - Glob Resolution

    /// Resolve a path that may contain glob wildcards into concrete paths.
    ///
    /// Supported globs:
    /// - `*` expands to all valid indices for that component (e.g. 1-4 for adjuster-rods, 1-6 for zone-controllers)
    private func resolveGlob(_ path: String) -> [String] {
        // If path contains no wildcard, check if it is a known path directly
        if !path.contains("*") {
            if intellisense.entry(for: path) != nil {
                return [path]
            }
            // Maybe it is a known path that we handle internally
            if isKnownPath(path) {
                return [path]
            }
            return []
        }

        // Expand globs
        let allPaths = intellisense.allPaths
        var matched: [String] = []

        for candidate in allPaths {
            if globMatches(pattern: path, candidate: candidate) {
                matched.append(candidate)
            }
        }

        return matched.sorted()
    }

    /// Check if a candidate path matches a glob pattern.
    /// The glob only supports `*` replacing a single path component segment between dots.
    private func globMatches(pattern: String, candidate: String) -> Bool {
        let patternParts = pattern.split(separator: ".").map(String.init)
        let candidateParts = candidate.split(separator: ".").map(String.init)

        guard patternParts.count == candidateParts.count else { return false }

        for (pat, cand) in zip(patternParts, candidateParts) {
            if pat == "*" || pat == "bank-*" || pat == "zone-*" {
                // Wildcard matches anything at this level
                // But for "bank-*", only match "bank-X" candidates
                if pat == "bank-*" && !cand.hasPrefix("bank-") {
                    return false
                }
                if pat == "zone-*" && !cand.hasPrefix("zone-") {
                    return false
                }
                continue
            }
            if pat != cand {
                return false
            }
        }
        return true
    }

    /// Check if a path is one we can handle even if not in the intellisense registry.
    private func isKnownPath(_ path: String) -> Bool {
        // All known settable/gettable paths should be in intellisense.
        // This is a fallback.
        return false
    }

    // MARK: - Output Management

    private func appendOutput(_ text: String) {
        // Split multi-line text into individual lines
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        commandOutput.append(contentsOf: lines)
        if commandOutput.count > CommandDispatcher.maxOutputLines {
            commandOutput.removeFirst(commandOutput.count - CommandDispatcher.maxOutputLines)
        }
    }

    // MARK: - Formatting

    private func rodGetString(_ name: String, _ current: Double, _ target: Double) -> String {
        let pos = formatValue(current)
        if abs(current - target) > 0.001 {
            let dir = target < current ? "withdrawing" : "inserting"
            return "\(name) position = \(pos) (\(dir) → \(formatValue(target)))"
        }
        return "\(name) position = \(pos)"
    }

    /// Returns just the current numeric value for a settable path (used by intellisense range hints).
    func currentValueString(for path: String) -> String? {
        switch path {
        case "core.adjuster-rods.1.pos": return formatValue((1.0 - state.adjusterPositions[0]) * 100.0)
        case "core.adjuster-rods.2.pos": return formatValue((1.0 - state.adjusterPositions[1]) * 100.0)
        case "core.adjuster-rods.3.pos": return formatValue((1.0 - state.adjusterPositions[2]) * 100.0)
        case "core.adjuster-rods.4.pos": return formatValue((1.0 - state.adjusterPositions[3]) * 100.0)
        case "core.zone-controllers.1.fill": return formatValue(state.zoneControllerFills[0])
        case "core.zone-controllers.2.fill": return formatValue(state.zoneControllerFills[1])
        case "core.zone-controllers.3.fill": return formatValue(state.zoneControllerFills[2])
        case "core.zone-controllers.4.fill": return formatValue(state.zoneControllerFills[3])
        case "core.zone-controllers.5.fill": return formatValue(state.zoneControllerFills[4])
        case "core.zone-controllers.6.fill": return formatValue(state.zoneControllerFills[5])
        case "core.mca.1.pos": return formatValue((1.0 - state.mcaPositions[0]) * 100.0)
        case "core.mca.2.pos": return formatValue((1.0 - state.mcaPositions[1]) * 100.0)
        case "core.shutoff-rods.pos": return formatValue(state.shutoffRodInsertionFraction * 100.0)
        case "secondary.turbine.governor": return formatValue(state.turbineGovernor)
        default:
            // Primary/tertiary pumps
            if path.hasPrefix("primary.pump.") && path.hasSuffix(".rpm") {
                let idx = Int(path.dropFirst("primary.pump.".count).dropLast(".rpm".count)) ?? 0
                if idx >= 1 && idx <= state.primaryPumps.count {
                    return formatValue(state.primaryPumps[idx - 1].rpm)
                }
            }
            if path.hasPrefix("tertiary.pump.") && path.hasSuffix(".rpm") {
                let idx = Int(path.dropFirst("tertiary.pump.".count).dropLast(".rpm".count)) ?? 0
                if idx >= 1 && idx <= state.coolingWaterPumps.count {
                    return formatValue(state.coolingWaterPumps[idx - 1].rpm)
                }
            }
            return nil
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 10000 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Alarm Extension on ReactorState

extension ReactorState {
    /// Add an alarm to the alarm list.
    func addAlarm(message: String, severity: AlarmEntry.AlarmSeverity) {
        let alarm = Alarm(time: elapsedTime, message: "[\(severity.rawValue)] \(message)", acknowledged: false)
        alarms.append(alarm)
        if alarms.count > 500 {
            alarms.removeFirst()
        }
    }
}

/// Alarm severity levels used by the command/terminal system.
enum AlarmEntry {
    enum AlarmSeverity: String {
        case warning = "WARN"
        case alarm   = "ALARM"
        case trip    = "TRIP"
    }
}
