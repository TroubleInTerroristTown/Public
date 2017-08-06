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

#include <sdktools>
#include <menus>

#include "cameras-and-drones/dronemanager.sp"

Menu playerDroneMenus[MAXPLAYERS + 1];

public void Menu_Drones(int client_index, int args)
{
	playerDroneMenus[client_index] = new Menu(MenuHandler_Drones);
	playerDroneMenus[client_index].SetTitle("Your drones");
	char playerName[64], name[64], ownerName[64], num[8];
	int droneNum;
	for (int i = 0; i < dronesList.Length; i++)
	{
		int owner = dronesOwnerList.Get(i);
		GetClientName(owner, ownerName, sizeof(ownerName));
		GetClientName(client_index, playerName, sizeof(playerName));
		if (StrEqual(ownerName, playerName, false) && args == droneNum)
		{
			Format(name, sizeof(name), "Active");
			Format(num, sizeof(num), "%i", -1);
			playerDroneMenus[client_index].AddItem(num, name, ITEMDRAW_DISABLED);
			droneNum++;
		}
		else if (StrEqual(ownerName, playerName, false))
		{
			Format(name, sizeof(name), "Use Drone", droneNum);
			Format(num, sizeof(num), "%i", droneNum);
			playerDroneMenus[client_index].AddItem(num, name);
			droneNum++;
		}
	}
	playerDroneMenus[client_index].ExitButton = true;
	playerDroneMenus[client_index].Display(client_index, MENU_TIME_FOREVER);
}

public int MenuHandler_Drones(Menu menu, MenuAction action, int param1, int params)
{
	if (action == MenuAction_Select)
	{
		char infoBuffer[64];
		menu.GetItem(params, infoBuffer, sizeof(infoBuffer));
		int drone = StringToInt(infoBuffer, 10);
		if (drone < dronesList.Length)
		{
			int droneNum = 0;
			char playerName[64];
			GetClientName(param1, playerName, sizeof(playerName));
			for (int i = 0; i < dronesList.Length; i++)
			{
				char ownerName[64];
				int owner = dronesOwnerList.Get(i);
				GetClientName(owner, ownerName, sizeof(ownerName));
				if (StrEqual(ownerName, playerName, false) && droneNum == drone)
				{
					TpToDrone(param1, dronesList.Get(i));
					break;
				}
				else if (StrEqual(ownerName, playerName, false))
					droneNum++;
			}
			Menu_Drones(param1, drone);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (params == MenuCancel_Exit)
		{
			if (IsValidEntity(param1))
				ExitDrone(param1);
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}