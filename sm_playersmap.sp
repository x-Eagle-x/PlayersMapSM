#include <sourcemod>
#include <geoip>
#include <adt_trie>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.00"
#define SQL_CONFIG "playersmap"

public Plugin myinfo = 
{
	name = "PlayersMap",
	author = "thEsp",
	description = "Shows a map about players' location.",
	version = PLUGIN_VERSION,
	url = "https://www.github.com/x-Eagle-x"
};

char g_szCountryCodes[MAXPLAYERS + 1][3];
StringMap g_PlayersCountry;
Database g_dbPlayers;

public void OnPluginStart()
{
	g_PlayersCountry = CreateTrie();
	
	if (!SQL_CheckConfig(SQL_CONFIG))
		SetFailState("Missing SQL config. :(");
		
	char szError[256];
	g_dbPlayers = SQL_Connect(SQL_CONFIG, false, szError, sizeof(szError));

	if (g_dbPlayers == null)
		SetFailState("Please check the SQL connection config. (%s)", szError);
		
	char szInitQuery[] = "CREATE TABLE IF NOT EXISTS players (id varchar(3), value int);";
	if (!SQL_FastQuery(g_dbPlayers, szInitQuery))
	{
		SQL_GetError(g_dbPlayers, szError, sizeof(szError));
		SetFailState("Something went wrong ;(. please contact the author! (%s)", szError);
	}
}

public void OnClientConnected(int iClient)
{
	char szClientIP[17];
	GetClientIP(iClient, szClientIP, sizeof(szClientIP));
	
	GeoipCode2(szClientIP, g_szCountryCodes[iClient]);
	SaveStats(g_szCountryCodes[iClient]);
}

public void OnClientDisconnect(int iClient)
{
	SaveStats(g_szCountryCodes[iClient], false);
	g_szCountryCodes[iClient][0] = 0;
}

void SaveStats(char[] szCountryCode, bool bConnect = true)
{
	int iPlayersPerCountry;
	char szQuery[128];
	Transaction QueryTransc;
	
	g_PlayersCountry.GetValue(szCountryCode, iPlayersPerCountry);
	g_PlayersCountry.SetValue(szCountryCode, bConnect ? ++iPlayersPerCountry : --iPlayersPerCountry);

	QueryTransc = SQL_CreateTransaction();

	if (iPlayersPerCountry)
	{
		Format(szQuery, sizeof(szQuery), "DELETE FROM players WHERE id = '%s';", szCountryCode);
		SQL_AddQuery(QueryTransc, szQuery);
		
		Format(szQuery, sizeof(szQuery), "INSERT INTO players VALUES('%s', %i);", szCountryCode, iPlayersPerCountry);
		SQL_AddQuery(QueryTransc, szQuery);
	}
	else
	{
		Format(szQuery, sizeof(szQuery), "DELETE FROM players WHERE id = '%s';", szCountryCode);
		SQL_AddQuery(QueryTransc, szQuery);
	}
	
	SQL_ExecuteTransaction(g_dbPlayers, QueryTransc, .onError = OnQueryError);
}

void OnQueryError(Database DB, any Data, int iQueries, const char[] szError, int iFailIndex, any[] QueryData)
{
	SetFailState("Failed to make a successful SQL query :(. (%s)", szError);
}

public void OnPluginEnd()
{
	delete(g_PlayersCountry);
	delete(g_dbPlayers);
}
