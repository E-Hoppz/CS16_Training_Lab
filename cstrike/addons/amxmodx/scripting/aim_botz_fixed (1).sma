/*
*	PLUGIN NAME 	: AimBotz Training (Modified for CS 1.6 Training Lab)
*	VERSION		: v1.0 (modified)
*	ORIGINAL AUTHOR	: Alghtryer (https://github.com/alghtryer/aimbotz)
*
*  	Original Copyright (C) 2018, Alghtryer <alghtryer.github.io>
*
*  	This program is free software; you can redistribute it and/or
*  	modify it under the terms of the GNU General Public License
*  	as published by the Free Software Foundation; either version 2
*  	of the License, or (at your option) any later version.
*
*  	This program is distributed in the hope that it will be useful,
*  	but WITHOUT ANY WARRANTY; without even the implied warranty of
*  	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  	GNU General Public License for more details.
*
*  	You should have received a copy of the GNU General Public License
*  	along with this program; if not, write to the Free Software
* 	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*  	
*	Original credits (features retained in this modified version):
*
*		Blizzard	: Frags Counter
*		Alka		: StopWatch
*		ConnorMcLeod	: Unlimited Ammo
*		uLLeticaL and Cha : AimBotz map (unmodified, map itself untouched)
*
*	Modifications in this version:
*		- Removed global "chooseteam"/"jointeam" hijack that broke team
*		  selection on every map, not just aim_botz (fixed a hard crash)
*		- Scoped bot-forcing and objective-entity removal to only run on
*		  the aim_botz map, instead of every map load
*		- Replaced the native CS bot system (bot_quota/bot_join_team) with
*		  YaPB, removing the dependency on Arkashine's CSBotEnabler
*		  (https://github.com/Arkshine/CSBotEnabler), which is no longer
*		  required or used by this version
*
*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <hamsandwich>
#include <fakemeta> 
#include <cstrike>

new PLUGIN[] = "AimBotz Training";
new AUTHOR[] = "Alghtryer";
new VERSION[] = "1.0";

enum 
{ 
    CurWeapon_IsActive = 1, // byte 
    CurWeapon_WeaponID, // byte 
    CurWeapon_ClipAmmo // byte 
} 

const XO_CBASEPLAYERWEAPON = 4 
const m_iClip = 51 
const m_iClientClip = 52 

const m_pActiveItem = 373 

new const g_iMaxClip[CSW_P90+1] = { 
    -1,  13, -1, 10,  1,  7,    1, 30, 30,  1,  30,  
        20, 25, 30, 35, 25,   12, 20, 10, 30, 100,  
        8 , 30, 30, 20,  2,    7, 30, 30, -1,  50 
} 

new const g_objective_ents[][] = {
	"func_bomb_target",
	"info_bomb_target",
	"hostage_entity",
	"monster_scientist",
	"func_hostage_rescue",
	"info_hostage_rescue",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone"
};

#define fm_create_entity(%1) engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, %1))

new const g_szClassname[] = "_task";

new bool:g_bStarted[33];
new Float:g_fStart[33];

new g_iMaxPlayers;

new g_iFrags[ 33 ];

public plugin_init() {

	register_plugin
	(
		PLUGIN,		//: AimBotz Training
		VERSION,	//: 1.0
		AUTHOR		//: Alghtryer <alghtryer.github.io>
	);
	
	
	register_cvar( "AimBotz", VERSION, FCVAR_SERVER | FCVAR_SPONLY);

	RegisterHam(Ham_Killed, "player", "PlayerKilled", 1); 
	register_event( "DeathMsg", "Event_DeathMsg", "a" );
	register_message(get_user_msgid("CurWeapon"), "Message_CurWeapon")
	register_forward(FM_Think, "fwd_Think", 0);
	
	register_clcmd("say /start", "clcmdStartTimer", -1, "");
	register_clcmd("say /stop", "clcmdResetTimer", -1, "");
	// Removed: chooseteam/jointeam hijack — this broke team selection on every map,
	// not just aim_botz. say /start and say /stop already do the same job safely.
	
	g_iMaxPlayers = get_maxplayers();
	
	create_fake_timer();
	set_task( 0.9, "Press_M", 0, _, _, "b" );

}
new const g_szTrainingMaps[][] = {
	"aim_botz",
	"aimbotzbycha"
	// Add more map names here as you bring in new variants
};

IsTrainingMap(const szMapName[]) {
	for (new i = 0; i < sizeof g_szTrainingMaps; i++) {
		if (equal(szMapName, g_szTrainingMaps[i]))
			return true;
	}
	return false;
}

public plugin_precache() {
	new szMapName[32];
	get_mapname(szMapName, charsmax(szMapName));

	// Modernized: drives bots through YaPB instead of the native CS bot system.
	// No longer needs CSBotEnabler, ham_register_cz_bots.sma, or BotProfile/BotChatter.db.
	if (IsTrainingMap(szMapName)) {
		server_cmd("mp_autoteambalance 0");
		server_cmd("mp_limitteams 0");
		server_cmd("humans_join_team T");
		server_cmd("mp_freezetime 0");

		// Fill CT side with YaPB bots (adjust the loop count to taste)
		for (new i = 0; i < 16; i++) {
			server_cmd("yb add");
		}

		for (new i = 0; i < sizeof g_objective_ents; ++i) {
			RemoveEntity(g_objective_ents[i]);
		}

		server_cmd("sv_restartround 1");
	}
}
public handled(id) { 
	if ( cs_get_user_team(id) == CS_TEAM_UNASSIGNED ) 
		return PLUGIN_CONTINUE;

	if(g_bStarted[id])
		clcmdResetTimer(id)
	else
		clcmdStartTimer(id); 

	return PLUGIN_HANDLED; 
}
public Press_M() {
	set_hudmessage(255, 255, 255, 0.01, 0.18, 0, 0.0, 1.0, 0.0, 0.0, -1 );
	show_hudmessage(0, "Press M for start/stop Stopwatch and Frag counter!!!");
}
public PlayerKilled(Victim){
	if (!is_user_alive(Victim))
		set_task(1.0, "PlayerRespawn", Victim);
}
public PlayerRespawn(id){
	if (!is_user_alive(id) && CS_TEAM_T <= cs_get_user_team(id) <= CS_TEAM_CT )
	{
		ExecuteHamB(Ham_CS_RoundRespawn, id);
	}
}
public cz_bot_ham_registerable( id ) 
{ 
	RegisterHamFromEntity(Ham_Killed, id, "PlayerKilled") 
}  
public client_disconnect(id){
	remove_task(id);
	return PLUGIN_HANDLED;
}
public Message_CurWeapon(iMsgId, iMsgDest, id) 
{ 
    if( get_msg_arg_int(CurWeapon_IsActive) ) 
    { 
        new iMaxClip = g_iMaxClip[  get_msg_arg_int( CurWeapon_WeaponID )  ] 
        if( iMaxClip > 2 && get_msg_arg_int(CurWeapon_ClipAmmo) < iMaxClip ) 
        { 
            // Fixed: previously used raw pdata offsets (m_iClip/m_iClientClip/m_pActiveItem)
            // hardcoded for stock mp.dll — these don't match ReGameDLL's memory layout and
            // caused a hard crash on every weapon switch. cs_set_weapon_ammo is the safe,
            // version-independent equivalent from the cstrike module.
            cs_set_weapon_ammo(id, iMaxClip);
            set_msg_arg_int(CurWeapon_ClipAmmo, ARG_BYTE, iMaxClip) 
        } 
    } 
} 

public create_fake_timer()
{
	new iEnt = fm_create_entity("info_target");
	set_pev(iEnt,pev_classname, g_szClassname);
	set_pev(iEnt, pev_nextthink, get_gametime() + 1.0);
}

public clcmdStartTimer(id)
{
	if(!g_bStarted[id])
		g_bStarted[id] = true;
		
	g_fStart[id] = get_gametime();
}

public clcmdResetTimer(id)
{
	new iBotCount = 0;
	for (new i = 1; i <= g_iMaxPlayers; i++) {
		if (is_user_connected(i) && is_user_bot(i))
			iBotCount++;
	}

	ClientPrintColor(id, "!tMake !g%d !tkills for  !g%.1f !tsec with !g%d !tbot.",g_iFrags[ id ], get_gametime() - g_fStart[id], iBotCount)
	set_hudmessage(255, 255, 255, -1.0, -1.0, 0, 6.0, 12.0)
	show_hudmessage(id, "%d kills ^nTime: %.1f ^n %d bot", g_iFrags[ id ], get_gametime() - g_fStart[id], iBotCount);
	g_bStarted[id] = false;
	g_fStart[id] = 0.0;
	arrayset( g_iFrags, 0, sizeof( g_iFrags ) );
}

public fwd_Think(ent)
{
	if(!pev_valid(ent))
		return FMRES_IGNORED;
	
	static szClassname[32];
	pev(ent, pev_classname, szClassname, sizeof szClassname - 1);
	
	if(szClassname[0] != '_' && szClassname[1] != 't')
		return FMRES_IGNORED;
	
	for(new i = 1 ; i <= g_iMaxPlayers ; i++)
	{
		if(is_user_connected(i) && g_bStarted[i] && g_fStart[i] > 0.0)
		{
			set_hudmessage(255, 255, 255, -1.0, 0.8, 0, 6.0, 0.1, 0.1, 0.1, 1);
			show_hudmessage(i, "Time: %.1f sec. ^nKill: %d", (get_gametime() - g_fStart[i]), g_iFrags[ i ]);
		}
	}
	set_pev(ent, pev_nextthink, get_gametime() + 0.1);
	
	return FMRES_IGNORED;
}
public Event_DeathMsg( ) {
    	new iKiller = read_data( 1 );
    	new iVictim = read_data( 2 );
    
    	if( iVictim != iKiller ) {
		if(g_bStarted[iKiller])
		{
       		 	g_iFrags[ iKiller ]++; 
    		}	
	}
}
RemoveEntity( const szClassName[ ] ){
    new szFakeClassName[ 32 ];
    GetFakeClassName( szClassName, szFakeClassName, charsmax( szFakeClassName ) );
    
    new iEntity = -1;
    while( ( iEntity = find_ent_by_class( iEntity, szClassName ) ) )
    {
        entity_set_string( iEntity, EV_SZ_classname, szFakeClassName );
    }
}
GetFakeClassName( const szClassName[ ], szFakeClassName[ ], const iLen ){
    formatex( szFakeClassName, iLen, "___%s", szClassName );
}
ClientPrintColor( id, String[ ], any:... ){
	new szMsg[ 190 ];
	vformat( szMsg, charsmax( szMsg ), String, 3 );
	
	replace_all( szMsg, charsmax( szMsg ), "!n", "^1" );
	replace_all( szMsg, charsmax( szMsg ), "!t", "^3" );
	replace_all( szMsg, charsmax( szMsg ), "!g", "^4" );
	
	static msgSayText = 0;
	static fake_user;
	
	if( !msgSayText )
	{
		msgSayText = get_user_msgid( "SayText" );
		fake_user = get_maxplayers( ) + 1;
	}
	
	message_begin( id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgSayText, _, id );
	write_byte( id ? id : fake_user );
	write_string( szMsg );
	message_end( );
}