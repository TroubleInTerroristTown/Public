#include <sourcemod>
#include <ttt>

#define PLUGIN_ITEM_SHORT "testitem"
#define PLUGIN_ITEM_LONG  "Test Item"
#define PLUGIN_ITEM_PRICE 350

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name = "TTT - Custom Item Test",
	author = "whocodes",
	description = "Testing for compilation etc",
	version = "1.0",
	url = "whocodes.pw"
};

public void OnAllPluginsLoaded(){
    if(TTT_IsLoaded()){
        TTT_RegisterCustomItem(PLUGIN_ITEM_SHORT, PLUGIN_ITEM_LONG, PLUGIN_ITEM_PRICE);
    }
}

public void TTT_OnItemPurchased(int client, const char[] item){
    if(TTT_IsValidClient(client) && IsPlayerAlive(client) && (strcmp(item, PLUGIN_ITEM_SHORT) == 0)){
        CPrintToChatClient(client, "It works! Hooray!");
        
        IgniteEntity(client, 5.0);
    }
}