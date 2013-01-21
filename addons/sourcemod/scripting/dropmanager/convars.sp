// ====[ VARIABLES ]================================================================
enum
{
	AllowHealthkit,
	AllowAmmoBox,
	AllowTNT,
	MenuMode,
	DeadDrop,
	AliveCheck,
	ItemLifeTime,
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
 * --------------------------------------------------------------------- */
LoadConVars()
{
	// Create convars
	AddConVar(AllowHealthkit,       ValueType_Bool,  CreateConVar("dod_dropmanager_healthkit",    "1",  "Whether or not enable healthkit dropping",                                                                 FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(AllowAmmoBox,         ValueType_Bool,  CreateConVar("dod_dropmanager_ammobox",      "1",  "Whether or not enable ammo box dropping",                                                                  FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(AllowTNT,             ValueType_Bool,  CreateConVar("dod_dropmanager_tnt",          "1",  "Whether or not enable TNT dropping",                                                                       FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(MenuMode,             ValueType_Bool,  CreateConVar("dod_dropmanager_menumode",     "0",  "Whether or not use 'menu mode'\nIt lets player choose items to drop via panel",                            FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(DeadDrop,             ValueType_Int,   CreateConVar("dod_dropmanager_deaddrop",     "0",  "Determines an item to drop on death:\n0 = Nothing\n1 = Healthkit\n2 = Ammo box\n3 = TNT\n4 = Random",      FCVAR_PLUGIN, true, 0.0, true, 4.0));
	AddConVar(AliveCheck,           ValueType_Bool,  CreateConVar("dod_dropmanager_alivecheck",   "1",  "Whether or not check item availability before death\nCan be useful for deaddop feature",                   FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(ItemLifeTime,         ValueType_Float, CreateConVar("dod_dropmanager_lifetime",     "45", "Number of seconds a dropped item stays on the ground",                                                     FCVAR_PLUGIN, true, 10.0, true, 120.0));
	AddConVar(CoolDown,             ValueType_Int,   CreateConVar("dod_dropmanager_cooldown",     "3",  "Number of seconds to wait between dropping items",                                                         FCVAR_PLUGIN, true, 0.0, true, 30.0));

	AddConVar(Healthkit_PickupRule, ValueType_Int,   CreateConVar("dod_drophealthkit_pickuprule", "0",  "Determines who can pick up dropped healthkits:\n0 = Everyone\n1 = Only teammates\n2 = Only enemies",       FCVAR_PLUGIN, true, 0.0, true, 2.0));
	AddConVar(Healthkit_AddHealth,  ValueType_Int,   CreateConVar("dod_drophealthkit_addhealth",  "50", "Determines amount of health to add to a player which picking up a healthkit",                              FCVAR_PLUGIN, true, 0.0, true, 100.0));
	AddConVar(Healthkit_SelfHeal,   ValueType_Int,   CreateConVar("dod_drophealthkit_selfheal",   "30", "Determines amount of player's health needed to use own healthkit for self healing",                        FCVAR_PLUGIN, true, 0.0, true, 99.0));
	AddConVar(Healthkit_TeamColor,  ValueType_Bool,  CreateConVar("dod_drophealthkit_teamcolor",  "0",  "Whether or not colorize dropped healthkit depends on team",                                                FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(Healthkit_NewModel,   ValueType_Bool,  CreateConVar("dod_drophealthkit_newmodel",   "0",  "Whether or not use new model for healthkit\nChange only via config!",                                      FCVAR_PLUGIN, true, 0.0, true, 1.0));

	AddConVar(AmmoBox_PickupRule,   ValueType_Int,   CreateConVar("dod_dropammobox_pickuprule",   "1",  "Determines who can pick up dropped ammo boxes:\n0 = Everyone\n1 = Only teammates\n2 = Only enemies",       FCVAR_PLUGIN, true, 0.0, true, 2.0));
	AddConVar(AmmoBox_ClipSize,     ValueType_Int,   CreateConVar("dod_dropammobox_clipsize",     "2",  "Determines number of clips a dropped ammo box contains",                                                   FCVAR_PLUGIN, true, 1.0, true, 5.0));
	AddConVar(AmmoBox_Realism,      ValueType_Bool,  CreateConVar("dod_dropammobox_realism",      "0",  "Whether or not use 'realism mode'\nIt means player may share ammo of primary weapons until no ammo left",  FCVAR_PLUGIN, true, 0.0, true, 1.0));
	AddConVar(AmmoBox_UseVoice,     ValueType_Bool,  CreateConVar("dod_dropammobox_voice",        "1",  "Whether or not use voice command when ammo is dropped",                                                    FCVAR_PLUGIN, true, 0.0, true, 1.0));

	AddConVar(TNT_PickupRule,       ValueType_Int,   CreateConVar("dod_droptnt_pickuprule",       "1",  "Determines who can pick up dropped TNT:\n0 = Everyone\n1 = Only teammates\n2 = Only enemies",              FCVAR_PLUGIN, true, 0.0, true, 2.0));
	AddConVar(TNT_DropLimit,        ValueType_Int,   CreateConVar("dod_droptnt_maxdrops",         "2",  "Determines how many TNT player can drop per life\nThis is created against spamming around bomb dispencer", FCVAR_PLUGIN, true, 1.0));
}

/* AddConVar()
 *
 * Used to add a convar into the convar list.
 * --------------------------------------------------------------------- */
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
 * --------------------------------------------------------------------- */
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
 * --------------------------------------------------------------------- */
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