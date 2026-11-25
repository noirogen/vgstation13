/*
 * MATERIAL SCIENCE: ORE AND SHEETS
 *
 * Every procgen material uses these two stack types. Each stack carries its material ID (mat_id), and only stacks
 * of the same material merge. Create them with new type(loc, amount, mat_id), drop_material_stack(), or the
 * material's spawn_ore()/spawn_sheets(); a plain new type(loc) gives a blank stack until it gets a material.
 */

/**
 * drop_stack() for stack types shared by several materials. Adds to an existing stack of the same type and
 * material in loc if there is room, otherwise makes new stacks. Returns the last stack touched.
 */
/proc/drop_material_stack(var/stack_type, var/atom/loc, var/add_amount = 1, var/mat_id, var/mob/user)
	if(!mat_id)
		return drop_stack(stack_type, loc, add_amount, user)
	if(add_amount <= 0)
		return null
	for(var/obj/item/stack/S in loc)
		if(S.gcDestroyed || S.amount <= 0) // Emptied stacks are deleted a tick later; don't add to them
			continue
		if(S.type == stack_type && S.get_stack_material_id() == mat_id && S.max_amount >= S.amount + add_amount)
			S.add(add_amount)
			S.update_icon()
			if(user)
				to_chat(user, "<span class='info'>You add [add_amount] item\s to the stack. It now contains [S.amount] [S.correct_name()].</span>")
			return S
	var/obj/item/stack/S
	while(add_amount > 0)
		S = new stack_type(loc, 1, mat_id)
		var/chunk = min(add_amount, S.max_amount)
		S.amount = chunk
		add_amount -= chunk
		S.update_materials()
		S.update_icon()
	return S

/**
 * Turns any procgen materials in a materials holder into sheets at out. Base materials are left for smelting recipes.
 * Returns how many sheets were made. If unit is set, its credit bookkeeping is kept in step (recycler).
 */
/proc/matsci_smelt_procgen(var/datum/materials/ore, var/atom/out, var/max_sheets = INFINITY, var/obj/machinery/mineral/processing_unit/unit = null)
	. = 0
	if(!ore)
		return
	for(var/mat_id in ore.storage)
		if(. >= max_sheets)
			break
		var/datum/material/procgen/M = matsci_get_material(mat_id)
		if(!M)
			continue
		var/sheets = min(round(ore.storage[mat_id] / M.cc_per_sheet), max_sheets - .)
		if(sheets <= 0)
			continue
		if(unit)
			unit.remove_from_credits_if_necessary(mat_id, ore.getValueByAmount(mat_id, sheets * M.cc_per_sheet))
		ore.removeAmount(mat_id, sheets * M.cc_per_sheet)
		score.oremined += sheets
		M.spawn_sheets(out, sheets)
		. += sheets

// ---------------- Ore ----------------

/obj/item/stack/ore/procgen
	name = "\improper strange ore"
	icon_state = "Silver ore"
	origin_tech = Tc_MATERIALS + "=3"
	var/mat_id

/obj/item/stack/ore/procgen/New(var/loc, var/amount = null, var/new_mat_id = null)
	if(new_mat_id)
		apply_material_vars(new_mat_id)
	..(loc, amount) // ore/New() adds the name to singular_name, so the name must be set before this

/// Sets name, sprite and starting materials from the material. Called before ..() in New(), so no materials datum yet.
/obj/item/stack/ore/procgen/proc/apply_material_vars(var/new_mat_id)
	var/datum/material/procgen/M = matsci_get_material(new_mat_id)
	if(!M)
		return FALSE
	mat_id = new_mat_id
	material_type = M
	name = "\improper [lowertext(M.name)] ore"
	icon_state = M.ore_state
	color = M.color
	melt_temperature = M.melt_temperature
	starting_materials = list()
	starting_materials[mat_id] = M.cc_per_sheet
	return TRUE

/// Gives an already-created blank stack a material (e.g. after a split).
/obj/item/stack/ore/procgen/proc/set_material(var/new_mat_id)
	if(!apply_material_vars(new_mat_id))
		return FALSE
	singular_name = initial(singular_name) + name
	irregular_plural = initial(irregular_plural) + name
	if(!materials)
		materials = new /datum/materials(src)
	update_materials()
	update_icon()
	return TRUE

/obj/item/stack/ore/procgen/get_stack_material_id()
	return mat_id

/obj/item/stack/ore/procgen/create_like(var/atom/new_loc)
	return new type(new_loc, 1, mat_id)

/obj/item/stack/ore/procgen/can_stack_with(var/obj/item/other_stack)
	if(ispath(other_stack)) // Paths carry no material, so never merge on type alone
		return FALSE
	var/obj/item/stack/ore/procgen/other = other_stack
	return istype(other) && other.type == type && mat_id && other.mat_id == mat_id

/obj/item/stack/ore/procgen/transfer_data_from(var/obj/item/stack/S, var/amount)
	..()
	if(!mat_id)
		var/obj/item/stack/ore/procgen/other = S
		if(istype(other) && other.mat_id)
			set_material(other.mat_id)

/obj/item/stack/ore/procgen/examine(mob/user)
	..()
	var/datum/material/procgen/M = matsci_get_material(mat_id)
	if(M)
		to_chat(user, M.examine_text())

// ---------------- Sheets ----------------

/obj/item/stack/sheet/mineral/procgen
	name = "strange sheets"
	singular_name = "strange sheet"
	icon_state = "sheet-silver"
	force = 5.0
	throwforce = 5
	w_class = W_CLASS_MEDIUM
	throw_speed = 3
	throw_range = 3
	origin_tech = Tc_MATERIALS + "=3"
	perunit = CC_PER_SHEET_MISC
	var/mat_id

/obj/item/stack/sheet/mineral/procgen/New(var/loc, var/amount = null, var/new_mat_id = null)
	if(new_mat_id)
		apply_material_vars(new_mat_id)
	..(loc, amount)

/obj/item/stack/sheet/mineral/procgen/proc/apply_material_vars(var/new_mat_id)
	var/datum/material/procgen/M = matsci_get_material(new_mat_id)
	if(!M)
		return FALSE
	mat_id = new_mat_id
	mat_type = new_mat_id
	material_type = M
	name = lowertext(M.name)
	singular_name = "[lowertext(M.name)] sheet"
	icon_state = M.sheet_state
	color = M.color
	melt_temperature = M.melt_temperature
	perunit = M.cc_per_sheet
	starting_materials = list()
	starting_materials[mat_id] = M.cc_per_sheet
	recipes = matsci_sheet_recipes(M)
	return TRUE

/obj/item/stack/sheet/mineral/procgen/proc/set_material(var/new_mat_id)
	if(!apply_material_vars(new_mat_id))
		return FALSE
	if(!materials)
		materials = new /datum/materials(src)
	update_materials()
	update_icon()
	return TRUE

/obj/item/stack/sheet/mineral/procgen/get_stack_material_id()
	return mat_id

/obj/item/stack/sheet/mineral/procgen/create_like(var/atom/new_loc)
	return new type(new_loc, 1, mat_id)

/obj/item/stack/sheet/mineral/procgen/can_stack_with(var/obj/item/other_stack)
	if(ispath(other_stack))
		return FALSE
	var/obj/item/stack/sheet/mineral/procgen/other = other_stack
	return istype(other) && other.type == type && mat_id && other.mat_id == mat_id

/obj/item/stack/sheet/mineral/procgen/transfer_data_from(var/obj/item/stack/S, var/amount)
	..()
	if(!mat_id)
		var/obj/item/stack/sheet/mineral/procgen/other = S
		if(istype(other) && other.mat_id)
			set_material(other.mat_id)

/obj/item/stack/sheet/mineral/procgen/examine(mob/user)
	..()
	var/datum/material/procgen/M = matsci_get_material(mat_id)
	if(M)
		to_chat(user, M.examine_text())
