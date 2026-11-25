// Crafting with procgen sheets. Every procgen sheet can make blacksmithing parts;
// glass-primary materials can also make windows, windoors, table doors and glass floor tiles.
// None of this needs the material to be researched.

var/list/datum/stack_recipe/matsci_sheet_recipes_cache
var/list/datum/stack_recipe/matsci_glass_sheet_recipes_cache

/// The recipe list for a procgen sheet. Recipes read the material off the stack, so the lists are shared.
/proc/matsci_sheet_recipes(var/datum/material/procgen/M)
	if(istype(M) && M.has_primary(MAT_GLASS))
		if(!matsci_glass_sheet_recipes_cache)
			matsci_glass_sheet_recipes_cache = list(
				new/datum/stack_recipe/matsci("window", /obj/structure/window/procgen/loose, 1, time = 10, on_floor = TRUE),
				new/datum/stack_recipe/matsci("full window", /obj/structure/window/full/procgen/loose, 2, time = 10, on_floor = TRUE),
				new/datum/stack_recipe/matsci("windoor", /obj/structure/windoor_assembly/procgen, 5, time = 10, start_unanchored = TRUE, on_floor = TRUE),
				new/datum/stack_recipe/table_door/matsci("table door", /obj/machinery/door/table/glass/procgen, 2, one_per_turf = TRUE, on_floor = TRUE),
				new/datum/stack_recipe/matsci("glass tile", /obj/item/stack/tile/rglass/procgen, 1, time = 2, on_floor = TRUE),
				null,
				blacksmithing_recipes,
				)
		return matsci_glass_sheet_recipes_cache
	if(!matsci_sheet_recipes_cache)
		matsci_sheet_recipes_cache = list(blacksmithing_recipes)
	return matsci_sheet_recipes_cache

/// Recipe whose result takes on the procgen material of the stack it was built from.
/datum/stack_recipe/matsci

/datum/stack_recipe/matsci/make_stack_result(var/mob/user, var/obj/item/stack/S, var/turf/construct_loc, var/amount)
	// Made with the material already set, so it joins a stack of the same material like drop_stack() would
	var/obj/item/stack/SS = drop_material_stack(result_type, construct_loc, amount, S.get_stack_material_id(), user)
	SS.update_materials()
	return SS

/datum/stack_recipe/matsci/finish_building(var/mob/user, var/obj/item/stack/S, var/atom/R)
	if(!istype(R, /obj/item/stack)) // Stack results got their material in make_stack_result()
		S.apply_material_to(R)
	return ..()

/datum/stack_recipe/table_door/matsci/finish_building(var/mob/user, var/obj/item/stack/S, var/obj/R)
	S.apply_material_to(R)
	return ..()

/// Makes this atom out of the given procgen material. Returns FALSE if the atom can't be made of it.
/atom/proc/matsci_set_material(var/mat_id)
	return FALSE

/obj/item/stack/sheet/mineral/procgen/apply_material_to(var/atom/A)
	if(mat_id && A)
		A.matsci_set_material(mat_id)

/datum/material/procgen/apply_material_appearance(var/obj/O)
	if(color && !istype(O, /obj/item/stack)) // Stacks can merge with stacks of other materials, so leave them untinted
		O.color = color

/datum/material/procgen/apply_sheet_appearance(var/atom/A)
	A.icon_state = sheet_state
	A.color = color

/// Shows a procgen material's details when examining something made of it.
/proc/matsci_examine_material(var/mob/user, var/datum/material/procgen/M)
	if(istype(M))
		to_chat(user, M.examine_text())
