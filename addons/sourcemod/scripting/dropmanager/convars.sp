/**
 * ------------------------------------------------------------------------------------------------------
 *   ___   __                   __    __
 *   | |  / /_  _ _____(_)_  _ / /_  / /__  _____
 *   | | / / __ `/  __/ / __ `/ __ \/ / _ \/ ___/
 *   | |/ / /_/ / /  / / /_/ / /_/ / /  __(__ )
 *   |___/\__,_/_/  /_/\__,_/\____/_/\___/____/
 *
 * ------------------------------------------------------------------------------------------------------
*/

enum
{
	AllowHealthkit,
	AllowAmmoBox,
	AllowTNT,
	AllowPistols,
	AllowNade,
	MenuMode,
	DeadDrop,
	AliveCheck,
	ItemLifeTime,
	ItemPriority,
	CoolDown,

	Healthkit_PickupRule,
	Healthkit_AddHealth,
	Healthkit_SelfHeal,
	Healthkit_TeamColor,
	Healthkit_NewModel,

	AmmoBox_PickupRule,
	AmmoBox_ClipSize,
	AmmoBox_Realism,
	AmmoBox_UseVoice,

	TNT_PickupRule,
	TNT_DropLimit,

	ConVar_Size
};

enum ValueType
{
	ValueType_Bool,
	ValueType_Int,
	ValueType_Float
};

enum ConVar
{
	Handle:ConVarHandle,	// Handle of the convar
	ValueType:Type,			// Type of value (int, bool)
	any:Value				// The value
};

new GetConVar[ConVar_Size][ConVar];

/* LoadConVars()
 *
 * Initialze cvars for plugin.
 * ------------------------------------------------------------------------------------------------------ */
LoadConVars()
{
	// Create version ConVar here
	CreateConVar("dod_dropmanager_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

	AddConVar(AllowHealthkit,       ValueType_Bool,  CreateConVar("dod_dropmanager_healthkit",    "1",   "Whether or not allow health kits dropping",                                                                            FCVAR_PLUGIN, true, 0.0,   true, 1.0));
	AddConVar(AllowAmmoBox,         ValueType_Bool,  CreateConVar("dod_dropmanager_ammobox",      "1",   "Whether or not allow ammo boxes dropping",                                                                             FCVAR_PLUGIN, true, 0.0,   true, 1.0));
	AddConVar(AllowTNT,             ValueType_Bool,  CreateConVar("dod_dropmanager_tnt",          "1",   "Whether or not allow explosives (TNT) dropping",                                                                       FCVAR_PLUGIN, true, 0.0,   true, 1.0));
	AddConVar(AllowPistols,         ValueType_Bool,  CreateConVar("dod_dropmanager_pistols",      "1",   "Whether or not allow pistols dropping\nPistols can be dropped using default \"drop\" command if player is holding it", FCVAR_PLUGIN, true, 0.0,   true, 1.0));
	AddConVar(AllowNade,            ValueType_Bool,  CreateConVar("dod_dropmanager_grenades",     "1",   "Whether or not allow grenades dropping\nPlayers may equip any grenades without limits and restrictions",               FCVAR_PLUGIN, true, 0.0,   true, 1.0));
	AddConVar(MenuMode,             ValueType_Bool,  CreateConVar("dod_dropmanager_menumode",     "0",   "Whether or not enable \"menu mode\"\nIt lets player select an items to drop using panel",                              FCVAR_PLUGIN, true, 0.0,   true, 1.0));
	AddConVar(DeadDrop,             ValueType_Int,   CreateConVar("dod_dropmanager_deaddrop",     "3",   "Determines an item to drop after death:\n1 = Health kit\n2 = Ammo box\n3 = TNT\n4 = Pistol\n5 = Grenade\n6 = Random",  FCVAR_PLUGIN, true, 0.0,   true, 6.0));
	AddConVar(AliveCheck,           ValueType_Bool,  CreateConVar("dod_dropmanager_alivecheck",   "1",   "Whether or not check item availability before player's death\nThis can be useful for \"deaddop\" features",            FCVAR_PLUGIN, true, 0.0,   true, 1.0));
	AddConVar(ItemLifeTime,         ValueType_Float, CreateConVar("dod_dropmanager_lifetime",     "45",  "Number of seconds a dropped items stays on the ground\n0 = Don't remove items until new round starts",                 FCVAR_PLUGIN, true, 0.0));
	AddConVar(ItemPriority,         ValueType_Int,   CreateConVar("dod_dropmanager_priority",     "123", "Determines a queue priority for items dropping when menu mode is disabled",                                            FCVAR_PLUGIN, true, 123.0, true, 321.0));
	AddConVar(CoolDown,             ValueType_Int,   CreateConVar("dod_dropmanager_cooldown",     "3",   "Number of seconds to wait between dropping items",                                                                     FCVAR_PLUGIN, true, 0.0,   true, 30.0));

	AddConVar(Healthkit_PickupRule, ValueType_Int,   CreateConVar("dod_drophealthkit_pickuprule", "0",   "Determines who can pick up dropped health kits:\n0 = Everyone\n1 = Only team mates\n2 = Only enemies",                 FCVAR_PLUGIN, true, 0.0,   true, 2.0));
	AddConVar(Healthkit_AddHealth,  ValueType_Int,   CreateConVar("dod_drophealthkit_addhealth",  "50",  "Determines amount of health to add to a player who is picked up a health kit",                                         FCVAR_PLUGIN, true, 0.0,   true, 100.0));
	AddConVar(Healthkit_SelfHeal,   ValueType_Int,   CreateConVar("dod_drophealthkit_selfheal",   "30",  "Determines amount of player's health needed to allow using own health kit for self healing",                           FCVAR_PLUGIN, true, 0.0,   true, 99.0));
	AddConVar(Healthkit_TeamColor,  ValueType_Bool,  CreateConVar("dod_drophealthkit_teamcolor",  "0",   "Whether or not colorize dropped health kit depends on client's team",                                                  FCVAR_PLUGIN, true, 0.0,   true, 1.0));
	AddConVar(Healthkit_NewModel,   ValueType_Bool,  CreateConVar("dod_drophealthkit_newmodel",   "0",   "Whether or not use new model for health kits\nMake sure to have this model on normal and fastdownload servers!",       FCVAR_PLUGIN, true, 0.0,   true, 1.0));

	AddConVar(AmmoBox_PickupRule,   ValueType_Int,   CreateConVar("dod_dropammobox_pickuprule",   "1",   "Determines who can pick up dropped ammo boxes:\n0 = Everyone\n1 = Only team mates\n2 = Only enemies",                  FCVAR_PLUGIN, true, 0.0,   true, 2.0));
	AddConVar(AmmoBox_ClipSize,     ValueType_Int,   CreateConVar("dod_dropammobox_clipsize",     "2",   "Determines number of clips a dropped ammo box contains",                                                               FCVAR_PLUGIN, true, 1.0,   true, 5.0));
	AddConVar(AmmoBox_Realism,      ValueType_Bool,  CreateConVar("dod_dropammobox_realism",      "0",   "Whether or not enable \"realism mode\"\nIt means player may share ammo of primary weapons until no ammo left",         FCVAR_PLUGIN, true, 0.0,   true, 1.0));
	AddConVar(AmmoBox_UseVoice,     ValueType_Bool,  CreateConVar("dod_dropammobox_voice",        "1",   "Whether or not use voice command when ammo box is dropped",                                                            FCVAR_PLUGIN, true, 0.0,   true, 1.0));

	AddConVar(TNT_PickupRule,       ValueType_Int,   CreateConVar("dod_droptnt_pickuprule",       "0",   "Determines who can pick up dropped explosives:\n0 = Everyone\n1 = Only team mates\n2 = Only enemies",                  FCVAR_PLUGIN, true, 0.0,   true, 2.0));
	AddConVar(TNT_DropLimit,        ValueType_Int,   CreateConVar("dod_droptnt_maxdrops",         "2",   "Determines how many explosives player can drop per life\nThis is created against spamming around bomb dispencer",      FCVAR_PLUGIN, true, 1.0));
}

/* AddConVar()
 *
 * Used to add a convar into the convar list.
 * ------------------------------------------------------------------------------------------------------ */
AddConVar(conVar, ValueType:type, Handle:conVarHandle)
{
	GetConVar[conVar][ConVarHandle] = conVarHandle;
	GetConVar[conVar][Type] = type;

	UpdateConVarValue(conVar);

	HookConVarChange(conVarHandle, OnConVarChange);
}

/* UpdateConVarValue()
 *
 * Updates the internal convar values.
 * ------------------------------------------------------------------------------------------------------ */
UpdateConVarValue(conVar)
{
	switch (GetConVar[conVar][Type])
	{
		case ValueType_Bool:  GetConVar[conVar][Value] = GetConVarBool (GetConVar[conVar][ConVarHandle]);
		case ValueType_Int:   GetConVar[conVar][Value] = GetConVarInt  (GetConVar[conVar][ConVarHandle]);
		case ValueType_Float: GetConVar[conVar][Value] = GetConVarFloat(GetConVar[conVar][ConVarHandle]);
	}
}

/* OnConVarChange()
 *
 * Updates the stored convar value if the convar's value change.
 * ------------------------------------------------------------------------------------------------------ */
public OnConVarChange(Handle:conVar, const String:oldValue[], const String:newValue[])
{
	for (new i = 0; i < ConVar_Size; i++)
	{
		if (conVar == GetConVar[i][ConVarHandle])
		{
			UpdateConVarValue(i);
		}
	}
}