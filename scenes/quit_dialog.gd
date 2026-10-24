class_name QuitDialog
extends CanvasLayer
## "Save before quitting?" over whatever screen is open. Shown by Game.request_quit() when Auto-save is
## off and there is progress that was not saved. The screen behind it is frozen until the choice is made.

var _scene: Node
var _scene_mode := Node.PROCESS_MODE_INHERIT
var _was_paused := false

@onready var _dim: Control = %Dim
@onready var _save_quit: Button = %SaveQuit
@onready var _quit_only: Button = %QuitOnly
@onready var _cancel: Button = %Cancel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim.theme = UiTheme.make()
	_scene = get_tree().current_scene
	if _scene != null:
		_scene_mode = _scene.process_mode
		_scene.process_mode = Node.PROCESS_MODE_DISABLED   # nothing behind the dialog reacts to input
	_was_paused = get_tree().paused
	get_tree().paused = true
	_save_quit.pressed.connect(func():
		SaveManager.write()
		get_tree().quit())
	_quit_only.pressed.connect(func(): get_tree().quit())
	_cancel.pressed.connect(close)
	_save_quit.call_deferred("grab_focus")


func _input(event: InputEvent) -> void:
	if InputManager.is_duplicate(event):
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.process_mode = _scene_mode
	get_tree().paused = _was_paused
	queue_free()
