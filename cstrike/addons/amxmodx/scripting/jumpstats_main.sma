#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <colorchat>
#include <hamsandwich>
#include <jumpstats_const>
#include <jumpstats_stocks>
#include <engine>
#include <fvault>

new const g_team_names[][] =
{
	"Terrorist",
	"Counter-Terrorist",
	"Spectator"
};

// Bugsy pointed out the <<= option
// I knew about this ability, but never thought about using it for bit shifting enums
enum (<<= 1)
{
	ONOFF_SPEED = 1,	// 		1
	ONOFF_COLORCHAT,	// 1 << 1 =	2
	ONOFF_SOUNDS,		// 2 << 1 =	4
	ONOFF_JUMPSTATS,	// 4 << 1 =	8
	ONOFF_STRAFESTATS,	// 8 << 1 =	16
	ONOFF_BEAM,		// 16 << 1 =	32
	ONOFF_SPECSTATS,	// 32 << 1 =	64
	ONOFF_PRESTRAFE,	// 64 << 1 =	128
	ONOFF_DIRHUD,
	ONOFF_BLOCKDIST,
	ONOFF_EDGEDIST
};

new const g_onoff_names[][] =
{
	"Speedometer",
	"Jump Chat Messages",
	"Jump Sounds",
	"Jump Stats",
	"Strafe Stats",
	"Jump Beam",
	"Spectator Stats",
	"PreStrafe Shower",
	"Direction in HUD",
	"Block Distance",
	"Edge Distances"
};

new const g_onoff_verbs[sizeof(g_onoff_names)][] =
{
	"has",
	"have",
	"have",
	"have",
	"have",
	"has",
	"have",
	"has",
	"has",
	"has",
	"have"
};

new const g_onoff_commands[sizeof(g_onoff_names)][] =
{
	"/speed",
	"/colorchat",
	"/ljsounds",
	"/ljstats",
	"/strafestats",
	"/ljbeam",
	"/specstats",
	"/preshow",
	"/dirhud",
	"/blockdist",
	"/edgedist"
};

new Trie:g_onoff_trie;

new const g_cvar_names[][] =
{
	"edgefriction",
	"sv_cheats",
	"sv_maxspeed",
	"sv_stepsize",
	"sv_maxvelocity"
};

new const g_cvar_values[sizeof(g_cvar_names)] =
{
	2, // edgefriction
	0, // sv_cheats
	320, // sv_maxspeed
	18, // sv_stepsize
	2000 // sv_maxvelocity
};

new g_server_frame_enabled;
new g_cvar_pointers[sizeof(g_cvar_names)];

new g_flags[33];

new cvar_allowteam;
new cvar_connectflags;
new cvar_legal_settings;
new cvar_legal_settings_kick;
new cvar_legal_settings_disagree;
new cvar_servertype;
new cvar_savetops;
new cvar_techs_allowed;
new cvar_speed_color;
new cvar_save_settings;
new cvar_save_prune;
new cvar_direction_forwards;

new g_techs_allowed;
new g_speed_color[RGB];

new const g_client_cvar_names[][] =
{
	"developer",
	"fps_max",
	"cl_forwardspeed",
	"cl_sidespeed",
	"cl_backspeed"
};

new Trie:g_client_cvar_index;

new const g_client_cvar_values[sizeof(g_client_cvar_names)] =
{
	0,
	101,
	400,
	400,
	400
};

new Trie:g_valid_weapons;
new g_weapons_allow;
new g_weapons_chat;
new g_weapons_sound;

new g_top_steamid[JUMP_TYPES][MAX_TOP][35];
new g_top_name[JUMP_TYPES][MAX_TOP][32];
new g_top_direction[JUMP_TYPES][MAX_TOP][32];
new Float:g_top_distance[JUMP_TYPES][MAX_TOP];
new Float:g_top_prestrafe[JUMP_TYPES][MAX_TOP];
new Float:g_top_maxspeed[JUMP_TYPES][MAX_TOP];
new g_top_strafes[JUMP_TYPES][MAX_TOP];
new g_top_sync[JUMP_TYPES][MAX_TOP];
new g_total_top[JUMP_TYPES];

new bool:g_best_exists[33][JUMP_TYPES];
new g_best_direction[33][JUMP_TYPES][32];
new Float:g_best_distance[33][JUMP_TYPES];
new Float:g_best_prestrafe[33][JUMP_TYPES];
new Float:g_best_maxspeed[33][JUMP_TYPES];
new g_best_strafes[33][JUMP_TYPES];
new g_best_sync[33][JUMP_TYPES];

new bool:g_connected[33];
new bool:g_alive[33];

new bool:g_agreed[33];

new g_menu_type[33];

new g_max_clients;

new g_cvar_forward;
new g_reset_forward;

new g_cache_entity;

new const g_best_vault[] = "jumpstats_best";
new const g_flags_vault[] = "jumpstats_flags";
new const g_agree_vault[] = "jumpstats_agree";

new g_top_menu;
new g_main_menu;
new g_admin_menu;
new g_reset_main_menu;
new g_reset_tops_menu;
new g_reset_best_menu;
new g_best_main_menu;

new g_menu_page[33];

new g_sound_files[SOUND_TOTAL][128];

public plugin_precache()
{
	new filename[64];
	get_configsdir(filename, sizeof(filename) - 1);
	
	new len = strlen(filename);
	
	add(filename[len], sizeof(filename) - len - 1, "/jumpstats_sounds.ini");
	
	for( new i = 0; i < SOUND_TOTAL; i++ )
	{
		copy(g_sound_files[i], sizeof(g_sound_files[]) - 1, g_default_sound_files[i]);
	}
	
	if( !file_exists(filename) )
	{
		new f = fopen(filename, "wt");
		
		fputs(f, "; This is where you can easily customize the jump sounds for your server^n^n");
		fputs(f, "; To change the sounds, you have to use this format:^n");
		fputs(f, "; ^"key^" ^"file path^"^n^n");
		fputs(f, "; The keys are:^n");
		for( new i = 0; i < SOUND_TOTAL; i++ )
		{
			fprintf(f, "; %s - (%s)^n", g_sound_file_keys[i], g_sound_file_desc[i]);
		}
		fputs(f, "^n; The default sounds are listed below^n^n");
		
		for( new i = 0; i < SOUND_TOTAL; i++ )
		{
			fprintf(f, "^"%s^" ^"%s^"^n", g_sound_file_keys[i], g_sound_files[i]);
		}
		
		fclose(f);
	}
	else
	{
		new Trie:sound_keys_trie = TrieCreate();
		for( new i = 0; i < SOUND_TOTAL; i++ )
		{
			TrieSetCell(sound_keys_trie, g_sound_file_keys[i], i);
		}
		
		new f = fopen(filename, "rt");
		
		new data[256], key[32], sound[128], i;
		while( !feof(f) )
		{
			fgets(f, data, sizeof(data) - 1);
			
			if( !data[0]
			|| data[0] == ';'
			|| data[0] == '/' && data[1] == '/' )
			{
				continue;
			}
			
			parse(data, key, sizeof(key) - 1, sound, sizeof(sound) - 1);
			
			if( TrieGetCell(sound_keys_trie, key, i) )
			{
				copy(g_sound_files[i], sizeof(g_sound_files[]) - 1, sound);
			}
		}
		
		fclose(f);
		
		TrieDestroy(sound_keys_trie);
	}
	
	for( new i = 0; i < SOUND_TOTAL; i++ )
	{
		precache_sound(g_sound_files[i]);
	}
	
	add(filename[len], sizeof(filename) - len - 1, "/jumpstats_reset.ini");
	
	if( !file_exists(filename) )
	{
		new const commands[][] =
		{
			"tele", "tp", "gocheck", "gc",
			"stuck", "unstuck",
			"start", "reset", "spawn", "restart"
		};
		
		new const prefixes[][] =
		{
			"", ".", "/"
		};
		
		new f = fopen(filename, "wt");
		
		fputs(f, "; These commands are not allowed to be used during jumps^n; Place commands in here that allow players to move with the use of other plugins^n^n");
		
		for( new s = 0; s < 2; s++ )
		{
			for( new i = 0; i < sizeof(commands); i++ )
			{
				for( new j = 0; j < sizeof(prefixes); j++ )
				{
					fprintf(f, "%s%s%s^n", (s == 0) ? "" : "say ", prefixes[j], commands[i]);
				}
			}
		}
		
		fputs(f, "+hook^n-hook");
		
		fclose(f);
	}
	
	get_datadir(filename, sizeof(filename) - 1);
	add(filename, sizeof(filename) - 1, "/jumpstats");
	
	if( !dir_exists(filename) )
	{
		mkdir(filename);
	}
}

public plugin_init()
{
	register_plugin("JumpStats Main", PLUGIN_VERSION, PLUGIN_AUTHOR);
	register_cvar(PLUGIN_NAME, PLUGIN_VERSION, (FCVAR_SERVER|FCVAR_SPONLY));
	
	if( !cstrike_running() ) return;
	
	FormatSaveFiles();
	
	register_concmd("js_reset", "CmdReset", ADMIN_RCON, "-- Opens a menu to choose which tops to reset.");
	
	for( new i = 0; i < JUMP_TYPES; i++ )
	{
		register_topcmd(g_jump_prefixes[i], "CmdTop");
	}
	
	g_top_menu = menu_create("Tops Menu", "MenuTopMain");
	g_main_menu = menu_create("JumpStats Menu", "MenuMain");
	g_admin_menu = menu_create("JumpStats Admin Menu", "MenuAdmin");
	g_reset_main_menu = menu_create("Reset Menu", "MenuReset");
	g_reset_tops_menu = menu_create("Reset Tops Menu", "MenuResetTops");
	g_reset_best_menu = menu_create("Reset Best Menu", "MenuResetBest");
	g_best_main_menu = menu_create("Personal Best Menu", "MenuBestMain");
	
	new callback_tops = menu_makecallback("CallbackTopMain");
	new callback_reset_tops = menu_makecallback("CallbackResetTops");
	new callback_reset_best = menu_makecallback("CallbackResetBest");
	
	menu_additem(g_top_menu, "\yMy Tops", "-1", _, callback_tops);
	menu_additem(g_main_menu, "Top Jumps", "1");
	menu_additem(g_main_menu, "Personal Best", "2");
	menu_additem(g_main_menu, "On/Off Menu", "3");
	menu_additem(g_main_menu, "Admin Menu", "4", ADMIN_RCON);
	menu_additem(g_admin_menu, "Reset Menu^n", "1");
	menu_additem(g_admin_menu, "Connect Enabler Menu", "2");
	menu_additem(g_admin_menu, "Allow Team Menu", "3");
	menu_additem(g_admin_menu, "Allow Weapons Menu", "4");
	menu_additem(g_admin_menu, "Allow Techniques Menu", "5");
	menu_additem(g_admin_menu, "\ySave Settings To File", "6");
	menu_additem(g_reset_main_menu, "Reset Tops Menu", "1");
	menu_additem(g_reset_main_menu, "Reset Best Menu", "2");
	menu_additem(g_reset_tops_menu, "\yReset All", "-1", _, callback_reset_tops);
	menu_additem(g_reset_best_menu, "\yReset All", "-1", _, callback_reset_best);
	menu_additem(g_best_main_menu, "View Best Menu", "1");
	menu_additem(g_best_main_menu, "Reset Best Menu", "2");
	
	new num[4];
	for( new i = 0; i < JUMP_TYPES; i++ )
	{
		num_to_str(i, num, sizeof(num) - 1);
		menu_additem(g_top_menu, g_jump_names[i], num, _, callback_tops);
		menu_additem(g_reset_tops_menu, g_jump_names[i], num, _, callback_reset_tops);
		menu_additem(g_reset_best_menu, g_jump_names[i], num, _, callback_reset_best);
	}
	
	g_onoff_trie = TrieCreate();
	
	register_clcmd("say /ljsmenu", "CmdMenu");
	new szCommand[ 32 ];
	for( new i = 0; i < sizeof(g_onoff_commands); i++ )
	{
		formatex( szCommand, 31, "say %s", g_onoff_commands[ i ] );
		register_clcmd(szCommand, "CmdMenu");
		
		formatex( szCommand, 31, "say_team %s", g_onoff_commands[ i ] );
		register_clcmd(szCommand, "CmdMenu");
		
		TrieSetCell(g_onoff_trie, g_onoff_commands[i], i);
	}
	
	register_clcmd("say /ljsversion", "CmdVersion");
	
	register_concmd("js_updatecvars", "CmdUpdateCvars", ADMIN_RCON);
	
	register_srvcmd("js_allow_weapon", "CmdAddWeapon");
	
	g_valid_weapons = TrieCreate();
	
	new name[32];
	for( new weapon = 1; weapon < sizeof(g_weapon_names); weapon++ )
	{
		if( weapon == 2 )
		{
			copy(name, sizeof(name) - 1, "shield");
		}
		else
		{
			//weapon_*
			//01234567
			
			get_weaponname(weapon, name, sizeof(name) - 1);
			copy(name, sizeof(name) - 1, name[7]);
		}
		
		TrieSetCell(g_valid_weapons, name, weapon);
	}
	
	RegisterHam(Ham_Spawn, "player", "FwdPlayerSpawn", 1);
	RegisterHam(Ham_Killed, "player", "FwdPlayerDeath", 1);
	
	register_touch("func_train", "player", "FwdResetJump");
	register_touch("func_door", "player", "FwdResetJumpDoor");
	register_touch("func_door_rotating", "player", "FwdResetJump");
	register_touch("func_conveyor", "player", "FwdResetJump");
	register_touch("func_rotating", "player", "FwdResetJump");
	register_touch("trigger_push", "player", "FwdResetJump");
	register_touch("trigger_teleport", "player", "FwdResetJump");
	register_touch("bcm_t", "player", "FwdResetJumpBCM3");
	register_touch("bcm_3", "player", "FwdResetJumpBCM5");
	
	LoadResetCommands("CmdResetJump");
	
	g_client_cvar_index = TrieCreate();
	for( new i = 0; i < sizeof(g_client_cvar_names); i++ )
	{
		TrieSetCell(g_client_cvar_index, g_client_cvar_names[i], i);
	}
	
	for( new i = 0; i < sizeof(g_cvar_names); i++ )
	{
		g_cvar_pointers[i] = get_cvar_pointer(g_cvar_names[i]);
	}
	
	g_server_frame_enabled = 1;
	
	cvar_allowteam = register_cvar("js_allowteam", "abc");
	cvar_connectflags = register_cvar("js_connectflags", "abcdefghijk");
	cvar_legal_settings = register_cvar("js_legal_settings", "1");
	cvar_legal_settings_kick = register_cvar("js_legal_settings_kick", "1");
	cvar_legal_settings_disagree = register_cvar("js_legal_settings_disagree", "1");
	cvar_servertype = register_cvar("js_servertype", "1");
	cvar_savetops = register_cvar("js_savetops", "1");
	cvar_techs_allowed = register_cvar("js_techs_allowed", "abcdefghijklm");
	cvar_speed_color = register_cvar("js_speed_color", "255 255 255");
	cvar_save_settings = register_cvar("js_save_settings", "1");
	cvar_save_prune = register_cvar("js_save_prune", "0");
	cvar_direction_forwards = register_cvar("js_direction_forwards", "1");
	
	g_max_clients = get_maxplayers();
	
	g_cvar_forward = CreateMultiForward("js_update_cvars", ET_IGNORE);
	g_reset_forward = CreateMultiForward("js_reset_jump", ET_IGNORE, FP_CELL, FP_CELL);
	
	new pluginsnum = get_pluginsnum(), funcid;
	for( new i = 0; i < pluginsnum; i++ )
	{
		funcid = get_func_id("js_load_sounds", i);
		if( funcid == -1 )
		{
			continue;
		}
		
		for( new j = 0; j < SOUND_TOTAL; j++ )
		{
			callfunc_begin_i(funcid, i);
			callfunc_push_int(j);
			callfunc_push_str(g_sound_files[j]);
			callfunc_end();
		}
	}
	
	TaskDelayedConfig();
	
	new entity = create_entity("info_target");
	if( is_valid_ent(entity) )
	{
		new classname[] = "js_speedometer";
		
		entity_set_string(entity, EV_SZ_classname, classname);
		register_think(classname, "FwdSpeedometer");
		entity_set_float(entity, EV_FL_nextthink, get_gametime() + SPEEDOMETER_INTERVAL);
	}
	else
	{
		set_task(SPEEDOMETER_INTERVAL, "TaskDoSpeed", _, _, _, "b");
	}
}

register_topcmd(pre[], handle[], flags=-1, desc[]="")
{
	static const after[][] = {"top", "10", "15"};
	static command[32], i;
	for( i = 0; i < sizeof(after); i++ )
	{
		formatex(command, sizeof(command) - 1, "say /%s%s", pre, after[i]);
		register_clcmd(command, handle, flags, desc);
	}
}

public TaskDelayedConfig()
{
	// addons/amxmodx/configs/jumpstats.cfg
	// 123456789012345678901234567890123456
	
	new filename[40];
	get_configsdir(filename, sizeof(filename) - 1);
	add(filename, sizeof(filename) - 1, "/jumpstats.cfg");
	
	if( file_exists(filename) )
	{
		server_cmd("exec %s", filename);
		//server_exec();
	}
	
	if( get_pcvar_num(cvar_savetops) )
	{
		for( new i = 0; i < JUMP_TYPES; i++ )
		{
			LoadTops(i);
		}
	}
	else
	{
		for( new i = 0; i < JUMP_TYPES; i++ )
		{
			// Since tops shouldn't save each map, we have to reset the save files every startup
			// By saving them here, the tops are still clear in the variables, so the files will be empty
			SaveTops(i);
		}
	}
	
	/*new retval;
	ExecuteForward(g_cvar_forward, retval);*/
	
	// We have to wait for the config to be executed before
	// retrieving the values.
	set_task(1.0, "EventCacheCvars");
	
	new servertype = get_pcvar_num(cvar_servertype);
	if( servertype == 1 )
	{
		register_event("HLTV", "EventCacheCvars", "a", "1=0", "2=0");
	}
	else
	{
		g_cache_entity = create_entity("info_target");
		if( !is_valid_ent(g_cache_entity) )
		{
			// it's a last resort :|
			set_task(CACHE_UPDATE_INTERVAL, "EventCacheCvars", _, _, _, "b");
		}
		else
		{
			new cvar_entity_classname[] = "js_cvar_cache";
			
			entity_set_string(g_cache_entity, EV_SZ_classname, cvar_entity_classname);
			register_think(cvar_entity_classname, "FwdCacheCvars");
			
			entity_set_float(g_cache_entity, EV_FL_nextthink, get_gametime() + CACHE_UPDATE_INTERVAL);
		}
	}
}

public plugin_end()
{
	TrieDestroy(g_client_cvar_index);
	
	TrieDestroy(g_onoff_trie);
}

public plugin_natives()
{
	register_library("jumpstats");
	
	register_native("js_user_has_colorchat", "_colorchat");
	register_native("js_user_has_sounds", "_sounds");
	register_native("js_user_has_jumpstats", "_jumpstats");
	register_native("js_user_has_strafestats", "_strafestats");
	register_native("js_user_has_beam", "_beam");
	register_native("js_user_has_specstats", "_specstats");
	register_native("js_user_has_prestrafe", "_prestrafe");
	register_native("js_user_has_dirhud", "_dirhud");
	register_native("js_user_has_blockdist", "_blockdist");
	register_native("js_user_has_edgedist", "_edgedist");
	
	register_native("js_check_user_top", "_check_top");
	register_native("js_check_user_best", "_check_best");
	
	register_native("js_get_top", "_get_top");
	register_native("js_get_top_num", "_get_top_num");
	
	register_native("js_get_weapons_allow", "_get_weapons_allow");
	register_native("js_get_weapons_chat", "_get_weapons_chat");
	register_native("js_get_weapons_sound", "_get_weapons_sound");
}

public bool:_colorchat(plugin, params)
{
	return !!(g_flags[get_param(1)] & ONOFF_COLORCHAT);
}

public bool:_sounds(plugin, params)
{
	new client = get_param(1);
	return ((g_flags[client] & ONOFF_SOUNDS) && (g_flags[client] & ONOFF_COLORCHAT));
}

public bool:_jumpstats(plugin, params)
{
	return !!(g_flags[get_param(1)] & ONOFF_JUMPSTATS);
}

public bool:_strafestats(plugin, params)
{
	return !!(g_flags[get_param(1)] & ONOFF_STRAFESTATS);
}

public bool:_beam(plugin, params)
{
	return !!(g_flags[get_param(1)] & ONOFF_BEAM);
}

public bool:_specstats(plugin, params)
{
	return !!(g_flags[get_param(1)] & ONOFF_SPECSTATS);
}

public bool:_prestrafe(plugin, params)
{
	return !!(g_flags[get_param(1)] & ONOFF_PRESTRAFE);
}

public bool:_dirhud(plugin, params)
{
	return !!(g_flags[get_param(1)] & ONOFF_DIRHUD);
}

public bool:_blockdist(plugin, params)
{
	return !!(g_flags[get_param(1)] & ONOFF_BLOCKDIST);
}

public bool:_edgedist(plugin, params)
{
	return !!(g_flags[get_param(1)] & ONOFF_EDGEDIST);
}

public _check_top(plugin, params)
{
	new client = get_param(1);
	new type = get_param(2);
	new direction = get_param(3);
	new Float:distance = get_param_f(4);
	new Float:prestrafe = get_param_f(5);
	new Float:maxspeed = get_param_f(6);
	new strafes = get_param(7);
	new sync = get_param(8);
	
	return CheckTop(client, type, direction, distance, prestrafe, maxspeed, strafes, sync);
}

public _check_best(plugin, params)
{
	new client = get_param(1);
	new type = get_param(2);
	new direction = get_param(3);
	new Float:distance = get_param_f(4);
	new Float:prestrafe = get_param_f(5);
	new Float:maxspeed = get_param_f(6);
	new strafes = get_param(7);
	new sync = get_param(8);
	
	return CheckBest(client, type, direction, distance, prestrafe, maxspeed, strafes, sync);
}

public _get_top(plugin, params)
{
	new type = get_param(1);
	if( !g_total_top[type] ) return 0;
	
	new num = get_param(2);
	if( !(0 <= num < g_total_top[type]) ) return 0;
	
	// 3 = name[], 4 = len
	set_string(3, g_top_name[type][num], get_param(4));
	
	// 5 = direction, 6 = distance, 7 = prestrafe, 8 = maxspeed, 9 = strafes, 10 = sync
	set_param_byref(5, DirectionNameToValue(g_top_direction[type][num]));
	set_param_byref(6, _:g_top_distance[type][num]);
	set_param_byref(7, _:g_top_prestrafe[type][num]);
	set_param_byref(8, _:g_top_maxspeed[type][num]);
	set_param_byref(9, g_top_strafes[type][num]);
	set_param_byref(10, g_top_sync[type][num]);
	
	return 1;
}

public _get_top_num(plugin, params)
{
	new type = get_param(1);
	
	if( !g_total_top[type] ) return -1;
	
	static authid[35];
	get_string(2, authid, sizeof(authid) - 1);
	
	for( new i = 0; i < g_total_top[type]; i++ )
	{
		if( !strcmp(authid, g_top_steamid[type][i], 1) )
		{
			return i;
		}
	}
	
	return -1;
}

public _get_weapons_allow(plugin, params)
{
	return g_weapons_allow;
}

public _get_weapons_chat(plugin, params)
{
	return g_weapons_chat;
}

public _get_weapons_sound(plugin, params)
{
	return g_weapons_sound;
}

public client_authorized(client)
{
	if( !is_user_bot(client) )
	{
		LoadBest(client);
		
		if( get_pcvar_num(cvar_legal_settings) )
		{
			static authid[35];
			get_user_authid(client, authid, sizeof(authid) - 1);
			
			if( fvault_get_keynum(g_agree_vault, authid) == -1 )
			{
				g_agreed[client] = false;
				
				g_flags[client] = 0;
			}
			else
			{
				g_agreed[client] = true;
				
				if( get_pcvar_num(cvar_save_settings) )
				{
					LoadSettings(client);
				}
				else
				{
					static flags[26];
					get_pcvar_string(cvar_connectflags, flags, sizeof(flags) - 1);
					g_flags[client] = read_flags(flags);
				}
				
				for( new i = 0; i < sizeof(g_client_cvar_names); i++ )
				{
					client_cmd(client, "%s %i", g_client_cvar_names[i], g_client_cvar_values[i]);
				}
				
				set_task(1.0, "TaskCheckCvars", client);
			}
		}
		else
		{
			g_agreed[client] = false;
			
			if( get_pcvar_num(cvar_save_settings) )
			{
				LoadSettings(client);
			}
			else
			{
				static flags[26];
				get_pcvar_string(cvar_connectflags, flags, sizeof(flags) - 1);
				g_flags[client] = read_flags(flags);
			}
		}
	}
}

public client_putinserver(client)
{
	if( !is_user_bot(client) )
	{
		g_connected[client] = true;
	}
	else //client is bot, so don't show agree menu.
	{
		g_agreed[client] = true;
	}
}

LoadSettings(client)
{
	static authid[35];
	get_user_authid(client, authid, sizeof(authid) - 1);
	
	static flags[26];
	if( !fvault_get_data(g_flags_vault, authid, flags, sizeof(flags) - 1) )
	{
		get_pcvar_string(cvar_connectflags, flags, sizeof(flags) - 1);
		fvault_set_data(g_flags_vault, authid, flags);
	}
	
	g_flags[client] = read_flags(flags);
}

public client_disconnect(client)
{
	g_connected[client] = false;
	g_alive[client] = false;
	
	remove_task(client);
	
	for( new i = 0; i < JUMP_TYPES; i++ )
	{
		g_best_exists[client][i] = false;
	}
	
	g_menu_page[client] = 0;
}

public CmdReset(client, level, cid)
{
	if( !cmd_access(client, level, cid, 1) ) return PLUGIN_HANDLED;
	
	if( client == 0 )
	{
		server_print("[JUMPSTATS] Server consoles cannot reset the stats!");
		return PLUGIN_HANDLED;
	}
	
	menu_display(client, g_reset_main_menu, g_menu_page[client]);
	
	return PLUGIN_HANDLED;
}

public CmdTop(client)
{
	menu_display(client, g_top_menu, g_menu_page[client]);
	
	return PLUGIN_HANDLED;
}

public CallbackTopMain(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		return ITEM_ENABLED;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	new type = str_to_num(info);
	
	if( type == -1 )
	{
		static steamid[35];
		get_user_authid(client, steamid, sizeof(steamid) - 1);
		
		static total;
		for( new i = 0; i < JUMP_TYPES; i++ )
		{
			if( !(total = g_total_top[i]) ) continue;
			
			for( new j = 0; j < total; j++ )
			{
				if( !strcmp(steamid, g_top_steamid[i][j], 1) )
				{
					return ITEM_ENABLED;
				}
			}
		}
	}
	else if( IsTechAllowed(type, g_techs_allowed) && g_total_top[type] )
	{
		return ITEM_ENABLED;
	}
	
	return ITEM_DISABLED;
}

public MenuTopMain(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		g_menu_page[client] = 0;
		ShowMainMenu(client);
		return;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	new type = str_to_num(info);
	
	if( type == -1 )
	{
		static steamid[35];
		get_user_authid(client, steamid, sizeof(steamid) - 1);
		
		static positions[JUMP_TYPES][2]; // 0 = position, 1 = JUMP_*
		
		static total;
		for( new i = 0; i < JUMP_TYPES; i++ )
		{
			positions[i][0] = -1;
			positions[i][1] = i;
			
			if( !(total = g_total_top[i]) ) continue;
			
			for( new j = 0; j < total; j++ )
			{
				if( !strcmp(steamid, g_top_steamid[i][j], 1) )
				{
					positions[i][0] = j;
					break;
				}
			}
		}
		
		SortCustom2D(positions, JUMP_TYPES, "SortPositions");
		
		static motd[2500];
		new len = formatex(motd, sizeof(motd) - 1,\
			"<body bgcolor=#A4BED6>\
			<table width=100%% cellpadding=2 cellspacing=0 border=0>\
			<tr align=center bgcolor=#52697B>\
			<th width=5%%>#\
			<th width=30%% align=left>Jump Type\
			<th width=15%%>Distance\
			<th width=12%%>MaxSpeed\
			<th width=12%%>PreStrafe\
			<th width=9%%>Strafes\
			<th width=7%%>Sync"
			);
		
		static pos, type;
		for( new i = 0; i < JUMP_TYPES; i++ )
		{
			if( (pos = positions[i][0]) >= 0 )
			{
				type = positions[i][1];
				len += formatex(motd[len], sizeof(motd) - len - 1, "<tr align=center>");
				len += formatex(motd[len], sizeof(motd) - len - 1, "<td>%i", pos + 1);
				len += formatex(motd[len], sizeof(motd) - len - 1, "<td align=left>%s", g_jump_names[type]);
				len += formatex(motd[len], sizeof(motd) - len - 1, "<td>%.1f", g_top_distance[type][pos]);
				len += formatex(motd[len], sizeof(motd) - len - 1, "<td>%.1f", g_top_maxspeed[type][pos]);
				len += formatex(motd[len], sizeof(motd) - len - 1, "<td>%.1f", g_top_prestrafe[type][pos]);
				len += formatex(motd[len], sizeof(motd) - len - 1, "<td>%i", g_top_strafes[type][pos]);
				len += formatex(motd[len], sizeof(motd) - len - 1, "<td>%i%%", g_top_sync[type][pos]);
			}
		}
		
		formatex(motd[len], sizeof(motd) - len - 1, "</table></body>");
		
		show_motd(client, motd, "Your Tops");
		
		menu_display(client, g_top_menu);
	}
	else
	{
		g_menu_page[client] = (type + 1) / 7;
		
		if( !IsTechAllowed(type, g_techs_allowed) )
		{
			client_print(client, print_chat, "[JUMPSTATS] The %s technique is not enabled.", g_jump_names[type]);
			menu_display(client, g_top_menu, g_menu_page[client]);
		}
		else
		{
			g_menu_type[client] = type;
			ShowTopMenu(client);
		}
	}
}

public SortPositions(const elem1[], const elem2[])
{
	if( elem1[0] < elem2[0] )
	{
		return -1;
	}
	else if( elem1[0] == elem2[0] )
	{
		return 0;
	}
	
	return 1;
}

public MenuReset(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		ShowAdminMenu(client);
		return;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	if( info[0] == '1' )
	{
		menu_display(client, g_reset_tops_menu, (g_menu_page[client] = 0));
	}
	else
	{
		menu_display(client, g_reset_best_menu, (g_menu_page[client] = 0));
	}
}

public CallbackResetTops(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		return ITEM_ENABLED;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	new type = str_to_num(info);
	
	if( type == -1 )
	{
		for( type = 0; type < JUMP_TYPES; type++ )
		{
			if( g_total_top[type] )
			{
				return ITEM_ENABLED;
			}
		}
	}
	else if( g_total_top[type] )
	{
		return ITEM_ENABLED;
	}
	
	return ITEM_DISABLED;
}

public MenuResetTops(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		g_menu_page[client] = 0;
		menu_display(client, g_reset_main_menu);
		return;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	new type = str_to_num(info);
	
	if( type == -1 )
	{
		for( type = 0; type < JUMP_TYPES; type++ )
		{
			for( new i = 0; i < MAX_TOP; i++ )
			{
				copy(g_top_steamid[type][i], sizeof(g_top_steamid[][]) - 1, "");
				copy(g_top_name[type][i], sizeof(g_top_name[][]) - 1, "");
				copy(g_top_direction[type][i], sizeof(g_top_direction[][]) - 1, "");
				g_top_distance[type][i] = 0.0;
				g_top_prestrafe[type][i] = 0.0;
				g_top_maxspeed[type][i] = 0.0;
				g_top_strafes[type][i] = 0;
				g_top_sync[type][i] = 0;
			}
			
			g_total_top[type] = 0;
			
			SaveTops(type);
		}
		
		static name[32];
		get_user_name(client, name, sizeof(name) - 1);
		
		ColorChat(0, RED, "[JUMPSTATS] %s has reset all top stats!", name);
		
		menu_display(client, g_reset_tops_menu, g_menu_page[client]);
	}
	else
	{
		for( new i = 0; i < MAX_TOP; i++ )
		{
			copy(g_top_steamid[type][i], sizeof(g_top_steamid[][]) - 1, "");
			copy(g_top_name[type][i], sizeof(g_top_name[][]) - 1, "");
			copy(g_top_direction[type][i], sizeof(g_top_direction[][]) - 1, "");
			g_top_distance[type][i] = 0.0;
			g_top_prestrafe[type][i] = 0.0;
			g_top_maxspeed[type][i] = 0.0;
			g_top_strafes[type][i] = 0;
			g_top_sync[type][i] = 0;
		}
		
		g_total_top[type] = 0;
		
		SaveTops(type);
		
		static name[32];
		get_user_name(client, name, sizeof(name) - 1);
		
		ColorChat(0, RED, "[JUMPSTATS] %s has reset the %s Top!", name, g_jump_names[type]);
		
		g_menu_page[client] = (type + 1) / 7;
		
		menu_display(client, g_reset_tops_menu, g_menu_page[client]);
	}
}

public CallbackResetBest(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		return ITEM_ENABLED;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	new type = str_to_num(info);
	
	if( type == -1 )
	{
		if( fvault_size(g_best_vault) )
		{
			return ITEM_ENABLED;
		}
	}
	else
	{
		static key[40];
		new len = strlen(g_jump_prefixes[type]);
		
		new total = fvault_size(g_best_vault);
		for( new i = 0; i < total; i++ )
		{
			fvault_get_keyname(g_best_vault, i, key, sizeof(key) - 1);
			
			if( equal(key[strlen(key) - len], g_jump_prefixes[type]) )
			{
				return ITEM_ENABLED;
			}
		}
	}
	
	return ITEM_DISABLED;
}

public MenuResetBest(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		g_menu_page[client] = 0;
		menu_display(client, g_reset_main_menu);
		return;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	new type = str_to_num(info);
	
	DeleteBest(0, type);
	
	static name[32];
	get_user_name(client, name, sizeof(name) - 1);
	
	if( type == -1 )
	{
		ColorChat(0, RED, "[JUMPSTATS] %s has reset all personal best records for all jump types!", name);
	}
	else
	{
		ColorChat(0, RED, "[JUMPSTATS] %s has reset all personal best records for %ss!", name, g_jump_names[type]);
	}
	
	g_menu_page[client] = (type + 1) / 7;
	
	menu_display(client, g_reset_best_menu, g_menu_page[client]);
}

public CmdMenu(client)
{
	static command[20];
	read_argv(1, command, sizeof(command) - 1);
	strtolower(command);
	
	static i;
	if( TrieGetCell(g_onoff_trie, command, i) )
	{
		SwitchOnOff(client, i);
	}
	else
	{
		ShowMainMenu(client);
	}
}

public CmdVersion(client)
{
	ColorChat(client, TEAM_COLOR, "^4[JUMPSTATS]^1 This server is running^3 JumpStats^1,^3 v%s by Exolent", PLUGIN_VERSION);
}

public CmdUpdateCvars(client, level, cid)
{
	if( !cmd_access(client, level, cid, 1) ) return PLUGIN_HANDLED;
	
	EventCacheCvars();
	
	console_print(client, "[JUMPSTATS] Cvar cache executed.");
	
	return PLUGIN_HANDLED;
}

public CmdAddWeapon(client, level, cid)
{
	if( !cmd_access(client, level, cid, 2) ) return PLUGIN_HANDLED;
	
	static name[32];
	read_argv(1, name, sizeof(name) - 1);
	strtolower(name);
	
	static weapon;
	if( TrieGetCell(g_valid_weapons, name, weapon) )
	{
		g_weapons_allow |= (1 << weapon);
		
		new iArgCount = read_argc();
		if( iArgCount > 2 )
		{
			read_argv(2, name, sizeof(name) - 1);
			if( name[0] == '1' )
			{
				g_weapons_chat |= (1 << weapon);
			}
			
			if( iArgCount > 3 )
			{
				read_argv(3, name, sizeof(name) - 1);
				if( name[0] == '1' )
				{
					g_weapons_sound |= (1 << weapon);
				}
			}
			else
			{
				g_weapons_sound |= (1 << weapon);
			}
		}
		else
		{
			g_weapons_chat |= (1 << weapon);
			g_weapons_sound |= (1 << weapon);
		}
	}
	else
	{
		log_amx("Invalid weapon name supplied for js_allow_weapon: ^"%s^"", name);
	}
	
	return PLUGIN_HANDLED;
}

public FwdPlayerSpawn(client)
{
	if( is_user_alive(client) )
	{
		g_alive[client] = true;
		
		if( !g_agreed[client] )
		{
			ShowAgreeMenu( client );
		}
	}
}

public FwdPlayerDeath(client, killer, shouldgib)
{
	g_alive[client] = bool:is_user_alive(client);
}

ResetJump(client, door)
{
	static ret;
	ExecuteForward(g_reset_forward, ret, client, door);
}

public FwdResetJump(ent, client)
{
	ResetJump(client, 0);
}

public FwdResetJumpDoor(ent, client)
{
	ResetJump(client, 1);
}

public FwdResetJumpBCM3(ent, client)
{
	static target[8];
	pev(ent, pev_target, target, sizeof(target) - 1);
	
	if( is_valid_ent(find_ent_by_tname(-1, target)) )
	{
		ResetJump(client, 0);
	}
}

public FwdResetJumpBCM5(ent, client)
{
	if( pev(ent, pev_iuser1) == 7 )
	{
		static property[32];
		pev(ent, pev_netname, property, sizeof(property) - 1);
		
		if( property[0] && is_valid_ent(engfunc(EngFunc_FindEntityByString, -1, "netname", property)) )
		{
			ResetJump(client, 0);
		}
	}
}

public CmdResetJump(client)
{
	ResetJump(client, 0);
}

public FwdSpeedometer(entity)
{
	TaskDoSpeed();
	
	entity_set_float(entity, EV_FL_nextthink, get_gametime() + SPEEDOMETER_INTERVAL);
}

public TaskDoSpeed()
{
	static alive, Float:velocity[3], Float:length;
	
	for( new client = 1; client <= g_max_clients; client++ )
	{
		if( g_connected[client]
		&& (g_flags[client] & ONOFF_SPEED)
		&& (is_user_alive(client) || (g_flags[client] & ONOFF_SPECSTATS)) )
		{
			// if client is alive or not spectating a player, it will return client
			alive = GetSpectatedPlayer(client);
			
			pev(alive, pev_velocity, velocity);
			
			length = vector_length(velocity);
			
			velocity[2] = 0.0;
			
			set_hudmessage(g_speed_color[R], g_speed_color[G], g_speed_color[B], HUD_POS_SPEEDOMETER_X, HUD_POS_SPEEDOMETER_Y, 0, 0.0, SPEEDOMETER_INTERVAL + 0.1, 0.0, 0.0, 4);
			show_hudmessage(client, "%.3f units/second^n%.3f velocity", vector_length(velocity), length);
		}
	}
}

public server_frame()
{
	if( !g_server_frame_enabled ) return;
	
	static entity, victim, Float:entity_origin[3];
	
	// Blockmaker Teleport Detection
	entity = -1;
	while( (entity = find_ent_by_class(entity, "bm_teleport_start")) )
	{
		pev(entity, pev_origin, entity_origin);
		
		victim = -1;
		while( (victim = find_ent_in_sphere(victim, entity_origin, 68.0)) )
		{
			if( (1 <= victim <= g_max_clients) && g_alive[victim] )
			{
				ResetJump(victim, 0);
			}
		}
	}
	
	for( new i = 0; i < sizeof(g_cvar_names); i++ )
	{
		set_pcvar_num(g_cvar_pointers[i], g_cvar_values[i]);
	}
}

public FwdCacheCvars(entity)
{
	if( entity == g_cache_entity )
	{
		EventCacheCvars();
		
		entity_set_float(entity, EV_FL_nextthink, get_gametime() + CACHE_UPDATE_INTERVAL);
	}
}

public EventCacheCvars()
{
	static bool:bAlreadyExecuted;
	if( !bAlreadyExecuted )
	{
		new iDays = get_pcvar_num( cvar_save_prune );
		if( iDays )
		{
			fvault_prune( g_agree_vault, _, get_systime( ) - ( iDays * 60 * 60 ) );
		}
		
		bAlreadyExecuted = true;
	}
	
	static retval;
	ExecuteForward(g_cvar_forward, retval);
	
	static flags[26];
	get_pcvar_string(cvar_techs_allowed, flags, sizeof(flags) - 1);
	g_techs_allowed = read_flags(flags);
	
	static r, g, b
	CvarToRGB(cvar_speed_color, r, g, b);
	g_speed_color[R] = r;
	g_speed_color[G] = g;
	g_speed_color[B] = b;
}

ShowMainMenu(client)
{
	if( !g_agreed[client] )
	{
		ShowAgreeMenu( client );
		return;
	}
	
	menu_display(client, g_main_menu);
}

public MenuMain(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		return;
	}
	
	static _access, info[3], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	switch( info[0] )
	{
		case '1':
		{
			menu_display(client, g_top_menu, g_menu_page[client]);
		}
		case '2':
		{
			new bool:has_jumps = false;
			for( new i = 0; i < JUMP_TYPES; i++ )
			{
				if( g_best_exists[client][i] )
				{
					has_jumps = true;
					break;
				}
			}
			
			if( has_jumps )
			{
				menu_display(client, g_best_main_menu);
			}
			else
			{
				client_print(client, print_chat, "[JUMPSTATS] You do not have any jumps.");
				
				ShowMainMenu(client);
			}
		}
		case '3':
		{
			ShowOnOffMenu(client);
		}
		case '4':
		{
			ShowAdminMenu(client);
		}
	}
}

ShowOnOffMenu(client, page=0)
{
	if( !g_agreed[client] )
	{
		ShowAgreeMenu( client );
		return;
	}
	
	static item[32], info[3];
	
	new menu = menu_create("JumpStats On/Off Menu", "MenuOnOff");
	
	for( new i = 0; i < sizeof(g_onoff_names); i++ )
	{
		formatex(item, sizeof(item) - 1, "%s: %s", g_onoff_names[i], (g_flags[client] & (1 << i)) ? "\yOn" : "\rOff");
		num_to_str(i, info, sizeof(info) - 1);
		
		menu_additem(menu, item, info);
	}
	
	menu_display(client, menu, page);
}

public MenuOnOff(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu);
		ShowMainMenu(client);
		return;
	}
	
	static _access, info[3], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	menu_destroy(menu);
	
	new key = str_to_num(info);
	SwitchOnOff(client, key);
	
	EventCacheCvars();
	
	ShowOnOffMenu(client, key / 7);
}

SwitchOnOff(client, num)
{
	if( g_agreed[client] )
	{
		new flag = (1 << num);
		
		g_flags[client] ^= flag;
		
		static authid[35];
		get_user_authid(client, authid, sizeof(authid) - 1);
		
		static flags[26];
		get_flags(g_flags[client], flags, sizeof(flags) - 1);
		
		fvault_set_data(g_flags_vault, authid, flags);
		
		ColorChat(client, (g_flags[client] & flag) ? BLUE : RED, "^x04[JUMPSTATS]^x03 %s %s been %sabled!", g_onoff_names[num], g_onoff_verbs[num], (g_flags[client] & flag) ? "en" : "dis");
	}
	else
	{
		ColorChat(client, RED, "^x04[JUMPSTATS]^x03 You must agree to accept legal jump settings!");
		
		ShowAgreeMenu( client );
	}
}

ShowAdminMenu(client)
{
	if( !g_agreed[client] )
	{
		ShowAgreeMenu( client );
		return;
	}
	
	menu_display(client, g_admin_menu);
}

public MenuAdmin(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		ShowMainMenu(client);
		return;
	}
	
	static _access, info[3], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	switch( info[0] )
	{
		case '1':
		{
			menu_display(client, g_reset_main_menu, (g_menu_page[client] = 0));
		}
		case '2':
		{
			ShowCustomizeMenu(client);
		}
		case '3':
		{
			ShowAllowTeamMenu(client);
		}
		case '4':
		{
			ShowWeaponMenu(client);
		}
		case '5':
		{
			ShowTechMenu(client);
		}
		case '6':
		{
			SaveSettingsToFile();
			
			ShowAdminMenu(client);
		}
	}
}

SaveSettingsToFile( )
{
	static szFilename[ 128 ], szTempFilename[ 128 ];
	if( !szFilename[ 0 ] )
	{
		get_configsdir( szFilename, 127 );
		formatex( szTempFilename, 127, "%s/rewrite_jumpstats.cfg", szFilename );
		add( szFilename, 127, "/jumpstats.cfg" );
	}
	
	new iFile = fopen( szFilename, "rt" );
	if( !iFile )
	{
		return 0;
	}
	
	new iTemp = fopen( szTempFilename, "wt" );
	
	static szData[ 1024 ], szCvar[ 32 ], iLen, i;
	new bool:bWeapons, bool:bTechs, bool:bTeams, bool:bConnect;
	while( !feof( iFile ) )
	{
		fgets( iFile, szData, 1023 );
		if( szData[ 0 ] && szData[ 0 ] != '^n' && szData[ 0 ] != '/' && szData[ 1 ] != '/' )
		{
			parse( szData, szCvar, 31 );
			
			if( equal( szCvar, "js_allow_weapon" ) )
			{
				if( !bWeapons )
				{
					bWeapons = true;
					
					for( i = 1; i < sizeof( g_weapon_names ); i++ )
					{
						if( g_weapons_allow & ( 1 << i ) )
						{
							if( i == 2 )
							{
								copy( szCvar, 31, "shield" );
							}
							else
							{
								get_weaponname( i, szCvar, 31 );
								copy( szCvar, 31, szCvar[ 7 ] );
							}
							
							fprintf( iTemp, "js_allow_weapon ^"%s^" ^"%i^" ^"%i^"%s",\
								szCvar,\
								( g_weapons_chat & ( 1 << i ) ) ? 1 : 0,\
								( g_weapons_sound & ( 1 << i ) ) ? 1 : 0,\
								szData[ strlen( szData ) - 1 ] == '^n' ? "^n" : ""
								);
						}
					}
				}
				
				continue;
			}
			if( equal( szCvar, "js_techs_allowed" ) )
			{
				if( !bTechs )
				{
					bTechs = true;
					
					iLen = 0;
					for( i = 0; i < JUMP_TYPES; i++ )
					{
						if( g_techs_allowed & ( 1 << i ) )
						{
							szCvar[ iLen++ ] = 'a' + i;
						}
					}
					szCvar[ iLen ] = 0;
					
					fprintf( iTemp, "js_techs_allowed ^"%s^"%s", szCvar, szData[ strlen( szData ) - 1 ] == '^n' ? "^n" : "" );
				}
				
				continue;
			}
			if( equal( szCvar, "js_allowteam" ) )
			{
				if( !bTeams )
				{
					bTeams = true;
					
					iLen = 0;
					for( i = 1; i <= 3; i++ )
					{
						if( g_techs_allowed & ( 1 << i ) )
						{
							szCvar[ iLen++ ] = 'a' + i - 1;
						}
					}
					szCvar[ iLen ] = 0;
					
					fprintf( iTemp, "js_allowteam ^"%s^"%s", szCvar, szData[ strlen( szData ) - 1 ] == '^n' ? "^n" : "" );
				}
				
				continue;
			}
			if( equal( szCvar, "js_connectflags" ) )
			{
				if( !bConnect )
				{
					bConnect = true;
					
					get_pcvar_string( cvar_connectflags, szCvar, 31 );
					
					fprintf( iTemp, "js_connectflags ^"%s^"%s", szCvar, szData[ strlen( szData ) - 1 ] == '^n' ? "^n" : "" );
				}
				
				continue;
			}
		}
		
		fputs( iTemp, szData );
	}
	
	fclose( iFile );
	fclose( iTemp );
	
	delete_file( szFilename );
	
	while( !rename_file( szTempFilename, szFilename, 1 ) ) { }
	
	return 1;
}

ShowCustomizeMenu(client, page=0)
{
	new menu = menu_create("Connect Enabler", "MenuCustomize");
	
	static connect_flags[26];
	get_pcvar_string(cvar_connectflags, connect_flags, sizeof(connect_flags) - 1);
	
	new flags = read_flags(connect_flags);
	
	static item[64], info[3];
	for( new i = 0; i < sizeof(g_onoff_names); i++ )
	{
		formatex(item, sizeof(item) - 1, "%s: %s", g_onoff_names[i], (flags & (1 << i)) ? "\yOn" : "\rOff");
		num_to_str(i, info, sizeof(info) - 1);
		
		menu_additem(menu, item, info);
	}
	
	menu_display(client, menu, page);
}

public MenuCustomize(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu);
		ShowAdminMenu(client);
		return;
	}
	
	static _access, info[3], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	menu_destroy(menu);
	
	new num = str_to_num(info);
	new flag = (1 << num);
	
	static connect_flags[26];
	get_pcvar_string(cvar_connectflags, connect_flags, sizeof(connect_flags) - 1);
	
	new flags = read_flags(connect_flags);
	
	flags ^= flag;
	
	get_flags(flags, connect_flags, sizeof(connect_flags) - 1);
	set_pcvar_string(cvar_connectflags, connect_flags);
	
	ColorChat(client, (flags & flag) ? BLUE : RED, "^x04[JUMPSTATS]^x03 %s %s been %sabled!", g_onoff_names[num], g_onoff_verbs[num], (flags & flag) ? "en" : "dis");
	
	EventCacheCvars();
	
	ShowCustomizeMenu(client, num / 7);
}

ShowAllowTeamMenu(client)
{
	new menu = menu_create("Allow Teams", "MenuAllowTeam");
	
	static team_flags[26];
	get_pcvar_string(cvar_allowteam, team_flags, sizeof(team_flags) - 1);
	
	new flags = read_flags(team_flags);
	
	static item[64], info[3];
	for( new i = 0; i < sizeof(g_team_names); i++ )
	{
		formatex(item, sizeof(item) - 1, "%s: %s", g_team_names[i], (flags & (1 << i)) ? "\yOn" : "\rOff");
		num_to_str(i, info, sizeof(info) - 1);
		
		menu_additem(menu, item, info);
	}
	
	menu_display(client, menu);
}

public MenuAllowTeam(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu);
		ShowAdminMenu(client);
		return;
	}
	
	static _access, info[3], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	menu_destroy(menu);
	
	new num = str_to_num(info);
	new flag = (1 << num);
	
	static team_flags[26];
	get_pcvar_string(cvar_allowteam, team_flags, sizeof(team_flags) - 1);
	
	new flags = read_flags(team_flags);
	
	flags ^= flag;
	
	get_flags(flags, team_flags, sizeof(team_flags) - 1);
	set_pcvar_string(cvar_allowteam, team_flags);
	
	ColorChat(0, (flags & flag) ? BLUE : RED, "^x04[JUMPSTATS]^x03 JumpStats for %ss have been %sabled!", g_team_names[num], (flags & flag) ? "en" : "dis");
	
	EventCacheCvars();
	
	ShowAllowTeamMenu(client);
}

ShowWeaponMenu(client, page=0)
{
	new menu = menu_create("Allow Weapons", "MenuWeapon");
	
	static item[64], info[3];
	for( new i = 1; i < sizeof(g_weapon_names); i++ )
	{
		formatex(item, sizeof(item) - 1, "%s: %s", g_weapon_names[i], (g_weapons_allow & (1 << i)) ? "\yOn" : "\rOff");
		num_to_str(i, info, sizeof(info) - 1);
		
		menu_additem(menu, item, info);
	}
	
	menu_display(client, menu, page);
}

public MenuWeapon(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu);
		ShowAdminMenu(client);
		return;
	}
	
	static _access, info[3], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	menu_destroy(menu);
	
	new num = str_to_num(info);
	new flag = (1 << num);
	
	g_weapons_allow ^= flag;
	
	ColorChat(client, (g_weapons_allow & flag) ? BLUE : RED, "^x04[JUMPSTATS]^x03 Using the %s for jumps has been %sabled!", g_weapon_names[num], (g_weapons_allow & flag) ? "en" : "dis");
	
	EventCacheCvars();
	
	ShowWeaponMenu(client, --num / 7);
}

ShowTechMenu(client, page=0)
{
	new menu = menu_create("Allow Techniques", "MenuTech");
	
	static item[64], info[3];
	for( new i = 0; i < JUMP_TYPES; i++ )
	{
		formatex(item, sizeof(item) - 1, "%s: %s", g_jump_names[i], (g_techs_allowed & (1 << i)) ? "\yOn" : "\rOff");
		num_to_str(i, info, sizeof(info) - 1);
		
		menu_additem(menu, item, info);
	}
	
	menu_display(client, menu, page);
}

public MenuTech(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu);
		ShowAdminMenu(client);
		return;
	}
	
	static _access, info[3], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	menu_destroy(menu);
	
	new num = str_to_num(info);
	new flag = (1 << num);
	
	g_techs_allowed ^= flag;
	
	static flags[27];
	get_flags(g_techs_allowed, flags, sizeof(flags) - 1);
	set_pcvar_string(cvar_techs_allowed, flags);
	
	ColorChat(client, (g_weapons_allow & flag) ? BLUE : RED, "^x04[JUMPSTATS]^x03 The %s technique has been %sabled!", g_jump_names[num], (g_techs_allowed & flag) ? "en" : "dis");
	
	EventCacheCvars();
	
	ShowTechMenu(client, num / 7);
}

ShowAgreeMenu( client )
{
	static szTitle[ 256 ];
	if( !szTitle[ 0 ] )
	{
		new iLen = copy( szTitle, 255, "This server requires:^n" );
		
		for( new i = 0; i < sizeof( g_client_cvar_names ); i++ )
		{
			iLen += formatex( szTitle[ iLen ], 255 - iLen, "\d- \r%s %i^n", g_client_cvar_names[ i ], g_client_cvar_values[ i ] );
		}
		
		add( szTitle, 255, "^n\yDo you accept this?" );
	}
	
	new hMenu = menu_create( szTitle, "MenuAgree" );
	menu_additem( hMenu, "Yes", "1" );
	if( get_pcvar_num( cvar_legal_settings_disagree ) )
	{
		menu_additem( hMenu, "No \r[ \wYou will be kicked! \r]", "2" );
	}
	else
	{
		menu_additem( hMenu, "No", "2" );
	}
	menu_additem( hMenu, "Yes and don't ask again", "3" );
	menu_setprop( hMenu, MPROP_EXIT, MEXIT_NEVER );
	
	menu_display( client, hMenu );
}

public MenuAgree(client, menu, item)
{
	if( item == MENU_EXIT ) return;
	
	static _access, info[3], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	if( info[0] != '2' )
	{
		g_agreed[client] = true;
		
		for( new i = 0; i < sizeof(g_client_cvar_names); i++ )
		{
			client_cmd(client, "%s %i", g_client_cvar_names[i], g_client_cvar_values[i]);
		}
		
		set_task(1.0, "TaskCheckCvars", client);
		
		static authid[35];
		get_user_authid(client, authid, sizeof(authid) - 1);
		
		if( info[0] == '3' )
		{
			fvault_set_data(g_agree_vault, authid, "1");
		}
		
		if( get_pcvar_num(cvar_save_settings) )
		{
			LoadSettings(client);
		}
		else
		{
			static flags[26];
			get_pcvar_string(cvar_connectflags, flags, sizeof(flags) - 1);
			g_flags[client] = read_flags(flags);
		}
	}
	else if( get_pcvar_num( cvar_legal_settings_disagree ) )
	{
		static const szReason[ ] = "You must agree to use legal jump settings to play here!";
		
		emessage_begin( MSG_ONE, SVC_DISCONNECT, _, client );
		ewrite_string( szReason );
		emessage_end( );
	}
}

public TaskCheckCvars(client)
{
	query_client_cvar(client, g_client_cvar_names[0], "QueryCvar");
}

enum
{
	STRINGTYPE_ERROR,
	STRINGTYPE_INTEGER,
	STRINGTYPE_FLOAT
};

public QueryCvar(client, const cvar_name[], const cvar_value[])
{
	new type = GetStringNumType(cvar_value);
	
	static cvar;
	TrieGetCell(g_client_cvar_index, cvar_name, cvar);
	
	if( type == STRINGTYPE_ERROR	
	|| type == STRINGTYPE_INTEGER && str_to_num(cvar_value) != g_client_cvar_values[cvar]
	|| type == STRINGTYPE_FLOAT && str_to_float(cvar_value) != float(g_client_cvar_values[cvar]) )
	{
		static authid[35];
		get_user_authid(client, authid, sizeof(authid) - 1);
		
		if( fvault_get_keynum(g_agree_vault, authid) >= 0 )
		{
			fvault_remove_key(g_agree_vault, authid);
		}
		
		if( get_pcvar_num(cvar_legal_settings_kick) )
		{
			static reason[192];
			formatex(reason, sizeof(reason) - 1, "You must use legal jump settings!^nYour '%s' must be %i!", cvar_name, g_client_cvar_values[cvar]);
			
			emessage_begin(MSG_ONE, SVC_DISCONNECT, _, client);
			ewrite_string(reason);
			emessage_end();
		}
		else
		{
			client_print(client, print_center, "[JUMPSTATS] You must use legal jump settings!");
			
			g_agreed[client] = false;
			g_flags[client] = 0;
		}
		
		return;
	}
	
	query_client_cvar(client, g_client_cvar_names[(cvar + 1) % sizeof(g_client_cvar_names)], "QueryCvar");
}

GetStringNumType(const string[])
{
	new len = strlen(string);
	if( len )
	{
		new bool:period = false;
		for( new i = 0; i < len; i++ )
		{
			if( '0' <= string[i] <= '9' ) continue;
			
			if( string[i] == '.' && !period )
			{
				period = true;
				continue;
			}
			
			return STRINGTYPE_ERROR;
		}
		
		return period ? STRINGTYPE_FLOAT : STRINGTYPE_INTEGER;
	}
	
	return STRINGTYPE_ERROR;
}

ShowTopMenu(client)
{
	if( !g_total_top[g_menu_type[client]] )
	{
		client_print(client, print_chat, "[JUMPSTATS] There are no top %ss right now.", g_jump_names[g_menu_type[client]]);
		menu_display(client, g_top_menu, g_menu_page[client]);
		return;
	}
	
	static title[32];
	formatex(title, sizeof(title) - 1, "%s Top", g_jump_names[g_menu_type[client]]);
	
	new menu = menu_create(title, "MenuTop");
	
	menu_additem(menu, "\yMOTD Top", "-1");
	
	static item[64], info[4];
	for( new i = 0; i < g_total_top[g_menu_type[client]]; i++ )
	{
		formatex(item, sizeof(item) - 1, "\y%i \w%s\R\y%.1f", i + 1, g_top_name[g_menu_type[client]][i], g_top_distance[g_menu_type[client]][i]);
		num_to_str(i, info, sizeof(info) - 1);
		
		menu_additem(menu, item, info);
	}
	
	menu_display(client, menu);
}

public MenuTop(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu);
		menu_display(client, g_top_menu, g_menu_page[client]);
		return;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	new pos = str_to_num(info);
	if( pos == -1 )
	{
		#if MAX_TOP > MOTD_INTERVAL
		if( g_total_top[g_menu_type[client]] > MOTD_INTERVAL )
		{
			menu_destroy(menu);
			ShowMOTDMenu(client);
		}
		else
		{
			ShowMOTD(client, 0);
			menu_display(client, menu);
		}
		#else
		ShowMOTD(client, 0);
		menu_display(client, menu);
		#endif
		return;
	}
	
	console_print(client, "----------------------------------");
	console_print(client, "%s Stats [#%i]", g_jump_names[g_menu_type[client]], pos + 1);
	console_print(client, "Name: %s", g_top_name[g_menu_type[client]][pos]);
	if( g_top_direction[g_menu_type[client]][pos][0] != g_direction_names[DIR_FORWARDS][0]
	|| get_pcvar_num(cvar_direction_forwards) )
	{
		console_print(client, "Direction: %s", g_top_direction[g_menu_type[client]][pos]);
	}
	console_print(client, "Distance: %f", g_top_distance[g_menu_type[client]][pos]);
	console_print(client, "MaxSpeed: %f (%.3f)", g_top_maxspeed[g_menu_type[client]][pos], g_top_maxspeed[g_menu_type[client]][pos] - g_top_prestrafe[g_menu_type[client]][pos]);
	console_print(client, "PreStrafe: %f", g_top_prestrafe[g_menu_type[client]][pos]);
	console_print(client, "Strafes: %i", g_top_strafes[g_menu_type[client]][pos]);
	console_print(client, "Sync: %i%%%%", g_top_sync[g_menu_type[client]][pos]);
	console_print(client, "----------------------------------");
	
	client_print(client, print_chat, "[JUMPSTATS] Stats for %s #%i have been printed in your console.", g_jump_names[g_menu_type[client]], pos + 1);
	
	menu_display(client, menu, ++pos / 7);
}

#if MAX_TOP > MOTD_INTERVAL
ShowMOTDMenu(client)
{
	static item[64];
	formatex(item, sizeof(item) - 1, "%s MOTD Top", g_jump_names[g_menu_type[client]]);
	
	new menu = menu_create(item, "MenuMOTD");
	
	static last, info[4];
	for( new i = 0; i < g_total_top[g_menu_type[client]]; i += MOTD_INTERVAL )
	{
		last = min(i + MOTD_INTERVAL, g_total_top[g_menu_type[client]]);
		
		if( last > (i + 1) )
		{
			formatex(item, sizeof(item) - 1, "#%i \y-> \w#%i", (i + 1), last);
		}
		else
		{
			formatex(item, sizeof(item) - 1, "#%i", (i + 1));
		}
		
		num_to_str(i, info, sizeof(info) - 1);
		
		menu_additem(menu, item, info);
	}
	
	menu_display(client, menu);
}

public MenuMOTD(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu);
		ShowTopMenu(client);
		return;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	ShowMOTD(client, str_to_num(info));
	
	menu_display(client, menu);
}
#endif

ShowMOTD(client, start)
{
	new last = min(start + MOTD_INTERVAL, g_total_top[g_menu_type[client]]);
	
	static motd[2500], len;
	len = format(motd, sizeof(motd) - 1, 		"<body bgcolor=#A4BED6>");
	len += format(motd[len], sizeof(motd) - len - 1, "<table width=100%% cellpadding=2 cellspacing=0 border=0>");
	len += format(motd[len], sizeof(motd) - len - 1, "<tr align=center bgcolor=#52697B>");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=5%%>#");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=30%% align=left>Name");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=15%%>Distance");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=12%%>MaxSpeed");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=12%%>PreStrafe");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=9%%>Strafes");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=7%%>Sync");
	
	new bestMaxspeed, bestPreStrafe, bestStrafes, bestSync;
	for( new i = 0; i < g_total_top[g_menu_type[client]]; i++ )
	{
		if( g_top_maxspeed[g_menu_type[client]][i] > g_top_maxspeed[g_menu_type[client]][bestMaxspeed] )
		{
			bestMaxspeed = i;
		}
		
		if( g_top_prestrafe[g_menu_type[client]][i] > g_top_prestrafe[g_menu_type[client]][bestPreStrafe] )
		{
			bestPreStrafe = i;
		}
		
		if( g_top_strafes[g_menu_type[client]][i] > g_top_strafes[g_menu_type[client]][bestStrafes] )
		{
			bestStrafes = i;
		}
		
		if( g_top_sync[g_menu_type[client]][i] > g_top_sync[g_menu_type[client]][bestSync] )
		{
			bestSync = i;
		}
	}
	
	static name[128], dir;
	for( new i = start; i < last; i++ )
	{
		dir = DirectionNameToValue(g_top_direction[g_menu_type[client]][i]);
		
		len += format(motd[len], sizeof(motd) - len - 1, "<tr align=center>");
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td>%i", (i + 1));
		copy(name, sizeof(name) - 1, g_top_name[g_menu_type[client]][i]);
		MakeNameMOTDSafe(name, 15);
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td align=left>%s", name);
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td>%.1f%s", g_top_distance[g_menu_type[client]][i], g_direction_motd[dir]);
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td>%s%.1f", i == bestMaxspeed ? "<font color=^"#FF0000^">" : "", g_top_maxspeed[g_menu_type[client]][i]);
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td>%s%.1f", i == bestPreStrafe ? "<font color=^"#FF0000^">" : "", g_top_prestrafe[g_menu_type[client]][i]);
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td>%s%i", i == bestStrafes ? "<font color=^"#FF0000^">" : "", g_top_strafes[g_menu_type[client]][i]);
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td>%s%i%%", i == bestSync ? "<font color=^"#FF0000^">" : "", g_top_sync[g_menu_type[client]][i]);
	}
	
	len += format(motd[len], sizeof(motd) - len - 1, "</table>");
	len += format(motd[len], sizeof(motd) - len - 1, "</body>");
	
	static title[64];
	formatex(title, sizeof(title) - 1, "%s Top", g_jump_names[g_menu_type[client]]);
	
	show_motd(client, motd, title);
}

public MenuBestMain(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		ShowMainMenu(client);
		return;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	if( info[0] == '1' )
	{
		ShowBestViewMenu(client);
	}
	else
	{
		ShowBestResetMenu(client);
	}
}

ShowBestViewMenu(client)
{
	static title[128];
	formatex(title, sizeof(title) - 1, "Your Best Jumps^nChoose one to print stats to console");
	
	new menu = menu_create(title, "MenuBestView");
	
	menu_additem(menu, "\yMOTD", "-1");
	
	new bool:has_jumps = false;
	static item[64], info[4];
	for( new i = 0; i < JUMP_TYPES; i++ )
	{
		num_to_str(i, info, sizeof(info) - 1);
		
		if( g_best_exists[client][i] )
		{
			formatex(item, sizeof(item) - 1, "%s\R\y%.1f", g_jump_names[i], g_best_distance[client][i]);
			
			menu_additem(menu, item, info);
			
			has_jumps = true;
		}
		else
		{
			menu_additem(menu, g_jump_names[i], info, _, menu_makecallback("CallbackDisabled"));
		}
	}
	
	if( has_jumps )
	{
		menu_display(client, menu);
	}
	else
	{
		menu_destroy(menu);
		
		client_print(client, print_chat, "[JUMPSTATS] You do not have any jumps!");
		ShowMainMenu(client);
	}
}

public CallbackDisabled(client, menu, item)
{
	return ITEM_DISABLED;
}

public MenuBestView(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu);
		menu_display(client, g_best_main_menu);
		return;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	
	new type = str_to_num(info);
	if( type == -1 )
	{
		ShowMOTDBest(client);
		menu_display(client, menu);
		return;
	}
	
	console_print(client, "----------------------------------");
	console_print(client, "%s Stats", g_jump_names[type]);
	if( g_best_direction[client][type][0] != g_direction_names[DIR_FORWARDS][0]
	|| get_pcvar_num(cvar_direction_forwards) )
	{
		console_print(client, "Direction: %s", g_best_direction[client][type]);
	}
	console_print(client, "Distance: %f", g_best_distance[client][type]);
	console_print(client, "MaxSpeed: %f (%.3f)", g_best_maxspeed[client][type], g_best_maxspeed[client][type] - g_best_prestrafe[client][type]);
	console_print(client, "PreStrafe: %f", g_best_prestrafe[client][type]);
	console_print(client, "Strafes: %i", g_best_strafes[client][type]);
	console_print(client, "Sync: %i%%%%", g_best_sync[client][type]);
	console_print(client, "----------------------------------");
	
	client_print(client, print_chat, "[JUMPSTATS] Stats for your %s have been printed in your console.", g_jump_names[type]);
	
	menu_display(client, menu, ++type / 7);
}

ShowMOTDBest(client)
{
	static motd[2500], len;
	len = format(motd, sizeof(motd) - 1, 		"<body bgcolor=#A4BED6>");
	len += format(motd[len], sizeof(motd) - len - 1, "<table width=100%% cellpadding=2 cellspacing=0 border=0>");
	len += format(motd[len], sizeof(motd) - len - 1, "<tr align=center bgcolor=#52697B>");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=30%% align=left>Jump Type");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=15%%>Distance");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=12%%>MaxSpeed");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=12%%>PreStrafe");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=9%%>Strafes");
	len += format(motd[len], sizeof(motd) - len - 1, "<th width=7%%>Sync");
	
	for( new i = 0; i < JUMP_TYPES; i++ )
	{
		if( !g_best_exists[client][i] )
		{
			//len += format(motd[len], sizeof(motd) - len - 1, "<tr>");
			continue;
		}
		
		len += format(motd[len], sizeof(motd) - len - 1, "<tr align=center>");
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td align=left>%s", g_jump_names[i]);
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td>%.1f", g_best_distance[client][i]);
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td>%.1f", g_best_maxspeed[client][i]);
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td>%.1f", g_best_prestrafe[client][i]);
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td>%i", g_best_strafes[client][i]);
		len += format(motd[len], sizeof(motd) - len - 1, 	"<td>%i%%", g_best_sync[client][i]);
	}
	
	len += format(motd[len], sizeof(motd) - len - 1, "</table>");
	len += format(motd[len], sizeof(motd) - len - 1, "</body>");
	
	show_motd(client, motd, "Your Best Jumps");
}

ShowBestResetMenu(client)
{
	static title[128];
	formatex(title, sizeof(title) - 1, "Your Best Jumps^nChoose one to reset", g_jump_names[g_menu_type[client]]);
	
	new menu = menu_create(title, "MenuBestReset");
	
	menu_additem(menu, "\yReset All", "-1");
	
	new bool:has_jumps = false;
	static item[64], info[4];
	for( new i = 0; i < JUMP_TYPES; i++ )
	{
		num_to_str(i, info, sizeof(info) - 1);
		
		if( g_best_exists[client][i] )
		{
			formatex(item, sizeof(item) - 1, "%s\R\y%.1f", g_jump_names[i], g_best_distance[client][i]);
			
			menu_additem(menu, item, info);
			
			has_jumps = true;
		}
		else
		{
			menu_additem(menu, g_jump_names[i], info, _, menu_makecallback("CallbackDisabled"));
		}
	}
	
	if( has_jumps )
	{
		menu_display(client, menu);
	}
	else
	{
		menu_destroy(menu);
		
		client_print(client, print_chat, "[JUMPSTATS] You do not have any jumps!");
		ShowMainMenu(client);
	}
}

public MenuBestReset(client, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu);
		menu_display(client, g_best_main_menu);
		return;
	}
	
	static _access, info[4], callback;
	menu_item_getinfo(menu, item, _access, info, sizeof(info) - 1, _, _, callback);
	menu_destroy(menu);
	
	new type = str_to_num(info);
	
	DeleteBest(client, type);
	
	if( type == -1 )
	{
		client_print(client, print_chat, "[JUMPSTATS] You have reset all of your personal best jump records!");
		
		ShowMainMenu(client);
	}
	else
	{
		client_print(client, print_chat, "[JUMPSTATS] You have reset our personal best jump record for %s!", g_jump_names[type]);
		
		new bool:has_jumps = false;
		for( new i = 0; i < JUMP_TYPES; i++ )
		{
			if( g_best_exists[client][i] )
			{
				has_jumps = true;
				break;
			}
		}
		
		if( has_jumps )
		{
			ShowBestResetMenu(client);
		}
		else
		{
			ShowMainMenu(client);
		}
	}
}

LoadTops(type)
{
	if( !file_exists(g_jump_filenames[type]) ) return;
	
	new f = fopen(g_jump_filenames[type], "rt");
	
	static data[128];
	static distance[16];
	static prestrafe[16];
	static maxspeed[16];
	static strafes[4];
	static sync[4];
	
	while( !feof(f) && g_total_top[type] < MAX_TOP )
	{
		fgets(f, data, sizeof(data) - 1);
		if( !data[0] ) continue;
		
		parse(data,\
			g_top_steamid[type][g_total_top[type]], sizeof(g_top_steamid[][]) - 1,\
			g_top_name[type][g_total_top[type]], sizeof(g_top_name[][]) - 1,\
			g_top_direction[type][g_total_top[type]], sizeof(g_top_direction[][]) - 1,\
			distance, sizeof(distance) - 1,\
			prestrafe, sizeof(prestrafe) - 1,\
			maxspeed, sizeof(maxspeed) - 1,\
			strafes, sizeof(strafes) - 1,\
			sync, sizeof(sync) - 1
			);
		
		g_top_distance[type][g_total_top[type]] = str_to_float(distance);
		g_top_prestrafe[type][g_total_top[type]] = str_to_float(prestrafe);
		g_top_maxspeed[type][g_total_top[type]] = str_to_float(maxspeed);
		g_top_strafes[type][g_total_top[type]] = str_to_num(strafes);
		g_top_sync[type][g_total_top[type]] = str_to_num(sync);
		
		g_total_top[type]++;
	}
	
	fclose(f);
}

SaveTops(type)
{
	new f = fopen(g_jump_filenames[type], "wt");
	
	for( new i = 0; i < g_total_top[type]; i++ )
	{
		fprintf(f, "^"%s^" ^"%s^" ^"%s^" ^"%f^" ^"%f^" ^"%f^" %i %i^n",\
			g_top_steamid[type][i],\
			g_top_name[type][i],\
			g_top_direction[type][i],\
			g_top_distance[type][i],\
			g_top_prestrafe[type][i],\
			g_top_maxspeed[type][i],\
			g_top_strafes[type][i],\
			g_top_sync[type][i]
			);
	}
	
	fclose(f);
}

CheckTop(client, type, direction, Float:distance, Float:prestrafe, Float:maxspeed, strafes, sync)
{
	new pos = GetTopPos(client, type);
	
	if( pos == -1 )
	{
		new newpos = -1;
		
		for( new i = 0; i < MAX_TOP; i++ )
		{
			if( g_top_distance[type][i] < distance )
			{
				newpos = i;
				break;
			}
		}
		
		if( newpos == -1 ) return 0;
		
		static steamid[35], name[32];
		get_user_authid(client, steamid, sizeof(steamid) - 1);
		get_user_name(client, name, sizeof(name) - 1);
		
		for( new i = MAX_TOP - 1; i > newpos; i-- )
		{
			copy(g_top_steamid[type][i], sizeof(g_top_steamid[][]) - 1, g_top_steamid[type][i - 1]);
			copy(g_top_name[type][i], sizeof(g_top_name[][]) - 1, g_top_name[type][i - 1]);
			copy(g_top_direction[type][i], sizeof(g_top_direction[][]) - 1, g_top_direction[type][i - 1]);
			g_top_distance[type][i] = g_top_distance[type][i - 1];
			g_top_prestrafe[type][i] = g_top_prestrafe[type][i - 1];
			g_top_maxspeed[type][i] = g_top_maxspeed[type][i - 1];
			g_top_strafes[type][i] = g_top_strafes[type][i - 1];
			g_top_sync[type][i] = g_top_sync[type][i - 1];
		}
		
		copy(g_top_steamid[type][newpos], sizeof(g_top_steamid[][]) - 1, steamid);
		copy(g_top_name[type][newpos], sizeof(g_top_name[][]) - 1, name);
		copy(g_top_direction[type][newpos], sizeof(g_top_direction[][]) - 1, g_direction_names[direction]);
		g_top_distance[type][newpos] = distance;
		g_top_prestrafe[type][newpos] = prestrafe;
		g_top_maxspeed[type][newpos] = maxspeed;
		g_top_strafes[type][newpos] = strafes;
		g_top_sync[type][newpos] = sync;
		
		if( g_total_top[type] < MAX_TOP )
		{
			g_total_top[type]++;
		}
		
		SaveTops(type);
		
		return newpos + 1;
	}
	else
	{
		if( g_top_distance[type][pos] > distance ) return 0;
		
		new newpos = -1;
		for( new i = 0; i < MAX_TOP; i++ )
		{
			if( g_top_distance[type][i] < distance )
			{
				newpos = i;
				break;
			}
		}
		
		for( new i = pos; i > newpos; i-- )
		{
			copy(g_top_steamid[type][i], sizeof(g_top_steamid[][]) - 1, g_top_steamid[type][i - 1]);
			copy(g_top_name[type][i], sizeof(g_top_name[][]) - 1, g_top_name[type][i - 1]);
			copy(g_top_direction[type][i], sizeof(g_top_direction[][]) - 1, g_top_direction[type][i - 1]);
			g_top_distance[type][i] = g_top_distance[type][i - 1];
			g_top_prestrafe[type][i] = g_top_prestrafe[type][i - 1];
			g_top_maxspeed[type][i] = g_top_maxspeed[type][i - 1];
			g_top_strafes[type][i] = g_top_strafes[type][i - 1];
			g_top_sync[type][i] = g_top_sync[type][i - 1];
		}
		
		static steamid[35], name[32];
		get_user_authid(client, steamid, sizeof(steamid) - 1);
		get_user_name(client, name, sizeof(name) - 1);
		
		copy(g_top_steamid[type][newpos], sizeof(g_top_steamid[][]) - 1, steamid);
		copy(g_top_name[type][newpos], sizeof(g_top_name[][]) - 1, name);
		copy(g_top_direction[type][newpos], sizeof(g_top_direction[][]) - 1, g_direction_names[direction]);
		g_top_distance[type][newpos] = distance;
		g_top_prestrafe[type][newpos] = prestrafe;
		g_top_maxspeed[type][newpos] = maxspeed;
		g_top_strafes[type][newpos] = strafes;
		g_top_sync[type][newpos] = sync;
		
		SaveTops(type);
		
		return newpos + 1;
	}
	
	return 0;
}

GetTopPos(client, type)
{
	if( !g_total_top[type] ) return -1;
	
	static authid[35];
	get_user_authid(client, authid, sizeof(authid) - 1);
	
	for( new i = 0; i < g_total_top[type]; i++ )
	{
		if( !strcmp(authid, g_top_steamid[type][i], 1) )
		{
			return i;
		}
	}
	
	return -1;
}

LoadBest(client)
{
	static authid[35];
	get_user_authid(client, authid, sizeof(authid) - 1);
	
	static key[40], data[128];
	static distance[16], prestrafe[16], maxspeed[16], strafes[4], sync[4];
	for( new i = 0; i < JUMP_TYPES; i++ )
	{
		formatex(key, sizeof(key) - 1, "%s_%s", authid, g_jump_prefixes[i]);
		
		if( (g_best_exists[client][i] = bool:fvault_get_data(g_best_vault, key, data, sizeof(data) - 1)) )
		{
			parse(data,\
				g_best_direction[client][i], sizeof(g_best_direction[][]) - 1,\
				distance, sizeof(distance) - 1,\
				prestrafe, sizeof(prestrafe) - 1,\
				maxspeed, sizeof(maxspeed) - 1,\
				strafes, sizeof(strafes) - 1,\
				sync, sizeof(sync) - 1
				);
			
			g_best_distance[client][i] = str_to_float(distance);
			g_best_prestrafe[client][i] = str_to_float(prestrafe);
			g_best_maxspeed[client][i] = str_to_float(maxspeed);
			g_best_strafes[client][i] = str_to_num(strafes);
			g_best_sync[client][i] = str_to_num(sync);
		}
	}
}

DeleteBest(client, jump_type)
{
	if( client )
	{
		static authid[35], key[40];
		get_user_authid(client, authid, sizeof(authid) - 1);
		
		if( jump_type == -1 )
		{
			for( new i = 0; i < JUMP_TYPES; i++ )
			{
				formatex(key, sizeof(key) - 1, "%s_%s", authid, g_jump_prefixes[i]);
				
				fvault_remove_key(g_best_vault, key);
				
				g_best_exists[client][i] = false;
			}
		}
		else
		{
			formatex(key, sizeof(key) - 1, "%s_%s", authid, g_jump_prefixes[jump_type]);
			
			fvault_remove_key(g_best_vault, key);
			
			g_best_exists[client][jump_type] = false;
		}
	}
	else
	{
		if( jump_type == -1 )
		{
			fvault_clear(g_best_vault);
			
			for( new c = 1; c <= g_max_clients; c++ )
			{
				for( new i = 0; i < JUMP_TYPES; i++ )
				{
					g_best_exists[c][i] = false;
				}
			}
		}
		else
		{
			// STEAM_0:X:XXXXX_JS
			// 123456789012345678
			// key[18] = \0
			// key[18 - len] = J
			
			static key[40];
			new len = strlen(g_jump_prefixes[jump_type]);
			
			new total = fvault_size(g_best_vault);
			for( new i = 0; i < total; i++ )
			{
				fvault_get_keyname(g_best_vault, i, key, sizeof(key) - 1);
				
				if( equal(key[strlen(key) - len], g_jump_prefixes[jump_type]) )
				{
					fvault_remove_key(g_best_vault, key);
					i--;
				}
			}
			
			for( new c = 1; c <= g_max_clients; c++ )
			{
				g_best_exists[c][jump_type] = false;
			}
		}
	}
}

SaveBest(client, jump_type)
{
	static key[40];
	get_user_authid(client, key, sizeof(key) - 1);
	
	format(key, sizeof(key) - 1, "%s_%s", key, g_jump_prefixes[jump_type]);
	
	static data[128];
	formatex(data, sizeof(data) - 1, "%s %f %f %f %i %i",\
		g_best_direction[client][jump_type],\
		g_best_distance[client][jump_type],\
		g_best_prestrafe[client][jump_type],\
		g_best_maxspeed[client][jump_type],\
		g_best_strafes[client][jump_type],\
		g_best_sync[client][jump_type]
		);
	
	fvault_set_data(g_best_vault, key, data);
}

CheckBest(client, jump_type, direction, Float:distance, Float:prestrafe, Float:maxspeed, strafes, sync)
{
	new new_best = 0;
	
	if( !g_best_exists[client][jump_type]
	|| g_best_distance[client][jump_type] < distance )
	{
		if( g_best_exists[client][jump_type] )
		{
			new_best = 1;
		}
		else
		{
			g_best_exists[client][jump_type] = true;
		}
		
		copy(g_best_direction[client][jump_type], sizeof(g_best_direction[][]) - 1, g_direction_names[direction]);
		g_best_distance[client][jump_type] = distance;
		g_best_prestrafe[client][jump_type] = prestrafe;
		g_best_maxspeed[client][jump_type] = maxspeed;
		g_best_strafes[client][jump_type] = strafes;
		g_best_sync[client][jump_type] = sync;
		
		SaveBest(client, jump_type);
	}
	
	return new_best;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
