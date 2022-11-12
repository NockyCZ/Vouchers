#include <sourcemod>
#include <colors_csgo>

#define MAX_PHRASES 64

#pragma semicolon 1
#pragma newdecls required

int g_iSayMode[MAXPLAYERS + 1];
/*
0 - NOTHING
1 - WRITE CODE
2 - WRITE COMMAND
3 - WRITE CREATE COMMAND
*/

Database g_hDatabase = null;
bool g_bFullyConnected;
bool g_bPlayerFetched[MAXPLAYERS + 1];

char g_szClientCodesList[1024][MAXPLAYERS + 1];
char g_szClientBanEndDate[64][MAXPLAYERS + 1];
char g_szClientCode[64][MAXPLAYERS + 1];
int g_iClientCodesUsed[MAXPLAYERS + 1];
int g_iClientUsageFails[MAXPLAYERS + 1];
bool g_bIsBanned[MAXPLAYERS + 1];

char g_szPath[PLATFORM_MAX_PATH];
char g_szLogPath[PLATFORM_MAX_PATH];
char g_szCommands[254];
char g_szTranslationPhrases[MAX_PHRASES][128];
char g_szCodesList[512];
int g_iLoadedTranslations;

// CREATE CODE CLIENT SETTINGS
bool g_bAdminEditor[MAXPLAYERS + 1];

char g_szEditingCode[64][MAXPLAYERS + 1];
char g_szEditingCode_Command[256][MAXPLAYERS + 1];
char g_szEditingCode_EndDate[64][MAXPLAYERS + 1];
char g_szEditingCode_Message[128][MAXPLAYERS + 1];

int g_iEditingCode_UsesRemaining[MAXPLAYERS + 1];
int g_iEditingCode_Uses[MAXPLAYERS + 1];
int g_iEditingCode_EndDate[MAXPLAYERS + 1];

//CONVARS
char g_szBlockTime[10];
char g_szAttempts[10];
ConVar g_cvAttempts;
ConVar g_cvBlockTime;

#include "vouchers/defines.sp"
#include "vouchers/sql.sp"
#include "vouchers/functions.sp"
#include "vouchers/menus.sp"

public Plugin myinfo = 
{
	name = "[Vouchers] Core", 
	author = "Nocky", 
	version = "1.0", 
	url = "https://github.com/nockycz"
};

public void OnPluginStart()
{
	g_cvAttempts = CreateConVar("vouchers_attempts", "5", "Number of attempts to enter a voucher before obtaining a block (0 - Disabled)");
	g_cvAttempts.AddChangeHook(OnConVarChanged);
	g_cvAttempts.GetString(g_szAttempts, sizeof(g_szAttempts));
	
	g_cvBlockTime = CreateConVar("vouchers_block_time", "120", "How many minutes will the player be blocked if they enter incorrect vouchers");
	g_cvBlockTime.AddChangeHook(OnConVarChanged);
	g_cvBlockTime.GetString(g_szBlockTime, sizeof(g_szBlockTime));
	
	AutoExecConfig(true, "Vouchers");
	
	BuildPath(Path_SM, g_szLogPath, sizeof(g_szLogPath), "logs/vouchers_core.txt");
	
	RegAdminCmd("sm_voucher_gen", GenerateVoucher_CMD, ADMFLAG_ROOT);
	RegAdminCmd("sm_voucher_add", CreateVoucher_CMD, ADMFLAG_ROOT);
	RegAdminCmd("sm_voucher_cmds", SetVoucherCommands_CMD, ADMFLAG_ROOT);
	
	RegAdminCmd("sm_voucher_del", DeleteVoucher_CMD, ADMFLAG_ROOT);
	RegAdminCmd("sm_voucher_rem", DeleteVoucher_CMD, ADMFLAG_ROOT);
	
	RegAdminCmd("sm_voucher_unblock", Unblock_CMD, ADMFLAG_ROOT);
	
	RegConsoleCmd("sm_code", UseCode_CMD);
	RegConsoleCmd("sm_codes", UseCode_CMD);
	RegConsoleCmd("sm_voucher", UseCode_CMD);
	RegConsoleCmd("sm_vouchers", UseCode_CMD);
	
	LoadTranslations("vouchers.phrases.txt");
	LoadTranslations("vouchers_messages.phrases.txt");
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvAttempts)
	{
		strcopy(g_szAttempts, sizeof(g_szAttempts), newValue);
		g_cvAttempts.SetString(newValue);
	}
	else if (convar == g_cvBlockTime)
	{
		strcopy(g_szBlockTime, sizeof(g_szBlockTime), newValue);
		g_cvBlockTime.SetString(newValue);
	}
}

public Action Unblock_CMD(int client, int args)
{
	if (args == 0)
	{
		ReplyToCommand(client, "[Vouchers] Usage: sm_voucher_unblock \"<steamid>\"");
		ReplyToCommand(client, "[Vouchers] Steamid must be in quotes (\" \")");
		return Plugin_Handled;
	}
	
	char szSteamID[32];
	GetCmdArg(1, szSteamID, sizeof(szSteamID));
	int iTarget = GetClientFromSID(szSteamID);
	
	if (iTarget != -1 && g_bIsBanned[iTarget])
	{
		g_bIsBanned[iTarget] = false;
		ReplyToCommand(client, "[Vouchers] Player %N (%s) successfully unblocked.", iTarget, szSteamID);
		CPrintToChat(iTarget, "%t %t", "Chat_Prefix", "You have been unblocked from using vouchers");
	}
	else
		ReplyToCommand(client, "[Vouchers] Player \"%s\" successfully unblocked.", szSteamID);
	
	LogToFile(g_szLogPath, "Player %N (%s) got unblock by Admin!", client, szSteamID);
	char szQuery[512];
	g_hDatabase.Format(szQuery, sizeof(szQuery), "UPDATE Vouchers_users SET ban_enddate = '1970-02-01 00:00:00' WHERE steamid = '%s';", szSteamID);
	g_hDatabase.Query(SQL_Error, szQuery);
	
	return Plugin_Handled;
}

public Action DeleteVoucher_CMD(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "[Vouchers] Invalid number of arguments.");
		ReplyToCommand(client, "[Vouchers] Usage: sm_voucher_del <code>");
		return Plugin_Handled;
	}
	char szCode[64];
	GetCmdArg(1, szCode, sizeof(szCode));
	
	char szQuery[512];
	g_hDatabase.Format(szQuery, sizeof(szQuery), "SELECT code FROM Vouchers WHERE code = '%s' LIMIT 1;", szCode);
	g_hDatabase.Query(SQL_RemoveVoucherCallback, szQuery);
	
	return Plugin_Handled;
}

public Action SetVoucherCommands_CMD(int client, int args)
{
	if (args != 2)
	{
		ReplyToCommand(client, "========================================");
		ReplyToCommand(client, "[Vouchers] Invalid number of arguments.");
		ReplyToCommand(client, "[Vouchers] Usage: sm_voucher_cmds <code> \"<commands>\"");
		ReplyToCommand(client, "[Vouchers] Commands must be in quotes (\" \") and separated with ;");
		ReplyToCommand(client, "[Vouchers] Available variables: steamid32, steamid64, userid, username");
		ReplyToCommand(client, "========================================");
		return Plugin_Handled;
	}
	
	char szCode[64], szQuery[512];
	GetCmdArg(1, szCode, sizeof(szCode));
	GetCmdArg(2, g_szCommands, sizeof(g_szCommands));
	
	g_hDatabase.Format(szQuery, sizeof(szQuery), "SELECT code FROM Vouchers WHERE code = '%s' LIMIT 1;", szCode);
	g_hDatabase.Query(SQL_UpdateCodeCommandsCallback, szQuery);
	
	return Plugin_Handled;
}

public Action CreateVoucher_CMD(int client, int args)
{
	char szCode[64], szMessage[64], szUseCount[10], szLifetime[10];
	if (IsValidClient(client))
	{
		CPrintToChat(client, "%t %t", "Chat_Prefix", "Use ingame menu editor");
		return Plugin_Handled;
	}
	if (args != 4)
	{
		ReplyToCommand(client, "[Vouchers] Invalid number of arguments.");
		ReplyToCommand(client, "[Vouchers] Usage: sm_voucher_add <code> \"<translation_message>\" <voucher_use_count> <voucher_lifetime>");
		return Plugin_Handled;
	}
	
	GetCmdArg(1, szCode, sizeof(szCode));
	GetCmdArg(2, szMessage, sizeof(szMessage));
	GetCmdArg(3, szUseCount, sizeof(szUseCount));
	GetCmdArg(4, szLifetime, sizeof(szLifetime));
	
	if (StrEqual(szMessage, "none", false))
		szMessage = "";
	
	int iUseCount;
	if (StringToInt(szUseCount) <= 0)
		iUseCount = -1;
	else
		iUseCount = StringToInt(szUseCount);
	
	char szQuery[512];
	g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_CREATE_NEW_CODE, szCode, szMessage, iUseCount);
	g_hDatabase.Query(SQL_Error, szQuery);
	
	if (StringToInt(szLifetime) >= 1)
	{
		g_hDatabase.Format(szQuery, sizeof(szQuery), "UPDATE Vouchers SET enddate = DATE_ADD(NOW(), INTERVAL %i MINUTE) WHERE code = '%s';", StringToInt(szLifetime), szCode);
		g_hDatabase.Query(SQL_Error, szQuery);
	}
	
	ReplyToCommand(client, "========================================");
	ReplyToCommand(client, "Voucher \"%s\" successfully created!", szCode);
	if (szMessage[0] == '\0')
		ReplyToCommand(client, "Activation message - none");
	else
		ReplyToCommand(client, "Activation message - %s", szMessage);
	if (iUseCount == -1)
		ReplyToCommand(client, "Use count - Unlimited");
	else
		ReplyToCommand(client, "Use count - %s", szUseCount);
	if (StringToInt(szLifetime) <= 0)
		ReplyToCommand(client, "Lifetime - Forever");
	else
		ReplyToCommand(client, "Lifetime - %s minutes", szLifetime);
	ReplyToCommand(client, "Add activation commands: sm_voucher_cmds %s \"<commands>\"", szCode);
	ReplyToCommand(client, "========================================");
	
	return Plugin_Handled;
}

public Action GenerateVoucher_CMD(int client, int args)
{
	char szCode[10], szMessage[64], szUseCount[10], szLifetime[10];
	
	if (IsValidClient(client))
	{
		CPrintToChat(client, "%t %t", "Chat_Prefix", "Use ingame menu editor");
		return Plugin_Handled;
	}
	if (args != 3)
	{
		ReplyToCommand(client, "[Vouchers] Invalid number of arguments.");
		ReplyToCommand(client, "[Vouchers] Usage: sm_voucher_gen \"<translation_message>\" <voucher_use_count> <voucher_lifetime>");
		return Plugin_Handled;
	}
	
	GetCmdArg(1, szMessage, sizeof(szMessage));
	GetCmdArg(2, szUseCount, sizeof(szUseCount));
	GetCmdArg(3, szLifetime, sizeof(szLifetime));
	GenerateRandomCode(szCode, sizeof(szCode));
	
	if (StrEqual(szMessage, "none", false))
		szMessage = "";
	
	int iUseCount;
	if (StringToInt(szUseCount) <= 0)
		iUseCount = -1;
	else
		iUseCount = StringToInt(szUseCount);
	
	char szQuery[512];
	g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_CREATE_NEW_CODE, szCode, szMessage, iUseCount);
	g_hDatabase.Query(SQL_Error, szQuery);
	
	if (StringToInt(szLifetime) >= 1)
	{
		g_hDatabase.Format(szQuery, sizeof(szQuery), "UPDATE Vouchers SET enddate = DATE_ADD(NOW(), INTERVAL %i MINUTE) WHERE code = '%s';", StringToInt(szLifetime), szCode);
		g_hDatabase.Query(SQL_Error, szQuery);
	}
	
	ReplyToCommand(client, "========================================");
	ReplyToCommand(client, "Voucher \"%s\" successfully generated!", szCode);
	if (szMessage[0] == '\0')
		ReplyToCommand(client, "Activation message - none");
	else
		ReplyToCommand(client, "Activation message - %s", szMessage);
	if (iUseCount == -1)
		ReplyToCommand(client, "Use count - Unlimited");
	else
		ReplyToCommand(client, "Use count - %s", szUseCount);
	if (StringToInt(szLifetime) <= 0)
		ReplyToCommand(client, "Lifetime - Forever");
	else
		ReplyToCommand(client, "Lifetime - %s minutes", szLifetime);
	ReplyToCommand(client, "Add activation commands: sm_voucher_cmds %s \"<commands>\"", szCode);
	ReplyToCommand(client, "========================================");
	
	return Plugin_Handled;
}


public void OnClientPostAdminCheck(int client)
{
	if (g_bFullyConnected && IsValidClient(client))
	{
		g_bAdminEditor[client] = false;
		g_bPlayerFetched[client] = false;
		g_bIsBanned[client] = false;
		g_iSayMode[client] = 0;
		g_iClientCodesUsed[client] = 0;
		g_iClientUsageFails[client] = 0;
		g_szClientCodesList[client] = "";
		g_szClientBanEndDate[client] = "";
		g_szClientCode[client] = "";
		
		char szSteamID[32];
		if (!GetClientAuthId(client, AuthId_Steam2, szSteamID, 32))
		{
			KickClient(client, "Verification problem, please reconnect.");
			return;
		}
		
		char szQuery[512];
		g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_LOAD_USER_DATA, szSteamID);
		g_hDatabase.Query(SQL_LoadUserDataCallback, szQuery, GetClientUserId(client));
	}
}

public void OnClientDisconnect(int client)
{
	if (IsValidClient(client) && g_bPlayerFetched[client])
		UpdateUserData(client);
}

public void OnConfigsExecuted()
{
	LoadCodeTranslations();
	
	if (!g_hDatabase)
		Database.Connect(SQL_Connection, "Vouchers");
}

public Action UseCode_CMD(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	if (!g_bFullyConnected)
		return Plugin_Handled;
	if (g_bIsBanned[client])
	{
		CPrintToChat(client, "%t %t", "Chat_Prefix", "You are prohibited from using vouchers");
		return Plugin_Handled;
	}
	
	g_szClientCode[client] = "";
	char szQuery[512];
	
	if (args == 0)
		CodeMenu(client);
	else if (args >= 1)
	{
		g_hDatabase.Format(szQuery, sizeof(szQuery), "SELECT code FROM Vouchers WHERE enddate < NOW();");
		g_hDatabase.Query(SQL_DeleteCodeCallback, szQuery);
		
		char szCode[64];
		GetCmdArg(1, szCode, sizeof(szCode));
		g_szClientCode[client] = szCode;
		
		g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_LOAD_CODES);
		g_hDatabase.Query(SQL_UseCodeCallback, szQuery, GetClientUserId(client));
	}
	
	return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (StrContains(sArgs, "cancel") != -1)
	{
		if (g_iSayMode[client] == 1 || g_iSayMode[client] == 2 || g_iSayMode[client] == 3)
		{
			CPrintToChat(client, "%t %t", "Chat_Prefix", "Operation aborted");
			g_iSayMode[client] = 0;
			return Plugin_Handled;
		}
	}
	
	if (g_iSayMode[client] == 1)
	{
		Format(g_szClientCode[client], sizeof(g_szClientCode), sArgs[0]);
		ReplaceString(g_szClientCode[client], sizeof(g_szClientCode), " ", "");
		
		char szQuery[512];
		g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_LOAD_CODES);
		g_hDatabase.Query(SQL_UseCodeCallback, szQuery, GetClientUserId(client));
		
		g_iSayMode[client] = 0;
		return Plugin_Handled;
	}
	else if (g_iSayMode[client] == 2)
	{
		if (StrContains(sArgs, "none") != -1)
		{
			Format(g_szEditingCode_Command[client], sizeof(g_szEditingCode_Command), "");
			CPrintToChat(client, "%t %t", "Chat_Prefix", "Commands deleted");
			EditCodeMenu_Command(client);
			g_iSayMode[client] = 0;
			return Plugin_Handled;
		}
		else
		{
			Format(g_szEditingCode_Command[client], sizeof(g_szEditingCode_Command), sArgs);
			EditCodeMenu_Command(client);
			g_iSayMode[client] = 0;
			return Plugin_Handled;
		}
	}
	else if (g_iSayMode[client] == 3)
	{
		char szBuffer[64];
		Format(szBuffer, sizeof(szBuffer), sArgs);
		ReplaceString(szBuffer, sizeof(szBuffer), " ", "");
		CPrintToChat(client, "%t %t", "Chat_Prefix", "New Code Created", szBuffer);
		
		char szQuery[512];
		g_hDatabase.Format(szQuery, sizeof(szQuery), SQL_CREATE_CODE, szBuffer);
		g_hDatabase.Query(SQL_Error, szQuery);
		
		g_iSayMode[client] = 0;
		return Plugin_Handled;
	}
	if (StrContains(sArgs, "!code", false) != -1 || StrContains(sArgs, "!voucher", false) != -1)
		return Plugin_Handled;
	
	return Plugin_Continue;
} 