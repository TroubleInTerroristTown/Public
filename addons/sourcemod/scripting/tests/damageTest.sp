#include <sourcemod>
#include <sdkhooks>
#include <ttt>

public void OnPluginStart()
{
    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public Action OnTakeDamageAlive(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
    if (TTT_IsClientValid(attacker))
    {
        PrintToChat(attacker, "Damage Type: %d", damagetype);

        if (damagetype & (1 << 30))
        {
            PrintToChat(attacker, "Damage Type is 1 << 30");
        }
        else if (damagetype & (1 << 31))
        {
            PrintToChat(attacker, "Damage Type is 1 << 31");
        }
    }
    
    return Plugin_Continue;
}
