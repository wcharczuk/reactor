import Foundation

/// Auxiliary plant systems: diesel generators, moderator, heavy water inventory.
enum AuxiliarySystems {

    static func step(state: ReactorState, dt: Double) {
        updateDieselGenerators(state: state, dt: dt)
        updateModerator(state: state, dt: dt)
        updateHeavyWaterInventory(state: state, dt: dt)
    }

    // MARK: - Diesel Generators

    private static func updateDieselGenerators(state: ReactorState, dt: Double) {
        for i in 0..<2 {
            if state.dieselGenerators[i].startTime > 0 && !state.dieselGenerators[i].available {
                // Diesel is in warmup phase
                let elapsed = state.elapsedTime - state.dieselGenerators[i].startTime
                if elapsed >= CANDUConstants.dieselStartTime {
                    // Warmup complete - diesel is now available
                    state.dieselGenerators[i].running = true
                    state.dieselGenerators[i].available = true
                    state.dieselGenerators[i].power = 0.0 // Available but not yet loaded
                }
            }

            if state.dieselGenerators[i].available && state.dieselGenerators[i].loaded {
                // Ramp power to rated
                let rampRate = CANDUConstants.dieselPower / 10.0 // reach full power in ~10s
                state.dieselGenerators[i].power = min(
                    state.dieselGenerators[i].power + rampRate * dt,
                    CANDUConstants.dieselPower
                )
            } else if state.dieselGenerators[i].available && !state.dieselGenerators[i].loaded {
                // Running but unloaded - at idle
                state.dieselGenerators[i].power = 0.0
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
