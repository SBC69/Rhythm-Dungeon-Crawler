# scripts/persistence/save_store.gd
class_name SaveStore
extends RefCounted

var save_dir: String = "user://saves"
var base_dir: String:
	get:
		return save_dir
	set(val):
		save_dir = val

func _init(custom_save_dir: String = "") -> void:
	if not custom_save_dir.is_empty():
		save_dir = custom_save_dir
	_ensure_directory()

func _ensure_directory() -> void:
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

func get_save_path() -> String:
	return save_dir.path_join("save_envelope.json")

func get_backup_path() -> String:
	return save_dir.path_join("save_envelope.json.bak")

func get_temp_path() -> String:
	return save_dir.path_join("save_envelope.json.tmp")

func save_envelope(envelope: Dictionary) -> bool:
	_ensure_directory()
	var temp_path = get_temp_path()
	var save_path = get_save_path()
	var backup_path = get_backup_path()

	var json_str = JSON.stringify(envelope, "  ")
	
	# 1. Write to temp file
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveStore: Failed to open temp file for writing: %s" % temp_path)
		return false
	file.store_string(json_str)
	file.close()

	# 2. Verify temp file
	var verify_file = FileAccess.open(temp_path, FileAccess.READ)
	if verify_file == null:
		push_error("SaveStore: Failed to read temp file for verification")
		return false
	var read_back = verify_file.get_as_text()
	verify_file.close()

	var decoded = SaveCodec.decode_envelope(read_back)
	if decoded.has("error"):
		push_error("SaveStore: Verification failed: %s" % decoded["error"])
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		return false

	# 3. Backup existing save if present
	if FileAccess.file_exists(save_path) and not SaveCodec.decode_envelope(FileAccess.get_file_as_string(save_path)).has("error"):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		var copy_err = DirAccess.copy_absolute(save_path, backup_path)
		if copy_err != OK:
			push_error("SaveStore: Failed to create backup: %d" % copy_err)
			return false

	# 4. Atomic replace
	var remove_old = OK
	if FileAccess.file_exists(save_path):
		remove_old = DirAccess.remove_absolute(save_path)
	
	if remove_old != OK:
		push_error("SaveStore: Failed to remove old save before rename: %d" % remove_old)
		return false

	var rename_err = DirAccess.rename_absolute(temp_path, save_path)
	if rename_err != OK:
		push_error("SaveStore: Failed to rename temp to save file: %d" % rename_err)
		# Attempt restore from backup
		if FileAccess.file_exists(backup_path):
			DirAccess.copy_absolute(backup_path, save_path)
		return false

	return true

func load_envelope() -> Dictionary:
	var save_path = get_save_path()
	var backup_path = get_backup_path()

	var had_primary = FileAccess.file_exists(save_path)
	var had_backup = FileAccess.file_exists(backup_path)

	if had_primary:
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file != null:
			var content = file.get_as_text()
			file.close()
			var decoded = SaveCodec.decode_envelope(content)
			if not decoded.has("error"):
				var original = JSON.parse_string(content)
				if int(original.get("schema_version", 0)) != SaveCodec.CURRENT_SCHEMA_VERSION:
					if not save_envelope(decoded):
						return {"error": "Migration could not be saved"}
				return _handle_timed_rollback_if_needed(decoded)

	# Try backup if save_path failed or was corrupt
	if had_backup:
		var b_file = FileAccess.open(backup_path, FileAccess.READ)
		if b_file != null:
			var b_content = b_file.get_as_text()
			b_file.close()
			var b_decoded = SaveCodec.decode_envelope(b_content)
			if not b_decoded.has("error"):
				return _handle_timed_rollback_if_needed(b_decoded)

	if had_primary or had_backup:
		return {"error": "Corrupt save file"}

	# Return default empty profile envelope when no save file exists yet
	return SaveCodec.encode_envelope(SaveCodec.create_default_profile(), {})

func _handle_timed_rollback_if_needed(envelope: Dictionary) -> Dictionary:
	var active_run: Dictionary = envelope.get("active_run", {})
	if active_run.is_empty():
		return envelope

	var mode_str = str(active_run.get("mode", ""))
	var is_timed = (mode_str == "TIMED_100")

	# If timed mode was in progress and closed without terminal outcome, rollback to entry_profile_snapshot!
	if is_timed and active_run.has("terminal_outcome") and str(active_run["terminal_outcome"]) == "NONE":
		if active_run.has("entry_profile_snapshot"):
			var snapshot: Dictionary = active_run["entry_profile_snapshot"]
			envelope["profile"] = snapshot.duplicate(true)
		envelope["active_run"] = {}
		# Save rolled back state
		save_envelope(envelope)

	return envelope
