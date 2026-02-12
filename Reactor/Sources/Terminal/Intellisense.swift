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
    private let validVerbs: [String] = ["set", "get", "start", "stop", "scram", "view", "speed", "status", "help", "quit", "exit"]

    /// Valid view screen names.
    private let viewScreens: [String] = ["overview", "core", "primary", "secondary", "electrical", "alarms"]

    /// Valid speed multipliers.
    private let validSpeeds: [String] = ["0.1", "0.25", "0.5", "1", "2", "5", "10"]

    /// Component help descriptions keyed by path prefix (longest prefix wins).
    private let componentDescriptions: [(prefix: String, text: String)] = [
        ("core.adjuster-rods", """
         ADJUSTER RODS — Fine Reactivity Control
         4 banks (A-D) of stainless steel rods normally withdrawn from the core.
         Each bank worth ~3.75 mk. Inserted/withdrawn to compensate for xenon
         transients and make small reactivity adjustments during load-following.
         Path: core.adjuster-rods.bank-{a,b,c,d}.pos (0=out, 100=in)
         """),
        ("core.zone-controllers", """
         ZONE CONTROLLERS — Spatial Flux Shaping
         6 vertical compartments in the moderator filled with light water (H2O).
         Light water absorbs neutrons, so raising fill level reduces local flux.
         Total reactivity worth ~1.5 mk. Used to flatten the flux profile and
         prevent xenon oscillations across the core.
         Path: core.zone-controllers.zone-{1..6}.fill (0-100%)
         """),
        ("core.mca", """
         MECHANICAL CONTROL ABSORBERS (MCA)
         2 motor-driven absorber rods for coarse reactivity control.
         Each worth ~5 mk. Used during large power maneuvers where adjuster
         rods alone provide insufficient reactivity span. Slower than adjusters
         but provide a larger reactivity effect.
         Path: core.mca.{1,2}.pos (0=out, 100=in)
         """),
        ("core.shutoff-rods", """
         SHUTOFF RODS — Emergency Shutdown (SDS-1)
         Gravity-driven spring-assisted shutdown rods held out of core by
         electromagnets. On SCRAM signal all rods drop into the core within
         ~2 seconds. Combined worth ~80 mk — enough to shut down the reactor
         from any operating state.
         Path: core.shutoff-rods.pos (0=out, 100=fully inserted)
         """),
        ("core", """
         CANDU-6 REACTOR CORE
         380 horizontal fuel channels in a calandria vessel filled with heavy
         water (D2O) moderator at ~70 degC. Each channel holds 12 fuel bundles
         of natural uranium. Rated thermal power: 2064 MW(th). The core uses
         on-power refueling — no need to shut down for fuel changes.
         """),
        ("primary", """
         PRIMARY HEAT TRANSPORT SYSTEM
         Pressurized heavy water (D2O) coolant circulated by 4 pumps through
         the fuel channels. Operating pressure ~10 MPa. Inlet ~265 degC,
         outlet ~310 degC. Two figure-of-eight loops, each with 2 pumps and
         2 steam generators. Total flow ~7700 kg/s at full power.
         """),
        ("secondary.turbine", """
         STEAM TURBINE & GOVERNOR VALVE
         Single-shaft turbine-generator rated ~680 MW(e) gross. The governor
         valve controls steam admission. At 1800 RPM (60 Hz) the generator
         is at synchronous speed for grid connection.
         Path: secondary.turbine.governor (0=closed, 1=open)
         """),
        ("secondary.feed-pump", """
         FEEDWATER PUMPS
         3 motor-driven pumps that return condensed water to the steam
         generators. Each draws ~3 MW. Binary start/stop operation. At least
         one feed pump must run to maintain steam generator levels.
         Path: start/stop secondary.feed-pump.{1,2,3}.auto
         """),
        ("secondary.sg", """
         STEAM GENERATORS
         4 vertical U-tube heat exchangers. Primary D2O (~310 degC) flows
         through the tubes; secondary light water boils on the shell side
         producing steam at ~4.7 MPa (~260 degC). Level is controlled by
         feedwater flow. Low level triggers a reactor trip.
         """),
        ("secondary.condenser", """
         CONDENSER
         Shell-and-tube heat exchanger below the turbine. Exhaust steam
         condenses on tubes cooled by tertiary (lake) water. Maintains
         vacuum (~5 kPa absolute) to maximize turbine efficiency.
         """),
        ("secondary", """
         SECONDARY (STEAM) SYSTEM
         Light water loop: 4 steam generators produce steam that drives the
         turbine-generator. Exhaust steam is condensed and returned by feed
         pumps. Includes turbine, condenser, 3 feed pumps, and the steam
         generator inventory.
         """),
        ("tertiary", """
         TERTIARY (COOLING WATER) SYSTEM
         Lake water circulated by 2 pumps through the condenser to remove
         waste heat. This is the ultimate heat sink for the plant.
         Path: tertiary.pump.{1,2}.rpm
         """),
        ("electrical", """
         ELECTRICAL SYSTEMS
         Generator output (~680 MW gross), grid connection via main breaker,
         and station service loads (~70 MW on-grid). When off-grid, essential
         loads (~2 MW) run on diesel backup. Grid sync requires turbine at
         1800 RPM (60 Hz).
         """),
        ("aux.diesel", """
         DIESEL GENERATORS — Emergency Backup Power
         2 diesel generators, 5 MW each. Require ~30 second warmup before
         accepting load. Provide emergency power when off-grid. Overload
         protection trips after 5 seconds above rated capacity — manage
         pump startups carefully to avoid tripping the diesels.
         Path: start/stop aux.diesel.{1,2}
         """),
    ]

    // MARK: - Init

    init() {
        var entries: [PathEntry] = []

        // --- Core: Read-only ---
        entries.append(PathEntry(
            path: "core.thermal-power",
            description: "Core thermal power (MW, read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "core.power-fraction",
            description: "Thermal power as fraction of rated (read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "core.fuel-temp",
            description: "Average fuel temperature (degC, read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "core.cladding-temp",
            description: "Average cladding temperature (degC, read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "core.reactivity",
            description: "Total reactivity (mk, read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "core.xenon-reactivity",
            description: "Xenon-135 reactivity worth (mk, read-only)",
            valueType: .readOnly, range: nil
        ))

        // --- Core: Adjuster Rods ---
        for bank in ["bank-a", "bank-b", "bank-c", "bank-d"] {
            entries.append(PathEntry(
                path: "core.adjuster-rods.\(bank).pos",
                description: "Adjuster rod \(bank) position (0=out, 100=in)",
                valueType: .double,
                range: 0.0...100.0
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
                path: "core.mca.\(unit).pos",
                description: "Mechanical control absorber \(unit) position (0=out, 100=in)",
                valueType: .double,
                range: 0.0...100.0
            ))
        }

        // --- Core: Shutoff rods ---
        entries.append(PathEntry(
            path: "core.shutoff-rods.pos",
            description: "Shutoff rod insertion (0=out, 100=in)",
            valueType: .double,
            range: 0.0...100.0
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
                path: "secondary.feed-pump.\(pump).auto",
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

        // --- Secondary: Read-only system values ---
        entries.append(PathEntry(
            path: "secondary.steam-pressure",
            description: "Main steam header pressure (MPa, read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "secondary.steam-temp",
            description: "Main steam temperature (degC, read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "secondary.steam-flow",
            description: "Total steam flow rate (kg/s, read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "secondary.feedwater-temp",
            description: "Feedwater temperature (degC, read-only)",
            valueType: .readOnly, range: nil
        ))

        // --- Electrical ---
        entries.append(PathEntry(
            path: "electrical.gross-power",
            description: "Gross electrical output (MW, read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "electrical.net-power",
            description: "Net electrical output (MW, read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "electrical.frequency",
            description: "Generator frequency (Hz, read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "electrical.grid-connected",
            description: "Generator grid synchronization (read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "electrical.station-service",
            description: "Current effective electrical load (MW, read-only)",
            valueType: .readOnly, range: nil
        ))
        entries.append(PathEntry(
            path: "electrical.diesel-capacity",
            description: "Available diesel generator capacity (MW, read-only)",
            valueType: .readOnly, range: nil
        ))

        // --- Tertiary: Pumps ---
        for pump in 1...2 {
            entries.append(PathEntry(
                path: "tertiary.pump.\(pump).rpm",
                description: "Cooling water pump \(pump) target RPM",
                valueType: .double,
                range: 0.0...1500.0
            ))
        }

        // --- Tertiary: Read-only ---
        entries.append(PathEntry(
            path: "tertiary.cooling-water-flow",
            description: "Total cooling water flow (kg/s, read-only)",
            valueType: .readOnly, range: nil
        ))

        // --- Auxiliary: Diesel Generators ---
        for dg in 1...2 {
            entries.append(PathEntry(
                path: "aux.diesel.\(dg).state",
                description: "Diesel generator \(dg) (use start/stop)",
                valueType: .toggle,
                range: nil
            ))
            entries.append(PathEntry(
                path: "aux.diesel.\(dg).fuel",
                description: "Diesel generator \(dg) fuel level (%, read-only)",
                valueType: .readOnly,
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
    func completions(for partialInput: String, valueLookup: ((String) -> String?)? = nil) -> [String] {
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
                let commandTopics = ["set", "get", "start", "stop", "scram", "view", "speed", "startup", "paths"]
                let componentTopics = componentDescriptions.map { $0.prefix }
                let allTopics = commandTopics + componentTopics
                return Array(Set(allTopics
                    .filter { $0.hasPrefix(partial) }
                    .map { "help \($0)" }
                )).sorted()
            }
            return []

        case "set", "get":
            return pathCompletions(verb: verb, tokens: tokens, partialInput: partialInput, includeSettable: verb == "set", valueLookup: valueLookup)

        case "start", "stop":
            return togglePathCompletions(verb: verb, tokens: tokens, partialInput: partialInput)

        case "scram", "status":
            return []

        default:
            return []
        }
    }

    /// Generate completions for set/get commands (paths with possible glob).
    private func pathCompletions(verb: String, tokens: [String], partialInput: String, includeSettable: Bool, valueLookup: ((String) -> String?)? = nil) -> [String] {
        // When the user has finished typing a path (space after it, or already typing a value),
        // show the valid range instead of more path completions.
        if verb == "set" && tokens.count >= 2 {
            let typedPath = tokens[1].lowercased()
            let isTypingValue = tokens.count >= 3 || partialInput.hasSuffix(" ")
            if isTypingValue, let hint = rangeHint(for: typedPath, valueLookup: valueLookup) {
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

        // For "set", filter to writable paths only. For "get", show all paths.
        let filteredEntries: [PathEntry]
        if includeSettable {
            filteredEntries = pathEntries.filter { $0.valueType != .toggle && $0.valueType != .readOnly }
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
    private func rangeHint(for path: String, valueLookup: ((String) -> String?)? = nil) -> String? {
        // Exact match
        if let entry = pathEntries.first(where: { $0.path == path }), let range = entry.range {
            let current = valueLookup?(path) ?? "?"
            return "Range: \(formatRange(range))  Current: \(current)"
        }
        // Glob match — find first matching entry with a range
        if path.contains("*") {
            for entry in pathEntries {
                if globMatchesSimple(pattern: path, candidate: entry.path), let range = entry.range {
                    return "Range: \(formatRange(range))"
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

    /// Generate completions for start/stop commands (startable/stoppable components only).
    private func togglePathCompletions(verb: String, tokens: [String], partialInput: String) -> [String] {
        let partialPath: String
        if tokens.count >= 2 && !partialInput.hasSuffix(" ") {
            partialPath = tokens[1].lowercased()
        } else {
            partialPath = ""
        }

        var results: [String] = []

        // Toggle entries (strip .state suffix for cleaner completions)
        for entry in pathEntries where entry.valueType == .toggle {
            let cleanPath = entry.path.hasSuffix(".state") ? String(entry.path.dropLast(6)) : entry.path
            if cleanPath.hasPrefix(partialPath) {
                results.append("\(verb) \(cleanPath)")
            }
        }

        return Array(Set(results)).sorted()
    }

    /// Generate glob path suggestions (e.g., "core.adjuster-rods.bank-*.pos").
    private func expandableGlobPaths(for verb: String, partialPath: String, includeSettable: Bool) -> [String] {
        var globs: Set<String> = []

        let filteredEntries: [PathEntry]
        if includeSettable {
            filteredEntries = pathEntries.filter { $0.valueType != .toggle && $0.valueType != .readOnly }
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
            return "SET <path> <value> - Set a system parameter. Example: set core.adjuster-rods.bank-a.pos 0"

        case "get":
            return "GET <path> - Read a system parameter. Example: get primary.pump.1.rpm"

        case "start":
            return "START <path> - Start a component. Example: start aux.diesel.1\nFor pumps, use 'set <path>.rpm <value>' instead."

        case "stop":
            return "STOP <path> - Stop a component. Example: stop aux.diesel.1\nFor pumps, use 'set <path>.rpm 0' instead."

        case "scram":
            return "SCRAM - Emergency shutdown. Fully inserts all shutoff rods immediately."

        case "view":
            return "VIEW <screen> - Switch display. Screens: overview, core, primary, secondary, electrical, alarms"

        case "speed":
            return "SPEED <multiplier> - Set time acceleration. Valid: 0.1, 0.25, 0.5, 1, 2, 5, 10"

        case "status":
            return "STATUS - Display summary of all major reactor parameters."

        case "startup":
            return """
            REACTOR STARTUP PROCEDURE:
            Phase 1 — Bootstrap on diesel (10 MW capacity):
            1. Start both diesels       start aux.diesel.*
            2. (Wait 30s for warmup)    speed 5
            3. CW pump at 10% RPM       set tertiary.pump.1.rpm 150
            4. Primary pumps at 10%     set primary.pump.1.rpm 150
               (repeat for pump 2)      set primary.pump.2.rpm 150
            5. Start feed pump (~3 MW)  start secondary.feed-pump.1.auto
            6. Withdraw shutoff rods    set core.shutoff-rods.pos 0
            Phase 2 — Achieve criticality:
            7. Withdraw adjuster rods   set core.adjuster-rods.bank-*.pos 0
            8. Lower zone controllers   set core.zone-controllers.zone-*.fill 50
            9. Monitor for criticality  view core
            Phase 3 — Power ascension:
            10. Open turbine governor   set secondary.turbine.governor 0.5
            11. Sync generator to grid when power > 5%
            12. Ramp pumps with power:  25% → 500 RPM, 50% → 1000 RPM,
                75% → 1200 RPM, 100% → 1500 RPM (rated)
            Low RPM on diesel conserves power (cube law). After grid sync
            you have unlimited electrical supply to ramp pumps fully.
            Use 'speed 5' to accelerate time. PageUp/PageDown to scroll.
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
            // Check component help (prefix match, longest prefix wins)
            if let text = componentHelp(for: lowered) {
                return text
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

    // MARK: - Component Help

    /// Returns a component help description for the given input, matching the longest prefix.
    private func componentHelp(for input: String) -> String? {
        var bestMatch: (prefix: String, text: String)?
        for entry in componentDescriptions {
            if input == entry.prefix || input.hasPrefix(entry.prefix + ".") {
                if bestMatch == nil || entry.prefix.count > bestMatch!.prefix.count {
                    bestMatch = entry
                }
            }
        }
        return bestMatch?.text
    }

    // MARK: - Formatting

    private func formatRange(_ range: ClosedRange<Double>) -> String {
        let lower = range.lowerBound == range.lowerBound.rounded() ? String(format: "%.0f", range.lowerBound) : String(format: "%.1f", range.lowerBound)
        let upper = range.upperBound == range.upperBound.rounded() ? String(format: "%.0f", range.upperBound) : String(format: "%.1f", range.upperBound)
        return "\(lower) - \(upper)"
    }
}
