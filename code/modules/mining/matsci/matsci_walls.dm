// Walls and false walls plated with procgen materials. They use the silver wall sprites, tinted with the material colour.

/obj/item/stack/sheet/mineral/procgen/get_wall_path(var/false_wall = FALSE)
	if(!mat_id)
		return null
	return false_wall ? /obj/structure/falsewall/procgen : /turf/simulated/wall/mineral/procgen

/turf/simulated/wall/mineral/procgen
	name = "strange wall"
	desc = "A wall with plating of an unusual material."
	icon_state = "silver0"
	walltype = "silver"
	mineral = "procgen"
	var/matsci_mat_id

/turf/simulated/wall/mineral/procgen/matsci_set_material(var/mat_id)
	var/datum/material/procgen/M = matsci_get_material(mat_id)
	if(!M)
		return FALSE
	matsci_mat_id = mat_id
	name = "[lowertext(M.name)] wall"
	desc = "A wall with [lowertext(M.name)] plating."
	color = M.color
	return TRUE

/turf/simulated/wall/mineral/procgen/examine(mob/user)
	..()
	matsci_examine_material(user, matsci_get_material(matsci_mat_id))

/turf/simulated/wall/mineral/procgen/get_sheet_type()
	return null // Sheets need the material, so dismantle_wall drops them itself

/turf/simulated/wall/mineral/procgen/dismantle_wall(devastated = 0, explode = 0)
	if(matsci_mat_id)
		drop_material_stack(/obj/item/stack/sheet/mineral/procgen, src, 2, matsci_mat_id)
	return ..()

/obj/structure/falsewall/procgen
	name = "strange wall"
	desc = "A wall with plating of an unusual material."
	icon_state = ""
	mineral = "silver" // Sprite set; the material is material_type

/obj/structure/falsewall/procgen/matsci_set_material(var/mat_id)
	var/datum/material/procgen/M = matsci_get_material(mat_id)
	if(!M)
		return FALSE
	material_type = M
	sheet_type = M.sheettype
	name = "[lowertext(M.name)] wall"
	desc = "A wall with [lowertext(M.name)] plating."
	color = M.color
	return TRUE

/obj/structure/falsewall/procgen/examine(mob/user)
	..()
	matsci_examine_material(user, material_type)

/obj/structure/falsewall/procgen/make_wall(var/turf/T)
	T.ChangeTurf(/turf/simulated/wall/mineral/procgen)
	var/datum/material/procgen/M = material_type
	if(istype(M))
		var/turf/new_wall = locate(T.x, T.y, T.z)
		new_wall.matsci_set_material(M.id)

/obj/structure/falsewall/procgen/dismantle()
	var/turf/T = get_turf(src)
	if(!T)
		return
	var/datum/material/procgen/M = material_type
	if(istype(M))
		drop_material_stack(M.sheettype, T, 2, M.id)
	new /obj/structure/girder/displaced(T)
	qdel(src)
