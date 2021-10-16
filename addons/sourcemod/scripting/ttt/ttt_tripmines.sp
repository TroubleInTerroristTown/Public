#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colorlib>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Tripmines"

#define SHORT_NAME_T "tripmines"

#define TRACE_START 24.0
#define TRACE_END 64.0

#define MDL_LASER "materials/sprites/purplelaser1.vmt"

#define SND_MINEPUT "weapons/g3sg1/g3sg1_slideback.wav"
#define SND_MINEACT "items/nvg_on.wav"

#define DEFAULT_MODEL "models/tripmine/tripmine.mdl"

ConVar g_cPluginTag = null;
ConVar g_cMeleeWeapon = null;
ConVar g_cLongName = null;
ConVar g_cPrice = null;
ConVar g_cLimit = null;
ConVar g_cPrio = null;
ConVar g_cAmount = null;
ConVar g_cCount = null;
ConVar g_cTDamage = null;
ConVar g_cOwnDamage = null;
ConVar g_cUsage = null;
ConVar g_cUsageCooldown = null;
ConVar g_cActTime = null;
ConVar g_cColor = null;
ConVar g_cRandomColor = null;
ConVar g_cRadius = null;
ConVar g_cDamage = null;

int g_iCount = 0;

char g_sPluginTag[64];
char g_sMeleeWeapon[64];

float g_fCooldown[MAXPLAYERS + 1];

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

    TTT_StartConfig("tripmines");
    CreateConVar("ttt2_tripmines_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("tripmines_name", "Tripmines", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("tripmines_price", "9000", "The amount of credits a tripmines costs as detective. 0 to disable.");
    g_cLimit = AutoExecConfig_CreateConVar("tripmines_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPrio = AutoExecConfig_CreateConVar("tripmines_sort_prio", "0", "The sorting priority of the tripmines in the shop menu.");
    g_cAmount = AutoExecConfig_CreateConVar("tripmines_mines", "1", "How mines get the player?", _, true, 1.0);
    g_cCount = AutoExecConfig_CreateConVar("tripmines_count", "1", "Amount of purchases for tripmines per round");
    g_cTDamage = AutoExecConfig_CreateConVar("tripmines_traitor_damage", "1", "Block damage for other traitors", _, true, 0.0, true, 1.0);
    g_cOwnDamage = AutoExecConfig_CreateConVar("tripmines_own_damage", "1", "Block own damage as tripmine owner", _, true, 0.0, true, 1.0);
    g_cUsage = AutoExecConfig_CreateConVar("tripmines_usage", "0", "Determinate if player should place mines with sm_tripmine command (0) or if they can place (left click) it using start malee weapon from ttt core ( ttt_start_melee_weapon ) (1)", _, true, 0.0, true, 1.0);
    g_cUsageCooldown = AutoExecConfig_CreateConVar("tripmines_usage_cooldown", "1", "Determinate how fast player can place another mine. Min value is 1 second.", _, true, 1.0, false, 0.0);
    g_cActTime = AutoExecConfig_CreateConVar("tripmines_activate_time", "3.0");
    g_cColor = AutoExecConfig_CreateConVar("tripmines_beam_color", "255 0 0", "RGB Color for the sBeam but tripmines_random_beam_color must be on 0 (Example: \"R G B\" or as color code: \"255 0 0 \" for red sBeam");
    g_cRandomColor = AutoExecConfig_CreateConVar("tripmines_random_beam_color", "0", "Determinate if beam from mines will get random colors 1 if true 0 otherwise.", _, true, 0.0, true, 1.0);
    g_cRadius = AutoExecConfig_CreateConVar("tripmines_radius", "256", "The explosion radius in units for tripmines", _, true, 60.0);
    g_cDamage = AutoExecConfig_CreateConVar("tripmines_damage", "550", "The explosion damage for tripmines", _, true, 100.0);
    TTT_EndConfig();

    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    g_cMeleeWeapon = FindConVar("ttt_start_melee_weapon");
    g_cMeleeWeapon.AddChangeHook(OnConVarChanged);
    g_cMeleeWeapon.GetString(g_sMeleeWeapon, sizeof(g_sMeleeWeapon));

    RegisterItem();
    
    if (!g_cUsage.BoolValue)
    {
        RegConsoleCmd("sm_tripmine", Command_TripMine);
    }
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
    else if (convar == g_cMeleeWeapon)
    {
        g_cMeleeWeapon.GetString(g_sMeleeWeapon, sizeof(g_sMeleeWeapon));
    }
}

public void OnMapStart()
{
    PrecacheModel(DEFAULT_MODEL);
    PrecacheModel(MDL_LASER, true);

    AddFileToDownloadsTable("models/tripmine/tripmine.dx90.vtx");
    AddFileToDownloadsTable("models/tripmine/tripmine.mdl");
    AddFileToDownloadsTable("models/tripmine/tripmine.phy");
    AddFileToDownloadsTable("models/tripmine/tripmine.vvd");
    AddFileToDownloadsTable("materials/models/tripmine/minetexture.vmt");
    AddFileToDownloadsTable("materials/models/tripmine/minetexture.vtf");

    PrecacheSound(SND_MINEPUT, true);
    PrecacheSound(SND_MINEACT, true);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_T);
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
    {
        return Plugin_Stop;
    }

    if (!g_cUsage.BoolValue)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Place Tripmine", client);
    }

    TTT_AddInventoryItem(client, SHORT_NAME_T, g_cAmount.IntValue);
    return Plugin_Continue;
}

public Action OnTraceAttack(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
    if ((g_cTDamage.BoolValue || g_cOwnDamage.BoolValue) && IsValidEntity(inflictor))
    {
        char sModel[PLATFORM_MAX_PATH + 1];
        GetEntPropString(inflictor, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
        
        if (StrContains(sModel, "tripmine.mdl", false) != -1)
        {
            if (g_cOwnDamage.BoolValue && victim == attacker)
            {
                return Plugin_Handled;
            }

            if (g_cTDamage.BoolValue && attacker != victim && TTT_GetClientRole(victim) == TTT_TEAM_TRAITOR)
            {
                return Plugin_Handled;
            }
        }
    }

    return Plugin_Continue;
}

public Action Command_TripMine(int client, int args)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Handled;
    }

    if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
    {
        return Plugin_Handled;
    }

    if (TTT_GetClientItemQuantity(client, SHORT_NAME_T) < 1)
    {
        CPrintToChat(client, "%T", "No tripmines", client);
        return Plugin_Handled;
    }
    
    SetMine(client);
    return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	if(!TTT_IsClientValid(client) || !IsPlayerAlive(client) || TTT_GetRoundStatus() != Round_Active || !g_cUsage.BoolValue)
    {
        return Plugin_Continue;
    }

	if(buttons & IN_ATTACK && TTT_GetClientItemQuantity(client, SHORT_NAME_T) > 0 && GetGameTime() > g_fCooldown[client]) {
        int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

        if (!IsValidEntity(iWeapon))
        {
            return Plugin_Continue;
        }

        char sWeapon[32];
        GetEntityClassname(iWeapon, sWeapon, sizeof(sWeapon));

        if(StrEqual(sWeapon, g_sMeleeWeapon, false)) {
            SetMine(client);

            buttons |= IN_ATTACK;
            return Plugin_Changed;
        }
	}
	
	return Plugin_Continue;
}

void SetMine(int client)
{
    char sBeam[64];
    char sBeamMDL[64];
    char sBuffer[128];
    
    Format(sBeam, sizeof(sBeam), "tmbeam%d", g_iCount);
    Format(sBeamMDL, sizeof(sBeamMDL), "tmbeammdl%d", g_iCount);
    
    if (++g_iCount > 10000)
    {
        g_iCount = 1;
    }

    float fStart[3];
    float fAngle[3];
    float fEnd[3];
    float fAngles[3];
    float fBeamEnd[3];
    GetClientEyePosition(client, fStart);
    GetClientEyeAngles(client, fAngle);
    GetAngleVectors(fAngle, fEnd, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(fEnd, fEnd);

    fStart[0] = fStart[0] + fEnd[0] * TRACE_START;
    fStart[1] = fStart[1] + fEnd[1] * TRACE_START;
    fStart[2] = fStart[2] + fEnd[2] * TRACE_START;
    
    fEnd[0] = fStart[0] + fEnd[0] * TRACE_END;
    fEnd[1] = fStart[1] + fEnd[1] * TRACE_END;
    fEnd[2] = fStart[2] + fEnd[2] * TRACE_END;
    
    TR_TraceRayFilter(fStart, fEnd, CONTENTS_SOLID, RayType_EndPoint, FilterAll, 0);

    g_fCooldown[client] = GetGameTime() + g_cUsageCooldown.FloatValue;
    
    if (TR_DidHit(null))
    {
        TTT_RemoveInventoryItem(client, SHORT_NAME_T);

        TR_GetEndPosition(fEnd, null);
        TR_GetPlaneNormal(null, fAngles);
        GetVectorAngles(fAngles, fAngles);

        TR_TraceRayFilter(fEnd, fAngles, CONTENTS_SOLID, RayType_Infinite, FilterAll, 0);
        TR_GetEndPosition(fBeamEnd, null);

        int iBeamMDL = CreateEntityByName("prop_dynamic_override");
        SetEntityModel(iBeamMDL, DEFAULT_MODEL);
        DispatchKeyValue(iBeamMDL, "StartDisabled", "false");
        DispatchSpawn(iBeamMDL);
        TeleportEntity(iBeamMDL, fEnd, fAngles, NULL_VECTOR);
        SetEntProp(iBeamMDL, Prop_Data, "m_usSolidFlags", 152);
        SetEntProp(iBeamMDL, Prop_Data, "m_CollisionGroup", 1);
        SetEntityMoveType(iBeamMDL, MOVETYPE_NONE);
        SetEntProp(iBeamMDL, Prop_Data, "m_MoveCollide", 0);
        SetEntProp(iBeamMDL, Prop_Data, "m_nSolidType", 6);
        SetEntPropEnt(iBeamMDL, Prop_Data, "m_hLastAttacker", client);
        DispatchKeyValue(iBeamMDL, "targetname", sBeamMDL);
        g_cRadius.GetString(sBuffer, sizeof(sBuffer));
        DispatchKeyValue(iBeamMDL, "ExplodeRadius", sBuffer);
        g_cDamage.GetString(sBuffer, sizeof(sBuffer));
        DispatchKeyValue(iBeamMDL, "ExplodeDamage", sBuffer);
        Format(sBuffer, sizeof(sBuffer), "%s,Break,,0,-1", sBeamMDL);
        DispatchKeyValue(iBeamMDL, "OnHealthChanged", sBuffer);
        Format(sBuffer, sizeof(sBuffer), "%s,Kill,,0,-1", sBeam);
        DispatchKeyValue(iBeamMDL, "OnBreak", sBuffer);
        SetEntProp(iBeamMDL, Prop_Data, "m_takedamage", 2);
        AcceptEntityInput(iBeamMDL, "Enable");
        HookSingleEntityOutput(iBeamMDL, "OnBreak", MineBreak, true);

        int iBeam = CreateEntityByName("env_beam");
        TeleportEntity(iBeam, fBeamEnd, NULL_VECTOR, NULL_VECTOR);
        SetEntityModel(iBeam, MDL_LASER);
        DispatchKeyValue(iBeam, "texture", MDL_LASER);
        DispatchKeyValue(iBeam, "targetname", sBeam);
        DispatchKeyValue(iBeam, "TouchType", "4");
        DispatchKeyValue(iBeam, "LightningStart", sBeam);
        DispatchKeyValue(iBeam, "BoltWidth", "4.0");
        DispatchKeyValue(iBeam, "life", "0");
        DispatchKeyValue(iBeam, "rendercolor", "0 0 0");
        DispatchKeyValue(iBeam, "renderamt", "0");
        DispatchKeyValue(iBeam, "HDRColorScale", "1.0");
        DispatchKeyValue(iBeam, "decalname", "Bigshot");
        DispatchKeyValue(iBeam, "StrikeTime", "0");
        DispatchKeyValue(iBeam, "TextureScroll", "35");
        Format(sBuffer, sizeof(sBuffer), "%s,Break,,0,-1", sBeamMDL);
        DispatchKeyValue(iBeam, "OnTouchedByEntity", sBuffer);     
        SetEntPropVector(iBeam, Prop_Data, "m_vecEndPos", fEnd);
        SetEntPropFloat(iBeam, Prop_Data, "m_fWidth", 4.0);
        AcceptEntityInput(iBeam, "TurnOff");

        DataPack pack = new DataPack();
        CreateTimer(g_cActTime.FloatValue, Timer_TurnBeamOn, pack);

        pack.WriteCell(GetClientUserId(client));
        pack.WriteCell(EntIndexToEntRef(iBeamMDL));
        pack.WriteCell(EntIndexToEntRef(iBeam));
        pack.WriteFloat(fEnd[0]);
        pack.WriteFloat(fEnd[1]);
        pack.WriteFloat(fEnd[2]);

        EmitSoundToAll(SND_MINEPUT, iBeamMDL);

        PrintHintText(client, "%T", "Remaining Tripmines", client, TTT_GetClientItemQuantity(client, SHORT_NAME_T));
    }
    else
    {
        PrintHintText(client, "%T", "Invalid location", client);
    }
}

public Action Timer_TurnBeamOn(Handle timer, DataPack pack)
{
    pack.Reset();

    int client = GetClientOfUserId(pack.ReadCell());
    int iBeamMDL = EntRefToEntIndex(pack.ReadCell());
    int iBeam = EntRefToEntIndex(pack.ReadCell());

    if ((client > 0 && client < MaxClients && IsClientInGame(client)) && IsValidEntity(iBeamMDL) && IsValidEntity(iBeam))
    {
        char sColor[18];

        if (g_cRandomColor.BoolValue)
        {
            Format(sColor, sizeof(sColor), "%i %i %i", GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255));
        }
        else
        {
            g_cColor.GetString(sColor, sizeof(sColor));
        }

        DispatchKeyValue(iBeam, "rendercolor", sColor);
        AcceptEntityInput(iBeam, "TurnOn");

        float fEnd[3];
        fEnd[0] = pack.ReadFloat();
        fEnd[1] = pack.ReadFloat();
        fEnd[2] = pack.ReadFloat();

        EmitSoundToAll(SND_MINEACT, iBeamMDL);
    }

    delete pack;
}

public void MineBreak(const char[] output, int caller, int activator, float delay)
{
    UnhookSingleEntityOutput(caller, "OnBreak", MineBreak);
    AcceptEntityInput(caller,"kill");
}

public bool FilterAll(int entity, int contentsMask)
{
    return false;
}
