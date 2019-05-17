package reactor

import "time"

// NewReactor returns a new reactor.
func NewReactor() *Reactor {
	return &Reactor{
		CoreTemperature:        BaseTemperature,
		ContainmentTemperature: BaseTemperature,
		ControlRods: []*ControlRod{
			NewControlRod(),
			NewControlRod(),
			NewControlRod(),
			NewControlRod(),
			NewControlRod(),
		},
		Primary:   NewPump(),
		Secondary: NewPump(),
		Turbine:   NewTurbine(),
	}
}

// Reactor is the main simulated object.
type Reactor struct {
	Alarm bool

	ContainmentTemperature float64
	CoreTemperature        float64

	ControlRods []*ControlRod
	Primary     *Pump
	Secondary   *Pump
	Turbine     *Turbine
}

// Simulate advances the simulation by the quantum.
func (r *Reactor) Simulate(quantum time.Duration) error {
	var err error
	// do the output calculation

	// create core heat
	for _, cr := range r.ControlRods {
		if err = cr.Simulate(quantum); err != nil {
			return err
		}
		Transfer(&cr.Temperature, &r.CoreTemperature, quantum, SinkTransferRateMinute/float64(len(r.ControlRods)))
	}

	// transfer core heat to primary inlet
	Transfer(&r.CoreTemperature, &r.Primary.InletTemperature, quantum, SinkTransferRateMinute)
	Transfer(&r.CoreTemperature, &r.ContainmentTemperature, quantum, ContainmentTransferRateMinute)

	// transfer primary inlet to outlet based on speed
	r.Primary.Simulate(quantum)

	// transfer primary outlet to secondary inlet
	Transfer(&r.Primary.OutletTemperature, &r.Secondary.InletTemperature, quantum, SinkTransferRateMinute)

	// transfer secondary inlet to outlet based on speed
	r.Secondary.Simulate(quantum)

	// take heat out of the secondary outlet
	base := float64(BaseTemperature)
	Transfer(&r.Secondary.OutletTemperature, &base, quantum, SinkTransferRateMinute)

	// spin the turbine by the resulting base
	delta := base - BaseTemperature
	rate := (float64(quantum) / float64(time.Minute))
	accel := rate * TurbineOutputRateMinute * delta
	deccel := r.Turbine.SpeedRPM * 0.15 * rate

	r.Turbine.SpeedRPM = r.Turbine.SpeedRPM + accel
	r.Turbine.SpeedRPM = r.Turbine.SpeedRPM - deccel

	return nil
}
