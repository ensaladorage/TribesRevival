extends CanvasLayer
## Scene-backed HUD. Availability and prices derive from shared rules.

signal placement_requested(item: String)
signal action_requested(action: Dictionary)

const Economy = preload("res://scripts/simulation/economy.gd")
const Rules = preload("res://scripts/simulation/survival_rules.gd")
const Progression = preload("res://scripts/simulation/progression.gd")
const ITEM_NAMES := {"gatherer": "Recolector", "axe": "Leñador", "bow": "Cazador", "sword": "Guardián", "hammer": "Artesana", "mage": "Mago", "campfire": "Hoguera", "shield": "Escudo"}
const RESOURCE_NAMES := {"food": "Comida", "wood": "Madera", "stone": "Piedra", "spark": "Brillo", "gold": "Oro"}
const ITEM_HINTS := {"gatherer": "Recluta un minion básico. Arrastra al terreno.", "axe": "Convertir en Leñador. Arrastra sobre un Recolector.", "bow": "Convertir en Cazador. Arrastra sobre un Recolector.", "sword": "Convertir en Guardián. Arrastra sobre un Recolector.", "hammer": "Convertir en Artesana para reunir Piedra y Brillo. Arrastra sobre un Recolector.", "mage": "Convertir en Mago. Arrastra sobre un Recolector.", "campfire": "Cura a los minions cercanos consumiendo comida. Arrastra al terreno.", "shield": "Escudo +1 HP. Arrastra sobre un Guardián sin escudo."}
var _items := {}
var _item_rows := {}
var _item_costs := {}
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
	# Scenes own layout, icons and styles; metadata binds semantic actions.
	_management = $Layout/Management
	_tech_page = $Layout/Management/Pages/TechnologiesPanel
	_upgrade_page = $Layout/Management/Pages/UpgradesPanel
	_technology_points = _tech_page.find_child("Points", true, false)
	_technology_toggle = $Layout/Dock/TechnologyToggle
	_technology_toggle.pressed.connect(func(): _toggle_panel("Tecnologías"))
	$Layout/Dock/UpgradeToggle.pressed.connect(func(): _toggle_panel("Mejoras"))
	for row in $Layout.find_children("*", "HBoxContainer", true, false):
		if row.has_meta("item_row"):
			_item_rows[row.get_meta("item_row")] = row
		elif row.has_meta("cost_for"):
			_item_costs[row.get_meta("cost_for")] = row
	for label in $Layout.find_children("*", "Label", true, false):
		if label.has_meta("resource"):
			_resource_counts[label.get_meta("resource")] = label
	for row in _tech_page.find_children("*", "HFlowContainer", true, false):
		if row.has_meta("tree_options"):
			_tree_rows[row.get_meta("tree_options")] = row
	for button in $Layout.find_children("*", "Button", true, false):
		if button.has_meta("item"):
			var item: String = button.get_meta("item")
			_items[item] = button
			button.button_down.connect(func(): placement_requested.emit(item))
		elif button.has_meta("tree"):
			var tree: String = button.get_meta("tree")
			button.pressed.connect(func():
				_selected_tree = "" if _selected_tree == tree else tree
				_refresh_panels())
		elif button.has_meta("technology"):
			var technology: String = button.get_meta("technology")
			_technologies[technology] = button
			button.pressed.connect(func():
				_pending_technology = technology
				action_requested.emit({"type": "unlock-technology", "technology": technology}))
		elif button.has_meta("tool"):
			var tool: String = button.get_meta("tool")
			_upgrades[tool] = button
			button.pressed.connect(func(): action_requested.emit({"type": "upgrade-tool", "tool": tool}))
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
		_items[item].text = ""
		if item in ["axe", "hammer", "sword"]:
			_apply_level_color(_items[item], state.toolLevels[item])
		_items[item].disabled = not available or not Economy.can_afford(amounts, cost)
		_item_rows[item].visible = _items[item].visible
		_item_costs[item].update_cost(cost, not _items[item].disabled)
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
	# All eleven variants are editable in TribesTheme.tres.
	button.theme_type_variation = StringName("ToolLevel%s" % level)
