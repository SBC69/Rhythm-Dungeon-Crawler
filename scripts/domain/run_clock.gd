# scripts/domain/run_clock.gd
class_name RunClock
extends RefCounted

var _start_time_msec: int = 0
var _frozen_elapsed_msec: int = -1
var _is_running: bool = false
var _use_fake_time: bool = false
var _fake_time_msec: int = 0

func start() -> void:
	_start_time_msec = _get_current_ticks()
	_frozen_elapsed_msec = -1
	_is_running = true

func freeze() -> int:
	if _frozen_elapsed_msec < 0 and _is_running:
		_frozen_elapsed_msec = get_elapsed_msec()
	_is_running = false
	return _frozen_elapsed_msec

func get_elapsed_msec() -> int:
	if _frozen_elapsed_msec >= 0:
		return _frozen_elapsed_msec
	if not _is_running:
		return 0
	return maxi(0, _get_current_ticks() - _start_time_msec)

func get_elapsed_seconds() -> float:
	return float(get_elapsed_msec()) / 1000.0

func format_time_string() -> String:
	var total_sec = int(get_elapsed_seconds())
	var m = total_sec / 60
	var s = total_sec % 60
	return "%02d:%02d" % [m, s]

func is_running() -> bool:
	return _is_running

func is_frozen() -> bool:
	return _frozen_elapsed_msec >= 0

# Test seams
func enable_fake_time(initial_msec: int = 0) -> void:
	_use_fake_time = true
	_fake_time_msec = initial_msec

func advance_fake_time(msec: int) -> void:
	if _use_fake_time:
		_fake_time_msec += msec

func _get_current_ticks() -> int:
	if _use_fake_time:
		return _fake_time_msec
	return Time.get_ticks_msec()

func serialize() -> Dictionary:
	return {
		"start_time_msec": _start_time_msec,
		"frozen_elapsed_msec": _frozen_elapsed_msec,
		"is_running": _is_running,
		"elapsed_msec": get_elapsed_msec()
	}

func deserialize(data: Dictionary) -> void:
	_start_time_msec = int(data.get("start_time_msec", 0))
	_frozen_elapsed_msec = int(data.get("frozen_elapsed_msec", -1))
	_is_running = bool(data.get("is_running", false))
