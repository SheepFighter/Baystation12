/obj/machinery/autolathe
	name = "\improper autolathe"
	desc = "It produces items using metal and glass."
	icon_state = "autolathe"
	density = 1
	anchored = 1
	use_power = 1
	idle_power_usage = 10
	active_power_usage = 100

	var/list/machine_recipes
	var/list/stored_material =  list("metal" = 0, "glass" = 0)
	var/list/storage_capacity = list("metal" = 0, "glass" = 0)
	var/show_category = "All"

	var/panel_open = 0
	var/hacked = 0
	var/disabled = 0
	var/shocked = 0
	var/busy = 0

	var/datum/wires/autolathe/wires = null

/obj/machinery/autolathe/interact(mob/user as mob)

	if(..() || (disabled && !panel_open))
		user << "\red \The [src] is disabled!"
		return

	if (shocked)
		shock(user,50)

	var/dat = "<center><h1>Autolathe Control Panel</h1><hr/>"

	if(!disabled)
		dat += "<table width = '100%'>"
		var/material_top = "<tr>"
		var/material_bottom = "<tr>"

		for(var/material in stored_material)
			material_top += "<td width = '25%' align = center><b>[material]</b></td>"
			material_bottom += "<td width = '25%' align = center>[stored_material[material]]<b>/[storage_capacity[material]]</b></td>"

		dat += "[material_top]</tr>[material_bottom]</tr></table><hr>"
		dat += "<h2>Printable Designs</h2><h3>Showing: <a href='?src=\ref[src];change_category=1'>[show_category]</a>.</h3></center><table width = '100%'>"

		var/index = 0
		for(var/datum/autolathe/recipe/R in machine_recipes)
			index++
			if(R.hidden && !hacked || (show_category != "All" && show_category != R.category))
				continue
			var/can_make = 1
			var/material_string = ""
			var/multiplier_string = ""
			var/max_sheets
			var/comma
			if(!R.resources || !R.resources.len)
				material_string = "No resources required.</td>"
			else
				//Make sure it's buildable and list requires resources.
				for(var/material in R.resources)
					var/sheets = round(stored_material[material]/R.resources[material])
					if(isnull(max_sheets) || max_sheets > sheets)
						max_sheets = sheets
					if(!isnull(stored_material[material]) && stored_material[material] < R.resources[material])
						can_make = 0
					if(!comma)
						comma = 1
					else
						material_string += ", "
					material_string += "[R.resources[material]] [material]"
				material_string += ".<br></td>"
				//Build list of multipliers for sheets.
				if(R.is_stack)
					if(max_sheets && max_sheets > 0)
						multiplier_string  += "<br>"
						for(var/i = 5;i<max_sheets;i*=2) //5,10,20,40...
							multiplier_string  += "<a href='?src=\ref[src];make=[index];multiplier=[i]'>\[x[i]\]</a>"
						multiplier_string += "<a href='?src=\ref[src];make=[index];multiplier=[max_sheets]'>\[x[max_sheets]\]</a>"

			dat += "<tr><td width = 180>[R.hidden ? "<font color = 'red'>*</font>" : ""]<b>[can_make ? "<a href='?src=\ref[src];make=[index];multiplier=1'>" : ""][R.name][can_make ? "</a>" : ""]</b>[R.hidden ? "<font color = 'red'>*</font>" : ""][multiplier_string]</td><td align = right>[material_string]</tr>"

		dat += "</table><hr>"
	//Hacking.
	if(panel_open)
		dat += "<h2>Maintenance Panel</h2>"
		dat += wires.GetInteractWindow()

		dat += "<hr>"

	user << browse(dat, "window=autolathe")
	onclose(user, "autolathe")

/obj/machinery/autolathe/attackby(var/obj/item/O as obj, var/mob/user as mob)

	if (stat)
		return

	if (busy)
		user << "\red \The [src] is busy. Please wait for completion of previous operation."
		return

	if(istype(O, /obj/item/weapon/screwdriver))
		panel_open = !panel_open
		icon_state = (panel_open ? "autolathe_t": "autolathe")
		user << "You [panel_open ? "open" : "close"] the maintenance hatch of [src]."
		updateUsrDialog()
		return

	if (panel_open)
		//Don't eat multitools or wirecutters used on an open lathe.
		if(istype(O, /obj/item/device/multitool) || istype(O, /obj/item/weapon/wirecutters))
			attack_hand(user)
			return

		//Dismantle the frame.
		if(istype(O, /obj/item/weapon/crowbar))
			dismantle()
			return

	if(O.loc != user && !(istype(O,/obj/item/stack)))
		return 0

	//Resources are being loaded.
	var/obj/item/eating = O
	if(!eating.matter)
		user << "\The [eating] does not contain significant amounts of useful materials and cannot be accepted."
		return

	var/filltype = 0       // Used to determine message.
	var/total_used = 0     // Amount of material used.
	var/mass_per_sheet = 0 // Amount of material constituting one sheet.

	for(var/material in eating.matter)

		if(isnull(stored_material[material]) || isnull(storage_capacity[material]))
			continue

		if(stored_material[material] >= storage_capacity[material])
			continue

		var/total_material = eating.matter[material]

		//If it's a stack, we eat multiple sheets.
		if(istype(eating,/obj/item/stack))
			var/obj/item/stack/stack = eating
			total_material *= stack.get_amount()

		if(stored_material[material] + total_material > storage_capacity[material])
			total_material = storage_capacity[material] - stored_material[material]
			filltype = 1
		else
			filltype = 2

		stored_material[material] += total_material
		total_used += total_material
		mass_per_sheet += eating.matter[material]

	if(!filltype)
		user << "\red \The [src] is full. Please remove material from the autolathe in order to insert more."
		return
	else if(filltype == 1)
		user << "You fill \the [src] to capacity with \the [eating]."
	else
		user << "You fill \the [src] with \the [eating]."

	flick("autolathe_o",src) // Plays metal insertion animation. Work out a good way to work out a fitting animation. ~Z

	if(istype(eating,/obj/item/stack))
		var/obj/item/stack/stack = eating
		stack.use(max(1,round(total_used/mass_per_sheet))) // Always use at least 1 to prevent infinite materials.
	else
		user.drop_item(O)
		del(O)

	updateUsrDialog()
	return

/obj/machinery/autolathe/attack_hand(mob/user as mob)
	user.set_machine(src)
	interact(user)

/obj/machinery/autolathe/Topic(href, href_list)

	if(..())
		return

	usr.set_machine(src)
	add_fingerprint(usr)

	if(busy)
		usr << "\red The autolathe is busy. Please wait for completion of previous operation."
		return

	if(href_list["change_category"])

		var/choice = input("Which category do you wish to display?") as null|anything in autolathe_categories+"All"
		if(!choice) return
		show_category = choice

	if(href_list["make"] && machine_recipes)

		var/index = text2num(href_list["make"])
		var/multiplier = text2num(href_list["multiplier"])
		var/datum/autolathe/recipe/making

		if(index > 0 && index <= machine_recipes.len)
			making = machine_recipes[index]

		//Exploit detection, not sure if necessary after rewrite.
		if(!making || multiplier < 0 || multiplier > 100)
			var/turf/exploit_loc = get_turf(usr)
			message_admins("[key_name_admin(usr)] tried to exploit an autolathe to duplicate an item! ([exploit_loc ? "<a href='?_src_=holder;adminplayerobservecoodjump=1;X=[exploit_loc.x];Y=[exploit_loc.y];Z=[exploit_loc.z]'>JMP</a>" : "null"])", 0)
			log_admin("EXPLOIT : [key_name(usr)] tried to exploit an autolathe to duplicate an item!")
			return

		busy = 1
		//This needs some work.
		use_power(max(2000, (making.power_use*multiplier)))

		//Check if we still have the materials.
		for(var/material in making.resources)
			if(!isnull(stored_material[material]))
				if(stored_material[material] < (making.resources[material]*multiplier))
					return

		//Consume materials.
		for(var/material in making.resources)
			if(!isnull(stored_material[material]))
				stored_material[material] = max(0,stored_material[material]-(making.resources[material]*multiplier))

		//Fancy autolathe animation.
		flick("autolathe_n",src)

		sleep(50)

		busy = 0

		//Sanity check.
		if(!making || !src) return

		//Create the desired item.
		var/obj/item/I = new making.path(get_step(loc, get_dir(src,usr)))
		if(multiplier>1 && istype(I,/obj/item/stack))
			var/obj/item/stack/S = I
			S.amount = multiplier

	updateUsrDialog()


/obj/machinery/autolathe/New()

	..()
	wires = new(src)
	//Create parts for lathe.
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/autolathe(src)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(src)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(src)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(src)
	component_parts += new /obj/item/weapon/stock_parts/manipulator(src)
	component_parts += new /obj/item/weapon/stock_parts/console_screen(src)
	RefreshParts()


/obj/machinery/autolathe/initialize()
	..()
	machine_recipes = autolathe_recipes

//Updates overall lathe storage size.
/obj/machinery/autolathe/RefreshParts()
	..()
	var/tot_rating = 0
	for(var/obj/item/weapon/stock_parts/matter_bin/MB in component_parts)
		tot_rating += MB.rating

	storage_capacity["metal"] = tot_rating  * 25000
	storage_capacity["glass"] = tot_rating  * 12500

/obj/machinery/autolathe/dismantle()
	..()
	var/list/sheets = list("metal" = /obj/item/stack/sheet/metal, "glass" = /obj/item/stack/sheet/glass)

	for(var/mat in stored_material)
		var/T = sheets[mat]
		var/obj/item/stack/sheet/S = new T
		if(stored_material[mat] > S.perunit)
			S.amount = round(stored_material[mat] / S.perunit)
			S.loc = loc
