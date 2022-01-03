#pragma semicolon 1

#include <sourcemod>
#include <gifts_core>

#define DEBUG_MODE 0

#if DEBUG_MODE 1
char g_szDebugLogFile[PLATFORM_MAX_PATH];

void DebugMsg(const char[] sMsg, any ...)
{
	static char szBuffer[512];
	VFormat(SZF(szBuffer), sMsg, 2);
	LogToFile(g_szDebugLogFile, szBuffer);
}
#define DebugMessage(%0) DebugMsg(%0);
#else
#define DebugMessage(%0)
#endif

public Plugin myinfo =
{
	name = "[Gifts] Dispatcher",
	author = "R1KO",
	version = "1.0"
}

#define SZF(%0)		%0, sizeof(%0)
#define CID(%0)		GetClientOfUserId(%0)
#define CUD(%0)		GetClientUserId(%0)

#define PMP			PLATFORM_MAX_PATH
#define MTL			MAX_TARGET_LENGTH
#define MPL			MAXPLAYERS
#define MCL			MaxClients

KeyValues g_hKeyValues;

int g_iGiftsCount;


bool g_bIsCSGO = false;

public void OnPluginStart()
{
	#if DEBUG_MODE 1
	BuildPath(Path_SM, SZF(g_szDebugLogFile), "logs/Gifts_Debug.log");
	#endif

	g_bIsCSGO = (GetEngineVersion() == Engine_CSGO);

	RegAdminCmd("sm_gifts_events_reload", Reload_CMD, ADMFLAG_ROOT);
}

public Action Reload_CMD(int iClient, int iArgs)
{
	LoadEventsConfig();

	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	LoadEventsConfig();
}

void LoadEventsConfig()
{
	if(g_hKeyValues)
	{
		UnhookEvents();

		delete g_hKeyValues;
	}

	g_iGiftsCount = 0;

	char szPath[PMP];
	g_hKeyValues = new KeyValues("Gifts_Dispater_Events");
	BuildPath(Path_SM, SZF(szPath), "configs/gifts/events.cfg");
	if (!g_hKeyValues.ImportFromFile(szPath))
	{
		SetFailState("[Gifts] Core: Не удалось открыть файл '%s'", szPath);
	}

	HookEvents();
}

void HookEvents()
{
	g_hKeyValues.Rewind();
	if(!g_hKeyValues.GotoFirstSubKey())
	{
		return;
	}

	char szEventName[32];
	do
	{
		g_hKeyValues.GetSectionName(SZF(szEventName));
		if (!HookEventEx(szEventName, Event_OnCallback))
		{
			continue;
		}
		g_hKeyValues.SetNum("__is_hooked", 1);
		

	} while (g_hKeyValues.GotoNextKey());
}

void UnhookEvents()
{
	g_hKeyValues.Rewind();
	if(!g_hKeyValues.GotoFirstSubKey())
	{
		return;
	}

	char szEventName[32];
	do
	{
		if (!g_hKeyValues.GetNum("__is_hooked"))
		{
			continue;
		}
		g_hKeyValues.GetSectionName(SZF(szEventName));
		UnhookEvent(szEventName, Event_OnCallback);
	} while (g_hKeyValues.GotoNextKey());
}

public void Event_OnCallback(Event hEvent, const char[] szEventName, bool bDontBroadcast)
{
	if(g_bIsCSGO && GameRules_GetProp("m_bWarmupPeriod"))
	{
		return;
	}

	g_hKeyValues.Rewind();
	if(!g_hKeyValues.JumpToKey(szEventName, false))
	{
		return;
	}

	char szValue[64];
	g_hKeyValues.GetString("entity_userid", SZF(szValue));

	if (szValue[0])
	{
		int iClient = CID(hEvent.GetInt(szValue));
		if (iClient)
		{
			/*
			g_hKeyValues.GetString("enemy_entity_userid", SZF(szValue));
			if (szValue[0])
			{
				int iEnemy = CID(hEvent.GetInt(szValue));
				if (iEnemy)
				{
					
				}
			}
			*/
		}
		return;
	}

	"position" "center" // где относительно сущности будет спавниться подарок center/origin

	// "entity_index" "site" - указывает на имя ключа в событии в котором лежит индекс сущности из которой будут взяты координаты
	// "entity_userid" "userid" - если значением является не индекс, а userid
	// "x" "posx" - указывает на имя ключа в событии в котором лежит координата x
	// "y" "posy" - указывает на имя ключа в событии в котором лежит координата y
	// "z" "posz" - указывает на имя ключа в событии в котором лежит координата z
	// "offset_x" "0" - указывает смещение по оси x
	// "offset_y" "0" - указывает смещение по оси y
	// "offset_z" "20" - указывает смещение по оси z
	// "gift_name" "3" - указывает имя подарка из конфига gifts.cfg (можно так же указать "random" или "random_force" чтобы не учитывать шанс выпадения)
	// "gift" {} - указывает структуру подарка (пример в конфиге gifts.cfg)
}

public Event_PlayerDeath(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	int iClient = CID(hEvent.GetInt("userid"));
	if(iClient)
	{
		if(g_bFromDeath)
		{
			int iAttaker = CID(hEvent.GetInt("attacker"));
			if(iAttaker > 0 && iClient != iAttaker && GetClientTeam(iClient) != GetClientTeam(iAttaker))
			{
				char szBuffer[16];
				int iGift = Math_GetRandomInt(1, g_iGiftsCount);
				IntToString(iGift, SZF(szBuffer));
				KvRewind(g_hKeyValues);
				if(KvJumpToKey(g_hKeyValues, szBuffer))
				{
					if (Math_GetRandomInt(0, 100) <= g_hKeyValues.GetNum("Chance", 20))
					{
						if(Forward_OnCreateGift_Pre(iClient, g_hKeyValues) == Plugin_Continue)
						{
							float fPos[3];
							GetClientAbsOrigin(iClient, fPos);
							fPos[2] -= 40.0;
							SpawnGift(iClient, fPos, iGift, g_hKeyValues);
						}
					}
				}
			}
		}
	}
}

int SpawnGift(int iClient = 0, const float fPos[3], int index = -1, KeyValues hKeyValues)
{
	DebugMessage("SpawnGift: %i", index)

	char szBuffer[PMP];
	hKeyValues.GetString("PropType", SZF(szBuffer), g_szDefaultPropType);
	int iEntity = CreateEntityByName(szBuffer);
	if(iEntity != -1)
	{
		char sTargetName[32];
		FormatEx(SZF(sTargetName), "gift_%i_%i", iEntity, index);
		DebugMessage("SpawnGift:: %s", sTargetName)

		DispatchKeyValue(iEntity, "solid", "6");
		DispatchKeyValue(iEntity, "physicsmode", "1");
		DispatchKeyValue(iEntity, "massScale", "1.0");
		// DispatchKeyValue(iEntity, "classname", "gift");
		DispatchKeyValueVector(iEntity, "origin", fPos);
		hKeyValues.GetString("Model", SZF(szBuffer));
		DispatchKeyValue(iEntity, "model", szBuffer[0] ? szBuffer:g_sGlobalModel);

		DispatchKeyValue(iEntity, "targetname", sTargetName);
		if(DispatchSpawn(iEntity))
		{
			SetEntProp(iEntity, Prop_Send, "m_usSolidFlags", 8);
			SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 1);
			
		//	TeleportEntity(iEntity, fPos, NULL_VECTOR, NULL_VECTOR);

			FormatEx(SZF(szBuffer), "OnUser1 !self:kill::%0.2f:-1", hKeyValues.GetFloat("Lifetime", g_fGlobalLifeTime));
			SetVariantString(szBuffer);
			AcceptEntityInput(iEntity, "AddOutput"); 
			AcceptEntityInput(iEntity, "FireUser1");
			SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", iClient);

			int iRotate = hKeyValues.GetNum("Rotate");
			if(iRotate)
			{
				int iRotating = CreateEntityByName("func_rotating");
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

				FormatEx(SZF(szBuffer), "%s,Kill,,0,-1", sTargetName);
				DispatchKeyValue(iEntity, "OnKilled", szBuffer);
				AcceptEntityInput(iRotating, "Start");
				
				if(iRotate == -1)
				{
					AcceptEntityInput(iRotating, "Reverse");
				}
			}
			else
			{
				SetEntityMoveType(iEntity, MOVETYPE_NONE);
			}
			
			if(hKeyValues.JumpToKey("Animations"))
			{
				if(hKeyValues.GotoFirstSubKey(false))
				{
					char szAnimation[64];
					do
					{
						hKeyValues.GetString(NULL_STRING, SZF(szAnimation));
						SetVariantString(szAnimation);
						AcceptEntityInput(iEntity, "SetAnimation");
					} while (hKeyValues.GotoNextKey( false));
					hKeyValues.GoBack();
				}
				hKeyValues.GoBack();
			}

			SDKHook(iEntity, SDKHook_StartTouchPost, Hook_GiftStartTouchPost);
	
			hKeyValues.GetString("SpawnSound", SZF(szBuffer));
			EmitAmbientSound(szBuffer[0] ? szBuffer : g_sGlobalSpawnSound, fPos, iEntity, SNDLEVEL_NORMAL);

			Forward_OnCreateGift_Post(iClient, iEntity, hKeyValues);

			return iEntity;
		}
	}
	return -1;
}

public void Hook_GiftStartTouchPost(int iEntity, int iClient)
{
	DebugMessage("Hook_GiftStartTouch:: iEntity %i, iClient %i", iEntity, iClient)

	if (iClient > 0 && iClient <= MCL && IsPlayerAlive(iClient) && !IsFakeClient(iClient))
	{
		DebugMessage("Hook_GiftStartTouch:: true")

		char sIndex[32];
		GetEntPropString(iEntity, Prop_Data, "m_iName", SZF(sIndex));
		DebugMessage("m_iName:: %s", sIndex)
		strcopy(SZF(sIndex), sIndex[FindCharInString(sIndex, '_', true)+1]);
		DebugMessage("KvJumpToKey:: %s", sIndex)
		KvRewind(g_hKeyValues);
		if(KvJumpToKey(g_hKeyValues, sIndex))
		{
			DebugMessage("Hook_GiftStartTouch: index: %s, Client: %i", sIndex, iClient)
			switch (Forward_OnPickUpGift_Pre(iClient))
			{
			case Plugin_Handled:
				{
					DebugMessage("Plugin_Handled")
					return;
				}
			case Plugin_Stop:
				{
					DebugMessage("Plugin_Stop")
					
					KillGift(iEntity);
					return;
				}
			case Plugin_Continue:
				{
					DebugMessage("Plugin_Continue")

					char szBuffer[PMP];
					float fPos[3];

					GetClientAbsOrigin(iClient, fPos);
					g_hKeyValues.GetString("PickUpSound", SZF(szBuffer));
					EmitAmbientSound(szBuffer[0] ? szBuffer : g_sGlobalPickUpSound, fPos, iEntity, SNDLEVEL_NORMAL);

					//	LogMessage("PickUpGift: '%s'", sIndex[5]);
					
					g_hKeyValues.GetString("TextToAll", SZF(szBuffer));
					DebugMessage("TextToAll = '%s'", szBuffer)
					//	LogMessage("TextToAll: '%s'", szBuffer);
					if(szBuffer[0])
					{
					//	EditText(SZF(szBuffer));
						ReplaceName(SZF(szBuffer), iClient);
						EditText(SZF(szBuffer));
						//	LogMessage("TextToAll: '%s'", szBuffer);
						for (int i = 1; i <= MCL; ++i)
						{
							if (i != iClient && IsClientInGame(i) && !IsFakeClient(i))
							{
								PrintToChat(i, szBuffer);
							}
						}
					}

					g_hKeyValues.GetString("TextToPlayer", SZF(szBuffer));
					DebugMessage("TextToPlayer = '%s'", szBuffer)
					//	LogMessage("TextToPlayer: '%s'", szBuffer);
					if(szBuffer[0])
					{
					//	EditText(SZF(szBuffer));
						ReplaceName(SZF(szBuffer), iClient);
						EditText(SZF(szBuffer));
						//	LogMessage("TextToPlayer: '%s'", szBuffer);
						PrintToChat(iClient, szBuffer);
					}
					
					KillGift(iEntity);
					
					Forward_OnPickUpGift_Post(iClient);
				}
			}
		}
	}
}

void KillGift(int iEntity)
{
	SDKUnhook(iEntity, SDKHook_StartTouchPost, Hook_GiftStartTouchPost);

	AcceptEntityInput(iEntity, "Kill");
}

void ReplaceName(char [] szBuffer, int iMaxLen, int iClient)
{
	char szName[MAX_NAME_LENGTH];
	GetClientName(iClient, SZF(szName));
	ReplaceString(szBuffer, iMaxLen, "{NAME}", szName, true);
}

void EditText(char[] szBuffer, int iMaxLen)
{
	if(g_bIsCSGO)
	{
		Format(szBuffer, iMaxLen, " \x01%s", szBuffer);
	
		ReplaceString(szBuffer, iMaxLen, "{RED}",		"\x02", false);
		ReplaceString(szBuffer, iMaxLen, "{LIME}",		"\x05", false);
		ReplaceString(szBuffer, iMaxLen, "{LIGHTGREEN}",	"\x06", false);
		ReplaceString(szBuffer, iMaxLen, "{LIGHTRED}",	"\x07", false);
		ReplaceString(szBuffer, iMaxLen, "{GRAY}",		"\x08", false);
		ReplaceString(szBuffer, iMaxLen, "{LIGHTOLIVE}",	"\x09", false);
		ReplaceString(szBuffer, iMaxLen, "{OLIVE}",		"\x10", false);
		ReplaceString(szBuffer, iMaxLen, "{PURPLE}",		"\x0E", false);
		ReplaceString(szBuffer, iMaxLen, "{LIGHTBLUE}",	"\x0B", false);
		ReplaceString(szBuffer, iMaxLen, "{BLUE}",		"\x0C", false);
	}
	else
	{
		Format(szBuffer, iMaxLen, "\x01%s", szBuffer);
	}
	
	ReplaceString(szBuffer, iMaxLen, "\\n",	"\n");
	ReplaceString(szBuffer, iMaxLen, "#",	"\x07");
	ReplaceString(szBuffer, iMaxLen, "{DEFAULT}",	"\x01");
	ReplaceString(szBuffer, iMaxLen, "{GREEN}",		"\x04");
	ReplaceString(szBuffer, iMaxLen, "{LIGHTGREEN}",	"\x03");
}

int Math_GetRandomInt(int min, int max)
{
	int  random = GetURandomInt();
	if (!random) random++;
	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

void Forward_OnLoadGift(int index)
{
	Call_StartForward(g_hForward_OnLoadGift);
	Call_PushCell(index);
	Call_PushCell(g_hKeyValues);
	Call_Finish();
}

Action Forward_OnCreateGift_Pre(int iClient, KeyValues hKeyValues)
{
	Action eResult = Plugin_Continue;

	Call_StartForward(g_hForward_OnCreateGift_Pre);
	Call_PushCell(iClient);
	Call_PushCell(hKeyValues);
	Call_Finish(eResult);
	
	return eResult;
}

void Forward_OnCreateGift_Post(int iClient, int iEntity, KeyValues hKeyValues)
{
	Call_StartForward(g_hForward_OnCreateGift_Post);
	Call_PushCell(iClient);
	Call_PushCell(iEntity);
	Call_PushCell(hKeyValues);
	Call_Finish();
}

Action Forward_OnPickUpGift_Pre(int iClient)
{
	Action eResult = Plugin_Continue;

	Call_StartForward(g_hForward_OnPickUpGift_Pre);
	Call_PushCell(iClient);
	Call_PushCell(g_hKeyValues);
	Call_Finish(eResult);
	
	return eResult;
}

void Forward_OnPickUpGift_Post(int iClient)
{
	Call_StartForward(g_hForward_OnPickUpGift_Post);
	Call_PushCell(iClient);
	Call_PushCell(g_hKeyValues);
	Call_Finish();
}

public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] error, int err_max) 
{
	CreateNative("Gifts_GetGiftsCount", Native_GetGiftsCount);
	CreateNative("Gifts_GetConfig", Native_GetConfig);

	CreateNative("Gifts_CreateGift", Native_CreateGift);

	RegPluginLibrary("gifts_core");

	return APLRes_Success; 
}

public int Native_GetGiftsCount(Handle hPlugin, int iNumParams)
{
	return g_iGiftsCount;
}

public int Native_GetConfig(Handle hPlugin, int iNumParams)
{
	KvRewind(g_hKeyValues);
	return view_as<int>(g_hKeyValues);
}

public int Native_CreateGift(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if(iClient < 0 || iClient > MCL)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Некорректный индекс игрока (%d)", iClient);
		return -1;
	}
	if(!IsClientInGame(iClient))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Игрок %d не подключен", iClient);
		return -1;
	}
	
	int iGift = GetNativeCell(3);
	if(iGift > g_iGiftsCount || iGift < -1)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Некорректный индекс подарка (%d)", iGift);
		return -1;
	}
	
	float fPos[3];
	GetNativeArray(2, fPos, 3);
	
	switch(iGift)
	{
		case -1:
		{
			char szBuffer[16];
			iGift = Math_GetRandomInt(1, g_iGiftsCount);
			IntToString(iGift, SZF(szBuffer));
			KvRewind(g_hKeyValues);
			if(KvJumpToKey(g_hKeyValues, szBuffer))
			{
				if(Forward_OnCreateGift_Pre(iClient, g_hKeyValues) == Plugin_Continue)
				{
					return SpawnGift(iClient, fPos, iGift, g_hKeyValues);
				}
			}
		}
		case 0:
		{
			KeyValues hKeyValues = view_as<KeyValues>(GetNativeCell(4));
			if(hKeyValues == INVALID_HANDLE)
			{
				ThrowNativeError(SP_ERROR_NATIVE, "Нужно указать либо корректный индекс либо структуру");
				return -1;
			}

			if(Forward_OnCreateGift_Pre(iClient, hKeyValues) == Plugin_Continue)
			{
				// TODO: prepare "PropType"
				return SpawnGift(iClient, fPos, iGift, hKeyValues);
			}
		}
		default:
		{
			char szBuffer[16];
			IntToString(iGift, SZF(szBuffer));
			KvRewind(g_hKeyValues);
			if(KvJumpToKey(g_hKeyValues, szBuffer))
			{
				if(Forward_OnCreateGift_Pre(iClient, g_hKeyValues) == Plugin_Continue)
				{
					return SpawnGift(iClient, fPos, iGift, g_hKeyValues);
				}
			}
		}
	}

	return -1;
}
