reactor
=======

We're going to build a game that is simulating operating a fictional nuclear reactor.

# Reactor components

Please research each component for the specific properties of the component.

The components we should simulate

- The core itself including fuel, cooling channels, control rods, the rate of reaction
- Primary (D2O) cooling loop including pumps and heat exchangers
- Secondary (H2O) cooling loop including pumps, condensers, the turbine
- Tertiary (H2O) cooling loop to cool the steam in the condenser
- Turbine output
- Auxiliary generators to power pumps

We should try and simulate these systems faithfully, using real temperature and pressure ranges, real power consumption of components like pumps, real output of components like the heat produced by the reactor given some medium sized amount of unenriched uranium fuel. Note that some systems require power, and require us to prime the auxiliary generator to e.g. begin pumping water. If you do not pump water, and retract control rods, this should create a failure condition fairly quickly (be realistic about timelines here).

# Game loop itself

The game loop, the task a human player must take on, is to start the reactor from cold and bring it to a specific power level as determined by orders.

# Game display and user interface

The game itself should be a 3D program that shows a simulated computer screen with a fixed resolution in the form of an 80s computer terminal. The player should see hte outline of the screen as a beige CRT monitor, simulating the curved (green tinted) tty display at some moderately large resolution like 320 columns and 96 rows. The controls on the monitor itself should be rendered using a TUI interface.

There should be two consistent controls always shown. A CLI input for commands to control the reactor taking up the bottom of the screen, and a status and messages panel taking up the vertical height of the screen on the left to show alarms and other condition messages about the reactor. When power level orders are recieved, a persistent message should be pinned to the top of the status screen, only being removed if a contravening order is generated to e.g. shut down the reactor safely.

Users should enter commands into a commandline with intellisense helpers to control the various aspects of the nuclear power plant, that is we should show help text for possible command completions and expected values.

The commands should be in the form of `<verb> <noun> <?value>` where e.g. `set primary-loop.pump.*.rpm 1600` would set all the primary loop pumps rpms to 1600 (e.g. we have a way to glob match specific systems). 

A special command is `scram` which fully inserts the control rods and stops the reactor.

The terminal should display relevant aspects of the entire system (reaction rate as measured by thermal output, power generation by electrical output by the turbine), and should have a mechanism to select individual components to see detailed data on e.g. the primary cooling loop (the temperature at various relevant positions, the pressure at various relevant positons, alarm statuses for pressures or temperatures at various positions). 

# Technologies used

Use your judgement but this should be a native macos application that renders the "virtual terminal" in 3d and simulates the retro nature of the terminal. 
