import Foundation

/// Auxiliary plant systems: diesel generators, moderator, heavy water inventory.
enum AuxiliarySystems {

    static func step(state: ReactorState, dt: Double) {
        updateDieselGenerators(state: state, dt: dt)
        checkDieselOverload(state: state, dt: dt)
        updateModerator(state: state, dt: dt)
        updateHeavyWaterInventory(state: state, dt: dt)
    }

    // MARK: - Diesel Generators

    private static func updateDieselGenerators(state: ReactorState, dt: Double) {
        for i in 0..<2 {
            if state.dieselGenerators[i].startTime >= 0 && !state.dieselGenerators[i].available {
                // Diesel is in warmup phase
                let elapsed = state.elapsedTime - state.dieselGenerators[i].startTime
                if elapsed >= CANDUConstants.dieselStartTime {
                    // Warmup complete - diesel is now available and auto-loaded
                    state.dieselGenerators[i].running = true
                    state.dieselGenerators[i].available = true
                    state.dieselGenerators[i].loaded = true
                    state.dieselGenerators[i].power = 0.0
                }
            }

            if state.dieselGenerators[i].available && state.dieselGenerators[i].loaded {
                // Ramp power to rated
                let rampRate = CANDUConstants.dieselPower / 10.0 // reach full power in ~10s
                state.dieselGenerators[i].power = min(
                    state.dieselGenerators[i].power + rampRate * dt,
                    CANDUConstants.dieselPower
                )

                // Consume fuel proportional to power output
                if state.dieselGenerators[i].power > 0 {
                    let fuelRate = (state.dieselGenerators[i].power / CANDUConstants.dieselPower) * dt / CANDUConstants.dieselFuelDuration
                    state.dieselGenerators[i].fuelLevel = max(state.dieselGenerators[i].fuelLevel - fuelRate, 0.0)

                    // Low fuel warning at 10%
                    if state.dieselGenerators[i].fuelLevel < 0.10 && !state.dieselGenerators[i].lowFuelWarned {
                        state.dieselGenerators[i].lowFuelWarned = true
                        state.addAlarm(message: "DIESEL \(i + 1) FUEL LOW (<10%)", severity: .warning)
                    }

                    // Out of fuel — stop diesel
                    if state.dieselGenerators[i].fuelLevel <= 0 {
                        state.dieselGenerators[i].running = false
                        state.dieselGenerators[i].available = false
                        state.dieselGenerators[i].loaded = false
                        state.dieselGenerators[i].power = 0.0
                        state.dieselGenerators[i].startTime = -1.0
                        state.addAlarm(message: "DIESEL \(i + 1) FUEL EXHAUSTED - engine stopped", severity: .alarm)
                    }
                }
            } else if state.dieselGenerators[i].available && !state.dieselGenerators[i].loaded {
                // Running but unloaded - at idle (minimal fuel consumption)
                let idleFuelRate = 0.05 * dt / CANDUConstants.dieselFuelDuration
                state.dieselGenerators[i].fuelLevel = max(state.dieselGenerators[i].fuelLevel - idleFuelRate, 0.0)
                state.dieselGenerators[i].power = 0.0

                if state.dieselGenerators[i].fuelLevel <= 0 {
                    state.dieselGenerators[i].running = false
                    state.dieselGenerators[i].available = false
                    state.dieselGenerators[i].loaded = false
                    state.dieselGenerators[i].startTime = -1.0
                    state.addAlarm(message: "DIESEL \(i + 1) FUEL EXHAUSTED - engine stopped", severity: .alarm)
                }
            }

            // If diesel was shut down
            if !state.dieselGenerators[i].running && state.dieselGenerators[i].power > 0 {
                state.dieselGenerators[i].power = 0.0
                state.dieselGenerators[i].loaded = false
                state.dieselGenerators[i].available = false
                state.dieselGenerators[i].startTime = -1.0
            }
        }
    }

    // MARK: - Diesel Overload

    private static func checkDieselOverload(state: ReactorState, dt: Double) {
        // Only relevant when off-grid and running on diesels
        guard !state.generatorConnected else {
            state.dieselOverloadStartTime = -1.0
            return
        }

        // Check if any diesels are actually available
        let hasDiesel = state.dieselGenerators.contains { $0.available && $0.loaded }
        guard hasDiesel else {
            state.dieselOverloadStartTime = -1.0
            return
        }

        if state.isElectricalOverloaded {
            if state.dieselOverloadStartTime < 0 {
                // Start overload timer
                state.dieselOverloadStartTime = state.elapsedTime
                state.addAlarm(message: "DIESEL OVERLOAD - load exceeds capacity", severity: .warning)
            } else {
                // Check if sustained overload exceeds trip delay
                let overloadDuration = state.elapsedTime - state.dieselOverloadStartTime
                if overloadDuration >= CANDUConstants.dieselOverloadTripDelay {
                    tripAllDiesels(state: state)
                }
            }
        } else {
            // Load within capacity, clear timer
            state.dieselOverloadStartTime = -1.0
        }
    }

    /// Trip all diesel generators due to overload. Cascading loss of all pumps.
    private static func tripAllDiesels(state: ReactorState) {
        // Trip all diesels
        for i in 0..<state.dieselGenerators.count {
            state.dieselGenerators[i].running = false
            state.dieselGenerators[i].available = false
            state.dieselGenerators[i].loaded = false
            state.dieselGenerators[i].power = 0.0
            state.dieselGenerators[i].startTime = -1.0
        }

        state.addAlarm(message: "DIESEL GENERATORS TRIPPED - OVERLOAD", severity: .trip)
        state.addAlarm(message: "STATION BLACKOUT", severity: .trip)

        // Trip all primary pumps (coastdown logic handles the rest)
        for i in 0..<state.primaryPumps.count where state.primaryPumps[i].running {
            state.primaryPumps[i].rpmAtTrip = state.primaryPumps[i].rpm
            state.primaryPumps[i].tripped = true
            state.primaryPumps[i].tripTime = state.elapsedTime
        }

        // Trip all cooling water pumps
        for i in 0..<state.coolingWaterPumps.count where state.coolingWaterPumps[i].running {
            state.coolingWaterPumps[i].rpmAtTrip = state.coolingWaterPumps[i].rpm
            state.coolingWaterPumps[i].tripped = true
            state.coolingWaterPumps[i].tripTime = state.elapsedTime
        }

        // Stop all feed pumps (binary on/off, no coastdown)
        for i in 0..<state.feedPumps.count {
            state.feedPumps[i].running = false
            state.feedPumps[i].flowRate = 0.0
        }

        state.dieselOverloadStartTime = -1.0
    }

    // MARK: - Moderator System

    private static func updateModerator(state: ReactorState, dt: Double) {
        // Moderator D2O circulation system
        // In CANDU, the moderator is separate from the coolant
        // It must be circulating for proper moderation and heat removal

        // If moderator is not circulating and reactor is producing significant power,
        // the moderator would heat up. This is a simplified model.
        // For game purposes, moderator circulation is a prerequisite for sustained operation.

        // No complex dynamics here - just track the on/off state
        // The moderator pump is assumed to have negligible startup time
    }

    // MARK: - Heavy Water Inventory

    private static func updateHeavyWaterInventory(state: ReactorState, dt: Double) {
        // Track D2O inventory as a percentage
        // Under normal conditions, inventory stays at 100%
        // Leaks could reduce it (future feature)
        // For now, clamp to valid range
        state.heavyWaterInventory = min(max(state.heavyWaterInventory, 0.0), 100.0)
    }

    // MARK: - Public Commands

    /// Start a diesel generator (begins warmup sequence).
    static func startDiesel(state: ReactorState, index: Int) {
        guard index >= 0 && index < 2 else { return }
        guard !state.dieselGenerators[index].running else { return }

        state.dieselGenerators[index].startTime = state.elapsedTime
        state.dieselGenerators[index].running = false // not yet running, warming up
        state.dieselGenerators[index].available = false
        state.dieselGenerators[index].loaded = false
        state.dieselGenerators[index].power = 0.0
    }

    /// Stop a diesel generator.
    static func stopDiesel(state: ReactorState, index: Int) {
        guard index >= 0 && index < 2 else { return }
        state.dieselGenerators[index].running = false
        state.dieselGenerators[index].available = false
        state.dieselGenerators[index].loaded = false
        state.dieselGenerators[index].power = 0.0
        state.dieselGenerators[index].startTime = -1.0
    }

    /// Load/unload a diesel generator onto the electrical bus.
    static func loadDiesel(state: ReactorState, index: Int, load: Bool) {
        guard index >= 0 && index < 2 else { return }
        guard state.dieselGenerators[index].available else { return }
        state.dieselGenerators[index].loaded = load
    }

    /// Toggle moderator circulation.
    static func setModeratorCirculation(state: ReactorState, running: Bool) {
        state.moderatorCirculating = running
    }
}
