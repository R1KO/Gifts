#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
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

#define PLUGIN_VERSION      "4.0.0"

public Plugin myinfo =
{
    name = "[Gifts] Core",
    author = "R1KO",
    version = PLUGIN_VERSION
}

#define SZF(%0)        %0, sizeof(%0)
#define CID(%0)        GetClientOfUserId(%0)
#define CUD(%0)        GetClientUserId(%0)

#define PMP            PLATFORM_MAX_PATH
#define MTL            MAX_TARGET_LENGTH
#define MPL            MAXPLAYERS
#define MCL            MaxClients

KeyValues g_hKeyValues;

Handle g_hForward_OnCreatePre,
    g_hForward_OnCreatePost,
    g_hForward_OnPickUpPre,
    g_hForward_OnPickUpPost,
    g_hForward_OnLoad,
    g_hForward_OnConfigLoaded;

int g_iGiftsCount;

char g_szDefaultModel[128],
    g_szDefaultSpawnSound[128],
    g_szDefaultPickUpSound[128];
float g_fDefaultLifeTime;

bool g_bIsCSGO = false;

static const char g_szDefaultPropType[] = "prop_physics_override",
    g_sPropType[][] = {
        "prop_physics_override",
        "prop_dynamic_override",
        "prop_physics_multiplayer",
        "prop_dynamic",
        "prop_physics",
    };

public void OnPluginStart()
{
    #if DEBUG_MODE 1
    BuildPath(Path_SM, SZF(g_szDebugLogFile), "logs/Gifts_Debug.log");
    #endif

    CreateConVar("sm_gifts_core_version", PLUGIN_VERSION, "GIFTS-CORE VERSION", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);

    g_hForward_OnLoad = CreateGlobalForward("Gifts_OnLoad", ET_Ignore, Param_String, Param_Cell);
    g_hForward_OnConfigLoaded = CreateGlobalForward("OnConfigLoaded", ET_Ignore, Param_Cell);
    g_hForward_OnCreatePre = CreateGlobalForward("Gifts_OnCreatePre", ET_Hook, Param_Cell, Param_Cell);
    g_hForward_OnCreatePost = CreateGlobalForward("Gifts_OnCreatePost", ET_Ignore, Param_Cell, Param_Cell);
    g_hForward_OnPickUpPre = CreateGlobalForward("Gifts_OnPickUpPre", ET_Hook, Param_Cell, Param_Cell);
    g_hForward_OnPickUpPost = CreateGlobalForward("Gifts_OnPickUpPost", ET_Ignore, Param_Cell, Param_Cell);

    g_bIsCSGO = (GetEngineVersion() == Engine_CSGO);

    RegAdminCmd("sm_gifts_reload", Reload_CMD, ADMFLAG_ROOT);
}

public Action Reload_CMD(int iClient, int iArgs)
{
    OnConfigsExecuted();

    return Plugin_Handled;
}

public void OnConfigsExecuted()
{
    if(g_hKeyValues)
    {
        delete g_hKeyValues;
    }

    g_iGiftsCount = 0;

    char szBuffer[PMP], szPath[PMP];
    g_hKeyValues = new KeyValues("Gifts");
    BuildPath(Path_SM, SZF(szPath), "configs/gifts/gifts.cfg");
    if (!FileToKeyValues(g_hKeyValues, szPath))
    {
        SetFailState("[Gifts] Core: Не удалось открыть файл '%s'", szPath);
    }
    g_hKeyValues.GetString("Default_Model", SZF(g_szDefaultModel), "models/items/cs_gift.mdl");
    UTIL_LoadModel(g_szDefaultModel);

    g_hKeyValues.GetString("Default_SpawnSound", SZF(g_szDefaultSpawnSound));
    UTIL_LoadSound(g_szDefaultSpawnSound);

    if(g_bIsCSGO && g_szDefaultSpawnSound[0])
    {
        Format(SZF(g_szDefaultSpawnSound), "*%s", g_szDefaultSpawnSound);
    }

    g_hKeyValues.GetString("Default_PickUpSound", SZF(g_szDefaultPickUpSound));
    UTIL_LoadSound(g_szDefaultPickUpSound);

    if(g_bIsCSGO && g_szDefaultPickUpSound[0])
    {
        Format(SZF(g_szDefaultPickUpSound), "*%s", g_szDefaultPickUpSound);
    }

    g_fDefaultLifeTime = g_hKeyValues.GetFloat("Default_Lifetime", 15.0);

    if(KvGotoFirstSubKey(g_hKeyValues))
    {
        do
        {
            IntToString(++g_iGiftsCount, szBuffer, 16);
            g_hKeyValues.SetSectionName(szBuffer);
            
            Forward_OnLoadGift(g_iGiftsCount);

            g_hKeyValues.GetString("PropType", SZF(szBuffer));
            if(!szBuffer[0] || !GetPropType(szBuffer))
            {
                g_hKeyValues.SetString("PropType", g_szDefaultPropType);
            }

            g_hKeyValues.GetString("Model", SZF(szBuffer));
            if(szBuffer[0])
            {
                if(!strcmp(szBuffer, g_szDefaultModel) || !UTIL_LoadModel(szBuffer))
                {
                    g_hKeyValues.SetString("Model", NULL_STRING);
                }
            }

            UTIL_ParseSound("SpawnSound", SZF(szBuffer));
            UTIL_ParseSound("PickUpSound", SZF(szBuffer));
        } while (KvGotoNextKey(g_hKeyValues));
    }
    
    if(g_iGiftsCount == 0)
    {
        SetFailState("[Gifts] Core: Не удалось найти ни одного подарка");
    }

    ReadDownloads();
}

void ReadDownloads()
{
    char szPath[PMP];
    BuildPath(Path_SM, SZF(szPath), "configs/gifts/giftsdownloadlist.ini");
    File hFile = OpenFile(szPath, "r");
    if (hFile == null)
    {
        LogError("[Gifts] Core: Не удалось открыть файл '%s'", szPath);
        return;
    }

    char szBuffer[PMP]; 
    int iPosition;
    while (!IsEndOfFile(hFile) && ReadFileLine(hFile, SZF(szBuffer)))
    {
        if ((iPosition = StrContains(szBuffer, "//")) != -1)
        {
            szBuffer[iPosition] = 0;
        }

        TrimString(szBuffer);
        if(szBuffer[0] && (FileExists(szBuffer, true) || FileExists(szBuffer, false)))
        {
            AddFileToDownloadsTable(szBuffer);
        }
    }
    delete hFile;
}

void UTIL_ParseSound(const char[] sKey, char[] szBuffer, int iMaxLen)
{
    g_hKeyValues.GetString(sKey, szBuffer, iMaxLen);
    if(!szBuffer[0] || !strcmp(szBuffer, "none") || !UTIL_LoadSound(szBuffer))
    {
        KvSetString(g_hKeyValues, sKey, NULL_STRING);
        return;
    }

    if(g_bIsCSGO)
    {
        Format(szBuffer, iMaxLen, "*%s", szBuffer);
        KvSetString(g_hKeyValues, sKey, szBuffer);
    }
}

bool UTIL_LoadSound(char[] szSound)
{
    if(!szSound[0])
    {
        return false;
    }

    char szBuffer[PMP];
    FormatEx(SZF(szBuffer), "sound/%s", szSound);

    if(!FileExists(szBuffer, true) && !FileExists(szBuffer))
    {
        return false;
    }

    AddFileToDownloadsTable(szBuffer);

    if(g_bIsCSGO)
    {
        FormatEx(SZF(szBuffer), "*%s", szSound);
        AddToStringTable(FindStringTable("soundprecache"), szBuffer);
    }
    else
    {
        PrecacheSound(szSound, true);
    }

    return true;
}

bool UTIL_LoadModel(const char[] szModel)
{
    if(!szModel[0] || !(FileExists(szModel, true) || FileExists(szModel)))
    {
        return false;
    }

    PrecacheModel(szModel, true);
    AddFileToDownloadsTable(szModel);
    return true;
}

bool GetPropType(char[] szBuffer)
{
    for(int i = 0; i < sizeof(g_sPropType); ++i)
    {
        if (!strcmp(szBuffer, g_sPropType[i]))
        {
            return true;
        }
    }
    return false;
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
        DispatchKeyValue(iEntity, "model", szBuffer[0] ? szBuffer:g_szDefaultModel);

        DispatchKeyValue(iEntity, "targetname", sTargetName);
        if(DispatchSpawn(iEntity))
        {
            SetEntProp(iEntity, Prop_Send, "m_usSolidFlags", 8);
            SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 1);
            
        //    TeleportEntity(iEntity, fPos, NULL_VECTOR, NULL_VECTOR);

            FormatEx(SZF(szBuffer), "OnUser1 !self:kill::%0.2f:-1", hKeyValues.GetFloat("Lifetime", g_fDefaultLifeTime));
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
            EmitAmbientSound(szBuffer[0] ? szBuffer : g_szDefaultSpawnSound, fPos, iEntity, SNDLEVEL_NORMAL);

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
                    EmitAmbientSound(szBuffer[0] ? szBuffer : g_szDefaultPickUpSound, fPos, iEntity, SNDLEVEL_NORMAL);

                    //    LogMessage("PickUpGift: '%s'", sIndex[5]);
                    
                    g_hKeyValues.GetString("TextToAll", SZF(szBuffer));
                    DebugMessage("TextToAll = '%s'", szBuffer)
                    //    LogMessage("TextToAll: '%s'", szBuffer);
                    if(szBuffer[0])
                    {
                    //    EditText(SZF(szBuffer));
                        ReplaceName(SZF(szBuffer), iClient);
                        EditText(SZF(szBuffer));
                        //    LogMessage("TextToAll: '%s'", szBuffer);
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
                    //    LogMessage("TextToPlayer: '%s'", szBuffer);
                    if(szBuffer[0])
                    {
                    //    EditText(SZF(szBuffer));
                        ReplaceName(SZF(szBuffer), iClient);
                        EditText(SZF(szBuffer));
                        //    LogMessage("TextToPlayer: '%s'", szBuffer);
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
    
        ReplaceString(szBuffer, iMaxLen, "{RED}", "\x02", false);
        ReplaceString(szBuffer, iMaxLen, "{LIME}", "\x05", false);
        ReplaceString(szBuffer, iMaxLen, "{LIGHTGREEN}", "\x06", false);
        ReplaceString(szBuffer, iMaxLen, "{LIGHTRED}", "\x07", false);
        ReplaceString(szBuffer, iMaxLen, "{GRAY}", "\x08", false);
        ReplaceString(szBuffer, iMaxLen, "{LIGHTOLIVE}", "\x09", false);
        ReplaceString(szBuffer, iMaxLen, "{OLIVE}", "\x10", false);
        ReplaceString(szBuffer, iMaxLen, "{PURPLE}", "\x0E", false);
        ReplaceString(szBuffer, iMaxLen, "{LIGHTBLUE}", "\x0B", false);
        ReplaceString(szBuffer, iMaxLen, "{BLUE}", "\x0C", false);
    }
    else
    {
        Format(szBuffer, iMaxLen, "\x01%s", szBuffer);
    }
    
    ReplaceString(szBuffer, iMaxLen, "\\n", "\n");
    ReplaceString(szBuffer, iMaxLen, "#", "\x07");
    ReplaceString(szBuffer, iMaxLen, "{DEFAULT}", "\x01");
    ReplaceString(szBuffer, iMaxLen, "{GREEN}", "\x04");
    ReplaceString(szBuffer, iMaxLen, "{LIGHTGREEN}", "\x03");
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
    CreateNative("Gifts_GetCount", Native_GetCount);
    CreateNative("Gifts_GetConfig", Native_GetConfig);
    CreateNative("Gifts_GetFromConfig", Native_GetFromConfig);
    CreateNative("Gifts_GetRandomFromConfig", Native_GetRandomFromConfig);

    CreateNative("Gifts_Create", Native_Create);

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
