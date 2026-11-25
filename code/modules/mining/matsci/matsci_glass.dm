// Glass made from glass-primary procgen materials: windows, windoors, table doors and glass floors.
// Each is a /procgen subtype of the normal glass type. Health is the normal type's health times the material's
// armor and quality relative to glass. Breaking one drops a shard of the material, which welds back into a sheet.

/proc/matsci_glass_health_mult(var/datum/material/M)
	var/datum/matsci_settings/S = matsci_settings()
	var/datum/material/glass = material_list[MAT_GLASS]
	var/armor_ratio = M.armor_mod
	var/quality_ratio = M.quality_mod
	if(glass)
		if(glass.armor_mod)
			armor_ratio /= glass.armor_mod
		if(glass.quality_mod)
			quality_ratio /= glass.quality_mod
	armor_ratio = clamp(armor_ratio, S.glass_stat_ratio_min, S.glass_stat_ratio_max)
	quality_ratio = clamp(quality_ratio, S.glass_stat_ratio_min, S.glass_stat_ratio_max)
	return armor_ratio * quality_ratio

/// The glass-primary procgen material with this ID, or null.
/proc/matsci_get_glass_material(var/mat_id)
	var/datum/material/procgen/M = matsci_get_material(mat_id)
	if(M && M.has_primary(MAT_GLASS))
		return M
	return null

/// Makes O out of procgen glass M: material, sheets, name, tint and scaled health.
/proc/matsci_apply_glass(var/obj/O, var/datum/material/procgen/M, var/base_name)
	O.material_type = M
	O.sheet_type = M.sheettype
	O.name = "[lowertext(M.name)] [base_name ? base_name : initial(O.name)]"
	O.color = M.color
	O.maxHealth = max(1, round(initial(O.health) * matsci_glass_health_mult(M), 1))
	O.health = O.maxHealth

/proc/matsci_spawn_shard(var/atom/loc, var/datum/material/procgen/M)
	if(istype(M))
		return new /obj/item/weapon/shard/procgen(loc, M.id)
	return null

// Self-repair. Things made of a self-repairing material join processing_objects while damaged and leave once whole.

/// Health healed per processing tick by things made of M. 0 if M doesn't self-repair.
/proc/matsci_self_repair_rate(var/datum/material/procgen/M)
	if(!istype(M))
		return 0
	var/strength = M.traits["self_repairing"]
	if(!strength)
		return 0
	var/datum/matsci_settings/S = matsci_settings()
	return S.self_repair_per_tick * strength

/proc/matsci_obj_needs_repair(var/obj/O)
	return O.health > 0 && O.health < O.maxHealth && matsci_self_repair_rate(O.material_type)

/// Heals O by one tick. Returns TRUE if it still needs repairing afterwards.
/proc/matsci_obj_repair_tick(var/obj/O)
	if(!matsci_obj_needs_repair(O))
		return FALSE
	O.health = min(O.maxHealth, O.health + matsci_self_repair_rate(O.material_type))
	return O.health < O.maxHealth

// Shards

/// A shard of procgen glass. Holds one sheet's worth of the material and welds back into a sheet.
/obj/item/weapon/shard/procgen
	name = "strange shard"
	desc = "A shard of an unusual glass."
	var/mat_id

/obj/item/weapon/shard/procgen/New(var/loc, var/new_mat_id)
	var/datum/material/procgen/M = matsci_get_material(new_mat_id)
	if(M)
		mat_id = new_mat_id
		material_type = M
		name = "[lowertext(M.name)] shard"
		desc = "A shard of [lowertext(M.name)]. Could probably be welded back into a sheet."
		color = M.color
		melt_temperature = M.melt_temperature
		glass = M.sheettype
		starting_materials = list()
		starting_materials[mat_id] = M.cc_per_sheet
	..(loc)

/obj/item/weapon/shard/procgen/attackby(obj/item/weapon/W, mob/user)
	if(iswelder(W))
		var/obj/item/tool/weldingtool/WT = W
		if(mat_id && WT.remove_fuel(0, user))
			drop_material_stack(glass, user.loc, 1, mat_id, user)
			qdel(src)
		return
	return ..()

/obj/item/weapon/shard/procgen/examine(mob/user)
	..()
	matsci_examine_material(user, material_type)

// Windows. Directional and full windows are separate branches, so both subtypes forward to these procs.

/proc/matsci_window_set_material(var/obj/structure/window/W, var/mat_id)
	var/datum/material/procgen/M = matsci_get_glass_material(mat_id)
	if(!M)
		return FALSE
	matsci_apply_glass(W, M)
	W.healthcheck(null, FALSE)
	return TRUE

/proc/matsci_window_drop_sheets(var/obj/structure/window/W, var/turf/T, var/mob/user)
	var/datum/material/procgen/M = W.material_type
	if(istype(M))
		drop_material_stack(M.sheettype, T, W.sheetamount, M.id, user)

/proc/matsci_window_smart_toggle(var/obj/structure/window/W)
	if(W.opacity)
		animate(W, color = (W.material_type ? W.material_type.color : "#FFFFFF"), time = 5)
		W.set_opacity(0)
	else
		animate(W, color = "#222222", time = 5)
		W.set_opacity(1)
	return W.opacity

/obj/structure/window/procgen
	var/is_self_repairing = FALSE

/obj/structure/window/procgen/loose
	anchored = 0
	d_state = 0

/obj/structure/window/procgen/matsci_set_material(var/mat_id)
	return matsci_window_set_material(src, mat_id)

/obj/structure/window/procgen/drop_glass_sheets(var/turf/T, var/mob/user)
	matsci_window_drop_sheets(src, T, user)

/obj/structure/window/procgen/spawnBrokenPieces()
	return matsci_spawn_shard(loc, material_type)

/obj/structure/window/procgen/smart_toggle()
	return matsci_window_smart_toggle(src)

/obj/structure/window/procgen/examine(mob/user)
	..()
	matsci_examine_material(user, material_type)

/obj/structure/window/procgen/healthcheck(var/mob/M, var/sound = 1)
	..()
	if(!gcDestroyed && !is_self_repairing && matsci_obj_needs_repair(src))
		is_self_repairing = TRUE
		processing_objects += src

/obj/structure/window/procgen/process()
	var/still_damaged = matsci_obj_repair_tick(src)
	healthcheck(null, FALSE)
	if(!still_damaged)
		is_self_repairing = FALSE
		processing_objects -= src

/obj/structure/window/full/procgen
	var/is_self_repairing = FALSE

/obj/structure/window/full/procgen/loose
	anchored = 0
	d_state = 0

/obj/structure/window/full/procgen/matsci_set_material(var/mat_id)
	return matsci_window_set_material(src, mat_id)

/obj/structure/window/full/procgen/drop_glass_sheets(var/turf/T, var/mob/user)
	matsci_window_drop_sheets(src, T, user)

/obj/structure/window/full/procgen/spawnBrokenPieces()
	return matsci_spawn_shard(loc, material_type)

/obj/structure/window/full/procgen/smart_toggle()
	return matsci_window_smart_toggle(src)

/obj/structure/window/full/procgen/examine(mob/user)
	..()
	matsci_examine_material(user, material_type)

/obj/structure/window/full/procgen/healthcheck(var/mob/M, var/sound = 1)
	..()
	if(!gcDestroyed && !is_self_repairing && matsci_obj_needs_repair(src))
		is_self_repairing = TRUE
		processing_objects += src

/obj/structure/window/full/procgen/process()
	var/still_damaged = matsci_obj_repair_tick(src)
	healthcheck(null, FALSE)
	if(!still_damaged)
		is_self_repairing = FALSE
		processing_objects -= src

// Windoors

/obj/structure/windoor_assembly/procgen
	windoor_type = /obj/machinery/door/window/procgen
	secure_type = /obj/machinery/door/window/procgen/secure

/obj/structure/windoor_assembly/procgen/secure
	secure = TRUE

/obj/structure/windoor_assembly/procgen/matsci_set_material(var/mat_id)
	var/datum/material/procgen/M = matsci_get_glass_material(mat_id)
	if(!M)
		return FALSE
	material_type = M
	glass_type = M.sheettype
	color = M.color
	update_name()
	return TRUE

/obj/structure/windoor_assembly/procgen/update_name()
	..()
	if(material_type)
		name = replacetext(name, initial(name), "[lowertext(material_type.name)] [initial(name)]")

/obj/structure/windoor_assembly/procgen/drop_glass_sheets(var/amount)
	var/datum/material/procgen/M = material_type
	if(istype(M))
		drop_material_stack(M.sheettype, loc, amount, M.id)

/obj/structure/windoor_assembly/procgen/make_windoor(var/mob/user)
	var/obj/machinery/door/window/windoor = ..()
	var/datum/material/procgen/M = material_type
	if(windoor && istype(M))
		windoor.matsci_set_material(M.id)
	return windoor

/obj/structure/windoor_assembly/procgen/examine(mob/user)
	..()
	matsci_examine_material(user, material_type)

/obj/machinery/door/window/procgen
	assembly_type = /obj/structure/windoor_assembly/procgen
	var/is_self_repairing = FALSE

/obj/machinery/door/window/procgen/secure
	name = "secure window door"
	icon_state = "leftsecure"
	base_state = "leftsecure"
	secure = TRUE
	health = 100
	assembly_type = /obj/structure/windoor_assembly/procgen/secure
	penetration_dampening = 4
	normalspeed = 0

/obj/machinery/door/window/procgen/matsci_set_material(var/mat_id)
	var/datum/material/procgen/M = matsci_get_glass_material(mat_id)
	if(!M)
		return FALSE
	matsci_apply_glass(src, M)
	return TRUE

/obj/machinery/door/window/procgen/set_assembly(var/obj/structure/windoor_assembly/WA)
	..()
	var/datum/material/procgen/M = material_type
	if(istype(M))
		WA.matsci_set_material(M.id)

/obj/machinery/door/window/procgen/try_break()
	if(health <= 0)
		playsound(src, "shatter", 70, 1)
		matsci_spawn_shard(loc, material_type)
		new /obj/item/stack/cable_coil(loc, 2)
		eject_electronics()
		qdel(src)
		return TRUE
	if(!is_self_repairing && matsci_obj_needs_repair(src))
		is_self_repairing = TRUE
		processing_objects += src
	return FALSE

/obj/machinery/door/window/procgen/process()
	if(!matsci_obj_repair_tick(src))
		is_self_repairing = FALSE
		processing_objects -= src

/obj/machinery/door/window/procgen/examine(mob/user)
	..()
	matsci_examine_material(user, material_type)

// Table doors. They're made of the procgen material alone, so breaking one leaves just a shard.

/obj/machinery/door/table/glass/procgen
	name = "table door"
	var/is_self_repairing = FALSE

/obj/machinery/door/table/glass/procgen/matsci_set_material(var/mat_id)
	var/datum/material/procgen/M = matsci_get_glass_material(mat_id)
	if(!M)
		return FALSE
	matsci_apply_glass(src, M)
	return TRUE

/obj/machinery/door/table/glass/procgen/checkhealth()
	if(health <= 0)
		playsound(src, "shatter", 50, 1)
		dismantle()
		return
	start_self_repair()

/obj/machinery/door/table/glass/procgen/check_cover(obj/item/projectile/P, turf/from)
	. = ..()
	if(!gcDestroyed)
		start_self_repair()

/obj/machinery/door/table/glass/procgen/dismantle()
	remove_electronics()
	var/datum/material/procgen/M = material_type
	if(istype(M))
		if(health <= 0)
			matsci_spawn_shard(loc, M)
		else
			drop_material_stack(M.sheettype, loc, sheet_amt, M.id)
	qdel(src)

/obj/machinery/door/table/glass/procgen/proc/start_self_repair()
	if(!is_self_repairing && matsci_obj_needs_repair(src))
		is_self_repairing = TRUE
		processing_objects += src

/obj/machinery/door/table/glass/procgen/process()
	if(!matsci_obj_repair_tick(src))
		is_self_repairing = FALSE
		processing_objects -= src

/obj/machinery/door/table/glass/procgen/examine(mob/user)
	..()
	matsci_examine_material(user, material_type)

// Glass floors

/turf/simulated/floor/glass/procgen
	var/matsci_mat_id
	var/is_self_repairing = FALSE

/turf/simulated/floor/glass/procgen/airless
	icon_state = "floor"
	oxygen = 0.01
	nitrogen = 0.01
	temperature = TCMB

/turf/simulated/floor/glass/procgen/matsci_set_material(var/mat_id)
	var/datum/material/procgen/M = matsci_get_glass_material(mat_id)
	if(!M)
		return FALSE
	matsci_mat_id = mat_id
	sheettype = M.sheettype
	name = "[lowertext(M.name)] [initial(name)]"
	max_health = max(1, round(initial(health) * matsci_glass_health_mult(M), 1))
	health = max_health
	overlays -= floor_overlays[glass_state]
	var/overlay_key = "[glass_state]-[M.color]"
	if(!floor_overlays[overlay_key])
		var/image/floor_overlay = image('icons/turf/overlays.dmi', glass_state)
		floor_overlay.plane = GLASSTILE_PLANE
		floor_overlay.color = M.color
		floor_overlays[overlay_key] = floor_overlay
	overlays += floor_overlays[overlay_key]
	update_icon()
	return TRUE

/turf/simulated/floor/glass/procgen/drop_glass_sheets()
	if(matsci_mat_id)
		drop_material_stack(sheettype, src, sheetamount, matsci_mat_id)

/turf/simulated/floor/glass/procgen/spawnBrokenPieces(var/turf/T)
	matsci_spawn_shard(T, matsci_get_material(matsci_mat_id))
	new /obj/item/stack/rods(T, 1) // The lattice; the glass itself has no rods in it

/turf/simulated/floor/glass/procgen/healthcheck(var/mob/M, var/sound = 1, var/method="unknown", var/no_teleport=TRUE)
	if(health > 0 && health < max_health && !is_self_repairing && matsci_self_repair_rate(matsci_get_material(matsci_mat_id)))
		is_self_repairing = TRUE
		processing_objects += src
	return ..()

/turf/simulated/floor/glass/procgen/process()
	var/rate = matsci_self_repair_rate(matsci_get_material(matsci_mat_id))
	if(rate && health > 0 && health < max_health)
		health = min(max_health, health + rate)
		update_icon()
	if(!rate || health <= 0 || health >= max_health)
		stop_self_repair()

/turf/simulated/floor/glass/procgen/proc/stop_self_repair()
	is_self_repairing = FALSE
	processing_objects -= src

/turf/simulated/floor/glass/procgen/ChangeTurf(var/turf/N, var/tell_universe=1, var/force_lighting_update = 0, var/allow = 1, var/defer_edges = FALSE)
	stop_self_repair() // This turf is about to become something else
	return ..()

/turf/simulated/floor/glass/procgen/examine(var/mob/user)
	..()
	matsci_examine_material(user, matsci_get_material(matsci_mat_id))

/obj/item/stack/tile/rglass/procgen
	name = "strange glass tile"
	desc = "A clear tile of an unusual glass."
	singular_name = "strange glass tile"
	air_type = /turf/simulated/floor/glass/procgen
	airless_type = /turf/simulated/floor/glass/procgen/airless
	var/mat_id

/obj/item/stack/tile/rglass/procgen/New(var/loc, var/amount = null, var/new_mat_id = null)
	if(new_mat_id)
		apply_material_vars(new_mat_id)
	..(loc, amount)

/obj/item/stack/tile/rglass/procgen/proc/apply_material_vars(var/new_mat_id)
	var/datum/material/procgen/M = matsci_get_material(new_mat_id)
	if(!M)
		return FALSE
	mat_id = new_mat_id
	material_type = M
	name = "[lowertext(M.name)] glass tile"
	singular_name = name
	color = M.color
	melt_temperature = M.melt_temperature
	starting_materials = list()
	starting_materials[mat_id] = M.cc_per_sheet
	return TRUE

/obj/item/stack/tile/rglass/procgen/matsci_set_material(var/new_mat_id)
	if(!apply_material_vars(new_mat_id))
		return FALSE
	if(!materials)
		materials = new /datum/materials(src)
	update_materials()
	update_icon()
	return TRUE

/obj/item/stack/tile/rglass/procgen/get_stack_material_id()
	return mat_id

/obj/item/stack/tile/rglass/procgen/create_like(var/atom/new_loc)
	return new type(new_loc, 1, mat_id)

/obj/item/stack/tile/rglass/procgen/can_stack_with(var/obj/item/other_stack)
	if(ispath(other_stack))
		return FALSE
	var/obj/item/stack/tile/rglass/procgen/other = other_stack
	return istype(other) && other.type == type && mat_id && other.mat_id == mat_id

/obj/item/stack/tile/rglass/procgen/transfer_data_from(var/obj/item/stack/S, var/amount)
	..()
	if(!mat_id)
		var/obj/item/stack/tile/rglass/procgen/other = S
		if(istype(other) && other.mat_id)
			matsci_set_material(other.mat_id)

/obj/item/stack/tile/rglass/procgen/examine(mob/user)
	..()
	matsci_examine_material(user, material_type)

/obj/item/stack/tile/rglass/procgen/build(turf/S as turf)
	..()
	var/turf/simulated/floor/glass/G = locate(S.x, S.y, S.z) // S now refers to the new turf, but don't count on it
	if(istype(G))
		G.matsci_set_material(mat_id)
