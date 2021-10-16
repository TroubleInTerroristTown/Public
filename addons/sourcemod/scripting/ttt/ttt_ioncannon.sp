#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <emitsoundany>
#include <colorlib>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Ion Cannon"
#define PLUGIN_AUTHORS "Jannik 'Peace-Maker' Hartung, AMXX version: A.F., Bara (CSGO port), " ... TTT_PLUGIN_AUTHOR

#define SHORT_NAME_ION "ion_default"
#define SHORT_NAME_ION_AUTO "ion_automatic"

#define ION_MODEL "models/props_lab/tpplug.mdl"
#define MDL_LASER "sprites/laserbeam.vmt"
#define FLARE_MDL "materials/sprites/yeflare1.vmt"

#define SOUND_APPROACH "ttt/ion/approaching.mp3"
#define SOUND_BEACON "ttt/ion/beacon_set.mp3"
#define SOUND_BEEP "ttt/ion/beacon_beep.mp3"
#define SOUND_ATTACK "ttt/ion/attack.mp3"
#define SOUND_READY "ttt/ion/ready.mp3"
#define SOUND_PLANT "ttt/ion/beacon_plant.mp3"
#define SOUND_STOP "common/warning.wav"

#define ACTION_BLOCK (IN_JUMP | IN_DUCK | IN_FORWARD | IN_BACK | IN_LEFT | IN_RIGHT | IN_MOVELEFT | IN_MOVERIGHT | IN_RELOAD | IN_RUN | IN_USE)

int g_iFlNextPrimaryAttack = -1;
int g_iLaserSprite = -1;
int g_iHaloSprite = -1;
int g_iGlowSprite = -1;
int g_iExplosionModel = -1;
int g_iSmokeSprite1 = -1;
int g_iSmokeSprite2 = -1;

ConVar g_cIonShakeTime = null;
ConVar g_cIonDeployTime = null;
ConVar g_cIonDeployWeapon = null;
ConVar g_CIonExplosionRate = null;
ConVar g_cIonExplosionRadius = null;
ConVar g_cIonExplosionMinDamage = null;
ConVar g_cIonExplosionMaxDamage = null;
ConVar g_cIonPlaceTime = null;
ConVar g_cIonSoundsVolume = null;
ConVar g_cIonAutoMenuTime = null;
ConVar g_cIonFriendlyFire = null;
ConVar g_cIonKarmaOnDisconnect = null;
ConVar g_cIonKarmaOnClear = null;
ConVar g_cIonDefLongName = null;
ConVar g_cIonDefPrice = null;
ConVar g_cIonDefPrio = null;
ConVar g_cIonDefCount = null;
ConVar g_cIonDefLimit = null;
ConVar g_cIonAutoLongName = null;
ConVar g_cIonAutoPrice = null;
ConVar g_cIonAutoPrio = null;
ConVar g_cIonAutoCount = null;
ConVar g_cIonAutoLimit = null;

ConVar g_cPluginTag = null;

char g_sPluginTag[64];

char g_sIonWeapon[PLATFORM_MAX_PATH];

float g_fBeamOrigin[MAXPLAYERS + 1][8][3];

enum struct PlayerData
{
    int iIonTarget;
    int iIonCannonAmmo;
    int iBeaconBeepPitch;
    int iInfoTargetEntity;
    int iFireWeaponStartTime;

    float fInfoTargetOrigin[3];
    float fBeaconBeepTime;
    float fBeamDegrees[8];
    float fBeamDistance;
    float fBeamRotationSpeed;
    float fSkyOrigin[3];

    bool bShowBeams;
    bool bIsPressingAttack;

    Handle hIonTarget;
    Handle hFiringWeapon;
    Handle hFiringWeaponCountdown;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHORS,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("TTT_HasIonCannon", Native_HasIonCannon);
    CreateNative("TTT_HasAutoIonCannon", Native_HasAutoIonCannon);
    CreateNative("TTT_GetIonCannon", Native_GetIonCannon);
    CreateNative("TTT_GetAutoIonCannon", Native_GetAutoIonCannon);
    CreateNative("TTT_AddIonCannon", Native_AddIonCannon);
    CreateNative("TTT_SetIonCannon", Native_SetIonCannon);
    CreateNative("TTT_IsFriendlyFired", Native_IsFriendlyFired);

    RegPluginLibrary("ttt_ioncannon");

    return APLRes_Success;
}

public int Native_HasIonCannon(Handle plugin, int numParams)
{
    return g_iPlayer[GetNativeCell(1)].iIonCannonAmmo > 0;
}

public int Native_HasAutoIonCannon(Handle plugin, int numParams)
{
    int target = GetClientOfUserId(g_iPlayer[GetNativeCell(1)].iIonTarget);

    return target > 0 && IsPlayerAlive(target) && TTT_GetClientRole(target) != TTT_TEAM_TRAITOR;
}

public int Native_GetIonCannon(Handle plugin, int numParams)
{
    return g_iPlayer[GetNativeCell(1)].iIonCannonAmmo;
}

public int Native_GetAutoIonCannon(Handle plugin, int numParams)
{
    int target = GetClientOfUserId(g_iPlayer[GetNativeCell(1)].iIonTarget);
    
    return (target > 0 && IsPlayerAlive(target) && TTT_GetClientRole(target) != TTT_TEAM_TRAITOR) ? target : -1;
}

public int Native_AddIonCannon(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int amount = GetNativeCell(2);

    if (amount > 0)
    {
        g_iPlayer[client].iIonCannonAmmo += amount;
    }

    return g_iPlayer[client].iIonCannonAmmo;
}

public int Native_SetIonCannon(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int cannons = GetNativeCell(2);

    if (cannons < 0)
    {
        g_iPlayer[client].iIonCannonAmmo = 0;
    }
    else
    {
        g_iPlayer[client].iIonCannonAmmo = cannons;
    }

    return g_iPlayer[client].iIonCannonAmmo;
}

public int Native_IsFriendlyFired(Handle plugin, int numParams)
{
    return g_cIonFriendlyFire.BoolValue;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();
    TTT_LoadTranslations();

    g_iFlNextPrimaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack");

    TTT_StartConfig("ion_cannon");
    CreateConVar("ion_cannon_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cIonShakeTime = AutoExecConfig_CreateConVar("ion_cannon_shake_time", "7", "How long should the client's screen shake after explosion in seconds?", _, true, 0.0);
    g_cIonDeployTime = AutoExecConfig_CreateConVar("ion_cannon_deploy_time", "7", "How long does it take to display the beams after deploying a ion cannon in seconds?", _, true, 0.0, true, 35.0);
    g_cIonDeployWeapon = AutoExecConfig_CreateConVar("ion_cannon_deploy_weapon", "weapon_knife", "Which weapon should be used to deploy ion cannons?");
    g_CIonExplosionRate = AutoExecConfig_CreateConVar("ion_cannon_explosion_rate", "5", "Determinate count of explosions (1.0 = max, 2.0 = 2x less, 3.0 = 3x less, ...).", _, true, 1.0, true, 30.0);
    g_cIonExplosionRadius = AutoExecConfig_CreateConVar("ion_cannon_explosion_radius", "2000", "The radius of the explosion.", _, true, 0.0);
    g_cIonExplosionMinDamage = AutoExecConfig_CreateConVar("ion_cannon_explosion_min_damage", "42100", "How much damage does the explosion deal at min?", _, true, 0.0);
    g_cIonExplosionMaxDamage = AutoExecConfig_CreateConVar("ion_cannon_explosion_max_damage", "58750", "How much damage does the explosion deal at max?", _, true, 0.0);
    g_cIonPlaceTime = AutoExecConfig_CreateConVar("ion_cannon_place_time", "5", "How many seconds should player have to stand still to deploy an ion cannon?", _, true, 0.0);
    g_cIonSoundsVolume = AutoExecConfig_CreateConVar("ion_cannon_sounds_volume", "0.8", "How loud should ion sounds be?", _, true, 0.0, true, 1.0);
    g_cIonAutoMenuTime = AutoExecConfig_CreateConVar("ion_cannon_auto_menu_time", "15", "How long should menu with targers stands?", _, true, 0.0);
    g_cIonFriendlyFire = AutoExecConfig_CreateConVar("ion_cannon_friendly_fire", "0", "Should Ion Cannon hurt other traitors?", _, true, 0.0, true, 1.0);
    g_cIonKarmaOnDisconnect = AutoExecConfig_CreateConVar("ion_cannon_karma_on_disconnect", "10", "Should player receive x karma when target disconnects? (0 to disable)", _, true, 0.0);
    g_cIonKarmaOnClear = AutoExecConfig_CreateConVar("ion_cannon_karma_on_clear", "5", "Should player receive x karma when round ends? (0 to disable)", _, true, 0.0);

    g_cIonDefLongName = AutoExecConfig_CreateConVar("ion_cannon_def_name", "Ion Cannon", "The name of this in Shop.");
    g_cIonDefPrice = AutoExecConfig_CreateConVar("ion_cannon_def_price", "18750", "The amount of credits it will costs as traitor. 0 to disable.", _, true, 0.0);
    g_cIonDefPrio = AutoExecConfig_CreateConVar("ion_cannon_def_prio", "0", "The sorting priority in the shop menu.");
    g_cIonDefCount = AutoExecConfig_CreateConVar("ion_cannon_def_count", "1", "How many ion cannons can player buy?", _, true, 1.0);
    g_cIonDefLimit = AutoExecConfig_CreateConVar("ion_cannon_def_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);

    g_cIonAutoLongName = AutoExecConfig_CreateConVar("ion_cannon_auto_name", "Auto Ion Cannon", "The name of this in Shop.");
    g_cIonAutoPrice = AutoExecConfig_CreateConVar("ion_cannon_auto_price", "38750", "The amount of credits it will costs as traitor. 0 to disable.", _, true, 0.0);
    g_cIonAutoPrio = AutoExecConfig_CreateConVar("ion_cannon_auto_prio", "0", "The sorting priority in the shop menu.");
    g_cIonAutoCount = AutoExecConfig_CreateConVar("ion_cannon_auto_count", "1", "How many auto ion cannons can player buy?", _, true, 1.0);
    g_cIonAutoLimit = AutoExecConfig_CreateConVar("ion_cannon_auto_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();

    HookEvent("player_spawn", Event_OnPlayerSpawn);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_ION);
        TTT_RemoveShopItem(SHORT_NAME_ION_AUTO);
    }
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    g_cIonDeployWeapon.AddChangeHook(OnConVarChanged);
    g_cIonDeployWeapon.GetString(g_sIonWeapon, sizeof(g_sIonWeapon));

    TTT_OnShopReady();
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cIonDeployWeapon)
    {
        strcopy(g_sIonWeapon, sizeof(g_sIonWeapon), newValue);
    }
    else if (convar == g_cPluginTag)
    {
        strcopy(g_sPluginTag, sizeof(g_sPluginTag), newValue);
    }
}

public void OnMapStart()
{
    char sSoundFile[PLATFORM_MAX_PATH];
    Format(sSoundFile, sizeof(sSoundFile), "sound/%s", SOUND_APPROACH);
    AddFileToDownloadsTable(sSoundFile);
    Format(sSoundFile, sizeof(sSoundFile), "sound/%s", SOUND_BEACON);
    AddFileToDownloadsTable(sSoundFile);
    Format(sSoundFile, sizeof(sSoundFile), "sound/%s", SOUND_ATTACK);
    AddFileToDownloadsTable(sSoundFile);
    Format(sSoundFile, sizeof(sSoundFile), "sound/%s", SOUND_READY);
    AddFileToDownloadsTable(sSoundFile);
    Format(sSoundFile, sizeof(sSoundFile), "sound/%s", SOUND_PLANT);
    AddFileToDownloadsTable(sSoundFile);
    Format(sSoundFile, sizeof(sSoundFile), "sound/%s", SOUND_BEEP);
    AddFileToDownloadsTable(sSoundFile);
    
    PrecacheSoundAny(SOUND_APPROACH, true);
    PrecacheSoundAny(SOUND_BEACON, true);
    PrecacheSoundAny(SOUND_ATTACK, true);
    PrecacheSoundAny(SOUND_READY, true);
    PrecacheSoundAny(SOUND_PLANT, true);
    PrecacheSoundAny(SOUND_BEEP, true);
    PrecacheSoundAny(SOUND_STOP, true);
    
    PrecacheModel(ION_MODEL, true);
    PrecacheModel(MDL_LASER, true);
    PrecacheModel(FLARE_MDL, true);
    PrecacheMaterial("materials/sprites/xfireball3.vtf");

    g_iHaloSprite = PrecacheModel("materials/sprites/halo.vmt");
    g_iGlowSprite = PrecacheModel("sprites/blueglow1.vmt", true);
    g_iLaserSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_iSmokeSprite1 = PrecacheModel("materials/effects/fire_cloud1.vmt", true);
    g_iSmokeSprite2 = PrecacheModel("materials/effects/fire_cloud2.vmt", true);
    g_iExplosionModel = PrecacheModel("materials/sprites/sprite_fire01.vmt", true);
}

public void TTT_OnShopReady()
{
    char sName[128];

    g_cIonDefLongName.GetString(sName, sizeof(sName));	
    TTT_RegisterShopItem(SHORT_NAME_ION, sName, g_cIonDefPrice.IntValue, TTT_TEAM_TRAITOR, g_cIonDefPrio.IntValue, g_cIonDefCount.IntValue, g_cIonDefLimit.IntValue, OnItemPurchased);

    g_cIonAutoLongName.GetString(sName, sizeof(sName));		
    TTT_RegisterShopItem(SHORT_NAME_ION_AUTO, sName, g_cIonAutoPrice.IntValue, TTT_TEAM_TRAITOR, g_cIonAutoPrio.IntValue, g_cIonAutoCount.IntValue, g_cIonAutoLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
    {
        return Plugin_Stop;
    }

    if (StrEqual(itemshort, SHORT_NAME_ION_AUTO, false))
    {
        if (g_iPlayer[client].iIonTarget != -1)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Ion cannon: One ion per time", client);
            return Plugin_Stop;
        }

        ShowTargetMenu(client);
    }
    else
    {
        g_iPlayer[client].iIonCannonAmmo++;
    }

    TTT_AddInventoryItem(client, itemshort);
    return Plugin_Continue;
}

public void TTT_OnInventoryMenuItemSelect(int client, const char[] itemshort)
{
    if (TTT_IsClientValid(client) && StrEqual(itemshort, SHORT_NAME_ION_AUTO))
    {
        if (TTT_GetClientItemQuantity(client, itemshort) > 0)
        {
            ShowTargetMenu(client);
        }
    }
}

void ShowTargetMenu(int client)
{
    Menu menu = new Menu(Menu_IonHandler);

    menu.SetTitle("%T", "Ion cannon: Select ion target", client);

    char sUID[8], sNick[MAX_NAME_LENGTH];
    LoopValidClients(i)
    {
        if (IsPlayerAlive(i) && client != i && TTT_GetClientRole(i) != TTT_TEAM_TRAITOR)
        {
            Format(sUID, sizeof(sUID), "%i", i);
            TTT_GetClientName(i, sNick, sizeof(sNick));

            menu.AddItem(sUID, sNick);
        }
    }

    menu.ExitButton = true;
    menu.Display(client, g_cIonAutoMenuTime.IntValue);
}

public int Menu_IonHandler(Handle menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sUID[8];
        GetMenuItem(menu, param, sUID, sizeof(sUID));

        int target = StringToInt(sUID);

        if (TTT_IsClientValid(target) && IsPlayerAlive(target) && TTT_GetClientRole(target) != TTT_TEAM_TRAITOR)
        {
            AimAtTarget(client, target);
        }
        else
        {
            ShowTargetMenu(client);
        }
    }
    else if (action == MenuAction_Cancel || action == MenuAction_End)
    {
        delete menu;
    }
}

void AimAtTarget(int client, int target) 
{
    TTT_RemoveInventoryItem(client, SHORT_NAME_ION_AUTO);

    g_iPlayer[client].iIonTarget = GetClientUserId(target);
    g_iPlayer[client].iInfoTargetEntity = -1;
    g_iPlayer[client].iBeaconBeepPitch = 97;
    g_iPlayer[client].fBeaconBeepTime = 1.12;
    g_iPlayer[client].fBeamDistance = 350.0;
    g_iPlayer[client].fBeamRotationSpeed = 0.0;
    g_iPlayer[client].bShowBeams = false;

    CreateTimer(0.0, Timer_OnIonPlanted, GetClientUserId(client));

    g_iPlayer[client].hIonTarget = CreateTimer(0.1, Timer_UpdateTargetPosition, GetClientUserId(client), TIMER_REPEAT);
}

Action Timer_UpdateTargetPosition(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    int target = GetClientOfUserId(g_iPlayer[client].iIonTarget);

    if (TTT_IsClientValid(target) && IsPlayerAlive(target) && TTT_GetClientRole(target) != TTT_TEAM_TRAITOR)
    {
        GetClientAbsOrigin(target, g_iPlayer[client].fInfoTargetOrigin);
    }
    else
    {
        g_iPlayer[client].iIonTarget = -1;

        LoopValidClients(i)
        {
            CPrintToChat(i, "%s %T", g_sPluginTag, "Ion cannon: Target left the area", i);
            CPrintToChat(i, "%s %T", g_sPluginTag, "Ion cannon: Fire at last know location", i);
        }

        TTT_ClearTimer(g_iPlayer[client].hIonTarget);
    }
}

public void OnClientDisconnect(int client)
{
    LoopValidClients(i)
    {
        if (GetClientOfUserId(g_iPlayer[i].iIonTarget) == client)
        {
            g_iPlayer[i].iIonTarget = -1;
            
            if (g_cIonKarmaOnDisconnect.IntValue > 0)
            {
                TTT_AddClientKarma(i, g_cIonKarmaOnDisconnect.IntValue, true);
            }

            LoopValidClients(j)
            {
                CPrintToChat(j, "%s %T", g_sPluginTag, "Ion cannon: Target left the area", j);
                CPrintToChat(j, "%s %T", g_sPluginTag, "Ion cannon: Fire at last know location", j);
            }

            TTT_ClearTimer(g_iPlayer[i].hIonTarget);
        }
    }

    ClearIon(client);
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    LoopValidClients(i)
    {
        ClearIon(i, true);
    }
}

void ClearIon(int client, bool ammo = false)
{
    if (ammo)
    {
        g_iPlayer[client].iIonCannonAmmo = 0;
    }

    int iEntity = EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity);

    if (iEntity > 0 && IsValidEntity(iEntity))
    {
        AcceptEntityInput(iEntity, "Kill");
    }

    g_iPlayer[client].iInfoTargetEntity = -1;

    if (GetClientOfUserId(g_iPlayer[client].iIonTarget) != -1)
    {
        if (g_cIonKarmaOnClear.IntValue > 0)
        {
            TTT_AddClientKarma(client, g_cIonKarmaOnClear.IntValue, true);
        }
    }

    g_iPlayer[client].iIonTarget = -1;

    iEntity = -1;
    g_iPlayer[client].iFireWeaponStartTime = 0;

    if (TTT_IsClientValid(client))
    {
        SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", 0.0);
        SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
    }

    TTT_ClearTimer(g_iPlayer[client].hIonTarget);
    TTT_ClearTimer(g_iPlayer[client].hFiringWeapon);
    TTT_ClearTimer(g_iPlayer[client].hFiringWeaponCountdown);
}

Action Event_OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!TTT_IsClientValid(client))
    {
        return;
    }
    
    ClearIon(client);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float fVel[3], float fAngles[3], int &weapon)
{
    if (buttons & IN_ATTACK && !g_iPlayer[client].bIsPressingAttack && g_iPlayer[client].iIonCannonAmmo > 0)
    {
        if (g_iPlayer[client].hFiringWeapon == INVALID_HANDLE)
        {
            char sWeapon[64];
            int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

            if (iWeapon != -1 && IsValidEntity(iWeapon) && IsValidEdict(iWeapon) && GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon)) && StrEqual(sWeapon, g_sIonWeapon))
            {
                char sBuffer[1024];

                if (EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity) > 0 || IsValidEntity(EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity)))
                {
                    Format(sBuffer, sizeof(sBuffer), "%T", "Ion cannon: One ion per time", client);
                    PrintCenterText2(client, "TTT - Ion Cannon", sBuffer);
                }
                else
                {
                    g_iPlayer[client].iInfoTargetEntity = -1;
                    g_iPlayer[client].iBeaconBeepPitch = 97;
                    g_iPlayer[client].fBeaconBeepTime = 1.12;
                    g_iPlayer[client].fBeamDistance = 350.0;
                    g_iPlayer[client].fBeamRotationSpeed = 0.0;
                    g_iPlayer[client].bShowBeams = false;
                    g_iPlayer[client].iIonCannonAmmo--;

                    EmitSoundToClientAny(client, SOUND_BEACON, SOUND_FROM_PLAYER, SNDCHAN_WEAPON);

                    SetEntDataFloat(iWeapon, g_iFlNextPrimaryAttack, GetGameTime() + 1.0);
                    
                    float fPlaceTime = g_cIonPlaceTime.FloatValue;

                    SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
                    SetEntProp(client, Prop_Send, "m_iProgressBarDuration", RoundToNearest(fPlaceTime));
                    
                    g_iPlayer[client].iFireWeaponStartTime = GetTime();
                    g_iPlayer[client].hFiringWeaponCountdown = CreateTimer(0.5, Timer_OnUpdatePlaceCountdown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
                    g_iPlayer[client].hFiringWeapon = CreateTimer(fPlaceTime, Timer_OnIonPlanted, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
                    
                    BlockKnife(client);

                    Format(sBuffer, sizeof(sBuffer), "%T", "Ion cannon: Placing ion beacon", client, RoundToNearest(fPlaceTime));
                    PrintCenterText2(client, "TTT - Ion Cannon", sBuffer);
                }

                g_iPlayer[client].bIsPressingAttack = true;
            }
        }
        
    }
    else if(g_iPlayer[client].hFiringWeapon != INVALID_HANDLE && (buttons & ACTION_BLOCK || weapon > 0 || !(buttons & IN_ATTACK)))
    {
        g_iPlayer[client].iIonCannonAmmo++;
        g_iPlayer[client].iFireWeaponStartTime = 0;

        TTT_ClearTimer(g_iPlayer[client].hFiringWeapon);
        TTT_ClearTimer(g_iPlayer[client].hFiringWeaponCountdown);
        
        StopSoundAny(client, SNDCHAN_WEAPON, SOUND_BEACON);
        
        EmitSoundToClientAny(client, SOUND_STOP, SOUND_FROM_PLAYER, SNDCHAN_WEAPON);
        
        char sBuffer[1024];
        Format(sBuffer, sizeof(sBuffer), "%T", "Ion cannon: Stopped placing ion beacon", client);
        PrintCenterText2(client, "TTT - Ion Cannon", sBuffer);

        SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", 0.0);
        SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
    }
    
    if (!(buttons & IN_ATTACK))
    {
        g_iPlayer[client].bIsPressingAttack = false;
    }

    if (g_iPlayer[client].bIsPressingAttack)
    {
        buttons &= ~IN_ATTACK;
        return Plugin_Changed;
    }
    
    return Plugin_Continue;
}

Action Timer_OnUpdatePlaceCountdown(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    if (!IsClientInGame(client) || g_iPlayer[client].iFireWeaponStartTime == 0)
    {
        TTT_ClearTimer(g_iPlayer[client].hFiringWeaponCountdown);
        return;
    }
    
    int iDifference = g_cIonPlaceTime.IntValue - GetTime() + g_iPlayer[client].iFireWeaponStartTime;

    if (iDifference < 1)
    {
        TTT_ClearTimer(g_iPlayer[client].hFiringWeaponCountdown);
        return;
    }

    BlockKnife(client);
    
    char sBuffer[1024];
    Format(sBuffer, sizeof(sBuffer), "%T", "Ion cannon: Placing ion beacon", client, iDifference);
    PrintCenterText2(client, "TTT - Ion Cannon", sBuffer);
}

void BlockKnife(int client)
{
    char sWeapon[64];
    int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

    if (iWeapon != -1 && IsValidEntity(iWeapon) && IsValidEdict(iWeapon) && GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon)) && StrEqual(sWeapon, g_sIonWeapon))
    {
        SetEntDataFloat(iWeapon, g_iFlNextPrimaryAttack, GetGameTime() + 1.0);
    }
}

Action Timer_OnIonPlanted(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    int target = TTT_IsClientValid(g_iPlayer[client].iIonTarget) ? GetClientOfUserId(g_iPlayer[client].iIonTarget) : client;

    if (target != client)
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s %T", g_sPluginTag, "Ion cannon: Auto ion cannon deployed", client);
        }
    }
    else
    {
        TTT_RemoveInventoryItem(client, SHORT_NAME_ION);

        LoopValidClients(i)
        {
            CPrintToChat(i, "%s %T", g_sPluginTag, "Ion cannon: Ion cannon deployed", client);
        }
    }

    EmitSoundToAllAny(SOUND_PLANT, SOUND_FROM_PLAYER, SNDCHAN_WEAPON);
    
    g_iPlayer[client].hFiringWeapon = INVALID_HANDLE;
    
    SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", 0.0);
    SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
    
    int iEntity = CreateEntityByName("info_target");
    
    if (iEntity == -1)
    {
        return;
    }
    
    DispatchKeyValue(iEntity, "targetname", "info_target_ion");
    SetEntityModel(iEntity, ION_MODEL);
    
    SetEntityMoveType(iEntity, MOVETYPE_NONE);
    SetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity", client);
    SetEntProp(iEntity, Prop_Send, "m_nSolidType", 6);
    
    int iEffects = GetEntProp(iEntity, Prop_Send, "m_fEffects");
    iEffects |= 32;
    SetEntProp(iEntity, Prop_Send, "m_fEffects", iEffects);

    if (DispatchSpawn(iEntity))
    {
        GetClientAbsOrigin(target, g_iPlayer[client].fInfoTargetOrigin);
        TeleportEntity(iEntity, g_iPlayer[client].fInfoTargetOrigin, NULL_VECTOR, NULL_VECTOR);
        
        TE_SetupGlowSprite(g_iPlayer[client].fInfoTargetOrigin, g_iGlowSprite, 3.0, 1.0, 100);
        TE_SendToAll();
        
        EmitSoundToAllAny(SOUND_BEEP, iEntity, SNDCHAN_ITEM, SNDLEVEL_GUNFIRE, SND_NOFLAGS, SNDVOL_NORMAL, g_iPlayer[client].iBeaconBeepPitch);

        CreateTimer(5.0, Timer_OnIonStartup, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(g_iPlayer[client].fBeaconBeepTime, Timer_OnPlayBeaconBeep, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

        g_iPlayer[client].iInfoTargetEntity = EntIndexToEntRef(iEntity);
    }
}

Action Timer_OnPlayBeaconBeep(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    int iEntity = EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity);
    
    if (iEntity < 0 || !IsValidEntity(iEntity))
    {
        return;
    }

    g_iPlayer[client].iBeaconBeepPitch += 3;
    g_iPlayer[client].fBeaconBeepTime -= 0.03;

    if (g_iPlayer[client].iBeaconBeepPitch > 255)
    {
        g_iPlayer[client].iBeaconBeepPitch = 255;
    }

    if (g_iPlayer[client].fBeaconBeepTime < 0.3)
    {
        g_iPlayer[client].fBeaconBeepTime = 0.3;
    }

    EmitSoundToAllAny(SOUND_BEEP, iEntity, SNDCHAN_ITEM, SNDLEVEL_GUNFIRE, SND_NOFLAGS, SNDVOL_NORMAL, g_iPlayer[client].iBeaconBeepPitch);

    CreateTimer(g_iPlayer[client].fBeaconBeepTime, Timer_OnPlayBeaconBeep, userid, TIMER_FLAG_NO_MAPCHANGE);

    TE_SetupGlowSprite(g_iPlayer[client].fInfoTargetOrigin, g_iGlowSprite, g_iPlayer[client].fBeaconBeepTime, 1.0, 100);
    TE_SendToAll();
}

Action Timer_OnIonStartup(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    if (EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity) < 0 || !IsValidEntity(EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity)))
    {
        return;
    }
    
    EmitSoundToAllAny(SOUND_APPROACH);

    LoopValidClients(i)
    {
        CPrintToChat(i, "%s %T", g_sPluginTag, "Ion cannon: Satellite approaching", i);
    }

    CreateTimer(g_cIonDeployTime.FloatValue, Timer_OnTraceReady, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_OnTraceReady(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    if (EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity) < 0 || !IsValidEntity(EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity)))
    {
        return;
    }
    
    // 1st
    g_fBeamOrigin[client][0][0] = g_iPlayer[client].fInfoTargetOrigin[0] + 300.0;
    g_fBeamOrigin[client][0][1] = g_iPlayer[client].fInfoTargetOrigin[1] + 150.0;
    g_fBeamOrigin[client][0][2] = g_iPlayer[client].fInfoTargetOrigin[2];
    g_iPlayer[client].fBeamDegrees[0] = 0.0;
    
    // 2nd
    g_fBeamOrigin[client][1][0] = g_iPlayer[client].fInfoTargetOrigin[0] + 300.0;
    g_fBeamOrigin[client][1][1] = g_iPlayer[client].fInfoTargetOrigin[1] - 150.0;
    g_fBeamOrigin[client][1][2] = g_iPlayer[client].fInfoTargetOrigin[2];
    g_iPlayer[client].fBeamDegrees[1] = 45.0;
    
    // 3rd
    g_fBeamOrigin[client][2][0] = g_iPlayer[client].fInfoTargetOrigin[0] - 300.0;
    g_fBeamOrigin[client][2][1] = g_iPlayer[client].fInfoTargetOrigin[1] - 150.0;
    g_fBeamOrigin[client][2][2] = g_iPlayer[client].fInfoTargetOrigin[2];
    g_iPlayer[client].fBeamDegrees[2] = 90.0;
    
    // 4th
    g_fBeamOrigin[client][3][0] = g_iPlayer[client].fInfoTargetOrigin[0] - 300.0;
    g_fBeamOrigin[client][3][1] = g_iPlayer[client].fInfoTargetOrigin[1] + 150.0;
    g_fBeamOrigin[client][3][2] = g_iPlayer[client].fInfoTargetOrigin[2];
    g_iPlayer[client].fBeamDegrees[3] = 135.0;
    
    // 5th
    g_fBeamOrigin[client][4][0] = g_iPlayer[client].fInfoTargetOrigin[0] + 150.0;
    g_fBeamOrigin[client][4][1] = g_iPlayer[client].fInfoTargetOrigin[1] + 300.0;
    g_fBeamOrigin[client][4][2] = g_iPlayer[client].fInfoTargetOrigin[2];
    g_iPlayer[client].fBeamDegrees[4] = 180.0;
    
    // 6th
    g_fBeamOrigin[client][5][0] = g_iPlayer[client].fInfoTargetOrigin[0] + 150.0;
    g_fBeamOrigin[client][5][1] = g_iPlayer[client].fInfoTargetOrigin[1] - 300.0;
    g_fBeamOrigin[client][5][2] = g_iPlayer[client].fInfoTargetOrigin[2];
    g_iPlayer[client].fBeamDegrees[5] = 225.0;
    
    // 7th
    g_fBeamOrigin[client][6][0] = g_iPlayer[client].fInfoTargetOrigin[0] - 150.0;
    g_fBeamOrigin[client][6][1] = g_iPlayer[client].fInfoTargetOrigin[1] - 300.0;
    g_fBeamOrigin[client][6][2] = g_iPlayer[client].fInfoTargetOrigin[2];
    g_iPlayer[client].fBeamDegrees[6] = 270.0;
    
    // 8th
    g_fBeamOrigin[client][7][0] = g_iPlayer[client].fInfoTargetOrigin[0] - 150.0;
    g_fBeamOrigin[client][7][1] = g_iPlayer[client].fInfoTargetOrigin[1] + 300.0;
    g_fBeamOrigin[client][7][2] = g_iPlayer[client].fInfoTargetOrigin[2];
    g_iPlayer[client].fBeamDegrees[7] = 315.0;
    
    g_iPlayer[client].bShowBeams = true;

    float fTime = 0.0;
    DataPack pack;

    for (int i = 0; i < 8; i++)
    {
        fTime += 0.3;

        pack = new DataPack();
        pack.WriteCell(i);
        pack.WriteCell(GetClientUserId(client));
        
        CreateTimer(fTime, Timer_OnTraceStart, pack, TIMER_FLAG_NO_MAPCHANGE);
    }
    
    EmitSoundToAllAny(SOUND_READY, _, _, _, _, g_cIonSoundsVolume.FloatValue);
    
    for (float i = 0.0; i < 7.5; i += 0.01)
    {
        CreateTimer(i + 3.0, Timer_OnLaserRotate, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    
    CreateTimer(2.9, Timer_OnAddSpeed, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(11.5, Timer_OnCreateFire, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(12.5, Timer_OnClearLasers, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(15.2, Timer_OnFireIonCannon, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_OnCreateFire(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    if (EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity) < 0 || !IsValidEntity(EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity)))
    {
        return;
    }

    int iFire = CreateEntityByName("env_fire");

    if (iFire != -1)
    {
        TeleportEntity(iFire, g_iPlayer[client].fInfoTargetOrigin, NULL_VECTOR, NULL_VECTOR);

        DispatchKeyValue(iFire, "health", "2");
        DispatchKeyValue(iFire, "firesize", "200");
        DispatchKeyValue(iFire, "fireattack", "1");
        DispatchKeyValue(iFire, "firetype", "Normal");
        DispatchKeyValue(iFire, "damagescale", "1.0");

        SetVariantString("spawnflags 128");
        AcceptEntityInput(iFire,"AddOutput");

        DispatchSpawn(iFire);

        ActivateEntity(iFire);
        AcceptEntityInput(iFire, "StartFire", client);
    }

    CreateTimer(1.5, Timer_OnCreateFire, userid, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_OnClearLasers(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    if (EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity) > 0 && IsValidEntity(EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity)))
    {
        g_iPlayer[client].bShowBeams = false;
    }
}

Action Timer_OnTraceStart(Handle timer, DataPack pack)
{
    pack.Reset();

    int index = pack.ReadCell();
    int userid = pack.ReadCell();

    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    delete pack;
    
    if (EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity) < 0 || !IsValidEntity(EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity)))
    {
        return;
    }
    
    g_iPlayer[client].fSkyOrigin = GetDistanceToSky(g_iPlayer[client].iInfoTargetEntity);

    float fRandomZ = Math_GetRandomFloat(300.0, g_iPlayer[client].fSkyOrigin[2]);
    
    float fBeamOrigin[3];
    fBeamOrigin[0] = g_fBeamOrigin[client][index][0];
    fBeamOrigin[1] = g_fBeamOrigin[client][index][1];
    fBeamOrigin[2] = g_fBeamOrigin[client][index][2] + fRandomZ;
    
    TE_SetupGlowSprite(fBeamOrigin, g_iGlowSprite, 2.0, 10.0, 100);
    TE_SendToAll();

    pack = new DataPack();
    pack.WriteCell(index);
    pack.WriteCell(client);

    RequestFrame(Frame_ShowBeam, pack);
}

Action Timer_OnLaserRotate(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    if (EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity) < 0 || !IsValidEntity(EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity)) || !g_iPlayer[client].bShowBeams)
    {
        return;
    }
    
    g_iPlayer[client].fBeamDistance -= 0.467;

    for (int i = 0; i < 8; i++)
    {
        g_iPlayer[client].fBeamDegrees[i] += g_iPlayer[client].fBeamRotationSpeed;

        if (g_iPlayer[client].fBeamDegrees[i] > 360.0)
        {
            g_iPlayer[client].fBeamDegrees[i] -= 360.0;
        }

        g_fBeamOrigin[client][i][0] = g_iPlayer[client].fInfoTargetOrigin[0] + Sine(g_iPlayer[client].fBeamDegrees[i]) * g_iPlayer[client].fBeamDistance;
        g_fBeamOrigin[client][i][1] = g_iPlayer[client].fInfoTargetOrigin[1] + Cosine(g_iPlayer[client].fBeamDegrees[i]) * g_iPlayer[client].fBeamDistance;
        g_fBeamOrigin[client][i][2] = g_iPlayer[client].fInfoTargetOrigin[2] + 0.0;
    }
}

Action Timer_OnAddSpeed(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    if (EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity) < 0 || !IsValidEntity(EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity)) || !g_iPlayer[client].bShowBeams)
    {
        return;
    }
    
    if (g_iPlayer[client].fBeamRotationSpeed > 1.0)
    {
        g_iPlayer[client].fBeamRotationSpeed = 1.0;
    }
        
    g_iPlayer[client].fBeamRotationSpeed += 0.1;
    
    CreateTimer(0.6, Timer_OnAddSpeed, userid, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_OnFireIonCannon(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    int iEntity = EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity);

    if (iEntity < 0 || !IsValidEntity(iEntity))
    {
        return;
    }

    int target = TTT_IsClientValid(g_iPlayer[client].iIonTarget) ? GetClientOfUserId(g_iPlayer[client].iIonTarget) : -1;

    if (target > 0 && IsPlayerAlive(target) && TTT_GetClientRole(target) != TTT_TEAM_TRAITOR)
    {
        ForcePlayerSuicide(target);

        Event event = CreateEvent("player_death", true);
        
        if (event == null)
        {
            return;
        }

        event.SetInt("userid", GetClientUserId(target));
        event.SetInt("attacker", GetClientUserId(client));
        event.Fire();
    }

    g_iPlayer[client].iIonTarget = -1;

    TTT_ClearTimer(g_iPlayer[client].hIonTarget);
    
    float fIonRadius = g_cIonExplosionRadius.FloatValue;
    float fShakeTime = g_cIonShakeTime.FloatValue;
    float fPlayerOrigin[3], fVecConnecting[3], fDirectionAngle[3], fEndPosition[3];

    LoopValidClients(i)
    {
        if (IsPlayerAlive(i))
        {
            GetClientAbsOrigin(i, fPlayerOrigin);
            fPlayerOrigin[2] += 50.0;
            MakeVectorFromPoints(g_iPlayer[client].fInfoTargetOrigin, fPlayerOrigin, fVecConnecting);
            GetVectorAngles(fVecConnecting, fDirectionAngle);
            TR_TraceRayFilter(g_iPlayer[client].fInfoTargetOrigin, fDirectionAngle, CONTENTS_PLAYERCLIP, RayType_Infinite, TraceRay_PlayerOnly, i);

            if (TR_DidHit())
            {
                TR_GetEndPosition(fEndPosition);

                if (GetDistance(g_iPlayer[client].fInfoTargetOrigin, fEndPosition) <= fIonRadius + 8000.0)
                {
                    TTT_ShakeClient(i, 0, 255.0, 255.0, fShakeTime);
                }
            }
        }
    }

    TE_SetupBeamPoints(g_iPlayer[client].fSkyOrigin, g_iPlayer[client].fInfoTargetOrigin, g_iLaserSprite, g_iHaloSprite, 0, 10, 15.0, 100.0, 100.0, 10, 4.0, {255, 255, 255, 255}, 0);
    
    TE_SetupBeamPoints(g_iPlayer[client].fSkyOrigin, g_iPlayer[client].fInfoTargetOrigin, g_iLaserSprite, g_iHaloSprite, 0, 10, 15.0, 100.0, 100.0, 10, 4.0, {255, 255, 255, 255}, 0);
    TE_SendToAll();
    
    TE_SetupBeamPoints(g_iPlayer[client].fSkyOrigin, g_iPlayer[client].fInfoTargetOrigin, g_iLaserSprite, g_iHaloSprite, 0, 30, 10.0, 60.0, 60.0, 10, 5.0, {0, 100, 250, 100}, 20);
    
    TE_SetupBeamPoints(g_iPlayer[client].fSkyOrigin, g_iPlayer[client].fInfoTargetOrigin, g_iLaserSprite, g_iHaloSprite, 0, 30, 10.0, 60.0, 60.0, 10, 5.0, {0, 100, 250, 100}, 20);
    TE_SendToAll();
    
    float fBeamHigh[3];
    fBeamHigh[0] = g_iPlayer[client].fInfoTargetOrigin[0];
    fBeamHigh[1] = g_iPlayer[client].fInfoTargetOrigin[1];
    fBeamHigh[2] = g_iPlayer[client].fInfoTargetOrigin[2] + 20.0;
    
    TE_SetupBeamRingPoint(fBeamHigh, 0.0, fIonRadius - 1000.0, g_iLaserSprite, g_iHaloSprite, 0, 30, 20.0, 100.0, 2.0, {0, 100, 250, 100}, 0, 0);
    TE_SetupBeamRingPoint(fBeamHigh, 0.0, fIonRadius - 1000.0, g_iLaserSprite, g_iHaloSprite, 0, 30, 20.0, 100.0, 2.0, {0, 100, 250, 100}, 10, 0);
    TE_SetupBeamRingPoint(fBeamHigh, 0.0, fIonRadius - 1000.0, g_iLaserSprite, g_iHaloSprite, 0, 30, 20.0, 100.0, 2.0, {0, 100, 250, 100}, 20, 0);
    TE_SetupBeamRingPoint(fBeamHigh, 0.0, fIonRadius - 1000.0, g_iLaserSprite, g_iHaloSprite, 0, 30, 20.0, 100.0, 2.0, {0, 100, 250, 100}, 30, 0);
    TE_SendToAll();
    
    for (int i = 0; i <= 300; i += 30)
    {
        TE_SetupBeamRingPoint(fBeamHigh, 0.0, fIonRadius, g_iLaserSprite, g_iHaloSprite, 0, 30, 10.0, 100.0, 5.0, {255, 255, 255, 200}, 300-i, 0);
        TE_SendToAll();
    }
    
    fBeamHigh[2] += 80.0;
    
    for(int i = 0; i <= 300; i += 30)
    {
        TE_SetupBeamRingPoint(fBeamHigh, 0.0, fIonRadius, g_iLaserSprite, g_iHaloSprite, 0, 30, 10.0, 100.0, 5.0, {255, 255, 255, 200}, 300-i, 0);
        TE_SendToAll();
    }
    
    fBeamHigh[2] += 80.0;
    
    for (int i = 0; i <= 300; i += 30)
    {
        TE_SetupBeamRingPoint(fBeamHigh, 0.0, fIonRadius, g_iLaserSprite, g_iHaloSprite, 0, 30, 10.0, 100.0, 5.0, {200, 255, 255, 200}, 300-i, 0);
        TE_SendToAll();
    }
    
    fBeamHigh[2] -= 160.0;
    
    float fMagnitude = Math_GetRandomFloat(g_cIonExplosionMinDamage.FloatValue, g_cIonExplosionMaxDamage.FloatValue);

    int iExplosion = CreateEntityByName("env_explosion");

    if (iExplosion != -1)
    {
        TeleportEntity(iExplosion, g_iPlayer[client].fInfoTargetOrigin, NULL_VECTOR, NULL_VECTOR);
        SetEntProp(iExplosion, Prop_Data, "m_sFireballSprite", g_iExplosionModel);
        SetEntProp(iExplosion, Prop_Data, "m_iMagnitude", RoundToNearest(fMagnitude));
        SetEntProp(iExplosion, Prop_Data, "m_iRadiusOverride", RoundToNearest(fIonRadius));
        SetEntProp(iExplosion, Prop_Data, "m_iCustomDamageType", DMG_BLAST);
        SetEntProp(iExplosion, Prop_Data, "m_nRenderMode", 5);
        SetEntPropEnt(iExplosion, Prop_Data, "m_hOwnerEntity", client);
        DispatchSpawn(iExplosion);
        ActivateEntity(iExplosion);
        AcceptEntityInput(iExplosion, "Explode", client, client);
    }

    float fDust[3];
    TE_SetupSmoke(fBeamHigh, g_iSmokeSprite1, 350.0, 15);
    TE_SetupSmoke(fBeamHigh, g_iSmokeSprite2, 350.0, 15);
    TE_SetupDust(fBeamHigh, fDust, 150.0, 15.0);
    TE_SendToAll();
    
    TE_SetupExplosion(g_iPlayer[client].fInfoTargetOrigin, g_iExplosionModel, 50.0, 30, TE_EXPLFLAG_ROTATE|TE_EXPLFLAG_DRAWALPHA, RoundToNearest(fIonRadius), RoundToNearest(fMagnitude));
    TE_SetupExplosion(fBeamHigh, g_iExplosionModel, 50.0, 30, TE_EXPLFLAG_ROTATE|TE_EXPLFLAG_DRAWALPHA, RoundToNearest(fIonRadius), RoundToNearest(fMagnitude));
    
    fBeamHigh[2] += 500.0;
    TE_SetupExplosion(fBeamHigh, g_iExplosionModel, 50.0, 30, TE_EXPLFLAG_ROTATE|TE_EXPLFLAG_DRAWALPHA, RoundToNearest(fIonRadius), RoundToNearest(fMagnitude));
    
    fBeamHigh[2] -= 100.0;
    fBeamHigh[1] += 600.0;
    TE_SetupExplosion(fBeamHigh, g_iExplosionModel, 50.0, 30, TE_EXPLFLAG_ROTATE|TE_EXPLFLAG_DRAWALPHA, RoundToNearest(fIonRadius), RoundToNearest(fMagnitude));
    
    fBeamHigh[0] -= 1600.0;
    TE_SetupExplosion(fBeamHigh, g_iExplosionModel, 50.0, 30, TE_EXPLFLAG_ROTATE|TE_EXPLFLAG_DRAWALPHA, RoundToNearest(fIonRadius), RoundToNearest(fMagnitude));
    
    fBeamHigh[1] += 600.0;
    TE_SetupExplosion(fBeamHigh, g_iExplosionModel, 50.0, 30, TE_EXPLFLAG_ROTATE|TE_EXPLFLAG_DRAWALPHA, RoundToNearest(fIonRadius), RoundToNearest(fMagnitude));
    
    fBeamHigh[1] -= 600.0;
    fBeamHigh[0] += 600.0;
    TE_SetupExplosion(fBeamHigh, g_iExplosionModel, 50.0, 30, TE_EXPLFLAG_ROTATE|TE_EXPLFLAG_DRAWALPHA, RoundToNearest(fIonRadius), RoundToNearest(fMagnitude));
    TE_SendToAll();
    
    for (float i = 0.6; i <= 12.0; i += 0.6)
    {
        CreateTimer(i, Timer_ShowExplosions, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    
    float fDirection[3] = {-90.0, 0.0, 0.0};

    SpawnShooter(client, fDirection, 0.0, 0.1, fDirection, 1200.0, 5.0, 20.5, g_iPlayer[client].fInfoTargetOrigin, FLARE_MDL);
    SpawnShooter(client, fDirection, 0.0, 0.1, fDirection, 500.0, 5.0, 15.5, g_iPlayer[client].fInfoTargetOrigin, FLARE_MDL);
    
    int iFire = CreateEntityByName("env_fire");

    if (iFire != -1)
    {
        TeleportEntity(iFire, g_iPlayer[client].fInfoTargetOrigin, NULL_VECTOR, NULL_VECTOR);

        DispatchKeyValue(iFire, "health", "5");
        DispatchKeyValue(iFire, "firesize", "3000");
        DispatchKeyValue(iFire, "fireattack", "1");
        DispatchKeyValue(iFire, "firetype", "Normal");
        DispatchKeyValue(iFire, "damagescale", "1");

        SetVariantString("spawnflags 128");
        AcceptEntityInput(iFire,"AddOutput");
        
        DispatchSpawn(iFire);
        
        ActivateEntity(iFire);
        AcceptEntityInput(iFire, "StartFire", client);
    }
    
    EmitSoundToAllAny(SOUND_ATTACK, iEntity, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN);
    
    AcceptEntityInput(iEntity, "Kill");

    g_iPlayer[client].iInfoTargetEntity = -1;
}

Action Timer_ShowExplosions(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    float fMagnitude = Math_GetRandomFloat(g_cIonExplosionMinDamage.FloatValue, g_cIonExplosionMaxDamage.FloatValue);

    for(int x = 0; x <= 30; x += g_CIonExplosionRate.IntValue)
    {
        g_iPlayer[client].fBeamDistance += 1.467;

        if (g_iPlayer[client].fBeamDistance > 350.0)
        {
            g_iPlayer[client].fBeamDistance = 0.0;
        }

        for (int i = 0; i < 8; i++)
        {
            g_iPlayer[client].fBeamDegrees[i] += 30.0;

            if (g_iPlayer[client].fBeamDegrees[i] > 360.0)
            {
                g_iPlayer[client].fBeamDegrees[i] -= 360.0;
            }

            g_fBeamOrigin[client][i][0] = g_iPlayer[client].fInfoTargetOrigin[0] + Sine(g_iPlayer[client].fBeamDegrees[i]) * g_iPlayer[client].fBeamDistance;
            g_fBeamOrigin[client][i][1] = g_iPlayer[client].fInfoTargetOrigin[1] + Cosine(g_iPlayer[client].fBeamDegrees[i]) * g_iPlayer[client].fBeamDistance;
            g_fBeamOrigin[client][i][2] = g_iPlayer[client].fInfoTargetOrigin[2] + 0.0;

            TE_SetupExplosion(g_fBeamOrigin[client][i], g_iExplosionModel, 50.0, 30, TE_EXPLFLAG_ROTATE | TE_EXPLFLAG_DRAWALPHA, RoundToNearest(g_cIonExplosionRadius.FloatValue), RoundToNearest(fMagnitude));
            TE_SendToAll();
        }
    }
}

stock bool TraceRay_PlayerOnly(int entity, int contentsMask, any data)
{
    return entity == data;
}

stock float GetDistanceToSky(int iEntity)
{
    float fTraceEnd[3];
    GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fTraceEnd);

    float fTraceDest[3];
    fTraceDest[0] = fTraceEnd[0];
    fTraceDest[1] = fTraceEnd[1];
    fTraceDest[2] = fTraceEnd[2] + 8192.0;

    float fSkyOrigin[3];
    Handle hTrace = TR_TraceRayEx(fTraceEnd, fTraceDest, CONTENTS_WINDOW | CONTENTS_MONSTER, RayType_EndPoint);

    TR_GetEndPosition(fSkyOrigin, hTrace);

    CloseHandle(hTrace);
    return fSkyOrigin;
}

stock float GetDistance(const float fVec1[3], const float fVec2[3])
{
    float x = fVec1[0] - fVec2[0];
    float y = fVec1[1] - fVec2[1];
    float z = fVec1[2] - fVec2[2];

    return SquareRoot(x * x + y * y + z * z);
}

stock void SpawnShooter(int client, float fAngles[3], float fGibs, float fDelay, float fGibAngles[3], float fVelocity, float fVariance,float fGibLife, float fLocation[3], const char[] sModelType)
{
    int iEnt;

    if ((iEnt = CreateEntityByName("env_shooter")) == -1)
    {
        return;
    }

    if (iEnt > 0 && IsValidEntity(iEnt) && IsValidEdict(iEnt))
    {
        DispatchKeyValueVector(iEnt, "angles", fAngles);
        DispatchKeyValueVector(iEnt, "gibangles", fGibAngles);
        DispatchKeyValueFloat(iEnt, "m_iGibs", fGibs);
        DispatchKeyValueFloat(iEnt, "delay", fDelay);
        DispatchKeyValueFloat(iEnt, "m_flVelocity", fVariance);
        DispatchKeyValueFloat(iEnt, "m_flVariance", fVariance);
        DispatchKeyValueFloat(iEnt, "m_flGibLife", fGibLife);
        DispatchKeyValue(iEnt, "rendermode", "5");
        DispatchKeyValue(iEnt, "shootmodel", sModelType);
        DispatchKeyValue(iEnt, "shootsounds", "-1");

        SetVariantString("spawnflags 4");
        AcceptEntityInput(iEnt,"AddOutput");

        ActivateEntity(iEnt);

        AcceptEntityInput(iEnt, "Shoot", client);

        TeleportEntity(iEnt, fLocation, NULL_VECTOR, NULL_VECTOR);

        CreateTimer(3.0, Timer_KillEntity, EntIndexToEntRef(iEnt));
    }
}

Action Timer_KillEntity(Handle timer, any ref)
{
    int iEnt = EntRefToEntIndex(ref);
    if (iEnt > 0 && IsValidEntity(iEnt))
    {
        char sName[64];
        GetEdictClassname(iEnt, sName, sizeof(sName));

        if (StrEqual(sName, "env_shooter", false) || StrEqual(sName, "gib", false) || StrEqual(sName, "env_sprite", false))
        {
            AcceptEntityInput(iEnt, "kill");
        }
    }
}

stock int PrecacheMaterial(const char[] material)
{
    static int materialNames = INVALID_STRING_TABLE;

    if (materialNames == INVALID_STRING_TABLE)
    {
        if ((materialNames = FindStringTable("Materials")) == INVALID_STRING_TABLE)
        {
            return INVALID_STRING_INDEX;
        }
    }

    int index = FindStringIndex2(materialNames, material);

    if (index == INVALID_STRING_INDEX)
    {
        int numStrings = GetStringTableNumStrings(materialNames);

        if (numStrings >= GetStringTableMaxStrings(materialNames))
        {
            return INVALID_STRING_INDEX;
        }

        index = numStrings;
        AddToStringTable(materialNames, material);
    }

    return index;
}

stock float Math_GetRandomFloat(float min, float max)
{
    return (GetURandomFloat() * (max  - min)) + min;
}

stock bool TTT_ShakeClient(int client, int iCommand = 0, float fAmplitude = 50.0, float fFrequency = 150.0, float fDuration = 3.0)
{
    if (!TTT_IsClientValid(client))
    {
        return false;
    }

    if (iCommand == 1)
    {
        fAmplitude = 0.0;
    }
    else if (fAmplitude <= 0.0)
    {
        return false;
    }

    Handle hMessage = StartMessageOne("Shake", client);

    if (hMessage == INVALID_HANDLE)
    {
        return false;
    }

    if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf)
    {
        PbSetInt(hMessage, "command", iCommand);
        PbSetFloat(hMessage, "local_amplitude", fAmplitude);
        PbSetFloat(hMessage, "frequency", fFrequency);
        PbSetFloat(hMessage, "duration", fDuration);
    }
    else
    {
        BfWriteByte(hMessage, iCommand);
        BfWriteFloat(hMessage, fAmplitude);
        BfWriteFloat(hMessage, fFrequency);
        BfWriteFloat(hMessage, fDuration);
    }

    EndMessage();
    return true;
}

stock int FindStringIndex2(int index, const char[] str)
{
    char sBuffer[1024];

    for (int i = 0; i < GetStringTableNumStrings(index); i++)
    {
        ReadStringTable(index, i, sBuffer, sizeof(sBuffer));

        if (StrEqual(sBuffer, str))
        {
            return i;
        }
    }

    return INVALID_STRING_INDEX;
}

void Frame_ShowBeam(any pack)
{
    view_as<DataPack>(pack).Reset();

    int index = view_as<DataPack>(pack).ReadCell();
    int client = view_as<DataPack>(pack).ReadCell();

    delete view_as<DataPack>(pack);

    if (EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity) < 0 || !IsValidEntity(EntRefToEntIndex(g_iPlayer[client].iInfoTargetEntity)) || !g_iPlayer[client].bShowBeams)
    {
        return;
    }
    
    float fStart[3];
    fStart[0] = g_fBeamOrigin[client][index][0];
    fStart[1] = g_fBeamOrigin[client][index][1];
    fStart[2] = g_iPlayer[client].fSkyOrigin[2];
    
    TE_SetupBeamPoints(fStart, g_fBeamOrigin[client][index], g_iLaserSprite, g_iHaloSprite, 0, 0, 0.08, 30.0, 30.0, 0, 0.0, {255, 255, 255, 255}, 20);
    TE_SendToAll();
    
    TE_SetupGlowSprite(g_fBeamOrigin[client][index], g_iGlowSprite, 0.03, 5.0, 100);
    TE_SendToAll();

    DataPack pack2 = new DataPack();
    pack2.WriteCell(index);
    pack2.WriteCell(client);

    RequestFrame(Frame_ShowBeam, pack2);
}
