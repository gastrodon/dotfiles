// Package create carries a Create-mod cheat sheet: block-state axes
// for common kinetic blocks and (rough) stress impact/capacity values.
//
// Values track Create 6.x on Minecraft 1.21.1; treat as advisory, not
// canonical — the mod's own datapack is authoritative for a given
// modpack because packs override stress. When Create datapack overrides
// are read from a live pack, prefer those.
package create

// KineticAxis is the state key controlling a kinetic block's rotation axis.
const KineticAxis = "axis"

// Axis values for kinetic blocks.
const (
	AxisX = "x"
	AxisY = "y"
	AxisZ = "z"
)

// Stress is the stress metadata for one block id.
type Stress struct {
	// Impact is stress units consumed at base RPM.
	Impact float64
	// Capacity is stress units provided at base RPM (0 for consumers).
	Capacity float64
}

// Default is a subset of Create 6.x stress values (base RPM).
// Extend as needed; the map is intentionally sparse.
var Default = map[string]Stress{
	"create:water_wheel":            {Capacity: 256},
	"create:large_water_wheel":      {Capacity: 1024},
	"create:windmill_bearing":       {Capacity: 512}, // per sail cluster; approximate
	"create:creative_motor":         {Capacity: 16384},
	"create:hand_crank":             {Capacity: 32},
	"create:mechanical_press":       {Impact: 8},
	"create:mechanical_mixer":       {Impact: 4},
	"create:mechanical_crafter":     {Impact: 2},
	"create:mechanical_saw":         {Impact: 4},
	"create:mechanical_drill":       {Impact: 4},
	"create:millstone":              {Impact: 4},
	"create:crushing_wheel":         {Impact: 8},
	"create:mechanical_bearing":     {Impact: 4},
	"create:rope_pulley":            {Impact: 4},
	"create:mechanical_piston":      {Impact: 4},
	"create:deployer":               {Impact: 2},
	"create:mechanical_belt":        {Impact: 1},
	"create:cogwheel":               {Impact: 0},
	"create:large_cogwheel":         {Impact: 0},
	"create:encased_chain_drive":    {Impact: 0},
	"create:mechanical_pump":        {Impact: 4},
	"create:portable_storage_iface": {Impact: 4},
}
