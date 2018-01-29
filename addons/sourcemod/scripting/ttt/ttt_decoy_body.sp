#pragma semicolon 1

#include <sourcemod>
#include <emitsoundany>
#include <multicolors>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Decoy Body"
#define SHORT_NAME "decoyBody"

#define EXPLODE_SOUND1 "weapons/hegrenade/explode3.wav"
#define EXPLODE_SOUND2 "weapons/hegrenade/explode4.wav"
#define EXPLODE_SOUND3 "weapons/hegrenade/explode5.wav"
#define BEEP_SOUND "weapons/hegrenade/beep.wav"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;
ConVar g_cDiscount = null;
ConVar g_cDamage = null;
ConVar g_cExplosionSize = null;
ConVar g_cRealBody = null;
ConVar g_cFakeBody = null;
ConVar g_cRemoveRealBody = null;
ConVar g_cRemoveFakeBody = null;
ConVar g_cInstantExplode = null;
ConVar g_cCountdown = null;
ConVar g_cBeepVolume = null;
ConVar g_cExplosionVolume = null;
ConVar g_cShowMessage = null;

int g_iCountdown[MAXPLAYERS + 1] =  { -1, ... };

bool g_bDecoyBody[MAXPLAYERS + 1] =  { false, ... };

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	LoadTranslations("ttt.phrases");
	
	TTT_StartConfig("decoy_body");
	CreateConVar("ttt2_decoy_body_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("decoy_body_name", "Decoy Body", "The name of this in Shop");
	g_cPrice = AutoExecConfig_CreateConVar("decoy_body_price", "9000", "The amount of credits decoy body costs as traitor. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("decoy_body_sort_prio", "0", "The sorting priority of the decoy body in the shop menu.");
	g_cDiscount = AutoExecConfig_CreateConVar("decoy_body_discount", "0", "Should decoy body discountable?", _, true, 0.0, true, 1.0);
	g_cDamage = AutoExecConfig_CreateConVar("decoy_body_grenade_damage", "99", "The damage the grenade does at the explosions center point. (Def. 99)");
	g_cExplosionSize = AutoExecConfig_CreateConVar("decoy_body_explosion_size", "350", "The size of the explosion. (Def. 350)");
	g_cRealBody = AutoExecConfig_CreateConVar("decoy_body_allow_on_real_body", "1", "Allow decoy bodies with real bodies", _, true, 0.0, true, 1.0);
	g_cFakeBody = AutoExecConfig_CreateConVar("decoy_body_allow_on_fake_body", "1", "Allow decoy bodies with fake bodies", _, true, 0.0, true, 1.0);
	g_cRemoveRealBody = AutoExecConfig_CreateConVar("decoy_body_remove_real_body_on_explosion", "1", "Remove the real body on explosion?", _, true, 0.0, true, 1.0);
	g_cRemoveFakeBody = AutoExecConfig_CreateConVar("decoy_body_remove_fake_body_on_explosion", "1", "Remove the fake body on explosion?", _, true, 0.0, true, 1.0);
	g_cInstantExplode = AutoExecConfig_CreateConVar("decoy_body_instant_explode", "0", "Instant explode for decoy bodies?", _, true, 0.0, true, 1.0);
	g_cCountdown = AutoExecConfig_CreateConVar("decoy_body_countdown", "3", "How much time in seconds until explode?", _, true, 0.0);
	g_cBeepVolume = AutoExecConfig_CreateConVar("decoy_body_beep_volume", "0.6", "Volume of beep sound", _, true, 0.0, true, 1.0);
	g_cExplosionVolume = AutoExecConfig_CreateConVar("decoy_body_explosion_volume", "0.6", "Volume of explosion sound", _, true, 0.0, true, 1.0);
	g_cShowMessage = AutoExecConfig_CreateConVar("decoy_body_show_message", "1", "Show message on decoy body found?", _, true, 0.0, true, 1.0);
	TTT_EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
	PrecacheSoundAny(EXPLODE_SOUND1, true);
	PrecacheSoundAny(EXPLODE_SOUND2, true);
	PrecacheSoundAny(EXPLODE_SOUND3, true);
	PrecacheSoundAny(BEEP_SOUND, true);
}

public void OnConfigsExecuted()
{
	g_cPluginTag = FindConVar("ttt_plugin_tag");
	g_cPluginTag.AddChangeHook(OnConVarChanged);
	g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	

	RegisterItem();
}

public Action TTT_OnItemsReset()
{
	RegisterItem();
}

void RegisterItem()
{
	char sName[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sName, sizeof(sName));
	TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cDiscount.BoolValue);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cPluginTag)
	{
		g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	}
}

public void OnClientDisconnect(int client)
{
	ResetStuff(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);

			if (role != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
			
			if (g_bDecoyBody[client])
			{
				return Plugin_Stop;
			}
			
			g_bDecoyBody[client] = true;
		}
	}
	return Plugin_Continue;
}

public Action TTT_OnBodyChecked(int client, int[] ragdoll)
{
	bool bReal = false;
	int attacker = -1;
	
	if (!StrEqual(ragdoll[AttackerName], "Fake!", false))
	{
		bReal = true;
	}
	
	if (!bReal)
	{
		attacker = GetClientOfUserId(ragdoll[Victim]);
	}
	else
	{
		attacker = GetClientOfUserId(ragdoll[Attacker]);
	}
	
	int body = EntRefToEntIndex(ragdoll[Ent]);
	
	if (TTT_IsClientValid(attacker) && g_bDecoyBody[attacker] && IsValidEntity(body))
	{
		if (!g_cRealBody.BoolValue && bReal)
		{
			return Plugin_Continue;
		}
		
		if (!g_cFakeBody.BoolValue && !bReal)
		{
			return Plugin_Continue;
		}
		
		float fPos[3];
		GetEntPropVector(body, Prop_Send, "m_vecOrigin", fPos);
		fPos[2] += 30;
		EmitAmbientSoundAny(BEEP_SOUND, fPos, body, _, _, g_cBeepVolume.FloatValue);
		
		g_iCountdown[attacker] = g_cCountdown.IntValue;
		
		if (g_cShowMessage.BoolValue)
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "Decoy Body Active", client);
		}
		
		DataPack pack = new DataPack();
		CreateDataTimer(1.0, Timer_DecoyBody, pack, TIMER_FLAG_NO_MAPCHANGE);
		pack.WriteCell(GetClientUserId(attacker));
		pack.WriteCell(EntIndexToEntRef(body));
		pack.WriteCell(bReal);
		
		g_bDecoyBody[attacker] = false;
	}
	
	return Plugin_Continue;
}

public Action Timer_DecoyBody(Handle timer, any pack)
{
	ResetPack(pack);
	
	int attacker = GetClientOfUserId(ReadPackCell(pack));
	int body = EntRefToEntIndex(ReadPackCell(pack));
	bool bReal = view_as<bool>(ReadPackCell(pack));
	
	if (TTT_IsClientValid(attacker) && IsValidEntity(body))
	{
		if (!g_cInstantExplode.BoolValue && g_iCountdown[attacker] > 0)
		{
			g_iCountdown[attacker]--;
			
			float fPos[3];
			GetEntPropVector(body, Prop_Send, "m_vecOrigin", fPos);
			fPos[2] += 30;
			EmitAmbientSoundAny(BEEP_SOUND, fPos);
			
			DataPack pack2 = new DataPack();
			CreateDataTimer(1.0, Timer_DecoyBody, pack2, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			pack2.WriteCell(GetClientUserId(attacker));
			pack2.WriteCell(EntIndexToEntRef(body));
			pack2.WriteCell(bReal);
			
			return Plugin_Stop;
		}
		else if (g_cInstantExplode.BoolValue || g_iCountdown[attacker] == 0)
		{
			if (g_cRemoveRealBody.BoolValue && bReal)
			{
				AcceptEntityInput(body, "Kill");
			}
			
			if (g_cRemoveFakeBody.BoolValue && !bReal)
			{
				AcceptEntityInput(body, "Kill");
			}
			
			CreateExplosion(body);

			ResetStuff(attacker);

			return Plugin_Stop;
		}
	}
	
	return Plugin_Stop;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetStuff(client);
	}
}

void ResetStuff(int client)
{
	g_bDecoyBody[client] = false;
	g_iCountdown[client] = -1;
}

void CreateExplosion(int body)
{
	int entity = -1;
	
	if((entity = CreateEntityByName("env_explosion")) != -1)
	{
		DispatchKeyValue(entity, "rendermode", "5");
		SetEntProp(entity, Prop_Data, "m_iMagnitude", g_cDamage.IntValue);
		SetEntProp(entity, Prop_Data, "m_iRadiusOverride", g_cExplosionSize.IntValue);
		
		float fPos[3];
		GetEntPropVector(body, Prop_Send, "m_vecOrigin", fPos);
		fPos[2] += 30;
		
		DispatchSpawn(entity);
		TeleportEntity(entity, fPos, NULL_VECTOR, NULL_VECTOR);
		
		int iSound = GetRandomInt(1, 3);
		
		if (iSound == 1)
		{
			EmitAmbientSoundAny(EXPLODE_SOUND1, fPos, entity, _, _, g_cExplosionVolume.FloatValue);
		}
		else if (iSound == 2)
		{
			EmitAmbientSoundAny(EXPLODE_SOUND2, fPos, entity, _, _, g_cExplosionVolume.FloatValue);
		}
		else if (iSound == 3)
		{
			EmitAmbientSoundAny(EXPLODE_SOUND3, fPos, entity, _, _, g_cExplosionVolume.FloatValue);
		}
		
		RequestFrame(Frame_TriggerEploxsion, entity);
	}
}

public void Frame_TriggerEploxsion(int entity)
{
	AcceptEntityInput(entity, "explode");
	AcceptEntityInput(entity, "Kill");
}