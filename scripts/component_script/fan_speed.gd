extends Control

@onready var fan_icon = $Sprite2D
@onready var fan_speed_label = $Panel/FanSpeedLabel

var angle := 0.0

func _ready():
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_update_fan_speed)
	add_child(timer)

func _update_fan_speed():
	var card_path = get_active_gpu_card_path()
	var result := []
	var status = OS.execute("bash", ["-c", "cat " + card_path + "/device/hwmon/hwmon*/fan1_input"], result)

	if status == 0 and result.size() > 0:
		var rpm = int(result[0].strip_edges())
		fan_speed_label.text = str(rpm) + " RPM"

		var rotation_speed = clamp(rpm / 100.0, 1.0, 30.0)
		angle += rotation_speed
		fan_icon.rotation_degrees = fmod(angle, 360.0)

func get_active_gpu_card_path() -> String:
	var base_path = "/sys/class/drm/"
	var dir = DirAccess.open(base_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("card") and not file_name.contains("-"):
				var mem_path = base_path + file_name + "/device/mem_info_vram_total"
				if FileAccess.file_exists(mem_path):
					return base_path + file_name
			file_name = dir.get_next()
	return "/sys/class/drm/card0"  # fallback
