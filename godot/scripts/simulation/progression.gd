class_name TribeProgression
extends RefCounted
## Current approved technologies only; proposed trees are not new mechanics.

const BALANCE := {
	"initialLevel": 0, "initialExperience": 0, "initialTechnologyPoints": 0,
	"experiencePerGatherAction": 1, "experiencePerRabbitDefeated": 3,
	"experiencePerBarbarianDefeated": 5, "initialExperienceToNextLevel": 12,
	"experienceRequirementIncreasePerLevel": 12, "shieldMaximumHealthBonus": 1,
}
const TECHNOLOGIES := [
	{"id": "artisan", "tree": "survival", "order": 0, "cost": 1, "minimumLevel": 2, "name": "Artesana", "description": "Permite convertir un recolector en artesana para reunir Piedra y Brillo."},
	{"id": "mage", "tree": "exploration", "order": 0, "cost": 1, "minimumLevel": 2, "name": "Mago", "description": "Permite convertir un recolector en Mago para entrar en mazmorras."},
	{"id": "shield", "tree": "combat", "order": 0, "cost": 1, "minimumLevel": 1, "name": "Escudo", "description": "Permite equipar a los guardianes para aumentar su vida máxima en 1."},
]

static func create_initial() -> Dictionary:
	return {"level": 0, "experience": 0, "experienceToNextLevel": 12, "technologyPoints": 0, "unlockedTechnologies": []}

static func award_experience(progression: Dictionary, amount: float) -> int:
	var gained := maxi(int(floor(amount)), 0) if is_finite(amount) else 0
	if gained == 0:
		return 0
	progression.experience += gained
	var levels_gained := 0
	while progression.experience >= progression.experienceToNextLevel:
		progression.experience -= progression.experienceToNextLevel
		progression.level += 1
		progression.technologyPoints += 1
		progression.experienceToNextLevel += 12
		levels_gained += 1
	return levels_gained

static func get_technology(id: String) -> Variant:
	for technology in TECHNOLOGIES:
		if technology.id == id:
			return technology
	return null

static func can_unlock(progression: Dictionary, id: String) -> bool:
	var technology: Variant = get_technology(id)
	return technology != null and id not in progression.unlockedTechnologies and progression.level >= technology.minimumLevel and progression.technologyPoints >= technology.cost

static func unlock(progression: Dictionary, id: String) -> bool:
	if not can_unlock(progression, id):
		return false
	progression.technologyPoints -= get_technology(id).cost
	progression.unlockedTechnologies.append(id)
	return true
