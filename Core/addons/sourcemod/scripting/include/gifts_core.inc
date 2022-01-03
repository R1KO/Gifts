#if defined _gifts_core_included
 #endinput
#endif
#define _gifts_core_included

/**********************************************************************
 * Вызывается когда создается подарок
 * *
 * @param		iEntity			Индекс сущности подарка
 * @param		hKeyValues		KeyValues структура ключа подарка
 * *
 * @return true - Разрешит создание, false - Запретит создание подарка
 **********************************************************************/
forward bool Gifts_OnCreatePre(int iEntity, KeyValues hKeyValues);

/**********************************************************************
 * Вызывается когда создается подарок
 * *
 * @param		iEntity			Индекс сущности подарка
 * @param		hKeyValues		KeyValues структура ключа подарка
 * *
 * @noreturn
 **********************************************************************/
forward void Gifts_OnCreatePost(int iEntity, KeyValues hKeyValues);

/**********************************************************************
 * Вызывается когда игрок пытается взять подарок
 * *
 * @param		iClient			Индекс игрока
 * @param		hKeyValues		KeyValues структура ключа подарка
 * *
 * @return
 * 			Plugin_Continue		Разрешит поднятие и удалит подарок
 * 			Plugin_Handled		Запретит игроку поднять подарок
 * 			Plugin_Stop			Запретит игроку поднять подарок и удалит его
 **********************************************************************/
forward Action Gifts_OnPickUpPre(int iClient, KeyValues hKeyValues);

/**********************************************************************
 * Вызывается когда игрок поднимает подарок
 * *
 * @param		iClient			Индекс игрока
 * @param		hKeyValues		KeyValues структура ключа подарка
 * *
 * @noreturn
 **********************************************************************/
forward void Gifts_OnPickUpPost(int iClient, KeyValues hKeyValues);

/**********************************************************************
 * Получает кол-во подарков в конфиге
 * *
 * @noparams
 * *
 * @return Кол-во подарков в конфиге
 **********************************************************************/
native int Gifts_GetCount();

/**********************************************************************
 * Получает конфиг подарков (KeyValues)
 * *
 * @noparams
 * *
 * @return Конфиг подарков (KeyValues)
 **********************************************************************/
native KeyValues Gifts_GetConfig();

/**********************************************************************
 * Получает случайный подарок из конфига
 * *
 * @param		bUseChance		Нужно ли учитывать шанс при выборе подарка
 * *
 * @return bool
 **********************************************************************/
native KeyValues Gifts_GetRandomFromConfig(bool bUseChance = true);

/**********************************************************************
 * Получает подарок из конфига (KeyValues)
 * *
 * @param		szBuffer		Имя подарка
 * *
 * @return KeyValues
 **********************************************************************/
native KeyValues Gifts_GetFromConfig(const char[] szGiftName);

/**********************************************************************
 * Вызывается когда загружается подарок
 * *
 * @param		szGiftName		Индекс подарка
 * @param		hKeyValues		KeyValues структура ключа подарка
 * *
 * @noreturn
 **********************************************************************/
forward void Gifts_OnLoad(const char[] szGiftName, KeyValues hKeyValues);

/**********************************************************************
 * Вызывается когда конфиг загружен
 * *
 * @param		iGiftIndex		Индекс подарка
 * @param		hKeyValues		KeyValues структура ключа подарка
 * *
 * @noreturn
 **********************************************************************/
forward void Gifts_OnConfigLoaded(KeyValues hKeyValues);

/**********************************************************************
 * Создает подарок
 * *
 * @param		fPos			Координаты
 * @param		hKeyValues		KeyValues структура ключа подарка (null - рандомный)
 * @param		bForce			Нужно ли вызывать событие "Gifts_OnCreatePre"
 * *
 * @return Индекс ентити созданного подарка. (В случае ошибки = -1)
 **********************************************************************/
native void Gifts_Create(float fPos[3], KeyValues hKeyValues = null, bool bForce = false);

stock int Math_GetRandomInt(int min, int max)
{
	int  random = GetURandomInt();
	if (!random) random++;
	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

public SharedPlugin __pl_gifts_core= 
{
	name = "gifts_core",
	file = "Gifts_Core.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN

public __pl_gifts_core_SetNTVOptional()
{
	MarkNativeAsOptional("Gifts_GetCount");
	MarkNativeAsOptional("Gifts_GetConfig");
	MarkNativeAsOptional("Gifts_GetRandomFromConfig");
	MarkNativeAsOptional("Gifts_GetFromConfig");
	MarkNativeAsOptional("Gifts_Create");
}
#endif
