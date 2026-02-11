import Foundation

/// Metadata for a single noun-path entry in the command system.
struct PathEntry {
    let path: String
    let description: String
    let valueType: ValueType
    let range: ClosedRange<Double>?

    enum ValueType {
        case double   // Continuous numeric value
        case integer  // Integer numeric value
        case toggle   // start/stop (no numeric value)
        case readOnly // Cannot be set, only read
    }
}

/// Provides tab-completion and inline help for the terminal command system.
///
/// Maintains a registry of all valid noun paths with their metadata and
/// generates completions based on partial input.
final class Intellisense {

    // MARK: - Registry

    /// All registered noun paths with metadata.
    private let pathEntries: [PathEntry]

    /// All valid verbs.
    private let validVerbs: [String] = ["set", "get", "start", "stop", "scram", "view", "speed", "status", "help"]

    /// Valid view screen names.
    private let viewScreens: [String] = ["overview", "core", "primary", "secondary", "electrical", "alarms"]

    /// Valid speed multipliers.
    private let validSpeeds: [String] = ["1", "2", "5", "10"]

    // MARK: - Init

    init() {
        var entries: [PathEntry] = []

        // --- Core: Adjuster Rods ---
        for bank in ["bank-a", "bank-b", "bank-c", "bank-d"] {
            entries.append(PathEntry(
                path: "core.adjuster-rods.\(bank).position",
                description: "Adjuster rod \(bank) position (0.0=inserted, 1.0=withdrawn)",
                valueType: .double,
                range: 0.0...1.0
            ))
        }

        // --- Core: Zone Controllers ---
        for zone in 1...6 {
            entries.append(PathEntry(
                path: "core.zone-controllers.zone-\(zone).fill",
                description: "Zone controller \(zone) light water fill level (0-100%)",
                valueType: .double,
                range: 0.0...100.0
            ))
        }

        // --- Core: MCA ---
        for unit in 1...2 {
            entries.append(PathEntry(
                path: "core.mca.\(unit).position",
                description: "Mechanical control absorber \(unit) position (0.0=inserted, 1.0=withdrawn)",
                valueType: .double,
                range: 0.0...1.0
            ))
        }

        // --- Core: Shutoff rods ---
        entries.append(PathEntry(
            path: "core.shutoff-rods.position",
            description: "Shutoff rod insertion (0.0=withdrawn, 1.0=fully inserted)",
            valueType: .double,
            range: 0.0...1.0
        ))

        // --- Primary: Pumps ---
        for pump in 1...4 {
            entries.append(PathEntry(
                path: "primary.pump.\(pump).rpm",
                description: "Primary heat transport pump \(pump) target RPM",
                valueType: .double,
                range: 0.0...1500.0
            ))
        }

        entries.append(PathEntry(
            path: "primary.pressure",
            description: "Primary system pressure (MPa, read-only)",
            valueType: .readOnly,
            range: nil
        ))

        entries.append(PathEntry(
            path: "primary.inlet-temp",
            description: "Primary inlet (cold leg) temperature (degC, read-only)",
            valueType: .readOnly,
            range: nil
        ))

        entries.append(PathEntry(
            path: "primary.outlet-temp",
            description: "Primary outlet (hot leg) temperature (degC, read-only)",
            valueType: .readOnly,
            range: nil
        ))

        entries.append(PathEntry(
            path: "primary.flow-rate",
            description: "Primary total flow rate (kg/s, read-only)",
            valueType: .readOnly,
            range: nil
        ))

        // --- Secondary: Feed Pumps ---
        for pump in 1...3 {
            entries.append(PathEntry(
                path: "secondary.feed-pump.\(pump).state",
                description: "Feed water pump \(pump) (use start/stop)",
                valueType: .toggle,
                range: nil
            ))
        }

        // --- Secondary: Turbine ---
        entries.append(PathEntry(
            path: "secondary.turbine.governor",
            description: "Turbine governor valve position (0.0=closed, 1.0=fully open)",
            valueType: .double,
            range: 0.0...1.0
        ))

        entries.append(PathEntry(
            path: "secondary.turbine.rpm",
            description: "Turbine speed in RPM (read-only)",
            valueType: .readOnly,
            range: nil
        ))

        entries.append(PathEntry(
            path: "secondary.condenser.pressure",
            description: "Condenser pressure in MPa (read-only)",
            valueType: .readOnly,
            range: nil
        ))

        entries.append(PathEntry(
            path: "secondary.condenser.temp",
            description: "Condenser temperature in degC (read-only)",
            valueType: .readOnly,
            range: nil
        ))

        // --- Secondary: Steam Generators ---
        for sg in 1...4 {
            entries.append(PathEntry(
                path: "secondary.sg.\(sg).level",
                description: "Steam generator \(sg) level (%, read-only)",
                valueType: .readOnly,
                range: nil
            ))
            entries.append(PathEntry(
                path: "secondary.sg.\(sg).pressure",
                description: "Steam generator \(sg) pressure (MPa, read-only)",
                valueType: .readOnly,
                range: nil
            ))
        }

        // --- Tertiary: Pumps ---
        for pump in 1...2 {
            entries.append(PathEntry(
                path: "tertiary.pump.\(pump).rpm",
                description: "Cooling water pump \(pump) target RPM",
                valueType: .double,
                range: 0.0...1500.0
            ))
        }

        // --- Auxiliary: Diesel Generators ---
        for dg in 1...2 {
            entries.append(PathEntry(
                path: "aux.diesel.\(dg).state",
                description: "Diesel generator \(dg) (use start/stop)",
                valueType: .toggle,
                range: nil
            ))
        }

        self.pathEntries = entries
    }

    // MARK: - Completions

    /// Returns matching completions for the current partial input string.
    ///
    /// The input may be a partial verb, a verb with a partial path, or a verb
    /// with a partial path and partial value.
    func completions(for partialInput: String) -> [String] {
        let trimmed = partialInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return validVerbs
        }

        let tokens = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            .map { String($0) }

        let verb = tokens[0].lowercased()

        // If we only have a partial verb (no space after it yet)
        if tokens.count == 1 && !partialInput.hasSuffix(" ") {
            return validVerbs.filter { $0.hasPrefix(verb) }
        }

        // We have a verb. Generate completions based on verb type.
        switch verb {
        case "view":
            if tokens.count < 2 || (tokens.count == 2 && !partialInput.hasSuffix(" ")) {
                let partial = tokens.count >= 2 ? tokens[1].lowercased() : ""
                return viewScreens
                    .filter { $0.hasPrefix(partial) }
                    .map { "view \($0)" }
            }
            return []

        case "speed":
            if tokens.count < 2 || (tokens.count == 2 && !partialInput.hasSuffix(" ")) {
                let partial = tokens.count >= 2 ? tokens[1] : ""
                return validSpeeds
                    .filter { $0.hasPrefix(partial) }
                    .map { "speed \($0)" }
            }
            return []

        case "help":
            if tokens.count < 2 || (tokens.count == 2 && !partialInput.hasSuffix(" ")) {
                let partial = tokens.count >= 2 ? tokens[1].lowercased() : ""
                let topics = ["set", "get", "start", "stop", "scram", "view", "speed", "startup", "paths"]
                return topics
                    .filter { $0.hasPrefix(partial) }
                    .map { "help \($0)" }
            }
            return []

        case "set", "get":
            return pathCompletions(verb: verb, tokens: tokens, partialInput: partialInput, includeSettable: verb == "set")

        case "start", "stop":
            return togglePathCompletions(verb: verb, tokens: tokens, partialInput: partialInput)

        case "scram", "status":
            return []

        default:
            return []
        }
    }

    /// Generate completions for set/get commands (paths with possible glob).
    private func pathCompletions(verb: String, tokens: [String], partialInput: String, includeSettable: Bool) -> [String] {
        // When the user has finished typing a path (space after it, or already typing a value),
        // show the valid range instead of more path completions.
        if verb == "set" && tokens.count >= 2 {
            let typedPath = tokens[1].lowercased()
            let isTypingValue = tokens.count >= 3 || partialInput.hasSuffix(" ")
            if isTypingValue, let hint = rangeHint(for: typedPath) {
                return [hint]
            }
        }

        let partialPath: String
        if tokens.count >= 2 && !partialInput.hasSuffix(" ") {
            partialPath = tokens[1].lowercased()
        } else if tokens.count >= 2 && partialInput.hasSuffix(" ") && tokens.count < 3 {
            // They typed "set " with a space - show all paths
            partialPath = ""
        } else {
            partialPath = tokens.count >= 2 ? tokens[1].lowercased() : ""
        }

        // For "set", filter to writable paths. For "get", show all paths.
        let filteredEntries: [PathEntry]
        if includeSettable {
            filteredEntries = pathEntries.filter { $0.valueType != .toggle }
        } else {
            filteredEntries = pathEntries
        }

        let matchingPaths = filteredEntries
            .filter { $0.path.hasPrefix(partialPath) }
            .map { "\(verb) \($0.path)" }

        // Also add glob variants if partial matches a numbered component pattern
        var results = matchingPaths
        let globPaths = expandableGlobPaths(for: verb, partialPath: partialPath, includeSettable: includeSettable)
        results.append(contentsOf: globPaths)

        // Remove duplicates and sort
        return Array(Set(results)).sorted()
    }

    /// Returns a range hint string for a completed path (exact or glob).
    private func rangeHint(for path: String) -> String? {
        // Exact match
        if let entry = pathEntries.first(where: { $0.path == path }), let range = entry.range {
            return "Value: \(formatRange(range))"
        }
        // Glob match — find first matching entry with a range
        if path.contains("*") {
            for entry in pathEntries {
                if globMatchesSimple(pattern: path, candidate: entry.path), let range = entry.range {
                    return "Value: \(formatRange(range))"
                }
            }
        }
        return nil
    }

    /// Simple glob matcher for path segments (* matches any single segment).
    private func globMatchesSimple(pattern: String, candidate: String) -> Bool {
        let patParts = pattern.split(separator: ".").map(String.init)
        let candParts = candidate.split(separator: ".").map(String.init)
        guard patParts.count == candParts.count else { return false }
        for (pat, cand) in zip(patParts, candParts) {
            if pat == "*" { continue }
            if pat.hasSuffix("*") {
                if !cand.hasPrefix(String(pat.dropLast())) { return false }
                continue
            }
            if pat != cand { return false }
        }
        return true
    }

    /// Generate completions for start/stop commands (toggle paths only).
    private func togglePathCompletions(verb: String, tokens: [String], partialInput: String) -> [String] {
        let partialPath: String
        if tokens.count >= 2 && !partialInput.hasSuffix(" ") {
            partialPath = tokens[1].lowercased()
        } else {
            partialPath = ""
        }

        let toggleEntries = pathEntries.filter { $0.valueType == .toggle }
        let matchingPaths = toggleEntries
            .filter { $0.path.hasPrefix(partialPath) }
            .map { "\(verb) \($0.path)" }

        // Also include component paths for start/stop of pumps (by removing .rpm suffix)
        var pumpPaths: [String] = []
        for entry in pathEntries where entry.path.hasSuffix(".rpm") {
            let basePath = String(entry.path.dropLast(4)) // remove ".rpm"
            if basePath.hasPrefix(partialPath) {
                pumpPaths.append("\(verb) \(basePath)")
            }
        }

        return Array(Set(matchingPaths + pumpPaths)).sorted()
    }

    /// Generate glob path suggestions (e.g., "core.adjuster-rods.bank-*.position").
    private func expandableGlobPaths(for verb: String, partialPath: String, includeSettable: Bool) -> [String] {
        var globs: Set<String> = []

        let filteredEntries: [PathEntry]
        if includeSettable {
            filteredEntries = pathEntries.filter { $0.valueType != .toggle }
        } else {
            filteredEntries = pathEntries
        }

        // Group paths by pattern (replace numbered/named segments with *)
        for entry in filteredEntries {
            let components = entry.path.split(separator: ".").map(String.init)
            for (i, comp) in components.enumerated() {
                // Check if this component matches a pattern like "bank-a", "1", "zone-1"
                if comp.last?.isNumber == true || ["bank-a", "bank-b", "bank-c", "bank-d"].contains(comp) {
                    var globComponents = components
                    if comp.hasPrefix("bank-") {
                        globComponents[i] = "bank-*"
                    } else if comp.hasPrefix("zone-") {
                        globComponents[i] = "zone-*"
                    } else {
                        globComponents[i] = "*"
                    }
                    let globPath = globComponents.joined(separator: ".")
                    if globPath.hasPrefix(partialPath) {
                        globs.insert("\(verb) \(globPath)")
                    }
                }
            }
        }

        return Array(globs)
    }

    // MARK: - Help Text

    /// Returns help text for a given command or topic.
    func helpText(for command: String) -> String? {
        let lowered = command.lowercased().trimmingCharacters(in: .whitespaces)

        switch lowered {
        case "set":
            return "SET <path> <value> - Set a system parameter. Example: set core.adjuster-rods.bank-a.position 0.5"

        case "get":
            return "GET <path> - Read a system parameter. Example: get primary.pump.1.rpm"

        case "start":
            return "START <path> - Start a component. Example: start aux.diesel.1"

        case "stop":
            return "STOP <path> - Stop a component. Example: stop primary.pump.1"

        case "scram":
            return "SCRAM - Emergency shutdown. Fully inserts all shutoff rods immediately."

        case "view":
            return "VIEW <screen> - Switch display. Screens: overview, core, primary, secondary, electrical, alarms"

        case "speed":
            return "SPEED <multiplier> - Set time acceleration. Valid: 1, 2, 5, 10"

        case "status":
            return "STATUS - Display summary of all major reactor parameters."

        case "startup":
            return """
            REACTOR STARTUP PROCEDURE:
            1. Start cooling water     start tertiary.pump.1 ; start tertiary.pump.2
            2. Start primary pumps      start primary.pump.1  (repeat for 2, 3, 4)
            3. Start feed pump          start secondary.feed-pump.1
            4. Withdraw shutoff rods    set core.shutoff-rods.position 0
            5. Withdraw adjuster rods   set core.adjuster-rods.bank-a.position 1
               (repeat for bank-b, bank-c, bank-d or use bank-*)
            6. Lower zone controller    set core.zone-controllers.zone-*.fill 50
            7. Monitor for criticality  view core
            8. Open turbine governor    set secondary.turbine.governor 0.5
            Raise power gradually. Use 'speed 5' to accelerate time.
            """

        case "paths":
            var text = "Available noun paths:\n"
            for entry in pathEntries {
                let rangeStr: String
                if let r = entry.range {
                    rangeStr = " [\(formatRange(r))]"
                } else {
                    rangeStr = ""
                }
                text += "  \(entry.path)\(rangeStr) - \(entry.description)\n"
            }
            return text

        default:
            // Check if it is a specific path
            if let entry = pathEntries.first(where: { $0.path == lowered }) {
                let rangeStr: String
                if let r = entry.range {
                    rangeStr = " Range: \(formatRange(r))."
                } else {
                    rangeStr = ""
                }
                return "\(entry.path) - \(entry.description).\(rangeStr)"
            }
            return nil
        }
    }

    /// Returns the path entry for a given path, if it exists.
    func entry(for path: String) -> PathEntry? {
        return pathEntries.first { $0.path == path.lowercased() }
    }

    /// Returns all registered path strings.
    var allPaths: [String] {
        return pathEntries.map { $0.path }
    }

    // MARK: - Formatting

    private func formatRange(_ range: ClosedRange<Double>) -> String {
        let lower = range.lowerBound == range.lowerBound.rounded() ? String(format: "%.0f", range.lowerBound) : String(format: "%.1f", range.lowerBound)
        let upper = range.upperBound == range.upperBound.rounded() ? String(format: "%.0f", range.upperBound) : String(format: "%.1f", range.upperBound)
        return "\(lower) - \(upper)"
    }
}
