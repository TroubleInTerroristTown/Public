/*
 * VPhysics Crash tests by c0rp3n
 *
 * Changelogs:
 * v0.1.0 Initial plugin checks whether players are too close before they die 
 *        and attempts to seperate them.
 *
 * v0.2.0 Correct bounds check to be && not ||, fixed not using the abs value
 *        when calulating the distance to move the player.
 *
 * v0.3.0 Move to using a array instead of an ArrayList to avoid unwanted 
 *        allocations should reduce any negligible performance impacts also 
 *        reduces the amount of iterations by updating the start index at the
 *        start of each frame.
 *
 * v0.4.0 Use SDKHook_OnTakeDamageAlivePost instead of SDKHook_OnTakeDamageAlive
 *        as this stops the hook being fired multiple times and damage
 *        calculation has still not been performed.
 *
 * v1.0.0 Release, slightly altered push distance based on testing, double death
          buffer size incase of respawns, though this should rarely happen.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

public Plugin myinfo =
{
    name = "VPhysics Crash Fix",
    author = "c0rp3n",
    description = "",
    version = "1.0.0",
    url = ""
};

enum struct DeathInfo
{
    float time;
    float pos[2];
}

int g_iDeathCount = 0;
int g_iDeathTimeIndex = 0;
DeathInfo g_deaths[MAXPLAYERS * 2];

public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamageAlivePost, Hook_OnTakeDamageAlive);
}

public void OnClientDisconnent(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamageAlivePost, Hook_OnTakeDamageAlive);
}

public void OnGameFrame()
{
    UpdateDeathTimeIndex();
}

////////////////////////////////////////////////////////////////////////////////
// Events
////////////////////////////////////////////////////////////////////////////////

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_iDeathCount = 0;
    g_iDeathTimeIndex = 0;
}

////////////////////////////////////////////////////////////////////////////////
// Hooks
////////////////////////////////////////////////////////////////////////////////

public void Hook_OnTakeDamageAlive(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    if (float(GetClientHealth(victim)) - damage <= 0.0)
    {
        float pos[3];
        GetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);

        // d* differce along the axis
        // ad* absolute difference
        float dx, dy, adx, ady;
        for (int i = g_iDeathTimeIndex; i < g_iDeathCount; ++i)
        {
            // using manhattan distance here as it is good enough for detection.
            dx = g_deaths[i].pos[0] - pos[0];
            dy = g_deaths[i].pos[1] - pos[1];
            adx = FloatAbs(dx);
            ady = FloatAbs(dy);
            if (adx <= 32.0 && ady <= 32.0)
            {
                // calculate the angle from the death location to the victim
                float theta = ArcTangent2(dx, dy);
                // calculate the distance required to make sure the players are
                // no longer stacked
                float dist = 32.0 + (32.0 - Max(adx, ady));

                // move the victim by the distance in the direction of theta
                pos[0] += dist * Cosine(theta);
                pos[1] += dist * Sine(theta);
                SetEntPropVector(victim, Prop_Send, "m_vecOrigin", pos);

                LogMessage("moved client #%d away from death #%d by %fu (%frad)", victim, i, dist, theta);

                break;
            }
        }

        PushDeath(pos);
    }
}

////////////////////////////////////////////////////////////////////////////////
// Stocks
////////////////////////////////////////////////////////////////////////////////

float Max(float x, float y)
{
    return x > y ? x : y;
}

/*
 * Updates the death time index, this is skip checking against old deaths before
 * a player dies; old deaths are deaths that occured a second earlier atm.
 */
void UpdateDeathTimeIndex()
{
    float time = GetGameTime();
    while (g_iDeathTimeIndex < g_iDeathCount && g_deaths[g_iDeathTimeIndex].time <= time - 1.0)
    {
        ++g_iDeathTimeIndex;
    }
}

/*
 * Adds a new death to the end of the deaths array.
 */
void PushDeath(float[] pos)
{
    g_deaths[g_iDeathCount].time = GetGameTime();
    g_deaths[g_iDeathCount].pos[0] = pos[0];
    g_deaths[g_iDeathCount].pos[1] = pos[1];
    ++g_iDeathCount;
}
