#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <emitsoundany>
#include <colorlib>
#include <ttt>
#include <ttt_bodies>
#include <ttt_shop>
#include <ttt_inventory>

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
ConVar g_cCount = null;
ConVar g_cLimit = null;
ConVar g_cBlockOwnBodyIdentify = null;
ConVar g_cBlockTDecoyIdentify = null;
ConVar g_cNoTraitorDecoyDamage = null;
ConVar g_cSetDecoyOwnBody = null;
ConVar g_cSetDecoyKilledBody = null;
ConVar g_cGiveTraitorDecoyBack = null;

enum struct PlayerData {
    int Countdown;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

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

    TTT_LoadTranslations();
    
    TTT_StartConfig("decoy_body");
    CreateConVar("ttt2_decoy_body_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("decoy_body_name", "Decoy Body", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("decoy_body_price", "9000", "The amount of credits decoy body costs as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("decoy_body_sort_prio", "0", "The sorting priority of the decoy body in the shop menu.");
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
    g_cCount = AutoExecConfig_CreateConVar("decoy_body_count", "2", "Max usages per round for this item (0 - Disabled).");
    g_cLimit = AutoExecConfig_CreateConVar("decoy_body_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cBlockOwnBodyIdentify = AutoExecConfig_CreateConVar("decoy_body_block_own_identify", "1", "Block decoy body identify for own bodies?", _, true, 0.0, true, 1.0);
    g_cBlockTDecoyIdentify = AutoExecConfig_CreateConVar("decoy_body_block_t_identify", "1", "Block decoy body effect if a Traitor identify a decoy body?", _, true, 0.0, true, 1.0);
    g_cNoTraitorDecoyDamage = AutoExecConfig_CreateConVar("decoy_body_block_traitor_decoy_damage", "1", "No traitor damage if decoy body explode?", _, true, 0.0, true, 1.0);
    g_cSetDecoyOwnBody = AutoExecConfig_CreateConVar("decoy_body_set_decoy_own_body", "1", "Activate decoy body on own traitor bodies, when you die with decoy in your inventory?", _, true, 0.0, true, 1.0);
    g_cSetDecoyKilledBody = AutoExecConfig_CreateConVar("decoy_body_set_decoy_killed_body", "1", "Activate decoy body on killed bodies?", _, true, 0.0, true, 1.0);
    g_cGiveTraitorDecoyBack = AutoExecConfig_CreateConVar("decody_body_give_decoy_back", "1", "Give decoy body item back if traitor identified an decoy body.", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);

    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME);
    }
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

    TTT_OnShopReady();
}

public void TTT_OnShopReady()
{
    char sName[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sName, sizeof(sName));
    TTT_RegisterShopItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public void OnClientDisconnect(int client)
{
    ResetStuff(client);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int iTeam = TTT_GetClientTeam(client);

    if (iTeam != TTT_TEAM_TRAITOR)
    {
        return Plugin_Stop;
    }
    
    TTT_AddInventoryItem(client, SHORT_NAME);
    return Plugin_Continue;
}

public void TTT_OnBodyFound(int client, int victim, int victimTeam, int attackerTeam, int entityref, bool silentID)
{
    int entity = EntRefToEntIndex(entityref);

    if (!IsValidEntity(entity))
    {
        return;
    }

    Ragdoll body;
    TTT_GetEntityRefRagdoll(entityref, body);

    int iTeam = TTT_GetClientTeam(client);

    if (g_cGiveTraitorDecoyBack.BoolValue)
    {
        if (body.Explode && iTeam == TTT_TEAM_TRAITOR)
        {
            body.Explode = false;
            TTT_SetRagdoll(body, sizeof(body));

            TTT_AddInventoryItem(client, SHORT_NAME);
            TTT_RemoveItemUsage(client, SHORT_NAME);
        }
    }

    if (g_cBlockOwnBodyIdentify.BoolValue && (client == GetClientOfUserId(body.Victim)))
    {
        return;
    }

    bool bReal = false;
    int attacker = -1;
    
    if (!StrEqual(body.AttackerName, "Fake!", false))
    {
        bReal = true;
    }
    
    if (!bReal)
    {
        attacker = GetClientOfUserId(body.Victim);
    }
    else
    {
        attacker = GetClientOfUserId(body.Attacker);
    }
    
    if (TTT_IsClientValid(attacker) && body.Explode)
    {
        if (!g_cRealBody.BoolValue && bReal)
        {
            return;
        }
        
        if (!g_cFakeBody.BoolValue && !bReal)
        {
            return;
        }

        if (g_cBlockTDecoyIdentify.BoolValue && iTeam == TTT_TEAM_TRAITOR)
        {
            return;
        }
        
        float fPos[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fPos);
        fPos[2] += 30;
        EmitAmbientSoundAny(BEEP_SOUND, fPos, entity, _, _, g_cBeepVolume.FloatValue);
        
        g_iPlayer[attacker].Countdown = g_cCountdown.IntValue;
        
        if (g_cShowMessage.BoolValue)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Decoy Body Active", client);
        }

        body.Explode = false;
        TTT_SetRagdoll(body, sizeof(body));
        
        DataPack pack = new DataPack();
        CreateTimer(1.0, Timer_DecoyBody, pack, TIMER_FLAG_NO_MAPCHANGE);
        pack.WriteCell(GetClientUserId(attacker));
        pack.WriteCell(EntIndexToEntRef(entity));
        pack.WriteCell(bReal);
    }
}

public Action Timer_DecoyBody(Handle timer, DataPack pack)
{
    pack.Reset();
    
    int attacker = GetClientOfUserId(pack.ReadCell());
    int body = EntRefToEntIndex(pack.ReadCell());
    bool bReal = view_as<bool>(pack.ReadCell());

    delete pack;
    
    if (TTT_IsClientValid(attacker) && IsValidEntity(body))
    {
        if (!g_cInstantExplode.BoolValue && g_iPlayer[attacker].Countdown > 0)
        {
            g_iPlayer[attacker].Countdown--;
            
            float fPos[3];
            GetEntPropVector(body, Prop_Send, "m_vecOrigin", fPos);
            fPos[2] += 30;
            EmitAmbientSoundAny(BEEP_SOUND, fPos);
            
            DataPack pack2 = new DataPack();
            CreateTimer(1.0, Timer_DecoyBody, pack2, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            pack2.WriteCell(GetClientUserId(attacker));
            pack2.WriteCell(EntIndexToEntRef(body));
            pack2.WriteCell(bReal);
            
            return Plugin_Stop;
        }
        else if (g_cInstantExplode.BoolValue || g_iPlayer[attacker].Countdown == 0)
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

public Action OnTraceAttack(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    char sName[32];
    GetEntPropString(inflictor, Prop_Send, "m_iName", sName, sizeof(sName));

    if (StrContains(sName, "decoybody", false) == -1)
    {
        return Plugin_Continue;
    }

    if (!g_cNoTraitorDecoyDamage.BoolValue)
    {
        TTT_LogString("-> [%N got %.0f damage from decoy body.]", iVictim, damage);
        return Plugin_Continue;
    }

    if (TTT_IsClientValid(iVictim) && IsValidEntity(inflictor))
    {
        char sClass[32];
        GetEntityClassname(inflictor, sClass, sizeof(sClass));

        if (StrEqual(sClass, "env_explosion", false) && TTT_GetClientTeam(iVictim) == TTT_TEAM_TRAITOR)
        {
            damage = 0.0;
            return Plugin_Changed;
        }
    }
    
    TTT_LogString("-> [%N got %.0f damage from decoy body.]", iVictim, damage);
    return Plugin_Continue;
}

public void TTT_OnClientDeath(int victim, int attacker, bool badAction)
{
    if (g_cSetDecoyKilledBody.BoolValue && TTT_IsItemInInventory(attacker, SHORT_NAME))
    {
        Ragdoll body;
        TTT_GetClientRagdoll(victim, body);

        if (!body.Explode)
        {
            body.Explode = true;
            TTT_SetRagdoll(body, sizeof(body));

            TTT_RemoveInventoryItem(attacker, SHORT_NAME);
            TTT_AddItemUsage(attacker, SHORT_NAME);
        }
    }
    else if (g_cSetDecoyOwnBody.BoolValue && TTT_IsItemInInventory(victim, SHORT_NAME))
    {
        Ragdoll body;
        TTT_GetClientRagdoll(victim, body);

        if (!body.Explode)
        {
            body.Explode = true;
            TTT_SetRagdoll(body, sizeof(body));

            TTT_RemoveInventoryItem(victim, SHORT_NAME);
            TTT_AddItemUsage(victim, SHORT_NAME);
        }
    }
}

void ResetStuff(int client)
{
    g_iPlayer[client].Countdown = -1;
}

void CreateExplosion(int body)
{
    int entity = -1;
    
    if((entity = CreateEntityByName("env_explosion")) != -1)
    {
        DispatchKeyValue(entity, "rendermode", "5");

        char sName[32];
        FormatEx(sName, sizeof(sName), SHORT_NAME ... "%d", body);
        DispatchKeyValue(entity, "targetname", sName);
        
        SetEntProp(entity, Prop_Data, "m_iMagnitude", g_cDamage.IntValue);
        SetEntProp(entity, Prop_Data, "m_iRadiusOverride", g_cExplosionSize.IntValue);
        
        float fPos[3];
        GetEntPropVector(body, Prop_Send, "m_vecOrigin", fPos);
        fPos[2] += 30;
        
        TeleportEntity(entity, fPos, NULL_VECTOR, NULL_VECTOR);
        DispatchSpawn(entity);
        
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
        
        RequestFrame(Frame_TriggerEploxsion, EntIndexToEntRef(entity));
    }
}

public void Frame_TriggerEploxsion(any ref)
{
    int iEntity = EntRefToEntIndex(ref);

    if (IsValidEntity(iEntity))
    {
        AcceptEntityInput(iEntity, "explode");
        AcceptEntityInput(iEntity, "Kill");

        TTT_RemoveRagdollFromArray(iEntity);
    }
}
