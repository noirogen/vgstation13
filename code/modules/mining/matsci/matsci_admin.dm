/*
 * MATERIAL SCIENCE: ADMIN TOOLS
 *
 * Debug verbs to list, inspect, spawn, generate and reroll procgen materials. Tuning values are on the global
 * matsci_settings_datum (view it with View Variables).
 */

/proc/matsci_choose_material(var/mob/user, var/prompt = "Choose a material")
	if(!matsci_materials.len)
		to_chat(user, "<span class='warning'>No procgen materials have been generated yet.</span>")
		return null
	var/list/choices = list()
	for(var/datum/material/procgen/M in matsci_materials)
		choices["[M.name] (T[M.tier], [M.id])"] = M
	var/choice = input(user, prompt, "Material science") as null|anything in choices
	if(!choice)
		return null
	return choices[choice]

/client/proc/matsci_list_materials()
	set category = "Debug"
	set name = "Matsci: List Materials"
	if(!check_rights(R_DEBUG))
		return

	var/dat = "<h2>Procgen materials ([matsci_materials.len])</h2>"
	dat += "<p>Settings: View Variables on <i>matsci_settings_datum</i>.</p>"
	dat += "<table border='1' cellpadding='3'><tr><th></th><th>Name</th><th>ID</th><th>Tier</th><th>Resembles</th><th>Traits</th><th>Blunt</th><th>Sharp</th><th>Quality</th><th>Armor</th><th>Melt (K)</th><th>Value</th><th>Found on</th><th>Researched</th></tr>"
	for(var/datum/material/procgen/M in matsci_materials)
		dat += "<tr>"
		dat += "<td style='background-color:[M.color];width:16px'></td>"
		dat += "<td>[M.name]</td><td>[M.id]</td><td>[M.tier]</td>"
		dat += "<td>[english_list(M.primary_names(), "none")]</td>"
		dat += "<td>[english_list(M.trait_names(TRUE), "none")]</td>"
		dat += "<td>[M.brunt_damage_mod]</td><td>[M.sharpness_mod]</td><td>[M.quality_mod]</td><td>[M.armor_mod]</td>"
		dat += "<td>[M.melt_temperature]</td><td>[M.value]</td>"
		dat += "<td>[english_list(M.found_on, "nowhere")]</td>"
		dat += "<td>[M.researched ? "Yes" : "No"]</td>"
		dat += "</tr>"
	dat += "</table>"
	usr << browse(HTML_SKELETON(dat), "window=matsci_materials;size=1000x500")

/client/proc/matsci_inspect_material()
	set category = "Debug"
	set name = "Matsci: Inspect Material"
	if(!check_rights(R_DEBUG))
		return
	var/datum/material/procgen/M = matsci_choose_material(usr, "Which material do you want to inspect?")
	if(M)
		debug_variables(M)

/client/proc/matsci_spawn_material()
	set category = "Debug"
	set name = "Matsci: Spawn Material"
	if(!check_rights(R_DEBUG))
		return
	var/datum/material/procgen/M = matsci_choose_material(usr, "Which material do you want to spawn?")
	if(!M)
		return
	var/form = input(usr, "Spawn ore or sheets?", "Material science") as null|anything in list("Ore", "Sheets")
	if(!form)
		return
	var/amount = input(usr, "How many?", "Material science", 50) as null|num
	if(!amount || amount < 1)
		return
	amount = min(round(amount), 500)
	var/turf/T = get_turf(usr)
	if(form == "Ore")
		M.spawn_ore(T, amount)
	else
		M.spawn_sheets(T, amount)
	log_admin("[key_name(usr)] spawned [amount] [M.name] ([M.id]) [lowertext(form)] at [T.x],[T.y],[T.z].")
	feedback_add_details("admin_verb", "MSSP")

/client/proc/matsci_generate_material_verb()
	set category = "Debug"
	set name = "Matsci: Generate Material"
	if(!check_rights(R_DEBUG))
		return
	var/datum/matsci_settings/S = matsci_settings()

	var/tier_choice = input(usr, "Tier?", "Material science", "Random") as null|anything in list("Random", "1", "2", "3", "4")
	if(!tier_choice)
		return
	var/tier = tier_choice == "Random" ? matsci_pick_index_weighted(S.asteroid_tier_weights) : text2num(tier_choice)

	var/list/force_primaries = null
	if(alert(usr, "Primary properties: roll them, or choose?", "Material science", "Roll", "Choose") == "Choose")
		force_primaries = list()
		for(var/i in 1 to 2)
			var/list/options = list("Done")
			for(var/mat_id in S.base_material_tiers)
				if(!(mat_id in force_primaries))
					options += mat_id
			var/picked = input(usr, "Add a primary property (chosen: [english_list(force_primaries, "none")])", "Material science", "Done") as null|anything in options
			if(!picked || picked == "Done")
				break
			force_primaries += picked

	var/list/force_traits = null
	if(alert(usr, "Secondary traits: roll them, or choose?", "Material science", "Roll", "Choose") == "Choose")
		force_traits = list()
		for(var/i in 1 to 3)
			var/list/options = list("Done")
			for(var/trait_id in matsci_get_traits())
				if(!(trait_id in force_traits))
					options += trait_id
			var/picked = input(usr, "Add a trait (chosen: [english_list(force_traits, "none")])", "Material science", "Done") as null|anything in options
			if(!picked || picked == "Done")
				break
			force_traits += picked

	var/datum/material/procgen/M = matsci_generate_material(tier, force_primaries, force_traits)
	var/add_to_asteroid = alert(usr, "Add [M.name] to the asteroid's ore spawns? (Only affects rock generated from now on.)", "Material science", "No", "Yes") == "Yes"
	if(add_to_asteroid)
		matsci_add_asteroid_material(M)

	to_chat(usr, "<span class='notice'>Generated [M.name] ([M.id]), tier [M.tier]: [M.stat_summary()]. Resembles [english_list(M.primary_names(), "nothing")]; traits: [english_list(M.trait_names(TRUE), "none")].</span>")
	log_admin("[key_name(usr)] generated procgen material [M.name] ([M.id])[add_to_asteroid ? " and added it to asteroid spawns" : ""].")
	message_admins("[key_name_admin(usr)] generated procgen material [M.name] ([M.id])[add_to_asteroid ? " and added it to asteroid spawns" : ""].")
	feedback_add_details("admin_verb", "MSGN")

/client/proc/matsci_reroll_round_set()
	set category = "Debug"
	set name = "Matsci: Reroll Asteroid Materials"
	if(!check_rights(R_DEBUG))
		return
	if(alert(usr, "Replace the asteroid's procgen materials with a new set? Ore already on the map keeps its material; only rock generated from now on uses the new set.", "Material science", "Cancel", "Reroll") != "Reroll")
		return
	matsci_generate_round_set()
	var/list/names = list()
	for(var/mineral_name in matsci_asteroid_minerals)
		var/mineral/procgen/MIN = matsci_asteroid_minerals[mineral_name]
		names += "[mineral_name] (T[MIN.tier])"
	log_admin("[key_name(usr)] rerolled the asteroid's procgen materials: [english_list(names)].")
	message_admins("[key_name_admin(usr)] rerolled the asteroid's procgen materials: [english_list(names)].")
	feedback_add_details("admin_verb", "MSRR")
