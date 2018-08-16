#if defined _ttt_included
    #endinput
#endif
#define _ttt_included

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(TTT_IsClientValid(%1))

#define TTT_PLUGIN_NAME "Trouble in Terrorist Town"
#define TTT_PLUGIN_AUTHOR "TTT-Contributors"
#define TTT_PLUGIN_DESCRIPTION "The game is about a group of \"terrorists\" who have traitors among them, out to kill everyone who's not a traitor."
#define TTT_PLUGIN_VERSION "<VERSION>"
#define TTT_PLUGIN_URL "https://github.com/Bara/TroubleinTerroristTown"

#define TTT_TEAM_UNASSIGNED (1 << 0)
#define TTT_TEAM_INNOCENT (1 << 1)
#define TTT_TEAM_TRAITOR (1 << 2)
#define TTT_TEAM_DETECTIVE (1 << 3)

#define ROLE_LENGTH 16
#define MAX_ITEM_LENGTH 64
#define TTT_LOG_SIZE 512

#include <autoexecconfig>

enum Ragdolls
{
    Ent,
    Victim,
    Attacker,
    VictimTeam,
    AttackerTeam,
    String:VictimName[MAX_NAME_LENGTH],
    String:AttackerName[MAX_NAME_LENGTH],
    bool:Scanned,
    Float:GameTime,
    String:Weaponused[32],
    bool:Found
}

enum KarmaUpdate
{
    Karma_Add,
    Karma_Set,
    Karma_Subtract
}

/**
 * Called before players roles are picked/assigned.
 * Return Plugin_Handled or higher to prevent round start.
 * You could slay players here to force them to sit out.
 */
forward Action TTT_OnRoundStart_Pre();

/**
 * Called when the actual TTT round starts (after selection time).
 *
 * @param innocents         Count of innocent players.
 * @param traitors          Count of traitor players.
 * @param detective         Count of detective players.
 */
forward void TTT_OnRoundStart(int innocents, int traitors, int detective);

/**
 * Called when round start is failed or prevented.
 *
 * @param players           The amount of players we have.
 *                          -1 if this round was prevented by
 *                          another plugin.
 * @param requiredPlayers   The amount of players we need.
 * @param detective         The amount needed for detective.
 */
forward void TTT_OnRoundStartFailed(int players, int requiredPlayers, int detective);

/**
 * Called when the actual TTT round ended.
 *
 * @param winner             The Winning Team.
 */
forward void TTT_OnRoundEnd(int winner);

/**
 * Called when a client's role is assigned.
 *
 * @param client            Client index.
 * @param role              Role.
 */
forward void TTT_OnClientGetRole(int client, int role);

/**
 * Called when a client dies, after Karma process
 *
 * @param victim            Person who died.
 * @param attacker          Attacker.
 */
forward void TTT_OnClientDeath(int victim, int attacker);

/**
 * Called when a client dies, before Karma process
 *
 * @param victim            Person who died.
 * @param attacker          Attacker.
 */
forward Action TTT_OnClientDeathPre(int victim, int attacker);

/**
 * Called when a body is found.
 *
 * @param client            The client who identified the body.
 * @param victim            The client whom the body belongs to. (-1 for invalid index)
 * @param deadPlayer        The name of the victim.
 * @param silentID          True if body was silenced id and false if normal inspect
 */
forward void TTT_OnBodyFound(int client, int victim, const char[] deadPlayer, bool silentID);

/**
 * Called before we create rules menu.
 * If want to change it use "return Plugin_Changed;"
 *
 * @param client            The client index.
 * @param show              True - Menu will be opened, False - Menu will not open
 */
forward Action TTT_OnRulesMenu(int client, bool &show);

/**
 * Called before we create detectives menu.
 * If want to change it use "return Plugin_Changed;"
 *
 * @param client            The client index.
 * @param show              True - Menu will be opened, False - Menu will not open
 */
forward Action TTT_OnDetectiveMenu(int client, bool &show);

/**
 * Called before a body will be scanned.
 *
 * @param client            The client who scanned the body.
 * @param ragdoll           The Array with Ragdoll informations (by reference).
 */
forward Action TTT_OnBodyCheck(int client, int[] ragdoll);

/**
 * Called on updated player models
 * (if ttt_update_client_model is true)
 *
 * @param client            The client index after updated model
 * @param model             Path of current model
 */
forward void TTT_OnModelUpdate(int client, const char[] model);

/**
 * Called after TTT_RespawnPlayer execute
 *
 * @param client            The client index
 */
forward void TTT_OnPlayerRespawn(int client);

forward int TTT_OnButtonPress(int client, int button);
forward int TTT_OnButtonRelease(int client, int button);

/**
 * Called before RDM will be handled.
 *
 * @param victim            Person who died.
 * @param attacker          Attacker.
 */
forward Action TTT_OnPlayerDeath(int victim, int attacker);

/**
 * Called once Karma has been updated on a client.
 *
 * @param client            Client index.
 * @param type              Type of update. (Enum above)
 * @param karma              Amount of Karma.
 */
forward void TTT_OnKarmaUpdate(int client, KarmaUpdate type, int karma);

/**
 * This forward will be called when a client hasn't access to command (TTT_CheckCommandAccess)
 * It's possible to give a client access to an not accessible command
 * You must use 'return Plugin_Changed;' if you want to change the bool 'access'
 */
forward bool TTT_OnCheckCommandAccess(int client, const char[] command, const char[] flags, bool access);







/**
 * Checks if the round is active.
 */
native bool TTT_IsRoundActive();

/**
 * Retrieve a client's role.
 *
 * @param client            Client index.
 */
native int TTT_GetClientRole(int client);

/**
 * Retrieve a client's karma.
 *
 * @param client            Client index.
 */
native int TTT_GetClientKarma(int client, bool publicKarma = true);

/**
 * Retrieve the Radgoll Info.
 *
 * @param client            The victims index.
 * @param radgoll           The array to save the ragoll infos.
 */
native bool TTT_GetClientRagdoll(int victim, int[] ragdoll);

/**
 * Retrieve the client index.
 *
 * @param ragdoll           The ragdoll index.
 * @return                  The client index
 */
native int TTT_GetClientByRagdollID(int ragdoll);

/**
 * Push a ragdoll to the global Ragdoll array (will get cleaned on Round Start).
 *
 * @param radgoll           The array to save as Ragdoll.
 */
native int TTT_SetRagdoll(int[] ragdoll);

/**
 * Set a client's role.
 *
 * @param client            Client index.
 * @param role              The new role.
 */
native int TTT_SetClientRole(int client, int role);

/**
 * Sets the karma of a client.
 *
 * @param client            Client index.
 * @param karma             Karma for the client.
 */
native int TTT_SetClientKarma(int client, int karma, bool force);

/**
 * Add karma to a client (currentKarma+karma).
 *
 * @param client            Client index.
 * @param karma             Karma that will be added.
 */
native int TTT_AddClientKarma(int client, int karma, bool force);

/**
 * Remove karma from a client (currentKarma-karma).
 *
 * @param client            Client index.
 * @param karma             Karma to remove.
 */
native int TTT_RemoveClientKarma(int client, int karma, bool force);

/**
 * Determins whether a player's body was found (if dead).
 *
 * @param client            Client index.
 */
native bool TTT_WasBodyFound(int client);

/**
 * Determins whether a player's body was scanned (if dead).
 *
 * @param client            Client index.
 */
native bool TTT_WasBodyScanned(int client);

/**
 * Determines if a player is dead and has had their body found.
 *
 * @param client              The client index to lookup.
 */
native bool TTT_GetFoundStatus(int client);

/**
 * Set whether a player appears dead and body found.
 *
 * @param client             The client index to change.
 * @param found             True if found & dead, false else.
 */
native void TTT_SetFoundStatus(int client, bool found);

/**
 * Log a String to the ingame Log.
 *
 * @param string            The message that should get logged.
 */
native void TTT_LogString(const char[] format, any ...);

/**
 * Force a player to be traitor next round. (If there are enough Traitors)
 *
 * @param client             The client index to change.
 * @return False if the client's role already forced for the next round.
 */
native bool TTT_ForceTraitor(int client);

/**
 * Force a player to be detective next round. (If there are enough Detectives)
 *
 * @param client             The client index to change.
 * @return False if the client's role is already forced for the next round.
 */
native bool TTT_ForceDetective(int client);

/**
 * NO DESCRIPTION
 *
 * @param client             The client index.
 * @param rounds             The amount of rounds to add.
 * @param force             Begin directly if client is alive.
 * @return Returns the amount of rounds, otherwise the client index is invalid
 */
native int TTT_AddRoundSlays(int client, int rounds, bool force);

/**
 * NO DESCRIPTION
 *
 * @param client             The client index.
 * @param rounds             The amount of rounds.
 * @param force             Begin directly if client is alive.
 * @return Returns the amount of rounds, otherwise the client index is invalid
 */
native int TTT_SetRoundSlays(int client, int rounds, bool force);

/**
 * Open rules menu for the client
 *
 * @param client            The client index.
 */
native void TTT_ClientOpenRules(int client);

/**
 * Returns the time of a active rounds (-1 for inactive round/failed to start)
 *
 * @param type                Which type is needed? (0 - Time, 1 - Minutes, 2 - Seconds)
 */
native void TTT_GetRoundTime(int type);

/**
 * Returns whether a client has access to a given command string.  The string 
 * can be any override string, as overrides can be independent of 
 * commands.  This feature essentially allows you to create custom 
 * flags using the override system.
 *
 * @param client        Client index.
 * @param command        Command name.  If the command is not found, the default 
 *                        flags are used.
 * @param cvar            Flag convar to use as a default, if the command or override 
 *                        is not found.
 * @param override_only    If true, SourceMod will not attempt to find a matching 
 *                        command, and it will only use the default flags specified.
 *                        Otherwise, SourceMod will ignore the default flags if 
 *                        there is a matching admin command.
 * @return                True if the client has access, false otherwise.
 *
 * THIS TEXT WAS COPIED FROM HERE: https://github.com/alliedmodders/sourcemod/blob/6c7e29cbdbe1fe17982a4531d839be65116abca2/plugins/include/console.inc#L479
 */
native bool TTT_CheckCommandAccess(int client, const char[] command, ConVar cvar, bool override_only = false);

/**
 * Respawns a player.
 *
 * @param client        Client Index
 * @noreturn
 *
 */
native void TTT_RespawnPlayer(int client);

/**
 * Returns the timestamp where "round_prestart" was executed.
 *
 * @return                Returns the timestamp where "round_prestart" was executed.
 */
native int TTT_GetRoundTimestamp();

stock void TTT_GetRoleNameByID(int role, char[] name, int length = ROLE_LENGTH)
{
    if (role == TTT_TEAM_INNOCENT)
    {
        Format(name, length, "Innocent");
    }
    else if (role == TTT_TEAM_DETECTIVE)
    {
        Format(name, length, "Detective");
    }
    else if (role == TTT_TEAM_TRAITOR)
    {
        Format(name, length, "Traitor");
    }
    else
    {
        Format(name, length, "Unassigned");
    }
}

stock void TTT_GetRoleNameByShortName(const char[] shortName, char[] name, int length = ROLE_LENGTH)
{
    if (StrEqual(shortName, "inno", false))
    {
        Format(name, length, "Innocent");
    }
    else if (StrEqual(shortName, "dete", false))
    {
        Format(name, length, "Detective");
    }
    else if (StrEqual(shortName, "trai", false))
    {
        Format(name, length, "Traitor");
    }
    else
    {
        Format(name, length, "Unassigned");
    }
}

stock int TTT_GetRoleIDByName(const char[] name)
{
    if (StrEqual(name, "innocent", false))
    {
        return TTT_TEAM_INNOCENT;
    }
    else if (StrEqual(name, "detective", false))
    {
        return TTT_TEAM_DETECTIVE;
    }
    else if (StrEqual(name, "traitor", false))
    {
        return TTT_TEAM_TRAITOR;
    }
    else
    {
        return TTT_TEAM_UNASSIGNED;
    }
}

stock int TTT_GetRoleIDByShortName(const char[] shortName)
{
    if (StrEqual(shortName, "inno", false))
    {
        return TTT_TEAM_INNOCENT;
    }
    else if (StrEqual(shortName, "dete", false))
    {
        return TTT_TEAM_DETECTIVE;
    }
    else if (StrEqual(shortName, "trai", false))
    {
        return TTT_TEAM_TRAITOR;
    }
    else
    {
        return TTT_TEAM_UNASSIGNED;
    }
}

stock void TTT_GetShortRoleNameByID(int role, char[] shortName, int length = ROLE_LENGTH)
{
    if (role == TTT_TEAM_INNOCENT)
    {
        Format(shortName, length, "inno");
    }
    else if (role == TTT_TEAM_DETECTIVE)
    {
        Format(shortName, length, "dete");
    }
    else if (role == TTT_TEAM_TRAITOR)
    {
        Format(shortName, length, "trai");
    }
    else
    {
        Format(shortName, length, "unas");
    }
}

stock void TTT_GetShortRoleNameByName(const char[] name, char[] shortName, int length = ROLE_LENGTH)
{
    if (StrEqual(name, "Innocent", false))
    {
        Format(shortName, length, "inno");
    }
    else if (StrEqual(name, "Detective", false))
    {
        Format(shortName, length, "dete");
    }
    else if (StrEqual(name, "Traitor", false))
    {
        Format(shortName, length, "trai");
    }
    else
    {
        Format(shortName, length, "unas");
    }
}

/**
 * Returns if the client is alive or dead.
 *
 * @param client        Player's index.
 * @return                True if the client is alive, false otherwise.
 */
native bool TTT_IsPlayerAlive(int client);

/**
 * Check if TTT plugin is loaded and running.
 */
stock bool TTT_IsLoaded()
{
    return LibraryExists("ttt");
}

/**
 * Check if a client index is valid.
 */
stock bool TTT_IsClientValid(int client)
{
    if (client > 0 && client <= MaxClients)
    {
        if (!IsClientConnected(client))
        {
            return false;
        }
        
        if (IsClientSourceTV(client))
        {
            return false;
        }

        if (!IsClientInGame(client))
        {
            return false;
        }

        return true;
    }
    return false;
}

stock void TTT_IsGameCSGO()
{
    if (GetEngineVersion() != Engine_CSGO)
    {
        SetFailState("Only CS:GO Support!");
        return;
    }
}

#pragma deprecated TTT_HasCVarFlags is "unsafe". Please use TTT_CheckCommandAccess
stock bool TTT_HasCVarFlags(int client, ConVar cFlags)
{
    char flags[24];
    cFlags.GetString(flags, sizeof(flags));

    AdminFlag aFlags[24];
    FlagBitsToArray(ReadFlagString(flags), aFlags, sizeof(aFlags));
    
    return tHasFlags(client, aFlags);
}

#pragma deprecated TTT_HasFlags is "unsafe". Please use TTT_CheckCommandAccess
stock bool TTT_HasFlags(int client, const char[] flags)
{
    AdminFlag aFlags[24];
    FlagBitsToArray(ReadFlagString(flags), aFlags, sizeof(aFlags));
    
    return tHasFlags(client, aFlags);
}

stock bool tHasFlags(int client, AdminFlag flags[24])
{
    int iFlags = GetUserFlagBits(client);

    if (iFlags & ADMFLAG_ROOT)
    {
        return true;
    }

    for (int i = 0; i < sizeof(flags); i++)
    {
        if (iFlags & FlagToBit(flags[i]))
        {
            return true;
        }
    }

    return false;
}

stock bool TTT_RemoveWeaponByClassname(int client, const char[] classname, int slot)
{
    for(int offset = 0; offset < 128; offset += 4)
    {
        int weapon = GetEntDataEnt2(client, FindSendPropInfo("CBasePlayer", "m_hMyWeapons") + offset);

        if (IsValidEntity(weapon))
        {
            char sClass[32];
            GetEntityClassname(weapon, sClass, sizeof(sClass));

            if (StrEqual(sClass, classname, false))
            {
                return TTT_SafeRemoveWeapon(client, weapon, slot);
            }
        }
    }
    
    return false;
}

stock bool TTT_SafeRemoveWeapon(int client, int weapon, int slot)
{
    if (HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
    {
        int iDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
        
        if (iDefIndex < 0 || iDefIndex > 700)
        {
            return false;
        }
    }
    
    if (HasEntProp(weapon, Prop_Send, "m_bInitialized"))
    {
        if (GetEntProp(weapon, Prop_Send, "m_bInitialized") == 0)
        {
            return false;
        }
    }
    
    if (HasEntProp(weapon, Prop_Send, "m_bStartedArming"))
    {
        if (GetEntSendPropOffs(weapon, "m_bStartedArming") > -1)
        {
            return false;
        }
    }
    
    if (GetPlayerWeaponSlot(client, slot) != weapon)
    {
        return false;
    }
    
    if (!RemovePlayerItem(client, weapon))
    {
        return false;
    }
    
    int iWorldModel = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel");
    
    if (IsValidEdict(iWorldModel) && IsValidEntity(iWorldModel))
    {
        if (!AcceptEntityInput(iWorldModel, "Kill"))
        {
            return false;
        }
    }
    
    if (weapon == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
    {
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
    }
    
    AcceptEntityInput(weapon, "Kill");
    
    return true;
}

stock void TTT_ShowOverlayToClient(int client, const char[] overlaypath)
{
    int iFlags = GetCommandFlags("r_screenoverlay");

    SetCommandFlags("r_screenoverlay", iFlags &~ FCVAR_CHEAT);
    ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
    SetCommandFlags("r_screenoverlay", iFlags);
}

stock void TTT_ShowOverlayToAll(const char[] overlaypath)
{
    LoopValidClients(i)
    {
        if (!IsFakeClient(i))
        {
            TTT_ShowOverlayToClient(i, overlaypath);
        }
    }
}

stock int TTT_GetRandomPlayer(bool alive = true, int targetRole = -1)
{
    int[] clients = new int[MaxClients + 1];
    int clientCount = 0;

    LoopValidClients(i)
    {
        if (alive && !TTT_IsPlayerAlive(i))
        {
            continue;
        }

        if (targetRole != -1 && TTT_IsValidRole(i, targetRole))
        {
            continue;
        }

        clients[clientCount++] = i;
    }

    if (clientCount == 0)
    {
         return -1;
    }

    return clients[GetRandomInt(0, clientCount-1)];
} 

stock bool TTT_IsWorldDamage(int iAttacker, int damagetype)
{
    if (damagetype == DMG_FALL
         || damagetype == DMG_GENERIC
         || damagetype == DMG_CRUSH
         || damagetype == DMG_SLASH
         || damagetype == DMG_BURN
         || damagetype == DMG_VEHICLE
         || damagetype == DMG_FALL
         || damagetype == DMG_BLAST
         || damagetype == DMG_SHOCK
         || damagetype == DMG_SONIC
         || damagetype == DMG_ENERGYBEAM
         || damagetype == DMG_DROWN
         || damagetype == DMG_PARALYZE
         || damagetype == DMG_NERVEGAS
         || damagetype == DMG_POISON
         || damagetype == DMG_ACID
         || damagetype == DMG_AIRBOAT
         || damagetype == DMG_PLASMA
         || damagetype == DMG_RADIATION
         || damagetype == DMG_SLOWBURN
         || iAttacker == 0
        )
    {
        return true;
    }
    return false;
}

stock void TTT_ClearTimer(Handle &timer, bool autoClose = false)
{
    if (timer != null)
    {
        KillTimer(timer, autoClose);
        timer = null;
    }
}

stock void TTT_StartConfig(char[] file, char[] directory = "ttt")
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile(file, directory);
}

stock void TTT_EndConfig()
{
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

stock bool TTT_IsWarmUp()
{
    return view_as<bool>(GameRules_GetProp("m_bWarmupPeriod"));
}

stock int TTT_IsValidRole(int client, int role)
{
    return (role & TTT_GetClientRole(client));
}

stock bool TTT_IsPrimaryWeapon(int weapon)
{
    if (IsValidEntity(weapon))
    {
        char sClass[32];
        GetEntityClassname(weapon, sClass, sizeof(sClass));

        if ((StrContains(sClass, "ak47", false) != -1) || (StrContains(sClass, "m4a1", false) != -1) ||
            (StrContains(sClass, "m4a1_silencer", false) != -1) || (StrContains(sClass, "awp", false) != -1) ||
            (StrContains(sClass, "p90", false) != -1) || (StrContains(sClass, "sg556", false) != -1) ||
            (StrContains(sClass, "aug", false) != -1) || (StrContains(sClass, "galilar", false) != -1) ||
            (StrContains(sClass, "famas", false) != -1) || (StrContains(sClass, "ssg08", false) != -1) ||
            (StrContains(sClass, "g3sg1", false) != -1) || (StrContains(sClass, "scar20", false) != -1) ||
            (StrContains(sClass, "m249", false) != -1) || (StrContains(sClass, "negev", false) != -1) ||
            (StrContains(sClass, "nova", false) != -1) || (StrContains(sClass, "xm1014", false) != -1) ||
            (StrContains(sClass, "sawedoff", false) != -1) || (StrContains(sClass, "mag7", false) != -1) ||
            (StrContains(sClass, "mac10", false) != -1) || (StrContains(sClass, "mp9", false) != -1) ||
            (StrContains(sClass, "mp7", false) != -1) || (StrContains(sClass, "ump45", false) != -1) ||
            (StrContains(sClass, "bizon", false) != -1) || (StrContains(sClass, "mp5sd", false) != -1))
        {
            return true;
        }
    }

    return false;
}


stock void TTT_ShowProgressbar(int client, Handle percentageSync, Handle textSync, int startTime, int endTime, const char[] sMessage)
{
    int iEnd = endTime - startTime;
    int iCurrent = GetTime() - startTime;
    float fPercentage = ((100.0 / float(iEnd)) * float(iCurrent));

    char sProgress[128];
    for(int i = 0; i < fPercentage / 5; i++)
    {
        Format(sProgress, sizeof(sProgress), "%s█", sProgress);
    }
    
    int iColor[4]; //0(R) 1(G) 2(B) 3(A)

    if (fPercentage >= 90.0)
    {
        // Green
        iColor[0] = 0;      //r
        iColor[1] = 204;    //g
        iColor[2] = 0;      //b
        iColor[3] = 0;      //a
    }
    else if(fPercentage >= 75.0)
    {
        // Lightgreen
        iColor[0] = 153;    //r
        iColor[1] = 255;    //g
        iColor[2] = 0;      //b
        iColor[3] = 0;      //a
    }
    else if(fPercentage >= 50.0)
    {
        // Yellow
        iColor[0] = 255;    //r
        iColor[1] = 255;    //g
        iColor[2] = 0;      //b
        iColor[3] = 0;      //a
    }
    else if(fPercentage >= 30.0)
    {
        // Orange
        iColor[0] = 255;    //r
        iColor[1] = 165;    //g
        iColor[2] = 0;      //b
        iColor[3] = 0;      //a
    }
    else
    {
        // Red
        iColor[0] = 255;    //r
        iColor[1] = 0;      //g
        iColor[2] = 0;      //b
        iColor[3] = 0;      //a
    }
    SetHudTextParams(0.17, 0.13, 1.1, iColor[0], iColor[1], iColor[2], iColor[3], 0, 0.0, 0.0, 0.0);
    ShowSyncHudText(client, percentageSync, "%.1f%%\n%s", fPercentage, sProgress);
    SetHudTextParams(0.17, 0.1, 1.1, iColor[0], iColor[1], iColor[2], iColor[3], 0, 0.0, 0.0, 0.0);
    ShowSyncHudText(client, textSync, sMessage, fPercentage, sProgress);
}

stock int TTT_GetRoundTimeLeft()
{
    if (TTT_GetRoundTimestamp() == -1)
    {
        LogError("Invalid timestamp (%d)", TTT_GetRoundTimestamp());
        return -1;
    }

    ConVar cRoundTime = FindConVar("mp_roundtime");
    int iElapsed = (GetTime() - TTT_GetRoundTimestamp());
    return ((cRoundTime.IntValue * 60) - iElapsed);
}

stock int TTT_GetRoundTimeElapsed()
{
    if (TTT_GetRoundTimestamp() == -1)
    {
        LogError("Invalid timestamp (%d)", TTT_GetRoundTimestamp());
        return -1;
    }

    ConVar cRoundTime = FindConVar("mp_roundtime");
    return (GetTime() - TTT_GetRoundTimestamp());
}
