extends CanvasLayer
## Native, provisional HUD. All availability and prices derive from shared rules.

signal placement_requested(item: String)
signal action_requested(action: Dictionary)

const Economy = preload("res://scripts/simulation/economy.gd")
const Rules = preload("res://scripts/simulation/survival_rules.gd")
const Progression = preload("res://scripts/simulation/progression.gd")
const ITEM_NAMES := {"gatherer": "Recolector", "axe": "Leñador", "bow": "Cazador", "sword": "Guardián", "hammer": "Artesana", "mage": "Mago", "campfire": "Hoguera", "shield": "Escudo"}
const RESOURCE_NAMES := {"food": "Comida", "wood": "Madera", "stone": "Piedra", "spark": "Brillo", "gold": "Oro"}
const ITEM_HINTS := {"gatherer": "Recluta un minion básico. Arrastra al terreno.", "axe": "Convertir en Leñador. Arrastra sobre un Recolector.", "bow": "Convertir en Cazador. Arrastra sobre un Recolector.", "sword": "Convertir en Guardián. Arrastra sobre un Recolector.", "hammer": "Convertir en Artesana para reunir Piedra y Brillo. Arrastra sobre un Recolector.", "mage": "Convertir en Mago. Arrastra sobre un Recolector.", "campfire": "Cura a los minions cercanos consumiendo comida. Arrastra al terreno.", "shield": "Escudo +1 HP. Arrastra sobre un Guardián sin escudo."}
var _items := {}
var _upgrades := {}
var _technologies := {}
var _management: PanelContainer
var _tech_page: VBoxContainer
var _upgrade_page: HFlowContainer
var _tree_rows := {}
var _open_panel := ""
var _selected_tree := ""
var _resource_counts := {}
var _technology_toggle: Button
var _technology_points: Label
var _last_observed_level := -1
var _pending_technology := ""
const ICONS := {"gatherer": "icon-minion", "axe": "icon-axe", "bow": "icon-bow", "sword": "icon-sword", "hammer": "icon-hammer", "mage": "icon-mage", "campfire": "icon-fireplace", "shield": "icon-shield"}

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var counters := HFlowContainer.new()
	counters.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	counters.offset_left = 220
	counters.offset_right = -20
	counters.offset_top = 16
	counters.alignment = FlowContainer.ALIGNMENT_CENTER
	counters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(counters)
	for resource in Economy.RESOURCE_TYPES:
		var group := HBoxContainer.new()
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ui/resource-%s.png" % resource)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(28, 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(icon)
		var count := Label.new()
		count.custom_minimum_size.x = 48
		count.tooltip_text = RESOURCE_NAMES[resource]
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(count)
		counters.add_child(group)
		_resource_counts[resource] = count
	var sidebar := VBoxContainer.new()
	sidebar.position = Vector2(16, 155)
	sidebar.custom_minimum_size.x = 145
	root.add_child(sidebar)
	var shield_dock := VBoxContainer.new()
	shield_dock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	shield_dock.offset_left = -161
	shield_dock.offset_right = -16
	shield_dock.offset_top = 155
	root.add_child(shield_dock)
	for item in ["gatherer", "axe", "bow", "sword", "hammer", "mage", "campfire", "shield"]:
		var button := Button.new()
		button.text = ITEM_NAMES[item]
		button.icon = load("res://assets/ui/%s.png" % ICONS[item])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.custom_minimum_size.y = 38
		button.button_down.connect(func(): placement_requested.emit(item))
		if item == "shield":
			shield_dock.add_child(button)
		else:
			sidebar.add_child(button)
		_items[item] = button
	var dock := HBoxContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	dock.position = Vector2(16, -54)
	root.add_child(dock)
	for panel in ["Tecnologías", "Mejoras"]:
		var button := Button.new()
		button.text = panel
		button.custom_minimum_size = Vector2(125, 38)
		button.pressed.connect(func(): _toggle_panel(panel))
		dock.add_child(button)
		if panel == "Tecnologías":
			_technology_toggle = button
	_management = PanelContainer.new()
	_management.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_management.position = Vector2(16, -260)
	_management.custom_minimum_size = Vector2(560, 190)
	_management.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("233037")
	style.set_content_margin_all(12)
	style.set_corner_radius_all(6)
	_management.add_theme_stylebox_override("panel", style)
	root.add_child(_management)
	var content := VBoxContainer.new()
	_management.add_child(content)
	_tech_page = VBoxContainer.new()
	content.add_child(_tech_page)
	_technology_points = Label.new()
	_tech_page.add_child(_technology_points)
	var trees := HFlowContainer.new()
	_tech_page.add_child(trees)
	for tree in ["survival", "exploration", "combat"]:
		var button := Button.new()
		button.text = {"survival": "Supervivencia", "exploration": "Exploración", "combat": "Combate"}[tree]
		button.pressed.connect(func():
			_selected_tree = "" if _selected_tree == tree else tree
			_refresh_panels())
		trees.add_child(button)
		var row := HFlowContainer.new()
		_tech_page.add_child(row)
		_tree_rows[tree] = row
	for technology in Progression.TECHNOLOGIES:
		var button := Button.new()
		button.text = "%s · %s punto" % [technology.name, technology.cost]
		button.icon = load("res://assets/ui/%s.png" % ICONS["hammer" if technology.id == "artisan" else technology.id])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.pressed.connect(func():
			_pending_technology = technology.id
			action_requested.emit({"type": "unlock-technology", "technology": technology.id}))
		_tree_rows[technology.tree].add_child(button)
		_technologies[technology.id] = button
	_upgrade_page = HFlowContainer.new()
	content.add_child(_upgrade_page)
	for tool in ["axe", "hammer", "sword"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(160, 70)
		button.icon = load("res://assets/ui/%s.png" % ICONS[tool])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 40)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.pressed.connect(func(): action_requested.emit({"type": "upgrade-tool", "tool": tool}))
		_upgrade_page.add_child(button)
		_upgrades[tool] = button
	_refresh_panels()

func _toggle_panel(panel: String) -> void:
	_open_panel = "" if _open_panel == panel else panel
	if panel == "Tecnologías":
		_selected_tree = ""
	_refresh_panels()

func reset_panels() -> void:
	_open_panel = ""
	_selected_tree = ""
	_last_observed_level = -1
	_pending_technology = ""
	_refresh_panels()

func _refresh_panels() -> void:
	_management.visible = not _open_panel.is_empty()
	_tech_page.visible = _open_panel == "Tecnologías"
	_upgrade_page.visible = _open_panel == "Mejoras"
	for tree in _tree_rows:
		_tree_rows[tree].visible = tree == _selected_tree

static func _cost_text(cost: Dictionary) -> String:
	var entries: PackedStringArray = []
	for resource in Economy.RESOURCE_TYPES:
		if cost.has(resource):
			entries.append("%s %s" % [cost[resource], RESOURCE_NAMES[resource]])
	return " + ".join(entries)

func update_state(state: Dictionary) -> void:
	var progression: Dictionary = state.progression
	# A fresh/loaded state establishes the baseline without opening a panel.
	if _last_observed_level >= 0 and progression.level > _last_observed_level:
		if _open_panel != "Tecnologías":
			_selected_tree = ""
		_open_panel = "Tecnologías"
	_last_observed_level = progression.level
	if not _pending_technology.is_empty() and _pending_technology in progression.unlockedTechnologies:
		if progression.technologyPoints == 0:
			_open_panel = ""
		_pending_technology = ""
	_technology_toggle.text = "Tecnologías · %s" % progression.technologyPoints
	_technology_points.text = "Puntos disponibles: %s" % progression.technologyPoints
	_refresh_panels()
	var amounts: Dictionary = state.inventory.amounts
	for resource in _resource_counts:
		_resource_counts[resource].text = str(amounts[resource])
	var gatherers := Rules.count_role(state.units, "gatherer")
	for item in _items:
		var cost: Dictionary
		var reason := ""
		var available: bool = state.phase == "playing"
		if item == "gatherer":
			cost = Economy.recruitment_cost(state.units.size())
			available = available and state.units.size() < 8
			if state.units.size() >= 8:
				reason = "Límite de tribu alcanzado"
		elif item == "campfire":
			cost = {"wood": 2}
			available = available and state.campfires.size() < 2
			if state.campfires.size() >= 2:
				reason = "Límite de hogueras alcanzado"
		elif item == "shield":
			var shielded: int = state.units.filter(func(unit): return unit.role == "guardian" and unit.hasShield).size()
			cost = Economy.shield_cost(shielded)
			_items[item].visible = "shield" in state.progression.unlockedTechnologies
			available = available and "shield" in state.progression.unlockedTechnologies and Rules.count_role(state.units, "guardian") > shielded
			if Rules.count_role(state.units, "guardian") == 0:
				reason = "Necesitas un guardián"
			elif Rules.count_role(state.units, "guardian") <= shielded:
				reason = "Todos los guardianes ya tienen escudo"
		else:
			var definition: Dictionary = Economy.SPECIALIZATIONS[item]
			var count := Rules.count_role(state.units, definition.role)
			cost = Economy.specialization_cost(item, count)
			available = available and gatherers > 0 and count < definition.limit
			if gatherers == 0:
				reason = "Necesitas un recolector"
			elif count >= definition.limit:
				reason = "Máximo alcanzado"
			if item in ["axe", "hammer"]:
				available = available and Rules.can_convert_last_gatherer(state.units)
				if reason.is_empty() and not Rules.can_convert_last_gatherer(state.units):
					reason = "No puedes convertir a tu último recolector"
			if item in ["hammer", "mage"]:
				var technology := "artisan" if item == "hammer" else "mage"
				_items[item].visible = technology in state.progression.unlockedTechnologies
				available = available and _items[item].visible
		_items[item].text = ITEM_NAMES[item] + "\n" + _cost_text(cost)
		if item in ["axe", "hammer", "sword"]:
			_items[item].text = "%s +%s\n%s" % [ITEM_NAMES[item], state.toolLevels[item], _cost_text(cost)]
			_apply_level_color(_items[item], state.toolLevels[item])
		_items[item].disabled = not available or not Economy.can_afford(amounts, cost)
		var tooltip := "%s\n%s\nCoste: %s" % [ITEM_NAMES[item], ITEM_HINTS[item], _cost_text(cost)]
		if not reason.is_empty():
			tooltip += "\n" + reason
		var missing := Economy.missing_resources(amounts, cost)
		if not missing.is_empty():
			tooltip += "\nFalta: " + _cost_text(missing)
		_items[item].tooltip_text = tooltip
	for technology in Progression.TECHNOLOGIES:
		var unlocked: bool = technology.id in state.progression.unlockedTechnologies
		_technologies[technology.id].text = "%s · %s" % [technology.name, "Desbloqueada" if unlocked else "%s punto" % technology.cost]
		_technologies[technology.id].disabled = state.phase != "playing" or not Progression.can_unlock(state.progression, technology.id)
		_technologies[technology.id].tooltip_text = "%s\n%s\n%s" % [technology.name, technology.description, "Desbloqueado" if unlocked else "Nivel requerido: %s" % technology.minimumLevel]
	for tool in _upgrades:
		var level: int = state.toolLevels[tool]
		var name: String = {"axe": "Hacha", "hammer": "Martillo", "sword": "Espada"}[tool]
		_upgrades[tool].text = "%s   %s" % [name, "Max" if level == 10 else "+%s" % level]
		_apply_level_color(_upgrades[tool], level)
		var upgrade: Variant = Economy.tool_upgrade(tool, level + 1)
		_upgrades[tool].disabled = state.phase != "playing" or upgrade == null or not Economy.can_afford(amounts, upgrade.cost)
		if upgrade == null:
			_upgrades[tool].tooltip_text = name + " · Max"
		else:
			_upgrades[tool].tooltip_text = "%s\nActual: %s\nSiguiente: %s\nCoste: %s\nFalta: %s" % [name, _effect_text(tool, level), _effect_text(tool, level + 1), _cost_text(upgrade.cost), _cost_text(Economy.missing_resources(amounts, upgrade.cost))]

static func _effect_text(tool: String, level: int) -> String:
	var effect := Economy.tool_effect(tool, level)
	if tool == "sword":
		return "+%.2f daño" % effect.guardianDamageBonus
	return "+%s%% velocidad · %s%% de +1 recurso" % [effect.gatherSpeedPercent, effect.bonusResourceChance]

func _apply_level_color(button: Button, level: int) -> void:
	if button.get_meta("tool_level", -1) == level:
		return
	button.set_meta("tool_level", level)
	var color := Color("39464a")
	if level == 10:
		color = Color("b77d35")
	elif level >= 7:
		color = Color("80508f")
	elif level >= 5:
		color = Color("168397")
	elif level >= 3:
		color = Color("3f8f54")
	elif level >= 1:
		color = Color("a7a7a7")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.lightened(0.12) if state == "hover" else color
		style.set_content_margin_all(8)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
