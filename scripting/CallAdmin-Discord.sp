#include <calladmin>
#include <clients>
#include <colorvariables>
#include <discordWebhookAPI>
#include <rankme>
#include <sourcebanschecker>
#include <sourcemod>
#pragma newdecls required
#pragma semicolon 1


public Plugin myinfo =
{
	name        = "CallAmin-Discord",
	author      = "Sarrus",
	description = "Send a discord message detailing the reason of the calladmin and more.",
	version     = "1.0.0",
	url         = "https://github.com/Sarrus1/CallAmin-Discord"
};

ConVar g_cvWebhookURL;
ConVar g_cvMention;
ConVar g_cvBotUsername;
ConVar g_cvFooterUrl;
ConVar g_cvEmbedColor;
ConVar g_cvHostname;
ConVar g_cvIP;
ConVar g_cvPort;

char g_szHostname[256];
char g_szIP[32];
char g_szPort[32];

bool g_bDebugging = false;

enum WaitingFor
{
	None,
	Calladmin,
	BugReport
}

public void
	OnPluginStart()
{
	g_cvWebhookURL  = CreateConVar("calladmin_discord_webhook", "", "The webhook to the discord channel where you want main record messages to be sent.", FCVAR_PROTECTED);
	g_cvMention     = CreateConVar("calladmin_discord_mention", "@here", "Optional discord mention to ping users when a new record has been set.");
	g_cvBotUsername = CreateConVar("calladmin_discord_username", "CallAdmin BOT", "Username of the bot");
	g_cvFooterUrl   = CreateConVar("calladmin_discord_footer_url", "https://images-ext-1.discordapp.net/external/tfTL-r42Kv1qP4FFY6sQYDT1BBA2fXzDjVmcknAOwNI/https/images-ext-2.discordapp.net/external/3K6ho0iMG_dIVSlaf0hFluQFRGqC2jkO9vWFUlWYOnM/https/images-ext-2.discordapp.net/external/aO9crvExsYt5_mvL72MFLp92zqYJfTnteRqczxg7wWI/https/discordsl.com/assets/img/img.png", "The url of the footer icon, leave blank to disable.");
	g_cvEmbedColor  = CreateConVar("calladmin_discord_embed_color", "0x00ffff", "Color of the embed for when main wr is beaten. Replace the usual '#' with '0x'.");
	g_cvIP          = CreateConVar("calladmin_discord_ip", "0.0.0.0", "Set your server IP here when auto detection is not working for you. (Use 0.0.0.0 to disable manually override)");
	g_cvHostname    = FindConVar("hostname");
	g_cvHostname.GetString(g_szHostname, sizeof g_szHostname);
	// g_cvHostname.AddChangeHook(OnConVarChanged);

	char szIP[32];
	g_cvIP.GetString(szIP, sizeof szIP);

	g_cvIP = FindConVar("ip");
	g_cvIP.GetString(g_szIP, sizeof g_szIP);
	if (StrEqual("0.0.0.0", g_szIP))
	{
		strcopy(g_szIP, sizeof g_szIP, szIP);
	}
	// g_cvIP.AddChangeHook(OnConVarChanged);
	g_cvPort = FindConVar("hostport");
	g_cvPort.GetString(g_szPort, sizeof g_szPort);

	RegAdminCmd("sm_calladmin_discordtest", CommandDiscordTest, ADMFLAG_ROOT, "Test the discord announcement");

	AutoExecConfig(true, "CallAdmin-Discord");
}


public Action CommandDiscordTest(int client, int args)
{
	CPrintToChat(client, "{blue}[CallAdmin-Discord] {green}Sending test message.");
	CallAdmin_OnReportPost(client, client, "This is the reason");
	CPrintToChat(client, "{blue}[CallAdmin-Discord] {green}Test message sent.");
	return Plugin_Handled;
}


public void CallAdmin_OnReportPost(int iClient, int iTarget, const char[] szReason)
{
	sendDiscordMessage(iClient, iTarget, "A reason");
}

void sendDiscordMessage(int iClient, int iTarget, char[] szReason)
{
	char webhook[1024];
	GetConVarString(g_cvWebhookURL, webhook, 1024);
	if (StrEqual(webhook, ""))
	{
		PrintToServer("[CallAdmin-Discord] No webhook specified, aborting.");
		return;
	}

	// Send Discord Announcement
	Webhook hook = new Webhook();

	char szMention[128];
	GetConVarString(g_cvMention, szMention, sizeof szMention);
	if (!StrEqual(szMention, ""))  // Checks if mention is disabled
	{
		hook.SetContent(szMention);
	}
	char szCalladminName[64];
	GetConVarString(g_cvBotUsername, szCalladminName, sizeof szCalladminName);

	hook.SetUsername(szCalladminName);

	Embed embed = new Embed();

	char color[16];
	GetConVarString(g_cvEmbedColor, color, sizeof color);
	embed.SetColor(StringToInt(color, 16));

	// Format title
	char szTitle[256];
	Format(szTitle, sizeof szTitle, "**steam://connect/%s:%s**", g_szIP, g_szPort);
	embed.SetTitle(szTitle);

	// Format Message
	char szClientID[256], szTargetID[256], szSteamClientID[64], szSteamTargetID[64], szNameClient[MAX_NAME_LENGTH], szNameTarget[MAX_NAME_LENGTH];

	GetClientName(iClient, szNameClient, sizeof szNameClient);
	GetClientAuthId(iClient, AuthId_SteamID64, szSteamClientID, sizeof szSteamClientID);
	Format(szClientID, sizeof szClientID, "[%s](https://steamcommunity.com/profiles/%s) - %d bans/ %d comms", szNameClient, szSteamClientID, SBCheckerGetClientsBans(iClient), SBCheckerGetClientsComms(iClient));

	GetClientName(iTarget, szNameTarget, sizeof szNameTarget);
	GetClientAuthId(iTarget, AuthId_SteamID64, szSteamTargetID, sizeof szSteamTargetID);

	Format(szTargetID, sizeof szTargetID, "[%s](https://steamcommunity.com/profiles/%s) - %d bans/ %d comms", szNameTarget, szSteamTargetID, SBCheckerGetClientsBans(iTarget), SBCheckerGetClientsComms(iTarget));

	char szClientStats[32], szTargetStats[32];
	int  stClient[35], stTarget[35];
	RankMe_GetStats(iClient, stClient);
	RankMe_GetStats(iTarget, stTarget);

	char szClientTime[32], szTargetTime[32];
	UnixToTime(stClient[9], szClientTime, sizeof szClientTime);
	UnixToTime(stTarget[9], szTargetTime, sizeof szTargetTime);

	Format(szClientStats, sizeof szClientStats, "**%d**pts - %s", RankMe_GetPoints(iClient, true), szClientTime);
	Format(szTargetStats, sizeof szTargetStats, "**%d**pts - %s", RankMe_GetPoints(iTarget, true), szTargetTime);

	char szClientSess[32], szTargetSess[32];

	char szClientTimeSess[32], szTargetTimeSess[32];

	UnixToTime(RoundFloat(GetClientTime(iClient)), szClientTimeSess, sizeof szClientTimeSess);
	UnixToTime(RoundFloat(GetClientTime(iTarget)), szTargetTimeSess, sizeof szTargetTimeSess);

	Format(szClientSess, sizeof szClientSess, "**%d**kills/**%d**deaths - %s", GetClientFrags(iClient), GetClientDeaths(iClient), szClientTimeSess);
	Format(szTargetSess, sizeof szTargetSess, "**%d**kills/**%d**deaths - %s", GetClientFrags(iTarget), GetClientDeaths(iTarget), szTargetTimeSess);

	// Add reporter fields
	EmbedField field = new EmbedField("Reporter", szClientID, true);
	embed.AddField(field);

	field = new EmbedField("Global stats", szClientStats, true);
	embed.AddField(field);

	field = new EmbedField("Session stats", szClientSess, true);
	embed.AddField(field);

	// Add target fields
	field = new EmbedField("Target", szTargetID, true);
	embed.AddField(field);

	field = new EmbedField("Global stats", szTargetStats, true);
	embed.AddField(field);

	field = new EmbedField("Session stats", szTargetSess, true);
	embed.AddField(field);

	field = new EmbedField("Reason", szReason, true);
	embed.AddField(field);

	// Add Footer
	EmbedFooter footer = new EmbedFooter();
	char        buffer[1000];
	Format(buffer, sizeof buffer, "Server: %s", g_szHostname);
	footer.SetText(buffer);

	char szFooterUrl[1024];
	GetConVarString(g_cvFooterUrl, szFooterUrl, sizeof szFooterUrl);
	if (!StrEqual(szFooterUrl, ""))
	{
		footer.SetIconURL(szFooterUrl);
		embed.SetFooter(footer);
	}

	hook.AddEmbed(embed);
	if (g_bDebugging)
	{
		char szDebugOutput[10000];
		hook.ToString(szDebugOutput, sizeof szDebugOutput);
		PrintToServer(szDebugOutput);
	}
	hook.Execute(webhook, OnWebHookExecuted, iClient);
	delete hook;
}


public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvHostname.GetString(g_szHostname, sizeof g_szHostname);
}

void OnWebHookExecuted(HTTPResponse response, int client)
{
	if (g_bDebugging)
	{
		PrintToServer("Processed client n°%d's webhook, status %d", client, response.Status);
		if (response.Status != HTTPStatus_NoContent)
		{
			PrintToServer("An error has occured while sending the webhook.");
			return;
		}
		PrintToServer("The webhook has been sent successfuly.");
	}
}

stock void UnixToTime(int time, char[] szBuffer, int iBufferSize)
{
	if (time < 3600)
	{
		int minutes = (time % 3600) / 60;
		int seconds = time % 60;

		Format(szBuffer, iBufferSize, "%dm:%ds", minutes, seconds);
		return;
	}
	int hours   = time / 3600;
	int minutes = (time % 3600) / 60;

	Format(szBuffer, iBufferSize, "%dh:%dm", hours, minutes);
}