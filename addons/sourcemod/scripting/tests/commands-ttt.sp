#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ttt>

public void OnPluginStart()
{
    RegConsoleCmd("sm_disableround", Command_DisableRound);
}

public Action Command_DisableRound(int client, int args)
{
    if (args != 1)
    {
        ReplyToCommand(client, "sm_disableround <0/1>");
        return Plugin_Handled;
    }

    char sArg[4];
    GetCmdArg(1, sArg, sizeof(sArg));

    bool status = view_as<bool>(StringToInt(sArg));
    TTT_DisableRounds(status);

    return Plugin_Handled;
}
