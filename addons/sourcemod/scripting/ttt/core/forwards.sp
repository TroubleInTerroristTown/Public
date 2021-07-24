void InitForwards()
{
    g_fwOnRoundStart_Pre = new GlobalForward("TTT_OnRoundStart_Pre", ET_Event);
    g_fwOnRoundStart = new GlobalForward("TTT_OnRoundStart", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnRoundStartFailed = new GlobalForward("TTT_OnRoundStartFailed", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnRoundEnd = new GlobalForward("TTT_OnRoundEnd", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnClientGetRole = new GlobalForward("TTT_OnClientGetRole", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnTakeDamage = new GlobalForward("TTT_OnTakeDamage", ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_Cell);
    g_fwOnClientDeath = new GlobalForward("TTT_OnClientDeath", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnClientDeathPre = new GlobalForward("TTT_OnClientDeathPre", ET_Event, Param_Cell, Param_Cell);
    g_fwOnButtonPress = new GlobalForward("TTT_OnButtonPress", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnButtonRelease = new GlobalForward("TTT_OnButtonRelease", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnModelUpdate = new GlobalForward("TTT_OnModelUpdate", ET_Ignore, Param_Cell, Param_String);
    g_fwOnPlayerDeathPre = new GlobalForward("TTT_OnPlayerDeath", ET_Event, Param_Cell, Param_Cell);
    g_fwOnPreKarmaUpdate = new GlobalForward("TTT_OnPreKarmaUpdate", ET_Event, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnKarmaUpdate = new GlobalForward("TTT_OnKarmaUpdate", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnRulesMenu = new GlobalForward("TTT_OnRulesMenu", ET_Event, Param_Cell, Param_CellByRef);
    g_fwOnDetectiveMenu = new GlobalForward("TTT_OnDetectiveMenu", ET_Event, Param_Cell, Param_CellByRef);
    g_fwOnCheckCommandAccess = new GlobalForward("TTT_OnCheckCommandAccess", ET_Event, Param_Cell, Param_String, Param_String, Param_CellByRef);
    g_fwOnPlayerRespawn = new GlobalForward("TTT_OnPlayerRespawn", ET_Ignore, Param_Cell);
    g_fwOnRoundSlay = new GlobalForward("TTT_OnRoundSlay", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnRoleSelection = new GlobalForward("TTT_OnRoleSelection", ET_Event, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef);
    g_fOnVersionCheck = new GlobalForward("TTT_OnVersionReceive", ET_Ignore, Param_Cell);
    g_fOnRoundTimerStart_Pre = new GlobalForward("TTT_OnRoundTimerStart_Pre", ET_Event, Param_CellByRef, Param_CellByRef);
}

Action Forward_OnRoundStart_Pre()
{
    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnRoundStart_Pre);
    Call_Finish(res);

    return res;
}

void Forward_OnRoundStart(int innocents, int traitors, int detectives, int misc)
{
    Call_StartForward(g_fwOnRoundStart);
    Call_PushCell(g_iRoundID);
    Call_PushCell(innocents);
    Call_PushCell(traitors);
    Call_PushCell(detectives);
    Call_PushCell(misc);
    Call_Finish();
}

void Forward_OnRoundStartFailed(int players)
{
    Call_StartForward(g_fwOnRoundStartFailed);
    Call_PushCell(players);
    Call_PushCell(g_crequiredPlayers.IntValue);
    Call_Finish();
}

void Forward_OnRoundEnd(int winner, int role)
{
    Call_StartForward(g_fwOnRoundEnd);
    Call_PushCell(winner);
    Call_PushCell(role);
    Call_PushCell(view_as<Handle>(g_aLogs));
    Call_Finish();
}

void Forward_OnClientGetRole(int client)
{
    Call_StartForward(g_fwOnClientGetRole);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Team);
    Call_PushCell(g_iPlayer[client].Role);
    Call_Finish();
}

void Forward_OnTakeDamage(int victim, int attacker, float damage, int weapon, bool badAction)
{
    Call_StartForward(g_fwOnTakeDamage);
    Call_PushCell(victim);
    Call_PushCell(attacker);
    Call_PushFloat(damage);
    Call_PushCell(weapon);
    Call_PushCell(view_as<int>(badAction));
    Call_Finish();
}

void Forward_OnClientDeath(int client, int attacker, bool badAction)
{
    Call_StartForward(g_fwOnClientDeath);
    Call_PushCell(client);
    Call_PushCell(attacker);
    Call_PushCell(view_as<int>(badAction));
    Call_Finish(); 
}

Action Forward_OnClientDeath_Pre(int client, int attacker)
{
    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnClientDeathPre);
    Call_PushCell(client);
    Call_PushCell(attacker);
    Call_Finish(res);

    return res;
}

void Forward_OnButtonPress(int client, int button)
{
    Call_StartForward(g_fwOnButtonPress);
    Call_PushCell(client);
    Call_PushCell(button);
    Call_Finish();
}

void Forward_OnButtonRelease(int client, int button)
{
    Call_StartForward(g_fwOnButtonRelease);
    Call_PushCell(client);
    Call_PushCell(button);
    Call_Finish();
}

void Forward_OnClientModelUpdate(int client)
{
    static char sModel[PLATFORM_MAX_PATH + 1];
    GetClientModel(client, sModel, sizeof(sModel));

    Call_StartForward(g_fwOnModelUpdate);
    Call_PushCell(client);
    Call_PushString(sModel);
    Call_Finish();
}

Action Forward_OnPlayerDeathPre(int client, int attacker)
{
    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnPlayerDeathPre);
    Call_PushCell(client);
    Call_PushCell(attacker);
    Call_Finish(res);

    return res;
}

Action Forward_OnPreKarmaUpdate(int client, KarmaUpdate type, int karma)
{
    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnPreKarmaUpdate);
    Call_PushCell(client);
    Call_PushCell(type);
    Call_PushCell(karma);
    Call_Finish(res);

    return res;
}

void Forward_OnKarmaUpdate(int client, KarmaUpdate type, int karma)
{
    Call_StartForward(g_fwOnKarmaUpdate);
    Call_PushCell(client);
    Call_PushCell(type);
    Call_PushCell(karma);
    Call_Finish();
}

Action Forward_OnRulesMenu(int client, bool& show)
{
    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnRulesMenu);
    Call_PushCell(client);
    Call_PushCellRef(show);
    Call_Finish(res);

    return res;
}

Action Forward_OnDetectiveMenu(int client, bool& show)
{
    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnDetectiveMenu);
    Call_PushCell(client);
    Call_PushCellRef(show);
    Call_Finish(res);

    return res;
}

Action Forward_OnCheckCommandAccess(int client, const char[] command, const char[] flags, bool& access)
{
    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnCheckCommandAccess);
    Call_PushCell(client);
    Call_PushString(command);
    Call_PushString(flags);
    Call_PushCellRef(access);
    Call_Finish(res);

    return res;
}

void Forward_OnPlayerRespawn(int client)
{
    Call_StartForward(g_fwOnPlayerRespawn);
    Call_PushCell(client);
    Call_Finish();
}

void Forward_OnRoundSlay(int client)
{
    Call_StartForward(g_fwOnRoundSlay);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].RoundSlays);
    Call_Finish(); 
}

Action Forward_OnRoleSelection(int& traitors, int& detectives, int& innocents, int& misc)
{
    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnRoleSelection);
    Call_PushCellRef(traitors);
    Call_PushCellRef(detectives);
    Call_PushCellRef(innocents);
    Call_PushCellRef(misc);
    Call_Finish(res);

    return res;
}

void Forward_OnVersionCheck()
{
    Call_StartForward(g_fOnVersionCheck);
    Call_PushCell(g_iVersion);
    Call_Finish();
}

void Forward_OnRoundStartTimer_Pre(bool& startTimer, float& endTime)
{
    Call_StartForward(g_fOnRoundTimerStart_Pre);
    Call_PushCellRef(startTimer);
    Call_PushCellRef(endTime);
    Call_Finish();
}
