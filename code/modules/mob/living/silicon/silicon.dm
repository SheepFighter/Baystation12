/mob/living/silicon
	gender = NEUTER
	voice_name = "synthesized voice"
	var/syndicate = 0
	var/datum/ai_laws/laws = null//Now... THEY ALL CAN ALL HAVE LAWS
	var/list/additional_law_channels = list("State")
	var/const/MAIN_CHANNEL = "Main Frequency"
	var/lawchannel = MAIN_CHANNEL // Default channel on which to state laws
	var/list/stating_laws = list()// Channels laws are currently being stated on
	var/lawcheck[1]
	var/ioncheck[1]
	var/obj/item/device/radio/common_radio

	var/list/hud_list[9]
	var/list/speech_synthesizer_langs = list()	//which languages can be vocalized by the speech synthesizer

	//Used in say.dm.
	var/speak_statement = "states"
	var/speak_exclamation = "declares"
	var/speak_query = "queries"
	var/pose //Yes, now AIs can pose too.
	var/obj/item/device/camera/siliconcam/aiCamera = null //photography
	var/local_transmit //If set, can only speak to others of the same type within a short range.

	var/sensor_mode = 0 //Determines the current HUD.
	#define SEC_HUD 1 //Security HUD mode
	#define MED_HUD 2 //Medical HUD mode

/mob/living/silicon/New()
	..()
	add_language("Galactic Common")

/mob/living/silicon/proc/show_laws()
	return

/mob/living/silicon/drop_item()
	return

/mob/living/silicon/emp_act(severity)
	switch(severity)
		if(1)
			src.take_organ_damage(20)
			Stun(rand(5,10))
		if(2)
			src.take_organ_damage(10)
			Stun(rand(1,5))
	flick("noise", src:flash)
	src << "\red <B>*BZZZT*</B>"
	src << "\red Warning: Electromagnetic pulse detected."
	..()

/mob/living/silicon/stun_effect_act(var/stun_amount, var/agony_amount)
	return	//immune

/mob/living/silicon/electrocute_act(var/shock_damage, var/obj/source, var/siemens_coeff = 1.0)

	if (istype(source, /obj/machinery/containment_field))
		var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
		s.set_up(5, 1, loc)
		s.start()

		shock_damage *= 0.75	//take reduced damage
		take_overall_damage(0, shock_damage)
		visible_message("\red [src] was shocked by \the [source]!", \
			"\red <B>Energy pulse detected, system damaged!</B>", \
			"\red You hear an electrical crack")
		if(prob(20))
			Stun(2)
		return

/mob/living/silicon/proc/damage_mob(var/brute = 0, var/fire = 0, var/tox = 0)
	return

/mob/living/silicon/IsAdvancedToolUser()
	return 1

/mob/living/silicon/blob_act()
	if (src.stat != 2)
		src.adjustBruteLoss(60)
		src.updatehealth()
		return 1
	return 0

/mob/living/silicon/bullet_act(var/obj/item/projectile/Proj)

	if(!Proj.nodamage)
		switch(Proj.damage_type)
			if(BRUTE)
				adjustBruteLoss(Proj.damage)
			if(BURN)
				adjustFireLoss(Proj.damage)

	Proj.on_hit(src,2)
	updatehealth()
	return 2

/mob/living/silicon/apply_effect(var/effect = 0,var/effecttype = STUN, var/blocked = 0)
	return 0//The only effect that can hit them atm is flashes and they still directly edit so this works for now
/*
	if(!effect || (blocked >= 2))	return 0
	switch(effecttype)
		if(STUN)
			stunned = max(stunned,(effect/(blocked+1)))
		if(WEAKEN)
			weakened = max(weakened,(effect/(blocked+1)))
		if(PARALYZE)
			paralysis = max(paralysis,(effect/(blocked+1)))
		if(IRRADIATE)
			radiation += min((effect - (effect*getarmor(null, "rad"))), 0)//Rads auto check armor
		if(STUTTER)
			stuttering = max(stuttering,(effect/(blocked+1)))
		if(EYE_BLUR)
			eye_blurry = max(eye_blurry,(effect/(blocked+1)))
		if(DROWSY)
			drowsyness = max(drowsyness,(effect/(blocked+1)))
	updatehealth()
	return 1*/

/proc/islinked(var/mob/living/silicon/robot/bot, var/mob/living/silicon/ai/ai)
	if(!istype(bot) || !istype(ai))
		return 0
	if (bot.connected_ai == ai)
		return 1
	return 0


// this function shows the health of the AI in the Status panel
/mob/living/silicon/proc/show_system_integrity()
	if(!src.stat)
		stat(null, text("System integrity: [round((health/maxHealth)*100)]%"))
	else
		stat(null, text("Systems nonfunctional"))


// This is a pure virtual function, it should be overwritten by all subclasses
/mob/living/silicon/proc/show_malf_ai()
	return 0


// this function displays the station time in the status panel
/mob/living/silicon/proc/show_station_time()
	stat(null, "Station Time: [worldtime2text()]")


// this function displays the shuttles ETA in the status panel if the shuttle has been called
/mob/living/silicon/proc/show_emergency_shuttle_eta()
	if(emergency_shuttle)
		var/eta_status = emergency_shuttle.get_status_panel_eta()
		if(eta_status)
			stat(null, eta_status)


// This adds the basic clock, shuttle recall timer, and malf_ai info to all silicon lifeforms
/mob/living/silicon/Stat()
	..()
	statpanel("Status")
	if (src.client.statpanel == "Status")
		show_station_time()
		show_emergency_shuttle_eta()
		show_system_integrity()
		show_malf_ai()

// this function displays the stations manifest in a separate window
/mob/living/silicon/proc/show_station_manifest()
	var/dat
	dat += "<h4>Crew Manifest</h4>"
	if(data_core)
		dat += data_core.get_manifest(1) // make it monochrome
	dat += "<br>"
	src << browse(dat, "window=airoster")
	onclose(src, "airoster")

//can't inject synths
/mob/living/silicon/can_inject(var/mob/user, var/error_msg)
	if(error_msg)
		user << "<span class='alert'>The armoured plating is too tough.</span>"
	return 0


//Silicon mob language procs

/mob/living/silicon/can_speak(datum/language/speaking)
	return universal_speak || (speaking in src.speech_synthesizer_langs)	//need speech synthesizer support to vocalize a language

/mob/living/silicon/add_language(var/language, var/can_speak=1)
	if (..(language) && can_speak)
		speech_synthesizer_langs.Add(all_languages[language])
		return 1

/mob/living/silicon/remove_language(var/rem_language)
	..(rem_language)

	for (var/datum/language/L in speech_synthesizer_langs)
		if (L.name == rem_language)
			speech_synthesizer_langs -= L

/mob/living/silicon/check_languages()
	set name = "Check Known Languages"
	set category = "IC"
	set src = usr

	var/dat = "<b><font size = 5>Known Languages</font></b><br/><br/>"

	for(var/datum/language/L in languages)
		if(!(L.flags & NONGLOBAL))
			dat += "<b>[L.name] (:[L.key])</b><br/>Speech Synthesizer: <i>[(L in speech_synthesizer_langs)? "YES":"NOT SUPPORTED"]</i><br/>[L.desc]<br/><br/>"

	src << browse(dat, "window=checklanguage")
	return

/mob/living/silicon/proc/toggle_sensor_mode()
	var/sensor_type = input("Please select sensor type.", "Sensor Integration", null) in list("Security", "Medical","Disable")
	switch(sensor_type)
		if ("Security")
			sensor_mode = SEC_HUD
			src << "<span class='notice'>Security records overlay enabled.</span>"
		if ("Medical")
			sensor_mode = MED_HUD
			src << "<span class='notice'>Life signs monitor overlay enabled.</span>"
		if ("Disable")
			sensor_mode = 0
			src << "Sensor augmentations disabled."

/mob/living/silicon/verb/pose()
	set name = "Set Pose"
	set desc = "Sets a description which will be shown when someone examines you."
	set category = "IC"

	pose =  copytext(sanitize(input(usr, "This is [src]. It is...", "Pose", null)  as text), 1, MAX_MESSAGE_LEN)

/mob/living/silicon/verb/set_flavor()
	set name = "Set Flavour Text"
	set desc = "Sets an extended description of your character's features."
	set category = "IC"

	flavor_text =  copytext(sanitize(input(usr, "Please enter your new flavour text.", "Flavour text", null)  as text), 1)

/mob/living/silicon/binarycheck()
	return 1

/mob/living/silicon/Topic(href, href_list)
	..()

	if (href_list["lawr"]) // Selects on which channel to state laws
		var/list/channels = list(MAIN_CHANNEL)
		if(common_radio)
			for (var/ch_name in common_radio.channels)
				channels += ch_name

		channels += additional_law_channels
		channels += "Cancel"

		var/setchannel = input(usr, "Specify channel.", "Channel selection") in channels
		if(setchannel != "Cancel")
			lawchannel = setchannel
			checklaws()
		return 1

	return 0

/mob/living/silicon/ex_act(severity)
	if(!blinded)
		flick("flash", flash)

	switch(severity)
		if(1.0)
			if (stat != 2)
				adjustBruteLoss(100)
				adjustFireLoss(100)
				if(!anchored)
					gib()
		if(2.0)
			if (stat != 2)
				adjustBruteLoss(60)
				adjustFireLoss(60)
		if(3.0)
			if (stat != 2)
				adjustBruteLoss(30)

	updatehealth()
