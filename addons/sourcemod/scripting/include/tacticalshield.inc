/*
*   This file is part of Tactical Shield.
*   Copyright (C) 2017  Keplyx
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU General Public License as published by
*   the Free Software Foundation, either version 3 of the License, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#if defined _tacticalshield_included
 #endinput
#endif

#define _tacticalshield_included

public SharedPlugin __pl_tacticalshield = 
{
	name = "tacticalshield",
	file = "tacticalshield.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public void __pl_tacticalshield_SetNTVOptional()
{
	MarkNativeAsOptional("GivePlayerShield");
	MarkNativeAsOptional("OverridePlayerShield");
	MarkNativeAsOptional("RemovePlayerShield");
	MarkNativeAsOptional("DestroyPlayerShield");
	MarkNativeAsOptional("SetEquipPlayerShield");
	MarkNativeAsOptional("SetHidePlayerShield");
}
#endif

/**
 * Override shield status for the specified player.
 *
 * @param client			Client index.
 * @param override			Override parameter: 0= no override, 1= force no shields, 2= force shields.
 * @return
 * @error					Invalid client.
 */
native void OverridePlayerShield(int client, int override);

/**
 * Give the specified player a shield, if he can have one.
 * It is the same as the command ts_buy but without using money.
 *
 * @param client			Client index.
 * @return
 * @error					Invalid client.
 */
native void GivePlayerShield(int client);

/**
 * Silently remove the shield for the specified player. He won't be able to use it anymore
 *
 * @param client			Client index.
 * @return
 * @error					Invalid client.
 */
native void RemovePlayerShield(int client);

/**
 * Destroy the shield for the specified player. He won't be able to use it anymore.
 * Same as RemovePlayerShield but gives player feedback (sound and message).
 *
 * @param client			Client index.
 * @return
 * @error					Invalid client.
 */
native void DestroyPlayerShield(int client);

/**
 * Force the specified player to equip/unequip the shield.
 *
 * @param client			Client index.
 * @return
 * @error					Invalid client.
 */
native void SetEquipPlayerShield(int client, bool equip);

/**
 * Hide/unhide the shield of the specified player. He will be able to use it again.
 * This removes the shield entity without removing the shield from the player inventory.
 * The player will then be able to use it again when unhidden.
 *
 * @param client			Client index.
 * @return
 * @error					Invalid client.
 */
native void SetHidePlayerShield(int client, bool hide);
