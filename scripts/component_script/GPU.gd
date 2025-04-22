extends Resource
class_name GPU

## Read and manage the system GPU

## Emitted when GPU power profile is updated
signal power_profile_updated(profile: String)
## Emitted when GPU frequency is updated
signal freq_updated(clock_mhz: float)

const GPU_SYS_PATH := "/sys/class/drm"

var gpu_count := get_total_gpu_count()
var vendor: String
var model: String
var vram_total: int
var logger := Log.get_logger("GPU")


func _init() -> void:
	var gpu_raw := _get_lspci_info()
	for param in gpu_raw:
		var parts := param.split(" ", false) as Array
		if parts.is_empty():
			continue
		if "VGA" in param or "Display" in param:
			if "NVIDIA" in param:
				vendor = "NVIDIA"
				model = _extract_model_from_lspci(param, "NVIDIA")
			elif "AMD" in param or "ATI" in param:
				vendor = "AMD"
				model = _extract_model_from_lspci(param, "AMD")
			elif "Intel" in param:
				vendor = "Intel"
				model = _extract_model_from_lspci(param, "Intel")
	
	# Get VRAM total if available
	vram_total = _get_vram_total()


## Returns the count of detected GPUs
func get_total_gpu_count() -> int:
	var gpu_dirs := []
	for i in range(5): # Try card0 through card4
		var path := GPU_SYS_PATH + "/card" + str(i)
		if DirAccess.dir_exists_absolute(path):
			gpu_dirs.append(path)
	
	if gpu_dirs.size() == 0:
		logger.warn("Unable to detect any GPUs")
		return 1
	return gpu_dirs.size()


## Returns an instance of the given GPU
func get_gpu(num: int) -> GPUDevice:
	# Try to load the GPU info if it already exists
	var res_path := "hardware://gpu/" + str(num)
	if ResourceLoader.exists(res_path):
		var gpu := load(res_path) as GPUDevice
		gpu.update()
		return gpu

	# Create a new GPU instance and take over the caching path
	var gpu := GPUDevice.new(num)
	gpu.take_over_path(res_path)
	gpu.update()

	return gpu


## Returns an array of all GPUs
func get_gpus() -> Array[GPUDevice]:
	var gpus: Array[GPUDevice] = []
	for gpu_num in range(0, gpu_count):
		var gpu := get_gpu(gpu_num)
		if gpu:
			gpus.append(gpu)
	
	return gpus


## Gets the current VRAM usage as a percentage (0-100)
func get_vram_usage_percent() -> float:
	var gpu := get_gpu(0)  # Default to first GPU
	if not gpu:
		return 0.0
	
	var used := gpu.get_vram_used()
	var total := gpu.get_vram_total()
	
	if total <= 0:
		return 0.0
		
	return (float(used) / float(total)) * 100.0


## Gets the current GPU frequency in MHz
func get_gpu_frequency() -> float:
	var gpu := get_gpu(0)  # Default to first GPU
	if not gpu:
		return 0.0
	
	return gpu.get_current_frequency()


## Gets the current power usage in watts
func get_power_usage() -> float:
	var gpu := get_gpu(0)  # Default to first GPU
	if not gpu:
		return 0.0
	
	return gpu.get_power_usage()


func _get_property(prop_path: String) -> String:
	if not FileAccess.file_exists(prop_path):
		return ""
	var file := FileAccess.open(prop_path, FileAccess.READ)
	var length := file.get_length()
	var bytes := file.get_buffer(length)

	return bytes.get_string_from_utf8()


## Extract model name from lspci output
func _extract_model_from_lspci(line: String, vendor_name: String) -> String:
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


## Get the total VRAM from the system
func _get_vram_total() -> int:
	for i in range(5): # Try card0 through card4
		var path := GPU_SYS_PATH + "/card" + str(i) + "/device/mem_info_vram_total"
		if FileAccess.file_exists(path):
			var vram_str := _get_property(path).strip_edges()
			return vram_str.to_int()
	
	# If we couldn't get VRAM from sys files, try lspci
	var cmd := Command.create("lspci", ["-v"])
	if cmd.execute_blocking() != OK:
		return 0
	
	var output := cmd.stdout
	if output.find("Memory") != -1:
		var mem_idx := output.find("Memory")
		var end_idx := output.find("\n", mem_idx)
		var mem_line := output.substr(mem_idx, end_idx - mem_idx)
		
		# Try to extract size
		var regex := RegEx.new()
		regex.compile("(\\d+)\\s*([GM])B")
		var result := regex.search(mem_line)
		if result:
			var size := result.get_string(1).to_int()
			var unit := result.get_string(2)
			if unit == "G":
				return size * 1024 * 1024 * 1024
			else: # MB
				return size * 1024 * 1024
	
	return 0


## Provides info on the GPU vendor, model, and capabilities.
func _get_lspci_info() -> PackedStringArray:
	var cmd := Command.create("lspci", [])
	if cmd.execute_blocking() != OK:
		return []
	return cmd.stdout.split("\n")


func _to_string() -> String:
	return "<GPU:" \
		+ " Vendor: (" + str(vendor) \
		+ ") Model: (" + str(model) \
		+ ") VRAM: (" + str(vram_total / 1024 / 1024) + " MB" \
		+ ")>" 