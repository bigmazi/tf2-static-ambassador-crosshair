#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <tf2attributes>

#pragma semicolon 1

public Plugin myinfo = {
	name = "[TF2] Static Ambassador crosshair",
	author = "bigmazi",
	description = "Disables the feature that resizes the crosshair of the Ambassador after making a shot",
	version = "1.0.0.0",
	url = "https://steamcommunity.com/id/bmazi"
}

#define AMBASSADOR_DEFIDX 61

enum CrosshairPreference
{
	Crosshair_Dynamic,
	Crosshair_Static,
	Crosshair_Default
}

CrosshairPreference g_preference[MAXPLAYERS + 1];

int g_off__m_flLastAccuracyCheck;

Handle g_cookie;

ConVar sm_static_ambassador_crosshair_plugin_enabled;
ConVar sm_static_ambassador_crosshair_by_default;

void TrySetHeadshotAttribute(int weapon, bool enableHeadshotsAttribute)
{
	int defidx = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	
	if (defidx == AMBASSADOR_DEFIDX)
	{
		float value = enableHeadshotsAttribute ? 1.0 : 0.0;
		TF2Attrib_SetByName(weapon, "revolver use hit locations", value);
	}
}

void TrySetHeadshotAttributeForPrimary(int player, bool enableHeadshotsAttribute)
{
	int weapon = GetPlayerWeaponSlot(player, 0);
	
	if (weapon != -1)
	{
		TrySetHeadshotAttribute(weapon, enableHeadshotsAttribute);
	}
}

void TrySetHeadshotAttributeForPrimaryAccordingToPreferences(int player)
{
	bool useStaticCrosshair;
	
	switch (g_preference[player])
	{
		case Crosshair_Default:
		{
			useStaticCrosshair =
				sm_static_ambassador_crosshair_by_default.BoolValue;
		}
		
		case Crosshair_Dynamic:
		{
			useStaticCrosshair = false;
		}
		
		case Crosshair_Static:
		{
			useStaticCrosshair = true;
		}
	}
	
	bool enableHeadshotsAttribute = !useStaticCrosshair;
	TrySetHeadshotAttributeForPrimary(player, enableHeadshotsAttribute);
}

void EnablePluginEffect()
{
	HookEvent("post_inventory_application", OnPostInventoryApplication);
	
	for (int player = 1; player <= MaxClients; player++)
	{
		if (IsClientInGame(player))
		{
			SDKHook(player, SDKHook_TraceAttack, OnTraceAttack);
			TrySetHeadshotAttributeForPrimaryAccordingToPreferences(player);
		}
	}
}

void DisablePluginEffect()
{
	UnhookEvent("post_inventory_application", OnPostInventoryApplication);
	
	for (int player = 1; player <= MaxClients; player++)
	{
		if (IsClientInGame(player))
		{
			SDKUnhook(player, SDKHook_TraceAttack, OnTraceAttack);
			
			bool enableHeadshotsAttribute = true;
			TrySetHeadshotAttributeForPrimary(player, enableHeadshotsAttribute);
		}
	}
}

Action OnTraceAttack(
	int victim, int& attacker, int& inflictor,
	float& damage, int& damagetype,
	int& ammotype, int hitbox, int hitgroup)
{
	if (attacker != inflictor)
		return Plugin_Continue;
	
	if (!(1 <= attacker <= MaxClients))
		return Plugin_Continue;
	
	int weapon = GetPlayerWeaponSlot(attacker, 0);	
	if (weapon == -1) return Plugin_Continue;
	
	int defidx = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");	
	if (defidx != AMBASSADOR_DEFIDX) return Plugin_Continue;
	
	float now = GetGameTime();
	
	float m_flLastAccuracyCheck =
		view_as<float>(GetEntData(weapon, g_off__m_flLastAccuracyCheck));
	
	if (now - m_flLastAccuracyCheck <= 1.0)
		return Plugin_Continue;
	
	if (damagetype & DMG_USE_HITLOCATIONS)
		return Plugin_Continue;
	
	damagetype |= DMG_USE_HITLOCATIONS;
	return Plugin_Changed;
}

void OnPostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	
	int player = GetClientOfUserId(userid);	
	if (player == 0) return;
	
	TrySetHeadshotAttributeForPrimaryAccordingToPreferences(player);
}

void OnPluginToggled(ConVar cvar, const char[] oldval, const char[] newval)
{
	if (!!StringToInt(oldval) == !!StringToInt(newval))
		return;
	
	bool enable = sm_static_ambassador_crosshair_plugin_enabled.BoolValue;
	
	if (enable)
	{
		EnablePluginEffect();
	}
	else
	{
		DisablePluginEffect();
	}
}

void OnDefaultModeChanged(ConVar cvar, const char[] oldval, const char[] newval)
{
	if (!sm_static_ambassador_crosshair_plugin_enabled.BoolValue)
		return;
	
	for (int player = 1; player <= MaxClients; player++)
	{
		if (IsClientInGame(player))
		{
			TrySetHeadshotAttributeForPrimaryAccordingToPreferences(player);
		}
	}
}

Action cl_static_ambassador_crosshair(int player, int argsCount)
{
	if (player == 0)
	{
		PrintToServer("[SM] \"cl_static_ambassador_crosshair\" is for clients to execute");
	}
	else
	{
		if (argsCount < 1)
		{
			char str[2];
			
			if (g_preference[player] != Crosshair_Default)
			{
				str[0] = view_as<char>(g_preference[player]) + '0';
			}
			
			ReplyToCommand(
				player, ""
				... "[SM] \"cl_static_ambassador_crosshair\" = \"%s\" (def. \"\")\n"
				... "- \"0\" = dynamic Ambassador crosshair, "
				... "\"1\" = static Ambassador crosshair, "
				... "\"\" = whatever server sets as default",
				str
			);
		}
		else
		{
			char str[12];
			GetCmdArg(1, str, sizeof(str));
			
			if (str[0] == '\0')
			{
				g_preference[player] = Crosshair_Default;
				SetClientCookie(player, g_cookie, "");
			}
			else
			{
				g_preference[player] = !!StringToInt(str)
					? Crosshair_Static
					: Crosshair_Dynamic;
				
				char newCookieValue[2];
				newCookieValue[0] = view_as<char>(g_preference[player]) + '0';
				
				SetClientCookie(player, g_cookie, newCookieValue);
				
			}
			
			if (sm_static_ambassador_crosshair_plugin_enabled.BoolValue)
			{
				TrySetHeadshotAttributeForPrimaryAccordingToPreferences(player);
			}
		}
	}
	
	return Plugin_Handled;
}

public void OnClientCookiesCached(int player)
{
	char buf[24];
	GetClientCookie(player, g_cookie, buf, sizeof(buf));
	
	if (buf[0] == '\0')
	{
		g_preference[player] = Crosshair_Default;
	}
	else
	{
		g_preference[player] =
			view_as<CrosshairPreference>(buf[0] - '0');
	}
}

public void OnClientPutInServer(int player)
{
	if (!AreClientCookiesCached(player))
	{
		g_preference[player] = Crosshair_Default;
	}
	
	SDKHook(player, SDKHook_TraceAttack, OnTraceAttack);
}

public void OnPluginStart()
{
	// CTFWeaponBuilder::m_iBuildState, just like CTFRevolver::m_flLastAccuracyCheck,
	// is located right after CTFWeaponBase table
	g_off__m_flLastAccuracyCheck = FindSendPropInfo(
		"CTFWeaponBuilder",
		"m_iBuildState"
	);
	
	g_cookie = RegClientCookie(
		"cookie_ambyxhair",
		"Static Ambassador crosshair",
		CookieAccess_Protected
	);
	
	RegConsoleCmd(
		"cl_static_ambassador_crosshair",
		cl_static_ambassador_crosshair,
		"Command that mimics a client-side cvar. \"0\" = dynamic Ambassador crosshair, \"1\" = static Ambassador crosshair, \"\" = follow server's suggestion (i.e. \"sm_static_ambassador_crosshair_by_default\")"
	);
	
	sm_static_ambassador_crosshair_by_default = CreateConVar(
		"sm_static_ambassador_crosshair_by_default",
		"1",
		"Whether clients who have not executed \"cl_static_ambassador_crosshair\" should have the Ambassador crosshair static (1) or dynamic (0)",
		0,
		true, 0.0,
		true, 1.0
	);
	
	sm_static_ambassador_crosshair_plugin_enabled = CreateConVar(
		"sm_static_ambassador_crosshair_plugin_enabled",
		"1",
		"If enabled, the \"static-ambassador-crosshair\" plugin has effect",
		0,
		true, 0.0,
		true, 1.0
	);
	
	HookConVarChange(
		sm_static_ambassador_crosshair_plugin_enabled,
		OnPluginToggled
	);
	
	HookConVarChange(
		sm_static_ambassador_crosshair_by_default,
		OnDefaultModeChanged
	);
	
	for (int player = 1; player <= MaxClients; player++)
	{
		if (IsClientInGame(player))
		{
			g_preference[player] = Crosshair_Default;
			
			if (AreClientCookiesCached(player))
			{
				OnClientCookiesCached(player);
			}
		}
	}
	
	if (sm_static_ambassador_crosshair_plugin_enabled.BoolValue)
	{
		EnablePluginEffect();
	}
	
	AutoExecConfig(true, "static-ambassador-crosshair");
}

public void OnPluginEnd()
{
	if (sm_static_ambassador_crosshair_plugin_enabled.BoolValue)
	{
		DisablePluginEffect();
	}
}