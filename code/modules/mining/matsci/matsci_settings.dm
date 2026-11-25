/*
 * MATERIAL SCIENCE: SETTINGS
 *
 * Every tunable number for procedurally generated materials lives here, so it can be changed live
 * with View Variables (debug the global matsci_settings_datum) and tested with the admin reroll verb.
 *
 * Lists indexed by tier are plain lists where list[tier] is the value for that tier (1 to 4).
 * Always fetch this through matsci_settings(): asteroid ore is placed during world boot,
 * before anything else gets a chance to create it.
 */

var/datum/matsci_settings/matsci_settings_datum

/proc/matsci_settings()
	if(!matsci_settings_datum)
		matsci_settings_datum = new /datum/matsci_settings
	return matsci_settings_datum

/datum/matsci_settings
	// ---------------- Asteroid round set ----------------
	var/asteroid_count_min = 3
	var/asteroid_count_max = 6
	/// One material of each of these tiers is always generated.
	var/list/asteroid_guaranteed_tiers = list(1, 2, 3)
	/// Weights for the remaining slots, indexed by tier.
	var/list/asteroid_tier_weights = list(50, 30, 15, 3)
	/// mineralSpawnChance pools that get the asteroid's procgen materials added to them. Other pools (snow, clown, mecha...) are left alone.
	var/list/asteroid_pools = list("random", "random_safe", "random_high")

	// ---------------- Planet sets ----------------
	var/planet_new_min = 2
	var/planet_new_max = 4
	/// Materials reused from anything already generated this round (asteroid or earlier planets).
	var/planet_reuse_min = 0
	var/planet_reuse_max = 2
	/// Planets roll better tiers than the asteroid. Indexed by tier.
	var/list/planet_tier_weights = list(35, 35, 20, 10)
	/// Planet veins are this many times the asteroid vein band (rolled per material, per planet).
	var/planet_vein_mult_min = 0.5
	var/planet_vein_mult_max = 1.5
	/// Multiplier on spawn weights for procgen ores on planets.
	var/planet_spawn_weight_mult = 1
	/// Planet type -> weight boosts for compatible primaries and traits. A boost, never a restriction.
	var/list/planet_biases = list(
		/datum/planet_type/lava = list("primaries" = list(MAT_PLASMA = 3), "traits" = list("explosive" = 3, "searing" = 3)),
		/datum/planet_type/snow = list("primaries" = list(MAT_GLASS = 3, MAT_DIAMOND = 2), "traits" = list("crystalline" = 3)),
		/datum/planet_type/desert = list("primaries" = list(MAT_GOLD = 3, MAT_SILVER = 2), "traits" = list("lightweight" = 2, "searing" = 1.5)),
		/datum/planet_type/jungle = list("primaries" = list(), "traits" = list("toxic" = 3, "luminous" = 2, "self_repairing" = 1.5)),
		/datum/planet_type/urban = list("primaries" = list(MAT_URANIUM = 3), "traits" = list("radioactive" = 3, "heavy" = 2, "toxic" = 1.5)),
		/datum/planet_type/xeno = list("primaries" = list(MAT_PHAZON = 3, MAT_PLASMA = 1.5), "traits" = list("phasic" = 3, "luminous" = 2)),
		/datum/planet_type/beach = list("primaries" = list(MAT_GLASS = 3), "traits" = list("luminous" = 1.5)),
		/datum/planet_type/grass = list("primaries" = list(MAT_IRON = 2), "traits" = list("dense" = 1.5)),
	)

	// ---------------- Veins ----------------
	/// Ore spawn weight per procgen material, indexed by tier. Base asteroid pool totals ~107 (iron 50, plasma 25...).
	var/list/spawn_weight_by_tier = list(8, 3, 1, 0.3)
	/// Max spread chance per tier (iron/plasma are 25, gold/silver/uranium/diamond 10). Min is half of this.
	var/list/vein_spread_max_by_tier = list(25, 10, 8, 6)
	/// Hard cap on any procgen spread chance. Spreading is recursive, so high values can flood a z-level.
	var/vein_spread_cap = 30
	/// Ore per mined turf. Same as every base ore.
	var/ore_per_turf = 5
	var/fortune_multiplier = 2

	// ---------------- Stats ----------------
	/// Blunt, sharpness, quality and armor multipliers are rolled between these, indexed by tier.
	var/list/stat_floor_by_tier = list(0.4, 0.6, 0.8, 1.0)
	var/list/stat_ceiling_by_tier = list(1.3, 1.6, 2.0, 2.6)
	/// Rolled stats are rounded to this step.
	var/stat_step = 0.05
	/// Melting point bands in Kelvin, indexed by tier. Each tier's min and max are above the previous tier's.
	/// Keep max below TEMPERATURE_WELDER / 0.9 (3866K) so nothing is unsmithable.
	var/list/melt_min_by_tier = list(1100, 1250, 1400, 1600)
	var/list/melt_max_by_tier = list(2000, 2500, 3200, 3800)

	// ---------------- Primary properties ----------------
	/// Base materials a procgen material can resemble, and the tier each counts as.
	var/list/base_material_tiers = list(
		MAT_IRON = 1,
		MAT_GLASS = 1,
		MAT_PLASMA = 2,
		MAT_URANIUM = 2,
		MAT_GOLD = 2,
		MAT_SILVER = 2,
		MAT_DIAMOND = 3,
		MAT_PHAZON = 4,
	)
	/// Weights for having 0, 1 or 2 primary properties (list[1] = none).
	var/list/primary_count_weights = list(20, 75, 5)
	/// Allow two-primary hybrids.
	var/allow_hybrids = TRUE
	/// Weight multiplier by tier distance (list[1] = same tier, list[4] = three tiers apart).
	var/list/primary_tier_affinity = list(4, 1.5, 0.5, 0.15)

	// ---------------- Secondary traits ----------------
	/// Weights for having 0 to 3 traits, per material tier (list[tier][count+1]).
	var/list/trait_count_weights = list(
		list(50, 35, 12, 3),
		list(35, 40, 20, 5),
		list(20, 40, 30, 10),
		list(10, 35, 35, 20),
	)
	/// Weight multiplier by distance between trait tier and material tier. No cap: far tiers are just unlikely.
	var/list/trait_tier_affinity = list(4, 1.5, 0.5, 0.15)
	/// Extra weight multiplier for negative traits, indexed by material tier (drawbacks are common low, rare high).
	var/list/negative_trait_mult_by_tier = list(2, 1.2, 0.6, 0.3)
	/// Trait strength range, indexed by material tier. Negative traits use the mirrored tier (T1 gets T4's range).
	var/list/trait_strength_min_by_tier = list(0.5, 0.7, 0.9, 1.1)
	var/list/trait_strength_max_by_tier = list(1.0, 1.2, 1.5, 1.8)

	// ---------------- Sheet crafting ----------------
	/// Glass-primary variants (windows, windoors, table doors, glass floors) get the glass version's health times
	/// (material armor / glass armor) times (material quality / glass quality). Each ratio is clamped to this range.
	var/glass_stat_ratio_min = 0.5
	var/glass_stat_ratio_max = 2
	/// Health healed per process tick by the self-repairing trait, times the trait's strength.
	var/self_repair_per_tick = 1

	// ---------------- Economy ----------------
	/// Value per sheet before stat quality, indexed by tier. For scale: iron 0.2, plasma 1, gold/silver 6, diamond/phazon 50.
	var/list/value_by_tier = list(0.5, 4, 20, 40)
	/// Added per non-negative trait, indexed by the trait's tier, times its strength.
	var/list/trait_value_by_tier = list(0.5, 1, 3, 6)

	// ---------------- Sprites ----------------
	/// Shape name -> list of sprite sets. One set is picked at random when a material is generated.
	/// "ore" and "sheet" are icon states in icons/obj/mining.dmi and icons/obj/stacks_sheets.dmi,
	/// "overlay" and "embed" are icon states in icons/turf/mine_overlays.dmi. Add more sets as sprites come in.
	var/list/sprite_sets = list(
		"metallic" = list(
			list("ore" = "Silver ore", "sheet" = "sheet-silver", "overlay" = "Silver", "embed" = "embed_Silver"),
		),
		"crystalline" = list(
			list("ore" = "Silver ore", "sheet" = "sheet-silver", "overlay" = "Silver", "embed" = "embed_Silver"),
		),
	)
	var/default_sprite_shape = "metallic"
	/// Primary property -> preferred shape.
	var/list/primary_sprite_shapes = list(
		MAT_GLASS = "crystalline",
		MAT_DIAMOND = "crystalline",
		MAT_PLASMA = "crystalline",
		MAT_PHAZON = "crystalline",
	)
	/// Trait -> shape. Takes priority over primaries.
	var/list/trait_sprite_shapes = list(
		"crystalline" = "crystalline",
	)

	// ---------------- Colours ----------------
	/// Primary property -> list(r, g, b). Hybrids blend; materials with no primary get a random colour.
	var/list/primary_colors = list(
		MAT_IRON = list(140, 140, 140),
		MAT_GLASS = list(165, 216, 230),
		MAT_PLASMA = list(155, 48, 255),
		MAT_URANIUM = list(76, 175, 80),
		MAT_GOLD = list(255, 215, 0),
		MAT_SILVER = list(192, 192, 192),
		MAT_DIAMOND = list(185, 242, 255),
		MAT_PHAZON = list(94, 42, 132),
	)
	/// Each RGB channel is shifted by up to this much, so materials with the same primary still look different.
	var/color_jitter = 45

	// ---------------- Names ----------------
	/// Suffix -> weight. Names are 1-2 roots plus one of these.
	var/list/name_suffixes = list("ium" = 5, "anium" = 2, "ite" = 4, "ine" = 2, "ide" = 1, "on" = 1)
	/// Chance (percent) of using two roots instead of one.
	var/two_root_chance = 35
	/// Chance (percent) that a root is taken from the generic list even when the material has properties.
	var/generic_root_chance = 20
	/// Shorter names are rerolled.
	var/name_min_length = 5
	/// Real element and mineral names the generator could produce by accident. Never used.
	var/list/name_blocklist = list(
		"argon", "barium", "boron", "carbon", "cerium", "curium", "ferrite", "fluorite", "hematite", "lithium", "magnesium",
		"neon", "osmium", "pyrite", "radium", "radon", "selenium", "siderite", "silicon", "sodium", "thorium", "xenon",
	)
	// Roots should end in a consonant, so they join cleanly with the suffixes.
	var/list/primary_syllables = list(
		MAT_IRON = list("fer", "stahl", "hemat", "mag", "sider"),
		MAT_GLASS = list("vitr", "hyal", "silic", "clar", "spec"),
		MAT_PLASMA = list("plas", "phor", "viol", "flux", "pyr"),
		MAT_URANIUM = list("urn", "rad", "nuc", "thor", "cer"),
		MAT_GOLD = list("aur", "chrys", "sol", "or", "mid"),
		MAT_SILVER = list("arg", "lun", "sel", "ster", "alb"),
		MAT_DIAMOND = list("adam", "carb", "kryst", "diam", "lith"),
		MAT_PHAZON = list("phaz", "zon", "void", "warp", "phen"),
	)
	var/list/trait_syllables = list(
		"explosive" = list("fulm", "bur", "deton"),
		"toxic" = list("tox", "ven", "mias"),
		"radioactive" = list("gam", "becq", "cur"),
		"searing" = list("ign", "scor", "cal"),
		"charged" = list("volt", "elec", "amper"),
		"luminous" = list("lux", "phos", "glim"),
		"lightweight" = list("aer", "lev", "plum"),
		"self_repairing" = list("viv", "reg", "rest"),
		"heavy" = list("grav", "bar", "pond"),
		"soft" = list("mol", "len", "tal"),
		"crystalline" = list("cryst", "quar", "geod"),
		"dense" = list("dens", "comp", "osm"),
		"phasic" = list("phas", "shift", "blink"),
	)
	var/list/generic_syllables = list("bel", "cor", "dra", "kel", "mor", "nex", "ral", "tor", "ves", "zar", "ost", "quel", "rin", "tal", "bor", "sar")
