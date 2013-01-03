/**
* DoD:S Dropmanager by Root
*
* Description:
*   Allows player to drop healthkit, ammo box or TNT.
*   Special thanks to FeuerSturm and BenSib!
*
* Version 2.0
* Changelog & more info at http://goo.gl/4nKhJ
*/

// ====[ SEMICOLON ]=================================================================
#pragma semicolon 1

// ====[ INCLUDES ]==================================================================
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// ====[ CONSTANTS ]=================================================================
#define PLUGIN_NAME    "DoD:S DropManager"
#define PLUGIN_VERSION "2.0"

#define DOD_MAXPLAYERS 33
#define MAXHEALTH      100
#define MAXENTITIES    2048 // Virtual entities can go to 2048

enum //Teams
{
	DODTeam_Unassigned,
	DODTeam_Spectators,
	DODTeam_Allies,
	DODTeam_Axis
}

enum //Slots
{
	Slot_Primary,
	Slot_Secondary,
	Slot_Melee,
	Slot_Grenade,
	Slot_Bomb
}

enum //Items
{
	Healthkit,
	Ammobox,
	Bomb
}

// ====[ VARIABLES ]=================================================================
new Handle:menumode     = INVALID_HANDLE,
	Handle:deaddrop     = INVALID_HANDLE,
	Handle:alivecheck   = INVALID_HANDLE,
	Handle:itemlifetime = INVALID_HANDLE,
	Handle:cooldowntime = INVALID_HANDLE,
	ItemDropped[DOD_MAXPLAYERS + 1];

// ====[ PLUGIN ]====================================================================
#include "dropmanager/ammobox.sp"
#include "dropmanager/healthkit.sp"
#include "dropmanager/tnt.sp"

public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root, FeuerSturm & BenSib",
	description = "Allows player to drop healthkit, ammo box or TNT using different ways",
	version     = PLUGIN_VERSION,
	url         = "http://dodsplugins.com/"
}


/* OnPluginStart()
 *
 * When the plugin starts up.
 * ---------------------------------------------------------------------------------- */
public OnPluginStart()
{
	// Create version ConVar
	CreateConVar       ("dod_dropmanager_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED);

	// Create normal ConVars
	allowhealthkit     = CreateConVar("dod_dropmanager_healthkit",    "1",  "Whether or not enable healthkit dropping", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	allowammobox       = CreateConVar("dod_dropmanager_ammobox",      "1",  "Whether or not enable ammo box dropping", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	allowtnt           = CreateConVar("dod_dropmanager_tnt",          "1",  "Whether or not enable TNT dropping", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	menumode           = CreateConVar("dod_dropmanager_menumode",     "1",  "Whether or not use 'menu mode'\nIt lets player choose items for dropping using panel", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	deaddrop           = CreateConVar("dod_dropmanager_deaddrop",     "0",  "Determines item to drop on player's death:\n0 = Nothing\n1 = Healthkit\n2 = Ammo box\n3 = TNT\n4 = Random", FCVAR_PLUGIN, true, 0.0, true, 4.0);
	alivecheck         = CreateConVar("dod_dropmanager_alivecheck",   "1",  "Whether or not check item avaliability before death. Can be useful for deaddop feature", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	itemlifetime       = CreateConVar("dod_dropmanager_lifetime",     "45", "Number of seconds a dropped item stays on the map", FCVAR_PLUGIN, true, 10.0, true, 120.0);
	cooldowntime       = CreateConVar("dod_dropmanager_cooldown",     "3",  "Number of seconds to wait between two drop commands", FCVAR_PLUGIN, true, 0.0, true, 30.0);

	healthkitrule      = CreateConVar("dod_drophealthkit_pickuprule", "0",  "Determines who can pick up dropped healthkits:\n0 = Everyone\n1 = Only teammates\n2 = Only enemies", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	healthkithealth    = CreateConVar("dod_drophealthkit_addhealth",  "50", "Determines amount of health to add to a player which picking up a healthkit", FCVAR_PLUGIN, true, 0.0, true, 100.0);
	healthkitselfheal  = CreateConVar("dod_drophealthkit_selfheal",   "30", "Determines amount of player's health to allow heal himself using own healthkit", FCVAR_PLUGIN, true, 0.0, true, 99.0);
	healthkitteamcolor = CreateConVar("dod_drophealthkit_teamcolor",  "0",  "Whether or not colorize dropped healthkit depends on player's team", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	healthkitcustom    = CreateConVar("dod_drophealthkit_newmodel",   "0",  "Whether or not use custom model for healthkit\nDo not change until map change!", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	ammopickuprule     = CreateConVar("dod_dropammobox_pickuprule",   "1",  "Determines who can pick up dropped ammo box:\n0 = Everyone\n1 = Only teammates\n2 = Only enemies", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	ammorealism        = CreateConVar("dod_dropammobox_realism",      "1",  "Whether or not use 'realism' mode\nIt means player may share ammo of primary weapons until no ammo left", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	ammosize           = CreateConVar("dod_dropammobox_clipsize",     "2",  "Determines number of clips a dropped ammo box contains", FCVAR_PLUGIN, true, 1.0, true, 5.0);
	ammovoice          = CreateConVar("dod_dropammobox_voice",        "1",  "Whether or not use voice command when ammo is dropped", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	tntpickuprule      = CreateConVar("dod_droptnt_pickuprule",       "0",  "Determines who can pick up dropped TNT:\n0 = Everyone\n1 = Only teammates\n2 = Only enemies", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	tntmaxdrops        = CreateConVar("dod_droptnt_maxdrops",         "3",  "Determines how many TNT's player can drop per life\nThis cvar created against spamming around bomb dispencer", FCVAR_PLUGIN, true, 1.0);

	// Added since 2.0
	LoadTranslations("dod_dropmanager.phrases");

	// Store send property offset for ammo setup
	m_iAmmo = FindSendPropOffs("CDODPlayer", "m_iAmmo");

	// Since 'dropammo' command is exists, use AddCommandListener instead of Reg*Cmd
	AddCommandListener(OnDropAmmo, "dropammo");

	// Hook events
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_hurt",  OnPlayerDeath);

	// Create and exec dod_dropmanager configuration file
	AutoExecConfig(true, "dod_dropmanager");
}

/* OnConfigsExecuted()
 *
 * When the map has loaded and all plugin configs are done executing.
 * ---------------------------------------------------------------------------------- */
public OnConfigsExecuted()
{
	// If custom healthkit model is defined...
	if (GetConVarBool(healthkitcustom))
	{
		// ...allow custom healthkit files to be downloaded to client
		for (new i = 0; i < sizeof(HealthkitFiles); i++)
			AddFileToDownloadsTable(HealthkitFiles[i]);
		PrecacheModel(HealthkitModel2, true);
	}

	// Precache a healthkit's model & sound
	PrecacheModel(HealthkitModel,  true);
	PrecacheSound(HealthkitSound,  true);
	PrecacheSound(HealSound,       true);

	// Also precache all ammoboxes, including sound
	PrecacheModel(AlliesAmmoModel, true);
	PrecacheModel(AxisAmmoModel,   true);
	PrecacheSound(AmmoSound,       true);

	// Model precaching prevents client crash
	PrecacheModel(TNTModel,        true);

	// Sound doesn't crash client, but you still need to precache this to make sound playable
	PrecacheSound(TNTSound,        true);
}

/* OnPlayerSpawn()
 *
 * Called when a player spawns.
 * ---------------------------------------------------------------------------------- */
public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Convert client index from an event
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	// If healthkits is enabled, allow players to use it, otherwise disable
	if (GetConVarBool(allowhealthkit))
		 HasHealthkit[client] = true;
	else HasHealthkit[client] = false;

	// Same way for ammo box
	if (GetConVarBool(allowammobox))
		 HasAmmoBox[client] = true;
	else HasAmmoBox[client] = false;

	BombsDropped[client]    = false;
}

/* OnPlayerDeath()
 *
 * Called when a player dies.
 * ---------------------------------------------------------------------------------- */
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	// Unfourdately I have to hook player_hurt event and check client health. Death event is too late to check weapon avaliability
	if (GetClientHealth(client) < 1)
	{
		// Check 4th slot (a bomb) right before death, because 'dod_tnt_pickup' event is client-side only
		if (GetConVarBool(allowtnt)
		&& GetPlayerWeaponSlot(client, Slot_Bomb) != -1)
		{ HasTNT[client] = true; }

		// Get value of 'drop on death' convar
		switch (GetConVarInt(deaddrop))
		{
			// Check for item avaliability and create it depends on value
			case 1:
			{
				// If 'alive check' is disabled, create healthkit even if healthkits is disabled
				if (!GetConVarBool(alivecheck)) CreateItem(client, Healthkit);
				else if (HasHealthkit[client])  CreateItem(client, Healthkit);
			}
			case 2:
			{
				// Otherwise check item avaliability, and create that
				if (!GetConVarBool(alivecheck)) CreateItem(client, Ammobox);
				else if (HasAmmoBox[client])    CreateItem(client, Ammobox);
			}
			case 3:
			{
				if (!GetConVarBool(alivecheck)) CreateItem(client, Bomb);
				else if (HasTNT[client])        CreateItem(client, Bomb);
			}
			case 4:
			{
				// Value 4 means random item. So get random integer between item indexes
				switch (GetRandomInt(Healthkit, Bomb))
				{
					// Same algorithm here
					case Healthkit:
					{
						if (!GetConVarBool(alivecheck)) CreateItem(client, Healthkit);
						else if (HasHealthkit[client])  CreateItem(client, Healthkit);
					}
					case Ammobox:
					{
						if (!GetConVarBool(alivecheck)) CreateItem(client, Ammobox);
						else if (HasAmmoBox[client])    CreateItem(client, Ammobox);
					}

					// Obviously for all items
					case Bomb:
					{
						if (!GetConVarBool(alivecheck)) CreateItem(client, Bomb);
						else if (HasTNT[client])        CreateItem(client, Bomb);
					}
				}
			}
		}
	}
}

/* OnDropAmmo()
 *
 * When the 'dropammo' command is called.
 * ---------------------------------------------------------------------------------- */
public Action:OnDropAmmo(client, const String:command[], argc)
{
	// Only valid and alive players can use this command
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		// If at least one feature is enabled, continue
		if (GetConVarBool(allowhealthkit) || GetConVarBool(allowammobox) || GetConVarBool(allowtnt))
		{
			// Create formula for LastDropTime due to cooldown
			new LastDropTime = (GetTime() - ItemDropped[client]);

			// It's really needed to check for TNT avaliability here
			if (GetConVarBool(allowtnt)
			&& GetPlayerWeaponSlot(client, Slot_Bomb) != -1)
			{ HasTNT[client] = true; }

			// Check current ammo to allow or disallow dropping
			if (GetConVarBool(allowammobox)) PerformAmmunition(client, ammotype:check);

			// Continue if time of last item dropping is equal or expired
			if (LastDropTime >= GetConVarInt(cooldowntime))
			{
				// Get time that client dropped item
				ItemDropped[client] = GetTime();

				// Menu mode is enabled
				if (GetConVarBool(menumode))
				{
					// initialize strings because I cant translate items directly in a panel
					decl String:szMenuTitle[64], String:szHealthkit[64], String:szAmmoBox[64], String:szTNT[64], String:szClose[64];

					// Format a string into translated one
					Format(szMenuTitle, sizeof(szMenuTitle), "%t", "Menu title");
					Format(szHealthkit, sizeof(szHealthkit), "%t", "Healthkit");
					Format(szAmmoBox,   sizeof(szAmmoBox),   "%t", "Ammobox");
					Format(szTNT,       sizeof(szTNT),       "%t", "TNT");
					Format(szClose,     sizeof(szClose),     "%t", "Close");

					// Panel is much better than menu
					new Handle:dropmenu = CreatePanel();

					// It's like SetMenuTitle for menus, but we're using panels you know
					DrawPanelText(dropmenu, szMenuTitle);

					// If client have an item, allow client to select it, otherwise just draw as disabled item
					if (HasHealthkit[client])
						 DrawPanelItem(dropmenu, szHealthkit);
					else DrawPanelItem(dropmenu, szHealthkit, ITEMDRAW_DISABLED);
					if (HasAmmoBox[client])
						 DrawPanelItem(dropmenu, szAmmoBox);
					else DrawPanelItem(dropmenu, szAmmoBox, ITEMDRAW_DISABLED);
					if (HasTNT[client])
						 DrawPanelItem(dropmenu, szTNT);
					else DrawPanelItem(dropmenu, szTNT, ITEMDRAW_DISABLED);

					// Just a spacer
					DrawPanelItem(dropmenu, NULL_STRING, ITEMDRAW_SPACER);

					// Since its a panel, its dont have 'Exit' or 'Close' items - create it right now
					SetPanelCurrentKey(dropmenu, 10);
					DrawPanelItem(dropmenu, szClose, ITEMDRAW_CONTROL);

					// Send panel to client and draw it until client close it
					SendPanelToClient(dropmenu, client, DropMenuHandler, MENU_TIME_FOREVER);

					// Fuck invalid handles
					CloseHandle(dropmenu);
				}

				// Menu mode is disabled
				else
				{
					// If client have a healthkit, drop it
					if (HasHealthkit[client]) CreateItem(client, Healthkit);

					// Nope. Drop ammo instead
					else if (HasAmmoBox[client]) CreateItem(client, Ammobox);

					// And then TNT if avalible
					else if (HasTNT[client]) CreateItem(client, Bomb);
				}
			}

			// Notice client if 'dropammo' command used twice for more than X seconds depends on cooldown value
			else
			{
				// Cooldown feature
				decl String:szCooldown[128];
				Format(szCooldown, sizeof(szCooldown), "%t", "Cooldown", GetConVarInt(cooldowntime) - LastDropTime);

				// Draw warning message in a middle of the screen
				PrintHintText(client, szCooldown);
			}
		}

		// Healthkit, ammo or TNT features is disabled - use dropcommand as usual
		else return Plugin_Continue;
	}

	return Plugin_Handled;
}

/* DropMenuHandler()
 *
 * Creates an item depends on client menu selection.
 * ---------------------------------------------------------------------------------- */
public DropMenuHandler(Handle:menu, MenuAction:action, client, param)
{
	// 'Cause there is not other actions than select
	if (action == MenuAction_Select)
	{
		// Create item depends on action parameter
		switch (param)
		{
			// Since panel title is 0, all indexes started by number 1
			case 1: CreateItem(client, Healthkit);
			case 2: CreateItem(client, Ammobox);
			case 3: CreateItem(client, Bomb);
		}
	}
}

/* CreateItem()
 *
 * Creates an item depends on index (healthkit, ammo box or TNT).
 * ---------------------------------------------------------------------------------- */
CreateItem(client, index)
{
	// Make sure that number of entities in the server is not exceeded number of virtual entities
	if (GetEntityCount() < GetMaxEntities() - 32)
	{
		// Creates a prop_physics_override entity, but does not spawn it yet
		new item = CreateEntityByName("prop_physics_override");

		switch (index)
		{
			// Now we can spawn an entity (item) depends on unique index
			case Healthkit: SpawnHealthkit(item, client);
			case Ammobox:   SpawnAmmoBox(item,   client);
			case Bomb:      SpawnTNT(item,       client);
		}
	}

	// Otherwise dont spawn any more items to prevent Engine error: ED_Alloc: no free edicts (server crash) and disable the plugin
	else SetFailState("Plugin unloaded. Entity limit is nearly reached (%i out of %i max.). Please switch or reload the map!", GetEntityCount(), GetMaxEntities());
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * ---------------------------------------------------------------------------------- */
bool:IsValidClient(client) return (client > 0 && client <= MaxClients && IsClientInGame(client)) ? true : false;