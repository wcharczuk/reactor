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
        appendOutput("Try: start tertiary.pump.1    (start cooling water)")
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

        // --- Core: Adjuster Rods ---
        case "core.adjuster-rods.bank-a.position":
            state.adjusterPositions[0] = value
            return "OK: bank-a position = \(formatValue(value))"
        case "core.adjuster-rods.bank-b.position":
            state.adjusterPositions[1] = value
            return "OK: bank-b position = \(formatValue(value))"
        case "core.adjuster-rods.bank-c.position":
            state.adjusterPositions[2] = value
            return "OK: bank-c position = \(formatValue(value))"
        case "core.adjuster-rods.bank-d.position":
            state.adjusterPositions[3] = value
            return "OK: bank-d position = \(formatValue(value))"

        // --- Core: Zone Controllers ---
        case "core.zone-controllers.zone-1.fill":
            return setZoneFill(index: 0, zone: 1, value: value)
        case "core.zone-controllers.zone-2.fill":
            return setZoneFill(index: 1, zone: 2, value: value)
        case "core.zone-controllers.zone-3.fill":
            return setZoneFill(index: 2, zone: 3, value: value)
        case "core.zone-controllers.zone-4.fill":
            return setZoneFill(index: 3, zone: 4, value: value)
        case "core.zone-controllers.zone-5.fill":
            return setZoneFill(index: 4, zone: 5, value: value)
        case "core.zone-controllers.zone-6.fill":
            return setZoneFill(index: 5, zone: 6, value: value)

        // --- Core: MCA ---
        case "core.mca.1.position":
            state.mcaPositions[0] = value
            return "OK: MCA-1 position = \(formatValue(value))"
        case "core.mca.2.position":
            state.mcaPositions[1] = value
            return "OK: MCA-2 position = \(formatValue(value))"

        // --- Core: Shutoff Rods ---
        case "core.shutoff-rods.position":
            if state.scramActive && value < state.shutoffRodInsertionFraction {
                return "ERROR: Cannot withdraw shutoff rods during SCRAM."
            }
            state.shutoffRodInsertionFraction = value
            state.shutoffRodsInserted = value > 0.5
            if value < 0.01 {
                return "OK: Shutoff rods WITHDRAWN"
            } else if value > 0.99 {
                return "OK: Shutoff rods FULLY INSERTED"
            } else {
                return "OK: Shutoff rods insertion = \(formatValue(value))"
            }

        // --- Primary: Pumps ---
        case "primary.pump.1.rpm":
            return setPumpRPM(pumpIndex: 0, pumpNumber: 1, value: value, pumps: &state.primaryPumps)
        case "primary.pump.2.rpm":
            return setPumpRPM(pumpIndex: 1, pumpNumber: 2, value: value, pumps: &state.primaryPumps)
        case "primary.pump.3.rpm":
            return setPumpRPM(pumpIndex: 2, pumpNumber: 3, value: value, pumps: &state.primaryPumps)
        case "primary.pump.4.rpm":
            return setPumpRPM(pumpIndex: 3, pumpNumber: 4, value: value, pumps: &state.primaryPumps)

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

    private func setPumpRPM(pumpIndex: Int, pumpNumber: Int, value: Double, pumps: inout [PumpState]) -> String {
        guard pumpIndex < pumps.count else {
            return "ERROR: Pump \(pumpNumber) does not exist."
        }
        if pumps[pumpIndex].tripped {
            return "ERROR: Pump \(pumpNumber) is tripped. Reset required."
        }
        pumps[pumpIndex].rpm = value
        if value > 0 && !pumps[pumpIndex].running {
            pumps[pumpIndex].running = true
        } else if value == 0 {
            pumps[pumpIndex].running = false
        }
        return "OK: Pump \(pumpNumber) target RPM = \(formatValue(value))"
    }

    private func setTertiaryPumpRPM(pumpIndex: Int, pumpNumber: Int, value: Double) -> String {
        guard pumpIndex < state.coolingWaterPumps.count else {
            return "ERROR: Cooling water pump \(pumpNumber) does not exist."
        }
        if state.coolingWaterPumps[pumpIndex].tripped {
            return "ERROR: Cooling water pump \(pumpNumber) is tripped."
        }
        state.coolingWaterPumps[pumpIndex].rpm = value
        if value > 0 && !state.coolingWaterPumps[pumpIndex].running {
            state.coolingWaterPumps[pumpIndex].running = true
        } else if value == 0 {
            state.coolingWaterPumps[pumpIndex].running = false
        }
        return "OK: Cooling pump \(pumpNumber) target RPM = \(formatValue(value))"
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

        // --- Core: Adjuster Rods ---
        case "core.adjuster-rods.bank-a.position":
            return "bank-a position = \(formatValue(state.adjusterPositions[0]))"
        case "core.adjuster-rods.bank-b.position":
            return "bank-b position = \(formatValue(state.adjusterPositions[1]))"
        case "core.adjuster-rods.bank-c.position":
            return "bank-c position = \(formatValue(state.adjusterPositions[2]))"
        case "core.adjuster-rods.bank-d.position":
            return "bank-d position = \(formatValue(state.adjusterPositions[3]))"

        // --- Core: Zone Controllers ---
        case "core.zone-controllers.zone-1.fill":
            return "zone-1 fill = \(formatValue(state.zoneControllerFills[0]))%"
        case "core.zone-controllers.zone-2.fill":
            return "zone-2 fill = \(formatValue(state.zoneControllerFills[1]))%"
        case "core.zone-controllers.zone-3.fill":
            return "zone-3 fill = \(formatValue(state.zoneControllerFills[2]))%"
        case "core.zone-controllers.zone-4.fill":
            return "zone-4 fill = \(formatValue(state.zoneControllerFills[3]))%"
        case "core.zone-controllers.zone-5.fill":
            return "zone-5 fill = \(formatValue(state.zoneControllerFills[4]))%"
        case "core.zone-controllers.zone-6.fill":
            return "zone-6 fill = \(formatValue(state.zoneControllerFills[5]))%"

        // --- Core: MCA ---
        case "core.mca.1.position":
            return "MCA-1 position = \(formatValue(state.mcaPositions[0]))"
        case "core.mca.2.position":
            return "MCA-2 position = \(formatValue(state.mcaPositions[1]))"

        // --- Core: Shutoff Rods ---
        case "core.shutoff-rods.position":
            return "Shutoff rods insertion = \(formatValue(state.shutoffRodInsertionFraction))"

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
        case "secondary.feed-pump.1.state":
            return "Feed pump 1: \(state.feedPumps[0].running ? "RUNNING" : "STOPPED")"
        case "secondary.feed-pump.2.state":
            return "Feed pump 2: \(state.feedPumps[1].running ? "RUNNING" : "STOPPED")"
        case "secondary.feed-pump.3.state":
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

        // --- Tertiary ---
        case "tertiary.pump.1.rpm":
            return "Cooling pump 1 RPM = \(formatValue(state.coolingWaterPumps[0].rpm))"
        case "tertiary.pump.2.rpm":
            return "Cooling pump 2 RPM = \(formatValue(state.coolingWaterPumps[1].rpm))"

        // --- Auxiliary ---
        case "aux.diesel.1.state":
            return "Diesel 1: \(state.dieselGenerators[0].running ? "RUNNING" : "STOPPED")\(state.dieselGenerators[0].available ? " (AVAILABLE)" : "")"
        case "aux.diesel.2.state":
            return "Diesel 2: \(state.dieselGenerators[1].running ? "RUNNING" : "STOPPED")\(state.dieselGenerators[1].available ? " (AVAILABLE)" : "")"

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

        case "secondary.feed-pump.1.state":
            state.feedPumps[0].running = true
            return "OK: Feed pump 1 started."
        case "secondary.feed-pump.2.state":
            state.feedPumps[1].running = true
            return "OK: Feed pump 2 started."
        case "secondary.feed-pump.3.state":
            state.feedPumps[2].running = true
            return "OK: Feed pump 3 started."

        // Allow starting pumps via their .rpm path
        case "primary.pump.1.rpm":
            return startPrimaryPump(index: 0, number: 1)
        case "primary.pump.2.rpm":
            return startPrimaryPump(index: 1, number: 2)
        case "primary.pump.3.rpm":
            return startPrimaryPump(index: 2, number: 3)
        case "primary.pump.4.rpm":
            return startPrimaryPump(index: 3, number: 4)

        case "tertiary.pump.1.rpm":
            return startTertiaryPump(index: 0, number: 1)
        case "tertiary.pump.2.rpm":
            return startTertiaryPump(index: 1, number: 2)

        default:
            return "ERROR: Cannot start \(path)"
        }
    }

    private func startPrimaryPump(index: Int, number: Int) -> String {
        guard index < state.primaryPumps.count else {
            return "ERROR: Primary pump \(number) does not exist."
        }
        if state.primaryPumps[index].tripped {
            return "ERROR: Primary pump \(number) is tripped. Reset required."
        }
        if state.primaryPumps[index].running {
            return "Primary pump \(number) already running."
        }
        state.primaryPumps[index].running = true
        if state.primaryPumps[index].rpm == 0 {
            state.primaryPumps[index].rpm = CANDUConstants.pumpRatedRPM
        }
        return "OK: Primary pump \(number) started at \(formatValue(state.primaryPumps[index].rpm)) RPM."
    }

    private func startTertiaryPump(index: Int, number: Int) -> String {
        guard index < state.coolingWaterPumps.count else {
            return "ERROR: Cooling pump \(number) does not exist."
        }
        if state.coolingWaterPumps[index].tripped {
            return "ERROR: Cooling pump \(number) is tripped."
        }
        if state.coolingWaterPumps[index].running {
            return "Cooling pump \(number) already running."
        }
        state.coolingWaterPumps[index].running = true
        if state.coolingWaterPumps[index].rpm == 0 {
            state.coolingWaterPumps[index].rpm = CANDUConstants.pumpRatedRPM
        }
        return "OK: Cooling pump \(number) started at \(formatValue(state.coolingWaterPumps[index].rpm)) RPM."
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
            state.dieselGenerators[0].power = 0.0
            return "OK: Diesel generator 1 stopped."

        case "aux.diesel.2.state":
            state.dieselGenerators[1].running = false
            state.dieselGenerators[1].available = false
            state.dieselGenerators[1].power = 0.0
            return "OK: Diesel generator 2 stopped."

        case "secondary.feed-pump.1.state":
            state.feedPumps[0].running = false
            state.feedPumps[0].flowRate = 0.0
            return "OK: Feed pump 1 stopped."
        case "secondary.feed-pump.2.state":
            state.feedPumps[1].running = false
            state.feedPumps[1].flowRate = 0.0
            return "OK: Feed pump 2 stopped."
        case "secondary.feed-pump.3.state":
            state.feedPumps[2].running = false
            state.feedPumps[2].flowRate = 0.0
            return "OK: Feed pump 3 stopped."

        case "primary.pump.1.rpm":
            state.primaryPumps[0].running = false
            state.primaryPumps[0].rpm = 0.0
            return "OK: Primary pump 1 stopped."
        case "primary.pump.2.rpm":
            state.primaryPumps[1].running = false
            state.primaryPumps[1].rpm = 0.0
            return "OK: Primary pump 2 stopped."
        case "primary.pump.3.rpm":
            state.primaryPumps[2].running = false
            state.primaryPumps[2].rpm = 0.0
            return "OK: Primary pump 3 stopped."
        case "primary.pump.4.rpm":
            state.primaryPumps[3].running = false
            state.primaryPumps[3].rpm = 0.0
            return "OK: Primary pump 4 stopped."

        case "tertiary.pump.1.rpm":
            state.coolingWaterPumps[0].running = false
            state.coolingWaterPumps[0].rpm = 0.0
            return "OK: Cooling pump 1 stopped."
        case "tertiary.pump.2.rpm":
            state.coolingWaterPumps[1].running = false
            state.coolingWaterPumps[1].rpm = 0.0
            return "OK: Cooling pump 2 stopped."

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

    private func handleSpeed(multiplier: Int) -> String {
        let validSpeeds = [1, 2, 5, 10]
        guard validSpeeds.contains(multiplier) else {
            return "ERROR: Speed must be one of: \(validSpeeds.map(String.init).joined(separator: ", "))"
        }
        state.timeAcceleration = multiplier
        return "OK: Time acceleration = \(multiplier)x"
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

        return """
        Power: \(power)% | Thermal: \(thermal) MW(th) | Gross: \(gross) MW(e) | Net: \(net) MW(e)
        Fuel: \(fuelT) degC | Pressure: \(pPressure) MPa | Flow: \(pFlow) kg/s | SCRAM: \(scramStatus)
        """
    }

    // MARK: - HELP

    private func handleHelp(topic: String?) -> String {
        guard let topic = topic else {
            return """
            Commands: set, get, start, stop, scram, view, speed, status, help
            Type 'help startup' for startup procedure. Type 'help paths' for all noun paths.
            Use Tab for auto-completion.
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
    /// - `bank-*` expands to bank-a, bank-b, bank-c, bank-d
    /// - `zone-*` expands to zone-1 through zone-6
    /// - Numeric `*` expands to all valid indices for that component
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
