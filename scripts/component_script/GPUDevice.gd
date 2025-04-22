extends Resource
class_name GPUDevice

## Represents a single GPU device in the system

## Emitted when GPU state is updated
signal state_updated()
## Emitted when GPU frequency changes
signal frequency_changed(clock_mhz: float)

var gpu_index: int
var device_path: String
var vendor: String
var model: String
var online: bool = true
var vram_total: int = 0
var logger := Log.get_logger("GPUDevice")

# Power management
var power_profile: String = "auto"
var power_dpm_state: String = "balanced"
var power_usage: float = 0.0

# Clock info
var current_frequency: float = 0.0
var max_frequency: float = 0.0
var memory_frequency: float = 0.0


func _init(index: int = 0) -> void:
	gpu_index = index
	device_path = "/sys/class/drm/card" + str(gpu_index)
	
	# Check if GPU exists
	if not DirAccess.dir_exists_absolute(device_path):
		logger.error("GPU device path does not exist: " + device_path)
		return
	
	# Get GPU info from lspci
	_update_gpu_info()
	
	# Initial update of stats
	update()


## Updates all GPU stats
func update() -> void:
	# Update clock speeds
	_update_frequencies()
	
	# Update power usage
	_update_power_usage()
	
	# Update VRAM info
	vram_total = get_vram_total()
	
	# Emit signal
	emit_signal("state_updated")


## Returns the amount of VRAM total in bytes
func get_vram_total() -> int:
	var path := device_path + "/device/mem_info_vram_total"
	if FileAccess.file_exists(path):
		var vram_str := _get_property(path).strip_edges()
		return vram_str.to_int()
	return 0


## Returns the amount of VRAM used in bytes
func get_vram_used() -> int:
	var path := device_path + "/device/mem_info_vram_used"
	if FileAccess.file_exists(path):
		var vram_str := _get_property(path).strip_edges()
		return vram_str.to_int()
	return 0


## Returns the GPU frequency in MHz
func get_current_frequency() -> float:
	return current_frequency


## Returns the memory frequency in MHz
func get_memory_frequency() -> float:
	return memory_frequency


## Returns the current power usage in watts
func get_power_usage() -> float:
	return power_usage


## Set the power profile for the GPU (auto, low, high, etc.)
func set_power_profile(profile: String) -> bool:
	var power_profile_path := device_path + "/device/power_dpm_force_performance_level"
	
	var valid_profiles := ["auto", "low", "high", "manual"]
	if not profile in valid_profiles:
		logger.error("Invalid power profile: " + profile)
		return false
	
	# Write the profile to the file
	var file := FileAccess.open(power_profile_path, FileAccess.WRITE)
	if not file:
		logger.error("Failed to open power profile file: " + power_profile_path)
		return false
	
	file.store_string(profile)
	file.close()
	
	# Update our stored value
	power_profile = profile
	emit_signal("power_profile_updated", profile)
	
	return true


func _update_gpu_info() -> void:
	var cmd := Command.create("lspci", ["-v"])
	if cmd.execute_blocking() != OK:
		return
	
	var output := cmd.stdout
	var lines := output.split("\n")
	
	for line in lines:
		if not "VGA" in line and not "Display" in line:
			continue
			
		if "NVIDIA" in line:
			vendor = "NVIDIA"
			model = _extract_gpu_model(line, "NVIDIA")
		elif "AMD" in line or "ATI" in line:
			vendor = "AMD"
			model = _extract_gpu_model(line, "AMD")
		elif "Intel" in line:
			vendor = "Intel" 
			model = _extract_gpu_model(line, "Intel")


func _update_frequencies() -> void:
	var old_freq := current_frequency
	
	# For AMD GPUs
	if vendor == "AMD":
		var sclk_path := device_path + "/device/pp_dpm_sclk"
		var mclk_path := device_path + "/device/pp_dpm_mclk"
		
		current_frequency = _get_amd_frequency(sclk_path)
		memory_frequency = _get_amd_frequency(mclk_path)
	
	# For NVIDIA GPUs (use nvidia-smi if available)
	elif vendor == "NVIDIA":
		var cmd := Command.create("nvidia-smi", ["--query-gpu=clocks.current.graphics,clocks.current.memory", "--format=csv,noheader,nounits"])
		if cmd.execute_blocking() == OK:
			var output := cmd.stdout.strip_edges()
			var parts := output.split(",")
			if parts.size() >= 2:
				current_frequency = float(parts[0].strip_edges())
				memory_frequency = float(parts[1].strip_edges())
	
	# For Intel GPUs (mostly integrated)
	elif vendor == "Intel":
		var freq_path := device_path + "/gt_cur_freq_mhz"
		if FileAccess.file_exists(freq_path):
			var freq_str := _get_property(freq_path).strip_edges()
			current_frequency = float(freq_str)
	
	# If frequency changed, emit signal
	if current_frequency != old_freq:
		emit_signal("frequency_changed", current_frequency)


func _update_power_usage() -> void:
	# For AMD GPUs
	if vendor == "AMD":
		# Try direct file access first (path varies by driver version)
		var hwmon_dirs := ["hwmon0", "hwmon1", "hwmon2", "hwmon3", "hwmon4"]
		for dir in hwmon_dirs:
			var power_path := device_path + "/device/hwmon/" + dir + "/power1_average"
			if FileAccess.file_exists(power_path):
				var power_str := _get_property(power_path).strip_edges()
				# Convert from microwatts to watts
				power_usage = float(power_str) / 1000000.0
				return
	
	# For NVIDIA GPUs
	elif vendor == "NVIDIA":
		var cmd := Command.create("nvidia-smi", ["--query-gpu=power.draw", "--format=csv,noheader,nounits"])
		if cmd.execute_blocking() == OK:
			var output := cmd.stdout.strip_edges()
			if output:
				power_usage = float(output)
				return


func _get_property(prop_path: String) -> String:
	if not FileAccess.file_exists(prop_path):
		return ""
	var file := FileAccess.open(prop_path, FileAccess.READ)
	var length := file.get_length()
	var bytes := file.get_buffer(length)

	return bytes.get_string_from_utf8()


func _get_amd_frequency(path: String) -> float:
	if not FileAccess.file_exists(path):
		return 0.0
		
	var content := _get_property(path)
	var lines := content.split("\n")
	
	# Look for the active frequency line (marked with *)
	for line in lines:
		if "*" in line:
			# Extract frequency value using regex
			var regex := RegEx.new()
			regex.compile("(\\d+)\\s*Mhz")
			var result := regex.search(line)
			if result:
				return float(result.get_string(1))
	
	return 0.0


func _extract_gpu_model(line: String, vendor_name: String) -> String:
	var start_idx := line.find(vendor_name)
	if start_idx == -1:
		return "Unknown"
	
	var end_idx := line.find("[")
	if end_idx == -1:
		end_idx = line.find("(")
	if end_idx == -1:
		end_idx = line.length()
	
	var model_str := line.substr(start_idx, end_idx - start_idx).strip_edges()
	
	# Remove vendor name if it's at the beginning
	if model_str.begins_with(vendor_name):
		model_str = model_str.substr(vendor_name.length()).strip_edges()
	
	# Remove Corporation/Technologies/etc.
	var common_words := ["Corporation", "Technologies", "Inc.", "Co.,Ltd"]
	for word in common_words:
		model_str = model_str.replace(word, "").strip_edges()
	
	return model_str


func _to_string() -> String:
	return "<GPUDevice:" \
		+ " index: (" + str(gpu_index) \
		+ ") Vendor: (" + str(vendor) \
		+ ") Model: (" + str(model) \
		+ ") VRAM: (" + str(vram_total / 1024 / 1024) + " MB" \
		+ ")>" 