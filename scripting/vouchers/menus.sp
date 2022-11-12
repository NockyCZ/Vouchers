void CodeMenu(int client)
{
	static char szText[128];
	Menu menu = new Menu(CodeMenu_Handler);
	
	menu.SetTitle("Vouchers Core\n ");
	
	Format(szText, sizeof(szText), "%T\n ", "Enter the voucher", client);
	menu.AddItem("0", szText);
	if (CheckCommandAccess(client, "", ADMFLAG_ROOT))
	{
		Format(szText, sizeof(szText), "%T", "View all vouchers", client);
		menu.AddItem("1", szText);
		Format(szText, sizeof(szText), "%T", "Create a new voucher", client);
		menu.AddItem("2", szText);
	}
	
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

int CodeMenu_Handler(Menu menu, MenuAction action, int client, int choice)
{
	if (action == MenuAction_Select)
	{
		switch (choice)
		{
			case 0:
			{
				char szQuery[512];
				g_hDatabase.Format(szQuery, sizeof(szQuery), "SELECT code FROM Vouchers WHERE enddate < NOW();");
				g_hDatabase.Query(SQL_DeleteCodeCallback, szQuery);
				
				CPrintToChat(client, "%t %t", "Chat_Prefix", "Write a voucher");
				g_iSayMode[client] = 1;
			}
			case 1:
			{
				g_bAdminEditor[client] = false;
				char szQuery[512];
				g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_LOAD_CODES);
				g_hDatabase.Query(SQL_ShowCodesMenuCallback, szQuery, GetClientUserId(client));
			}
			case 2:
			{
				CreateCode_Menu(client);
			}
		}
	}
	if (action == MenuAction_End)
		delete menu;
}

void CreateCode_Menu(int client)
{
	static char szText[128];
	Menu menu = new Menu(CreateCode_Menu_Handler);
	
	menu.SetTitle("%T\n ", "Create a new voucher", client);
	
	Format(szText, sizeof(szText), "%T", "Generate a random voucher", client);
	menu.AddItem("generate", szText);
	Format(szText, sizeof(szText), "%T", "Create a voucher", client);
	menu.AddItem("1", szText);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int CreateCode_Menu_Handler(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char szBuffer[64];
			menu.GetItem(choice, szBuffer, sizeof(szBuffer));
			
			if (IsCharNumeric(szBuffer[0]))
			{
				CPrintToChat(client, "%t %t", "Chat_Prefix", "Write a new voucher");
				g_iSayMode[client] = 3;
			}
			else
			{
				char szCode[10];
				GenerateRandomCode(szCode, sizeof(szCode));
				CPrintToChat(client, "%t %t", "Chat_Prefix", "New Code Created", szCode);
				char szQuery[512];
				g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_CREATE_CODE, szCode);
				g_hDatabase.Query(SQL_Error, szQuery);
			}
		}
		case MenuAction_Cancel:
		{
			if (choice == MenuCancel_ExitBack)
				CodeMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public void SQL_ShowCodesMenuCallback(Database database, DBResultSet results, const char[] error, int data)
{
	if (results == null)
		SetFailState(error);
	
	int client = GetClientOfUserId(data);
	
	if (IsValidClient(client))
	{
		if (results.RowCount != 0)
		{
			Menu menu = new Menu(SQL_ShowCodesMenuCallback_Handler);
			
			menu.SetTitle("Vouchers Core\n ");
			
			while (results.FetchRow())
			{
				char szCode[MAX_NAME_LENGTH];
				results.FetchString(0, szCode, sizeof(szCode));
				menu.AddItem(szCode, szCode);
			}
			
			menu.ExitBackButton = true;
			menu.Display(client, MENU_TIME_FOREVER);
		}
	}
}

int SQL_ShowCodesMenuCallback_Handler(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char szBuffer[64];
			menu.GetItem(choice, szBuffer, sizeof(szBuffer));
			
			char szQuery[512];
			g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_LOAD_CODE_DATA, szBuffer);
			g_hDatabase.Query(SQL_LoadCodeDataCallback, szQuery, GetClientUserId(client));
		}
		case MenuAction_Cancel:
		{
			if (choice == MenuCancel_ExitBack)
				CodeMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

void EditCodeMenu_Main(int client)
{
	static char szText[128];
	Menu menu = new Menu(EditCodeMenu_Main_Handler);
	menu.SetTitle("%T\n ", "Voucher Menu Title", client, g_szEditingCode[client]);
	
	Format(szText, sizeof(szText), "%T", "Used Menu", client, g_iEditingCode_Uses[client]);
	menu.AddItem("0", szText, ITEMDRAW_DISABLED);
	if (g_iEditingCode_UsesRemaining[client] <= 0)
	{
		Format(szText, sizeof(szText), "%T", "Usages Remaining Unlimited Menu", client);
		menu.AddItem("1", szText, g_bAdminEditor[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	else
	{
		Format(szText, sizeof(szText), "%T", "Usages Remaining Menu", client, g_iEditingCode_UsesRemaining[client]);
		menu.AddItem("1", szText, g_bAdminEditor[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	
	int iDuration = StringToInt(g_szEditingCode_EndDate[client]);
	if (iDuration == 0)
	{
		Format(szText, sizeof(szText), "%T", "Validity Forever Menu", client);
		menu.AddItem("2", szText, g_bAdminEditor[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	else
	{
		Format(szText, sizeof(szText), "%T", "Validity Menu", client, g_szEditingCode_EndDate[client]);
		menu.AddItem("2", szText, g_bAdminEditor[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	
	if (g_szEditingCode_Message[client][0] == '\0')
	{
		Format(szText, sizeof(szText), "%T\n ", "Message None Menu", client);
		menu.AddItem("3", szText, g_bAdminEditor[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	else
	{
		Format(szText, sizeof(szText), "%T\n ", "Message Menu", client, g_szEditingCode_Message[client]);
		menu.AddItem("3", szText, g_bAdminEditor[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	if (g_szEditingCode_Command[client][0] == '\0')
	{
		Format(szText, sizeof(szText), "%T\n ", "Commands Not Set Menu", client);
		menu.AddItem("4", szText, g_bAdminEditor[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	else
	{
		char szBuffer[512];
		Format(szBuffer, sizeof(szBuffer), "%s", g_szEditingCode_Command[client]);
		ReplaceString(szBuffer, sizeof(szBuffer), ";", "\n");
		Format(szText, sizeof(szText), "%T\n ", "Commands Menu", client, szBuffer);
		menu.AddItem("4", szText, g_bAdminEditor[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	
	if (!g_bAdminEditor[client])
	{
		Format(szText, sizeof(szText), "%T", "Edit Voucher Menu", client);
		menu.AddItem("5", szText);
	}
	else
	{
		Format(szText, sizeof(szText), "%T", "Save", client);
		menu.AddItem("5", szText);
		Format(szText, sizeof(szText), "%T", "Delete", client);
		menu.AddItem("6", szText);
	}
	
	if (!g_bAdminEditor[client])
		menu.ExitBackButton = true;
	else
		menu.ExitBackButton = false;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

int EditCodeMenu_Main_Handler(Menu menu, MenuAction action, int client, int choice)
{
	if (action == MenuAction_Select)
	{
		char szBuffer[64]; // , szQuery[512]; 
		menu.GetItem(choice, szBuffer, sizeof(szBuffer));
		
		switch (choice)
		{
			case 0:
			{
				EditCodeMenu_Main(client);
			}
			case 1:
			{
				EditCodeMenu_Remaining(client);
			}
			case 2:
			{
				EditCodeMenu_Lifetime(client);
			}
			case 3:
			{
				EditCodeMenu_Message(client);
			}
			case 4:
			{
				EditCodeMenu_Command(client);
			}
			case 5:
			{
				if (!g_bAdminEditor[client])
				{
					g_bAdminEditor[client] = true;
					EditCodeMenu_Main(client);
				}
				else
				{
					char szQuery[512];
					g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_UPDATE_CODE_DATA, g_szEditingCode_Command[client], g_szEditingCode_Message[client], g_iEditingCode_Uses[client], g_iEditingCode_UsesRemaining[client], g_szEditingCode[client]);
					g_hDatabase.Query(SQL_Error, szQuery);
					CPrintToChat(client, "%t %t", "Chat_Prefix", "Voucher Edited", g_szEditingCode[client]);
				}
			}
			case 6:
			{
				DeleteCode(g_szEditingCode[client], "Deleted by Admin");
				CPrintToChat(client, "%t %t", "Chat_Prefix", "Voucher Deleted", g_szEditingCode[client]);
			}
		}
	}
	if (action == MenuAction_Cancel)
	{
		if (choice == MenuCancel_ExitBack)
		{
			char szQuery[512];
			g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_LOAD_CODES);
			g_hDatabase.Query(SQL_ShowCodesMenuCallback, szQuery, GetClientUserId(client));
		}
	}
	if (action == MenuAction_End)
		delete menu;
}

void EditCodeMenu_Lifetime(int client)
{
	static char szText[128];
	Menu menu = new Menu(EditCodeMenu_Lifetime_Handler);
	
	int iDuration = StringToInt(g_szEditingCode_EndDate[client]);
	if (iDuration == 0)
		menu.SetTitle("%T\n%T - %T\n ", "Edit Voucher", client, g_szEditingCode[client], "Validity", client, "Forever", client);
	else if (g_iEditingCode_EndDate[client] == 0)
		menu.SetTitle("%T\n%T - %s\n ", "Edit Voucher", client, g_szEditingCode[client], "Validity", client, g_szEditingCode_EndDate[client]);
	else
	{
		if (g_iEditingCode_EndDate[client] == 1)
			menu.SetTitle("%T\n%T - %i %T\n ", "Edit Voucher", client, g_szEditingCode[client], "Validity", client, iDuration, "Minutes", client);
		else if (g_iEditingCode_EndDate[client] == 2)
			menu.SetTitle("%T\n%T - %i %T\n ", "Edit Voucher", client, g_szEditingCode[client], "Validity", client, iDuration, "Hours", client);
		else if (g_iEditingCode_EndDate[client] == 3)
			menu.SetTitle("%T\n%T - %i %T\n ", "Edit Voucher", client, g_szEditingCode[client], "Validity", client, iDuration, "Days", client);
	}
	
	Format(szText, sizeof(szText), "%T\n ", "Forever", client);
	menu.AddItem("forever", szText);
	
	Format(szText, sizeof(szText), "%T", "Minutes", client);
	menu.AddItem("minutes", szText, g_iEditingCode_EndDate[client] == 1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if (g_iEditingCode_EndDate[client] == 1)
	{
		menu.AddItem("+1", "+1");
		menu.AddItem("-1", "-1\n ");
	}
	
	Format(szText, sizeof(szText), "%T", "Hours", client);
	menu.AddItem("hours", szText, g_iEditingCode_EndDate[client] == 2 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if (g_iEditingCode_EndDate[client] == 2)
	{
		menu.AddItem("+1", "+1");
		menu.AddItem("-1", "-1\n ");
	}
	
	Format(szText, sizeof(szText), "%T", "Days", client);
	menu.AddItem("days", szText, g_iEditingCode_EndDate[client] == 3 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if (g_iEditingCode_EndDate[client] == 3)
	{
		menu.AddItem("+1", "+1");
		menu.AddItem("-1", "-1");
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int EditCodeMenu_Lifetime_Handler(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			int iDuration = StringToInt(g_szEditingCode_EndDate[client]);
			char szBuffer[128];
			menu.GetItem(choice, szBuffer, sizeof(szBuffer));
			
			if (StrEqual(szBuffer, "forever", false))
			{
				iDuration = 0;
				g_iEditingCode_EndDate[client] = 0;
			}
			else if (StrEqual(szBuffer, "minutes", false))
			{
				iDuration = 1;
				g_iEditingCode_EndDate[client] = 1;
			}
			else if (StrEqual(szBuffer, "hours", false))
			{
				iDuration = 1;
				g_iEditingCode_EndDate[client] = 2;
			}
			else if (StrEqual(szBuffer, "days", false))
			{
				iDuration = 1;
				g_iEditingCode_EndDate[client] = 3;
			}
			else if (StrEqual(szBuffer, "+1", false))
			{
				iDuration++;
			}
			else if (StrEqual(szBuffer, "-1", false))
			{
				if (iDuration >= 1 && iDuration != 0)
					iDuration--;
			}
			
			IntToString(iDuration, g_szEditingCode_EndDate[client], sizeof(g_szEditingCode_EndDate));
			
			EditCodeMenu_Lifetime(client);
		}
		case MenuAction_Cancel:
		{
			if (choice == MenuCancel_ExitBack)
			{
				char szQuery[512];
				int iDuration = StringToInt(g_szEditingCode_EndDate[client]);
				if (g_iEditingCode_EndDate[client] == 0)
				{
					Format(g_szEditingCode_EndDate[client], sizeof(g_szEditingCode_EndDate), "%T", "Forever", client);
					g_hDatabase.Format(szQuery, sizeof(szQuery), "UPDATE Vouchers SET enddate = NULL WHERE code = '%s';", g_szEditingCode[client]);
					g_hDatabase.Query(SQL_Error, szQuery);
				}
				else if (g_iEditingCode_EndDate[client] == 1)
				{
					Format(g_szEditingCode_EndDate[client], sizeof(g_szEditingCode_EndDate), "%i %T", iDuration, "Minutes", client);
					g_hDatabase.Format(szQuery, sizeof(szQuery), "UPDATE Vouchers SET enddate = DATE_ADD(NOW(), INTERVAL %i MINUTE) WHERE code = '%s';", iDuration, g_szEditingCode[client]);
					g_hDatabase.Query(SQL_Error, szQuery);
				}
				else if (g_iEditingCode_EndDate[client] == 2)
				{
					Format(g_szEditingCode_EndDate[client], sizeof(g_szEditingCode_EndDate), "%i %T", iDuration, "Hours", client);
					g_hDatabase.Format(szQuery, sizeof(szQuery), "UPDATE Vouchers SET enddate = DATE_ADD(NOW(), INTERVAL %i HOUR) WHERE code = '%s';", iDuration, g_szEditingCode[client]);
					g_hDatabase.Query(SQL_Error, szQuery);
				}
				else if (g_iEditingCode_EndDate[client] == 3)
				{
					Format(g_szEditingCode_EndDate[client], sizeof(g_szEditingCode_EndDate), "%i %T", iDuration, "Days", client);
					g_hDatabase.Format(szQuery, sizeof(szQuery), "UPDATE Vouchers SET enddate = DATE_ADD(NOW(), INTERVAL %i DAY) WHERE code = '%s';", iDuration, g_szEditingCode[client]);
					g_hDatabase.Query(SQL_Error, szQuery);
				}
				g_iEditingCode_EndDate[client] = 0;
				EditCodeMenu_Main(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

void EditCodeMenu_Remaining(int client)
{
	static char szText[128];
	Menu menu = new Menu(EditCodeMenu_Remaining_Handler);
	
	if (g_iEditingCode_UsesRemaining[client] <= 0)
		menu.SetTitle("%T\n%T - %T\n ", "Edit Voucher", client, g_szEditingCode[client], "Maximum use", client, "Unlimited", client);
	else
		menu.SetTitle("%T\n%T - %i\n ", "Edit Voucher", client, g_szEditingCode[client], "Maximum use", client, g_iEditingCode_UsesRemaining[client]);
	
	menu.AddItem("1", "+1");
	menu.AddItem("2", "-1");
	
	Format(szText, sizeof(szText), "%T", "Unlimited", client);
	menu.AddItem("3", szText);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int EditCodeMenu_Remaining_Handler(Menu menu, MenuAction action, int client, int choice)
{
	if (action == MenuAction_Select)
	{
		char szBuffer[64]; //, szQuery[512];
		menu.GetItem(choice, szBuffer, sizeof(szBuffer));
		
		switch (choice)
		{
			case 0:
			{
				if (g_iEditingCode_UsesRemaining[client] <= 0)
					g_iEditingCode_UsesRemaining[client] = 1;
				else
					g_iEditingCode_UsesRemaining[client]++;
				
				EditCodeMenu_Remaining(client);
			}
			case 1:
			{
				
				if (g_iEditingCode_UsesRemaining[client] <= -1)
				{
					g_iEditingCode_UsesRemaining[client] = -1;
					EditCodeMenu_Remaining(client);
				}
				else
				{
					g_iEditingCode_UsesRemaining[client]--;
					if (g_iEditingCode_UsesRemaining[client] == 0)
						g_iEditingCode_UsesRemaining[client] = -1;
					
					EditCodeMenu_Remaining(client);
				}
			}
			case 2:
			{
				g_iEditingCode_UsesRemaining[client] = -1;
				EditCodeMenu_Remaining(client);
			}
		}
	}
	if (action == MenuAction_Cancel)
	{
		if (choice == MenuCancel_ExitBack)
			EditCodeMenu_Main(client);
	}
	if (action == MenuAction_End)
		delete menu;
}

void EditCodeMenu_Message(int client)
{
	static char szText[128];
	Menu menu = new Menu(EditCodeMenu_Message_Handler);
	
	if (g_szEditingCode_Message[client][0] == '\0')
		menu.SetTitle("%T\n%T - %T\n ", "Edit Voucher", client, g_szEditingCode[client], "Message phrase", client, "None", client);
	else
		menu.SetTitle("%T\n%T - %s\n ", "Edit Voucher", client, g_szEditingCode[client], "Message phrase", client, g_szEditingCode_Message[client]);
	
	Format(szText, sizeof(szText), "%T\n ", "None", client);
	menu.AddItem("none", szText, StrEqual("", g_szEditingCode_Message[client], true) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	for (int i = 0; i < g_iLoadedTranslations; i++)
	{
		menu.AddItem(g_szTranslationPhrases[i], g_szTranslationPhrases[i], StrEqual(g_szTranslationPhrases[i], g_szEditingCode_Message[client], true) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int EditCodeMenu_Message_Handler(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char szBuffer[128];
			menu.GetItem(choice, szBuffer, sizeof(szBuffer));
			
			if (StrEqual(szBuffer, "none"))
				g_szEditingCode_Message[client] = "";
			else
				Format(g_szEditingCode_Message[client], sizeof(g_szEditingCode_Message), szBuffer);
			
			EditCodeMenu_Message(client);
		}
		case MenuAction_Cancel:
		{
			if (choice == MenuCancel_ExitBack)
				EditCodeMenu_Main(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

void EditCodeMenu_Command(int client)
{
	static char szText[256];
	Menu menu = new Menu(EditCodeMenu_Command_Handler);
	
	menu.SetTitle("%T\n ", "Edit Voucher", client, g_szEditingCode[client]);
	
	
	if (g_szEditingCode_Command[client][0] == '\0')
	{
		Format(szText, sizeof(szText), "%T", "Commands Not Set Menu", client);
		menu.AddItem("0", szText);
	}
	else
	{
		char szBuffer[256];
		Format(szBuffer, sizeof(szBuffer), "%s", g_szEditingCode_Command[client]);
		ReplaceString(szBuffer, sizeof(szBuffer), ";", "\n");
		Format(szText, sizeof(szText), "%T", "Commands Menu", client, szBuffer);
		menu.AddItem("0", szText);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int EditCodeMenu_Command_Handler(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_iSayMode[client] = 2;
			CPrintToChat(client, "%t %t", "Chat_Prefix", "Write a new commands");
			CPrintToChat(client, "%t %t", "Chat_Prefix", "Write a new commands2");
		}
		case MenuAction_Cancel:
		{
			if (choice == MenuCancel_ExitBack)
				EditCodeMenu_Main(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}
