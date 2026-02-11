# Reactor Simulator — Implementation Plan

## Overview

A native macOS game simulating a CANDU-6 style nuclear reactor, rendered as a 3D CRT monitor displaying a green-phosphor virtual terminal. The player starts from a cold reactor and must bring it to ordered power levels using text commands.

## Technology Stack

- **Language:** Swift
- **3D Rendering:** Metal + MetalKit (raw, not SceneKit/RealityKit)
- **App Shell:** SwiftUI with `NSViewRepresentable` wrapping a custom `MTKView`
- **Text Rendering:** CoreText/CoreGraphics drawing to a shared `MTLTexture`
- **CRT Effects:** Custom Metal fragment shader (barrel distortion, scanlines, phosphor glow, green tint, vignette)
- **Dependencies:** None external — Apple platform APIs only
- **Target:** macOS 14+ (Sonoma), Metal 3

---

## Project Structure

```
Reactor/
├── Reactor.xcodeproj          (generated via xcodegen from project.yml)
├── project.yml                (xcodegen spec)
├── Sources/
│   ├── App/
│   │   ├── ReactorApp.swift              # @main SwiftUI entry
│   │   ├── ContentView.swift             # NSViewRepresentable + GameController
│   │   └── GameMTKView.swift             # MTKView subclass (keyboard input)
│   ├── Renderer/
│   │   ├── Renderer.swift                # MTKViewDelegate, orchestrates 3 render passes
│   │   ├── ShaderTypes.h                 # Shared C structs (Swift ↔ Metal)
│   │   ├── BridgingHeader.h              # Bridging header
│   │   ├── SceneShaders.metal            # 3D scene vertex/fragment shaders
│   │   ├── CRTShader.metal               # CRT post-processing shader
│   │   ├── TerminalRenderer.swift        # Renders terminal buffer → texture via CoreGraphics
│   │   ├── SceneRenderer.swift           # Renders 3D monitor model + screen
│   │   └── MeshGenerator.swift           # Procedural CRT monitor bezel mesh
│   ├── Terminal/
│   │   ├── TerminalBuffer.swift          # 320×96 cell grid
│   │   ├── TerminalLayout.swift          # Layout manager (panels, views)
│   │   ├── CommandLine.swift             # Input line, history, cursor (class: TerminalCommandLine)
│   │   ├── CommandParser.swift           # Parses verb/noun/value
│   │   ├── CommandDispatcher.swift       # Routes commands to simulation
│   │   └── Intellisense.swift            # Tab completion, help text
│   └── Simulation/
│       ├── ReactorState.swift            # Complete state class + CANDUConstants
│       ├── Neutronics.swift              # Point kinetics (implicit Euler, 6 delayed groups)
│       ├── Reactivity.swift              # Feedback model, rod worth, xenon/iodine ODEs
│       ├── ThermalHydraulics.swift       # Fuel/coolant heat transfer
│       ├── PrimaryLoop.swift             # D2O loop, 4 pumps, pressure model
│       ├── SecondaryLoop.swift           # Steam generators, turbine, condenser, feed pumps
│       ├── TertiaryLoop.swift            # Cooling water
│       ├── Electrical.swift              # Generator, station service, grid connection
│       ├── AuxiliarySystems.swift        # Diesel generators, moderator system
│       ├── SafetySystem.swift            # SCRAM logic, alarm conditions, decay heat
│       ├── OrdersGenerator.swift         # Power level orders state machine
│       └── GameLoop.swift                # Fixed timestep, time acceleration, substep scheduling
└── Resources/
    └── Assets.xcassets
```

---

## Reactor Model (CANDU-6 Based)

### Core Parameters
| Parameter | Value |
|---|---|
| Type | CANDU-6 (pressurized heavy water) |
| Thermal power | 2064 MWth |
| Electrical output | ~660 MWe net (~728 MWe gross) |
| Fuel | Natural (unenriched) UO2 |
| Moderator | D2O (heavy water) |
| Prompt neutron lifetime | 0.9 ms |
| Delayed neutron fraction (beta) | 0.0065 |

### Control Devices
| Device | Worth | Player Control |
|---|---|---|
| Adjuster rods (4 banks) | ~15 mk total (3.75/bank) | set position 0.0–1.0 |
| Zone controllers (6 zones) | ±3 mk total | set fill 0–100% |
| Mechanical control absorbers (2) | ~10 mk total | set position 0.0–1.0 |
| Shutoff rods (SDS1) | >80 mk | SCRAM only |

### Primary Loop (D2O)
- Inlet 265°C / Outlet 310°C, Pressure 10.0 MPa
- 4 pumps × 5.6 MW each, 8600 kg/s total flow

### Secondary Loop (H2O)
- Steam 4.7 MPa / 260°C, 1040 kg/s
- 4 steam generators, turbine 1800 RPM (60 Hz), condenser 5 kPa

### Tertiary Loop (Cooling Water)
- ~40 m³/s, inlet 18°C, 2 pumps × 3.5 MW

### Electrical
- Station service ~70 MW, 2 diesel generators × 5 MW (3 min start)

### Safety Limits
- Max fuel centerline 2840°C (UO2 melt)
- SCRAM insertion < 2 seconds

---

## Simulation Engine

### Point Kinetics (6-group delayed neutrons)
```
dn/dt = ((rho - beta) / Lambda) * n + sum(lambda_i * C_i)
dC_i/dt = (beta_i / Lambda) * n - lambda_i * C_i
```
Solved with implicit Euler for unconditional stability.

### Reactivity Model
```
rho_total = rho_rods + rho_zone_controllers
          + alpha_fuel × (T_fuel - T_fuel_ref)       [Doppler: -0.014 mk/°C]
          + alpha_coolant × (T_coolant - T_cool_ref)  [+0.028 mk/°C]
          - rho_xenon
```
Rod worth uses S-curve: `rho(z) = rho_total × 0.5 × [z - sin(2πz)/(2π)]`

### Xe-135 / I-135 Dynamics
Two ODEs tracking concentrations. Equilibrium Xe worth ~28 mk. Peak after shutdown ~36 mk at ~11 hours.

### Thermal-Hydraulics (Lumped Parameter)
- Fuel node tau ~5–10s, coolant node tau ~15–20s
- SG: LMTD heat exchange model
- Pumps: affinity laws, coastdown on trip

### Decay Heat
`Q_decay = Q_rated × 0.066 × t^(-0.2)` (simplified ANS-5.1)

### Integration Schedule (per frame at 60 fps)
| Subsystem | Interval |
|---|---|
| Reactivity + Neutronics + Thermal | Every substep (16.7 ms) |
| Primary loop | Every 3 substeps (50 ms) |
| Secondary / Tertiary / Electrical | Every 6 substeps (100 ms) |
| Xenon / Iodine | Every 60 substeps (1 s) |

### Time Acceleration
1×, 2×, 5×, 10× — multiplies substeps per frame. SCRAM snaps back to 1×.

### Automatic SCRAM Triggers
- High neutron power > 103% FP
- High power rate > 10%/s
- Low primary pressure < 9.0 MPa / High > 11.5 MPa
- Low primary flow < 80% rated
- Low SG level (any < 20%)
- High fuel temperature > 2500°C
- Manual `scram` command

---

## Terminal Display (320 × 96 characters)

### Layout
```
┌────────────────────────────────────────────────────────────────────┐
│ STATUS/ALARMS (60 cols) │  MAIN DISPLAY AREA (258 cols)           │
│                         │                                          │
│ ┌─ ORDERS ────────────┐ │  (Shows current view: overview,         │
│ │ TARGET: 85% FP      │ │   or detail screen for a subsystem)     │
│ └─────────────────────┘ │                                          │
│                         │                                          │
│ ┌─ ALARMS ────────────┐ │                                          │
│ │ ▲ HIGH T_FUEL 12:03 │ │                                          │
│ └─────────────────────┘ │                                          │
│                         │                                          │
│ ┌─ KEY STATUS ────────┐ │                                          │
│ │ PWR:  45.2% FP      │ │                                          │
│ │ ROD:  ████░░░░ 52%  │ │                                          │
│ │ Xe:   12.3 mk       │ │                                          │
│ │ TIME: 1x 03:24:15   │ │                                          │
│ └─────────────────────┘ │                                          │
│                         ├──────────────────────────────────────────│
│                         │ COMMAND INPUT (258 cols × ~8 rows)       │
│                         │ > set adjuster-rods.bank-a.position 0    │
│                         │ Completions: ...                         │
└─────────────────────────┴──────────────────────────────────────────┘
```

### Views
- `view overview` — flow diagram with key numbers
- `view core` — fuel/cladding temps, rod positions, reactivity breakdown, Xe/I
- `view primary` — 4 pumps, headers, pressures, D2O flow
- `view secondary` — 4 SGs, feed pumps, condenser, turbine/governor
- `view electrical` — generator, station service, diesels, net power
- `view alarms` — full alarm log

### Command System
Format: `<verb> <noun-path> [value]`

**Verbs:** set, get, start, stop, scram, view, speed, status, help

**Noun paths** (dot-separated, glob with `*`):
```
core.adjuster-rods.bank-{a,b,c,d}.position   (0.0–1.0)
core.zone-controllers.zone-{1–6}.fill         (0–100%)
core.mca.{1,2}.position                       (0.0–1.0)
primary.pump.{1–4}.rpm                        (0–1500)
secondary.feed-pump.{1–3}.rpm
secondary.turbine.governor                     (0.0–1.0)
tertiary.pump.{1,2}.rpm
aux.diesel.{1,2}                              (via start/stop)
```

---

## Render Pipeline (3 passes)

1. **Terminal → Texture:** CoreGraphics/CoreText renders 320×96 chars into 2560×1536 `MTLTexture` (8×16 px/cell)
2. **CRT Post-Processing:** Fragment shader applies barrel distortion, scanlines, phosphor mask, green tint, bloom, vignette, flicker
3. **3D Scene:** Bezel frame + screen quad with CRT texture, PBR lighting

Current CRT settings: curvature 0.005, scanlines 0.15, glow 0.4, vignette 0.3.
Monitor mesh: flat bezel frame only (no 3D body — deferred for later polish).

---

## Game Flow

### Startup Sequence
1. Start diesel generators → wait ~3 min warmup
2. Start moderator circulation
3. Start primary loop pumps sequentially
4. Verify primary flow and temps
5. Withdraw adjuster rods slowly → reactor goes critical
6. Monitor power rise on delayed neutron timescale
7. Start secondary feed pumps, open turbine governor
8. Synchronize generator to grid
9. Ramp to ordered power level, managing xenon
10. Transfer station service from diesels to main generator

### Orders System
Orders arrive at intervals: "ACHIEVE 25% FULL POWER" → 50% → 75% → 85% → 100%.
Can also order reductions or shutdown.

### Failure Scenarios
- Rods out without coolant → fuel temp spike → auto-SCRAM (or melt)
- Loss of feedwater → SG dryout → primary overheat → SCRAM
- All pumps trip → loss of flow → SCRAM + decay heat
- Xenon-precluded restart after extended high-power operation

---

## Implementation Status

### Completed (Phase 1–6)
- [x] Xcode project with xcodegen, builds with 0 errors / 0 warnings
- [x] SwiftUI app shell with NSViewRepresentable wrapping GameMTKView
- [x] Metal render pipeline (3 passes: terminal texture → CRT shader → 3D scene)
- [x] CRT shader (barrel distortion, scanlines, phosphor mask, green tint, bloom, vignette, flicker)
- [x] Procedural monitor bezel mesh (simplified flat frame)
- [x] Terminal buffer (320×96 grid) with CoreGraphics text rendering to MTLTexture
- [x] Terminal layout with 6 views (overview, core, primary, secondary, electrical, alarms)
- [x] Left status panel (orders, alarms, key status)
- [x] Command input with cursor, history, tab completion
- [x] Command parser (verb/noun/value) and dispatcher with glob support
- [x] Intellisense with path registry
- [x] ReactorState with full CANDU-6 parameters (CANDUConstants)
- [x] Point kinetics (implicit Euler, 6 delayed neutron groups)
- [x] Reactivity model (S-curve rod worth, Doppler/coolant feedback, Xe/I dynamics)
- [x] Thermal hydraulics (lumped fuel/coolant nodes)
- [x] Primary loop (4 pumps with coastdown, pressure model)
- [x] Secondary loop (4 SGs with LMTD, turbine, condenser, 3 feed pumps)
- [x] Tertiary loop (cooling water, 2 pumps)
- [x] Electrical system (generator, station service, grid connection)
- [x] Auxiliary systems (diesel generators with warmup, moderator circulation)
- [x] Safety system (8 auto-SCRAM triggers, shutoff rod insertion, decay heat)
- [x] Orders generator (state machine ramping through power levels)
- [x] Game loop with fixed timestep and time acceleration (1×/2×/5×/10×)
- [x] Keyboard input handling in GameMTKView

### TODO / Polish
- [ ] Refine 3D monitor model (currently just a flat bezel frame — add body, stand later)
- [ ] Tune CRT shader parameters (curvature, glow, scanline look)
- [ ] Add retro bitmap font (currently using system Menlo)
- [ ] Generator synchronization logic (breaker close at correct frequency/phase)
- [ ] Sound effects (optional)
- [ ] Startup tutorial / guided walkthrough
- [ ] Save/load game state
- [ ] Fuel damage progression model (beyond just temp threshold)
- [ ] Thermosiphon natural circulation after pump trip
- [ ] More detailed moderator system simulation
- [ ] Power coefficient of reactivity (void coefficient)
- [ ] Verify simulation tuning against realistic CANDU-6 transient behavior
- [ ] Test all failure scenarios end-to-end

---

## Key Architecture Notes

- **ReactorState** is a `final class` (reference type), shared by GameLoop, CommandDispatcher, and TerminalLayout. All simulation modules take `state: ReactorState` (not `inout`).
- **TerminalLayout** uses static methods — no instance needed.
- **CommandParser** uses static `parse()` method.
- **GameLoop** owns the ReactorState and OrdersGenerator. Called once per frame via `update(dt:)`.
- **GameController** (in ContentView.swift) wires everything together: creates state, game loop, terminal, dispatcher, and connects keyboard input.
- **Renderer** holds references to TerminalBuffer and GameLoop. Each frame: updates game loop → renders terminal to texture → CRT shader → 3D scene.

## Build Instructions

```bash
cd Reactor
xcodegen generate        # regenerate .xcodeproj from project.yml
open Reactor.xcodeproj   # open in Xcode, hit Run
```

Or from command line:
```bash
xcodebuild -project Reactor.xcodeproj -scheme Reactor -destination 'platform=macOS' build
```
