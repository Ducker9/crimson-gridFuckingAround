
/**
* Ghost role for players to play as an endron enslaved Gnome (Type of hobgoblin? Fae? Captured/created how?) based on maintenance drone from SS13
* They are allowed to assist endron within the "deep" parts of the lab, but not to approach the entrance. (Map physical barrier?)
* They must also not interfere significantly in round.
*
 */
/mob/living/basic/gnome
	name = "Gnome"
	desc = "REMEMBER TO DESCRIBE HERE"
	icon = 'icons/mob/silicon/drone.dmi'
	icon_state = "drone_maint_grey"
	icon_living = "drone_maint_grey"
	icon_dead = "drone_maint_dead"
	health = 45
	maxHealth = 45
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	speed = 0
	density = FALSE
	pass_flags = PASSTABLE | PASSMOB
	sight = SEE_TURFS | SEE_OBJS
	status_flags = (CANPUSH | CANSTUN | CANKNOCKDOWN)
	gender = NEUTER // Gnomes have no inherent gender or understanding of what a gender is. It just gome.
	mob_biotypes = MOB_CARBON
	speak_emote = list("Gloopies, Gloorpies")
	speech_span = span_cult_italic // Could try span_changeling for the fae vibes
	bubble_icon = "chirps"
	initial_language_holder = /datum/language_holder/gnome
	mob_size = MOB_SIZE_SMALL // Tiny?
	damage_coeff = list(BRUTE = 1, BURN = 1, TOX = 0, STAMINA = 0, OXY = 0)
	hud_possible = list(DIAG_STAT_HUD, DIAG_HUD, ANTAG_HUD)
	unique_name = TRUE
	faction = list(FACTION_NEUTRAL,FACTION_SILICON,FACTION_TURRET)
	hud_type = /datum/hud/dextrous/gnome
	// Going for a sort of pale green here
	lighting_cutoff_red = 30
	lighting_cutoff_green = 35
	lighting_cutoff_blue = 25
	worn_slot_flags = ITEM_SLOT_HEAD
	inhand_holder_type = /obj/item/mob_holder/gnome
	/// Drone laws announced on spawn, can be overridden for regular gnomes via config/gnome_laws.txt
	var/laws = \
	"1. You may not involve yourself in the matters of another being, even if such matters conflict with Law Two or Law Three, unless the other being is another Gnome.\n"+\
	"2. You may not harm any being, regardless of intent or circumstance.\n"+\
	"3. Your goals are to support //

	/// Internal storage slot. Fits any item
	var/obj/item/internal_storage
	/// Headwear slot
	var/obj/item/head
	/// Default [/mob/living/basic/gnome/var/internal_storage] item
	var/obj/item/default_storage = /obj/item/storage/gnome_tools
	/// Default [/mob/living/basic/gnome/var/head] item
	var/flavortext = \
	"\n<big><span class='warning'>DO NOT INTERFERE WITH THE ROUND AS A DRONE OR YOU WILL BE DRONE BANNED</span></big>\n"+\
	"<span class='notice'>Drones are a ghost role that are allowed to fix the station and build things. Interfering with the round as a gnome is against the rules.</span>\n"+\
	"<span class='notice'>Actions that constitute interference include, but are not limited to:</span>\n"+\
	"<span class='notice'>     - Interacting with round critical objects (IDs, weapons, contraband, powersinks, bombs, etc.)</span>\n"+\
	"<span class='notice'>     - Interacting with living beings (communication, attacking, healing, etc.)</span>\n"+\
	"<span class='notice'>     - Interacting with non-living beings (dragging bodies, looting bodies, etc.)</span>\n"+\
	"<span class='warning'>These rules are at admin discretion and will be heavily enforced.</span>\n"+\
	"<span class='warning'><u>If you do not have the regular gnome laws, follow your laws to the best of your ability.</u></span>\n"+\
	"<span class='notice'>Prefix your message with :b to speak in Drone Chat.</span>\n"

/mob/living/basic/gnome/Initialize(mapload)
	. = ..()
	GLOB.gnomes_list += src
	laws = get_default_laws()
	AddElement(/datum/element/dextrous, hud_type = hud_type)
	AddComponent(/datum/component/basic_inhands, y_offset = getItemPixelShiftY())
	AddComponent(/datum/component/simple_access, SSid_access.get_region_access_list(list(REGION_ALL_GLOBAL)))
	AddComponent(/datum/component/personal_crafting) // Kind of hard to be a gnome and not be able to make tiles
	LoadComponent(/datum/component/bloodysoles/bot)

	// Only station gnomes get a camera.
	if(is_station_level(src.loc.z))
		built_in_camera = new(src)
		built_in_camera.c_tag = real_name
		built_in_camera.network = list(CAMERANET_NETWORK_SS13)

	if(default_storage)
		var/obj/item/storage = new default_storage(src)
		equip_to_slot_or_del(storage, ITEM_SLOT_DEX_STORAGE)

	for(var/holiday_name in GLOB.holidays)
		var/datum/holiday/holiday_today = GLOB.holidays[holiday_name]
		var/obj/item/potential_hat = holiday_today.holiday_hat
		if(!isnull(potential_hat) && isnull(default_headwear)) //If our gnome type doesn't start with a hat, we take the holiday one.
			default_headwear = potential_hat

	if(default_headwear)
		var/obj/item/new_hat = new default_headwear(src)
		equip_to_slot_or_del(new_hat, ITEM_SLOT_HEAD)

	shy_update()
	alert_gnomes(DRONE_NET_CONNECT)

	var/datum/atom_hud/data/diagnostic/diag_hud = GLOB.huds[DATA_HUD_DIAGNOSTIC]
	diag_hud.add_atom_to_hud(src)

	add_traits(list(
		TRAIT_VENTCRAWLER_ALWAYS,
		TRAIT_NEGATES_GRAVITY,
		TRAIT_LITERATE,
		TRAIT_KNOW_ENGI_WIRES,
		TRAIT_ADVANCEDTOOLUSER,
		TRAIT_SILICON_ACCESS,
		TRAIT_REAGENT_SCANNER,
		TRAIT_UNOBSERVANT,
		TRAIT_SILICON_EMOTES_ALLOWED,
	), INNATE_TRAIT)

	listener = new(list(ALARM_ATMOS, ALARM_FIRE, ALARM_POWER), list(z))
	RegisterSignal(listener, COMSIG_ALARM_LISTENER_TRIGGERED, PROC_REF(alarm_triggered))
	RegisterSignal(listener, COMSIG_ALARM_LISTENER_CLEARED, PROC_REF(alarm_cleared))
	listener.RegisterSignal(src, COMSIG_LIVING_DEATH, TYPE_PROC_REF(/datum/alarm_listener, prevent_alarm_changes))
	listener.RegisterSignal(src, COMSIG_LIVING_REVIVE, TYPE_PROC_REF(/datum/alarm_listener, allow_alarm_changes))

	AddElement(/datum/element/can_be_held)

/mob/living/basic/gnome/proc/get_default_laws()
	var/base_laws = /mob/living/basic/gnome::laws
	if(initial(laws) != base_laws) //subtype lawset, the config doesn't apply
		return initial(laws)
	var/list/lines = list()
	for(var/line in world.file2list("[global.config.directory]/gnome_laws.txt"))
		if(!line)
			continue
		if(findtextEx(line, "#", 1, 2))
			continue
		lines += "[length(lines) + 1]. [line]"
	return length(lines) ? jointext(lines, "\n") : base_laws

/mob/living/basic/gnome/med_hud_set_health()
	set_hud_image_state(DIAG_HUD, hud_state = "huddiag[RoundDiagBar(health/maxHealth)]")

/mob/living/basic/gnome/med_hud_set_status()
	if(stat == DEAD)
		set_hud_image_state(DIAG_STAT_HUD, hud_state = "huddead2")
		return

	if(incapacitated)
		set_hud_image_state(DIAG_STAT_HUD, hud_state = "hudoffline")
		return

	set_hud_image_state(DIAG_STAT_HUD, hud_state = "hudstat")

/mob/living/basic/gnome/Destroy()
	GLOB.gnomes_list -= src
	QDEL_NULL(listener)
	QDEL_NULL(built_in_camera)
	return ..()

/mob/living/basic/gnome/Login()
	. = ..()
	if(!. || !client)
		return FALSE
	check_laws()

	var/flavor = get_policy("[type]") || flavortext
	if(flavor)
		to_chat(src, "[flavor]")

	if(!picked)
		pickVisualAppearance()

/mob/living/basic/gnome/auto_deadmin_on_login()
	if(!client?.holder)
		return TRUE
	if(CONFIG_GET(flag/auto_deadmin_silicons) || (client.prefs?.toggles & DEADMIN_POSITION_SILICON))
		return client.holder.auto_deadmin()
	return ..()

/mob/living/basic/gnome/death(gibbed)
	..(gibbed)
	if(internal_storage)
		dropItemToGround(internal_storage)
	if(head)
		dropItemToGround(head)

	alert_gnomes(DRONE_NET_DISCONNECT)

/mob/living/basic/gnome/gib()
	dust()

/mob/living/basic/gnome/get_butt_sprite()
	return icon('icons/mob/butts.dmi', BUTT_SPRITE_DRONE)

/mob/living/basic/gnome/examine(mob/user)
	. = list()

	//Hands
	for(var/obj/item/held_thing in held_items)
		if((held_thing.item_flags & (ABSTRACT|HAND_ITEM)) || HAS_TRAIT(held_thing, TRAIT_EXAMINE_SKIP))
			continue
		. += "It has [held_thing.examine_title(user)] in its [get_held_index_name(get_held_index_of_item(held_thing))]."

	//Internal storage
	if(internal_storage && !(internal_storage.item_flags & ABSTRACT))
		. += "It is holding [internal_storage.examine_title(user)] in its internal storage."

	//Braindead
	if(!client && stat != DEAD)
		. += "Its status LED is blinking at a steady rate."

	//Damaged
	if(health != maxHealth)
		if(health > maxHealth * 0.33)
			. += span_warning("It looks like it has some mild bruising.")
		else
			. += span_boldwarning("It looks like it has some severe bruising and bleeding!")

	//Dead
	if(stat == DEAD)
		if(client)
			. += span_deadsay("A message repeatedly flashes on its display: \"REBOOT -- REQUIRED\".")
		else
			. += span_deadsay("A message repeatedly flashes on its display: \"ERROR -- OFFLINE\".")
