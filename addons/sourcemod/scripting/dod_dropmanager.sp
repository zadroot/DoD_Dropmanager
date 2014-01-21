/**
* DoD:S DropManager by Root
*
* Description:
*   Allows player to drop health kits, ammo boxes, explosives and some weapons.
*   Special thanks to FeuerSturm, BenSib and Andersso!
*
* Version 4.0 (1.0 Realism)
* Changelog & more info at http://goo.gl/4nKhJ
*/

/** If you need to get Realism DropManager - just recompile a plugin with REALISM definition below */
// #define REALISM

#include <sdktools>
#include <sdkhooks>

// ====[ CONSTANTS ]===================================================================================
#define PLUGIN_NAME       "DoD:S DropManager"
#if defined REALISM
#define PLUGIN_VERSION    "1.0 Realism"
#else
#define PLUGIN_VERSION    "4.0"
#endif

// Too many macros (c) Andersso
#define HOOKTOUCH_DELAY   0.5
#define DEATHORIGIN       5.0
#define ALIVEORIGIN       43.0

#define MAX_WEAPON_LENGTH 24
#define DOD_MAXPLAYERS    33
#if defined REALISM
#define COLLISION_GROUP_INTERACTIVE_DERBIS 3
#define IS_MEDIC(%1)      GetEntProp(%1, Prop_Send, "m_bWearingSuit", 1)
#define SF_NORESPAWN      (1 << 30)
#define MAXHEALTH         83 // Maximum health bounds for realism dropmanager (community request)
#else
#define MAXHEALTH         100
#endif

enum //Slots
{
	SLOT_PRIMARY = 0,
	SLOT_SECONDARY,
	SLOT_MELEE,
	SLOT_GRENADE,
	SLOT_EXPLOSIVE
}

enum //Teams
{
	Spectators = 1,
	Allies,
	Axis
}

enum //Items
{
	INVALID_ITEM = -1,
	NOITEM,
	Healthkit,
	Ammobox,
	Bomb,
	Pistol,
	Grenade,
	Random,
#if defined REALISM
	All
#endif
}

enum //Pickup rule
{
	allteams = 0,
	mates,
	enemies
}

new	LastDropped[DOD_MAXPLAYERS + 1], Handle:dropmenu = INVALID_HANDLE;
#if defined REALISM
new	Handle:SetDieThink         = INVALID_HANDLE,
	Handle:CreateServerRagdoll = INVALID_HANDLE,
	bool:AllowItemDropping     = true;
#endif

// ====[ PLUGIN ]======================================================================================
#include "dropmanager/convars.sp"
#include "dropmanager/ammobox.sp"
#include "dropmanager/healthkit.sp"
#include "dropmanager/tnt.sp"
#include "dropmanager/weapons.sp"

public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "Allows player to drop health kits, ammo boxes, explosives and some weapons using different ways",
	version     = PLUGIN_VERSION,
	url         = "http://dodsplugins.com/"
}


/* OnPluginStart()
 *
 * When the plugin starts up.
 * ---------------------------------------------------------------------------------------------------- */
public OnPluginStart()
{
	// Load plugin's console variables
	LoadConVars();

	// Load plugin translations
	LoadTranslations("dod_dropmanager.phrases");

	// Store property offset for ammo setup
	m_iAmmo = FindSendPropOffs("CDODPlayer", "m_iAmmo");

	// Since those commands is exists, use AddCommandListener instead of Reg*Cmd
	AddCommandListener(OnDropWeapon, "drop");
	AddCommandListener(OnDropAmmo,   "dropammo");

	// Hook spawn and hurt (death) events
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_hurt",  OnPlayerDeath);

	// Create and exec plugin's configuration file
	AutoExecConfig(true, "dod_dropmanager");

#if defined REALISM
	new Handle:gameConf = LoadGameConfigFile("plugin.dropmanager");

	// Make sure config is exists, otherwise disable plugin
	if (gameConf == INVALID_HANDLE)
	{
		SetFailState("Could not open game config file: \"plugin.dropmanager\"!");
	}

	// Prepare SDKCall for SetDieThink sig
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gameConf, SDKConf_Signature, "SetDieThink");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);

	// If signature is not valid, disable plugin and ask author!
	if ((SetDieThink = EndPrepSDKCall()) == INVALID_HANDLE)
	{
		SetFailState("Failed to init SDKCall: \"SetDieThink\"!");
	}

	// Prepare CreateServerRagdoll signature
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gameConf, SDKConf_Signature, "CreateServerRagdoll");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity,  SDKPass_Pointer); // pAnimating
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);   // forceBone
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByRef);   // info
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);   // collisionGroup
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);           // bUseLRURetirement
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer); // Entity index

	if ((CreateServerRagdoll = EndPrepSDKCall()) == INVALID_HANDLE)
	{
		SetFailState("Failed to init SDKCall: \"CreateServerRagdoll\"!");
	}

	// Free config handle
	CloseHandle(gameConf);
#endif
}

/* OnConfigsExecuted()
 *
 * When the map has loaded and all plugin configs are done executing.
 * ---------------------------------------------------------------------------------------------------- */
public OnConfigsExecuted()
{
	// If custom healthkit model is defined...
	if (GetConVar[Healthkit_NewModel][Value])
	{
		// ...allow custom healthkit files to be downloaded to clients
		for (new i; i < sizeof(HealthkitFiles); i++)
			AddFileToDownloadsTable(HealthkitFiles[i]);
	}

	// Precache a healthkit's model & sounds
	PrecacheModel(HealthkitModel);
	PrecacheModel(HealthkitModel2);
	PrecacheSound(HealthkitSound);

	// No need to precache ammo boxes/tnt models and sounds (because those are stock)
	PrecacheSound(PickSound);

#if defined REALISM
	OnRealismEnded();
#else
	PrecacheSound(HealSound);
#endif
}

#if defined REALISM
/* OnEntityCreated()
 *
 * When an entity is created.
 * ---------------------------------------------------------------------------------------------------- */
public OnEntityCreated(entity, const String:classname[])
{
	// Check whether nor not client side ragdoll was created
	if (StrEqual(classname, "dod_ragdoll"))
	{
		// If ragdolls should stay during all the round, kill original now
		if (GetConVar[RagdollStay][Value]) RemoveEntity(entity);
	}
}

/* OnClientPutInServer()
 *
 * Called when a client is entering the game.
 * ---------------------------------------------------------------------------------------------------- */
public OnClientPutInServer(client)
{
	// Needed to set lifetime for weapon properly
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
}
#endif

/* OnPlayerSpawn()
 *
 * Called when a player spawns.
 * ---------------------------------------------------------------------------------------------------- */
public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Get client userid from event
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	// If healthkits is enabled, allow players to use it (otherwise disable)
	if (GetConVar[AllowHealthkit][Value])
		 HasHealthkit[client] = true;
	else HasHealthkit[client] = false;

	if (GetConVar[AllowAmmoBox][Value])
		 HasAmmoBox[client] = true;
	else HasAmmoBox[client] = false;

	// Change pistol, grenade and a TNT availability in player's backpack to false (just make sure those are not available yet)
	HasPistol[client] = false;
	HasNade[client]   = false;
	HasTNT[client]    = false;

	// Reset amount of dropped bombs at every player respawn
	BombsDropped[client] = false;
}

/* OnPlayerDeath()
 *
 * Called when a player dies.
 * ---------------------------------------------------------------------------------------------------- */
public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Unfortunately I have to hook player_hurt event and check client's health (because death event is too late to check weapon availability)
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetClientHealth(client) < 1)
	{
		// Retrieve the pistol and grenade weapons before player's death
		new pistol  = GetPlayerWeaponSlot(client, SLOT_SECONDARY);
		new grenade = GetPlayerWeaponSlot(client, SLOT_GRENADE);
		new bool:alivecheck = GetConVar[AliveCheck][Value];

		// Check 4th slot (TNT) right before death, because 'dod_tnt_pickup' event is client-side only
		if (GetConVar[AllowTNT][Value]
		&& IsValidEntity(GetPlayerWeaponSlot(client, SLOT_EXPLOSIVE)))
		{ HasTNT[client] = true; }

		// Make sure player is having a pistol in his inventory
		if (GetConVar[AllowPistols][Value]
		&& IsValidEntity(pistol))
		{ HasPistol[client] = true; }

		if (GetConVar[AllowNade][Value]
		&& IsValidEntity(grenade))
		{ HasNade[client] = true; }

#if defined REALISM
		if (GetConVar[RagdollStay][Value])
		{
			new Handle:data;

			// This will also return ragdoll index (cause of last SDKCall param)
			new ragdoll = CreateServerSideRagdoll(client);

			// Disable motions for this ragdoll after 5 seconds due to expensive transmit
			CreateDataTimer(5.0, Timer_DisableMotion, data, TIMER_FLAG_NO_MAPCHANGE);

			// Write entity reference and player's team in data timer
			WritePackCell(data, EntIndexToEntRef(ragdoll));
			WritePackCell(data, GetClientTeam(client));
		}
#else
		decl Float:origin[3]; GetClientAbsOrigin(client, origin);
#endif
		// Does dead drop features is enabled ?
		switch (GetConVar[DeadDrop][Value])
		{
			case Healthkit: // Drop healthkit after player's death
			{
				if (alivecheck == false)       CreateItem(client, type:Healthkit);
				else if (HasHealthkit[client]) CreateItem(client, type:Healthkit);
			}
			case Ammobox: // Drop ammo box after player's death
			{
				if (alivecheck == false)     CreateItem(client, type:Ammobox);
				else if (HasAmmoBox[client]) CreateItem(client, type:Ammobox);
			}
			case Bomb: // Drop TNT after player's death
			{
				if (alivecheck == false) CreateItem(client, type:Bomb);
				else if (HasTNT[client]) CreateItem(client, type:Bomb);
			}
			case Pistol: // Drop pistol after player's death
			{
				// If realism dropmanager were compiled, create pistol as a prop_physics_override entity
#if defined REALISM
				if (alivecheck == false)    CreateItem(client, type:Pistol);
				else if (HasPistol[client]) CreateItem(client, type:Pistol);
#else
				// Otherwise drop weapon properly
				if (alivecheck == false)    DOD_DropWeapon(client, pistol, origin);
				else if (HasPistol[client]) DOD_DropWeapon(client, pistol, origin);
#endif
			}
			case Grenade: // Drop grenade after player's death
			{
				if (alivecheck == false)  CreateItem(client, type:Grenade);
				else if (HasNade[client]) CreateItem(client, type:Grenade);
			}
			case Random: // Drop random item after player's death
			{
				switch (GetRandomInt(from:Healthkit, to:Grenade))
				{
					case Healthkit:
					{
						// If plugin shouldn't check item avaliability on death, just create it
						if (alivecheck == false)       CreateItem(client, type:Healthkit);
						else if (HasHealthkit[client]) CreateItem(client, type:Healthkit);
					}
					case Ammobox:
					{
						// Otherwise make sure player is having an ammobox in inventory
						if (alivecheck == false)     CreateItem(client, type:Ammobox);
						else if (HasAmmoBox[client]) CreateItem(client, type:Ammobox);
					}
					case Bomb:
					{
						if (alivecheck == false) CreateItem(client, type:Bomb);
						else if (HasTNT[client]) CreateItem(client, type:Bomb);
					}
					case Pistol:
					{
#if defined REALISM
						if (alivecheck == false)    CreateItem(client, type:Pistol);
						else if (HasPistol[client]) CreateItem(client, type:Pistol);
#else
						// Also use same drop weapon method here, but change original toss location to 'death origin'
						if (alivecheck == false)    DOD_DropWeapon(client, pistol, origin);
						else if (HasPistol[client]) DOD_DropWeapon(client, pistol, origin);
#endif
					}
					case Grenade:
					{
						if (alivecheck == false)  CreateItem(client, type:Grenade);
						else if (HasNade[client]) CreateItem(client, type:Grenade);
					}
				}
			}
#if defined REALISM
			case All:
			{
				// Drop all available items which player is got
				if (HasHealthkit[client]) CreateItem(client, type:Healthkit);
				if (HasAmmoBox[client])   CreateItem(client, type:Ammobox);
				if (HasPistol[client])    CreateItem(client, type:Pistol);
				if (HasNade[client])      CreateItem(client, type:Grenade);
				if (HasTNT[client])       CreateItem(client, type:Bomb);
			}
#endif
		}
	}
}

/* OnPlayerRunCmd()
 *
 * When a clients movement buttons are being processed.
 * ---------------------------------------------------------------------------------------------------- */
public Action:OnPlayerRunCmd(client, &buttons)
{
	// Does player is pressing +USE button and cooldown for dropped weapons is expired?
	if ((buttons & IN_USE) && GetTime() - LastDropped[client] >= 1)
	{
		// Get the entity a client is aiming at
		new item = GetClientAimTarget(client, false);

		// If we found an entity - make sure its valid
		if (IsValidEntity(item))
		{
			// Retrieve the client's eye position and entity origin vector to compare distance
			decl Float:vec1[3], Float:vec2[3];
			GetClientEyePosition(client, vec1);
			GetEntPropVector(item, Prop_Send, "m_vecOrigin", vec2);

			// If distance is pretty close (like default for weapons to pickup using +USE button), retrieve the item index
			if (GetVectorDistance(vec1, vec2) < 128.0)
			{
				switch (GetEntProp(item, Prop_Data, "m_iHammerID"))
				{
					// A grenade was found
					case Grenade: OnGrenadeTouched(item, client);
					case Pistol:
					{
						// Create pistol as a prop_physics_override entity for realism
#if defined REALISM
						CreateItem(client, type:Pistol);
#else
						// Otherise it's better to change the weapon to best available before dropping it to skip bad animations
						CreateTimer(SMALLEST_INTERVAL, Timer_ChangeWeapon, client, TIMER_FLAG_NO_MAPCHANGE);
						DOD_DropWeapon(client, GetPlayerWeaponSlot(client, SLOT_SECONDARY), NULL_VECTOR);
#endif
						// For pistol firstly drop the weapon, and then emit hook callback as well
						OnPistolTouched(item, client);
					}
				}
			}
		}
	}
}

#if defined REALISM
/* OnWeaponDrop()
 *
 * Called when player drops a weapon.
 * ---------------------------------------------------------------------------------------------------- */
public OnWeaponDrop(client, weapon)
{
	// Make sure weapon is valid and infinite time is set
	if (!GetConVar[ItemLifeTime][Value] && IsValidEntity(weapon))
	{
		// Prepare spawnflags datamap offset
		static spawnflags;

		// Try to find datamap offset for m_spawnflags property
		if (!spawnflags && (spawnflags = FindDataMapOffs(weapon, "m_spawnflags")) == -1)
		{
			ThrowError("Failed to obtain offset: \"m_spawnflags\"!");
		}

		// Remove SF_NORESPAWN flag from m_spawnflags datamap
		SetEntData(weapon, spawnflags, GetEntData(weapon, spawnflags) & ~SF_NORESPAWN);

		// And call the signature to properly dont remove weapons from the ground
		CreateTimer(SMALLEST_INTERVAL, Timer_SetDieThink, EntIndexToEntRef(weapon), TIMER_FLAG_NO_MAPCHANGE);
	}
}
#endif

/* OnDropWeapon()
 *
 * When the 'drop' command is called.
 * ---------------------------------------------------------------------------------------------------- */
public Action:OnDropWeapon(client, const String:command[], argc)
{
	// Only valid and alive players can use this command
#if defined REALISM
	if (IsValidClient(client)
	&& IsPlayerAlive(client)
	&& !IS_MEDIC(client)
	&& AllowItemDropping) // In realism dropmanager check whether or not dropping is allowed
#else
	if (IsValidClient(client) && IsPlayerAlive(client))
#endif
	{
		if (GetConVar[AllowPistols][Value])
		{
			// Get name of weapon which player is holiding at this moment
			decl String:weapon[MAX_WEAPON_LENGTH];
			GetClientWeapon(client, weapon, sizeof(weapon));

			// Loop through all pistol classnames
			for (new i; i < sizeof(Pistols); i++) // i=0
			{
#if defined REALISM
				// Check whether or not player holding a pistol
				if (StrEqual(weapon, Pistols[i]))
				{
					// Weapon classnames in realism versions uses prefix
					CreateItem(client, type:Pistol);

					// Block the command itself, otherwise player will drop pistol and the primary weapon in same time
					return Plugin_Handled;
				}
#else
				// Skip the first 7 characters in weapon string to avoid comparing with the "weapon_" prefix
				if (StrEqual(weapon[7], Pistols[i]))
				{
					// Firstly change weapon to skip bad animations
					CreateTimer(SMALLEST_INTERVAL, Timer_ChangeWeapon, client, TIMER_FLAG_NO_MAPCHANGE);

					// And then perform pistol dropping
					DOD_DropWeapon(client, GetPlayerWeaponSlot(client, SLOT_SECONDARY), NULL_VECTOR);
					return Plugin_Handled;
				}
#endif
			}
		}

		// Does player can drop their grenades?
		if (GetConVar[AllowNade][Value])
		{
			decl String:weapon[MAX_WEAPON_LENGTH];
			GetClientWeapon(client, weapon, sizeof(weapon));

			// Does player is holding frag grenades now?
			if (StrEqual(weapon, Grenades[frag_us])
			||  StrEqual(weapon, Grenades[frag_ger]))
			{
				// Just create a nade instead of dropping
				CreateItem(client, type:Grenade);
				return Plugin_Handled;
			}
		}

		// Allow players to drop weapons as usual
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

/* OnDropAmmo()
 *
 * When the 'dropammo' command is called.
 * ---------------------------------------------------------------------------------------------------- */
public Action:OnDropAmmo(client, const String:command[], argc)
{
#if defined REALISM
	if (IsValidClient(client)
	&& IsPlayerAlive(client)
	&& !IS_MEDIC(client) // Medics are not allowed to drop one more healthkit
	&& AllowItemDropping)
#else
	if (IsValidClient(client) && IsPlayerAlive(client))
#endif
	{
		// Do the stuff if at least one feature is enabled
		if (GetConVar[AllowHealthkit][Value] || GetConVar[AllowAmmoBox][Value] || GetConVar[AllowTNT][Value])
		{
			// It's really needed to check for TNT availability here (and using only this way)
			if (GetConVar[AllowTNT][Value]
			&& IsValidEntity(GetPlayerWeaponSlot(client, SLOT_EXPLOSIVE))
			&& BombsDropped[client] < GetConVar[TNT_DropLimit][Value])
			{ HasTNT[client] = true; }

			// Check current ammo to allow or disallow dropping
			if (GetConVar[AllowAmmoBox][Value]) PerformAmmunition(client, ammotype:check);

			// Create formula for LastDropTime due to cooldown
			new LastDropTime = (GetTime() - LastDropped[client]);

			// Continue if time of last item dropping is equal or expired
			if (LastDropTime >= GetConVar[CoolDown][Value])
			{
				// Menu mode is enabled
				if (GetConVar[MenuMode][Value])
				{
					// Format translated menu title string
					decl String:szMenuTitle[64]; Format(szMenuTitle, sizeof(szMenuTitle), "%t", "Menu title");

					// Create menu with allowed items to drop. We don't need to use other actions than MenuAction_DrawItem or MenuAction_Select
					dropmenu = CreateMenu(DropMenuHandler, MenuAction_DrawItem|MenuAction_Select);

					// Sets the menu's title/instruction message (translated by format)
					SetMenuTitle(dropmenu, szMenuTitle);

					// Add items to menu
					AddTranslatedMenuItem(dropmenu, NULL_STRING, "Healthkit", client);
					AddTranslatedMenuItem(dropmenu, NULL_STRING, "Ammobox", client);
					AddTranslatedMenuItem(dropmenu, NULL_STRING, "TNT", client);

					// Display dropmenu as long as possible
					DisplayMenu(dropmenu, client, MENU_TIME_FOREVER);
				}

				// Menu mode is disabled - get the item drop priority value
				else
				{
					switch (GetConVar[ItemPriority][Value])
					{
						case 132: // 1. Healthkit 2. TNT 3. Ammobox
						{
							if (HasHealthkit[client])    CreateItem(client, type:Healthkit);
							else if (HasTNT[client])     CreateItem(client, type:Bomb);
							else if (HasAmmoBox[client]) CreateItem(client, type:Ammobox);
						}
						case 213: // 1. Ammobox 2. Healthkit 3. TNT
						{
							if (HasAmmoBox[client])        CreateItem(client, type:Ammobox);
							else if (HasHealthkit[client]) CreateItem(client, type:Healthkit);
							else if (HasTNT[client])       CreateItem(client, type:Bomb);
						}
						case 231: // 1. Ammobox 2. TNT 3. Healthkit
						{
							if (HasAmmoBox[client])        CreateItem(client, type:Ammobox);
							else if (HasTNT[client])       CreateItem(client, type:Bomb);
							else if (HasHealthkit[client]) CreateItem(client, type:Healthkit);
						}
						case 312: // 1. TNT 2. Healthkit 3. Ammobox
						{
							if (HasTNT[client])            CreateItem(client, type:Bomb);
							else if (HasHealthkit[client]) CreateItem(client, type:Healthkit);
							else if (HasAmmoBox[client])   CreateItem(client, type:Ammobox);
						}
						case 321: // 1. TNT 2. Ammobox 3. Healthkit
						{
							if (HasTNT[client])            CreateItem(client, type:Bomb);
							else if (HasAmmoBox[client])   CreateItem(client, type:Ammobox);
							else if (HasHealthkit[client]) CreateItem(client, type:Healthkit);
						}
						default: // Default (1. Healthkit 2. Ammobox 3. TNT) or maybe any other invalid number
						{
							if (HasHealthkit[client])    CreateItem(client, type:Healthkit);
							else if (HasAmmoBox[client]) CreateItem(client, type:Ammobox);
							else if (HasTNT[client])     CreateItem(client, type:Bomb);
						}
					}
				}
			}

			// Notice client if 'dropammo' command used twice for more than X seconds depends on cooldown value
			else
			{
				decl String:szCooldown[128];
				Format(szCooldown, sizeof(szCooldown), "%t", "Cooldown", GetConVar[CoolDown][Value] - LastDropTime);
				PrintHintText(client, szCooldown);
			}
		}

		// Use 'dropammo' as usual if healthkits, ammo boxes and TNT's is disabled
		else return Plugin_Continue;
	}

	return Plugin_Handled;
}

/* DropMenuHandler()
 *
 * Creates an item depends on client menu selection.
 * ---------------------------------------------------------------------------------------------------- */
public DropMenuHandler(Handle:menu, MenuAction:action, client, param)
{
	// Increase param index because it's starting from 0, but item indexes is starting from 1
	++param;

	// An item is being drawn
	if (action == MenuAction_DrawItem)
	{
		// Sets drawing style depends on item avaliability. If player is not having an item - still show it, but not allow player to select it; otherwise use default style
		switch (param)
		{
			case Healthkit: return HasHealthkit[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
			case Ammobox:   return HasAmmoBox[client]   ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
			case Bomb:      return HasTNT[client]       ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
		}
	}

	// An item was selected
	else if (action == MenuAction_Select)
	{
		switch (param)
		{
			// Drop appropriate item on selection
			case Healthkit: CreateItem(client, type:Healthkit);
			case Ammobox:   CreateItem(client, type:Ammobox);
			case Bomb:      CreateItem(client, type:Bomb);
		}
	}

	// If we change an item, we have to return the value it returns. But if we do not change an item, we must return 0
	return NOITEM;
}

#if defined REALISM
/* Timer_SetDieThink()
 *
 * Timer to call signature for anti-weapon removing.
 * ---------------------------------------------------------------------------------------------------- */
public Action:Timer_SetDieThink(Handle:event, any:data)
{
	// Convert entity reference to entity index
	new entity  = EntRefToEntIndex(data);
	if (entity != INVALID_ENT_REFERENCE)
	{
		// Calls an SDK function with the given parameters
		SDKCall(SetDieThink, entity, false);
	}
}

/* Timer_DisableMotion()
 *
 * Timer to disable motions for server-side ragdolls.
 * ---------------------------------------------------------------------------------------------------- */
public Action:Timer_DisableMotion(Handle:event, any:data)
{
	// Make sure we've passed valid data
	if (data == INVALID_HANDLE)
	{
		// Stop timer and log an error if data pack handle is invalid
		LogError("Invalid ragdoll entity reference or player team index was passed!");
		return Plugin_Stop;
	}

	// Reset data pack
	ResetPack(data);

	// Retrieve entity reference from pack and validate it
	new entity  = EntRefToEntIndex(ReadPackCell(data));
	if (entity != INVALID_ENT_REFERENCE)
	{
		// If entity reference is valid, accept disable motion input
		AcceptEntityInput(entity, "DisableMotion"); // Properly set ragdoll's team same as player's (a FieldMedic compatibility)
		SetEntProp(entity, Prop_Send, "m_iTeamNum", ReadPackCell(data));
	}

	return Plugin_Stop;
}

/* OnRealismStarted()
 *
 * Called when realism has started.
 * ---------------------------------------------------------------------------------------------------- */
public Action:OnRealismStarted()
{
	// Exec realism config for dropmanager when realism starts
	ServerCommand("exec sourcemod/dod_dropmanager_realism.cfg");

	// Disallow dropping
	AllowItemDropping = false;
}

/* OnRealismEnded()
 *
 * Called when realism has ended.
 * ---------------------------------------------------------------------------------------------------- */
public Action:OnRealismEnded()
{
	// Exec public config for dropmanager and allow items dropping again
	ServerCommand("exec sourcemod/dod_dropmanager_public.cfg");
	AllowItemDropping = true;
}

/* OnRoundStart()
 *
 * Called when realism round has started (pre-match).
 * ---------------------------------------------------------------------------------------------------- */
public Action:OnRoundStart()
{
	// Dont allow players to drop anything during warmup
	AllowItemDropping = false;
}

/* OnRoundLive()
 *
 * Called when round state set to LIVE.
 * ---------------------------------------------------------------------------------------------------- */
public Action:OnRoundLive()
{
	AllowItemDropping = true;
}
#endif

/* AddTranslatedMenuItem()
 *
 * Adds translated item names to dropmanager menu.
 * ---------------------------------------------------------------------------------------------------- */
AddTranslatedMenuItem(Handle:menu, const String:opt[], const String:phrase[], client)
{
	decl String:buffer[64];
	Format(buffer, sizeof(buffer), "%T", phrase, client);
	AddMenuItem(menu, opt, buffer);
}

/* CreateItem()
 *
 * Creates an item depends on index (healthkit, ammo box or TNT).
 * ---------------------------------------------------------------------------------------------------- */
CreateItem(client, index)
{
	decl item;

	// Make sure we can create a prop_physics_override entity, but does not spawn it yet
	if ((item = CreateEntityByName("prop_physics_override")) != INVALID_ITEM)
	{
		// Create local bool which is checks whether or not item owner is alive. Required for proper item spawning
		new bool:IsAlivePlayer = GetClientHealth(client) > 0;

		// Declare origin, angles and velocity positions to spawn item correctly in a front of player
		decl Float:origin[3], Float:angles[3], Float:velocity[3];

		// Get client origin vector
		GetClientAbsOrigin(client, origin);

		// Get client eye angles (not direction player looking)
		GetClientEyeAngles(client, angles);

		// Get vectors in the direction of an angle
		GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(velocity, velocity);

		// Scale velocity by 317 units
		ScaleVector(velocity, 317.0);

		// Increase origin's and velocity Z-vector to teleport item properly
		origin[2]   += IsAlivePlayer ? ALIVEORIGIN : DEATHORIGIN;
		velocity[2] += ALIVEORIGIN;

		switch (index)
		{
			case Healthkit: SpawnHealthkit(item, client, bool:IsAlivePlayer);
			case Ammobox:   SpawnAmmoBox(item,   client, bool:IsAlivePlayer);
			case Bomb:      SpawnTNT(item,       client, bool:IsAlivePlayer);
#if defined REALISM
			case Pistol:    SpawnPistol(item,    client, angles, bool:IsAlivePlayer);
#endif
			case Grenade:   SpawnGrenade(item,   client, angles, bool:IsAlivePlayer);
		}

		// After spawning an item, make it be collideable but fires touch functions, and set team
		SetEntProp(item, Prop_Send, "m_iTeamNum", GetClientTeam(client));
		SetEntProp(item, Prop_Send, "m_usSolidFlags",  152);
		SetEntProp(item, Prop_Send, "m_CollisionGroup", 11);

		// If player is alive, drop an item in front of it; otherwise teleport an item just around player's corpse
		TeleportEntity(item, origin, NULL_VECTOR, IsAlivePlayer ? velocity : NULL_VECTOR);

		// Do a timestamp after dropping item
		LastDropped[client] = GetTime();

		CreateTimer(HOOKTOUCH_DELAY, HookItemTouch, EntIndexToEntRef(item), TIMER_FLAG_NO_MAPCHANGE);

		// Set lifetime of an item if defined
		if (GetConVar[ItemLifeTime][Value])
		{
			// declare outout
			decl String:output[32];

			// Add output to kill itself when time is expired
			Format(output, sizeof(output), "OnUser1 !self:kill::%0.2f:-1", GetConVar[ItemLifeTime][Value]);

			// Set a string in the global variant object and properly add output to make it work
			SetVariantString(output);
			AcceptEntityInput(item, "AddOutput");
			AcceptEntityInput(item, "FireUser1");
		}
	}
}

#if defined REALISM
/* CreateServerRagdoll()
 *
 * Creates a server-side ragdoll.
 * ---------------------------------------------------------------------------------------------------- */
CreateServerSideRagdoll(client)
{
	new any:info[23];

	// bUseLRURetirement must be set to false
	/**CBaseEntity *CreateServerRagdoll( CBaseAnimating *pAnimating, int forceBone, const CTakeDamageInfo &info, int collisionGroup, bool bUseLRURetirement )*/
	return SDKCall(CreateServerRagdoll, client, 0, info, COLLISION_GROUP_INTERACTIVE_DERBIS, false);
}
#else
/* DOD_DropWeapon()
 *
 * Forces a player to drop their weapon.
 * ---------------------------------------------------------------------------------------------------- */
DOD_DropWeapon(client, weapon, const Float:vecTarget[3])
{
	// Check for valid client and its weapon
	if (IsValidClient(client) && IsValidEntity(weapon))
	{
		// Force a client to drop the specified weapon
		SDKHooks_DropWeapon(client, weapon, vecTarget);

		// Get the classname of a dropped weapon, and the angle
		decl String:class[MAX_WEAPON_LENGTH], Float:ang[3];
		GetEdictClassname(weapon, class, sizeof(class));
		GetEntPropVector(weapon, Prop_Send, "m_angRotation", ang);

		// Make sure colt was dropped
		if (StrEqual(class[7], Pistols[COLT]))
		{
			// Colt's physics model is fucked up, and easier way to fix it is just adding 90 units to model angle
			// https://github.com/ValveSoftware/Source-1-Games/issues/774
			ang[2] += 90.0; TeleportEntity(weapon, NULL_VECTOR, ang, NULL_VECTOR);

			// This thing prevents physics model from sliding at a ground as well
			SetEntProp(weapon, Prop_Data, "m_MoveCollide", true);
		}

		// This timestamp is for +USE cooldown
		LastDropped[client] = GetTime();

		// Unfortunately pistol's ammo (not clip size) after dropping wont save, so lets change ammo manually then
		SetPistolAmmo(client, weapon, ammotype:drop);
		SetEntProp(weapon, Prop_Data, "m_iHammerID", Pistol);

		// I have to hook touch callback for dropped pistol as well
		CreateTimer(HOOKTOUCH_DELAY, HookItemTouch, EntIndexToEntRef(weapon), TIMER_FLAG_NO_MAPCHANGE);

		// Make sure that player is not having a pistol anymore
		HasPistol[client] = false;
	}
}
#endif

/* HookItemTouch()
 *
 * Makes item able to be touched by player.
 * ---------------------------------------------------------------------------------------------------- */
public Action:HookItemTouch(Handle:timer, any:ref)
{
	// Retrieve the entity index from a reference
	new item = EntRefToEntIndex(ref);

	// Make sure entity reference is valid
	if (item != INVALID_ENT_REFERENCE)
	{
		// So now lets check what item was actually dropped (healthkit, ammobox or w/e) and hook their touch callbacks appropriately
		switch (GetEntProp(item, Prop_Data, "m_iHammerID"))
		{
			case Healthkit:
			{
				SDKHook(item, SDKHook_StartTouch, OnHealthKitTouched);
				SDKHook(item, SDKHook_Touch,      OnHealthKitTouched);
				SDKHook(item, SDKHook_EndTouch,   OnHealthKitTouched);
			}
			case Ammobox:
			{
				SDKHook(item, SDKHook_StartTouch, OnAmmoBoxTouched);
				SDKHook(item, SDKHook_Touch,      OnAmmoBoxTouched);
				SDKHook(item, SDKHook_EndTouch,   OnAmmoBoxTouched);
			}
			case Bomb:
			{
				SDKHook(item, SDKHook_StartTouchPost, OnBombTouched);
				SDKHook(item, SDKHook_TouchPost,      OnBombTouched);
				SDKHook(item, SDKHook_EndTouchPost,   OnBombTouched);
			}
			case Grenade:
			{
				SDKHook(item, SDKHook_StartTouchPost, OnGrenadeTouched);
				SDKHook(item, SDKHook_TouchPost,      OnGrenadeTouched);
				SDKHook(item, SDKHook_EndTouchPost,   OnGrenadeTouched);
			}
			case Pistol:
			{
#if defined REALISM
				SDKHook(item, SDKHook_StartTouchPost, OnPistolTouched);
				SDKHook(item, SDKHook_TouchPost,      OnPistolTouched);
				SDKHook(item, SDKHook_EndTouchPost,   OnPistolTouched);
#else
				// Since we're dropped real pistol entity, its unnecessary to hook Start/EndTouch callbacks as well
				SDKHook(item, SDKHook_Touch, OnPistolTouched);
#endif
			}
		}
	}
}

/* RemoveWeapon()
 *
 * Removes weapon from player's slot.
 * ---------------------------------------------------------------------------------------------------- */
RemoveWeapon(client, slot)
{
	if (RemovePlayerItem(client, slot))
	{
		// Because RemoveEdict is not safe to use at all
		RemoveEntity(slot);
	}
}

/* RemoveEntity()
 *
 * Removes an entity from the world.
 * ---------------------------------------------------------------------------------------------------- */
RemoveEntity(const entity)
{
	return AcceptEntityInput(entity, "Kill");
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * ---------------------------------------------------------------------------------------------------- */
bool:IsValidClient(client) return (1 <= client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) > Spectators) ? true : false;