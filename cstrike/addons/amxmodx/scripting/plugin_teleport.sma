/*****************************************************************************************
* Teleportation commands, by bahrmanou © 2002-2006 e-mail: Amiga5707@hotmail.com
*
* This plugin was written for TFC in mind, but could be useful for other mods too.
* Very handy in cooperative/concjump/pipejump/etc... maps.
*
* All 'amx_tp' commands allowed only for users with permission level ADMIN_LEVEL_B
* except amx_tpallow and amx_tpallowuser which are allowed for ADMIN_RCON only
* (change if you dont like it).
*
* The 'say' commands are for all.
*
* This plugin was first written for Adminmod (by me).
*
*
* Very big thanks to NL)Ramon(NL for his auto-unstuck plugin!!
*
* Versions:
*
* - 1.3: added amx_tpgo
* - 1.4: added angles stuff and velocity
* - 1.4.1: viewing angles fixed
* - 1.4.2: removed 'youre not really stuck' bit, didnt work
* - 1.4.3: replaced client_print(..print_console,..) by console_print()
* - 1.4.4: added /l command
*          added /stats command
* - 1.5: added support for speedrun mode
* - 1.6: added plugin_cfg() which restart cvar amx_teleport for each map.
* - 1.7: added amx_tpaim
* - 1.7.1: cannot save position while in noclip mode
* - 1.7.2: delay for destuckme as for posme
* - 1.8: new unstuck method thx to NL)Ramon(NL !
*
*****************************************************************************************/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fun>
#include <fakemeta>
#include <entconst>

#define USE_SPEEDRUN		1		// comment this line out if u dont use speedrun

#define PLUGNAME		"plugin_teleport"
#define VERSION			"1.8"
#define AUTHOR			"Bahrmanou"

#define ACCESS_TELEPORT 	ADMIN_LEVEL_B
#define ACCESS_ADMIN		ADMIN_RCON
#define MAX_TEXT_LENGTH		200
#define MAX_DATA_LENGTH		200
#define MAX_NAME_LENGTH		33
#define MAX_NUMBER_LENGTH	20
#define MAX_PLAYERS		33
#define NUMSLOTS		40		// slots: 40 slots seems enough but change it if u want to
#define NUM_EFFECTS		6

new g_effects[NUM_EFFECTS+1][] = {
	"Random",
	"Teleport",
	"Sparks",
	"Lavasplash",
	"Explosion",
	"Implosion",
	"Light"
}

new g_stats[MAX_PLAYERS][2]
new g_cfgfilepath[MAX_TEXT_LENGTH]
new g_slot_name[NUMSLOTS][MAX_TEXT_LENGTH]
new g_slot[NUMSLOTS][3]
new g_slot_angle[NUMSLOTS][3]
new g_user[2][MAX_PLAYERS][3]
new g_user_angle[2][MAX_PLAYERS][3]
new g_player_allowed[MAX_PLAYERS]
new g_pos_delay_status = 1			// teleport delay is ON by default
new g_pos_delay = 2				// delay = 2 secs
new g_last_time[MAX_PLAYERS]
new g_tp_sounds[3][25] = {
	"items/r_item1.wav",
	"items/r_item2.wav",
	"items/health1.wav"
}

new g_cvteleport
new g_cvteleport_effect
new g_cvunstuck
new g_cvunstuck_effect

#if defined USE_SPEEDRUN
new g_vault_str[10]
#endif

public plugin_precache()
{
	if (entity_count() < get_global_int(GL_maxEntities) - 15*get_maxplayers() - 2) {
		for (new i=0; i<3; i++) {
			precache_sound(g_tp_sounds[i])
		}
	}
}


public plugin_init() {
	register_plugin(PLUGNAME, VERSION, AUTHOR)
	
	new efstr[100]
	formatex(efstr, 99, "- [n]: get/set teleporting effect ([0,%d], 0 = random).", NUM_EFFECTS)
	
	register_concmd("amx_tpstack", "amx_tpstack", ACCESS_TELEPORT, "- [user]: stack players on you.")
	register_concmd("amx_tpallow", "amx_tpallow", ACCESS_ADMIN,  "- [on|off|0|1]: enable/disable teleporting.")
	register_concmd("amx_tpallowuser","amx_tpallowuser",ACCESS_ADMIN,"- <target> ['on'|'off']: enable/disable teleporting for target.")
	register_concmd("amx_tpeffect", "amx_tpeffect", ACCESS_TELEPORT, efstr)
	register_concmd("amx_tpempty","amx_tpempty",ACCESS_TELEPORT,": remove all positions in list.")
	register_concmd("amx_tpadd","amx_tpadd",ACCESS_TELEPORT,"- [target]: add target position in first free slot.")
	register_concmd("amx_tpmem","amx_tpmem",ACCESS_TELEPORT,"- <target> <Slot_num>: memorize target position in a slot.")
	register_concmd("amx_tp","amx_tp",ACCESS_TELEPORT,"- <target> <Slot_num | Slot_name>: teleport target from a g_slot.")
	register_concmd("amx_tpgo","amx_tpgo",ACCESS_TELEPORT,"- <target> <x> <y> <z>: teleport target to coordinates.")
	register_concmd("amx_tplist","amx_tplist",ACCESS_TELEPORT,": display memorised positions.")
	register_concmd("amx_tpload","amx_tpload",ACCESS_TELEPORT,": load positions from file.")
	register_concmd("amx_tpsave","amx_tpsave",ACCESS_TELEPORT,": save positions to file.")
	register_concmd("amx_tpname","amx_tpname",ACCESS_TELEPORT,"- <Slot_num> [Slot_name]: name or unname a slot.")
	register_concmd("amx_tpcopy","amx_tpcopy",ACCESS_TELEPORT,"- <user> <target>: copy the user position to target.")
	register_concmd("amx_tpsend","amx_tpsend",ACCESS_TELEPORT,"- <user> <target>: stack user on target.")
	register_concmd("amx_tpaim","amx_tpaim",ACCESS_TELEPORT,"- <user>: send user where im looking.")
	register_concmd("amx_tpdelay","amx_tpdelay",ACCESS_TELEPORT,"- [delay]: set a delay between 2 posme (0 = OFF).")
	register_concmd("amx_tpinfo","amx_tpinfo",ACCESS_TELEPORT,": display the current position coordinates.")
	
	register_clcmd("say saveme", "cmdSaveme", 0, ": save your current position.")
	register_clcmd("say /s", "cmdSaveme", 0, ": save your current position.")
	register_clcmd("say saveme2", "cmdSaveme2", 0, ": save your second current position.")
	register_clcmd("say posme", "cmdPosme", 0, ": teleport you back at your saved position.")
	register_clcmd("say /p", "cmdPosme", 0, ": teleport you back at your saved position.")
	register_clcmd("say /l", "cmdPosme", 0, ": teleport you back at your saved position.")
	register_clcmd("say posme2", "cmdPosme2", 0, ": teleport you back at your second saved position.")
	register_clcmd("say /stats", "cmdStats", 0, ": displays checkpoint stats.")
	register_clcmd("say /teleport_version", "cmdVersion", 0, "")
	
	g_cvteleport = register_cvar("amx_teleport", "1")
	g_cvteleport_effect = register_cvar("amx_teleport_effect", "1")
	
	// automatic unstuck cvars
	g_cvunstuck = register_cvar("amx_autounstuck","1")
	g_cvunstuck_effect = register_cvar("amx_autounstuckeffects","1")
	
	// empty the players positions.
	for (new i=1; i<MAX_PLAYERS; i++) {
		g_user[0][i][0] = g_user[0][i][1] = g_user[0][i][2] = -1
		g_user[1][i][0] = g_user[1][i][1] = g_user[1][i][2] = -1
	}
	// empty and load list (if file exists) at map change automatically
	for (new i=0; i<NUMSLOTS; i++) {
		formatex(g_slot_name[i], MAX_TEXT_LENGTH, "pos%i", i+1)
		g_slot[i][0] = g_slot[i][1] = g_slot[i][2] = -1
	}
	
	new map[MAX_TEXT_LENGTH], cfgdir[MAX_TEXT_LENGTH]
	get_mapname(map, MAX_TEXT_LENGTH-1)
	get_configsdir(cfgdir, MAX_TEXT_LENGTH)
	formatex(g_cfgfilepath, MAX_TEXT_LENGTH-1, "%s/pos", cfgdir)
	if (!dir_exists(g_cfgfilepath)) {
		mkdir(g_cfgfilepath)
	}
	formatex(g_cfgfilepath, MAX_TEXT_LENGTH-1, "%s/pos/%s.pos", cfgdir, map)
	read_file_(g_cfgfilepath)

	set_task(0.1,"checkstuck")

	return PLUGIN_CONTINUE;
}

public plugin_cfg() {
	set_cvar_num("amx_teleport", 1)
	set_cvar_num("amx_teleport_effect", 1)
	set_cvar_num("g_cvunstuck", 1)
	set_cvar_num("g_cvunstuck_effect", 1)
}

public client_putinserver(id) {
	g_player_allowed[id] = 1
	g_last_time[id] = 0
	g_stats[id][0] = g_stats[id][1] = 0
}


/*****************************************************************************************
*
*	amx_tpallow
*
*       syntax:
*       amx_tpallow flag             flag: 'on' | 'off' | 0 | 1
*       amx_tpallow                  display current teleporting status
*
******************************************************************************************/
public amx_tpallow(id, level, cid) {
	new arg1[5], flag = get_pcvar_num(g_cvteleport)
	
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	read_argv(1, arg1, 4)
	
	if (arg1[0]) { // argument present
		new argument = str_to_num(arg1)
		if (equali(arg1, "on") || argument) {
			if (flag) {
				console_print(id, "Teleportation already ON!")
			} else {
				console_print(id, "Teleportation is now ON.")
				set_cvar_num("amx_teleport", 1)
			}
		} else {
			if (!flag) {
				console_print(id, "Teleportation already OFF!")
			} else {
				console_print(id, "Teleportation is now OFF.")
				set_cvar_num("amx_teleport", 0)
			}
		}
	} else { // no argument, read the current
		if (flag) {
			console_print(id, "Teleportation is ON.")
		} else {
			console_print(id, "Teleportation is OFF.")
		}
	}
	
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpallowuser
*
*       syntax:
*       amx_tpallowuser #user flag           flag: 'on' | 'off' | '0'| '1'
*
******************************************************************************************/
public amx_tpallowuser(id, level, cid) {
	if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED
	
	new user, arg1[MAX_NAME_LENGTH], arg2[5]
	
	read_argv(1, arg1, MAX_NAME_LENGTH-1)
	read_argv(2, arg2, 4)
	
	user = cmd_target(id, arg1, 2)
	if (!user) {
		console_print(id, "Unknown player: %s!", arg1)
		return PLUGIN_HANDLED
	}
	new userName[MAX_NAME_LENGTH]
	get_user_name(user, userName, MAX_NAME_LENGTH-1)
	
	if (!access(id, ACCESS_ADMIN) && access(user, ADMIN_IMMUNITY)) {
		console_print(id, "%s is immune, you cannot do that!", userName)
		return PLUGIN_HANDLED
	}
	
	if (equali(arg2, "on") || equali(arg2, "1")) {
		g_player_allowed[user] = 1
		console_print(id, "Player %s can now teleport himself.", userName)
	} else {
		g_player_allowed[user] = 0
		console_print(id, "Player %s is now unable to teleport himself.", userName)
	}
	
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpeffect
*
*       syntax:
*       amx_tpeffect [n]             get/set teleporting effect
*
******************************************************************************************/
public amx_tpeffect(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new effectStr[2], effect
	
	read_argv(1, effectStr, 1)
	if (!effectStr[0]) {
		console_print(id, "Effects:")
		for (new i=0; i<=NUM_EFFECTS; i++) {
			console_print(id, "%d : %s", i, g_effects[i])
		}
		console_print(id, "^nTeleport effect is currently: %d.^n", get_pcvar_num(g_cvteleport_effect))
		return PLUGIN_HANDLED
	}
	effect = str_to_num(effectStr)
	if (effect<0 || effect>NUM_EFFECTS) {
		console_print(id, "Effect must be in range [0,%d]!", NUM_EFFECTS)
		return PLUGIN_HANDLED
	}
	set_cvar_num("amx_teleport_effect", effect)
	return PLUGIN_HANDLED
}

/*****************************************************************************************
*
*	amx_tpdelay
*
*       syntax:
*       amx_tpdelay          get the delay status and value
*       amx_tpdelay 0        set delay status OFF
*       amx_tpdelay secs     set delay status ON and value in seconds
*
******************************************************************************************/
public amx_tpdelay(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new arg1[MAX_NUMBER_LENGTH]
	new delay;
	
	read_argv(1, arg1, MAX_NUMBER_LENGTH-1)
	
	if (!arg1[0]) {
		if (!g_pos_delay_status) {
			console_print(id, "Teleportation delay is disabled.")
		} else {
			console_print(id, "Teleportation delay is enabled and is set to %d seconds.", g_pos_delay)
		}
		return PLUGIN_HANDLED;
	}
	delay = str_to_num(arg1)
	if (delay == 0) {
		g_pos_delay_status = 0;
		console_print(id, "Teleportation delay is now disabled.")
	} else {
		g_pos_delay_status = 1;
		g_pos_delay = delay;
		console_print(id, "Teleportation delay is now enabled and is set to %d seconds.", delay)
	}
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpempty
*
*       syntax:
*       amx_tpempty                  empty positions list
*
******************************************************************************************/
public amx_tpempty(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	for (new i=0; i<NUMSLOTS; i++) {
		formatex(g_slot_name[i], MAX_TEXT_LENGTH, "pos%i", i+1);
		g_slot[i][0] = g_slot[i][1] = g_slot[i][2] = -1
	}
	console_print(id, "The list is now empty.");
	return PLUGIN_HANDLED
}

/*****************************************************************************************
*
*	amx_tpadd
*
*       syntax:
*       amx_tpadd #user              add #user position to list
*       amx_tpadd                    add commanduser position to list
*
******************************************************************************************/
public amx_tpadd(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new arg1[MAX_NAME_LENGTH], user
	
	read_argv(1,arg1,MAX_NAME_LENGTH-1)
	
	if (!arg1[0]) { // no user --> commanduser
		user = id
	} else {
		user = cmd_target(id, arg1, 2)
		if (!user) {
			console_print(id, "Unknown player: %s!", arg1)
			return PLUGIN_HANDLED
		}
	}
	
	new userName[MAX_NAME_LENGTH]
	new origin[3], i
	new Float:angles[3], iangles[3]
	
	get_user_name(user, userName, MAX_NAME_LENGTH-1)
	get_user_origin(user, origin)
	pev(user, pev_angles, angles)
	FVecIVec(angles, iangles)
	for (i=0; i<NUMSLOTS; i++) {
		if (g_slot[i][0]==-1 && g_slot[i][1]==-1 && g_slot[i][2]==-1) {
			g_slot[i][0] = origin[0]
			g_slot[i][1] = origin[1]
			g_slot[i][2] = origin[2]
			g_slot_angle[i][0] = iangles[0]
			g_slot_angle[i][1] = iangles[1]
			g_slot_angle[i][2] = iangles[2]
			console_print(id, "Success : player %s's position added in slot #%d.", userName, i+1)
			return PLUGIN_HANDLED;
		}
	}
	console_print(id, "No more slot available!")
	return PLUGIN_HANDLED
}

/*****************************************************************************************
*
*	amx_tpmem
*
*       syntax:
*       amx_tpmem #user #slot        memorize #user position in #slot
*
******************************************************************************************/
public amx_tpmem(id, level, cid) {
	if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED
	
	new arg1[MAX_NAME_LENGTH], arg2[5], user, slot
	
	read_argv(1, arg1, MAX_NAME_LENGTH-1)
	read_argv(2, arg2, 4)
	
	user = cmd_target(id, arg1, 2)
	if (!user) {
		console_print(id, "Unknown player: %s!", arg1)
		return PLUGIN_HANDLED
	}
	slot = str_to_num(arg2)
	if (slot<1 || slot>=NUMSLOTS) {
		console_print(id, "Bad slot number: %d!", slot)
		return PLUGIN_HANDLED
	}
	
	new origin[3], userName[MAX_NAME_LENGTH]
	new Float:angles[3], iangles[3]
	
	get_user_origin(user, origin)
	pev(user, pev_angles, angles)
	FVecIVec(angles, iangles)
	get_user_name(user, userName, MAX_NAME_LENGTH-1)
	g_slot[slot-1][0] = origin[0]
	g_slot[slot-1][1] = origin[1]
	g_slot[slot-1][2] = origin[2]
	g_slot_angle[slot-1][0] = iangles[0]
	g_slot_angle[slot-1][1] = iangles[1]
	g_slot_angle[slot-1][2] = iangles[2]
	console_print(id, "Success: player %s's position set in slot #%d.", userName, slot)
	
	return PLUGIN_HANDLED
}

/*****************************************************************************************
*
*	amx_tplist
*
*       syntax:
*       amx_tplist           display the list
*
******************************************************************************************/
public amx_tplist(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	new i;
	new n = 0;
	
	for (i=0; i<NUMSLOTS; i++) {
		if (!(g_slot[i][0]==-1 && g_slot[i][1]==-1 && g_slot[i][2]==-1)) {
			n++;
			console_print(id, "g_slot %02d: X %d, Y %d, Z %d ; %s", i+1, g_slot[i][0], g_slot[i][1], g_slot[i][2], g_slot_name[i])
		}
	}
	if (n==0) {
		console_print(id, "The list is empty.");
	}
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpload
*
*       syntax:
*       amx_tpload           load the list from defaultfile
*
******************************************************************************************/
public amx_tpload(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	if (read_file_(g_cfgfilepath)) {
		console_print(id, "Success: loading from file %s.", g_cfgfilepath)
	} else {
		console_print(id, "Unknown file %s!", g_cfgfilepath)
	}
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpsave
*
*       syntax:
*       amx_tpsave           save the list in defaultfile
*
******************************************************************************************/
public amx_tpsave(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new txt[MAX_TEXT_LENGTH]
	
	delete_file(g_cfgfilepath)
	for (new i=0; i<NUMSLOTS; i++) {
		formatex(txt, MAX_TEXT_LENGTH-1, "%d %d %d %d %d %d %s",
		g_slot[i][0], g_slot[i][1], g_slot[i][2],
		g_slot_angle[i][0], g_slot_angle[i][1], g_slot_angle[i][2],
		g_slot_name[i])
		if (write_file(g_cfgfilepath, txt, -1)==0) {
			console_print(id, "Error writing file %s!", g_cfgfilepath)
			return PLUGIN_HANDLED;
		}
	}
	console_print(id, "Success: saved to file %s.", g_cfgfilepath);
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpname
*
*       syntax:
*       amx_tpname <#slot> <name>    name the slot number #slot
*       amx_tpname <#slot>           unname the slot #slot (back to name 'posxx' where xx is the slot number)
*
******************************************************************************************/
public amx_tpname(id, level, cid) {
	if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
	
	new arg1[5], arg2[MAX_TEXT_LENGTH], slot
	
	read_argv(1, arg1, 4)
	read_argv(2, arg2, MAX_NAME_LENGTH-1)
	
	slot = str_to_num(arg1)
	if (slot<1 || slot>=NUMSLOTS) {
		console_print(id, "Bad slot number: %d!", slot)
		return PLUGIN_HANDLED
	}
	
	if (!arg2[0]) { // no name given, unname it
		formatex(g_slot_name[slot-1], MAX_TEXT_LENGTH, "pos%d", slot)
	} else {
		formatex(g_slot_name[slot-1], MAX_TEXT_LENGTH, arg2)
	}
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpcopy
*
*       syntax:
*       amx_tpcopy #user1 #user2             copy personnal position of #user1 (saved by 'saveme') to #user2
*
******************************************************************************************/
public amx_tpcopy(id, level, cid) {
	if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED
	
	new user1, user2
	new strUser1[MAX_NAME_LENGTH], strUser2[MAX_NAME_LENGTH]
	
	read_argv(1, strUser1, MAX_NAME_LENGTH-1)
	read_argv(2, strUser2, MAX_NAME_LENGTH-1)
	
	user1 = cmd_target(id, strUser1, 2)
	user2 = cmd_target(id, strUser2, 2)
	if (!user1) {
		console_print(id, "Unknown player: %s!", strUser1)
		return PLUGIN_HANDLED
	}
	if (!user2) {
		console_print(id, "Unknown player: %s!", strUser2)
		return PLUGIN_HANDLED
	}
	
	get_user_name(user1, strUser1, MAX_NAME_LENGTH-1)
	get_user_name(user2, strUser1, MAX_NAME_LENGTH-1)
	
	if (g_user[0][user1][0]==-1 && g_user[0][user1][1]==-1 && g_user[0][user1][2]==-1) {
		console_print(id, "Failed : position of user %s is not set yet!", strUser1)
	} else {
		g_user[0][user2][0] = g_user[0][user1][0]
		g_user[0][user2][1] = g_user[0][user1][1]
		g_user[0][user2][2] = g_user[0][user1][2]
		g_user_angle[0][user2][0] = g_user_angle[0][user1][0]
		g_user_angle[0][user2][1] = g_user_angle[0][user1][1]
		g_user_angle[0][user2][2] = g_user_angle[0][user1][2]
		console_print(id, "Succeeded : copied user %s's position to user %s.", strUser1, strUser2);
	}
	
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpstack
*
*	syntax:
*	amx_tpstack		stack all players on your head
*	amx_tpstack <user>	stack only <user> on your head
*
******************************************************************************************/
public amx_tpstack(id, level, cid) {
	if (!cmd_access(id,level,cid,1)) return PLUGIN_HANDLED
	
	new origin[3]
	new Float:angles[3]
	new  idName[32]
	new Players[32]
	
	get_user_name(id, idName, 31)
	get_user_origin(id, origin, 0)
	pev(id, pev_angles, angles)
	
	if (read_argc() <= 1) { // no user, stack all
		new player, playercount, i
		
		get_players(Players, playercount)
		
		for (i=0; i<playercount; i++) {
			player = Players[i]
#if defined USE_SPEEDRUN
			formatex(g_vault_str, 9, "timer_%d", player)
			if (player != id) { // DONT teleport command user himself!!
				if (!get_vaultdata(g_vault_str)) {
					set_pev(player, pev_velocity, { 0.0, 0.0, 0.0 })
					origin[2] += 96
					set_user_origin(player, origin)
					set_pev(player, pev_angles, angles)
					set_pev(player, pev_fixangle, 1)
				}
			}
#else
			if (player != id) { // DONT teleport command user himself!!
				set_pev(player, pev_velocity, { 0.0, 0.0, 0.0 })
				origin[2] += 96
				set_user_origin(player, origin)
				set_pev(player, pev_angles, angles)
				set_pev(player, pev_fixangle, 1)
			}
#endif
		}
		
		switch(get_cvar_num("amx_show_activity")) {
			case 1: client_print(0, print_chat, "ADMIN: Everybody has been teleported.")
			case 2: client_print(0, print_chat, "ADMIN (%s): Everybody has been teleported.", idName)
		}
		
	} else { // stack only user
		new arg1[32]
		
		read_argv(1, arg1, 31)
		
		new player = cmd_target(id, arg1, 4)
		
		if (player==0) {
			client_print(id, print_chat, "Unknown player: %s", arg1)
			return PLUGIN_HANDLED
		}
		
		new plName[32]
		get_user_name(player,plName,31)
		
#if defined USE_SPEEDRUN
		formatex(g_vault_str, 9, "timer_%d", player)
		if (!get_vaultdata(g_vault_str)) {
			set_pev(player, pev_velocity, { 0.0, 0.0, 0.0 })
			origin[2] += 96
			set_user_origin(player, origin)
			set_pev(player, pev_angles, angles)
			set_pev(player, pev_fixangle, 1)
			
			msg_show_activity(id, plName)
		} else {
			console_print(id, "%s is in speedrun mode and cant be teleported!", plName)
		}
#else
		set_pev(player, pev_velocity, { 0.0, 0.0, 0.0 })
		origin[2] += 96
		set_user_origin(player, origin)
		set_pev(player, pev_angles, angles)
		set_pev(player, pev_fixangle, 1)
			
		msg_show_activity(id, plName)
#endif
		
	}
	
	return PLUGIN_HANDLED
}

/*****************************************************************************************
*
*	amx_tp
*
*       syntax:
*       amx_tp #user #slot   teleport #user at position from #slot
*       amx_tp #user slotname teleport #user at position named slotname
*       amx_tp #user         teleport #user at position from last slot
*       amx_tp                       teleport commanduser at position from last slot
*
******************************************************************************************/
public amx_tp(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	
	new arg1[MAX_NAME_LENGTH], arg2[MAX_TEXT_LENGTH]
	new slotnum = 0, user
	
	read_argv(1, arg1, MAX_NAME_LENGTH-1)
	read_argv(2, arg2, MAX_TEXT_LENGTH-1)
	
	if (!arg1[0]) {
		user = id
	} else {
		user = cmd_target(id, arg1, 2)
		if (!user) {
			console_print(id, "Unkown player: %s!", arg1)
			return PLUGIN_HANDLED
		}
	}
	
	if (!arg2[0]) {
		new found
		for (new i=NUMSLOTS-1; i>=0; i--) {
			if (g_slot[i][0]!=-1 || g_slot[i][1]!=-1 || g_slot[i][2]!=-1) {
				found =1
				slotnum = i
				break
			}
		}
		if (!found) {
			console_print(id, "No slot left!")
			return PLUGIN_HANDLED
		}
	} else {
		slotnum = str_to_num(arg2)
		if (!slotnum) { // maybe a slot name
			for (new i=0; i<NUMSLOTS; i++) {
				if (containi(g_slot_name[i], arg2)!=-1) {
					slotnum = i+1
					break
				}
			}
		}
		if (!slotnum) {
			console_print(id, "Bad slot number or unknown slot: %s!", arg2)
			return PLUGIN_HANDLED
		}
		if (g_slot[slotnum-1][0]==-1 && g_slot[slotnum-1][1]==-1 && g_slot[slotnum-1][2]==-1) {
			console_print(id, "Unitialized slot: %d!", slotnum)
			return PLUGIN_HANDLED
		}
	}
	
	new userName[MAX_NAME_LENGTH]
	get_user_name(user, userName, MAX_NAME_LENGTH-1)
	
	if (!access(id, ACCESS_ADMIN) && access(user, ADMIN_IMMUNITY)) {
		console_print(id, "%s is immune, you cannot do that!", userName)
		return PLUGIN_HANDLED
	}
	
#if defined USE_SPEEDRUN
	formatex(g_vault_str, 9, "timer_%d", user)
	if (!get_vaultdata(g_vault_str)) {
		new Float:angles[3]
		
		IVecFVec(g_slot_angle[slotnum-1], angles)
		set_pev(user, pev_velocity, { 0.0, 0.0, 0.0 })
		set_user_origin(user, g_slot[slotnum-1])
		set_pev(user, pev_angles, angles)
		set_pev(user, pev_fixangle, 1)
		
		console_print(id, "Success: player %s was sent to slot %d.", userName, slotnum)
		msg_show_activity(id, userName)
	} else {
		console_print(id, "%s is in speedrun mode and cant be teleported!", userName)
	}
#else
	new Float:angles[3]
		
	IVecFVec(g_slot_angle[slotnum-1], angles)
	set_pev(user, pev_velocity, { 0.0, 0.0, 0.0 })
	set_user_origin(user, g_slot[slotnum-1])
	set_pev(user, pev_angles, angles)
	set_pev(user, pev_fixangle, 1)
		
	console_print(id, "Success: player %s was sent to slot %d.", userName, slotnum)
	msg_show_activity(id, userName)
#endif	
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpgo
*
*       syntax:
*       amx_tpgo #user x y z  : teleport user to coordinates
*
******************************************************************************************/
public amx_tpgo(id, level, cid) {
	if (!cmd_access(id, level, cid, 5)) return PLUGIN_HANDLED
	
	new userStr[MAX_NAME_LENGTH], xStr[8], yStr[8], zStr[8]
	new x, y, z, user
	
	read_argv(1, userStr, MAX_NAME_LENGTH-1)
	read_argv(2, xStr, 7)
	read_argv(3, yStr, 7)
	read_argv(4, zStr, 7)
	
	user = cmd_target(id, userStr, 2)
	if (!user) {
		console_print(id, "Unkown player: %s!", userStr)
		return PLUGIN_HANDLED
	}
	
	x = str_to_num(xStr)
	y = str_to_num(yStr)
	z = str_to_num(zStr)
	
	new userName[MAX_NAME_LENGTH]
	get_user_name(user, userName, MAX_NAME_LENGTH-1)
	
	if (!access(id, ACCESS_ADMIN) && access(user, ADMIN_IMMUNITY)) {
		console_print(id, "%s is immune, you cannot do that!", userName)
		return PLUGIN_HANDLED
	}
	
#if defined USE_SPEEDRUN
	formatex(g_vault_str, 9, "timer_%d", user)
	if (!get_vaultdata(g_vault_str)) {
		new origin[3]
		origin[0] = x
		origin[1] = y
		origin[2] = z
		set_pev(user, pev_velocity, { 0.0, 0.0, 0.0 })
		set_user_origin(user, origin)
		
		console_print(id, "Success: player %s was sent to (%d %d %d).", userName, x, y, z)
		msg_show_activity(id, userName)
	} else {
		console_print(id, "%s is in speedrun mode and cant be teleported!", userName)
	}
#else
	new origin[3]
	origin[0] = x
	origin[1] = y
	origin[2] = z
	set_pev(user, pev_velocity, { 0.0, 0.0, 0.0 })
	set_user_origin(user, origin)
		
	console_print(id, "Success: player %s was sent to (%d %d %d).", userName, x, y, z)
	msg_show_activity(id, userName)
#endif	
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpsend
*
*       syntax:
*       amx_tpsend #user1 #user2                     send #user1 to #user2 current position (stack on #user2)
*
******************************************************************************************/
public amx_tpsend(id, level, cid) {
	if (!cmd_access(id, level, cid, 3)) return PLUGIN_HANDLED
	
	new user1, user2
	new strUser1[MAX_NAME_LENGTH], strUser2[MAX_NAME_LENGTH]
	
	read_argv(1, strUser1, MAX_NAME_LENGTH-1)
	read_argv(2, strUser2, MAX_NAME_LENGTH-1)
	
	user1 = cmd_target(id, strUser1, 2)
	user2 = cmd_target(id, strUser2, 2)
	if (!user1) {
		console_print(id, "Unknown player: %s!", strUser1)
		return PLUGIN_HANDLED
	}
	if (!user2) {
		console_print(id, "Unknown player: %s!", strUser2)
		return PLUGIN_HANDLED
	}
	
	get_user_name(user1, strUser1, MAX_NAME_LENGTH-1)
	get_user_name(user2, strUser1, MAX_NAME_LENGTH-1)
	
	if (!access(id, ACCESS_ADMIN) && access(user1, ADMIN_IMMUNITY)) {
		console_print(id, "%s is immune, you cannot do that!", strUser1)
		return PLUGIN_HANDLED
	}
	
#if defined USE_SPEEDRUN
	formatex(g_vault_str, 9, "timer_%d", user1)
	if (!get_vaultdata(g_vault_str)) {
		new origin[3]
		new Float:angles[3]
		
		get_user_origin(user2, origin)
		origin[2] += 96
		pev(user2, pev_angles, angles)
		set_pev(user1, pev_velocity, { 0.0, 0.0, 0.0 })
		set_user_origin(user1, origin)
		set_pev(user1, pev_angles, angles)
		set_pev(user1, pev_fixangle, 1)
		
		console_print(id, "Success : %s was sent to %s.", strUser1, strUser2)
		msg_show_activity(id, strUser1)
	} else {
		console_print(id, "%s is in speedrun mode and cant be teleported!", strUser1)
	}
#else
	new origin[3]
	new Float:angles[3]
		
	get_user_origin(user2, origin)
	origin[2] += 96
	pev(user2, pev_angles, angles)
	set_pev(user1, pev_velocity, { 0.0, 0.0, 0.0 })
	set_user_origin(user1, origin)
	set_pev(user1, pev_angles, angles)
	set_pev(user1, pev_fixangle, 1)
		
	console_print(id, "Success : %s was sent to %s.", strUser1, strUser2)
	msg_show_activity(id, strUser1)
#endif
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpaim
*
*       syntax:
*       amx_tpaim #user                     send #user where im looking.
*
******************************************************************************************/
public amx_tpaim(id, level, cid) {
	if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED
	
	new user
	new strUser[MAX_NAME_LENGTH]
	
	read_argv(1, strUser, MAX_NAME_LENGTH-1)
	
	user = cmd_target(id, strUser, 2)
	if (!user) {
		console_print(id, "Unknown player: %s!", strUser)
		return PLUGIN_HANDLED
	}
	
	get_user_name(user, strUser, MAX_NAME_LENGTH-1)
	
	if (!access(id, ACCESS_ADMIN) && access(user, ADMIN_IMMUNITY)) {
		console_print(id, "%s is immune, you cannot do that!", strUser)
		return PLUGIN_HANDLED
	}
	
#if defined USE_SPEEDRUN
	formatex(g_vault_str, 9, "timer_%d", user)
	if (!get_vaultdata(g_vault_str)) {
		new origin[3]
		new Float:angles[3]
		
		get_user_origin(id, origin, 3)
		origin[2] += 38
		pev(id, pev_angles, angles)
		angles[1] += 180.0
		set_pev(user, pev_velocity, { 0.0, 0.0, 0.0 })
		set_user_origin(user, origin)
		set_pev(user, pev_angles, angles)
		set_pev(user, pev_fixangle, 1)
		
		console_print(id, "Success : %s was teleported.", strUser)
		msg_show_activity(id, strUser)
	} else {
		console_print(id, "%s is in speedrun mode and cant be teleported!", strUser)
	}
#else
	new origin[3]
	new Float:angles[3]
		
	get_user_origin(id, origin, 3)
	origin[2] += 38
	pev(id, pev_angles, angles)
	angles[1] += 180.0
	set_pev(user, pev_velocity, { 0.0, 0.0, 0.0 })
	set_user_origin(user, origin)
	set_pev(user, pev_angles, angles)
	set_pev(user, pev_fixangle, 1)
		
	console_print(id, "Success : %s was teleported.", strUser)
	msg_show_activity(id, strUser)
#endif	
	return PLUGIN_HANDLED;
}

/*****************************************************************************************
*
*	amx_tpinfo
*
*	syntax:
*	amx_tpinfo	display coords to user.
*
******************************************************************************************/
public amx_tpinfo(id, level, cid) {
	if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED
	new origin[3]
	
	get_user_origin(id, origin)
	console_print(id, "Your position is: X = %d, Y = %d, Z = %d.", origin[0], origin[1], origin[2])
	return PLUGIN_HANDLED
}

public cmdPosme(id, level, cid) {
	if (!PlayerAllowedToPos(id)) return PLUGIN_HANDLED
	
#if defined USE_SPEEDRUN
	formatex(g_vault_str, 9, "timer_%d", id)
	if (!get_vaultdata(g_vault_str)) {
		if (g_user[0][id][0]!=-1 || g_user[0][id][1]!=-1 || g_user[0][id][2]!=-1) {
			new Float:angles[3]
			IVecFVec(g_user_angle[0][id], angles)
			set_pev(id, pev_velocity, { 0.0, 0.0, 0.0 })
			set_user_origin(id, g_user[0][id])
			set_pev(id, pev_angles, angles)
			set_pev(id, pev_fixangle, 1)
			do_effect(g_user[0][id])
			do_sound(id, 0)
			client_print(id, print_chat, "Teleporting succeeded.")
			g_stats[id][1]++
		} else {
			client_print(id, print_chat, "Your position was not saved before.")
		}
	} else {
		client_print(id, print_chat, "You are not allowed to teleport in speedrun mode!")
	}
#else
	if (g_user[0][id][0]!=-1 || g_user[0][id][1]!=-1 || g_user[0][id][2]!=-1) {
		new Float:angles[3]
		IVecFVec(g_user_angle[0][id], angles)
		set_pev(id, pev_velocity, { 0.0, 0.0, 0.0 })
		set_user_origin(id, g_user[0][id])
		set_pev(id, pev_angles, angles)
		set_pev(id, pev_fixangle, 1)
		do_effect(g_user[0][id])
		do_sound(id, 0)
		client_print(id, print_chat, "Teleporting succeeded.")
		g_stats[id][1]++
	} else {
		client_print(id, print_chat, "Your position was not saved before.")
	}
#endif
	return PLUGIN_HANDLED
}

public cmdPosme2(id, level, cid) {
	if (!PlayerAllowedToPos(id)) return PLUGIN_HANDLED
	
#if defined USE_SPEEDRUN
	formatex(g_vault_str, 9, "timer_%d", id)
	if (!get_vaultdata(g_vault_str)) {
		if (g_user[1][id][0]!=-1 || g_user[1][id][1]!=-1 || g_user[1][id][2]!=-1) {
			new Float:angles[3]
			IVecFVec(g_user_angle[1][id], angles)
			set_pev(id, pev_velocity, { 0.0, 0.0, 0.0 })
			set_user_origin(id, g_user[1][id])
			set_pev(id, pev_angles, angles)
			set_pev(id, pev_fixangle, 1)
			do_effect(g_user[1][id])
			do_sound(id, 0)
			client_print(id, print_chat, "Teleporting succeeded.")
			g_stats[id][1]++
		} else {
			client_print(id, print_chat, "Your position was not saved before.")
		}
	} else {
		client_print(id, print_chat, "You are not allowed to teleport in speedrun mode!")
	}
#else
	if (g_user[1][id][0]!=-1 || g_user[1][id][1]!=-1 || g_user[1][id][2]!=-1) {
		new Float:angles[3]
		IVecFVec(g_user_angle[1][id], angles)
		set_pev(id, pev_velocity, { 0.0, 0.0, 0.0 })
		set_user_origin(id, g_user[1][id])
		set_pev(id, pev_angles, angles)
		set_pev(id, pev_fixangle, 1)
		do_effect(g_user[1][id])
		do_sound(id, 0)
		client_print(id, print_chat, "Teleporting succeeded.")
		g_stats[id][1]++
	} else {
		client_print(id, print_chat, "Your position was not saved before.")
	}
#endif
	return PLUGIN_HANDLED
}

public cmdSaveme(id, level, cid) {
	if (!PlayerAllowedToSave(id)) return PLUGIN_HANDLED
	
	new Float:angles[3]
	
	get_user_origin(id, g_user[0][id])
	pev(id, pev_v_angle, angles)
	FVecIVec(angles, g_user_angle[0][id])
	do_sound(id, 1)
	client_print(id, print_chat, "Your position has been saved.")
	g_stats[id][0]++
	
	return PLUGIN_HANDLED
}

public cmdSaveme2(id, level, cid) {
	if (!PlayerAllowedToSave(id)) return PLUGIN_HANDLED
	
	new Float:angles[3]
	
	get_user_origin(id, g_user[1][id])
	pev(id, pev_v_angle, angles)
	FVecIVec(angles, g_user_angle[1][id])
	do_sound(id, 1)
	client_print(id, print_chat, "Your position has been saved.")
	g_stats[id][0]++
	
	return PLUGIN_HANDLED
}

public cmdStats(id, level, cid) {
	if (!get_pcvar_num(g_cvteleport)) {
		client_print(id, print_chat, "Teleporting not allowed now.")
		return PLUGIN_HANDLED
	}
	
	new out[256]
	new Players[32], playercount, player_name[33]
	
	formatex(out, 255, "Your current stats:  %d saves , %d loads.", g_stats[id][0], g_stats[id][1])
	client_print(id, print_chat, out)
	
	get_user_name(id, player_name, 32)
	formatex(out, 255, "Current %s stats: %d saves, %d loads.", player_name, g_stats[id][0], g_stats[id][1])
	get_players(Players, playercount)
	for (new i=0; i<playercount; i++) {
		if (Players[i]!=id) client_print(Players[i], print_chat, out)
	}
	return PLUGIN_HANDLED
}

public cmdVersion(id, level, cid) {
	new msg[256]
	
	formatex(msg, 255, "%s by Bahrmanou^nVersion %s^n(C)2006, Bahrmanou(amiga5707@hotmail.com)", PLUGNAME, VERSION)
	
	set_hudmessage(20, 20, 180, -1.0, 0.05)
	show_hudmessage(id, msg)
	return PLUGIN_HANDLED
}

PlayerAllowedToSave(UserIndex) {
	if (!get_pcvar_num(g_cvteleport) && !access(UserIndex, ADMIN_IMMUNITY)) {
		client_print(UserIndex, print_chat, "Teleporting currently not allowed.")
		return 0;
	}
	if (!g_player_allowed[UserIndex] && !access(UserIndex, ADMIN_IMMUNITY)) {
		client_print(UserIndex, print_chat, "You are not allowed to teleport.")
		return 0;
	}
	if (get_user_noclip(UserIndex)) {
		client_print(UserIndex, print_chat, "You cannot save while in noclip mode!")
		return 0
	}
	// only players with access ACCESS_TELEPORT can save position while spectator/dead.
	if (!is_user_alive(UserIndex) || !get_user_team(UserIndex)) {
		if (!access(UserIndex, ACCESS_TELEPORT)) {
			client_print(UserIndex, print_chat, "You cannot save while being spectator or dead, sorry!")
			return 0;
		}
	}
	return 1;
}

PlayerAllowedToPos(UserIndex) {
	if (!get_pcvar_num(g_cvteleport) && !access(UserIndex, ADMIN_IMMUNITY)) {
		client_print(UserIndex, print_chat, "Teleporting currently not allowed.")
		return 0;
	}
	if (!g_player_allowed[UserIndex] && !access(UserIndex, ADMIN_IMMUNITY)) {
		client_print(UserIndex, print_chat, "You are not allowed to teleport.")
		return 0;
	}
	
	if (g_pos_delay_status == 0)
		return 1;
	
	if (!access(UserIndex, ACCESS_TELEPORT)) {
		new CurTime;
		new SecsAgo;
		
		CurTime = get_systime()
		
		if (!g_last_time[UserIndex]) {
			g_last_time[UserIndex] = CurTime;
			return 1;
		}
		
		SecsAgo = CurTime - g_last_time[UserIndex]
		
		if (SecsAgo < g_pos_delay) {
			client_print(UserIndex, print_chat, "You are not allowed to teleport yet: %d seconds remaining...", g_pos_delay-SecsAgo)
			return 0;
		} else {
			g_last_time[UserIndex] = CurTime
		}
	}
	return 1;
}

read_file_(filename[]) {
	new buffer[MAX_TEXT_LENGTH]
	new pos[3][MAX_NUMBER_LENGTH]
	new angle[3][MAX_NUMBER_LENGTH]
	
	if (file_exists(filename)) {
		new len
		for (new i=0; i<NUMSLOTS; i++) {
			if (read_file(filename, i, buffer, MAX_TEXT_LENGTH-1, len)) {
				parse(buffer, 
				pos[0], MAX_NUMBER_LENGTH-1, 
				pos[1], MAX_NUMBER_LENGTH-1, 
				pos[2], MAX_NUMBER_LENGTH-1, 
				angle[0], MAX_NUMBER_LENGTH-1,
				angle[1], MAX_NUMBER_LENGTH-1,
				angle[2], MAX_NUMBER_LENGTH-1,
				g_slot_name[i], MAX_TEXT_LENGTH-1)
				g_slot[i][0] = str_to_num(pos[0])
				g_slot[i][1] = str_to_num(pos[1])
				g_slot[i][2] = str_to_num(pos[2])
				g_slot_angle[i][0] = str_to_num(angle[0])
				g_slot_angle[i][1] = str_to_num(angle[1])
				g_slot_angle[i][2] = str_to_num(angle[2])
			}
		}
		return 1
	}
	return 0
}

do_effect(origin[]) {
	new effectnum = get_pcvar_num(g_cvteleport_effect)
	if  (effectnum<1 || effectnum>NUM_EFFECTS) effectnum = random_num(1,NUM_EFFECTS)
	switch (effectnum) {
		case 1: {
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_TELEPORT)
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2])
			message_end()
		}
		case 2: {
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_SPARKS)
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2]+50)
			message_end()
		}
		case 3: {
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_LAVASPLASH)
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2])
			message_end()
		}
		case 4: {
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_EXPLOSION2)
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2])
			write_byte(1)	// starting color
			write_byte(16)	// num colors
			message_end()
		}
		case 5: {
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_IMPLOSION)
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2])
			write_byte(60)	// radius
			write_byte(35)	// count
			write_byte(15)	// life
			message_end()
		}
		case 6: {
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_DLIGHT)
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2])
			write_byte(40)	// radius
			write_byte(random(256))	// color red
			write_byte(random(256))	// color green
			write_byte(random(256))	// color blue
			write_byte(15)	// life
			write_byte(20)	// decay rate
			message_end()
		}
		default: {
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_TELEPORT)
			write_coord(origin[0])
			write_coord(origin[1])
			write_coord(origin[2])
			message_end()
		}
	}
}

do_sound(id, n) {
	client_cmd(id, "speak %s", g_tp_sounds[n])
}

msg_show_activity(id, name[]) {
	switch(get_cvar_num("amx_show_activity")) {
		case 1: client_print(0, print_chat, "ADMIN: %s has been teleported.", name)
		case 2: {
			new idName[MAX_NAME_LENGTH]
			get_user_name(id, idName, MAX_NAME_LENGTH-1)
			client_print(0, print_chat, "ADMIN (%s): %s has been teleported.", idName, name)
		}
	}
}

/******************************************************************************
 *
 *	Auto unstucking.
 *
 *	From the great NL)Ramon(NL plugin
 *
 ******************************************************************************/
public check_stuck_player(i) {
	static stuck[33]
	static Float:origin[3]
	static Float:mins[3]
	static hull
	static const Float:size[][3] = {
		{0.0, 0.0, 1.0}, {0.0, 0.0, -1.0}, {0.0, 1.0, 0.0}, {0.0, -1.0, 0.0}, {1.0, 0.0, 0.0}, {-1.0, 0.0, 0.0}, {-1.0, 1.0, 1.0}, {1.0, 1.0, 1.0}, {1.0, -1.0, 1.0}, {1.0, 1.0, -1.0}, {-1.0, -1.0, 1.0}, {1.0, -1.0, -1.0}, {-1.0, 1.0, -1.0}, {-1.0, -1.0, -1.0},
		{0.0, 0.0, 2.0}, {0.0, 0.0, -2.0}, {0.0, 2.0, 0.0}, {0.0, -2.0, 0.0}, {2.0, 0.0, 0.0}, {-2.0, 0.0, 0.0}, {-2.0, 2.0, 2.0}, {2.0, 2.0, 2.0}, {2.0, -2.0, 2.0}, {2.0, 2.0, -2.0}, {-2.0, -2.0, 2.0}, {2.0, -2.0, -2.0}, {-2.0, 2.0, -2.0}, {-2.0, -2.0, -2.0},
		{0.0, 0.0, 3.0}, {0.0, 0.0, -3.0}, {0.0, 3.0, 0.0}, {0.0, -3.0, 0.0}, {3.0, 0.0, 0.0}, {-3.0, 0.0, 0.0}, {-3.0, 3.0, 3.0}, {3.0, 3.0, 3.0}, {3.0, -3.0, 3.0}, {3.0, 3.0, -3.0}, {-3.0, -3.0, 3.0}, {3.0, -3.0, -3.0}, {-3.0, 3.0, -3.0}, {-3.0, -3.0, -3.0},
		{0.0, 0.0, 4.0}, {0.0, 0.0, -4.0}, {0.0, 4.0, 0.0}, {0.0, -4.0, 0.0}, {4.0, 0.0, 0.0}, {-4.0, 0.0, 0.0}, {-4.0, 4.0, 4.0}, {4.0, 4.0, 4.0}, {4.0, -4.0, 4.0}, {4.0, 4.0, -4.0}, {-4.0, -4.0, 4.0}, {4.0, -4.0, -4.0}, {-4.0, 4.0, -4.0}, {-4.0, -4.0, -4.0},
		{0.0, 0.0, 5.0}, {0.0, 0.0, -5.0}, {0.0, 5.0, 0.0}, {0.0, -5.0, 0.0}, {5.0, 0.0, 0.0}, {-5.0, 0.0, 0.0}, {-5.0, 5.0, 5.0}, {5.0, 5.0, 5.0}, {5.0, -5.0, 5.0}, {5.0, 5.0, -5.0}, {-5.0, -5.0, 5.0}, {5.0, -5.0, -5.0}, {-5.0, 5.0, -5.0}, {-5.0, -5.0, -5.0}
	}
	
	if (is_user_connected(i) && is_user_alive(i)) {
		pev(i, pev_origin, origin)
		hull = pev(i, pev_flags) & FL_DUCKING ? HULL_HEAD : HULL_HUMAN
		if (!is_hull_vacant(origin, hull, i) && !get_user_noclip(i) && !(pev(i, pev_solid) & SOLID_NOT)) {
			++stuck[i]
			if(stuck[i] >= 5) {
				pev(i, pev_mins, mins)
				new Float:vec[3]
				vec[2] = origin[2]
				for (new ofs; ofs < sizeof size; ++ofs) {
					vec[0] = origin[0] - mins[0] * size[ofs][0]
					vec[1] = origin[1] - mins[1] * size[ofs][1]
					vec[2] = origin[2] - mins[2] * size[ofs][2]
					if (is_hull_vacant(vec, hull,i)) {
						engfunc(EngFunc_SetOrigin, i, vec)
						unstuck_effects(i)
						ofs = sizeof size
					}
				}
			}
		} else {
			stuck[i] = 0
		}
	}
}

public checkstuck() {
	if(get_pcvar_num(g_cvunstuck) >= 1) {
		new maxp = get_maxplayers()
		for (new i=0; i<=maxp; i++) {
			check_stuck_player(i)
		}
		set_task(0.1,"checkstuck")
	} else {
		set_task(0.5,"checkstuck")
	}
}

stock bool:is_hull_vacant(const Float:origin[3], hull,id) {
	new tr = 0
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, id, tr)
	if (!get_tr2(tr, TraceResult:TR_StartSolid) || !get_tr2(tr, TraceResult:TR_AllSolid)) //get_tr2(tr, TR_InOpen))
		return true
	
	return false
}

public unstuck_effects(id) {
	if(get_pcvar_num(g_cvunstuck_effect)) {
		set_hudmessage(255,150,50, -1.0, 0.65, 0, 6.0, 1.5,0.1,0.7) // HUDMESSAGE
		show_hudmessage(id,"You should be unstucked now!.") // HUDMESSAGE
		message_begin(MSG_ONE_UNRELIABLE,105,{0,0,0},id )      
		write_short(1<<10)   // fade lasts this long duration
		write_short(1<<10)   // fade lasts this long hold time
		write_short(1<<1)   // fade type (in / out)
		write_byte(20)            // fade red
		write_byte(255)    // fade green
		write_byte(255)        // fade blue
		write_byte(255)    // fade alpha
		message_end()
		client_cmd(id,"spk fvox/blip.wav")
		set_pev(id,pev_velocity,{0.0,0.0,0.0}) // stand still
	}
}
