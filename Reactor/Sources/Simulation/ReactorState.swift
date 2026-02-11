import Foundation

// MARK: - CANDU-6 Physical Constants

struct CANDUConstants {
    // Rated thermal power (MW_th)
    static let ratedThermalPower: Double = 2064.0
    // Rated gross electrical (MW_e)
    static let ratedGrossElectrical: Double = 728.0
    // Rated net electrical (MW_e)
    static let ratedNetElectrical: Double = 660.0

    // --- Neutronics ---
    static let totalBeta: Double = 0.0065
    static let promptNeutronLifetime: Double = 0.0009 // seconds (Lambda)

    struct DelayedGroup {
        let beta: Double
        let lambda: Double // decay constant (1/s)
    }

    static let delayedGroups: [DelayedGroup] = [
        DelayedGroup(beta: 0.000247, lambda: 0.0127),
        DelayedGroup(beta: 0.001385, lambda: 0.0317),
        DelayedGroup(beta: 0.001222, lambda: 0.115),
        DelayedGroup(beta: 0.002645, lambda: 0.311),
        DelayedGroup(beta: 0.000832, lambda: 1.40),
        DelayedGroup(beta: 0.000169, lambda: 3.87),
    ]

    // --- Reactivity Worth (mk) ---
    static let adjusterBankWorth: Double = 3.75   // mk per bank (4 banks)
    static let adjusterTotalWorth: Double = 15.0   // mk total
    static let mcaWorth: Double = 5.0              // mk per MCA device (2 devices)
    static let mcaTotalWorth: Double = 10.0        // mk total
    static let zoneControlTotalWorth: Double = 3.0 // mk total (symmetric about 0)
    static let shutoffRodWorth: Double = 80.0      // mk total (all SORs)

    // --- Reactivity Feedback Coefficients ---
    static let dopplerCoefficient: Double = -0.014   // mk/degC (negative = stabilizing)
    static let coolantTempCoefficient: Double = 0.028 // mk/degC (positive in CANDU)
    static let fuelTempReference: Double = 25.0       // degC
    static let coolantTempReference: Double = 25.0    // degC

    // --- Thermal-Hydraulic ---
    static let fuelHeatCapacity: Double = 300.0       // kJ/degC (effective whole-core)
    static let coolantHeatCapacity: Double = 600.0    // kJ/degC (primary D2O in core)
    static let fuelToCoolantResistance: Double = 0.005 // degC/kW at rated flow
    static let coolantToSGResistance: Double = 0.008  // degC/kW at rated conditions

    // --- Primary Loop ---
    static let primaryPumps: Int = 4
    static let pumpRatedRPM: Double = 1500.0
    static let pumpRatedFlow: Double = 2150.0         // kg/s per pump
    static let totalRatedFlow: Double = 8600.0        // kg/s total
    static let pumpMotorPower: Double = 5.6           // MW per pump
    static let pumpCoastdownTau: Double = 30.0        // seconds
    static let primaryPressureRated: Double = 10.0    // MPa
    static let primaryPressureCoeff: Double = 0.02    // MPa/degC thermal expansion
    static let primaryTempRatedInlet: Double = 265.0  // degC
    static let primaryTempRatedOutlet: Double = 310.0 // degC

    // --- Secondary Loop ---
    static let steamPressureRated: Double = 4.7       // MPa
    static let steamTempRated: Double = 260.0         // degC (saturation at 4.7 MPa)
    static let steamFlowRated: Double = 1040.0        // kg/s total
    static let feedwaterTempRated: Double = 187.0     // degC
    static let sgLevelNominal: Double = 50.0          // % of range
    static let sgCount: Int = 4
    static let turbineRatedRPM: Double = 1800.0       // RPM for 60 Hz
    static let turbineEfficiency: Double = 0.34       // overall cycle efficiency
    static let condenserPressureRated: Double = 0.005 // MPa (~5 kPa)
    static let condenserTempRated: Double = 33.0      // degC
    static let sgUA: Double = 12000.0                 // kW/degC (effective UA for all 4 SGs)

    // --- Tertiary Loop ---
    static let coolingWaterInletTemp: Double = 18.0   // degC (lake/river)
    static let coolingWaterFlowRated: Double = 40000.0 // kg/s (~40 m^3/s)
    static let coolingWaterPumpPower: Double = 3.5    // MW per pump
    static let coolingWaterPumps: Int = 2

    // --- Electrical ---
    static let generatorEfficiency: Double = 0.985    // electrical efficiency
    static let generatorPoles: Int = 4
    static let stationServiceBase: Double = 70.0      // MW base load
    static let dieselPower: Double = 5.0              // MW each
    static let dieselStartTime: Double = 180.0        // seconds (3 minutes)

    // --- Xenon/Iodine ---
    // Iodine-135 yield from fission
    static let gammaIodine: Double = 0.061            // fractional yield
    // Xenon-135 yield from fission (direct)
    static let gammaXenon: Double = 0.003             // fractional yield
    // Iodine-135 decay constant
    static let lambdaIodine: Double = 2.87e-5         // 1/s (T_1/2 ~ 6.7 hr)
    // Xenon-135 decay constant
    static let lambdaXenon: Double = 2.09e-5          // 1/s (T_1/2 ~ 9.2 hr)
    // Xenon-135 microscopic absorption cross section * flux scaling
    static let sigmaXenonPhi: Double = 3.0e-5         // 1/s per unit neutron density
    // Xenon reactivity coefficient (mk per unit xenon concentration)
    static let xenonReactivityCoeff: Double = -28.0    // mk at equilibrium full power

    // --- Safety ---
    static let scramInsertionTime: Double = 2.0       // seconds for full shutoff rod insertion
    static let fuelMeltTemp: Double = 2840.0          // degC (UO2 melting point)
}

// MARK: - Sub-State Types

struct PumpState {
    var rpm: Double
    var running: Bool
    var tripped: Bool
    var tripTime: Double // time at which pump was tripped

    static func off() -> PumpState {
        PumpState(rpm: 0.0, running: false, tripped: false, tripTime: 0.0)
    }

    static func atRated() -> PumpState {
        PumpState(rpm: CANDUConstants.pumpRatedRPM, running: true, tripped: false, tripTime: 0.0)
    }
}

struct FeedPumpState {
    var running: Bool
    var flowRate: Double // kg/s

    static func off() -> FeedPumpState {
        FeedPumpState(running: false, flowRate: 0.0)
    }
}

struct DieselGeneratorState {
    var running: Bool
    var loaded: Bool
    var power: Double      // MW currently producing
    var startTime: Double  // game-time when start was commanded; -1 if not started
    var available: Bool    // true once warmup is complete

    static func off() -> DieselGeneratorState {
        DieselGeneratorState(running: false, loaded: false, power: 0.0, startTime: -1.0, available: false)
    }
}

struct Alarm: Equatable {
    let time: Double
    let message: String
    var acknowledged: Bool

    static func == (lhs: Alarm, rhs: Alarm) -> Bool {
        return lhs.time == rhs.time && lhs.message == rhs.message
    }
}

// MARK: - Reactor State

final class ReactorState {

    // --- Neutronics ---
    var neutronDensity: Double = 1e-8
    var precursorConcentrations: [Double] = Array(repeating: 0.0, count: 6)

    // --- Reactivity (mk) ---
    var totalReactivity: Double = 0.0
    var rodReactivity: Double = 0.0
    var feedbackReactivity: Double = 0.0
    var xenonReactivity: Double = 0.0

    // --- Control Devices ---
    // Adjuster rods: 4 banks, position 0 (fully inserted) to 1 (fully withdrawn)
    var adjusterPositions: [Double] = [0.0, 0.0, 0.0, 0.0]
    // Zone controllers: 6 zones, fill level 0-100%
    var zoneControllerFills: [Double] = [100.0, 100.0, 100.0, 100.0, 100.0, 100.0]
    // Mechanical Control Absorbers: 2, position 0 (fully inserted) to 1 (fully withdrawn)
    var mcaPositions: [Double] = [0.0, 0.0]
    // Shutoff rods: true = inserted (safe), false = withdrawn
    var shutoffRodsInserted: Bool = true
    var shutoffRodInsertionFraction: Double = 1.0 // 1.0 = fully inserted

    // --- Fuel Temperatures ---
    var fuelTemp: Double = 25.0
    var claddingTemp: Double = 25.0

    // --- Primary Loop ---
    var primaryInletTemp: Double = 25.0
    var primaryOutletTemp: Double = 25.0
    var primaryPressure: Double = 0.1 // MPa (atmospheric when cold)
    var primaryFlowRate: Double = 0.0 // kg/s
    var primaryPumps: [PumpState] = [.off(), .off(), .off(), .off()]

    // --- Secondary Loop ---
    var steamPressure: Double = 0.1    // MPa
    var steamTemp: Double = 25.0       // degC
    var steamFlow: Double = 0.0        // kg/s
    var feedwaterTemp: Double = 25.0   // degC
    var sgLevels: [Double] = [50.0, 50.0, 50.0, 50.0] // %
    var condenserPressure: Double = 0.1 // MPa
    var condenserTemp: Double = 25.0    // degC
    var turbineGovernor: Double = 0.0   // 0-1
    var turbineRPM: Double = 0.0
    var feedPumps: [FeedPumpState] = [.off(), .off(), .off()]

    // --- Tertiary Loop ---
    var coolingWaterInletTemp: Double = 18.0
    var coolingWaterOutletTemp: Double = 18.0
    var coolingWaterFlow: Double = 0.0 // kg/s
    var coolingWaterPumps: [PumpState] = [.off(), .off()]

    // --- Electrical ---
    var grossPower: Double = 0.0          // MW_e
    var netPower: Double = 0.0            // MW_e
    var stationServiceLoad: Double = 70.0 // MW_e
    var generatorFrequency: Double = 0.0  // Hz
    var generatorConnected: Bool = false
    var dieselGenerators: [DieselGeneratorState] = [.off(), .off()]

    // --- Xenon / Iodine ---
    var xenonConcentration: Double = 0.0
    var iodineConcentration: Double = 0.0
    // xenonReactivity is already declared above in Reactivity section

    // --- Safety ---
    var scramActive: Bool = false
    var scramTime: Double = -1.0
    var alarms: [Alarm] = []

    // --- Game ---
    var elapsedTime: Double = 0.0
    var timeAcceleration: Int = 1
    var currentOrder: String = "COMMENCE REACTOR STARTUP"

    // --- Thermal Power ---
    var thermalPower: Double = 0.0       // MW_th
    var thermalPowerFraction: Double = 0.0 // fraction of rated (0-1+)

    // --- Decay Heat Tracking ---
    var decayHeatPower: Double = 0.0     // MW_th from decay
    var lastFullPowerTime: Double = -1.0 // game-time when reactor was last at significant power
    var shutdownTime: Double = -1.0      // game-time of shutdown/scram

    // --- Moderator ---
    var moderatorCirculating: Bool = false
    var heavyWaterInventory: Double = 100.0 // percent of nominal

    // MARK: - Cold Shutdown Factory

    static func coldShutdown() -> ReactorState {
        let state = ReactorState()
        // Neutronics at deeply subcritical source level
        state.neutronDensity = 1e-8
        // Equilibrium precursor concentrations at source level
        for i in 0..<6 {
            let group = CANDUConstants.delayedGroups[i]
            state.precursorConcentrations[i] = (group.beta / (CANDUConstants.promptNeutronLifetime * group.lambda)) * state.neutronDensity
        }

        // Reactivity - deeply subcritical with all rods in
        state.totalReactivity = 0.0
        state.rodReactivity = 0.0
        state.feedbackReactivity = 0.0
        state.xenonReactivity = 0.0

        // Control devices - all safe
        state.adjusterPositions = [0.0, 0.0, 0.0, 0.0]
        state.zoneControllerFills = [100.0, 100.0, 100.0, 100.0, 100.0, 100.0]
        state.mcaPositions = [0.0, 0.0]
        state.shutoffRodsInserted = true
        state.shutoffRodInsertionFraction = 1.0

        // All temperatures at ambient
        state.fuelTemp = 25.0
        state.claddingTemp = 25.0
        state.primaryInletTemp = 25.0
        state.primaryOutletTemp = 25.0
        state.primaryPressure = 0.1
        state.primaryFlowRate = 0.0
        state.primaryPumps = [.off(), .off(), .off(), .off()]

        state.steamPressure = 0.1
        state.steamTemp = 25.0
        state.steamFlow = 0.0
        state.feedwaterTemp = 25.0
        state.sgLevels = [50.0, 50.0, 50.0, 50.0]
        state.condenserPressure = 0.1
        state.condenserTemp = 25.0
        state.turbineGovernor = 0.0
        state.turbineRPM = 0.0
        state.feedPumps = [.off(), .off(), .off()]

        state.coolingWaterInletTemp = CANDUConstants.coolingWaterInletTemp
        state.coolingWaterOutletTemp = CANDUConstants.coolingWaterInletTemp
        state.coolingWaterFlow = 0.0
        state.coolingWaterPumps = [.off(), .off()]

        state.grossPower = 0.0
        state.netPower = 0.0
        state.stationServiceLoad = CANDUConstants.stationServiceBase
        state.generatorFrequency = 0.0
        state.generatorConnected = false
        state.dieselGenerators = [.off(), .off()]

        state.xenonConcentration = 0.0
        state.iodineConcentration = 0.0

        state.scramActive = false
        state.scramTime = -1.0
        state.alarms = []

        state.elapsedTime = 0.0
        state.timeAcceleration = 1
        state.currentOrder = "REPORT TO CONTROL ROOM"

        state.thermalPower = 0.0
        state.thermalPowerFraction = 0.0
        state.decayHeatPower = 0.0
        state.lastFullPowerTime = -1.0
        state.shutdownTime = -1.0

        state.moderatorCirculating = false
        state.heavyWaterInventory = 100.0

        return state
    }
}
