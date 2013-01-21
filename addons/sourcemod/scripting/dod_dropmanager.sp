/**
* DoD:S DropManager by Root
*
* Description:
*   Allows player to drop healthkit, ammo box or TNT.
*   Special thanks to FeuerSturm and BenSib!
*
* Version 3.0
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
#define PLUGIN_VERSION "3.0"

#define DOD_MAXPLAYERS 33
#define MAXHEALTH      100
#define MAXENTITIES    2048 // Virtual entities can go to 2048 max

#define SLOT_PRIMARY   0
#define SLOT_EXPLOSIVE 4

enum Teams
{
	Spectators = 1,
	Allies,
	Axis,
};

enum Items
{
	Healthkit,
	Ammobox,
	Bomb,
};

new LastDropped[DOD_MAXPLAYERS + 1];

// ====[ PLUGIN ]====================================================================
#include "dropmanager/convars.sp"
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
	// Create version convar
	CreateConVar("dod_dropmanager_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY);

	// Load all plugin convars from dropmanager/convars.sp file
	LoadConVars();

	// Added: 2.0 update
	LoadTranslations("dod_dropmanager.phrases");

	// Store send property offset for ammo setup
	m_iAmmo = FindSendPropOffs("CDODPlayer", "m_iAmmo");

	// Since 'dropammo' command is exists, use AddCommandListener instead of Reg*Cmd
	AddCommandListener(OnDropAmmo, "dropammo");

	// Hook events
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_hurt",  OnPlayerDeath);

	// Create and exec plugin's configuration file
	AutoExecConfig(true, "dod_dropmanager");
}

/* OnConfigsExecuted()
 *
 * When the map has loaded and all plugin configs are done executing.
 * ---------------------------------------------------------------------------------- */
public OnConfigsExecuted()
{
	// If custom healthkit model is defined...
	if (GetConVar[Healthkit_NewModel][Value])
	{
		// ...allow custom healthkit files to be downloaded to clients
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

	// Sounds doesn't crash client, but you still need to precache them tho
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
	if (GetConVar[AllowHealthkit][Value])
		 HasHealthkit[client] = true;
	else HasHealthkit[client] = false;

	// Same way for ammo box
	if (GetConVar[AllowAmmoBox][Value])
		 HasAmmoBox[client] = true;
	else HasAmmoBox[client] = false;

	// Reset dropped bombs
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
		if (GetConVar[AllowTNT][Value]
		&& IsValidEntity(GetPlayerWeaponSlot(client, SLOT_EXPLOSIVE)))
		{ HasTNT[client] = true; }

		switch (GetConVar[DeadDrop][Value])
		{
			case 1:
			{
				if (!GetConVar[AliveCheck][Value]) CreateItem(client, type:Healthkit);
				else if (HasHealthkit[client])     CreateItem(client, type:Healthkit);
			}
			case 2:
			{
				if (!GetConVar[AliveCheck][Value]) CreateItem(client, type:Ammobox);
				else if (HasAmmoBox[client])       CreateItem(client, type:Ammobox);
			}
			case 3:
			{
				if (!GetConVar[AliveCheck][Value]) CreateItem(client, type:Bomb);
				else if (HasTNT[client])           CreateItem(client, type:Bomb);
			}
			case 4:
			{
				switch (GetRandomInt(from:Healthkit, to:Bomb))
				{
					case Healthkit:
					{
						if (!GetConVar[AliveCheck][Value]) CreateItem(client, type:Healthkit);
						else if (HasHealthkit[client])     CreateItem(client, type:Healthkit);
					}
					case Ammobox:
					{
						if (!GetConVar[AliveCheck][Value]) CreateItem(client, type:Ammobox);
						else if (HasAmmoBox[client])       CreateItem(client, type:Ammobox);
					}
					case Bomb:
					{
						if (!GetConVar[AliveCheck][Value]) CreateItem(client, type:Bomb);
						else if (HasTNT[client])           CreateItem(client, type:Bomb);
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
		// If at least one feature is enabled - continue
		if (GetConVar[AllowHealthkit][Value] || GetConVar[AllowAmmoBox][Value] || GetConVar[AllowTNT][Value])
		{
			// It's really needed to check for TNT avaliability here
			if (GetConVar[AllowTNT][Value]
			&& IsValidEntity(GetPlayerWeaponSlot(client, SLOT_EXPLOSIVE)))
			{ HasTNT[client] = true; }

			// Check current ammo to allow or disallow dropping
			if (GetConVar[AllowAmmoBox][Value]) PerformAmmunition(client, ammotype:check);

			// Create formula for LastDropTime due to cooldown
			new LastDropTime = (GetTime() - LastDropped[client]);

			// Continue if time of last item dropping is equal or expired
			if (LastDropTime >= GetConVar[CoolDown][Value])
			{
				// Get time that client dropped item
				LastDropped[client] = GetTime();

				// Menu mode is enabled
				if (GetConVar[MenuMode][Value])
				{
					// Format a string into translated one
					decl String:szMenuTitle[64]; Format(szMenuTitle, sizeof(szMenuTitle), "%t", "Menu title");
					decl String:szHealthkit[64]; Format(szHealthkit, sizeof(szHealthkit), "%t", "Healthkit");
					decl String:szAmmoBox[64];   Format(szAmmoBox,   sizeof(szAmmoBox),   "%t", "Ammobox");
					decl String:szTNT[64];       Format(szTNT,       sizeof(szTNT),       "%t", "TNT");
					decl String:szClose[64];     Format(szClose,     sizeof(szClose),     "%t", "Close");

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
					if (HasHealthkit[client]) CreateItem(client, type:Healthkit);

					// Nope. Drop ammo instead
					else if (HasAmmoBox[client]) CreateItem(client, type:Ammobox);

					// And then TNT if avalible
					else if (HasTNT[client]) CreateItem(client, type:Bomb);
				}
			}

			// Notice client if 'dropammo' command used twice for more than X seconds depends on cooldown value
			else
			{
				// Cooldown string
				decl String:szCooldown[128];
				Format(szCooldown, sizeof(szCooldown), "%t", "Cooldown", GetConVar[CoolDown][Value] - LastDropTime);

				// Draw warning message in a middle of the screen
				PrintHintText(client, szCooldown);
			}
		}

		// Use 'dropammo' as usual if healthkits, ammo boxes and bombs is disabled
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
			case 1: CreateItem(client, type:Healthkit);
			case 2: CreateItem(client, type:Ammobox);
			case 3: CreateItem(client, type:Bomb);
		}
	}
}

/* CreateItem()
 *
 * Creates an item depends on index (healthkit, ammo box or TNT).
 * ---------------------------------------------------------------------------------- */
CreateItem(client, index)
{
	// Make sure that number of entities in the server is not exceeded number of max virtual entities
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

	// Otherwise dont spawn any more items to prevent 'Engine error: ED_Alloc: no free edicts' (otherwise known as server crash) and disable plugin
	else SetFailState("Entity limit is nearly reached (%i out of %i). Please switch or reload the map!", GetEntityCount(), GetMaxEntities());
}

/* IsValidClient()
 *
 * Checks if a client is valid.
 * ---------------------------------------------------------------------------------- */
bool:IsValidClient(client)
{
	// Make sure client index is valid, client in game and not a spectator
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && Teams:GetClientTeam(client) > Teams:Spectators) ? true : false;
}