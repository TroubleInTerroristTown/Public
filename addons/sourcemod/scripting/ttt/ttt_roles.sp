#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <colorlib>
#include <ttt>

public Plugin myinfo =
{
    name = TTT_PLUGIN_NAME ... " - Role Manager",
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

bool g_bIsReady = false;

GlobalForward g_fRolesRegister = null;
GlobalForward g_fRolesReady = null;

enum struct Role
{
    char Key[8];
    int Id;
    float Rarity;
    int MinRequired;
    int MaxAmount;
}

ArrayList g_aInnocentRoles;
ArrayList g_aTraitorRoles;
ArrayList g_aDetectiveRoles;
ArrayList g_aMiscRoles;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("ttt-roles");

    g_fRolesRegister = new GlobalForward("TTT_RolesRegister", ET_Ignore);
    g_fRolesReady = new GlobalForward("TTT_RolesReady", ET_Ignore);

    CreateNative("TTT_IsRolesReady", Native_IsRolesReady);
    CreateNative("TTT_RegisterRole", Native_RegisterRole);
    CreateNative("TTT_GetTeamRoles", Native_GetTeamRoles);
    CreateNative("TTT_GetRoleIDs", Native_GetRoleIDs);
    // GetRoleNameByID
    // GetRoleIDByName

    return APLRes_Success;
}


public void OnPluginStart()
{
    g_aInnocentRoles = new ArrayList(sizeof(Role));
    g_aTraitorRoles = new ArrayList(sizeof(Role));
    g_aDetectiveRoles = new ArrayList(sizeof(Role));
    g_aMiscRoles = new ArrayList(sizeof(Role));
}

public void OnConfigsExecuted()
{
    g_aInnocentRoles.Clear();
    g_aTraitorRoles.Clear();
    g_aDetectiveRoles.Clear();
    g_aMiscRoles.Clear();

    Call_StartForward(g_fRolesRegister);
    Call_Finish();

    g_bIsReady = true;

    Call_StartForward(g_fRolesReady);
    Call_Finish();
}

////////////////////////////////////////////////////////////////////////////////
// Natives
////////////////////////////////////////////////////////////////////////////////

public int Native_IsRolesReady(Handle plugin, int numParams)
{
    return view_as<int>(g_bIsReady);
}

public int Native_RegisterRole(Handle plugin, int numParams)
{
    Role role;
    GetNativeString(1, role.Key, sizeof(Role::Key));
    int team = GetNativeCell(2);
    role.Id = GetNativeCell(3);
    role.Rarity = view_as<float>(GetNativeCell(4));
    role.MinRequired = GetNativeCell(5);
    role.MaxAmount = GetNativeCell(6);

    if (CheckRoleExist(team, role.Id))
    {
        return 0;
    }

    LogMessage("Team: %d, Id: %d, Rarity: %f, MinRequired: %d, MaxAmount: %d, Key: %s", team, role.Id, role.Rarity, role.MinRequired, role.MaxAmount, role.Key);

    if (team == TTT_TEAM_INNOCENT)
    {
        g_aInnocentRoles.PushArray(role, sizeof(role));
    }
    if (team == TTT_TEAM_TRAITOR)
    {
        g_aTraitorRoles.PushArray(role, sizeof(role));
    }
    if (team == TTT_TEAM_DETECTIVE)
    {
        g_aDetectiveRoles.PushArray(role, sizeof(role));
    }
    if (team == TTT_TEAM_MISC)
    {
        g_aMiscRoles.PushArray(role, sizeof(role));
    }

    return 0;
}

public int Native_GetTeamRoles(Handle plugin, int numParams)
{
    int team = GetNativeCell(1);
    int count = GetNativeCell(2);
    int playerCount = GetNativeCell(3);

    int roles[MAXPLAYERS + 1];
    if (team == TTT_TEAM_INNOCENT)
    {
        GetRoles(g_aInnocentRoles, 0, count, playerCount, roles);
    }
    else if (team == TTT_TEAM_TRAITOR)
    {
        GetRoles(g_aTraitorRoles, 0, count, playerCount, roles);
    }
    else if (team == TTT_TEAM_DETECTIVE)
    {
        GetRoles(g_aDetectiveRoles, 0, count, playerCount, roles);
    }
    else if (team == TTT_TEAM_MISC)
    {
        GetRoles(g_aMiscRoles, 0, count, playerCount, roles);
    }

    SetNativeArray(4, roles, count);

    return 0;
}

public int Native_GetRoleIDs(Handle plugin, int numParams)
{
    int team = GetNativeCell(1);
    int size = GetNativeCell(3);

    int roleIDs[32];
    int roleCount = 0;
    if (team == TTT_TEAM_INNOCENT)
    {
        roleCount = GetRoleIDs(g_aInnocentRoles, roleIDs, size);
    }
    else if (team == TTT_TEAM_TRAITOR, size)
    {
        roleCount = GetRoleIDs(g_aTraitorRoles, roleIDs, size);
    }
    else if (team == TTT_TEAM_DETECTIVE)
    {
        roleCount = GetRoleIDs(g_aDetectiveRoles, roleIDs, size);
    }
    else if (team == TTT_TEAM_MISC)
    {
        roleCount = GetRoleIDs(g_aMiscRoles, roleIDs, size);
    }

    SetNativeArray(2, roleIDs, roleCount);

    return roleCount;
}

////////////////////////////////////////////////////////////////////////////////
// Stocks
////////////////////////////////////////////////////////////////////////////////

int Min(int a, int b)
{
    if (a < b)
    {
        return a;
    }
    else
    {
        return b;
    }
}

void GetRoles(ArrayList inRoles, int skip, int count, int playerCount, int outRoles[MAXPLAYERS + 1])
{
    // Fill with default if there are no roles
    if (inRoles.Length == 0)
    {
        skip = count;
    }

    // Add default roles
    for (int i = 0; i < Min(skip, count); ++i)
    {
        outRoles[i] = 0;
    }

    // If there are less 
    if (skip >= count)
    {
        return;
    }

    // Sort roles randomly
    int roleIndex[32];
    int roleCount = 0;
    Role role;
    for (int i = 0; i < inRoles.Length; ++i)
    {
        inRoles.GetArray(i, role);
        
        if (role.MinRequired > playerCount)
        {
            continue;
        }

        for (int j = 0; j < role.MaxAmount; ++j)
        {
            roleIndex[roleCount] = i;
            ++roleCount;
        }
    }

    // Randomly arrange roles
    SortIntegers(roleIndex, roleCount, Sort_Random);

    float roleChances[32];
    // float raritySum = 0.0;

    // Sum and fetchrole
    for (int i = 0; i < roleCount; ++i)
    {
        inRoles.GetArray(roleIndex[i], role);

        roleChances[i] = role.Rarity;
        // raritySum += role.Rarity;
    }

    // Normalise
     /*for (int i = 0; i < roleCount; ++i)
    {
        roleChances[i] = roleChances[i] / raritySum;
    } */

    // Accumlate
    for (int i = 1; i < roleCount; ++i)
    {
        roleChances[i] = roleChances[i] + roleChances[i - 1];
    }

    // Assign random roles
    int roleCounts[MAXPLAYERS + 1] = { 0, ... };
    for (int i = skip; i < count; ++i)
    {
        outRoles[i] = 0;

        if (roleChances[i] == 0.0)
        {
            break;
        }

        float fRandom = GetRandomFloat();
        for (int j = 0; j < roleCount; ++j)
        {
            if (fRandom <= roleChances[i])
            {
                inRoles.GetArray(roleIndex[i], role);

                if (roleCounts[i] >= role.MaxAmount)
                {
                    break;
                }

                outRoles[i] = role.Id;
                ++roleCounts[i];

                break;
            }
        }
    }
}

int GetRoleIDs(ArrayList inRoles, int roles[32], int maxSize)
{
    int roleCount = Min(inRoles.Length, maxSize);
    Role role;
    for (int i = 0; i < roleCount; ++i)
    {
        inRoles.GetArray(i, role);
        roles[i] = role.Id;
    }

    return roleCount;
}

bool CheckRoleExist(int team, int id)
{
    bool bFound = false;
    Role role;

    if (team == TTT_TEAM_INNOCENT)
    {
        for (int i = 0; i < g_aInnocentRoles.Length; i++)
        {
            g_aInnocentRoles.GetArray(i, role, sizeof(role));

            bFound = (role.Id == id);
        }
    }
    if (team == TTT_TEAM_TRAITOR)
    {
        for (int i = 0; i < g_aTraitorRoles.Length; i++)
        {
            g_aTraitorRoles.GetArray(i, role, sizeof(role));

            bFound = (role.Id == id);
        }
    }
    if (team == TTT_TEAM_DETECTIVE)
    {
        for (int i = 0; i < g_aDetectiveRoles.Length; i++)
        {
            g_aDetectiveRoles.GetArray(i, role, sizeof(role));

            bFound = (role.Id == id);
        }
    }
    if (team == TTT_TEAM_MISC)
    {
        for (int i = 0; i < g_aMiscRoles.Length; i++)
        {
            g_aMiscRoles.GetArray(i, role, sizeof(role));

            bFound = (role.Id == id);
        }
    }

    return bFound;
}
