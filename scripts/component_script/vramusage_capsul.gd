extends Control
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
	return "/sys/class/drm/card0" # fallback

# UI nodes
@onready var mem_freq_info = $Panel/memory_freq/m_freq
@onready var gpu_freq_info = $Panel/GPU_freq/G_freq
@onready var power_info = $Panel/power_gpu/P_usage

@onready var vram_bar = $TextureProgressBar/capsul_progress/TextureProgressBar
@onready var vram_label = $TextureProgressBar/capsul_progress/Label2

func _ready():
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_update_gpu_info)
	add_child(timer)

func _update_gpu_info():
	_update_vram()
	_update_gpu_freq()
	_update_mem_freq()
	_update_power()

# ✅ VRAM USAGE
func _update_vram():
	var result := []
	var status = OS.execute("bash", ["-c", "cat /sys/class/drm/card0/device/mem_info_vram_used"], result)
	var result2 := []
	var status2 = OS.execute("bash", ["-c", "cat /sys/class/drm/card0/device/mem_info_vram_total"], result2)

	if status == 0 and status2 == 0 and result.size() > 0 and result2.size() > 0:
		var used = float(result[0].strip_edges())
		var total = float(result2[0].strip_edges())
		if total > 0:
			var percent = (used / total) * 100.0
			vram_bar.value = percent
			vram_label.text = str("%.1f" % percent) + " %"

# ✅ GPU FREQ
func _update_gpu_freq():
	var result := []
	var status = OS.execute("bash", ["-c", "cat /sys/class/drm/card0/device/pp_dpm_sclk | grep '*'"], result)
	if status == 0 and result.size() > 0:
		var line = result[0].strip_edges()
		# مثلا خروجی: "7: 1350Mhz *"
		var parts = line.split(" ")
		for p in parts:
			if p.ends_with("Mhz"):
				gpu_freq_info.text = p
				break

# ✅ MEMORY FREQ (ممکنه نیاز به radeontop یا sensors داشته باشه)
func _update_mem_freq():
	var result := []
	var status = OS.execute("bash", ["-c", "cat /sys/class/drm/card0/device/pp_dpm_mclk | grep '*'"], result)
	if status == 0 and result.size() > 0:
		var line = result[0].strip_edges()
		var parts = line.split(" ")
		for p in parts:
			if p.ends_with("Mhz"):
				mem_freq_info.text = p
				break

# ✅ POWER USAGE
func _update_power():
	var result := []
	var status = OS.execute("bash", ["-c", "cat /sys/class/drm/card0/device/hwmon/hwmon*/power1_average"], result)
	if status == 0 and result.size() > 0:
		var mwatts = float(result[0].strip_edges())
		var watts = mwatts / 1000000.0
		power_info.text = str("%.1f" % watts) + " W"
