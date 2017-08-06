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

#include "cameras-and-drones/cameramanager.sp"

Menu playerCamMenus[MAXPLAYERS + 1];

public void Menu_Cameras(int client_index, int args)
{
	playerCamMenus[client_index] = new Menu(MenuHandler_Cameras);
	playerCamMenus[client_index].SetTitle("Available cameras");
	char name[64], ownerName[64], num[8];
	for (int i = 0; i < camerasList.Length; i++)
	{
		int owner = camOwnersList.Get(i);
		GetClientName(owner, ownerName, sizeof(ownerName));
		
		if (args == i)
		{
			Format(name, sizeof(name), "Active: %s's Camera", ownerName);
			Format(num, sizeof(num), "%i", -1);
			playerCamMenus[client_index].AddItem(num, name, ITEMDRAW_DISABLED);
		}
		else
		{
			Format(name, sizeof(name), "Watch %s's Camera", ownerName);
			Format(num, sizeof(num), "%i", i);
			playerCamMenus[client_index].AddItem(num, name); 
		}
	}
	playerCamMenus[client_index].ExitButton = true;
	playerCamMenus[client_index].Display(client_index, MENU_TIME_FOREVER);
}

public int MenuHandler_Cameras(Menu menu, MenuAction action, int param1, int params)
{
	if (action == MenuAction_Select)
	{
		char infoBuffer[64];
		menu.GetItem(params, infoBuffer, sizeof(infoBuffer));
		int cam = StringToInt(infoBuffer, 10);
		if (cam < camerasList.Length)
			TpToCam(param1, camerasList.Get(cam));
		Menu_Cameras(param1, cam);
	}
	else if (action == MenuAction_Cancel)
	{
		if (params == MenuCancel_Exit)
		{
			if (IsValidEntity(param1))
				ExitCam(param1);
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}