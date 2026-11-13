extends SceneTree

var _started := false

func _process(delta: float) -> bool:
	if not _started:
		_started = true
		_run.call_deferred()
	return false

func _run() -> void:
	print("Starting async test runner...")
	print("Autoload GameManager: ", root.get_node_or_null("/root/GameManager"))
	quit(0)
