/*
 * MATERIAL SCIENCE: MINERAL DEPOSITS
 *
 * One /mineral/procgen per material per place it spawns (the asteroid, each planet), so each place can have its own
 * vein size. Deposits drop ore through drop_material_stack() so the ore keeps its material, and draw a tinted overlay.
 */

/mineral/procgen
	ore = /obj/item/stack/ore/procgen
	result_amount = 5
	fortune_multiplier = 2
	var/mat_id
	var/tier = 1

/mineral/procgen/New(var/datum/material/procgen/M, var/new_spread_chance)
	var/datum/matsci_settings/S = matsci_settings()
	result_amount = S.ore_per_turf
	fortune_multiplier = S.fortune_multiplier
	if(istype(M))
		mat_id = M.id
		tier = M.tier
		name = M.name
		display_name = M.name
		spread_chance = new_spread_chance
	..()

/mineral/procgen/proc/get_material()
	return matsci_get_material(mat_id)

/mineral/procgen/drop_ore_stack(var/turf/unsimulated/mineral/T)
	return drop_material_stack(ore, T, result_amount, mat_id)

/mineral/procgen/get_material_id()
	return mat_id

/mineral/procgen/get_overlay_image()
	var/datum/material/procgen/M = get_material()
	var/image/I = image('icons/turf/mine_overlays.dmi', M ? M.overlay_state : "Silver")
	if(M)
		I.color = M.color
	return I

/mineral/procgen/get_scan_state(var/embedded = FALSE)
	var/datum/material/procgen/M = get_material()
	if(!M)
		return ..()
	return embedded ? M.embed_state : M.overlay_state

/mineral/procgen/get_scan_color()
	var/datum/material/procgen/M = get_material()
	return M ? M.color : null
