/*
*   This file is part of Cameras and Drones.
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

#if defined _camerasanddrones_included
 #endinput
#endif

#define _camerasanddrones_included

public SharedPlugin __pl_camerasanddrones = 
{
	name = "cameras-and-drones",
	file = "cameras-and-drones.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public void __pl_camerasanddrones_SetNTVOptional()
{
	MarkNativeAsOptional("BuyPlayerGear");
	MarkNativeAsOptional("OverridePlayerGear");
	MarkNativeAsOptional("IsPlayerInGear");
}
#endif

/**
 * Give player the gear (camera or drone) depending on its team
 * It is the same as the command cd_buy but without using money.
 *
 * @param client		Client index.
 * @return
 * @error				Invalid client.
 */
native void BuyPlayerGear(int client);

/**
 * Override the gear for the specified player.
 *
 * @param client		Client index.
 * @param override		Override parameter: -1= no gear, 0= no override, 1= force cameras, 2= force drones.
 * @return
 * @error				Invalid client.
 */
native void OverridePlayerGear(int client, int override);

/**
 * Checks if the specified player is using his gear.
 *
 * @param client		Client index.
 * @return				True if the plyer if using his gear, false otherwise.
 * @error				Invalid client.
 */
native bool IsPlayerInGear(int client);