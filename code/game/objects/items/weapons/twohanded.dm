/* Two-handed Weapons
 * Contains:
 * 		Twohanded
 *		Fireaxe
 *		Double-Bladed Energy Swords
 */

/*##################################################################
##################### TWO HANDED WEAPONS BE HERE~ -Agouri :3 ########
####################################################################*/

//Rewrote TwoHanded weapons stuff and put it all here. Just copypasta fireaxe to make new ones ~Carn
//This rewrite means we don't have two variables for EVERY item which are used only by a few weapons.
//It also tidies stuff up elsewhere.

/*
 * Twohanded
 */
/obj/item/weapon/twohanded
	var/wielded = 0
	var/force_wielded = 0
	var/wieldsound = null
	var/unwieldsound = null

/obj/item/weapon/twohanded/proc/unwield()
	wielded = 0
	force = initial(force)
	name = "[initial(name)]"
	update_icon()

/obj/item/weapon/twohanded/proc/wield()
	wielded = 1
	force = force_wielded
	name = "[initial(name)] (Wielded)"
	update_icon()

/obj/item/weapon/twohanded/mob_can_equip(M as mob, slot)
	//Cannot equip wielded items.
	if(wielded)
		M << "<span class='warning'>Unwield the [initial(name)] first!</span>"
		return 0

	return ..()

/obj/item/weapon/twohanded/dropped(mob/user as mob)
	//handles unwielding a twohanded weapon when dropped as well as clearing up the offhand
	if(user)
		var/obj/item/weapon/twohanded/O = user.get_inactive_hand()
		if(istype(O))
			O.unwield()
	return	unwield()

/obj/item/weapon/twohanded/update_icon()
	return

/obj/item/weapon/twohanded/pickup(mob/user)
	unwield()

/obj/item/weapon/twohanded/attack_self(mob/user as mob)
	if( istype(user,/mob/living/carbon/monkey) )
		user << "<span class='warning'>It's too heavy for you to wield fully.</span>"
		return

	..()

	if(wielded) //Trying to unwield it
		unwield()
		user << "<span class='notice'>You are now carrying the [name] with one hand.</span>"
		if (src.unwieldsound)
			playsound(src.loc, unwieldsound, 50, 1)

		var/obj/item/weapon/twohanded/offhand/O = user.get_inactive_hand()
		if(O && istype(O))
			O.unwield()

	else //Trying to wield it
		if(user.get_inactive_hand())
			user << "<span class='warning'>You need your other hand to be empty</span>"
			return
		wield()
		user << "<span class='notice'>You grab the [initial(name)] with both hands.</span>"
		if (src.wieldsound)
			playsound(src.loc, wieldsound, 50, 1)

		var/obj/item/weapon/twohanded/offhand/O = new(user) ////Let's reserve his other hand~
		O.name = "[initial(name)] - offhand"
		O.desc = "Your second grip on the [initial(name)]"
		user.put_in_inactive_hand(O)

	if(istype(user,/mob/living/carbon/human))
		var/mob/living/carbon/human/H = user
		H.update_inv_l_hand()
		H.update_inv_r_hand()

	return

///////////OFFHAND///////////////
/obj/item/weapon/twohanded/offhand
	w_class = 5.0
	icon_state = "offhand"
	name = "offhand"

	unwield()
		del(src)

	wield()
		del(src)

/*
 * Fireaxe
 */
/obj/item/weapon/twohanded/fireaxe  // DEM AXES MAN, marker -Agouri
	icon_state = "fireaxe0"
	name = "fire axe"
	desc = "Truly, the weapon of a madman. Who would think to fight fire with an axe?"
	force = 10
	sharp = 1
	edge = 1
	w_class = 4.0
	slot_flags = SLOT_BACK
	force_wielded = 40
	attack_verb = list("attacked", "chopped", "cleaved", "torn", "cut")

/obj/item/weapon/twohanded/fireaxe/update_icon()  //Currently only here to fuck with the on-mob icons.
	icon_state = "fireaxe[wielded]"
	return

/obj/item/weapon/twohanded/fireaxe/afterattack(atom/A as mob|obj|turf|area, mob/user as mob, proximity)
	if(!proximity) return
	..()
	if(A && wielded && (istype(A,/obj/structure/window) || istype(A,/obj/structure/grille))) //destroys windows and grilles in one hit
		if(istype(A,/obj/structure/window)) //should just make a window.Break() proc but couldn't bother with it
			var/obj/structure/window/W = A

			new /obj/item/weapon/shard( W.loc )
			if(W.reinf) new /obj/item/stack/rods( W.loc)

			if (W.dir == SOUTHWEST)
				new /obj/item/weapon/shard( W.loc )
				if(W.reinf) new /obj/item/stack/rods( W.loc)
		del(A)


/*
 * Double-Bladed Energy Swords - Cheridan
 */
/obj/item/weapon/twohanded/dualsaber
	icon_state = "dualsaber0"
	name = "double-bladed energy sword"
	desc = "Handle with care."
	force = 3
	throwforce = 5.0
	throw_speed = 1
	throw_range = 5
	w_class = 2.0
	force_wielded = 30
	wieldsound = 'sound/weapons/saberon.ogg'
	unwieldsound = 'sound/weapons/saberoff.ogg'
	flags = FPRINT | TABLEPASS | NOSHIELD
	origin_tech = "magnets=3;syndicate=4"
	attack_verb = list("attacked", "slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut")
	sharp = 1
	edge = 1

/obj/item/weapon/twohanded/dualsaber/update_icon()
	icon_state = "dualsaber[wielded]"
	return

/obj/item/weapon/twohanded/dualsaber/attack(target as mob, mob/living/user as mob)
	..()
	if((CLUMSY in user.mutations) && (wielded) &&prob(40))
		user << "\red You twirl around a bit before losing your balance and impaling yourself on the [src]."
		user.take_organ_damage(20,25)
		return
	if((wielded) && prob(50))
		spawn(0)
			for(var/i in list(1,2,4,8,4,2,1,2,4,8,4,2))
				user.set_dir(i)
				sleep(1)

/obj/item/weapon/twohanded/dualsaber/IsShield()
	if(wielded)
		return 1
	else
		return 0

//spears, bay edition
/obj/item/weapon/twohanded/spear
	icon_state = "spearglass0"
	name = "spear"
	desc = "A haphazardly-constructed yet still deadly weapon of ancient design."
	force = 14
	w_class = 4.0
	slot_flags = SLOT_BACK
	force_wielded = 22 // Was 13, Buffed - RR
	throwforce = 20
	throw_speed = 3
	edge = 0
	sharp = 1
	flags = NOSHIELD
	hitsound = 'sound/weapons/bladeslice.ogg'
	attack_verb = list("attacked", "poked", "jabbed", "torn", "gored")

/obj/item/weapon/twohanded/spear/update_icon()
	icon_state = "spearglass[wielded]"
	return
