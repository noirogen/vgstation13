/*
 * MATERIAL SCIENCE: SECONDARY TRAITS
 *
 * One singleton datum per trait, stored in matsci_traits (id -> datum).
 * Traits are rolled when a material is generated and stored on it as trait ID -> strength.
 * Stat-modifier traits (soft, dense, crystalline) change the material's stats at that point.
 */

#define MATSCI_TRAIT_HAZARD "hazard"
#define MATSCI_TRAIT_POSITIVE "positive"
#define MATSCI_TRAIT_NEGATIVE "negative"
#define MATSCI_TRAIT_MIXED "mixed"

var/list/datum/matsci_trait/matsci_traits

/proc/matsci_get_traits()
	if(!matsci_traits)
		matsci_traits = list()
		for(var/path in subtypesof(/datum/matsci_trait))
			var/datum/matsci_trait/T = new path
			if(!T.id)
				continue
			matsci_traits[T.id] = T
	return matsci_traits

/proc/matsci_get_trait(var/id)
	var/list/traits = matsci_get_traits()
	return traits[id]

/datum/matsci_trait
	var/id
	var/name
	var/desc
	var/category = MATSCI_TRAIT_POSITIVE
	/// Usual material tier for this trait. Ignored for rolling weights if any_tier is set.
	var/tier = 1
	var/any_tier = FALSE
	/// Never rolled on materials below this tier (round-threatening traits are T3+ only).
	var/min_material_tier = 1
	/// Base rolling weight.
	var/weight = 10
	/// Trait IDs that can't appear on the same material.
	var/list/exclusive_with

/// Called once when a material is generated, after its stats are rolled. Only stat-modifier traits do anything here.
/datum/matsci_trait/proc/apply_stats(var/datum/material/procgen/M, var/strength)
	return

/datum/matsci_trait/proc/is_negative()
	return category == MATSCI_TRAIT_NEGATIVE

// ---------------- Hazard ----------------

/datum/matsci_trait/explosive
	id = "explosive"
	name = "Explosive"
	desc = "Small, capped blasts on hit, on thrown impact, when mined and when heated carelessly."
	category = MATSCI_TRAIT_HAZARD
	tier = 3
	min_material_tier = 3

/datum/matsci_trait/toxic
	id = "toxic"
	name = "Toxic"
	desc = "Harmful to handle barehanded; weapons deal extra toxin damage."
	category = MATSCI_TRAIT_HAZARD
	tier = 1

/datum/matsci_trait/radioactive
	id = "radioactive"
	name = "Radioactive"
	desc = "Irradiates on hit and nearby while held or stored."
	category = MATSCI_TRAIT_HAZARD
	tier = 2

/datum/matsci_trait/searing
	id = "searing"
	name = "Searing"
	desc = "Weapons set targets alight; sheets can ignite in plasma-rich air."
	category = MATSCI_TRAIT_HAZARD
	tier = 3

// ---------------- Positive ----------------

/datum/matsci_trait/charged
	id = "charged"
	name = "Charged"
	desc = "Items with power cells slowly recharge; machine parts are more power efficient."
	tier = 3

/datum/matsci_trait/luminous
	id = "luminous"
	name = "Luminous"
	desc = "Glows in the material's colour."
	tier = 1

/datum/matsci_trait/lightweight
	id = "lightweight"
	name = "Lightweight"
	desc = "Thrown farther; armor and tools slow you less."
	tier = 2
	exclusive_with = list("heavy")

/datum/matsci_trait/self_repairing
	id = "self_repairing"
	name = "Self-repairing"
	desc = "Slowly regains integrity and quality."
	tier = 4

// ---------------- Negative ----------------

/datum/matsci_trait/heavy
	id = "heavy"
	name = "Heavy"
	desc = "Bulky; slows whoever carries or wears it."
	category = MATSCI_TRAIT_NEGATIVE
	tier = 1
	exclusive_with = list("lightweight")

/datum/matsci_trait/soft
	id = "soft"
	name = "Soft"
	desc = "Lower sharpness and armor."
	category = MATSCI_TRAIT_NEGATIVE
	tier = 1
	exclusive_with = list("dense")

/datum/matsci_trait/soft/apply_stats(var/datum/material/procgen/M, var/strength)
	M.sharpness_mod *= max(0.1, 1 - 0.2 * strength)
	M.armor_mod *= max(0.1, 1 - 0.2 * strength)

// ---------------- Mixed ----------------

/datum/matsci_trait/crystalline
	id = "crystalline"
	name = "Crystalline"
	desc = "Better base stats, but alloys poorly."
	category = MATSCI_TRAIT_MIXED
	tier = 2
	any_tier = TRUE

/datum/matsci_trait/crystalline/apply_stats(var/datum/material/procgen/M, var/strength)
	var/bonus = 1 + 0.1 * strength
	M.brunt_damage_mod *= bonus
	M.sharpness_mod *= bonus
	M.quality_mod *= bonus
	M.armor_mod *= bonus

/datum/matsci_trait/dense
	id = "dense"
	name = "Dense"
	desc = "More blunt damage and armor, less sharpness."
	category = MATSCI_TRAIT_MIXED
	tier = 2
	any_tier = TRUE
	exclusive_with = list("soft")

/datum/matsci_trait/dense/apply_stats(var/datum/material/procgen/M, var/strength)
	M.brunt_damage_mod *= 1 + 0.15 * strength
	M.armor_mod *= 1 + 0.15 * strength
	M.sharpness_mod *= max(0.1, 1 - 0.15 * strength)

/datum/matsci_trait/phasic
	id = "phasic"
	name = "Phasic"
	desc = "Behaves like phazon: on use, may cause an EMP or teleport the target or wielder, and may teleport itself away."
	category = MATSCI_TRAIT_MIXED
	tier = 4
