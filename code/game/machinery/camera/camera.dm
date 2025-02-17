/obj/machinery/camera
	name = "security camera"
	desc = "It's used to monitor rooms."
	icon = 'icons/obj/monitors.dmi'
	icon_state = "camera"
	use_power = 2
	idle_power_usage = 5
	active_power_usage = 10
	layer = 5

	var/list/network = list("SS13")
	var/c_tag = null
	var/c_tag_order = 999
	var/status = 1
	anchored = 1.0
	var/panel_open = 0 // 0 = Closed / 1 = Open
	var/invuln = null
	var/bugged = 0
	var/obj/item/weapon/camera_assembly/assembly = null

	var/toughness = 5 //sorta fragile

	// WIRES
	var/datum/wires/camera/wires = null // Wires datum

	//OTHER

	var/view_range = 7
	var/short_range = 2

	var/light_disabled = 0
	var/alarm_on = 0
	var/busy = 0

/obj/machinery/camera/New()
	wires = new(src)
	assembly = new(src)
	assembly.state = 4
	/* // Use this to look for cameras that have the same c_tag.
	for(var/obj/machinery/camera/C in cameranet.cameras)
		var/list/tempnetwork = C.network&src.network
		if(C != src && C.c_tag == src.c_tag && tempnetwork.len)
			world.log << "[src.c_tag] [src.x] [src.y] [src.z] conflicts with [C.c_tag] [C.x] [C.y] [C.z]"
	*/
	if(!src.network || src.network.len < 1)
		if(loc)
			error("[src.name] in [get_area(src)] (x:[src.x] y:[src.y] z:[src.z] has errored. [src.network?"Empty network list":"Null network list"]")
		else
			error("[src.name] in [get_area(src)]has errored. [src.network?"Empty network list":"Null network list"]")
		ASSERT(src.network)
		ASSERT(src.network.len > 0)
	..()

/obj/machinery/camera/Del()
	if(!alarm_on)
		triggerCameraAlarm()
	
	cancelCameraAlarm()
	..()

/obj/machinery/camera/emp_act(severity)
	if(!isEmpProof())
		if(prob(100/severity))
			stat |= EMPED
			SetLuminosity(0)
			kick_viewers()
			triggerCameraAlarm()
			update_icon()
			
			spawn(900)
				stat &= ~EMPED
				cancelCameraAlarm()
				update_icon()
			
			..()

/obj/machinery/camera/bullet_act(var/obj/item/projectile/P)
	if(P.damage_type == BRUTE || P.damage_type == BURN)
		take_damage(P.damage)

/obj/machinery/camera/ex_act(severity)
	if(src.invuln)
		return
	
	//camera dies if an explosion touches it!
	if(severity <= 2 || prob(50))
		destroy()
	
	..() //and give it the regular chance of being deleted outright


/obj/machinery/camera/blob_act()
	return

/obj/machinery/camera/hitby(AM as mob|obj)
	..()
	if (istype(AM, /obj))
		var/obj/O = AM
		if (O.throwforce >= src.toughness)
			visible_message("<span class='warning'><B>[src] was hit by [O].</B></span>")
		take_damage(O.throwforce)

/obj/machinery/camera/proc/setViewRange(var/num = 7)
	src.view_range = num
	cameranet.updateVisibility(src, 0)

/obj/machinery/camera/attack_hand(mob/living/carbon/human/user as mob)

	if(!istype(user))
		return

	if(user.species.can_shred(user))
		set_status(0)
		visible_message("<span class='warning'>\The [user] slashes at [src]!</span>")
		playsound(src.loc, 'sound/weapons/slash.ogg', 100, 1)
		icon_state = "[initial(icon_state)]1"
		add_hiddenprint(user)
		destroy()

/obj/machinery/camera/attackby(obj/W as obj, mob/living/user as mob)

	// DECONSTRUCTION
	if(isscrewdriver(W))
		//user << "<span class='notice'>You start to [panel_open ? "close" : "open"] the camera's panel.</span>"
		//if(toggle_panel(user)) // No delay because no one likes screwdrivers trying to be hip and have a duration cooldown
		panel_open = !panel_open
		user.visible_message("<span class='warning'>[user] screws the camera's panel [panel_open ? "open" : "closed"]!</span>",
		"<span class='notice'>You screw the camera's panel [panel_open ? "open" : "closed"].</span>")
		playsound(src.loc, 'sound/items/Screwdriver.ogg', 50, 1)

	else if((iswirecutter(W) || ismultitool(W)) && panel_open)
		interact(user)

	else if(iswelder(W) && (wires.CanDeconstruct() || (stat & BROKEN)))
		if(weld(W, user))
			if (stat & BROKEN)
				new /obj/item/weapon/circuitboard/broken(src.loc)
				new /obj/item/stack/cable_coil(src.loc, length=2)
			else if(assembly)
				assembly.loc = src.loc
				assembly.state = 1
				new /obj/item/stack/cable_coil(src.loc, length=2)
			del(src)

	// OTHER
	else if (can_use() && (istype(W, /obj/item/weapon/paper) || istype(W, /obj/item/device/pda)) && isliving(user))
		var/mob/living/U = user
		var/obj/item/weapon/paper/X = null
		var/obj/item/device/pda/P = null

		var/itemname = ""
		var/info = ""
		if(istype(W, /obj/item/weapon/paper))
			X = W
			itemname = X.name
			info = X.info
		else
			P = W
			itemname = P.name
			info = P.notehtml
		U << "You hold \a [itemname] up to the camera ..."
		for(var/mob/living/silicon/ai/O in living_mob_list)
			if(!O.client) continue
			if(U.name == "Unknown") O << "<b>[U]</b> holds \a [itemname] up to one of your cameras ..."
			else O << "<b><a href='byond://?src=\ref[O];track2=\ref[O];track=\ref[U]'>[U]</a></b> holds \a [itemname] up to one of your cameras ..."
			O << browse(text("<HTML><HEAD><TITLE>[]</TITLE></HEAD><BODY><TT>[]</TT></BODY></HTML>", itemname, info), text("window=[]", itemname))
		for(var/mob/O in player_list)
			if (istype(O.machine, /obj/machinery/computer/security))
				var/obj/machinery/computer/security/S = O.machine
				if (S.current == src)
					O << "[U] holds \a [itemname] up to one of the cameras ..."
					O << browse(text("<HTML><HEAD><TITLE>[]</TITLE></HEAD><BODY><TT>[]</TT></BODY></HTML>", itemname, info), text("window=[]", itemname))
	
	else if (istype(W, /obj/item/weapon/camera_bug))
		if (!src.can_use())
			user << "\blue Camera non-functional"
			return
		if (src.bugged)
			user << "\blue Camera bug removed."
			src.bugged = 0
		else
			user << "\blue Camera bugged."
			src.bugged = 1
			
	else if(W.damtype == BRUTE || W.damtype == BURN) //bashing cameras
		if (W.force >= src.toughness)
			visible_message("<span class='warning'><b>[src] has been [pick(W.attack_verb)] with [W] by [user]!</b></span>")
			if (istype(W, /obj/item)) //is it even possible to get into attackby() with non-items?
				var/obj/item/I = W
				if (I.hitsound)
					playsound(loc, I.hitsound, 50, 1, -1)
		take_damage(W.force)
	
	else
		..()

/obj/machinery/camera/proc/deactivate(user as mob, var/choice = 1)
	if(choice != 1)
		//legacy support, if choice is != 1 then just kick viewers without changing status
		kick_viewers()
	else
		set_status( !src.status )
		if (!(src.status))
			visible_message("\red [user] has deactivated [src]!")
			playsound(src.loc, 'sound/items/Wirecutter.ogg', 100, 1)
			icon_state = "[initial(icon_state)]1"
			add_hiddenprint(user)
		else
			visible_message("\red [user] has reactivated [src]!")
			playsound(src.loc, 'sound/items/Wirecutter.ogg', 100, 1)
			icon_state = initial(icon_state)
			add_hiddenprint(user)

/obj/machinery/camera/proc/take_damage(var/force, var/message)
	//prob(25) gives an average of 3-4 hits
	if (force >= toughness && (force > toughness*4 || prob(25)))
		destroy()

//Used when someone breaks a camera 
/obj/machinery/camera/proc/destroy()
	stat |= BROKEN
	kick_viewers()
	triggerCameraAlarm()
	update_icon()
	
	//sparks
	var/datum/effect/effect/system/spark_spread/spark_system = new /datum/effect/effect/system/spark_spread()
	spark_system.set_up(5, 0, loc)
	spark_system.start()
	playsound(loc, "sparks", 50, 1)

/obj/machinery/camera/proc/set_status(var/newstatus)
	if (status != newstatus)
		status = newstatus
		// now disconnect anyone using the camera
		//Apparently, this will disconnect anyone even if the camera was re-activated.
		//I guess that doesn't matter since they couldn't use it anyway?
		kick_viewers()

//This might be redundant, because of check_eye()
/obj/machinery/camera/proc/kick_viewers()
	for(var/mob/O in player_list)
		if (istype(O.machine, /obj/machinery/computer/security))
			var/obj/machinery/computer/security/S = O.machine
			if (S.current == src)
				O.unset_machine()
				O.reset_view(null)
				O << "The screen bursts into static."

/obj/machinery/camera/update_icon()
	if (!status || (stat & BROKEN))
		icon_state = "[initial(icon_state)]1"
	else if (stat & EMPED)
		icon_state = "[initial(icon_state)]emp"
	else
		icon_state = initial(icon_state)

/obj/machinery/camera/proc/triggerCameraAlarm()
	alarm_on = 1
	if(!get_area(src))
		return
	
	for(var/mob/living/silicon/S in mob_list)
		S.triggerAlarm("Camera", get_area(src), list(src), src)


/obj/machinery/camera/proc/cancelCameraAlarm()
	alarm_on = 0
	if(!get_area(src))
		return
	
	for(var/mob/living/silicon/S in mob_list)
		S.cancelAlarm("Camera", get_area(src), src)

//if false, then the camera is listed as DEACTIVATED and cannot be used
/obj/machinery/camera/proc/can_use()
	if(!status)
		return 0
	if(stat & (EMPED|BROKEN))
		return 0
	return 1

/obj/machinery/camera/proc/can_see()
	var/list/see = null
	var/turf/pos = get_turf(src)
	if(isXRay())
		see = range(view_range, pos)
	else
		see = hear(view_range, pos)
	return see

/atom/proc/auto_turn()
	//Automatically turns based on nearby walls.
	var/turf/simulated/wall/T = null
	for(var/i = 1, i <= 8; i += i)
		T = get_ranged_target_turf(src, i, 1)
		if(istype(T))
			//If someone knows a better way to do this, let me know. -Giacom
			switch(i)
				if(NORTH)
					src.set_dir(SOUTH)
				if(SOUTH)
					src.set_dir(NORTH)
				if(WEST)
					src.set_dir(EAST)
				if(EAST)
					src.set_dir(WEST)
			break

//Return a working camera that can see a given mob
//or null if none
/proc/seen_by_camera(var/mob/M)
	for(var/obj/machinery/camera/C in oview(4, M))
		if(C.can_use())	// check if camera disabled
			return C
			break
	return null

/proc/near_range_camera(var/mob/M)

	for(var/obj/machinery/camera/C in range(4, M))
		if(C.can_use())	// check if camera disabled
			return C
			break

	return null

/obj/machinery/camera/proc/weld(var/obj/item/weapon/weldingtool/WT, var/mob/user)

	if(busy)
		return 0
	if(!WT.isOn())
		return 0

	// Do after stuff here
	user << "<span class='notice'>You start to weld the [src]..</span>"
	playsound(src.loc, 'sound/items/Welder.ogg', 50, 1)
	WT.eyecheck(user)
	busy = 1
	if(do_after(user, 100))
		busy = 0
		if(!WT.isOn())
			return 0
		return 1
	busy = 0
	return 0

/obj/machinery/camera/interact(mob/living/user as mob)
	if(!panel_open || istype(user, /mob/living/silicon/ai))
		return
	
	if(stat & BROKEN)
		user << "<span class='warning'>\The [src] is broken.</span>"
		return

	user.set_machine(src)
	wires.Interact(user)
