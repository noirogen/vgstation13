/*
 * MATERIAL SCIENCE: GENERATION
 *
 * matsci_generate_material() rolls one material: stats, primary properties, traits, value, colour, sprites, name.
 * matsci_generate_round_set() rolls the asteroid's materials (called from SetupMinerals() during world boot).
 * matsci_generate_planet_set() rolls a planet's materials (called from SSmapping.spawn_planet()).
 * All the numbers come from matsci_settings().
 */

/// Lowercase names already in use (base materials, minerals and procgen materials), so names stay unique.
var/list/matsci_used_names

/proc/matsci_rand_between(var/low, var/high)
	return low + rand() * (high - low)

/// Picks an index from a plain list of weights. Returns 1 if every weight is zero.
/proc/matsci_pick_index_weighted(var/list/weights)
	var/total = 0
	for(var/w in weights)
		total += max(0, w)
	if(total <= 0)
		return 1
	var/roll = rand() * total
	for(var/i in 1 to weights.len)
		roll -= max(0, weights[i])
		if(roll <= 0)
			return i
	return weights.len

/proc/matsci_tier_value(var/list/by_tier, var/tier)
	if(!by_tier || !by_tier.len)
		return 0
	return by_tier[clamp(round(tier), 1, by_tier.len)]

/**
 * Generates and registers a new procedurally generated material.
 *
 * * tier - 1 to 4
 * * force_primaries - list of base material IDs to use instead of rolling. An empty list means none.
 * * force_traits - list of trait IDs (or trait ID -> strength) to use instead of rolling. An empty list means none.
 * * planet - if set, that planet type's biases boost matching primaries and traits.
 */
/proc/matsci_generate_material(var/tier, var/list/force_primaries = null, var/list/force_traits = null, var/datum/planet_type/planet = null)
	var/datum/matsci_settings/S = matsci_settings()
	tier = clamp(round(tier), 1, 4)

	var/list/primary_bias
	var/list/trait_bias
	if(planet)
		var/list/bias = S.planet_biases[planet.type]
		if(bias)
			primary_bias = bias["primaries"]
			trait_bias = bias["traits"]

	var/datum/material/procgen/M = new
	M.tier = tier

	if(force_primaries)
		M.primaries = force_primaries.Copy()
	else
		M.primaries = matsci_roll_primaries(tier, primary_bias)

	matsci_roll_stats(M)

	if(force_traits)
		M.traits = list()
		for(var/trait_id in force_traits)
			var/datum/matsci_trait/T = matsci_get_trait(trait_id)
			if(!T)
				continue
			var/strength = force_traits[trait_id]
			M.traits[trait_id] = isnum(strength) ? strength : matsci_roll_trait_strength(T, tier)
	else
		M.traits = matsci_roll_traits(tier, trait_bias)

	for(var/trait_id in M.traits)
		var/datum/matsci_trait/T = matsci_get_trait(trait_id)
		T.apply_stats(M, M.traits[trait_id])

	M.brunt_damage_mod = round(M.brunt_damage_mod, 0.01)
	M.sharpness_mod = round(M.sharpness_mod, 0.01)
	M.quality_mod = round(M.quality_mod, 0.01)
	M.armor_mod = round(M.armor_mod, 0.01)

	M.value = matsci_calculate_value(M)
	M.color = matsci_roll_color(M.primaries)
	matsci_pick_sprites(M)
	M.name = matsci_generate_name(M)
	M.processed_name = M.name

	matsci_register_material(M)
	return M

/// Rolls the four stat multipliers and melting point. Higher tiers raise the floor; at least one stat is at or above the tier average.
/proc/matsci_roll_stats(var/datum/material/procgen/M)
	var/datum/matsci_settings/S = matsci_settings()
	var/low = matsci_tier_value(S.stat_floor_by_tier, M.tier)
	var/high = matsci_tier_value(S.stat_ceiling_by_tier, M.tier)
	var/average = (low + high) / 2
	var/list/stat_names = list("brunt_damage_mod", "sharpness_mod", "quality_mod", "armor_mod")

	var/any_above = FALSE
	for(var/stat in stat_names)
		var/value = clamp(round(matsci_rand_between(low, high), S.stat_step), low, high)
		M.vars[stat] = value
		if(value >= average)
			any_above = TRUE
	if(!any_above)
		M.vars[pick(stat_names)] = clamp(round(matsci_rand_between(average, high), S.stat_step), average, high)

	M.melt_temperature = round(matsci_rand_between(matsci_tier_value(S.melt_min_by_tier, M.tier), matsci_tier_value(S.melt_max_by_tier, M.tier)))

/proc/matsci_roll_primaries(var/tier, var/list/bias)
	var/datum/matsci_settings/S = matsci_settings()
	var/list/result = list()
	var/count = matsci_pick_index_weighted(S.primary_count_weights) - 1
	if(count >= 2 && !S.allow_hybrids)
		count = 1
	if(count <= 0)
		return result

	var/list/candidates = list()
	for(var/mat_id in S.base_material_tiers)
		var/distance = min(abs(S.base_material_tiers[mat_id] - tier), S.primary_tier_affinity.len - 1)
		var/weight = S.primary_tier_affinity[distance + 1]
		if(bias && isnum(bias[mat_id]))
			weight *= bias[mat_id]
		if(weight > 0)
			candidates[mat_id] = weight

	for(var/i in 1 to count)
		if(!candidates.len)
			break
		var/picked = pickweight(candidates)
		result += picked
		candidates -= picked
	return result

/proc/matsci_roll_traits(var/tier, var/list/bias)
	var/datum/matsci_settings/S = matsci_settings()
	var/list/result = list()
	var/list/count_weights = S.trait_count_weights[clamp(tier, 1, S.trait_count_weights.len)]
	var/count = matsci_pick_index_weighted(count_weights) - 1
	if(count <= 0)
		return result

	var/list/traits = matsci_get_traits()
	var/list/candidates = list()
	for(var/trait_id in traits)
		var/datum/matsci_trait/T = traits[trait_id]
		if(tier < T.min_material_tier)
			continue
		var/weight = T.weight
		if(T.any_tier)
			weight *= S.trait_tier_affinity[min(2, S.trait_tier_affinity.len)]
		else
			weight *= S.trait_tier_affinity[min(abs(T.tier - tier), S.trait_tier_affinity.len - 1) + 1]
		if(T.is_negative())
			weight *= matsci_tier_value(S.negative_trait_mult_by_tier, tier)
		if(bias && isnum(bias[trait_id]))
			weight *= bias[trait_id]
		if(weight > 0)
			candidates[trait_id] = weight

	for(var/i in 1 to count)
		if(!candidates.len)
			break
		var/picked = pickweight(candidates)
		var/datum/matsci_trait/T = traits[picked]
		result[picked] = matsci_roll_trait_strength(T, tier)
		candidates -= picked
		for(var/excluded in T.exclusive_with)
			candidates -= excluded
	return result

/// Better ranges at higher tiers. For negative traits "better" means weaker, so they use the mirrored tier.
/proc/matsci_roll_trait_strength(var/datum/matsci_trait/T, var/tier)
	var/datum/matsci_settings/S = matsci_settings()
	var/strength_tier = T.is_negative() ? (5 - tier) : tier
	return round(matsci_rand_between(matsci_tier_value(S.trait_strength_min_by_tier, strength_tier), matsci_tier_value(S.trait_strength_max_by_tier, strength_tier)), 0.05)

/// Tier base value x stat quality + trait bonuses.
/proc/matsci_calculate_value(var/datum/material/procgen/M)
	var/datum/matsci_settings/S = matsci_settings()
	var/tier_average = (matsci_tier_value(S.stat_floor_by_tier, M.tier) + matsci_tier_value(S.stat_ceiling_by_tier, M.tier)) / 2
	var/stat_quality = tier_average ? M.average_stat() / tier_average : 1
	var/total = matsci_tier_value(S.value_by_tier, M.tier) * stat_quality
	for(var/trait_id in M.traits)
		var/datum/matsci_trait/T = matsci_get_trait(trait_id)
		if(T && !T.is_negative())
			total += matsci_tier_value(S.trait_value_by_tier, T.tier) * M.traits[trait_id]
	return round(max(0, total), 0.01)

/proc/matsci_roll_color(var/list/primaries)
	var/datum/matsci_settings/S = matsci_settings()
	var/red = 0
	var/green = 0
	var/blue = 0
	var/count = 0
	for(var/mat_id in primaries)
		var/list/rgb_list = S.primary_colors[mat_id]
		if(!rgb_list || rgb_list.len < 3)
			continue
		red += rgb_list[1]
		green += rgb_list[2]
		blue += rgb_list[3]
		count++
	if(count)
		red /= count
		green /= count
		blue /= count
	else
		red = rand(60, 230)
		green = rand(60, 230)
		blue = rand(60, 230)
	var/jitter = S.color_jitter
	red = clamp(round(red + rand(-jitter, jitter)), 0, 255)
	green = clamp(round(green + rand(-jitter, jitter)), 0, 255)
	blue = clamp(round(blue + rand(-jitter, jitter)), 0, 255)
	return rgb(red, green, blue)

/// Picks a sprite set by shape: trait shape first, then primary shape, then the default.
/proc/matsci_pick_sprites(var/datum/material/procgen/M)
	var/datum/matsci_settings/S = matsci_settings()
	var/shape
	for(var/trait_id in M.traits)
		if(S.trait_sprite_shapes[trait_id])
			shape = S.trait_sprite_shapes[trait_id]
			break
	if(!shape)
		for(var/mat_id in M.primaries)
			if(S.primary_sprite_shapes[mat_id])
				shape = S.primary_sprite_shapes[mat_id]
				break
	if(!shape || !length(S.sprite_sets[shape]))
		shape = S.default_sprite_shape
	var/list/sets = S.sprite_sets[shape]
	if(!length(sets))
		return
	var/list/chosen = pick(sets)
	M.sprite_shape = shape
	if(chosen["ore"])
		M.ore_state = chosen["ore"]
	if(chosen["sheet"])
		M.sheet_state = chosen["sheet"]
	if(chosen["overlay"])
		M.overlay_state = chosen["overlay"]
	if(chosen["embed"])
		M.embed_state = chosen["embed"]

// ---------------- Names ----------------

/proc/matsci_name_taken(var/name)
	if(!matsci_used_names)
		matsci_used_names = list()
		var/datum/matsci_settings/S = matsci_settings()
		for(var/blocked in S.name_blocklist)
			matsci_used_names[lowertext(blocked)] = TRUE
		if(!material_list)
			initialize_materials()
		for(var/mat_id in material_list)
			var/datum/material/mat = material_list[mat_id]
			matsci_used_names[lowertext(mat.name)] = TRUE
		for(var/path in subtypesof(/mineral))
			var/mineral/min_path = path
			if(initial(min_path.name))
				matsci_used_names[lowertext(initial(min_path.name))] = TRUE
			if(initial(min_path.display_name))
				matsci_used_names[lowertext(initial(min_path.display_name))] = TRUE
	return matsci_used_names[lowertext(name)] ? TRUE : FALSE

/proc/matsci_claim_name(var/name)
	matsci_name_taken(name) // Makes sure the list exists
	matsci_used_names[lowertext(name)] = TRUE

/// Joins two name pieces, dropping one letter where they'd clash ("plasma" + "ium" -> "plasmium", "fer" + "rite" -> "ferite").
/proc/matsci_join_syllable(var/left, var/right)
	if(!length(left))
		return right
	if(!length(right))
		return left
	var/vowels = "aeiouy"
	var/last = copytext(left, length(left))
	var/first = copytext(right, 1, 2)
	if(last == first)
		return left + copytext(right, 2)
	if(length(left) > 2 && findtext(vowels, last) && findtext(vowels, first))
		return copytext(left, 1, length(left)) + right
	return left + right

/// 1-2 roots from the material's properties (or generic ones) plus a suffix. Unique within the round.
/proc/matsci_generate_name(var/datum/material/procgen/M)
	var/datum/matsci_settings/S = matsci_settings()
	var/list/pool = list()
	for(var/mat_id in M.primaries)
		var/list/syllables = S.primary_syllables[mat_id]
		if(syllables)
			pool |= syllables
	for(var/trait_id in M.traits)
		var/list/syllables = S.trait_syllables[trait_id]
		if(syllables)
			pool |= syllables

	var/name
	for(var/attempt in 1 to 30)
		name = ""
		var/roots = prob(S.two_root_chance) ? 2 : 1
		var/list/used_roots = list()
		for(var/i in 1 to roots)
			var/list/source = (!pool.len || prob(S.generic_root_chance)) ? S.generic_syllables : pool
			source = source - used_roots
			if(!source.len)
				break
			var/root = pick(source)
			used_roots += root
			name = matsci_join_syllable(name, root)
		name = capitalize(matsci_join_syllable(name, pickweight(S.name_suffixes)))
		if(length(name) < S.name_min_length)
			continue
		if(!matsci_name_taken(name))
			matsci_claim_name(name)
			return name

	// Ran out of attempts: number the last one until it's unique.
	var/base_name = name
	var/n = 2
	while(matsci_name_taken(name))
		name = "[base_name]-[n++]"
	matsci_claim_name(name)
	return name

// ---------------- Round and planet sets ----------------

/// Asteroid procgen minerals: name -> /mineral/procgen. Also registered in name_to_mineral.
var/list/matsci_asteroid_minerals = list()
/// Merged spawn pools for the asteroid (pool name -> weighted list), rebuilt after a reroll.
var/list/matsci_asteroid_pool_cache = list()

/proc/matsci_roll_spread(var/tier, var/multiplier = 1)
	var/datum/matsci_settings/S = matsci_settings()
	var/band_max = matsci_tier_value(S.vein_spread_max_by_tier, tier)
	var/spread = matsci_rand_between(band_max / 2, band_max) * multiplier
	return clamp(round(spread), 0, S.vein_spread_cap)

/// Rolls the asteroid's materials. Replaces any previous asteroid set; ore already on the map keeps its material.
/proc/matsci_generate_round_set()
	if(!name_to_mineral)
		SetupMinerals() // Sets up the base minerals and spawn pools, then calls back into this proc
		return
	var/datum/matsci_settings/S = matsci_settings()
	for(var/old_name in matsci_asteroid_minerals)
		name_to_mineral -= old_name
	matsci_asteroid_minerals = list()
	matsci_asteroid_pool_cache = list()

	var/list/tiers = S.asteroid_guaranteed_tiers.Copy()
	var/count = rand(S.asteroid_count_min, S.asteroid_count_max)
	while(tiers.len < count)
		tiers += matsci_pick_index_weighted(S.asteroid_tier_weights)

	for(var/tier in tiers)
		var/datum/material/procgen/M = matsci_generate_material(tier)
		matsci_add_asteroid_material(M)

/// Adds a material to the asteroid's spawn pools (used by the round set and the admin generate verb).
/proc/matsci_add_asteroid_material(var/datum/material/procgen/M)
	if(!name_to_mineral)
		SetupMinerals()
	M.found_on |= "Asteroid"
	var/mineral/procgen/MIN = new /mineral/procgen(M, matsci_roll_spread(M.tier))
	name_to_mineral[MIN.name] = MIN
	matsci_asteroid_minerals[MIN.name] = MIN
	matsci_asteroid_pool_cache = list()
	return MIN

/**
 * Returns the weighted ore pool for a mineral turf: the base pool plus the procgen ores for where the turf is.
 * Planet turfs get their planet's materials; everything else gets the asteroid's materials, but only for asteroid_pools.
 */
/proc/matsci_get_spawn_pool(var/pool_name, var/turf/T)
	if(!islist(mineralSpawnChance) || !mineralSpawnChance.len)
		SetupMineralSpawnLists()
	var/list/base = mineralSpawnChance[pool_name]
	if(!base)
		return base
	var/area/A = get_area(T)
	if(A && A.planet && A.planet.matsci_minerals)
		return A.planet.matsci_get_pool(pool_name, base)

	var/datum/matsci_settings/S = matsci_settings()
	if(!(pool_name in S.asteroid_pools) || !matsci_asteroid_minerals.len)
		return base
	var/list/cached = matsci_asteroid_pool_cache[pool_name]
	if(cached)
		return cached
	var/list/pool = base.Copy()
	for(var/mineral_name in matsci_asteroid_minerals)
		var/mineral/procgen/MIN = matsci_asteroid_minerals[mineral_name]
		pool[mineral_name] = matsci_tier_value(S.spawn_weight_by_tier, MIN.tier)
	matsci_asteroid_pool_cache[pool_name] = pool
	return pool

/// Finds a mineral by name, checking the turf's planet first (planet minerals have their own vein sizes).
/proc/matsci_find_mineral(var/mineral_name, var/turf/T)
	var/area/A = get_area(T)
	if(A && A.planet && A.planet.matsci_minerals)
		var/mineral/planet_mineral = A.planet.matsci_minerals[mineral_name]
		if(planet_mineral)
			return planet_mineral
	if(!name_to_mineral)
		return null
	return name_to_mineral[mineral_name]

/datum/planet_type
	/// Procgen material IDs that spawn on this planet.
	var/list/matsci_material_ids
	/// Mineral name -> /mineral/procgen with this planet's vein size.
	var/list/matsci_minerals
	/// Pool name -> merged weighted pool.
	var/list/matsci_pool_cache

/datum/planet_type/proc/matsci_get_pool(var/pool_name, var/list/base)
	if(!matsci_pool_cache)
		matsci_pool_cache = list()
	var/list/cached = matsci_pool_cache[pool_name]
	if(cached)
		return cached
	var/datum/matsci_settings/S = matsci_settings()
	var/list/pool = base.Copy()
	for(var/mineral_name in matsci_minerals)
		var/mineral/procgen/MIN = matsci_minerals[mineral_name]
		pool[mineral_name] = matsci_tier_value(S.spawn_weight_by_tier, MIN.tier) * S.planet_spawn_weight_mult
	matsci_pool_cache[pool_name] = pool
	return pool

/// Rolls a planet's materials: mostly new ones (biased by planet type), plus some reused from earlier this round.
/proc/matsci_generate_planet_set(var/datum/planet_type/P)
	var/datum/matsci_settings/S = matsci_settings()
	if(!name_to_mineral)
		SetupMinerals() // Make sure the asteroid set exists, so it can be reused here.

	P.matsci_material_ids = list()
	P.matsci_minerals = list()
	P.matsci_pool_cache = list()

	var/list/reuse_candidates = matsci_materials.Copy()
	var/list/chosen = list()

	var/new_count = rand(S.planet_new_min, S.planet_new_max)
	while(new_count-- > 0)
		chosen += matsci_generate_material(matsci_pick_index_weighted(S.planet_tier_weights), null, null, P)

	var/reuse_count = min(rand(S.planet_reuse_min, S.planet_reuse_max), reuse_candidates.len)
	while(reuse_count-- > 0)
		var/datum/material/procgen/reused = pick(reuse_candidates)
		reuse_candidates -= reused
		chosen += reused

	for(var/datum/material/procgen/M in chosen)
		M.found_on |= P.planet_name
		P.matsci_material_ids += M.id
		var/multiplier = matsci_rand_between(S.planet_vein_mult_min, S.planet_vein_mult_max)
		var/mineral/procgen/MIN = new /mineral/procgen(M, matsci_roll_spread(M.tier, multiplier))
		P.matsci_minerals[MIN.name] = MIN
