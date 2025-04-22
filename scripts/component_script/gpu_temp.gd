extends Control
@onready var settings = $box_temp/CenterContainer/Label.label_settings

func _update_temp_color(temp: int):
	if temp < 50:
		settings.font_color = Color.RED
	elif temp < 70:
		settings.font_color = Color.ORANGE
	else:
		settings.font_color = Color.RED

@onready var temp_label = $box_temp/CenterContainer/Label

func _ready():
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_update_temp)
	add_child(timer)

func _update_temp():
	var result := []
	var status = OS.execute("bash", ["-c", "sensors | grep 'edge' | head -n1 | grep -o '[0-9]\\{2,\\}'"], result)

	if status == 0 and result.size() > 0:
		var temp = int(result[0].strip_edges())
		temp_label.text = str(temp) + "°"

		if temp < 50:
			temp_label.add_theme_color_override("font_color", Color.RED)
		elif temp < 70:
			temp_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			temp_label.add_theme_color_override("font_color", Color.RED)
