extends SceneTree
## Exercises the real menu and application signals with isolated save files.

const Saves = preload("res://scripts/persistence/save_repository.gd")
const State = preload("res://scripts/simulation/game_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory := "user://test-play-menu-%s" % OS.get_process_id()
	var game = preload("res://scenes/main.tscn").instantiate()
	game.saves = Saves.new(directory)
	root.add_child(game)
	var menus = game.menus
	var buttons: Array[String] = []
	for button: Button in menus._content.find_children("*", "Button", true, false):
		buttons.append(button.text)
	_expect(buttons == ["Jugar", "Tutorial", "Salir"], "Main menu actions")
	await process_frame
	await process_frame
	var main_panel: Rect2 = menus.page_host.get_global_rect()
	var main_title: Label = menus._content.get_node("TitleSpace/Title")
	var main_title_rect := main_title.get_global_rect()
	var main_title_text := main_title.text
	_press(menus, "Play")
	_expect(menus.screen == "play", "Jugar opens its submenu")
	_expect(not menus._content.get_node("Actions/Load").visible, "No load with empty slots")
	await process_frame
	await process_frame
	_expect(root.gui_get_focus_owner() == null, "No default focus in Jugar")
	_expect(menus.page_host.get_global_rect() == main_panel, "Same panel geometry without saves")
	_expect(menus._content.get_node("TitleSpace/Title").text == main_title_text, "Same title text")
	_expect(menus._content.get_node("TitleSpace/Title").get_global_rect() == main_title_rect, "Same title geometry")
	menus.update_slots([{"slot": 1, "status": "invalid", "reason": "corrupt"}])
	_expect(not menus._content.get_node("Actions/Load").visible, "No load with invalid saves only")
	_press(menus, "Back")
	_expect(menus.screen == "main", "Back from Jugar")
	_press(menus, "Tutorial")
	_expect(menus.screen == "tutorial", "Tutorial opens")
	_press(menus, "Play")
	_expect(menus.screen == "play", "Jugar from Tutorial opens the submenu")
	_expect(root.gui_get_focus_owner() == null, "No default focus when Jugar opens from Tutorial")
	menus.handle_escape()

	var state := State.create_initial()
	state.progression.level = 2
	for slot in range(1, 4):
		_expect(game.saves.save_slot(slot, state).ok, "Create isolated save %s" % slot)
		menus.update_slots(game.saves.list_slots())
		_press(menus, "Play")
		_expect(menus._content.get_node("Actions/Load").visible, "Load with %s valid saves" % slot)
		menus.handle_escape()
		_expect(menus.screen == "main", "Escape from Jugar")

	var before: Array = game.saves.list_slots()
	_press(menus, "Play")
	await process_frame
	await process_frame
	_expect(menus.page_host.get_global_rect() == main_panel, "Same panel geometry with saves")
	_press(menus, "NewGame")
	_expect(menus.screen == "game" and game.session.state.progression.level == 0, "New game with all slots occupied")
	_expect(game.saves.list_slots() == before, "New game preserves all saves")

	menus.show_main()
	_press(menus, "Play")
	_press(menus, "Load")
	_expect(menus.screen == "slots", "Load opens the existing slots")
	_expect(root.gui_get_focus_owner() == null, "No default focus in the slot menu")
	_press(menus, "Back")
	_expect(menus.screen == "play", "Back from slots returns to Jugar")
	_press(menus, "Load")
	menus.handle_escape()
	_expect(menus.screen == "play", "Escape from slots returns to Jugar")
	_press(menus, "Load")
	_press(menus, "Select")
	_expect(menus.screen == "game" and game.session.state.progression.level == 2, "Load restores the selected save")

	menus.show_pause()
	_press(menus, "Load")
	menus.handle_escape()
	_expect(menus.screen == "pause", "Slots opened from pause return to pause")

	menus.show_main()
	_press(menus, "Play")
	_press(menus, "Load")
	for slot in range(1, 4):
		var row: Node = menus._content.get_node("Rows").get_child(slot - 1)
		row.get_node("Delete").pressed.emit()
		_press(menus, "Confirm")
	_press(menus, "Back")
	_expect(not menus._content.get_node("Actions/Load").visible, "Load disappears after deleting the last valid save")

	for slot in range(1, 4):
		game.saves.delete_slot(slot)
	DirAccess.remove_absolute(directory)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	game.free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS play menu flow")
	quit(0 if failures.is_empty() else 1)

func _press(menus: Node, button_name: String) -> void:
	var button := menus._content.find_child(button_name, true, false) as Button
	if button == null or not button.is_visible_in_tree() or button.disabled:
		failures.append("Cannot press %s on %s" % [button_name, menus.screen])
		return
	button.pressed.emit()

func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
