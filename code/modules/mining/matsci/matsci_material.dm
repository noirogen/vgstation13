/*
 * MATERIAL SCIENCE: PROCEDURALLY GENERATED MATERIALS
 *
 * A /datum/material/procgen is created at runtime (see matsci_generator.dm) and registered into the global
 * material_list under a runtime ID ("$pg1", "$pg2"...). All procgen materials share one ore type and one sheet type;
 * those stacks carry the material ID, so always spawn them through the material's spawn_* procs or drop_material_stack().
 *
 * Everything stored here is plain data (numbers, strings, lists of them) so it can be serialised.
 */

var/list/datum/material/procgen/matsci_materials = list() // All procgen materials this round, in generation order
var/matsci_material_counter = 0

#define MATSCI_ID_PREFIX "$pg"

/proc/matsci_get_material(var/mat_id)
	if(!istext(mat_id))
		return null
	if(!material_list)
		initialize_materials()
	var/datum/material/procgen/M = material_list[mat_id]
	return istype(M) ? M : null

/// Assigns an ID if needed and adds the material to material_list, so material holders and machines accept it.
/proc/matsci_register_material(var/datum/material/procgen/M)
	if(!material_list)
		initialize_materials()
	if(!M.id)
		M.id = "[MATSCI_ID_PREFIX][++matsci_material_counter]"
	material_list[M.id] = M
	if(!matsci_materials)
		matsci_materials = list()
	matsci_materials |= M
	return M

/datum/material/procgen
	name = "unknown material"
	cc_per_sheet = CC_PER_SHEET_MISC
	oretype = /obj/item/stack/ore/procgen
	sheettype = /obj/item/stack/sheet/mineral/procgen
	default_show_in_menus = FALSE

	/// 1 (common, iron-like) to 4 (phazon-like).
	var/tier = 1
	/// Base material IDs this one resembles (0-2 of them).
	var/list/primaries = list()
	/// Trait ID -> rolled strength.
	var/list/traits = list()
	/// Stats and traits are hidden from players until researched.
	var/researched = FALSE
	/// Materials can only be renamed once.
	var/renamed = FALSE

	/// Sprite shape and icon states, picked at generation from matsci_settings().sprite_sets.
	var/sprite_shape
	var/ore_state = "Silver ore"
	var/sheet_state = "sheet-silver"
	var/overlay_state = "Silver"
	var/embed_state = "embed_Silver"

	/// Where this material spawns ("Asteroid", planet names...).
	var/list/found_on = list()

/datum/material/procgen/spawn_sheets(var/atom/loc, var/amount)
	return drop_material_stack(sheettype, loc, amount, id)

/datum/material/procgen/spawn_ore(var/atom/loc, var/amount)
	return drop_material_stack(oretype, loc, amount, id)

/datum/material/procgen/create_sheet(var/atom/loc)
	return new sheettype(loc, 1, id)

/datum/material/procgen/proc/has_trait(var/trait_id)
	return (trait_id in traits)

/datum/material/procgen/proc/has_primary(var/mat_id)
	return (mat_id in primaries)

/// Human-readable names of this material's primary properties, e.g. list("plasmalike").
/datum/material/procgen/proc/primary_names()
	. = list()
	for(var/mat_id in primaries)
		var/datum/material/base = material_list[mat_id]
		. += "[base ? lowertext(base.name) : mat_id]like"

/datum/material/procgen/proc/trait_names(var/with_strength = FALSE)
	. = list()
	for(var/trait_id in traits)
		var/datum/matsci_trait/T = matsci_get_trait(trait_id)
		var/label = T ? T.name : trait_id
		. += with_strength ? "[label] ([traits[trait_id]])" : label

/// Average of the four stat multipliers.
/datum/material/procgen/proc/average_stat()
	return (brunt_damage_mod + sharpness_mod + quality_mod + armor_mod) / 4

/// One-line stat summary.
/datum/material/procgen/proc/stat_summary()
	return "blunt [brunt_damage_mod], sharpness [sharpness_mod], quality [quality_mod], armor [armor_mod], melts at [melt_temperature]K"

/// Text for examining ore or sheets of this material.
/datum/material/procgen/proc/examine_text()
	if(!researched)
		return "<span class='info'>You can't tell much about this material without studying it.</span>"
	. = "<span class='info'>Properties: [stat_summary()].</span>"
	var/list/prim = primary_names()
	if(prim.len)
		. += "<br><span class='info'>Resembles: [english_list(prim)].</span>"
	var/list/tr = trait_names()
	if(tr.len)
		. += "<br><span class='info'>Traits: [english_list(tr)].</span>"

/// Plain-data snapshot of this material.
/datum/material/procgen/proc/serialize()
	return list(
		"id" = id,
		"name" = name,
		"tier" = tier,
		"primaries" = primaries.Copy(),
		"traits" = traits.Copy(),
		"brunt_damage_mod" = brunt_damage_mod,
		"sharpness_mod" = sharpness_mod,
		"quality_mod" = quality_mod,
		"armor_mod" = armor_mod,
		"melt_temperature" = melt_temperature,
		"value" = value,
		"color" = color,
		"sprite_shape" = sprite_shape,
		"ore_state" = ore_state,
		"sheet_state" = sheet_state,
		"overlay_state" = overlay_state,
		"embed_state" = embed_state,
		"researched" = researched,
		"renamed" = renamed,
	)

/// Restores a material from serialize() output. Does not register it.
/datum/material/procgen/proc/deserialize(var/list/data)
	id = data["id"]
	name = data["name"]
	processed_name = name
	tier = data["tier"]
	var/list/prim = data["primaries"]
	primaries = prim ? prim.Copy() : list()
	var/list/tr = data["traits"]
	traits = tr ? tr.Copy() : list()
	brunt_damage_mod = data["brunt_damage_mod"]
	sharpness_mod = data["sharpness_mod"]
	quality_mod = data["quality_mod"]
	armor_mod = data["armor_mod"]
	melt_temperature = data["melt_temperature"]
	value = data["value"]
	color = data["color"]
	sprite_shape = data["sprite_shape"]
	ore_state = data["ore_state"]
	sheet_state = data["sheet_state"]
	overlay_state = data["overlay_state"]
	embed_state = data["embed_state"]
	researched = data["researched"]
	renamed = data["renamed"]

#undef MATSCI_ID_PREFIX
