#pragma semicolon 1

#define PLUGIN_VERSION "3.2"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

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

int m_hMyWeapons;

int g_iFakeWeaponRef[MAXPLAYERS + 1];
int g_iCooldown[MAXPLAYERS + 1];

int g_bGrenade[MAXPLAYERS + 1];

#define LoopIngameClients(%1) for(int %1=1;%1<=MaxClients;++%1)\
if(IsClientInGame(%1))

public void OnPluginStart()
{
	CreateConVar("no_weapon_fix_version", PLUGIN_VERSION, "No Weapon Fix Version", FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	cvEnable = CreateConVar("no_weapon_fix_enable", "1", "Enables this plugin (1: Enable; 0: Disable).");
	g_bEnable = GetConVarBool(cvEnable);
	HookConVarChange(cvEnable, OnSettingChanged);

	cvBlockGrenades = CreateConVar("no_weapon_fix_block_grenades", "0", "Block all grenades from being throwable (1: Enable; 0: Disable).");
	g_bBlockGrenades = GetConVarBool(cvBlockGrenades);
	HookConVarChange(cvBlockGrenades, OnSettingChanged);

	cvCooldownLimit = CreateConVar("no_weapon_fix_cooldown_limit", "-5000", "Set this to 0 for instant spam protection.");
	g_iCooldownLimit = GetConVarInt(cvCooldownLimit);
	HookConVarChange(cvCooldownLimit, OnSettingChanged);

	cvCooldownHeat = CreateConVar("no_weapon_fix_cooldown_heat", "100", "Add this amount of heat to the cooldown (heat is reduced by 1 for each OnPlayerRunCmd).");
	g_iCooldownHeat = GetConVarInt(cvCooldownHeat);
	HookConVarChange(cvCooldownHeat, OnSettingChanged);

	cvFakeItemClass = CreateConVar("no_weapon_fix_fake_item_class", "0", "Set to 1 to use weapon_healthshot instead of weapon_decoy as fake items.");
	g_iFakeItemClass = GetConVarInt(cvFakeItemClass);
	HookConVarChange(cvFakeItemClass, OnSettingChanged);

	AutoExecConfig(true, "no_weapon_fix_v32");

	m_hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");

	if(m_hMyWeapons == -1)
	{
		char Error[128];
		FormatEx(Error, sizeof(Error), "FATAL ERROR m_hMyWeapons [%d]. Please contact the author.", m_hMyWeapons);
		SetFailState(Error);
	}

	HookEvent("item_equip", Event_ItemEquip);

	LoopIngameClients(i)
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
}

public Action Event_ItemEquip(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	g_bGrenade[client] = GetEventInt(event, "weptype") == 8;
}

public Action OnWeaponCanUse(int client, int weapon)
{
	int decoy = EntRefToEntIndex(g_iFakeWeaponRef[client]);

	// No fake decoy equipped, let him pickup whatever he wants
	if(decoy <= 0)
	{
		// Fake decoy got removed somehow, give cooldown
		if(g_iFakeWeaponRef[client] > 0)
		{
			g_iCooldown[client] += g_iCooldownHeat;
			g_iFakeWeaponRef[client] = 0;
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

		g_iFakeWeaponRef[client] = 0;

		return Plugin_Continue;
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!g_bEnable || !IsPlayerAlive(client))
		return Plugin_Continue;

	if(g_iCooldown[client] > g_iCooldownLimit)
		g_iCooldown[client]--;

	// Get the fake decoy
	int decoy = EntRefToEntIndex(g_iFakeWeaponRef[client]);

	// Check if player has another weapon, thanks to ShaRen
	int iWeapon = decoy;
	for (int j = 0, ent = 0; j < 128; j += 4)
	{
		ent = GetEntDataEnt2(client, m_hMyWeapons + j);
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

		g_iFakeWeaponRef[client] = 0;
	}
	// Create a new fake decoy
	else if(iWeapon <= 0)
	{
		// Fake decoy got removed somehow, give cooldown
		if(g_iFakeWeaponRef[client] > 0)
		{
			g_iCooldown[client] += g_iCooldownHeat;
			g_iFakeWeaponRef[client] = 0;
		}

		if(g_iCooldown[client] > 0)
			return Plugin_Continue;

		SetEntProp(client, Prop_Data, "m_bDrawViewmodel", 0);

		if(g_iFakeItemClass == 1)
			iWeapon = GivePlayerItem(client, "weapon_healthshot");
		else iWeapon = GivePlayerItem(client, "weapon_decoy");

		PreventThrowable(client, iWeapon);

		g_iFakeWeaponRef[client] = EntIndexToEntRef(iWeapon);
		decoy = EntRefToEntIndex(g_iFakeWeaponRef[client]);
	}

	// Prevent decoy from being throwable
	if(iWeapon > 0 && (iWeapon == decoy || (g_bGrenade[client] && g_bBlockGrenades)))
		PreventThrowable(client, iWeapon);

	return Plugin_Continue;
}

void PreventThrowable(int client, int iWeapon)
{
    float fUnlockTime = GetGameTime() + 0.5;

    SetEntPropFloat(client, Prop_Send, "m_flNextAttack", fUnlockTime);
    SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", fUnlockTime);
}
