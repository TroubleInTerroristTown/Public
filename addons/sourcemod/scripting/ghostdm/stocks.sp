stock bool IsClientValid(int client)
{
    if (client > 0 && client <= MaxClients)
    {
        if (!IsClientConnected(client))
        {
            return false;
        }
        
        if (IsClientSourceTV(client))
        {
            return false;
        }

        if (!IsClientInGame(client))
        {
            return false;
        }

        return true;
    }
    return false;
}

stock bool SafeRemoveWeapon(int client, int weapon, int slot)
{
    int iDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
    
    if (iDefIndex < 0 || iDefIndex > 700)
    {
        return false;
    }
    
    if (HasEntProp(weapon, Prop_Send, "m_bInitialized"))
    {
        if (GetEntProp(weapon, Prop_Send, "m_bInitialized") == 0)
        {
            return false;
        }
    }
    
    if (HasEntProp(weapon, Prop_Send, "m_bStartedArming"))
    {
        if (GetEntSendPropOffs(weapon, "m_bStartedArming") > -1)
        {
            return false;
        }
    }
    
    if (GetPlayerWeaponSlot(client, slot) != weapon)
    {
        return false;
    }
    
    if (!RemovePlayerItem(client, weapon))
    {
        return false;
    }
    
    int iWorldModel = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel");
    
    if (IsValidEdict(iWorldModel) && IsValidEntity(iWorldModel))
    {
        if (!AcceptEntityInput(iWorldModel, "Kill"))
        {
            return false;
        }
    }
    
    if (weapon == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"))
    {
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
    }
    
    AcceptEntityInput(weapon, "Kill");
    
    return true;
}
