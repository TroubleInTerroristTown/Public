#pragma semicolon 1

#include <ttt>
#include <profiler>

public void OnPluginStart()
{
    RegAdminCmd("sm_role", Command_Role, ADMFLAG_ROOT);
}

public Action Command_Role(int client, int args)
{
    int count = 5000;

    Handle hProfiler = CreateProfiler();
    StartProfiling(hProfiler);

    for (int i = 1; i <= count; i++)
    {
        char sRole[ROLE_LENGTH];
        TTT_GetRoleNameByID(TTT_GetClientRole(client), sRole, sizeof(sRole));
    }

    StopProfiling(hProfiler);
    float fNative = GetProfilerTime(hProfiler);




    hProfiler = CreateProfiler();
    StartProfiling(hProfiler);

    for (int i = 1; i <= count; i++)
    {
        char sRole[ROLE_LENGTH];
        GetRoleNameByID(TTT_GetClientRole(client), sRole, sizeof(sRole));
    }

    StopProfiling(hProfiler);
    float fStock = GetProfilerTime(hProfiler);
    ReplyToCommand(client, "Native time for %d requests: %f", count, fNative);
    ReplyToCommand(client, "Stock time for %d requests: %f", count, fStock);

    delete hProfiler;
    return Plugin_Continue;
}

void GetRoleNameByID(int role, char[] sRole, int length)
{
    if (role == TTT_TEAM_INNOCENT)
    {
        Format(sRole, length, "Innocent");
    }
    else if (role == TTT_TEAM_DETECTIVE)
    {
        Format(sRole, length, "Detective");
    }
    else if (role == TTT_TEAM_TRAITOR)
    {
        Format(sRole, length, "Traitor");
    }
    else
    {
        Format(sRole, length, "Unassigned");
    }
}
