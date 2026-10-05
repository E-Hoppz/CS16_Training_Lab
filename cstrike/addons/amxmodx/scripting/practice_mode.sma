#include <amxmodx>
#include <amxmisc>
#include <reapi>

#define PLUGIN "FROGHOUSE Practice Mode"
#define VERSION "1.0"
#define AUTHOR "E-Hoppz"

#if !defined DAMAGE_NO
#define DAMAGE_NO 0.0
#endif
#if !defined DAMAGE_AIM
#define DAMAGE_AIM 2.0
#endif

new g_pCvarPractice;
new Float:g_vecOrigin[33][3];
new Float:g_vecAngles[33][3];
new Float:g_vecVelocity[33][3];
new bool:g_bHasCheckpoint[33];

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    g_pCvarPractice = register_cvar("amx_practice", "1");

    register_clcmd("say /sp", "Cmd_SavePos");
    register_clcmd("say_team /sp", "Cmd_SavePos");
    register_clcmd("say /tp", "Cmd_Teleport");
    register_clcmd("say_team /tp", "Cmd_Teleport");
    register_clcmd("say /noclip", "Cmd_Noclip");
    register_clcmd("say_team /noclip", "Cmd_Noclip");
    register_clcmd("say /god", "Cmd_Godmode");
    register_clcmd("say_team /god", "Cmd_Godmode");

    register_event("CurWeapon", "Event_CurWeapon", "be", "1=1");
    RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", 1);
}

public client_disconnected(id)
{
    g_bHasCheckpoint[id] = false;
}

public Cmd_SavePos(const id)
{
    if (!get_pcvar_num(g_pCvarPractice) || !is_user_alive(id))
        return PLUGIN_HANDLED;

    get_entvar(id, var_origin, g_vecOrigin[id]);
    get_entvar(id, var_v_angle, g_vecAngles[id]);
    get_entvar(id, var_velocity, g_vecVelocity[id]);
    g_bHasCheckpoint[id] = true;

    client_print_color(id, print_team_default, "^4[Practice]^1 Checkpoint ^2saved^1!");
    return PLUGIN_HANDLED;
}

public Cmd_Teleport(const id)
{
    if (!get_pcvar_num(g_pCvarPractice) || !is_user_alive(id))
        return PLUGIN_HANDLED;

    if (!g_bHasCheckpoint[id])
    {
        client_print_color(id, print_team_default, "^4[Practice]^1 No checkpoint saved. Use ^3/sp^1 first.");
        return PLUGIN_HANDLED;
    }

    set_entvar(id, var_origin, g_vecOrigin[id]);
    set_entvar(id, var_angles, g_vecAngles[id]);
    set_entvar(id, var_v_angle, g_vecAngles[id]);
    set_entvar(id, var_fixangle, 1);
    set_entvar(id, var_velocity, g_vecVelocity[id]);

    client_print_color(id, print_team_default, "^4[Practice]^1 Teleported to checkpoint.");
    return PLUGIN_HANDLED;
}

public Cmd_Noclip(const id)
{
    if (!get_pcvar_num(g_pCvarPractice) || !is_user_alive(id))
        return PLUGIN_HANDLED;

    new iMoveType = get_entvar(id, var_movetype);
    if (iMoveType == MOVETYPE_NOCLIP)
    {
        set_entvar(id, var_movetype, MOVETYPE_WALK);
        client_print_color(id, print_team_default, "^4[Practice]^1 Noclip: ^3OFF");
    }
    else
    {
        set_entvar(id, var_movetype, MOVETYPE_NOCLIP);
        client_print_color(id, print_team_default, "^4[Practice]^1 Noclip: ^2ON");
    }
    return PLUGIN_HANDLED;
}

public Cmd_Godmode(const id)
{
    if (!get_pcvar_num(g_pCvarPractice) || !is_user_alive(id))
        return PLUGIN_HANDLED;

    new Float:flTakeDamage;
    get_entvar(id, var_takedamage, flTakeDamage);

    if (flTakeDamage == DAMAGE_NO)
    {
        set_entvar(id, var_takedamage, DAMAGE_AIM);
        client_print_color(id, print_team_default, "^4[Practice]^1 Godmode: ^3OFF");
    }
    else
    {
        set_entvar(id, var_takedamage, DAMAGE_NO);
        client_print_color(id, print_team_default, "^4[Practice]^1 Godmode: ^2ON");
    }
    return PLUGIN_HANDLED;
}

public Event_CurWeapon(const id)
{
    if (!get_pcvar_num(g_pCvarPractice) || !is_user_alive(id))
        return;

    new iItem = get_member(id, m_pActiveItem);
    if (is_entity(iItem))
    {
        set_member(iItem, m_Weapon_iClip, 100);
    }
}

public CBasePlayer_Killed_Post(const id, const iAttacker, const iGib)
{
    if (!get_pcvar_num(g_pCvarPractice))
        return;

    set_task(0.1, "Task_InstantRespawn", id);
}

public Task_InstantRespawn(const id)
{
    if (!is_user_connected(id) || is_user_alive(id))
        return;

    rg_round_respawn(id);

    if (g_bHasCheckpoint[id])
    {
        set_task(0.05, "Task_RestoreCheckpoint", id);
    }
}

public Task_RestoreCheckpoint(const id)
{
    if (!is_user_alive(id))
        return;

    new Float:vecZero[3];
    set_entvar(id, var_origin, g_vecOrigin[id]);
    set_entvar(id, var_angles, g_vecAngles[id]);
    set_entvar(id, var_v_angle, g_vecAngles[id]);
    set_entvar(id, var_fixangle, 1);
    set_entvar(id, var_velocity, vecZero);
}
