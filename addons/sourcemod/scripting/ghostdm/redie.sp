Redie_OnPluginStart()
{
    AddNormalSoundHook(view_as<NormalSHook>(OnNormalSoundPlayed));

    LoopValidClients(i)
    {
        SDKHook(i, SDKHook_WeaponCanUse, OnWeaponCanUse);
        SDKHook(i, SDKHook_WeaponEquip, OnWeaponCanUse);
        SDKHook(i, SDKHook_TraceAttack, OnTraceAttack);
    }
}

void Redie_OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    SDKHook(client, SDKHook_WeaponEquip, OnWeaponCanUse);
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

void Redie_OnRoundStart()
{
    g_bBlockRedie = false;
    
    LoopValidClients(client)
    {
        ResetRedie(client);
        
        SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
        SDKUnhook(client, SDKHook_TraceAttack, OnTraceAttack);
    }
    
    int ent = MaxClients + 1;
    
    SDKUnhook(ent, SDKHook_EndTouch, OnEntityTouch);
    SDKUnhook(ent, SDKHook_StartTouch, OnEntityTouch);
    SDKUnhook(ent, SDKHook_Touch, OnEntityTouch);
    
    while((ent = FindEntityByClassname(ent, "trigger_multiple")) != -1)
    {
        SDKHook(ent, SDKHook_EndTouch, OnEntityTouch);
        SDKHook(ent, SDKHook_StartTouch, OnEntityTouch);
        SDKHook(ent, SDKHook_Touch, OnEntityTouch);
    }
    
    while((ent = FindEntityByClassname(ent, "func_door")) != -1)
    {
        SDKHook(ent, SDKHook_EndTouch, OnEntityTouch);
        SDKHook(ent, SDKHook_StartTouch, OnEntityTouch);
        SDKHook(ent, SDKHook_Touch, OnEntityTouch);
    }
}

void Redie_OnRoundEnd()
{
    g_bBlockRedie = true;

    LoopValidClients(i)
    {
        ResetRedie(i);
    }
}

void Redie_OnPlayerSpawn(int client)
{
    if(g_bRedie[client])
    {
        ResetRedie(client);
        CreateTimer(0.5, Timer_FixSolids, GetClientUserId(client));
    }
}


void Redie_OnPlayerDeath(int client)
{
    if(CheckCommandAccess(client, "sm_redie", ADMFLAG_CUSTOM4))
    {
        CPrintToChat(client, "%s Gib %s!redie %sein, um als Geist weiterzuspielen.", g_sPluginTag, "{green}", "{lightgreen}");
    }
}

public Action Command_redie(int client, int args)
{
    if(IsClientValid(client))
    {
        if(!IsPlayerAlive(client))
        {
            if(GetClientTeam(client) > CS_TEAM_SPECTATOR)
            {
                if(!g_bBlockRedie)
                {
                    g_bRedie[client] = true;
                    
                    SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
                    SDKUnhook(client, SDKHook_TraceAttack, OnTraceAttack);
                    
                    CS_RespawnPlayer(client);
                    
                    for(int i = CS_SLOT_PRIMARY; i <= CS_SLOT_C4; i++)
                    {
                        int index = -1;
                        
                        while((index = GetPlayerWeaponSlot(client, i)) != -1)
                        {
                            SafeRemoveWeapon(client, index, i);
                        }
                    }

                    SetEntProp(client, Prop_Send, "m_lifeState", 1);
        
                    g_bRedie[client] = true;
        
                    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
                    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
                    
                    LoopValidClients(i)
                    {
                        SetListenOverride(client, i, Listen_Yes);
                        
                        if(IsPlayerAlive(i))
                            SetListenOverride(i, client, Listen_No);
                        else
                            SetListenOverride(i, client, Listen_Yes);
                    }
        
                    CPrintToChat(client, "%s Du bist nun ein Geist.", g_sPluginTag);
                }
                else
                {
                    CPrintToChat(client, "%s Du musst bis zur nächsten Runde warten.", g_sPluginTag);
                }
            }
            else
            {
                CPrintToChat(client, "%s Du musst in einem Team sein, um %s!redie %snutzen zu können.", g_sPluginTag, "{green}", "{lightgreen}");
            }
        }
        else
        {
            CPrintToChat(client, "%s Du musst tot sein, um %s!redie %snutzen zu können.", g_sPluginTag, "{green}", "{lightgreen}");
        }
    }
    
    return Plugin_Handled;
}

public Action Command_reback(int client, int args)
{
    if(IsClientValid(client))
    {
        if(g_bRedie[client])
        {
            int iTeam = GetClientTeam(client);
            
            ChangeClientTeam(client, CS_TEAM_SPECTATOR);
            ChangeClientTeam(client, iTeam);
            
            LoopValidClients(i)
            {
                SetListenOverride(client, i, Listen_Default);
                SetListenOverride(i, client, Listen_Default);
            }
            
            ResetRedie(client);
        }
        else
        {
            CPrintToChat(client, "%s Du musst im %s!redie %ssein, um %s!reback %snutzen zu können.", g_sPluginTag, "{green}", "{lightgreen}", "{green}", "{lightgreen}");
        }
    }
    
    return Plugin_Handled;
}

void Redie_OnPlayerRunCmd(int client, int &buttons)
{
    if(g_bRedie[client])
    {
        buttons &= ~IN_USE;
        
        if(buttons & IN_RELOAD)
        {
            if(!g_bNoclipBlock[client])
            {
                g_bNoclipBlock[client] = true;
                
                SetEntityMoveType(client, MOVETYPE_NOCLIP);
                g_hNoclip[client] = CreateTimer(1.0, Timer_Noclip, client);
                
                CPrintToChat(client, "%s Du hast für %s1 Sekunde %sNoclip.", g_sPluginTag, "{green}", "{lightgreen}");
            }
        }
    }
}

public Action OnWeaponCanUse(int client, int weapon)
{
    if(IsClientValid(client) && g_bRedie[client])
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if(IsClientValid(victim) && g_bRedie[victim])
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public Action OnEntityTouch(int entity, int other)
{
    if(IsClientValid(other) && g_bRedie[other])
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public Action OnNormalSoundPlayed(int[] clients, int &numClients, char[] sample, int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char[] soundEntry, int &seed)
{
    if(IsClientValid(entity) && g_bRedie[entity])
    {
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Timer_FixSolids(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (IsClientValid(client))
    {
        SetEntProp(client, Prop_Data, "m_CollisionGroup", 1);
        SetEntProp(client, Prop_Data, "m_nSolidType", 0);
        SetEntProp(client, Prop_Send, "m_usSolidFlags", 4);

        CPrintToChat(client, "m_CollisionGroup: %d", GetEntProp(client, Prop_Data, "m_CollisionGroup"));
        CPrintToChat(client, "m_nSolidType: %d", GetEntProp(client, Prop_Data, "m_nSolidType"));
        CPrintToChat(client, "m_usSolidFlags: %d", GetEntProp(client, Prop_Send, "m_usSolidFlags"));
    }
}

public Action Timer_Noclip(Handle timer, any client)
{
    if(IsClientValid(client) && g_bRedie[client])
    {
        SetEntityMoveType(client, MOVETYPE_WALK);
        
        g_hNoclipReset[client] = CreateTimer(5.0, Timer_NoclipReset, client);
    }
    
    g_hNoclip[client] = null;
}

public Action Timer_NoclipReset(Handle timer, any client)
{
    if(IsClientValid(client) && g_bRedie[client])
    {
        g_bNoclipBlock[client] = false;
    }
    
    g_hNoclipReset[client] = null;
}

void ResetRedie(int client)
{
    g_bRedie[client] = false;
    g_bNoclipBlock[client] = false;
    
    LoopValidClients(i)
    {
        SetListenOverride(client, i, Listen_Default);
        SetListenOverride(i, client, Listen_Default);
    }

    SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    SDKUnhook(client, SDKHook_TraceAttack, OnTraceAttack);
    
    delete g_hNoclip[client];
    delete g_hNoclipReset[client];
}
