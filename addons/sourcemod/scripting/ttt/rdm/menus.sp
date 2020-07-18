int MenuHandler_RDM(Menu menu, MenuAction action, int client, int data) {
    switch (action) {
        case MenuAction_Select: {
            char info[8];
            menu.GetItem(data, info, 8);
            g_playerData[client].currentDeath = StringToInt(info);

            Menu_PunishChoice(client);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

void Menu_PunishChoice(int client)
{
            Menu punishMenu = new Menu(MenuHandler_PunishChoice);
            char sPunishTitle[64], sPunishSlay[64], sPunishWarn[64];
            Format(sPunishTitle, sizeof(sPunishTitle), "%T", "RDM: Report - Punishment Menu Title", client);
            punishMenu.SetTitle(sPunishTitle);
            Format(sPunishSlay, sizeof(sPunishSlay), "%T", "RDM: Report - Punishment Slay", client);
            punishMenu.AddItem("", sPunishSlay);
            Format(sPunishWarn, sizeof(sPunishWarn), "%T", "RDM: Report - Punishment Warning", client);
            punishMenu.AddItem("", sPunishWarn);

            punishMenu.Display(client, 240);
}

int MenuHandler_PunishChoice(Menu menu, MenuAction action, int client, int choice)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            CaseChoice punishment = CaseChoice_None;
            if (choice == 0)
            {
                punishment = CaseChoice_Slay;
            }
            else if (choice == 1)
            {
                punishment = CaseChoice_Warn;
            }

            Db_InsertReport(client, g_playerData[client].currentDeath, punishment);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

void Menu_Verdict(int client)
{
    Menu verdictMenu = new Menu(MenuHandler_Verdict);
    verdictMenu.AddItem("", "Innocent");
    verdictMenu.AddItem("", "Guilty");
    verdictMenu.Display(client, 240);
}

int MenuHandler_Verdict(Menu menu, MenuAction action, int client, int choice)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            CaseVerdict verdict = CaseVerdict_None;
            if (choice == 0)
            {
                verdict = CaseVerdict_Innocent;
            }
            else if (choice == 1)
            {
                verdict = CaseVerdict_Guilty;
            }

            Db_UpdateVerdict(client, g_playerData[client].currentCase, verdict);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}
