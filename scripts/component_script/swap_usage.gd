extends Node

@onready var swap_bar = $TextureProgressBar
@onready var swap_label = $TextureProgressBar/Label

func _ready():
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_update_swap)
	add_child(timer)

func _update_swap():
	var result := []
	var status = OS.execute("bash", ["-c", "free | grep Swap"], result)
	if status == 0 and result.size() > 0:
		var parts = result[0].strip_edges().split(" ", false)
		var clean_parts := []
		for p in parts:
			if p != "":
				clean_parts.append(p)
		if clean_parts.size() >= 3:
			var total = float(clean_parts[1])
			var used = float(clean_parts[2])
			if total > 0:
				var percent = (used / total) * 100.0
				swap_bar.value = percent
				swap_label.text = str("%.1f" % percent) + " %"
