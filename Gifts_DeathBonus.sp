#pragma semicolon 1

#include <sourcemod>
#include <sdktools_gamerules>
#include <gifts_core>

public Plugin myinfo =
{
    name = "[Gifts] Death Bonus",
    author = "R1KO",
    version = "1.0.0"
}

#define SZF(%0)        %0, sizeof(%0)
#define CID(%0)        GetClientOfUserId(%0)
#define CUD(%0)        GetClientUserId(%0)

#define PMP            PLATFORM_MAX_PATH
#define MTL            MAX_TARGET_LENGTH
#define MPL            MAXPLAYERS
#define MCL            MaxClients

bool g_bIsCSGO = false;
ConVar g_hEnabled;
ConVar g_hOnlyEnemy;
ConVar g_hChance;

public void OnPluginStart()
{
    g_hEnabled = CreateConVar("sm_gifts_death_bonus_enabled", "1", "Включено ли выпадение подарка из убитых", _, true, 0.0, true, 1.0);
    g_hOnlyEnemy = CreateConVar("sm_gifts_death_bonus_only_enemy", "1", "Подарок выпадает только из убитых противником?", _, true, 0.0, true, 1.0);
    g_hChance = CreateConVar("sm_gifts_death_bonus_chance", "50", "Шанс выпадения подарка из убитого (0 - 100)", _, true, 0.0, true, 100.0);

    HookEvent("player_death", Event_PlayerDeath);

    g_bIsCSGO = (GetEngineVersion() == Engine_CSGO);
}

public Event_PlayerDeath(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
    if(!g_hEnabled.BoolValue)
    {
        return;
    }

    if(g_bIsCSGO && GameRules_GetProp("m_bWarmupPeriod"))
    {
        return;
    }

    int iClient = CID(hEvent.GetInt("userid"));
    if(!iClient)
    {
        return;
    }

    if(g_hOnlyEnemy.BoolValue)
    {
        int iAttaker = CID(hEvent.GetInt("attacker"));
        if(iAttaker > 0 && iClient != iAttaker && GetClientTeam(iClient) != GetClientTeam(iAttaker))
        {
            return;
        }
    }

    if (RoundToNearest(GetURandomFloat() * 100) > g_hChance.IntValue) 
    {
        return;
    }

    KeyValues hGift = Gifts_GetRandomFromConfig(true);

    float fPos[3];
    GetClientAbsOrigin(iClient, fPos);
    fPos[2] -= 40.0;
    Gifts_Create(fPos, hGift, false);
}
