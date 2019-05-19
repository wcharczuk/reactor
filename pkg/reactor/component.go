package reactor

// NewComponent returns a new component.
func NewComponent(cfg Config) *Component {
	return &Component{
		Config: cfg,
	}
}

// Component is the base component type.
type Component struct {
	Config
}
