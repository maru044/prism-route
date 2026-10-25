extends RefCounted
## Shared accepted B defaults for the small grove and the streamed world.
const TRANSITION_SECONDS := 3.0
const CYCLE_SECONDS := 24.0
const DEFAULT_PARAMETERS := {
	"frequency": 2.1, "min_angle": 45.0, "max_angle": 85.0, "event_interval": 4.2,
	"press": 0.22, "hold": 0.12, "release": 0.46, "rebound": 0.20,
	"body_hz": 0.85, "tip_hz": 2.4, "tip_angle": 4.0, "tip_lag": 0.045,
}

static func apply(material: ShaderMaterial, parameters: Dictionary, motion: int = 2) -> void:
	material.set_shader_parameter("gust_motion", motion)
	material.set_shader_parameter("gust_sway_hz", parameters.frequency)
	material.set_shader_parameter("gust_event_interval", parameters.event_interval)
	material.set_shader_parameter("gust_min_angle", deg_to_rad(parameters.min_angle))
	material.set_shader_parameter("gust_max_angle", deg_to_rad(maxf(parameters.min_angle, parameters.max_angle)))
	material.set_shader_parameter("gust_stages", Vector4(parameters.press, parameters.hold, parameters.release, parameters.rebound))
	material.set_shader_parameter("gust_body_hz", parameters.body_hz)
	material.set_shader_parameter("gust_tip_hz", parameters.tip_hz)
	material.set_shader_parameter("gust_tip_amplitude", deg_to_rad(parameters.tip_angle))
	material.set_shader_parameter("gust_tip_lag", parameters.tip_lag)

static func quintic_ease(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x*x*x*(x*(x*6.0-15.0)+10.0)

static func loaded_angle(clock: float, p: Dictionary) -> float:
	var hz: float = p.body_hz
	var stages := Vector4(p.press,p.hold,p.release,p.rebound)
	stages /= stages.x+stages.y+stages.z+stages.w
	var interval := maxf(p.event_interval, 2.0/hz)
	var event := floori(clock/interval)
	var seed := float((event*1664525+1013904223)&65535)/65535.0
	var phase := (clock-event*interval-interval*(0.25+seed*0.15))*hz
	var pressure := 1.0
	if phase>=0.0 and phase<1.0:
		if phase<stages.z:pressure=lerpf(1.0,0.28,quintic_ease(phase/stages.z))
		elif phase<stages.z+stages.w:pressure=lerpf(0.28,0.0,quintic_ease((phase-stages.z)/stages.w))
		elif phase<stages.z+stages.w+stages.x:pressure=quintic_ease((phase-stages.z-stages.w)/stages.x)
	return deg_to_rad(lerpf(p.min_angle,p.max_angle,pressure*(0.98+0.02*sin(clock*0.73))))

static func tip_angle(clock: float, u: float, p: Dictionary) -> float:
	var weight := smoothstep(0.35,1.0,u)
	var phase: float = TAU*p.tip_hz*(clock-p.tip_lag*u)
	return deg_to_rad(p.tip_angle)*weight*weight*(sin(phase)+0.15*sin(phase*1.7))/1.15

static func update_shared_curve(material: ShaderMaterial, clock: float, p: Dictionary = DEFAULT_PARAMETERS) -> void:
	var body := loaded_angle(clock,p)
	var forward := Vector4.ZERO
	var up := Vector4.ZERO
	var normal_forward := Vector4.ZERO
	var normal_up := Vector4.ONE
	var center := Vector2.ZERO
	for row in 4:
		var u := float(row+1)*0.25
		var middle := u-0.125
		var tangent := body*middle+tip_angle(clock,middle,p)
		center += Vector2(sin(tangent),cos(tangent))*0.25
		forward[row]=center.x;up[row]=center.y
		var angle := body*u+tip_angle(clock,u,p)
		var normal := Vector2(0.55*sin(angle),0.45+0.55*cos(angle)).normalized()
		normal_forward[row]=normal.x;normal_up[row]=normal.y
	material.set_shader_parameter("gust_curve_forward",forward)
	material.set_shader_parameter("gust_curve_up",up)
	material.set_shader_parameter("gust_curve_normal_forward",normal_forward)
	material.set_shader_parameter("gust_curve_normal_up",normal_up)
