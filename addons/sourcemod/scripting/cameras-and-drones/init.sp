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

#include <convars>

ConVar cvar_welcome_message = null;

ConVar cvar_gearteam = null;
ConVar cvar_camprice = null;
ConVar cvar_droneprice = null;

ConVar cvar_totalmax_cam = null;
ConVar cvar_totalmax_drone = null;

ConVar cvar_pickuprange = null;
ConVar cvar_jumpcooldown = null;

ConVar cvar_tkprotect = null;

ConVar cvar_dronespeed = null;
ConVar cvar_dronejump = null;


public void CreateConVars(char[] version)
{
	CreateConVar("cameras-and-drones_version", version, "Cameras and Drones Version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	cvar_welcome_message = CreateConVar("cd_welcomemessage", "1", "Displays a welcome message to new players. 0 = no message, 1 = display message", FCVAR_NOTIFY, true, 0.0, true, 1.0); 
	
	cvar_gearteam = CreateConVar("cd_gearteam", "3", "Set which team can use cameras. The oposite will have drones. 0 = All drones, 1 = All cameras, 2 = T cameras, 3 = CT cameras", FCVAR_NOTIFY);
	
	cvar_camprice = CreateConVar("cd_camprice", "800", "Set cameras price. min = 0, max = 30000", FCVAR_NOTIFY, true, 0.0, true, 30000.0);
	cvar_droneprice = CreateConVar("cd_droneprice", "800", "Set drones price. min = 0, max = 30000", FCVAR_NOTIFY, true, 0.0, true, 30000.0);
	
	cvar_totalmax_cam = CreateConVar("cd_totalmax_cam", "1", "Set the maximum cameras a player can setup. min = 1, max = 10", FCVAR_NOTIFY, true, 1.0, true, 10.0);
	cvar_totalmax_drone = CreateConVar("cd_totalmax_drone", "1", "Set the maximum drones a player can setup. min = 1, max = 10", FCVAR_NOTIFY, true, 1.0, true, 10.0);
	
	cvar_pickuprange = CreateConVar("cd_pickuprange", "150", "Set the max range at which a player can pickup its drone/cam. 0 = no pickup", FCVAR_NOTIFY, true, 0.0, true, 30000.0);
	cvar_jumpcooldown = CreateConVar("cd_jumpcooldown", "1", "Set the time players must wait before jmping again with the drone.", FCVAR_NOTIFY, true, 0.0, true, 30000.0);
	
	cvar_tkprotect = CreateConVar("cd_tkprotect", "1", "Set whether teammates can break gear. 0 = no protection, 1 = protected", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	cvar_dronespeed = CreateConVar("cd_dronespeed", "150", "Set the drone speed. 130 = human walk, 250 = human run", FCVAR_NOTIFY, true, 1.0, true, 500.0);
	cvar_dronejump = CreateConVar("cd_dronejump", "300", "Set drone jump force", FCVAR_NOTIFY, true, 0.0, true, 500.0);
	cvar_dronespeed.AddChangeHook(OnDroneSpeedChange);
	cvar_dronejump.AddChangeHook(OnDroneJumpChange);
	AutoExecConfig(true, "cameras-and-drones");
}

public void RegisterCommands()
{
	RegAdminCmd("cd_override", OverrideGear, ADMFLAG_GENERIC, "Override gear for a player");
	RegConsoleCmd("cd_buy", BuyGear, "Buy team gear");
	RegConsoleCmd("cd_cam", OpenGear, "Open gear");
	RegConsoleCmd("cd_help", ShowHelp, "Show plugin help");
	RegConsoleCmd("say !cd_help", ShowHelp, "Show plugin help");
}
