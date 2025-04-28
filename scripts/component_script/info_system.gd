extends Control

@onready var label_cpu  = $fetch_box/GridContainer/VBoxContainer_left/cpu_name
@onready var label_c_arch = $fetch_box/GridContainer/VBoxContainer_left/cpu_arch
@onready var label_c_freq = $fetch_box/GridContainer/VBoxContainer_left/cpu_freq
@onready var label_board  = $fetch_box/GridContainer/VBoxContainer_left/mb_name

@onready var label_gpu  = $fetch_box/GridContainer/VBoxContainer_left/gpu_model
@onready var label_gpu_arch  = $fetch_box/GridContainer/VBoxContainer_left/gpu_arch
@onready var label_gpu_freq  = $fetch_box/GridContainer/VBoxContainer_left/gpu_freq

func _ready():
	# CPU info
	label_cpu.text = get_cmd("lscpu | grep 'Model name' | cut -d ':' -f2")
	label_c_arch.text = get_cmd("lscpu | grep 'Architecture' | cut -d ':' -f2")
	label_c_freq.text = get_cmd("lscpu | grep 'CPU max MHz' | cut -d ':' -f2") + " MHz"
	label_board.text = get_cmd("cat /sys/devices/virtual/dmi/id/board_name")

	# GPU info (AMD ROCm via JSON)
	var gpu_info = get_rocm_gpu_info_json("0")
	label_gpu.text = gpu_info.get("Subsystem ID", "Unknown")
	label_gpu_arch.text = gpu_info.get("GFX Version", "Unknown")
	label_gpu_freq.text = get_rocm_gpu_freq()


func get_cmd(cmd: String) -> String:
	var out := []
	var status = OS.execute("bash", ["-c", cmd], out)
	if status == 0 and out.size() > 0:
		return out[0].strip_edges()
	return "?"

func get_rocm_gpu_info_json(gpu_index := "0") -> Dictionary:
	var path := "/tmp/rocm_gpu_info.json"
	var cmd := "/opt/rocm/bin/rocm-smi --showproductname --json > " + path
	var result = OS.execute("bash", ["-c", cmd])
	if result != 0:
		return {}

	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(content)
			if typeof(parsed) == TYPE_DICTIONARY:
				return parsed.get("card", {}).get(gpu_index, {})
	return {}

func get_rocm_gpu_freq() -> String:
	var out := []
	var status = OS.execute("/opt/rocm/bin/rocm-smi", ["--showclocks"], out)
	if status == 0 and out.size() > 0:
		for line in out:
			if line.find("GPU") != -1 and line.find("MHz") != -1:
				return line.strip_edges()
	return "?"
