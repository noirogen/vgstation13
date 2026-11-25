// Procedurally generated materials: generation rules, storage, stack identity, smelting.

/datum/unit_test/matsci/start()

/datum/unit_test/matsci/generation/start()
	var/datum/matsci_settings/S = matsci_settings()
	var/list/stat_names = list("brunt_damage_mod", "sharpness_mod", "quality_mod", "armor_mod")
	for(var/tier in 1 to 4)
		var/low = S.stat_floor_by_tier[tier]
		var/high = S.stat_ceiling_by_tier[tier]
		var/average = (low + high) / 2
		for(var/i in 1 to 25)
			// No primaries or traits, so the stats are the raw roll (traits like Dense modify them afterwards).
			var/datum/material/procgen/M = matsci_generate_material(tier, list(), list())
			if(!M.id || material_list[M.id] != M)
				fail("[M.name] was not registered in material_list")
			if(M.tier != tier)
				fail("[M.name] has tier [M.tier], expected [tier]")
			var/best = 0
			for(var/stat in stat_names)
				var/value = M.vars[stat]
				best = max(best, value)
				if(value < low || value > high)
					fail("[M.name] (T[tier]) [stat] = [value], outside [low]-[high]")
			if(best < average)
				fail("[M.name] (T[tier]) has no stat at or above the tier average [average]")
			if(M.melt_temperature < S.melt_min_by_tier[tier] || M.melt_temperature > S.melt_max_by_tier[tier])
				fail("[M.name] (T[tier]) melts at [M.melt_temperature], outside its tier band")

	var/list/seen = list()
	for(var/datum/material/procgen/M in matsci_materials)
		var/key = lowertext(M.name)
		if(seen[key])
			fail("Duplicate procgen material name: [M.name]")
		seen[key] = TRUE

/datum/unit_test/matsci/explosive_tier/start()
	// Round-threatening traits never roll below their minimum material tier.
	for(var/i in 1 to 200)
		var/tier = (i % 2) + 1
		var/list/traits = matsci_roll_traits(tier, null)
		if("explosive" in traits)
			fail("Explosive rolled on a tier [tier] material")
			return

/datum/unit_test/matsci/melt_bands/start()
	var/datum/matsci_settings/S = matsci_settings()
	for(var/tier in 2 to 4)
		if(S.melt_min_by_tier[tier] <= S.melt_min_by_tier[tier - 1])
			fail("Tier [tier] minimum melting point is not above tier [tier - 1]'s")
		if(S.melt_max_by_tier[tier] <= S.melt_max_by_tier[tier - 1])
			fail("Tier [tier] maximum melting point is not above tier [tier - 1]'s")
	for(var/tier in 1 to 4)
		if(S.melt_max_by_tier[tier] * 0.9 > TEMPERATURE_WELDER)
			fail("Tier [tier] materials can melt above what a welder can smith")

/datum/unit_test/matsci/storage/start()
	var/datum/material/procgen/M = matsci_generate_material(1, list(), list())
	var/datum/materials/holder = new
	assert_eq(holder.getAmount(M.id), 0)
	holder.addAmount(M.id, 100)
	assert_eq(holder.getAmount(M.id), 100)
	var/datum/materials/other = new
	other.addFrom(holder, TRUE)
	assert_eq(other.getAmount(M.id), 100)
	assert_eq(holder.getAmount(M.id), 0)
	qdel(holder)
	qdel(other)

/datum/unit_test/matsci/stacks/start()
	var/turf/T = run_loc_bottom_left
	var/datum/material/procgen/A = matsci_generate_material(1, list(), list())
	var/datum/material/procgen/B = matsci_generate_material(1, list(), list())

	var/obj/item/stack/ore/procgen/ore_a = drop_material_stack(/obj/item/stack/ore/procgen, T, 10, A.id)
	var/obj/item/stack/ore/procgen/ore_b = drop_material_stack(/obj/item/stack/ore/procgen, T, 10, B.id)
	if(ore_a == ore_b)
		fail("Ores of two different materials merged")
	assert_eq(ore_a.mat_id, A.id)
	assert_eq(ore_b.mat_id, B.id)
	if(ore_a.can_stack_with(ore_b))
		fail("can_stack_with() allows ores of different materials")

	var/obj/item/stack/ore/procgen/more_a = drop_material_stack(/obj/item/stack/ore/procgen, T, 5, A.id)
	assert_eq(more_a, ore_a)
	assert_eq(ore_a.amount, 15)
	assert_eq(ore_a.materials.getAmount(A.id), 15 * A.cc_per_sheet)

	var/obj/item/stack/ore/procgen/copy = ore_a.create_like(null)
	assert_eq(copy.mat_id, A.id)
	assert_eq(copy.amount, 1)
	qdel(copy)

	var/obj/structure/ore_box/box = new(T)
	box.try_add_ore(ore_a)
	box.try_add_ore(ore_b)
	assert_eq(box.stored_ores[A.id], 15)
	assert_eq(box.stored_ores[B.id], 10)
	qdel(ore_a)
	qdel(ore_b)

	box.dump_everything()
	var/list/totals = list()
	for(var/obj/item/stack/ore/procgen/O in T)
		if(O.gcDestroyed)
			continue
		totals[O.mat_id] += O.amount
	assert_eq(totals[A.id], 15)
	assert_eq(totals[B.id], 10)

/datum/unit_test/matsci/smelting/start()
	var/turf/T = run_loc_bottom_left
	var/datum/material/procgen/M = matsci_generate_material(2, list(), list())
	var/datum/materials/ore = new
	ore.addAmount(M.id, M.cc_per_sheet * 7 + 5)
	assert_eq(matsci_smelt_procgen(ore, T), 7)
	var/obj/item/stack/sheet/mineral/procgen/sheet = locate(/obj/item/stack/sheet/mineral/procgen) in T
	if(!sheet)
		fail("No procgen sheets were made")
		return
	assert_eq(sheet.mat_id, M.id)
	assert_eq(sheet.amount, 7)
	assert_eq(ore.getAmount(M.id), 5)
	qdel(ore)

/// How many things of exactly this type (summing stack amounts) are on T, optionally only of one procgen material. Ignores deleted things.
/proc/matsci_test_count(var/turf/T, var/thing_type, var/mat_id)
	. = 0
	for(var/atom/movable/A in T)
		if(A.gcDestroyed || A.type != thing_type)
			continue
		if(mat_id && (!("mat_id" in A.vars) || A.vars["mat_id"] != mat_id))
			continue
		if(istype(A, /obj/item/stack))
			var/obj/item/stack/S = A
			. += S.amount
		else
			. += 1

/datum/unit_test/matsci/sheet_recipes/start()
	var/datum/material/procgen/plain = matsci_generate_material(1, list(MAT_IRON), list())
	var/datum/material/procgen/glassy = matsci_generate_material(1, list(MAT_GLASS), list())
	var/obj/item/stack/sheet/mineral/procgen/plain_sheet = new(null, 1, plain.id)
	var/obj/item/stack/sheet/mineral/procgen/glass_sheet = new(null, 1, glassy.id)
	if(!(blacksmithing_recipes in plain_sheet.recipes))
		fail("Procgen sheets can't be used for blacksmithing")
	if(!(blacksmithing_recipes in glass_sheet.recipes))
		fail("Glass-primary procgen sheets can't be used for blacksmithing")
	var/found_window = FALSE
	for(var/datum/stack_recipe/R in glass_sheet.recipes)
		if(R.result_type == /obj/structure/window/procgen/loose)
			found_window = TRUE
	if(!found_window)
		fail("Glass-primary procgen sheets can't make windows")
	for(var/datum/stack_recipe/R in plain_sheet.recipes)
		if(R.result_type == /obj/structure/window/procgen/loose)
			fail("Procgen sheets without the glass primary can make windows")
		// Recipes with these set are hidden on maps without the matching z-level
		if(R.z_up_required || R.z_down_required)
			fail("Procgen recipe [R.title] needs a z-level above or below")
	qdel(plain_sheet)
	qdel(glass_sheet)

/datum/unit_test/matsci/glass_variants/start()
	var/turf/T = run_loc_bottom_left
	var/datum/material/procgen/M = matsci_generate_material(2, list(MAT_GLASS), list())
	var/datum/material/procgen/not_glass = matsci_generate_material(2, list(MAT_IRON), list())
	var/obj/structure/window/procgen/W = new /obj/structure/window/procgen/loose(T)
	if(W.matsci_set_material(not_glass.id))
		fail("A window was made of a material without the glass primary")
	if(!W.matsci_set_material(M.id))
		fail("A window couldn't be made of a glass-primary material")
		return
	var/expected = max(1, round(initial(W.health) * matsci_glass_health_mult(M), 1))
	assert_eq(W.maxHealth, expected)
	assert_eq(W.health, expected)
	if(!findtext(W.name, lowertext(M.name)))
		fail("Procgen window is called [W.name]")

	W.drop_glass_sheets(T)
	assert_eq(matsci_test_count(T, /obj/item/stack/sheet/mineral/procgen, M.id), W.sheetamount)

	var/glass_shards = matsci_test_count(T, /obj/item/weapon/shard)
	var/obj/item/weapon/shard/procgen/shard = W.spawnBrokenPieces()
	if(!istype(shard))
		fail("Procgen window didn't break into a procgen shard")
	else
		assert_eq(shard.mat_id, M.id)
		assert_eq(shard.glass, M.sheettype)
		assert_eq(shard.materials.getAmount(M.id), M.cc_per_sheet)
		assert_eq(shard.materials.getAmount(MAT_GLASS), 0)
	if(matsci_test_count(T, /obj/item/weapon/shard) != glass_shards)
		fail("Procgen window also dropped a glass shard")
	qdel(W)

	// Windoor materials survive the trip between assembly and windoor, secure or not.
	var/obj/structure/windoor_assembly/procgen/WA = new(T)
	WA.matsci_set_material(M.id)
	var/obj/machinery/door/window/procgen/windoor = WA.make_windoor()
	assert_eq(windoor.type, /obj/machinery/door/window/procgen)
	assert_eq(windoor.material_type, M)
	var/obj/structure/windoor_assembly/procgen/WA2 = windoor.make_assembly()
	assert_eq(WA2.material_type, M)
	assert_eq(WA2.glass_type, M.sheettype)
	WA2.secure = TRUE
	var/obj/machinery/door/window/procgen/secure_windoor = WA2.make_windoor()
	assert_eq(secure_windoor.type, /obj/machinery/door/window/procgen/secure)
	assert_eq(secure_windoor.material_type, M)
	qdel(WA)
	qdel(windoor)
	qdel(WA2)
	qdel(secure_windoor)
	for(var/obj/item/I in T)
		qdel(I)

	// Broken procgen table doors leave only a shard.
	var/obj/machinery/door/table/glass/procgen/TD = new(T)
	TD.matsci_set_material(M.id)
	var/shards_before = matsci_test_count(T, /obj/item/weapon/shard/procgen, M.id)
	var/rods_before = matsci_test_count(T, /obj/item/stack/rods)
	TD.health = 0
	TD.checkhealth()
	assert_eq(matsci_test_count(T, /obj/item/weapon/shard/procgen, M.id), shards_before + 1)
	assert_eq(matsci_test_count(T, /obj/item/stack/rods), rods_before)

	var/obj/item/stack/tile/rglass/procgen/tiles = new(null, 5, M.id)
	var/obj/item/stack/tile/rglass/procgen/copy = tiles.create_like(null)
	assert_eq(copy.mat_id, M.id)
	assert_eq(tiles.materials.getAmount(M.id), 5 * M.cc_per_sheet)
	var/datum/material/procgen/other = matsci_generate_material(2, list(MAT_GLASS), list())
	var/obj/item/stack/tile/rglass/procgen/other_tiles = new(null, 1, other.id)
	if(tiles.can_stack_with(other_tiles))
		fail("Glass tiles of different materials can stack")
	qdel(tiles)
	qdel(copy)
	qdel(other_tiles)

/datum/unit_test/matsci/self_repair/start()
	var/turf/T = run_loc_bottom_left
	var/datum/material/procgen/M = matsci_generate_material(4, list(MAT_GLASS), list("self_repairing" = 1))
	var/datum/material/procgen/plain = matsci_generate_material(4, list(MAT_GLASS), list())
	var/obj/structure/window/procgen/W = new /obj/structure/window/procgen/loose(T)
	var/obj/structure/window/procgen/W_plain = new /obj/structure/window/procgen/loose(T)
	W.matsci_set_material(M.id)
	W_plain.matsci_set_material(plain.id)
	if(W in processing_objects)
		fail("An undamaged self-repairing window is processing")
	W.health = max(1, W.maxHealth - 3)
	W.healthcheck(null, FALSE)
	W_plain.health = max(1, W_plain.maxHealth - 3)
	W_plain.healthcheck(null, FALSE)
	if(!(W in processing_objects))
		fail("A damaged self-repairing window isn't processing")
	if(W_plain in processing_objects)
		fail("A damaged window without the self-repairing trait is processing")
	for(var/i in 1 to 10)
		if(!(W in processing_objects))
			break
		W.process()
	assert_eq(W.health, W.maxHealth)
	if(W in processing_objects)
		fail("A fully repaired window is still processing")
	qdel(W)
	qdel(W_plain)

	var/obj/machinery/door/window/procgen/windoor = new(T)
	windoor.matsci_set_material(M.id)
	windoor.take_damage(3)
	if(!(windoor in processing_objects))
		fail("A damaged self-repairing windoor isn't processing")
	for(var/i in 1 to 10)
		if(!(windoor in processing_objects))
			break
		windoor.process()
	assert_eq(windoor.health, windoor.maxHealth)
	if(windoor in processing_objects)
		fail("A fully repaired windoor is still processing")
	qdel(windoor)

	var/obj/machinery/door/table/glass/procgen/TD = new(T)
	TD.matsci_set_material(M.id)
	TD.health -= 3
	TD.checkhealth()
	if(!(TD in processing_objects))
		fail("A damaged self-repairing table door isn't processing")
	for(var/i in 1 to 10)
		if(!(TD in processing_objects))
			break
		TD.process()
	assert_eq(TD.health, TD.maxHealth)
	if(TD in processing_objects)
		fail("A fully repaired table door is still processing")
	qdel(TD)
	for(var/obj/item/I in T)
		qdel(I)

/datum/unit_test/matsci/walls/start()
	var/turf/T = run_loc_bottom_left
	var/datum/material/procgen/M = matsci_generate_material(2, list(MAT_IRON), list())
	var/obj/item/stack/sheet/mineral/procgen/sheets = new(null, 2, M.id)
	assert_eq(sheets.get_wall_path(), /turf/simulated/wall/mineral/procgen)
	assert_eq(sheets.get_wall_path(TRUE), /obj/structure/falsewall/procgen)
	var/obj/item/stack/sheet/mineral/procgen/blank = new(null, 2)
	if(blank.get_wall_path())
		fail("Procgen sheets with no material can plate a girder")
	var/obj/item/stack/sheet/mineral/diamond/diamonds = new(null, 2)
	assert_eq(diamonds.get_wall_path(), /turf/simulated/wall/mineral/diamond)
	qdel(blank)
	qdel(diamonds)

	var/obj/structure/falsewall/procgen/FW = new(T)
	sheets.apply_material_to(FW)
	qdel(sheets)
	if(!findtext(FW.name, lowertext(M.name)))
		fail("Procgen false wall is called [FW.name]")
	FW.dismantle()
	assert_eq(matsci_test_count(T, /obj/item/stack/sheet/mineral/procgen, M.id), 2)
	for(var/obj/structure/girder/G in T)
		qdel(G)

/datum/unit_test/matsci/tile_recipe/start()
	var/turf/T = run_loc_bottom_left
	var/datum/material/procgen/M = matsci_generate_material(2, list(MAT_GLASS), list())
	var/obj/item/stack/sheet/mineral/procgen/sheets = new(null, 10, M.id)
	var/datum/stack_recipe/matsci/R
	for(var/datum/stack_recipe/matsci/candidate in sheets.recipes)
		if(candidate.result_type == /obj/item/stack/tile/rglass/procgen)
			R = candidate
	if(!R)
		fail("Glass-primary procgen sheets have no glass tile recipe")
		return
	var/obj/item/stack/tile/rglass/procgen/first = R.make_stack_result(null, sheets, T, 1)
	var/obj/item/stack/tile/rglass/procgen/second = R.make_stack_result(null, sheets, T, 1)
	assert_eq(first.mat_id, M.id)
	assert_eq(second, first)
	assert_eq(first.amount, 2)
	assert_eq(first.materials.getAmount(M.id), 2 * M.cc_per_sheet)
	qdel(first)
	qdel(sheets)
