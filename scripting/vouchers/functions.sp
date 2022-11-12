void UseCode(int client)
{
	char szBuffer[70];
	Format(szBuffer, sizeof(szBuffer), ";%s;", g_szClientCode[client]);
	
	if (StrContains(g_szClientCodesList[client], szBuffer, true) != -1)
	{
		CPrintToChat(client, "%t %t", "Chat_Prefix", "Voucher already used");
	}
	else if (StrContains(g_szCodesList, szBuffer, true) != -1)
	{
		char szQuery[512];
		g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_LOAD_CODE_DATA, g_szClientCode[client]);
		g_hDatabase.Query(SQL_UseCodeDataCallback, szQuery, GetClientUserId(client));
	}
	else
	{
		if (StringToInt(g_szAttempts) >= 1)
		{
			g_iClientUsageFails[client]++;
			if (g_iClientUsageFails[client] == (StringToInt(g_szAttempts) - 1))
			{
				CPrintToChat(client, "%t %t", "Chat_Prefix", "Voucher was not found", g_szClientCode[client]);
				CPrintToChat(client, "%t %t", "Chat_Prefix", "Last usage remaining");
			}
			else if (g_iClientUsageFails[client] >= StringToInt(g_szAttempts))
			{
				CPrintToChat(client, "%t %t", "Chat_Prefix", "Vouchers usage ban", g_szAttempts, g_szBlockTime);
				g_iClientUsageFails[client] = 0;
				
				char szSteamID[32];
				GetClientAuthId(client, AuthId_Steam2, szSteamID, 32);
				
				char szQuery[512];
				g_hDatabase.Format(szQuery, sizeof(szQuery), "UPDATE Vouchers_users SET ban_enddate = DATE_ADD(NOW(), INTERVAL %i MINUTE) WHERE steamid = '%s';", StringToInt(g_szBlockTime), szSteamID);
				g_hDatabase.Query(SQL_Error, szQuery);
				g_bIsBanned[client] = true;
				LogToFile(g_szLogPath, "Player %N (%s) got banned! (Used wrong voucher enough times)", client, szSteamID);
			}
			else
				CPrintToChat(client, "%t %t", "Chat_Prefix", "Voucher was not found", g_szClientCode[client]);
		}
		else
			CPrintToChat(client, "%t %t", "Chat_Prefix", "Voucher was not found", g_szClientCode[client]);
	}
}

void LoadCodeTranslations()
{
	BuildPath(Path_SM, g_szPath, sizeof(g_szPath), "translations/vouchers_messages.phrases.txt");
	
	KeyValues kv = new KeyValues("Phrases");
	kv.ImportFromFile(g_szPath);
	
	if (!FileExists(g_szPath))
	{
		SetFailState("Translations phrases (%s) not found", g_szPath);
		return;
	}
	if (!kv.GotoFirstSubKey())
	{
		SetFailState("In phrases file (%s) is error", g_szPath);
		return;
	}
	
	int i = 0;
	do
	{
		kv.GetSectionName(g_szTranslationPhrases[i], sizeof(g_szTranslationPhrases[]));
		i++;
		
	} while (kv.GotoNextKey());
	
	g_iLoadedTranslations = i;
	
	delete kv;
	return;
}

void UpdateUserData(int client)
{
	char szSteamID[32];
	if (!GetClientAuthId(client, AuthId_Steam2, szSteamID, 32))
		return;
	
	char szQuery[512];
	g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_UPDATE_USER_DATA, g_szClientCodesList[client], g_iClientCodesUsed[client], g_iClientUsageFails[client], szSteamID);
	g_hDatabase.Query(SQL_Error, szQuery);
}

void DeleteCode(char[] szCode, char[] szDeleteReason)
{
	LogToFile(g_szLogPath, "Voucher \"%s\" deleted. [Reason: %s]", szCode, szDeleteReason);
	
	char szQuery[512];
	g_hDatabase.Format(szQuery, sizeof(szQuery), "DELETE from Vouchers WHERE code = '%s';", szCode);
	g_hDatabase.Query(SQL_Error, szQuery);
	
	/*
	char szBuffer[64];
	Format(szBuffer, sizeof(szBuffer), ";%s;", szCode);
	if (StrContains(g_szCodesList, szBuffer, true) != -1)
		ReplaceString(g_szCodesList, sizeof(g_szCodesList), szBuffer, "");
	*/
}

stock int GenerateRandomCode(char[] szOutput, int iSize)
{
	char szBuffer[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	
	for (int i = 0; i < iSize; i++) {
		szOutput[i] = szBuffer[GetRandomInt(0, 61)];
	}
	return iSize;
}

stock bool IsValidClient(int client, bool alive = false)
{
	return (0 < client && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client) == false && (alive == false || IsPlayerAlive(client)));
}

stock int GetClientFromSID(char[] szSID)
{
	char szSteamID[32];
	for (int i = 1; i <= MaxClients; i++)
	if (IsValidClient(i))
	{
		GetClientAuthId(i, AuthId_Steam2, szSteamID, 32);
		if (StrEqual(szSID, szSteamID, false))
			return i;
	}
	return -1;
} 