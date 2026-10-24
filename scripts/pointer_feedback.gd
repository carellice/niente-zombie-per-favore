extends CanvasLayer
## A light painted tap ripple. It observes input before GUI handling, never consumes it.

signal pulse_started(position: Vector2)

const LIFETIME: float = 0.42
const MAX_PULSES: int = 16

var surface: Surface
var effect_count: int:
	get:
		return surface.pulses.size() if is_instance_valid(surface) else 0

class Surface extends Control:
	var pulses: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func advance(delta: float) -> void:
		for index: int in range(pulses.size() - 1, -1, -1):
			pulses[index].age += delta
			if float(pulses[index].age) >= LIFETIME:
				pulses.remove_at(index)
		queue_redraw()

	func _draw() -> void:
		var scale_factor: float = clampf(get_viewport_rect().size.x / 1440.0, 0.8, 1.3)
		for pulse: Dictionary in pulses:
			var progress: float = clampf(float(pulse.age) / LIFETIME, 0.0, 1.0)
			var expansion: float = 1.0 - pow(1.0 - progress, 3.0)
			var opacity: float = pow(1.0 - progress, 1.25)
			var center: Vector2 = pulse.position
			var radius: float = lerpf(4.0, 24.0, expansion) * scale_factor
			# A soft brown edge keeps the cream readable on both sky and paper panels.
			draw_arc(center, radius, 0.0, TAU, 48, Color(0.30, 0.23, 0.14, 0.16 * opacity), 4.2 * scale_factor, true)
			draw_arc(center, radius, 0.0, TAU, 48, Color(1.0, 0.94, 0.79, 0.90 * opacity), 1.9 * scale_factor, true)
			draw_arc(center, radius * 0.68, 0.0, TAU, 40, Color(0.75, 0.63, 0.35, 0.63 * opacity), 1.25 * scale_factor, true)
			draw_circle(center, (3.6 - 2.0 * expansion) * scale_factor, Color(1.0, 0.94, 0.79, 0.50 * opacity), true, -1, true)
			for dot: int in range(4):
				var angle: float = PI * 0.25 + float(dot) * PI * 0.5
				var point: Vector2 = center + Vector2.from_angle(angle) * (radius + 4.0 * scale_factor)
				var tint: Color = Color(0.58, 0.69, 0.43, 0.68 * opacity) if dot % 2 == 0 else Color(0.96, 0.77, 0.42, 0.80 * opacity)
				draw_circle(point, lerpf(2.0, 0.9, progress) * scale_factor, tint, true, -1, true)

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

func _ready() -> void:
	surface = Surface.new()
	surface.name = "ClickRipples"
	add_child(surface)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Godot also emits a mouse event for touch when emulation is enabled.
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
			add_pulse(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		add_pulse(event.position)

func _process(delta: float) -> void:
	if is_instance_valid(surface) and not surface.pulses.is_empty():
		surface.advance(delta)

func add_pulse(position: Vector2) -> void:
	if not is_instance_valid(surface):
		return
	if surface.pulses.size() >= MAX_PULSES:
		surface.pulses.pop_front()
	surface.pulses.append({"position": position, "age": 0.0})
	surface.queue_redraw()
	pulse_started.emit(position)
