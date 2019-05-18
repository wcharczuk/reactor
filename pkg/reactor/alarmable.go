package reactor

// Alarmable is a type that can contribute alarms.
type Alarmable interface {
	Alarms() []Alarm
}
