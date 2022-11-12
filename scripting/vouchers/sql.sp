public void SQL_LoadUserDataCallback(Database database, DBResultSet results, const char[] error, int data)
{
	if (results == null)
		SetFailState(error);
	
	int client = GetClientOfUserId(data);
	
	if (IsValidClient(client))
	{
		char szSteamID[32];
		if (results.RowCount != 0)
		{
			while (results.FetchRow())
			{
				results.FetchString(0, g_szClientCodesList[client], sizeof(g_szClientCodesList));
				results.FetchString(3, g_szClientBanEndDate[client], sizeof(g_szClientBanEndDate));
				g_iClientCodesUsed[client] = results.FetchInt(1);
				g_iClientUsageFails[client] = results.FetchInt(2);
				
				char szQuery[512];
				GetClientAuthId(client, AuthId_Steam2, szSteamID, 32);
				
				g_hDatabase.Format(szQuery, sizeof(szQuery), "SELECT TIMESTAMPDIFF(MINUTE, ban_enddate, NOW()) as timeleft FROM Vouchers_users WHERE steamid = '%s';", szSteamID);
				g_hDatabase.Query(SQL_LoadBanEndDateCallback, szQuery, GetClientUserId(client));
			}
		}
		else
		{
			char szQuery[512];
			GetClientAuthId(client, AuthId_Steam2, szSteamID, 32);
			
			g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_CREATE_USER_DATA, szSteamID);
			g_hDatabase.Query(SQL_Error, szQuery, GetClientUserId(client));
		}
		g_bPlayerFetched[client] = true;
	}
}

public void SQL_LoadBanEndDateCallback(Database database, DBResultSet results, const char[] error, int data)
{
	if (results == null)
		SetFailState(error);
	
	int client = GetClientOfUserId(data);
	
	if (IsValidClient(client))
	{
		if (results.RowCount != 0)
		{
			while (results.FetchRow())
			{
				char szEndDate[64];
				results.FetchString(0, szEndDate, sizeof(szEndDate));
				
				int iDuration = StringToInt(szEndDate);
				if (iDuration <= -1)
					g_bIsBanned[client] = true;
				else
					g_bIsBanned[client] = false;
			}
		}
	}
}

public void SQL_LoadCodeDataCallback(Database database, DBResultSet results, const char[] error, int data)
{
	if (results == null)
		SetFailState(error);
	
	int client = GetClientOfUserId(data);
	
	if (IsValidClient(client))
	{
		if (results.RowCount != 0)
		{
			while (results.FetchRow())
			{
				results.FetchString(0, g_szEditingCode[client], sizeof(g_szEditingCode));
				results.FetchString(1, g_szEditingCode_Command[client], sizeof(g_szEditingCode_Command)); //command
				results.FetchString(2, g_szEditingCode_EndDate[client], sizeof(g_szEditingCode_EndDate)); //enddate
				results.FetchString(3, g_szEditingCode_Message[client], sizeof(g_szEditingCode_Message)); //translations
				g_iEditingCode_Uses[client] = results.FetchInt(4);
				g_iEditingCode_UsesRemaining[client] = results.FetchInt(5);
				
				EditCodeMenu_Main(client);
			}
		}
	}
}

public void SQL_UseCodeDataCallback(Database database, DBResultSet results, const char[] error, int data)
{
	if (results == null)
		SetFailState(error);
	
	int client = GetClientOfUserId(data);
	
	if (IsValidClient(client))
	{
		if (results.RowCount != 0)
		{
			while (results.FetchRow())
			{
				char szCode[64], szCommand[256], szEndDate[64], szMessage[128], szBuffer[64];
				int iUses, iUsesRemaining;
				
				results.FetchString(0, szCode, sizeof(szCode));
				results.FetchString(1, szCommand, sizeof(szCommand));
				results.FetchString(2, szEndDate, sizeof(szEndDate));
				results.FetchString(3, szMessage, sizeof(szMessage));
				iUses = results.FetchInt(4);
				iUsesRemaining = results.FetchInt(5);
				
				g_iClientUsageFails[client] = 0;
				g_iClientCodesUsed[client]++;
				Format(szBuffer, sizeof(szBuffer), ";%s;", g_szClientCode[client]);
				StrCat(g_szClientCodesList[client], sizeof(g_szClientCodesList), szBuffer);
				
				char szSteamID32[32], szSteamID64[64], szUserid[32], szServerCmd[256], szUsername[MAX_NAME_LENGTH];
				GetClientAuthId(client, AuthId_Steam2, szSteamID32, 32);
				GetClientAuthId(client, AuthId_SteamID64, szSteamID64, 64);
				GetClientName(client, szUsername, sizeof(szUsername));
				Format(szUserid, sizeof(szUserid), "#%i", client);
				Format(szServerCmd, sizeof(szServerCmd), szCommand);
				
				ReplaceString(szServerCmd, sizeof(szServerCmd), "steamid32", szSteamID32);
				ReplaceString(szServerCmd, sizeof(szServerCmd), "steamid64", szSteamID64);
				ReplaceString(szServerCmd, sizeof(szServerCmd), "userid", szUsername);
				ReplaceString(szServerCmd, sizeof(szServerCmd), "username", szUsername);
				
				ServerCommand(szServerCmd);
				if (szMessage[0] != '\0')
					CPrintToChat(client, "%t", szMessage);
				else
					CPrintToChat(client, "%t %t", "Chat_Prefix", "Voucher Used", szCode);
				
				LogToFile(g_szLogPath, "Player %N (%s) used \"%s\" voucher.", client, szSteamID32, szCode);
				
				if (iUsesRemaining >= 1)
				{
					iUsesRemaining--;
					iUses++;
					if (iUsesRemaining == 0)
						DeleteCode(szCode, "Maximum usages");
					else
					{
						char szQuery[512];
						g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_UPDATE_CODE_DATA, szCommand, szMessage, iUses, iUsesRemaining, szCode);
						g_hDatabase.Query(SQL_Error, szQuery);
					}
				}
				else
				{
					char szQuery[512];
					g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_UPDATE_CODE_DATA, szCommand, szMessage, iUses, iUsesRemaining, szCode);
					g_hDatabase.Query(SQL_Error, szQuery);
				}
			}
		}
	}
}

public void SQL_DeleteCodeCallback(Database database, DBResultSet results, const char[] error, int data)
{
	if (results == null)
		SetFailState(error);
	
	if (results.RowCount != 0)
	{
		while (results.FetchRow())
		{
			char szCode[64];
			results.FetchString(0, szCode, sizeof(szCode));
			DeleteCode(szCode, "Expired");
		}
	}
}

public void SQL_UseCodeCallback(Database database, DBResultSet results, const char[] error, int data)
{
	if (results == null)
		SetFailState(error);
	
	int client = GetClientOfUserId(data);
	if (IsValidClient(client))
	{
		if (results.RowCount != 0)
		{
			g_szCodesList = "";
			while (results.FetchRow())
			{
				char szBuffer[512], szCode[64];
				results.FetchString(0, szCode, sizeof(szCode));
				
				Format(szBuffer, sizeof(szBuffer), ";%s;", szCode);
				StrCat(g_szCodesList, sizeof(g_szCodesList), szBuffer);
			}
			UseCode(client);
		}
	}
}

public void SQL_RemoveVoucherCallback(Database database, DBResultSet results, const char[] error, int data)
{
	if (results == null)
		SetFailState(error);
	
	bool bVoucherFound = false;
	char szCode[64];
	
	if (results.RowCount != 0)
	{
		while (results.FetchRow())
		{
			results.FetchString(0, szCode, sizeof(szCode));
			bVoucherFound = true;
		}
	}
	if (bVoucherFound)
	{
		DeleteCode(szCode, "Deleted by Admin");
		PrintToServer("[Vouchers] Voucher \"%s\" successfully deleted!", szCode);
	}
	else
		PrintToServer("[Vouchers] Voucher was not found!");
}

public void SQL_UpdateCodeCommandsCallback(Database database, DBResultSet results, const char[] error, int data)
{
	if (results == null)
		SetFailState(error);
	
	bool bVoucherFound = false;
	char szCode[64];
	
	if (results.RowCount != 0)
	{
		while (results.FetchRow())
		{
			results.FetchString(0, szCode, sizeof(szCode));
			bVoucherFound = true;
		}
	}
	if (bVoucherFound)
	{
		char szQuery[512];
		g_hDatabase.Format(szQuery, sizeof(szQuery), "UPDATE Vouchers SET command = '%s' WHERE code = '%s';", g_szCommands, szCode);
		g_hDatabase.Query(SQL_Error, szQuery);
		
		ReplaceString(g_szCommands, sizeof(g_szCommands), ";", "\n");
		PrintToServer("========================================");
		PrintToServer("New commands has been set on \"%s\" voucher!", szCode);
		PrintToServer(" ");
		PrintToServer("%s", g_szCommands);
		PrintToServer("========================================");
	}
	else
		PrintToServer("[Vouchers] Voucher was not found!");
}

public void SQL_Connection(Database database, const char[] error, int data)
{
	if (database == null)
		SetFailState(error);
	else
	{
		g_hDatabase = database;
		g_hDatabase.SetCharset("utf8mb4");
		
		g_hDatabase.Query(SQL_CreateCallback, SQL_CREATE_CODES_TABLE);
		g_hDatabase.Query(SQL_Error, SQL_CREATE_USERS_TABLE);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && !g_bPlayerFetched[i])
				OnClientPostAdminCheck(i);
		}
	}
}

public void SQL_CreateCallback(Database database, DBResultSet results, const char[] error, int data)
{
	if (results == null)
		SetFailState(error);
	
	g_bFullyConnected = true;
	
	char szQuery[512];
	g_hDatabase.Format(szQuery, sizeof(szQuery), "SELECT code FROM Vouchers WHERE enddate < NOW();");
	g_hDatabase.Query(SQL_DeleteCodeCallback, szQuery);
}

public void SQL_Error(Database datavas, DBResultSet results, const char[] error, int data)
{
	if (results == null)
		SetFailState(error);
} 