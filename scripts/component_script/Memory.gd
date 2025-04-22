extends Node

@onready var ram_bar = $TextureProgressBar
@onready var ram_label = $TextureProgressBar/Label

func _ready():
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_update_ram)
	add_child(timer)

func _update_ram():
	var result := []
	var status = OS.execute("bash", ["-c", "free | grep Mem"], result)
	if status == 0 and result.size() > 0:
		var parts = result[0].strip_edges().split(" ", false)
		var clean_parts := []
		for p in parts:
			if p != "":
				clean_parts.append(p)
		if clean_parts.size() >= 3:
			var total = float(clean_parts[1])
			var used = float(clean_parts[2])
			var percent = (used / total) * 100.0
			ram_bar.value = percent
			ram_label.text = str("%.1f" % percent) + " %"
