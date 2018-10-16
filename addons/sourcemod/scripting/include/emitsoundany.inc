/**
 * vim: set ts=4 :
 * =============================================================================
 * EmitSoundAny
 * Play sounds in a cross-game friendly way CS:GO and DOTA2 friendly way.
 *
 * EmitSoundAny (C)2014 AlliedModders and Powerlord (Ross Bemrose)
 * SourceMod (C)2004-2007 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: 1.0.3
 */
#if defined _emitsoundany_included
 #endinput
#endif
#define _emitsoundany_included

#include <sdktools>

static bool g_bCheckedEngine = false;
static bool g_bNeedsFakePrecache = false;

stock static int EmitSoundCheckEngineVersion()
{
    if (g_bCheckedEngine)
    {
        return;
    }

    EngineVersion engVersion = GetEngineVersion();

    if (engVersion == Engine_CSGO || engVersion == Engine_DOTA)
    {
        g_bNeedsFakePrecache = true;
    }
    g_bCheckedEngine = true;
}

stock static bool FakePrecacheSoundEx( const char[] szPath )
{
    char szPathStar[PLATFORM_MAX_PATH];
    Format(szPathStar, sizeof(szPathStar), "*%s", szPath);

    AddToStringTable( FindStringTable( "soundprecache" ), szPathStar );
    return true;
}

stock bool PrecacheSoundAny( const char[] szPath, bool preload=false)
{
    EmitSoundCheckEngineVersion();

    if (g_bNeedsFakePrecache)
    {
        return FakePrecacheSoundEx(szPath);
    }
    else
    {
        return PrecacheSound(szPath, preload);
    }
}

stock void EmitSoundAny(const clients[],
                 int numClients,
                 const char[] sample,
                 int entity = SOUND_FROM_PLAYER,
                 int channel = SNDCHAN_AUTO,
                 int level = SNDLEVEL_NORMAL,
                 int flags = SND_NOFLAGS,
                 float volume = SNDVOL_NORMAL,
                 int pitch = SNDPITCH_NORMAL,
                 int speakerentity = -1,
                 const float origin[3] = NULL_VECTOR,
                 const float dir[3] = NULL_VECTOR,
                 bool updatePos = true,
                 float soundtime = 0.0)
{
    EmitSoundCheckEngineVersion();

    char szSound[PLATFORM_MAX_PATH];

    if (g_bNeedsFakePrecache)
    {
        Format(szSound, sizeof(szSound), "*%s", sample);
    }
    else
    {
        strcopy(szSound, sizeof(szSound), sample);
    }

    EmitSound(clients, numClients, szSound, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);
}

stock void EmitSoundToClientAny(int client,
                 const char[] sample,
                 int entity = SOUND_FROM_PLAYER,
                 int channel = SNDCHAN_AUTO,
                 int level = SNDLEVEL_NORMAL,
                 int flags = SND_NOFLAGS,
                 float volume = SNDVOL_NORMAL,
                 int pitch = SNDPITCH_NORMAL,
                 int speakerentity = -1,
                 const float origin[3] = NULL_VECTOR,
                 const float dir[3] = NULL_VECTOR,
                 bool updatePos = true,
                 float soundtime = 0.0)
{
    int[] clients = new int[1];
    clients[0] = client;
    /* Save some work for SDKTools and remove SOUND_FROM_PLAYER references */
    entity = (entity == SOUND_FROM_PLAYER) ? client : entity;
    EmitSoundAny(clients, 1, sample, entity, channel,
    level, flags, volume, pitch, speakerentity,
    origin, dir, updatePos, soundtime);
}

stock void EmitSoundToAllAny(const char[] sample,
                 int entity = SOUND_FROM_PLAYER,
                 int channel = SNDCHAN_AUTO,
                 int level = SNDLEVEL_NORMAL,
                 int flags = SND_NOFLAGS,
                 float volume = SNDVOL_NORMAL,
                 int pitch = SNDPITCH_NORMAL,
                 int speakerentity = -1,
                 const float origin[3] = NULL_VECTOR,
                 const float dir[3] = NULL_VECTOR,
                 bool updatePos = true,
                 float soundtime = 0.0)
{
    int[] clients = new int[MaxClients];
    int total = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            clients[total++] = i;
        }
    }

    if (!total)
    {
        return;
    }

    EmitSoundAny(clients, total, sample, entity, channel,
    level, flags, volume, pitch, speakerentity,
    origin, dir, updatePos, soundtime);
}

stock void EmitAmbientSoundAny(const char[] sample,
                        const float pos[3],
                        int entity = SOUND_FROM_WORLD,
                        int level = SNDLEVEL_NORMAL,
                        int flags = SND_NOFLAGS,
                        float vol = SNDVOL_NORMAL,
                        int pitch = SNDPITCH_NORMAL,
                        float delay = 0.0)
{
    EmitSoundCheckEngineVersion();

    char szSound[PLATFORM_MAX_PATH];

    if (g_bNeedsFakePrecache)
    {
        Format(szSound, sizeof(szSound), "*%s", sample);
    }
    else
    {
        strcopy(szSound, sizeof(szSound), sample);
    }

    EmitAmbientSound(szSound, pos, entity, level, flags, vol, pitch, delay);
}

stock void StopSoundAny(int entity, int channel, const char[] name)
{
    EmitSoundCheckEngineVersion();

    char szSound[PLATFORM_MAX_PATH];

    if (g_bNeedsFakePrecache)
    {
        Format(szSound, sizeof(szSound), "*%s", name);
    }
    else
    {
        strcopy(szSound, sizeof(szSound), name);
    }

    StopSound(entity, channel, szSound);
}
