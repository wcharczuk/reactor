# Reactor

A real-time CANDU-6 nuclear reactor simulator with a phosphor-green CRT terminal interface, built in Swift with Metal rendering.

![CANDU-6 Plant Overview](Assets/screenshot.png)

## What is this?

You operate a [CANDU-6](https://en.wikipedia.org/wiki/CANDU_reactor) pressurized heavy water reactor from cold shutdown to full power and back. Every major system is modeled: neutron kinetics with six delayed groups, xenon-135 transients, a two-node fuel/coolant thermal model, four-loop primary heat transport, steam generators, turbine-generator, electrical grid synchronization, and diesel backup power.

The interface is a 213x70 character-cell terminal rendered to a Metal texture with CRT post-processing (scanlines, phosphor glow, vignette) — modeled after real nuclear plant control room displays.

## Why it's interesting

- **The physics fight back.** Xenon-135 builds up after power changes and poisons the reactor over hours. You have to anticipate it and compensate with control rods, or watch your power slowly collapse. Recovering from a xenon pit after a trip is a real challenge.
- **Power management matters from the start.** You bootstrap on two 5 MW diesel generators. Pump motors follow a cube law — starting too many pumps at high RPM trips the diesels and blacks out the station. You learn to nurse the plant up on minimal flow.
- **Everything is coupled.** Lowering zone controller fill adds reactivity, which raises neutron flux, which raises fuel temperature, which feeds back through the Doppler coefficient to limit the excursion. Coolant temperature rises, pressure climbs, steam production increases, the turbine speeds up. One change propagates through every system.
- **The safety systems are real.** Automatic SCRAM on high neutron power, high log rate, low coolant pressure, low flow, low steam generator level, or high fuel temperature. Shutoff rods drop by gravity in under 2 seconds. You can trip the reactor by being too aggressive — or not aggressive enough.

## Controls

Commands follow a `verb noun value` pattern with tab completion:

```
set core.adjuster-rods.1.pos 0       # withdraw adjuster bank 1
set core.zone-controllers.*.fill 80   # set all zone fills to 80%
set primary.pump.*.rpm 1500           # ramp all primary pumps to rated
start aux.diesel.*                    # start both diesel generators
start electrical.grid.sync            # synchronize generator to grid
scram                                 # emergency shutdown
help startup                          # full startup procedure
```

Use `view` to switch between overview, core, primary, secondary, electrical, and alarms displays. `time 10` accelerates the simulation.

## Building

Requires Xcode on macOS.

```
xcodebuild -project Reactor/Reactor.xcodeproj -scheme Reactor -configuration Debug build
```

Or open `Reactor/Reactor.xcodeproj` in Xcode and run.
