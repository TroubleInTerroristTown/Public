#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public void OnPluginStart()
{
    HookEvent("weapon_fire", Event_WeaponFire);
    AddNormalSoundHook(SoundHook);
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    PrintToChatAll("Event_WeaponFire");
}

public Action SoundHook(int clients[64], int &numClients, char sound[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
    PrintToChatAll("SoundHook - %s", sound);
    return Plugin_Stop;
}