#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <gifts_core>

#define DEBUG_MODE 0

#define PLUGIN_VERSION      "3.1.3"

public Plugin:myinfo =
{
	name = "[Gifts] Core",
	author = "R1KO",
	version = PLUGIN_VERSION
}

#define SZF(%0)		%0, sizeof(%0)
#define CID(%0)		GetClientOfUserId(%0)
#define CUD(%0)		GetClientUserId(%0)

#define PMP			PLATFORM_MAX_PATH
#define MTL			MAX_TARGET_LENGTH
#define MPL			MAXPLAYERS
#define MCL			MaxClients

new Handle:g_hKeyValues;

new Handle:g_hForward_OnLoadGift,
	Handle:g_hForward_OnCreatedGift,
	Handle:g_hForward_OnPickUpGift_Pre,
	Handle:g_hForward_OnPickUpGift_Post;

new g_iGiftsCount,
	String:g_sGlobalModel[128],
	String:g_sGlobalSpawnSound[128],
	String:g_sGlobalPickUpSound[128],
	Float:g_fGlobalLifeTime,
	bool:g_bFromDeath = false,
	bool:g_bIsCSGO = false;

public OnPluginStart()
{
	CreateConVar("sm_gifts_core_version", PLUGIN_VERSION, "GIFTS-CORE VERSION", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);

	g_hForward_OnLoadGift			= CreateGlobalForward("Gifts_OnLoadGift",			ET_Ignore,	Param_Cell, Param_Cell);
	g_hForward_OnCreatedGift		= CreateGlobalForward("Gifts_OnCreatedGift",		ET_Ignore,	Param_Cell, Param_Cell);
	g_hForward_OnPickUpGift_Pre		= CreateGlobalForward("Gifts_OnPickUpGift_Pre",		ET_Hook,	Param_Cell, Param_Cell);
	g_hForward_OnPickUpGift_Post	= CreateGlobalForward("Gifts_OnPickUpGift_Post",	ET_Ignore,	Param_Cell, Param_Cell);

	HookEvent("player_death", Event_PlayerDeath);

	g_bIsCSGO = (GetEngineVersion() == Engine_CSGO);

	RegAdminCmd("sm_gifts_reload", Reload_CMD, ADMFLAG_ROOT);
}

public Action:Reload_CMD(iClient, iArgs)
{
	OnConfigsExecuted();

	return Plugin_Handled;
}

public OnConfigsExecuted()
{
	if(g_hKeyValues)
	{
		CloseHandle(g_hKeyValues);
	}

	g_iGiftsCount = 0;

	decl String:sBuffer[PMP], String:sPath[PMP];
	g_hKeyValues = CreateKeyValues("Gifts");
	BuildPath(Path_SM, SZF(sBuffer), "configs/gifts.cfg");
	if (FileToKeyValues(g_hKeyValues, sBuffer))
	{
		KvGetString(g_hKeyValues, "Default_Model", SZF(g_sGlobalModel), "models/items/cs_gift.mdl");
		UTIL_LoadModel(g_sGlobalModel);

		KvGetString(g_hKeyValues, "Default_SpawnSound", SZF(g_sGlobalSpawnSound), "items/gift_drop.wav");
		UTIL_LoadSound(g_sGlobalSpawnSound);
		
		if(g_bIsCSGO)
		{
			Format(SZF(g_sGlobalSpawnSound), "*%s", g_sGlobalSpawnSound);
		}

		KvGetString(g_hKeyValues, "Default_PickUpSound", SZF(g_sGlobalPickUpSound), "items/gift_drop.wav");
		UTIL_LoadSound(g_sGlobalPickUpSound);

		if(g_bIsCSGO)
		{
			Format(SZF(g_sGlobalPickUpSound), "*%s", g_sGlobalPickUpSound);
		}

		g_fGlobalLifeTime = KvGetFloat(g_hKeyValues, "Default_Lifetime", 15.0);
		g_bFromDeath = bool:KvGetNum(g_hKeyValues, "Gift_Death");

		if(KvGotoFirstSubKey(g_hKeyValues))
		{
			do
			{
				IntToString(++g_iGiftsCount, sBuffer, 16);
				KvSetSectionName(g_hKeyValues, sBuffer);
				
				Forward_OnLoadGift(g_iGiftsCount);
				//	LogMessage("LoadGift: '%s'", sBuffer);

				KvGetString(g_hKeyValues, "Model", SZF(sBuffer));
				if(sBuffer[0])
				{
					if(!strcmp(sBuffer, g_sGlobalModel) || !UTIL_LoadModel(sBuffer))
					{
						KvSetString(g_hKeyValues, "Model", NULL_STRING);
					}
				}

				KvGetString(g_hKeyValues, "SpawnSound", SZF(sBuffer));
				if(sBuffer[0])
				{
					if(!strcmp(sBuffer, g_sGlobalSpawnSound) || !UTIL_LoadSound(sBuffer))
					{
						KvSetString(g_hKeyValues, "SpawnSound", NULL_STRING);
					}
					else if(g_bIsCSGO)
					{
						FormatEx(SZF(sPath), "*%s", sBuffer);
						KvSetString(g_hKeyValues, "SpawnSound", sPath);
					}
				}

				KvGetString(g_hKeyValues, "PickUpSound", SZF(sBuffer));
				if(sBuffer[0])
				{
					if(!strcmp(sBuffer, g_sGlobalPickUpSound) || !UTIL_LoadSound(sBuffer))
					{
						KvSetString(g_hKeyValues, "PickUpSound", NULL_STRING);
					}
					else if(g_bIsCSGO)
					{
						FormatEx(SZF(sPath), "*%s", sBuffer);
						KvSetString(g_hKeyValues, "PickUpSound", sPath);
					}
				}

				/*
				KvGetString(g_hKeyValues, "TextToAll", SZF(sBuffer));
				if(sBuffer[0])
				{
					//	LogMessage("TextToAll: '%s'", sBuffer);
					EditText(SZF(sBuffer));
					//	LogMessage("EditText->TextToAll: '%s'", sBuffer);
					KvSetString(g_hKeyValues, "TextToAll", sBuffer);
				}

				KvGetString(g_hKeyValues, "TextToPlayer", SZF(sBuffer));
				if(sBuffer[0])
				{
					//	LogMessage("TextToPlayer: '%s'", sBuffer);
					EditText(SZF(sBuffer));
					//	LogMessage("EditText->TextToPlayer: '%s'", sBuffer);
					KvSetString(g_hKeyValues, "TextToPlayer", sBuffer);
				}*/
				

			} while (KvGotoNextKey(g_hKeyValues));
		}
		
		if(g_iGiftsCount == 0)
		{
			SetFailState("[Gifts] Core: Не удалось найти ни одного подарка");
		}
	}
	else
	{
		SetFailState("[Gifts] Core: Не удалось открыть файл '%s'", sPath);
	}

	ReadDownloads();
}

ReadDownloads()
{
	new Handle:hFile = OpenFile("addons/sourcemod/configs/giftsdownloadlist.ini", "r");

	if (hFile != INVALID_HANDLE)
	{
		decl String:sBuffer[PMP];
		while (!IsEndOfFile(hFile) && ReadFileLine(hFile, SZF(sBuffer)))
		{
			TrimString(sBuffer);
			if(sBuffer[0] && IsCharAlpha(sBuffer[0]) && StrContains(sBuffer, "//") == -1 && FileExists(sBuffer))
			{
				AddFileToDownloadsTable(sBuffer);
			}
		}
		CloseHandle(hFile);
	}
	else
	{
		LogError("[Gifts] Core: Не удалось открыть файл 'addons/sourcemod/configs/giftsdownloadlist.ini'");
	}
}

bool:UTIL_LoadSound(String:sSound[])
{
	if(sSound[0])
	{
		decl String:sBuffer[PMP];
		FormatEx(SZF(sBuffer), "sound/%s", sSound);

		if(FileExists(sBuffer, true) || FileExists(sBuffer))
		{
			AddFileToDownloadsTable(sBuffer);
			
			if(g_bIsCSGO)
			{
				AddToStringTable(FindStringTable("soundprecache"), sSound);
			}
			else
			{
				PrecacheSound(sSound, true);
			}

			return true;
		}
	}

	return false;
}

bool:UTIL_LoadModel(const String:sModel[])
{
	if(sModel[0] && FileExists(sModel))
	{
		PrecacheModel(sModel, true);
		AddFileToDownloadsTable(sModel);
		return true;
	}

	return false;
}

public Event_PlayerDeath(Handle:hEvent, const String:sEvName[], bool:bDontBroadcast)
{
	if(GameRules_GetProp("m_bWarmupPeriod"))
	{
		return;
	}

	new iClient = CID(GetEventInt(hEvent, "userid"));
	if(iClient)
	{
		if(g_bFromDeath)
		{
			new iAttaker = CID(GetEventInt(hEvent, "attacker"));
			if(iAttaker > 0 && iClient != iAttaker && GetClientTeam(iClient) != GetClientTeam(iAttaker))
			{
				decl iGift, String:sBuffer[16];
				iGift = Math_GetRandomInt(1, g_iGiftsCount);
				IntToString(iGift, SZF(sBuffer));
				KvRewind(g_hKeyValues);
				if(KvJumpToKey(g_hKeyValues, sBuffer))
				{
					if (Math_GetRandomInt(0, 100) <= KvGetNum(g_hKeyValues, "Chance", 20))
					{
						decl Float:fPos[3];
						GetClientAbsOrigin(iClient, fPos);
						fPos[2] -= 40.0;
						SpawnGift(iClient, fPos, iGift);
					}
				}
			}
		}
	}
}

SpawnGift(iClient = 0, const Float:fPos[3], index)
{
	#if DEBUG_MODE
	DEBUG_PrintToAll("SpawnGift: %i", index);
	#endif

	new iEntity = CreateEntityByName("prop_physics_override");
	if(iEntity)
	{
		decl String:sTargetName[32], String:sBuffer[PMP];
		FormatEx(SZF(sTargetName), "gift_%i_%i", iEntity, index);
		#if DEBUG_MODE
		DEBUG_PrintToAll("SpawnGift:: %s", sTargetName);
		#endif
		DispatchKeyValue(iEntity, "solid", "6");
		DispatchKeyValue(iEntity, "physicsmode", "2");
		DispatchKeyValue(iEntity, "massScale", "1.0");
		DispatchKeyValue(iEntity, "classname", "gift");
		DispatchKeyValueVector(iEntity, "origin", fPos);
		KvGetString(g_hKeyValues, "Model", SZF(sBuffer));
		DispatchKeyValue(iEntity, "model", sBuffer[0] ? sBuffer:g_sGlobalModel);

		DispatchKeyValue(iEntity, "targetname", sTargetName);
		if(DispatchSpawn(iEntity))
		{
			SetEntProp(iEntity, Prop_Send, "m_usSolidFlags", 8);
			SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 1);
			
		//	TeleportEntity(iEntity, fPos, NULL_VECTOR, NULL_VECTOR);

			FormatEx(SZF(sBuffer), "OnUser1 !self:kill::%0.2f:-1", KvGetFloat(g_hKeyValues, "Lifetime", g_fGlobalLifeTime));
			SetVariantString(sBuffer);
			AcceptEntityInput(iEntity, "AddOutput"); 
			AcceptEntityInput(iEntity, "FireUser1");
			SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", iClient);

			if(KvGetNum(g_hKeyValues, "Rotate", 1))
			{
				new iRotating = CreateEntityByName("func_rotating");
				DispatchKeyValueVector(iRotating, "origin", fPos);
				FormatEx(SZF(sTargetName), "rotating_%i", iRotating);
				DispatchKeyValue(iRotating, "targetname", sTargetName);
				DispatchKeyValue(iRotating, "maxspeed", "160");
				DispatchKeyValue(iRotating, "friction", "0");
				DispatchKeyValue(iRotating, "dmg", "0");
				DispatchKeyValue(iRotating, "solid", "0");
				DispatchKeyValue(iRotating, "spawnflags", "64");
				DispatchSpawn(iRotating);
				
				SetEntPropEnt(iRotating, Prop_Send, "m_hOwnerEntity", iEntity);

				SetVariantString("!activator");
				AcceptEntityInput(iEntity, "SetParent", iRotating, iRotating);

				FormatEx(SZF(sBuffer), "%s,Kill,,0,-1", sTargetName);
				DispatchKeyValue(iEntity, "OnKilled", sBuffer);
				AcceptEntityInput(iRotating, "Start");
			}
			else
			{
				SetEntityMoveType(iEntity, MOVETYPE_NONE);
			}
			
			Forward_OnCreatedGift(iEntity);

			SDKHook(iEntity, SDKHook_StartTouchPost, Hook_GiftStartTouchPost);
			
			KvGetString(g_hKeyValues, "SpawnSound", SZF(sBuffer));
			EmitAmbientSound(sBuffer[0] ? sBuffer:g_sGlobalSpawnSound, fPos, iEntity, SNDLEVEL_NORMAL);

			return iEntity;
		}
	}
	return -1;
}

public Hook_GiftStartTouchPost(iEntity, iClient)
{
	#if DEBUG_MODE
	DEBUG_PrintToAll("Hook_GiftStartTouch:: iEntity %i, iClient %i", iEntity, iClient);
	#endif
	if (iClient > 0 && iClient <= MCL && IsPlayerAlive(iClient) && !IsFakeClient(iClient))
	{
		#if DEBUG_MODE
		DEBUG_PrintToAll("Hook_GiftStartTouch:: true");
		#endif

		decl String:sIndex[32];
		GetEntPropString(iEntity, Prop_Data, "m_iName", SZF(sIndex));
		#if DEBUG_MODE
		DEBUG_PrintToAll("m_iName:: %s", sIndex);
		#endif
		strcopy(SZF(sIndex), sIndex[FindCharInString(sIndex, '_', true)+1]);
		#if DEBUG_MODE
		DEBUG_PrintToAll("KvJumpToKey:: %s", sIndex);
		#endif
		KvRewind(g_hKeyValues);
		if(KvJumpToKey(g_hKeyValues, sIndex))
		{
			#if DEBUG_MODE
			DEBUG_PrintToAll("Hook_GiftStartTouch: index: %s, Client: %i", sIndex, iClient);
			#endif
			switch (Forward_OnPickUpGift_Pre(iClient))
			{
			case Plugin_Handled:
				{
					#if DEBUG_MODE
					DEBUG_PrintToAll("Plugin_Handled");
					#endif
					return;
				}
			case Plugin_Stop:
				{
					#if DEBUG_MODE
					DEBUG_PrintToAll("Plugin_Stop");
					#endif
					
					KillGift(iEntity);
					return;
				}
			case Plugin_Continue:
				{
					#if DEBUG_MODE
					DEBUG_PrintToAll("Plugin_Continue");
					#endif

					decl String:sBuffer[PMP], Float:fPos[3];

					GetClientAbsOrigin(iClient, Float:fPos);
					KvGetString(g_hKeyValues, "PickUpSound", SZF(sBuffer));
					EmitAmbientSound(sBuffer[0] ? sBuffer:g_sGlobalPickUpSound, fPos, iEntity, SNDLEVEL_NORMAL);

					//	LogMessage("PickUpGift: '%s'", sIndex[5]);
					
					KvGetString(g_hKeyValues, "TextToAll", SZF(sBuffer));
					#if DEBUG_MODE
					DEBUG_PrintToAll("TextToAll = '%s'", sBuffer);
					#endif
					//	LogMessage("TextToAll: '%s'", sBuffer);
					if(sBuffer[0])
					{
					//	EditText(SZF(sBuffer));
						ReplaceName(SZF(sBuffer), iClient);
						EditText(SZF(sBuffer));
						//	LogMessage("TextToAll: '%s'", sBuffer);
						for (new i = 1; i <= MCL; ++i)
						{
							if (i != iClient && IsClientInGame(i) && !IsFakeClient(i)) PrintToChat(i, sBuffer);
						}
					}

					KvGetString(g_hKeyValues, "TextToPlayer", SZF(sBuffer));
					#if DEBUG_MODE
					DEBUG_PrintToAll("TextToPlayer = '%s'", sBuffer);
					#endif
					//	LogMessage("TextToPlayer: '%s'", sBuffer);
					if(sBuffer[0])
					{
					//	EditText(SZF(sBuffer));
						ReplaceName(SZF(sBuffer), iClient);
						EditText(SZF(sBuffer));
						//	LogMessage("TextToPlayer: '%s'", sBuffer);
						PrintToChat(iClient, sBuffer);
					}
					
					KillGift(iEntity);
					
					Forward_OnPickUpGift_Post(iClient);
				}
			}
		}
	}
}

KillGift(iEntity)
{
	SDKUnhook(iEntity, SDKHook_StartTouchPost, Hook_GiftStartTouchPost);

	AcceptEntityInput(iEntity, "Kill");
}

ReplaceName(String:sBuffer[], MaxLen, iClient)
{
	decl String:sName[MAX_NAME_LENGTH];
	GetClientName(iClient, SZF(sName));
	ReplaceString(sBuffer, MaxLen, "{NAME}", sName, true);
}

EditText(String:sBuffer[], iMaxLen)
{
	if(g_bIsCSGO)
	{
		Format(sBuffer, iMaxLen, " \x01%s", sBuffer);
	
		ReplaceString(sBuffer, iMaxLen, "{RED}",		"\x02", false);
		ReplaceString(sBuffer, iMaxLen, "{LIME}",		"\x05", false);
		ReplaceString(sBuffer, iMaxLen, "{LIGHTGREEN}",	"\x06", false);
		ReplaceString(sBuffer, iMaxLen, "{LIGHTRED}",	"\x07", false);
		ReplaceString(sBuffer, iMaxLen, "{GRAY}",		"\x08", false);
		ReplaceString(sBuffer, iMaxLen, "{LIGHTOLIVE}",	"\x09", false);
		ReplaceString(sBuffer, iMaxLen, "{OLIVE}",		"\x10", false);
		ReplaceString(sBuffer, iMaxLen, "{PURPLE}",		"\x0E", false);
		ReplaceString(sBuffer, iMaxLen, "{LIGHTBLUE}",	"\x0B", false);
		ReplaceString(sBuffer, iMaxLen, "{BLUE}",		"\x0C", false);
	}
	else
	{
		Format(sBuffer, iMaxLen, "\x01%s", sBuffer);
	}
	
	ReplaceString(sBuffer, iMaxLen, "\\n",	"\n");
	ReplaceString(sBuffer, iMaxLen, "#",	"\x07");
	ReplaceString(sBuffer, iMaxLen, "{DEFAULT}",	"\x01");
	ReplaceString(sBuffer, iMaxLen, "{GREEN}",		"\x04");
	ReplaceString(sBuffer, iMaxLen, "{LIGHTGREEN}",	"\x03");
}

Math_GetRandomInt(min, max)
{
	new random = GetURandomInt();
	if (!random) random++;
	new number = RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
	return number;
}

#if DEBUG_MODE
DEBUG_PrintToClient(iClient, const String:sMsg[], any:...)
{
	decl String:sBuffer[PMP];
	VFormat(SZF(sBuffer), sMsg, 3);
	PrintToChat(iClient, "\x04[GIFTS DEBUG] \x01%s", sBuffer);
}

DEBUG_PrintToAll(const String:sMsg[], any:...)
{
	decl String:sBuffer[PMP];
	VFormat(SZF(sBuffer), sMsg, 2);
	PrintToChatAll("\x04[GIFTS DEBUG] \x01%s", sBuffer);
}
#endif

Forward_OnLoadGift(index)
{
	Call_StartForward(g_hForward_OnLoadGift);
	Call_PushCell(index);
	Call_PushCell(g_hKeyValues);
	Call_Finish();
}

Forward_OnCreatedGift(iEntity)
{
	Call_StartForward(g_hForward_OnCreatedGift);
	Call_PushCell(iEntity);
	Call_PushCell(g_hKeyValues);
	Call_Finish();
}

Action:Forward_OnPickUpGift_Pre(iClient)
{
	new Action:result = Plugin_Continue;

	Call_StartForward(g_hForward_OnPickUpGift_Pre);
	Call_PushCell(iClient);
	Call_PushCell(g_hKeyValues);
	Call_Finish(result);
	
	return result;
}

Forward_OnPickUpGift_Post(iClient)
{
	Call_StartForward(g_hForward_OnPickUpGift_Post);
	Call_PushCell(iClient);
	Call_PushCell(g_hKeyValues);
	Call_Finish();
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	RegPluginLibrary("gifts_core");

	return APLRes_Success; 
}