#pragma semicolon 1

#define PLUGIN_VERSION "3.2"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <ttt>

public Plugin myinfo =
{
    name = "No Weapon Fix",
    author = ".#Zipcore",
    description = "",
    version = PLUGIN_VERSION,
    url = ""
};

ConVar cvEnable;
bool g_bEnable;

ConVar cvBlockGrenades;
bool g_bBlockGrenades;

ConVar cvCooldownLimit;
int g_iCooldownLimit;

ConVar cvCooldownHeat;
int g_iCooldownHeat;

ConVar cvFakeItemClass;
int g_iFakeItemClass;

enum struct PlayerData {
    int FakeRef;
    int Cooldown;

    bool Grenade;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

public void OnPluginStart()
{
    CreateConVar("no_weapon_fix_version", PLUGIN_VERSION, "No Weapon Fix Version", FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

    cvEnable = CreateConVar("no_weapon_fix_enable", "1", "Enables this plugin (1: Enable; 0: Disable).");
    g_bEnable = cvEnable.BoolValue;
    cvEnable.AddChangeHook(OnSettingChanged);

    cvBlockGrenades = CreateConVar("no_weapon_fix_block_grenades", "0", "Block all grenades from being throwable (1: Enable; 0: Disable).");
    g_bBlockGrenades = cvBlockGrenades.BoolValue;
    cvBlockGrenades.AddChangeHook(OnSettingChanged);

    cvCooldownLimit = CreateConVar("no_weapon_fix_cooldown_limit", "-5000", "Set this to 0 for instant spam protection.");
    g_iCooldownLimit = cvCooldownLimit.IntValue;
    cvCooldownLimit.AddChangeHook(OnSettingChanged);

    cvCooldownHeat = CreateConVar("no_weapon_fix_cooldown_heat", "100", "Add this amount of heat to the cooldown (heat is reduced by 1 for each OnPlayerRunCmd).");
    g_iCooldownHeat = cvCooldownHeat.IntValue;
    cvCooldownHeat.AddChangeHook(OnSettingChanged);

    cvFakeItemClass = CreateConVar("no_weapon_fix_fake_item_class", "0", "Set to 1 to use weapon_healthshot instead of weapon_decoy as fake items.");
    g_iFakeItemClass = cvFakeItemClass.IntValue;
    cvFakeItemClass.AddChangeHook(OnSettingChanged);

    AutoExecConfig(true, "no_weapon_fix_v32");

    HookEvent("item_equip", Event_ItemEquip);

    LoopValidClients(i)
        OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public int OnSettingChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
    if(convar == cvEnable)
        g_bEnable = view_as<bool>(StringToInt(newValue));
    else if(convar == cvCooldownLimit)
        g_iCooldownLimit = StringToInt(newValue);
    else if(convar == cvCooldownHeat)
        g_iCooldownHeat = StringToInt(newValue);
    else if(convar == cvFakeItemClass)
        g_iFakeItemClass = StringToInt(newValue);
    
    return 0;
}

public Action Event_ItemEquip(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    g_iPlayer[client].Grenade = event.GetInt("weptype") == 8;

    return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon)
{
    int decoy = EntRefToEntIndex(g_iPlayer[client].FakeRef);

    // No fake decoy equipped, let him pickup whatever he wants
    if(decoy <= 0)
    {
        // Fake decoy got removed somehow, give cooldown
        if(g_iPlayer[client].FakeRef > 0)
        {
            g_iPlayer[client].Cooldown += g_iCooldownHeat;
            g_iPlayer[client].FakeRef = 0;
        }
        return Plugin_Continue;
    }

    // Picking up fake decoy
    if(weapon == decoy)
        return Plugin_Continue;

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    // Picking up a deocy, lets remove it and use the fake decoy as a real one
    if((g_iFakeItemClass == 0 && StrEqual(classname, "weapon_decoy")) || (g_iFakeItemClass == 1 && StrEqual(classname, "weapon_healthshot")))
    {
        SetEntProp(client, Prop_Data, "m_bDrawViewmodel", 1);

        AcceptEntityInput(weapon, "Kill");

        g_iPlayer[client].FakeRef = 0;

        return Plugin_Continue;
    }

    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if(!g_bEnable || !IsPlayerAlive(client) || TTT_GetRoundStatus() == Round_Active)
        return Plugin_Continue;

    if(g_iPlayer[client].Cooldown > g_iCooldownLimit)
        g_iPlayer[client].Cooldown--;

    // Get the fake decoy
    int decoy = EntRefToEntIndex(g_iPlayer[client].FakeRef);

    // Check if player has another weapon, thanks to ShaRen
    int iWeapon = decoy;
    for(int i = 0; i < GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons"); i++)
    {
        int ent = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
        if (ent > 0 && ent != decoy) // skip fake decoy
        {
            iWeapon = ent;
            break;
        }
    }

    // No fake decoy needed anymore
    if(iWeapon != decoy && decoy > MaxClients && decoy != INVALID_ENT_REFERENCE)
    {
        SetEntProp(client, Prop_Data, "m_bDrawViewmodel", 1);

        SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", iWeapon);
        ChangeEdictState(client, FindDataMapInfo(client, "m_hActiveWeapon"));

        AcceptEntityInput(decoy, "Kill");

        g_iPlayer[client].FakeRef = 0;
    }
    // Create a new fake decoy
    else if(iWeapon <= 0)
    {
        // Fake decoy got removed somehow, give cooldown
        if(g_iPlayer[client].FakeRef > 0)
        {
            g_iPlayer[client].Cooldown += g_iCooldownHeat;
            g_iPlayer[client].FakeRef = 0;
        }

        if(g_iPlayer[client].Cooldown > 0)
            return Plugin_Continue;

        SetEntProp(client, Prop_Data, "m_bDrawViewmodel", 0);

        if(g_iFakeItemClass == 1)
            iWeapon = GivePlayerItem(client, "weapon_healthshot");
        else iWeapon = GivePlayerItem(client, "weapon_decoy");

        PreventThrowable(client, iWeapon);

        g_iPlayer[client].FakeRef = EntIndexToEntRef(iWeapon);
        decoy = EntRefToEntIndex(g_iPlayer[client].FakeRef);
    }

    // Prevent decoy from being throwable
    if(iWeapon > 0 && (iWeapon == decoy || (g_iPlayer[client].Grenade && g_bBlockGrenades)))
        PreventThrowable(client, iWeapon);

    return Plugin_Continue;
}

public void TTT_OnRoundStart(int id, int i, int t, int d, int m)
{
    RequestFrame(Frame_ResetDrawViewModel);
}

void Frame_ResetDrawViewModel()
{
    LoopValidClients(i)
    {
        if (IsPlayerAlive(i))
        {
            SetEntProp(i, Prop_Data, "m_bDrawViewmodel", 1);
        }
    }
}

void PreventThrowable(int client, int iWeapon)
{
    float fUnlockTime = GetGameTime() + 0.5;

    SetEntPropFloat(client, Prop_Send, "m_flNextAttack", fUnlockTime);
    SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", fUnlockTime);
}
