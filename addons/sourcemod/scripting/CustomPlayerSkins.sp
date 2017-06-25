#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_NORECEIVESHADOW          (1 << 6)
#define EF_PARENT_ANIMATES          (1 << 9)

#define CPS_NOFLAGS         0
#define CPS_RENDER          (1 << 0)
#define CPS_NOATTACHMENT    (1 << 1) //This will parent, but not bonemerge.
#define CPS_IGNOREDEATH     (1 << 2) //This will prevent the removal of the skin on death.
#define CPS_TRANSMIT        (1 << 3) //This will ignore the hook for Transmit

int g_PlayerModels[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE,...};
int g_TransmitSkin[MAXPLAYERS+1][MAXPLAYERS+1];
int g_SkinFlags[MAXPLAYERS+1];

EngineVersion EVGame;
#define PLUGIN_VERSION              "1.4"
public Plugin myinfo = {
	name = "Custom Player Skins (Core)",
	author = "Mitchell, Root",
	description = "Natives for custom skins to be applied to the players.",
	version = PLUGIN_VERSION,
	url = "mtch.tech"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("CPS_SetSkin", Native_SetSkin);
	CreateNative("CPS_GetSkin", Native_GetSkin);
	CreateNative("CPS_RemoveSkin", Native_RemoveSkin);
	CreateNative("CPS_HasSkin", Native_HasSkin);
	
	CreateNative("CPS_SetTransmit", Native_SetTransmit);
	RegPluginLibrary("CustomPlayerSkins");
	return APLRes_Success;
}

public void OnPluginStart() {
	CreateConVar("sm_custom_player_skins_version", PLUGIN_VERSION, "Custom Player Skins Version", \
											FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	HookEvent("player_death", Event_Death);

	EVGame = GetEngineVersion();

	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			setTransmit(i, 0, 1);
		}
	}
}

public void OnMapStart() {
	SetCvar("sv_disable_immunity_alpha", "1");
}

/**
 * Make sure to delete all the skins! And reset their colors...
 */
public void OnPluginEnd() {
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			RemoveSkin(i, CPS_NOFLAGS);
		}
	}
}

/**
 * Core function to set the player's skin from another plugin.
 */
public int Native_SetSkin(Handle plugin, int args) {
	int client = GetNativeCell(1);
	int skin = INVALID_ENT_REFERENCE;
	if(NativeCheck_IsClientValid(client) && IsPlayerAlive(client)) {
		char sModel[PLATFORM_MAX_PATH];
		GetNativeString(2, sModel, PLATFORM_MAX_PATH);
		int flags = GetNativeCell(3);
		skin = CreatePlayerModelProp(client, sModel, flags);
	}
	return skin;
}

/**
 * Core function to get the player's skin from another plugin.
 * This will return the reference of the entity.
 */
public int Native_GetSkin(Handle plugin, int args) {
	int client = GetNativeCell(1);
	if(NativeCheck_IsClientValid(client)) {
		if(IsValidEntity(g_PlayerModels[client])) {
			return EntRefToEntIndex(g_PlayerModels[client]);
		}
	}
	return INVALID_ENT_REFERENCE;
}

/**
 * Core function to check if the player has a skin.
 */
public int Native_HasSkin(Handle plugin, int args) {
	int client = GetNativeCell(1);
	if(NativeCheck_IsClientValid(client) && IsValidEntity(g_PlayerModels[client])) {
		return true;
	}
	return false;
}

/**
 * Core function to get the player's skin from another plugin.
 * This will reset the player's skin (remove it).
 */
public int Native_RemoveSkin(Handle plugin, int args) {
	int client = GetNativeCell(1);
	if(NativeCheck_IsClientValid(client)) {
		int flags = CPS_NOFLAGS;
		if(args > 1) {
			flags = GetNativeCell(2);
		}
		RemoveSkin(client, flags);
	}
	return INVALID_ENT_REFERENCE;
}

/**
 * CPS_SetTransmit(owner, client, transmit)
 * owner is the player that owns the skin.
 * client is the player that is wanting to see the skin.
 * transmit is a int, depending on the level is the override:
 *   0 - Do not transmit at all.
 *   1 - Transmit only if all other cases pass
 *   2 - Force transmit, bypassing other checks.
 */
public int Native_SetTransmit(Handle plugin, int args) {
	int owner = GetNativeCell(1);
	int client = GetNativeCell(2);
	int transmit = GetNativeCell(3);
	setTransmit(owner, client, transmit);
}

/**
 * This just returns the flags of the skin, probably will never be used..
 */
public int Native_GetFlags(Handle plugin, int args) {
	new client = GetNativeCell(1);
	//I didnt do any checks here for the client to be in game since it is a variable..
	return g_SkinFlags[client];
}

/**
 * When a player dies we should remove the skin, so there isn't a random prop floating.
 */
public Action Event_Death(Handle event, const char[] name, bool dontBroadcast) {
	//Well what about the custom death flags?
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsClientInGame(client)) {
		if(!(g_SkinFlags[client] & CPS_IGNOREDEATH)) {
			RemoveSkin(client, CPS_RENDER); //Why would we change the render of a dead person O_o
		}
	}
}

/**
 * Sets the transmit settings of the skin
 */
public void setTransmit(int owner, int client, int transmit) {
	if(client <= 0) {
		for(int i = 1; i <= MaxClients; i++) {
			setTransmit(owner, i, transmit);
		}
	} else {
		g_TransmitSkin[owner][client] = transmit;
	}
}

/**
 * Creates a prop that will act as the player's model via bonemerging.
 * This prop is not solid, and no bullets will be affected by the skin.
 */
public int CreatePlayerModelProp(int client, char[] sModel, int flags) {
	RemoveSkin(client, CPS_RENDER);
	int skin = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(skin, "model", sModel);
	DispatchKeyValue(skin, "disablereceiveshadows", "1");
	DispatchKeyValue(skin, "disableshadows", "1");
	DispatchKeyValue(skin, "solid", "0");
	DispatchKeyValue(skin, "spawnflags", "256");
	SetEntProp(skin, Prop_Send, "m_CollisionGroup", 11);
	DispatchSpawn(skin);
	SetEntProp(skin, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW|EF_PARENT_ANIMATES);
	SetVariantString("!activator");
	AcceptEntityInput(skin, "SetParent", client, skin);
	if(!(flags & CPS_NOATTACHMENT)) {
		if(EVGame == Engine_CSGO) {
			SetVariantString("primary");
		} else {
			SetVariantString("forward");
		}
		AcceptEntityInput(skin, "SetParentAttachment", skin, skin, 0);
	}
	if(!(flags & CPS_RENDER)) { //Does not have CPS_RENDER flag
		SetEntityRenderColor(client, 255, 255, 255, 0);
		SetEntityRenderMode(client, RENDER_TRANSALPHA);
	}
	g_SkinFlags[client] = flags;
	g_PlayerModels[client] = EntIndexToEntRef(skin);
	//Transmit Settings
	if(!(flags & CPS_TRANSMIT)) {
		SDKHook(skin, SDKHook_SetTransmit, OnShouldDisplay);
	}
	setTransmit(client, client, 0);
	return skin;
}

/**
 * Remove the skin, if it exists, and also set the player back to normal.
 */
public void RemoveSkin(int client, int flags) {
	if(IsValidEntity(g_PlayerModels[client])) {
		AcceptEntityInput(g_PlayerModels[client], "Kill");
	}
	if(!(flags & CPS_RENDER)) {
		SetEntityRenderMode(client, RENDER_NORMAL);
	}
	g_PlayerModels[client] = INVALID_ENT_REFERENCE;
	g_SkinFlags[client] = CPS_NOFLAGS;
	setTransmit(client, 0, 1);
}

/**
 * Displays the skin to everybody but the player and anybody spectating
 * first person of said player.
 */
public Action OnShouldDisplay(int skin, int client) {
	for(int i = 1; i <= MaxClients; i++) {
		if(skin == EntRefToEntIndex(g_PlayerModels[i])) {
			if(g_TransmitSkin[i][client] == 0) {
				return Plugin_Handled;
			}
			break;
		}
	}
	int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	if((target > 0 && target <= MaxClients) && \
		(skin == EntRefToEntIndex(g_PlayerModels[target]))) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

stock bool NativeCheck_IsClientValid(int client) {
	if(client <= 0 || client > MaxClients) {
		ThrowNativeError(SP_ERROR_NATIVE, "Client index %i is invalid", client);
		return false;
	}
	if(!IsClientInGame(client)) {
		ThrowNativeError(SP_ERROR_NATIVE, "Client %i is not in game", client);
		return false;
	}
	return true;
}

stock void SetCvar(char[] cvar, char[] value) {
	ConVar convar = FindConVar(cvar);
	if(convar != null) {
		convar.SetString(value, true, false);
	}
}