#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_NORECEIVESHADOW          (1 << 6)
#define EF_PARENT_ANIMATES          (1 << 9)

#define CPS_NOFLAGS         0
#define CPS_RENDER          (1 << 0)
#define CPS_NOATTACHMENT    (1 << 1)
#define CPS_IGNOREDEATH     (1 << 2) //This will prevent the removal of the skin on death.

new g_PlayerModels[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE,...};
new g_TransmitSkin[MAXPLAYERS+1][MAXPLAYERS+1];
new g_SkinFlags[MAXPLAYERS+1];

new EngineVersion:EVGame;
#define PLUGIN_VERSION              "1.3.4"
public Plugin:myinfo = {
	name = "Custom Player Skins (Core)",
	author = "Mitchell, Root",
	description = "Natives for custom skins to be applied to the players.",
	version = PLUGIN_VERSION,
	url = "SnBx.info"
}
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Plugin Functions
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	CreateNative("CPS_SetSkin", Native_SetSkin);
	CreateNative("CPS_GetSkin", Native_GetSkin);
	CreateNative("CPS_RemoveSkin", Native_RemoveSkin);
	CreateNative("CPS_HasSkin", Native_HasSkin);
	
	CreateNative("CPS_SetTransmit", Native_SetTransmit);
	RegPluginLibrary("CustomPlayerSkins");
	return APLRes_Success;
}

public OnPluginStart() {
	CreateConVar("sm_custom_player_skins_version", PLUGIN_VERSION, "Custom Player Skins Version", \
											0|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	HookEvent("player_death", Event_Death);

	EVGame = GetEngineVersion();

	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			setTransmit(i);
		}
	}
}

public OnMapStart() {
	SetCvar("sv_disable_immunity_alpha", "1");
}
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------OnPluginEnd		(type: Plugin Function)
	Make sure to delete all the skins! And reset their colors...
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public OnPluginEnd() {
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			RemoveSkin(i);
		}
	}
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Native_SetSkin		(type: Native)
	Core function to set the player's skin from another plugin.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Native_SetSkin(Handle:plugin, args) {
	new client = GetNativeCell(1);
	new skin = INVALID_ENT_REFERENCE;
	if(NativeCheck_IsClientValid(client) && IsPlayerAlive(client)) {
		new String:sModel[PLATFORM_MAX_PATH];
		GetNativeString(2, sModel, PLATFORM_MAX_PATH);
		new flags = GetNativeCell(3);
		skin = CreatePlayerModelProp(client, sModel, flags);
	}
	return skin;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Native_GetSkin		(type: Native)
	Core function to get the player's skin from another plugin.
	This will return the reference of the entity.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Native_GetSkin(Handle:plugin, args) {
	new client = GetNativeCell(1);
	if(NativeCheck_IsClientValid(client)) {
		if(IsValidEntity(g_PlayerModels[client])) {
			return EntRefToEntIndex(g_PlayerModels[client]);
		}
	}
	return INVALID_ENT_REFERENCE;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Native_HasSkin		(type: Native)
	Core function to check if the player has a skin.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Native_HasSkin(Handle:plugin, args) {
	new client = GetNativeCell(1);
	if(NativeCheck_IsClientValid(client) && IsValidEntity(g_PlayerModels[client])) {
		return true;
	}
	return false;
}


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Native_RemoveSkin		(type: Native)
	Core function to get the player's skin from another plugin.
	This will reset the player's skin (remove it).
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Native_RemoveSkin(Handle:plugin, args) {
	new client = GetNativeCell(1);
	if(NativeCheck_IsClientValid(client)) {
		new flags = CPS_NOFLAGS;
		if(args > 1) {
			flags = GetNativeCell(2);
		}
		RemoveSkin(client, flags);
	}
	return INVALID_ENT_REFERENCE;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Native_SetTransmit	(type: Native)
	Core function to set the player's skin from another plugin.
	CPS_SetTransmit( owner, client, transmit )
	owner is the player that owns the skin.
	client is the player that is wanting to see the skin.
	transmit is a int, depending on the level is the override:
		0 - Do not transmit at all.
		1 - Transmit only if all other cases pass
		2 - Force transmit, bypassing other checks.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Native_SetTransmit(Handle:plugin, args) {
	new owner = GetNativeCell(1);
	new client = GetNativeCell(2);
	new transmit = GetNativeCell(3);
	setTransmit(owner, client, transmit);
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Native_GetFlags	(type: Native)
	This just returns the flags of the skin, probably will never be used..
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Native_GetFlags(Handle:plugin, args) {
	new client = GetNativeCell(1);
	//I didnt do any checks here for the client to be in game since it is a variable..
	return g_SkinFlags[client];
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------Event_Death		(type: Event)
	When a player dies we should remove the skin, so there isn't a random
	prop floating.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast) {
	//Well what about the custom death flags?
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsClientInGame(client)) {
		if(!(g_SkinFlags[client] & CPS_IGNOREDEATH)) {
			RemoveSkin(client, CPS_RENDER); //Why would we change the render of a dead person O_o
		}
	}
}
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------setTransmit		(type: Public Function)
	Multiple uses for this function:
		Resetting all of the player's transmit options
		Setting a single option on the variable for a player.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
setTransmit( owner, client = 0, transmit = 1) {
	if(client <= 0) {
		for(new i = 1; i <= MaxClients; i++) {
			setTransmit(owner, i, transmit);
		}
	} else {
		g_TransmitSkin[owner][client] = transmit;
	}
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------CreatePlayerModelProp		(type: Public Function)
	Creates a prop that will act as the player's model via bonemerging.
	This prop is not solid, and no bullets will be affected by the skin.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
CreatePlayerModelProp(client, String:sModel[], flags = CPS_NOFLAGS) {
	RemoveSkin(client, CPS_RENDER);
	new Ent = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(Ent, "model", sModel);
	DispatchKeyValue(Ent, "disablereceiveshadows", "1");
	DispatchKeyValue(Ent, "disableshadows", "1");
	DispatchKeyValue(Ent, "solid", "0");
	DispatchKeyValue(Ent, "spawnflags", "256");
	SetEntProp(Ent, Prop_Send, "m_CollisionGroup", 11);
	DispatchSpawn(Ent);
	SetEntProp(Ent, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW|EF_PARENT_ANIMATES);
	SetVariantString("!activator");
	AcceptEntityInput(Ent, "SetParent", client, Ent, 0);
	if(!(flags & CPS_NOATTACHMENT)) {
		if(EVGame == Engine_CSGO) {
			SetVariantString("primary");
		} else {
			SetVariantString("forward");
		}
		AcceptEntityInput(Ent, "SetParentAttachment", Ent, Ent, 0);
	}
	if(!(flags & CPS_RENDER)) { //Does not have CPS_RENDER flag
		SetEntityRenderColor(client, 255, 255, 255, 0);
		SetEntityRenderMode(client, RENDER_TRANSALPHA);
	}
	g_SkinFlags[client] = flags;
	g_PlayerModels[client] = EntIndexToEntRef(Ent);
	//Transmit Settings
	SDKHook(Ent, SDKHook_SetTransmit, OnShouldDisplay);
	setTransmit(client, client, 0);
	return Ent;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------RemoveSkin		(type: Public Function)
	Remove the skin, if it exists, and also set the player back to normal.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
RemoveSkin(client, flags = CPS_NOFLAGS) {
	if(IsValidEntity(g_PlayerModels[client])) {
		AcceptEntityInput(g_PlayerModels[client], "Kill");
	}
	if(!(flags & CPS_RENDER)) {
		SetEntityRenderMode(client, RENDER_NORMAL);
	}
	g_PlayerModels[client] = INVALID_ENT_REFERENCE;
	g_SkinFlags[client] = CPS_NOFLAGS;
	setTransmit(client);
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------OnShouldDisplay		(type: SDKHooks SetTransmit Function)
	Displays the skin to everybody but the player and anybody spectating
	first person of said player.
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public Action:OnShouldDisplay(Ent, Client) {
	for(new i = 1; i <= MaxClients; i++) {
		if(Ent == EntRefToEntIndex(g_PlayerModels[i])) {
			if(g_TransmitSkin[i][Client] == 0) {
				return Plugin_Handled;
			}
			break;
		}
	}
/*
	if(Ent == EntRefToEntIndex(g_PlayerModels[Client])) {
		return Plugin_Handled;
	}
*/
	new target = GetEntPropEnt(Client, Prop_Send, "m_hObserverTarget");
	if((target > 0 && target <= MaxClients) && \
		(Ent == EntRefToEntIndex(g_PlayerModels[target]))) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
------NativeCheck_IsClientValid		(type: Public Function)
	Not sure who created this, but I ripped it from some where...
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
public NativeCheck_IsClientValid(client) {
	if (client <= 0 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client index %i is invalid", client);
	}
	if (!IsClientInGame(client)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client %i is not in game", client);
	}
	return true;
}

stock SetCvar(String:scvar[], String:svalue[]) {
	SetConVarString(FindConVar(scvar), svalue, true);
}