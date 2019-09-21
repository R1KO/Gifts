#pragma semicolon 1
#include <sourcemod>
#include <sdktools_functions>
#include <gifts_core.inc>


#pragma newdecls required

//#define CLIENT_EQ_SERVER // Client = Server?

#define L4D2
//#define CSGO
//#define CSS

#if defined L4D2 && !defined CSGO && !defined CSS
#include <gifts/gifts_models_l4d2.inc>
#elseif !defined L4D2 && defined CSGO && !defined CSS
#include <gifts/gifts_models_csgo.inc>
#elseif !defined L4D2 && !defined CSGO && defined CSS
#include <gifts/gifts_models_css.inc>
#endif

#define SEC_RANGE						3.0
#define SEC_TELEPORT					3.0
#define SEC_ONE_COUNT					0.1
#define POS_SHIFT_RANGE					50.0


#define PLUGIN_VERSION      			"1.0.5.2"
#define DEBUG_LOG						// Логирование?
#define INC_GIFTS						// Для Gifts
#define PLUGIN_VALUE_GIFTS_CHECK		"gifts_check"
#define PLUGIN_VALUE_UP_GIFTS_CHECK		"Gifts_Check"
#define PLUGIN_VALUE_TOTAL				PLUGIN_VALUE_GIFTS_CHECK
#define PLUGIN_VALUE_UP_TOTAL			PLUGIN_VALUE_UP_GIFTS_CHECK
#tryinclude <one_plugins/utils_debug>
#if !defined _utils_debug_included
#define DebugMessage(%0)
enum DEBUG_LEVEL
{
	LDEBUG, 
	LINFO, 
	LWARN, 
	LERROR, 
	LFATAL
}
#endif


#define CMD_CHECK				"sm_gifts_create"
#define CMD_RELOAD				"sm_gifts_reload"
#define CMD_KVFILE				"sm_gifts_kvfile"

enum TypeCount
{
	Config, 
	Physics, 
	Dynamic,
}

public Plugin myinfo = 
{
	name = "[Gifts] Create Item", 
	author = "R1KO & DarklSide", 
	version = PLUGIN_VERSION
}

public void OnPluginStart()
{
	DebugMessage(LINFO, 0, "OnPluginStart = sm_"...PLUGIN_VALUE_TOTAL..."_version[%s]", PLUGIN_VERSION)
	
	// sm_gifts_create "1-9" "config" "noteleport" "0.0" "100.0" "40.0"
	// sm_gifts_create "3-12" "phy" "noteleport" "0.0" "100.0" "40.0"
	
	// sm_gifts_create "random" "config" "teleport" "0.0" "100.0" "40.0"
	// sm_gifts_create "all" "config" "teleport" "0.0" "100.0" "40.0"
	// sm_gifts_create "2" "config" "teleport" "0.0" "100.0" "40.0"
	
	// sm_gifts_create "random" "phy" "teleport" "0.0" "100.0" "40.0"
	// sm_gifts_create "8" "phy" "teleport" "0.0" "100.0" "40.0"
	
	RegAdminCmd(CMD_CHECK, sm_gifts_create, ADMFLAG_ROOT, "<random|all|int|int-int> <config|phy> <teleport> [float] [float] [float]");
	RegAdminCmd(CMD_KVFILE, sm_gifts_kvfile, ADMFLAG_ROOT, "get kv to file");
}

public void OnAllPluginsLoaded()
{
	AddCommandListener(sm_gifts_reload, CMD_RELOAD);
}

public Action sm_gifts_kvfile(int iClient, int iArgs)
{
	GetKeyValuesToFile("KV");
}

public Action sm_gifts_reload(int client, char[] command, int arg)
{
	GetKeyValuesToFile("KV_restart");
}

void GetKeyValuesToFile(const char[] name)
{
	char sFile[64];
	Format(sFile, sizeof(sFile), "addons/sourcemod/logs/%s_config.ini", name);
	KeyValues g_hKeyValues = Gifts_GetConfig();
	KeyValuesToFile(g_hKeyValues, sFile);
}

void GetPositionClassname(const char[][] sClassname, int maxlen, float[3] fPos)
{
	int iEntity = INVALID_ENT_REFERENCE;
	for (int i = 0; i < maxlen; i++)
	{
		while ((iEntity = FindEntityByClassname(iEntity, sClassname[i])) != INVALID_ENT_REFERENCE)
		{
			//DEBUG_PrintToClient(LDEBUG, 0, "GetPositionClassname = m_vecOrigin[%.1f][%.1f][%.1f], sClassname[%d][%s], maxlen[%d]", fPos[0], fPos[1], fPos[2], i, sClassname[i], maxlen);
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fPos);
			return;
		}
	}
	DEBUG_PrintToClient(LWARN, 0, "GetPositionClassname = Error_Position_get");
}

public Action sm_gifts_create(int iClient, int iArgs)
{
	char sFuncName[] = CMD_CHECK;
	
	#if defined CLIENT_EQ_SERVER
	if (!iClient)
	{
		iClient = 1;
	}
	#endif
	
	float fPos[3];
	if (iClient)
	{
		GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", fPos);
	}
	else
	{
		char sClassname[][] =  {
			"info_player_terrorist", 
			"info_player_counterterrorist", 
			"info_player_start", 
		};
		GetPositionClassname(sClassname, sizeof(sClassname), fPos);
		//if (fPos[0] == 0.0 && fPos[1] == 0.0 fPos[2] == 0.0)
	}
	
	char sArgs[64];
	GetCmdArgString(sArgs, sizeof(sArgs));
	DEBUG_PrintToClient(LDEBUG, iClient, "%s = Args[%s]", sFuncName, sArgs);
	
	char sArg_Type[64];
	char sArg_Config[64];
	char sArg_XYZ[64];
	char sArg_Teleport[64]; bool bArg_Teleport;
	
	int iGift; char sGift[64];
	int iCount; TypeCount eConfig = Config;
	
	DEBUG_PrintToClient(LDEBUG, iClient, "%s = m_vecOrigin[%.1f][%.1f][%.1f]", sFuncName, fPos[0], fPos[1], fPos[2]);
	
	
	int iArg_Config = 2;
	if (GetCmdArg(iArg_Config, sArg_Config, sizeof(sArg_Config)))
	{
		if (StrEqual(sArg_Config, "config", false))
		{
			eConfig = Config;
			iCount = Gifts_GetGiftsCount();
		}
		#if defined MODELS_PHYSICS
		else if (StrEqual(sArg_Config, "phy", false))
		{
			eConfig = Physics;
			iCount = sizeof(modelsPhysics) - 1;
		}
		#endif
		#if defined MODELS_DYNAMIC
		else if (StrEqual(sArg_Config, "dynamic", false))
		{
			eConfig = Dynamic;
			iCount = sizeof(modelsDynamic) - 1;
		}
		#endif
		else
		{
			DEBUG_PrintToClient(LERROR, iClient, "%s = Error_argument_type[%d][%s]", sFuncName, iArg_Config, sArg_Config);
			return Plugin_Handled;
		}
	}
	else
	{
		DEBUG_PrintToClient(LERROR, iClient, "%s = Error_argument[%d][%s]", sFuncName, iArg_Config, sArg_Config);
		return Plugin_Handled;
	}
	
	DEBUG_PrintToClient(LDEBUG, iClient, "%s = Count[%s][%d]", sFuncName, sArg_Config, iCount);
	
	int iArg_Teleport = 3;
	if (GetCmdArg(iArg_Teleport, sArg_Teleport, sizeof(sArg_Teleport)))
	{
		if (StrEqual(sArg_Teleport, "teleport", false))
		{
			bArg_Teleport = true;
		}
	}
	else
	{
		DEBUG_PrintToClient(LERROR, iClient, "%s = Error_argument[%d][%s]", sFuncName, iArg_Teleport, sArg_Teleport);
		return Plugin_Handled;
	}
	
	
	int iArg_XYZ = 4; // +2
	for (int i = iArg_XYZ; i <= iArg_XYZ + 2; i++)
	{
		if (GetCmdArg(i, sArg_XYZ, sizeof(sArg_XYZ)))
		{
			float fAction;
			if (StringToFloatEx(sArg_XYZ, fAction))
			{
				fPos[i - iArg_XYZ] += fAction;
			}
			else
			{
				DEBUG_PrintToClient(LERROR, iClient, "%s = Error_argument_float[%d][%s]", sFuncName, i, sArg_XYZ);
				return Plugin_Handled;
			}
		}
	}
	
	
	int iArg_Type = 1;
	if (GetCmdArg(1, sArg_Type, sizeof(sArg_Type)))
	{
		if (StrEqual(sArg_Type, "random", false))
		{
			iGift = GetRandomInt(1, iCount);
			IntToString(iGift, sGift, sizeof(sGift));
			CreateTimer_CreateRange(SEC_ONE_COUNT, bArg_Teleport, SEC_TELEPORT, sArg_Type, iClient, fPos, iGift, sGift, eConfig);
		}
		else if (StrEqual(sArg_Type, "all", false)) // range
		{
			float fSecRange = 0.0; float fSecTeleport = 0.0;
			for (int i = 1; i <= iCount; i++)
			{
				fPos[1] += POS_SHIFT_RANGE;
				
				fSecRange += SEC_RANGE;
				fSecTeleport += SEC_TELEPORT;
				
				IntToString(i, sGift, sizeof(sGift));
				CreateTimer_CreateRange(fSecRange, bArg_Teleport, fSecTeleport, sArg_Type, iClient, fPos, i, sGift, eConfig);
			}
		}
		else if (StrContains(sArg_Type, "-", false) != -1)
		{
			int iStart = 0; int iEnd = 0; char szBuffer[2][64];
			int iArgc = ExplodeString(sArg_Type, "-", szBuffer, sizeof(szBuffer), sizeof(szBuffer[]));
			if (!StringToIntEx(szBuffer[0], iStart))
			{
				DEBUG_PrintToClient(LERROR, iClient, "%s = Error_argument_StringToIntEx_iStart[%d][%s]", sFuncName, iArg_Type, sArg_Type);
				return Plugin_Handled;
			}
			if (!StringToIntEx(szBuffer[1], iEnd))
			{
				DEBUG_PrintToClient(LERROR, iClient, "%s = Error_argument_StringToIntEx_iEnd[%d][%s]", sFuncName, iArg_Type, sArg_Type);
				return Plugin_Handled;
			}
			
			if (iStart != iEnd && iStart < iEnd && iArgc == 2)
			{
				DEBUG_PrintToClient(LDEBUG, iClient, "%s = StrContains[%s], iArgc[%d], iStart[%d], iEnd[%d]", sFuncName, sArg_Type, iArgc, iStart, iEnd);
				
				if (iStart >= 1 && iEnd <= iCount) // range
				{
					float fSecRange = 0.0; float fSecTeleport = 0.0;
					for (int i = iStart; i <= iEnd; i++)
					{
						fPos[1] += POS_SHIFT_RANGE;
						
						fSecRange += SEC_RANGE;
						fSecTeleport += SEC_TELEPORT;
						
						IntToString(i, sGift, sizeof(sGift));
						CreateTimer_CreateRange(fSecRange, bArg_Teleport, fSecTeleport, sArg_Type, iClient, fPos, i, sGift, eConfig);
					}
				}
				else DEBUG_PrintToClient(LERROR, iClient, "%s = Error_argument_int[%d][%s]", sFuncName, iArg_Type, sArg_Type);
			}
			else DEBUG_PrintToClient(LERROR, iClient, "%s = Error_argument_iStart=iEnd[%d][%s]", sFuncName, iArg_Type, sArg_Type);
		}
		else if (StringToIntEx(sArg_Type, iGift))
		{
			if (iGift >= 1 && iGift <= iCount)
			{
				IntToString(iGift, sGift, sizeof(sGift)); //sArg_Type
				CreateTimer_CreateRange(SEC_ONE_COUNT, bArg_Teleport, SEC_TELEPORT, sArg_Type, iClient, fPos, iGift, sGift, eConfig);
			}
			else DEBUG_PrintToClient(LERROR, iClient, "%s = Error_argument_int[%d][%s]", sFuncName, iArg_Type, sArg_Type);
		}
		else DEBUG_PrintToClient(LERROR, iClient, "%s = Error_argument_type[%d][%s]", sFuncName, iArg_Type, sArg_Type);
	}
	else DEBUG_PrintToClient(LERROR, iClient, "%s = Error_argument_get[%d][%s]", sFuncName, iArg_Type, sArg_Type);
	
	return Plugin_Handled;
}

int CreateItem(char[] sArg_Type, int iClient, float[3] fPos, int iGift, char[] sGift, TypeCount eConfig)
{
	char sFuncName[] = "CreateItem";
	DEBUG_PrintToClient(LDEBUG, iClient, "%s = sArg_Type[%s], iClient[%d], fPos[%.1f][%.1f][%.1f], iGift[%d], sGift[%s], eConfig[%d]", sFuncName, sArg_Type, iClient, fPos[0], fPos[1], fPos[2], iGift, sGift, eConfig);
	
	int iIndex = -1;
	
	switch (eConfig)
	{
		case Config:
		{
			KeyValues g_hKeyValues = Gifts_GetConfig();
			KvRewind(g_hKeyValues);
			if (KvJumpToKey(g_hKeyValues, sGift))
			{
				iIndex = Gifts_CreateGift(iClient, fPos, iGift);
			}
			else DEBUG_PrintToClient(LERROR, iClient, "%s = !KvJumpToKey_sGift[%s]", sFuncName, sGift);
		}
		#if defined MODELS_PHYSICS || defined MODELS_DYNAMIC
		case Physics:
		{
			char sModel[PLATFORM_MAX_PATH];
			
			#if defined MODELS_PHYSICS || defined MODELS_DYNAMIC
			switch (eConfig)
			{
				#if defined MODELS_PHYSICS
				case Physics:strcopy(sModel, sizeof(sModel), modelsPhysics[iGift]);
				#endif
				#if defined MODELS_DYNAMIC
				case Dynamic:strcopy(sModel, sizeof(sModel), modelsDynamic[iGift]);
				#endif
			}
			#endif
			
			if (!IsModelPrecached(sModel))
			{
				PrecacheModel(sModel, false);
				DEBUG_PrintToClient(LWARN, iClient, "%s = !IsModelPrecached[%s]", sFuncName, sModel);
			}
			
			//char sBuffer[32];
			//FormatEx(sBuffer, sizeof(sBuffer), "%x%x%x", GetMyHandle(), GetTime(), GetRandomInt(1, 100));
			//KeyValues hKeyValues = new KeyValues(sBuffer);
			KeyValues hKeyValues = new KeyValues("custom");
			KvSetNum(hKeyValues, "is_custom", 1);
			KvSetString(hKeyValues, "Model", sModel);
			KvSetString(hKeyValues, "Lifetime", "30.0");
			KvSetString(hKeyValues, "TextToAll", "{NAME} поднял подарок и получит Бонус!");
			
			char sSectionName[64], sTempModel[64]; char sTempLifetime[64]; char sTempTextToAll[64];
			KvGetSectionName(hKeyValues, sSectionName, sizeof(sSectionName));
			KvGetString(hKeyValues, "Model", sTempModel, sizeof(sTempModel));
			KvGetString(hKeyValues, "Lifetime", sTempLifetime, sizeof(sTempLifetime));
			KvGetString(hKeyValues, "TextToAll", sTempTextToAll, sizeof(sTempTextToAll));
			
			DEBUG_PrintToClient(LDEBUG, iClient, "%s = sGift[%s], is_custom[%d], sSectionName[%s], Model[%s], Lifetime[%s], TextToAll[%s]", sFuncName, sGift, KvGetNum(hKeyValues, "is_custom"), sSectionName, sTempModel, sTempLifetime, sTempTextToAll);
			
			int iFindName = FindCharInString(sModel, '/', true);
			if (iFindName == -1)
			{
				DEBUG_PrintToClient(LERROR, iClient, "%s = iFindName[%s]", sFuncName, sModel);
			}
			char sFile[64]; char sName[64]; 
			Format(sName, sizeof(sName), "%s", sModel[iFindName + 1]);
			Format(sFile, sizeof(sFile), "addons/sourcemod/logs/check/custom_%s_%d.ini", iFindName == -1 ? "":sName, iGift);
			KeyValuesToFile(hKeyValues, sFile); // logs/check/
			
			iIndex = Gifts_CreateGift(iClient, fPos, 0, hKeyValues);
			delete hKeyValues;
		}
		#endif
	}
	
	DEBUG_PrintToClient(iIndex == -1 ? LWARN:LDEBUG, iClient, "%s = CreateGift[%s][%s][%d], Valid[%d][%d], fPos[%.1f][%.1f][%.1f]", sFuncName, sGift, sArg_Type, iIndex, IsValidEntity(iIndex), IsValidEdict(iIndex), fPos[0], fPos[1], fPos[2]);
	
	return iIndex;
}

void CreateTimer_CreateRange(float fSecRange, bool bArg_Teleport, float fSecTeleport, char[] sArg_Type, int iClient, float[3] fPos, int iGift, char[] sGift, TypeCount eConfig)
{
	char sFuncName[] = "CreateTimer_CreateRange";
	DEBUG_PrintToClient(LDEBUG, iClient, "%s = fSecRange[%.1f], bArg_Teleport[%d], fSecTeleport[%.1f], sArg_Type[%s], iClient[%d], fPos[%.1f][%.1f][%.1f], iGift[%d], sGift[%s], eConfig[%d]", sFuncName, fSecRange, bArg_Teleport, fSecTeleport, sArg_Type, iClient, fPos[0], fPos[1], fPos[2], iGift, sGift, eConfig);
	
	DataPack h_dCreateRange;
	CreateDataTimer(fSecRange, Timer_dp_CreateRange, h_dCreateRange);
	h_dCreateRange.WriteCell(bArg_Teleport);
	h_dCreateRange.WriteFloat(fSecTeleport);
	h_dCreateRange.WriteString(sArg_Type);
	h_dCreateRange.WriteCell(iClient);
	h_dCreateRange.WriteFloat(fPos[0]);
	h_dCreateRange.WriteFloat(fPos[1]);
	h_dCreateRange.WriteFloat(fPos[2]);
	h_dCreateRange.WriteCell(iGift);
	h_dCreateRange.WriteString(sGift);
	h_dCreateRange.WriteCell(eConfig);
}

public Action Timer_dp_CreateRange(Handle timer, DataPack h_dCreateRange)
{
	h_dCreateRange.Reset();
	
	bool bArg_Teleport; float fSecTeleport; char sArg_Type[64]; int iClient; float fPos[3]; int iGift; char sGift[64]; TypeCount eConfig;
	bArg_Teleport = h_dCreateRange.ReadCell();
	fSecTeleport = h_dCreateRange.ReadFloat();
	h_dCreateRange.ReadString(sArg_Type, sizeof(sArg_Type));
	iClient = h_dCreateRange.ReadCell();
	fPos[0] = h_dCreateRange.ReadFloat();
	fPos[1] = h_dCreateRange.ReadFloat();
	fPos[2] = h_dCreateRange.ReadFloat();
	iGift = h_dCreateRange.ReadCell();
	h_dCreateRange.ReadString(sGift, sizeof(sGift));
	eConfig = view_as<TypeCount>(h_dCreateRange.ReadCell());
	
	int iIndex = CreateItem(sArg_Type, iClient, fPos, iGift, sGift, eConfig);
	if (iClient && bArg_Teleport)
	{
		CreateTimer_Teleport(fSecTeleport, iIndex, iClient, fPos, iGift);
	}
	return Plugin_Stop;
}

void CreateTimer_Teleport(float fSecTeleport, int iIndex, int iClient, float[3] fPos, int iGift)
{
	char sFuncName[] = "CreateTimer_Teleport";
	DEBUG_PrintToClient(LDEBUG, iClient, "%s = fSecTeleport[%.1f], iIndex[%d], iClient[%d], fPos[%.1f][%.1f][%.1f], iGift[%d]", sFuncName, fSecTeleport, iIndex, iClient, fPos[0], fPos[1], fPos[2], iGift);
	
	DataPack h_dteleport;
	CreateDataTimer(fSecTeleport, Timer_dp_teleport, h_dteleport);
	h_dteleport.WriteCell(iIndex);
	h_dteleport.WriteCell(iClient);
	h_dteleport.WriteFloat(fPos[0]);
	h_dteleport.WriteFloat(fPos[1]);
	h_dteleport.WriteFloat(fPos[2]);
	h_dteleport.WriteCell(iGift);
}

public Action Timer_dp_teleport(Handle timer, DataPack h_dteleport)
{
	h_dteleport.Reset();
	
	int iIndex = h_dteleport.ReadCell(); // to if
	int iClient = h_dteleport.ReadCell();
	if (iClient && IsClientInGame(iClient))
	{
		float fPos[3]; int iGift;
		fPos[0] = h_dteleport.ReadFloat();
		fPos[1] = h_dteleport.ReadFloat();
		fPos[2] = h_dteleport.ReadFloat();
		iGift = h_dteleport.ReadCell();
		
		TeleportEntity(iClient, fPos, NULL_VECTOR, NULL_VECTOR);
		
		bool bValidIndex = IsValidEntity(iIndex);
		DEBUG_PrintToClient(bValidIndex ? LDEBUG:LWARN, iClient, "Timer_dp_teleport = iGift[%d], iIndex[%d], TeleportEntity[%L], Valid[%d][%d], fPos[%.1f][%.1f][%.1f]", iGift, iIndex, iClient, bValidIndex, IsValidEdict(iIndex), fPos[0], fPos[1], fPos[2]);
	}
	return Plugin_Stop;
}

void DEBUG_PrintToClient(DEBUG_LEVEL dLevel, int iClient, const char[] sMsg, any...)
{
	char sBuffer[PLATFORM_MAX_PATH];
	VFormat(sBuffer, sizeof(sBuffer), sMsg, 4);
	if (!iClient || IsClientInGame(iClient))
	{
		ReplyToCommand(iClient, "[GIFTS_Check][%d] %s", dLevel, sBuffer);
	}
	#if !defined _utils_debug_included
	if (dLevel == LERROR)
	{
		LogError("%s", sBuffer);
	}
	#endif
	DebugMessage(dLevel, iClient, "%s", sBuffer)
}
