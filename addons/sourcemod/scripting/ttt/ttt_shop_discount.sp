#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Shop Discounts"

ConVar g_cEnable = null;
ConVar g_cPercents = null;
ConVar g_cFlags = null;

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
	
	TTT_StartConfig("shop_discount");
	CreateConVar("ttt2_shop_discount_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cEnable = AutoExecConfig_CreateConVar("shop_discount_enable", "0", "Enable discounts in shop? (Default: 0)", _, true, 0.0, true, 1.0);
	g_cPercents = AutoExecConfig_CreateConVar("shop_discount_percents", "20", "How much percent discount? It's currently for all items with enabled discount, but we'll add better support with next bigger update.");
	g_cFlags = AutoExecConfig_CreateConVar("shop_discount_flags", "o", "Which flags has access to discount prices? (Default: o)");
	TTT_EndConfig();
}

public Action TTT_OnItemPurchase(int client, int &price, bool &count, const char[] item)
{
	if (!g_cEnable.BoolValue)
	{
		return Plugin_Continue;
	}
	
	char sAccess[18];
	g_cFlags.GetString(sAccess, sizeof(sAccess));
	
	if (TTT_IsClientValid(client) && TTT_HasFlags(client, sAccess) && IsPlayerAlive(client))
	{
		float fPercents = 1.0 + g_cPercents.FloatValue / 100;
		int newPrice = RoundToCeil(price / fPercents);
		price = newPrice;
		
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
