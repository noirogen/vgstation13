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
