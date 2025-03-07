#include <sourcemod>
#include <entity_prop_stocks>
#include <sdktools_functions>
#include <sdkhooks>


#define TEAM_INFECTED	3
#define ZC_JOCKEY		5


bool	g_isHitWithOpenFire[MAXPLAYERS + 1] = { false, ... };
int		g_lastJockeyFireHitter[MAXPLAYERS + 1] = { 0, ... };
Handle	g_ignitionTimers[MAXPLAYERS + 1] = { null, ... };


public Plugin myinfo =
{
	name = "L4D2 Jockey Extinguish Fix",
	author = "Skeletor",
	description = "Prevents the bug when riding jockey extinguishes himself a couple seconds after jumping on someone",
	version = "1.0",
	url = ""
}

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("jockey_ride", Event_JockeyRide);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client))
		return;
	
	g_isHitWithOpenFire[client] = false;
	g_lastJockeyFireHitter[client] = 0;
	
	if (IsJockey(client))	
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
	int jockey = GetClientOfUserId(event.GetInt("userid"));
	if (g_isHitWithOpenFire[jockey])
		ReigniteJockey(jockey);
}

Action Timer_Reignite(Handle timer, int jockey)
{
	if (!IsJockey(jockey) || !IsPlayerAlive(jockey) || GetEntPropEnt(jockey, Prop_Send, "m_jockeyVictim") <= 0 || (GetEntityFlags(jockey) & FL_INWATER))
	{
		g_ignitionTimers[jockey] = null;
		return Plugin_Stop;
	}
	
	IgniteJockey(jockey);
	return Plugin_Continue;
}

Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	char inflictorCN[16];
	GetEdictClassname(inflictor, inflictorCN, sizeof(inflictorCN));
	
	if ((damagetype == DMG_BURN) || StrEqual(inflictorCN, "inferno", false))
	{
		g_isHitWithOpenFire[victim] = true;
		g_lastJockeyFireHitter[victim] = attacker;
		
		if (GetEntPropEnt(victim, Prop_Send, "m_jockeyVictim") > 0)
			ReigniteJockey(victim);
	}
	
	return Plugin_Continue;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool IsJockey(int client)
{
	return IsValidClient(client)
		&& GetClientTeam(client) == TEAM_INFECTED
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_JOCKEY;
}

void IgniteJockey(int jockey)
{
	// if last attacker isnt valid (eg. left the game), count jockey as self attacker. dunno if this check even needed :liam_al:
	int lastHitter = g_lastJockeyFireHitter[jockey];
	int attacker = IsValidClient(lastHitter) ? lastHitter : jockey;
	
	ExtinguishEntity(jockey);
	SDKHooks_TakeDamage(jockey, attacker, attacker, 0.0, DMG_BURN);
}

void ReigniteJockey(int jockey)
{
	if (!g_ignitionTimers[jockey])
		g_ignitionTimers[jockey] = CreateTimer(0.2, Timer_Reignite, jockey, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}