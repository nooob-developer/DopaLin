extends Resource
class_name CPUCore

## Represents a single CPU core in the system

## Emitted when core state is updated
signal state_updated()
## Emitted when core frequency changes
signal frequency_changed(freq: float)
## Emitted when core online status changes
signal online_changed(online: bool)

var core_index: int
var cpu_path: String
var online: bool = true
var current_frequency: float = 0.0
var min_frequency: float = 0.0
var max_frequency: float = 0.0
var governor: String = "powersave"
var logger := Log.get_logger("CPUCore")


func _init(index: int = 0) -> void:
	core_index = index
	cpu_path = "/sys/bus/cpu/devices/cpu" + str(core_index)
	
	# Check if core is online
	online = _is_core_online()
	
	# Initial update of stats
	update()


## Updates all CPU core stats
func update() -> void:
	# Skip if core is offline
	if not online:
		return
		
	# Update frequency values
	_update_frequencies()
	
	# Update governor
	_update_governor()
	
	# Emit signal
	emit_signal("state_updated")


## Gets the current CPU core frequency in MHz
func get_current_frequency() -> float:
	return current_frequency


## Gets the minimum CPU core frequency in MHz
func get_min_frequency() -> float:
	return min_frequency


## Gets the maximum CPU core frequency in MHz
func get_max_frequency() -> float:
	return max_frequency


## Gets the current CPU governor (e.g. "performance", "powersave")
func get_governor() -> String:
	return governor


## Set CPU governor (e.g. "performance", "powersave", "ondemand", "conservative")
func set_governor(new_governor: String) -> bool:
	if not online:
		logger.error("Cannot set governor on offline core: " + str(core_index))
		return false
		
	var valid_governors := ["performance", "powersave", "ondemand", "conservative", "schedutil"]
	if not new_governor in valid_governors:
		logger.error("Invalid governor: " + new_governor)
		return false
		
	var governor_path := cpu_path + "/cpufreq/scaling_governor"
	var file := FileAccess.open(governor_path, FileAccess.WRITE)
	if not file:
		logger.error("Failed to open governor file: " + governor_path)
		return false
		
	file.store_string(new_governor)
	file.close()
	
	# Update our stored value
	governor = new_governor
	
	return true


## Set CPU core online status
func set_online(is_online: bool) -> bool:
	# CPU0 can't be disabled on most systems
	if core_index == 0 and not is_online:
		logger.error("Cannot disable CPU0")
		return false
		
	var online_path := "/sys/devices/system/cpu/cpu" + str(core_index) + "/online"
	if not FileAccess.file_exists(online_path):
		logger.error("Online control not available for core: " + str(core_index))
		return false
		
	var file := FileAccess.open(online_path, FileAccess.WRITE)
	if not file:
		logger.error("Failed to open online file: " + online_path)
		return false
		
	file.store_string("1" if is_online else "0")
	file.close()
	
	# Update our status and emit signal
	var old_online := online
	online = is_online
	
	if old_online != online:
		emit_signal("online_changed", online)
	
	return true


func _is_core_online() -> bool:
	# CPU0 is always online
	if core_index == 0:
		return true
		
	var online_path := "/sys/devices/system/cpu/cpu" + str(core_index) + "/online"
	if not FileAccess.file_exists(online_path):
		# If the file doesn't exist, assume the core is always online
		return true
		
	var file := FileAccess.open(online_path, FileAccess.READ)
	var content := file.get_as_text().strip_edges()
	
	return content == "1"


func _update_frequencies() -> void:
	var old_freq := current_frequency
	
	# Get current frequency
	var cur_freq_path := cpu_path + "/cpufreq/scaling_cur_freq"
	var cur_freq_str := _get_property(cur_freq_path).strip_edges()
	if not cur_freq_str.is_empty():
		# Convert from kHz to MHz
		current_frequency = float(cur_freq_str) / 1000.0
	
	# Get min frequency
	var min_freq_path := cpu_path + "/cpufreq/scaling_min_freq"
	var min_freq_str := _get_property(min_freq_path).strip_edges()
	if not min_freq_str.is_empty():
		# Convert from kHz to MHz
		min_frequency = float(min_freq_str) / 1000.0
	
	# Get max frequency
	var max_freq_path := cpu_path + "/cpufreq/scaling_max_freq"
	var max_freq_str := _get_property(max_freq_path).strip_edges()
	if not max_freq_str.is_empty():
		# Convert from kHz to MHz
		max_frequency = float(max_freq_str) / 1000.0
	
	# Emit signal if frequency changed
	if current_frequency != old_freq:
		emit_signal("frequency_changed", current_frequency)


func _update_governor() -> void:
	var governor_path := cpu_path + "/cpufreq/scaling_governor"
	var governor_str := _get_property(governor_path).strip_edges()
	if not governor_str.is_empty():
		governor = governor_str


func _get_property(prop_path: String) -> String:
	if not FileAccess.file_exists(prop_path):
		return ""
	var file := FileAccess.open(prop_path, FileAccess.READ)
	var length := file.get_length()
	var bytes := file.get_buffer(length)

	return bytes.get_string_from_utf8()


func _to_string() -> String:
	if not online:
		return "<CPUCore:" \
			+ " index: (" + str(core_index) \
			+ ") [Offline]" \
			+ ">"
			
	return "<CPUCore:" \
		+ " index: (" + str(core_index) \
		+ ") Freq: (" + str(current_frequency) + " MHz" \
		+ ") Governor: (" + governor \
		+ ")>" 