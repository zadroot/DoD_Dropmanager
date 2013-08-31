/**
 * ------------------------------------------------------------------------------------------------------
 *    _    __    __
 *   | |  /  |  / /__  ____ _____  ____  ____  _____
 *   | | / / | / / _ \/ __ `/ __ \/ __ \/ __ \/ ___/
 *   | |/ /| |/ /  __/ /_/ / /_/ / /_/ / / / (__  )
 *   |___/ |___/\___/\__,_/ .___/\____/_/ /_/____/
 *                        /_/
 * ------------------------------------------------------------------------------------------------------
*/

#define SMALLEST_INTERVAL 0.1

#define COLT 0
#define frag_us 0
#define frag_ger 1

// I've changed table to avoid overbounds: { noweapon, colt, p38, c96, garand, k98, m1carbine }
new	bool:HasPistol[DOD_MAXPLAYERS + 1], pistoloffs[]  = { -1, 4, 8, 12, -1, -1, 24 },
	bool:HasNade[DOD_MAXPLAYERS + 1],   grenadeoffs[] = { 52, 56 };

new	const
	String:PickSound[]       = { "weapons/ammopickup.wav" },
	String:Grenades[][]      = { "weapon_frag_us", "weapon_frag_ger" },
	String:GrenadeModels[][] = { "models/weapons/w_frag.mdl", "models/weapons/w_stick.mdl" },
	String:Pistols[][]       = // Because I already ignore 'weapon_' prefix
{
	"colt",
	"p38",
	"c96",
	"m1carbine"
};

/* OnPistolTouched()
 *
 * When the pistol is touched.
 * ------------------------------------------------------------------------------------------------------ */
public Action:OnPistolTouched(pistol, client)
{
	if (IsValidClient(client))
	{
		// If player is not having a pistol, give it to a player
		if (!IsValidEntity(GetPlayerWeaponSlot(client, SLOT_SECONDARY)))
		{
			// Originally pistol is not having touch sound, but we want to emit it
			decl Float:vecOrigin[3];
			GetClientEyePosition(client, vecOrigin);
			EmitAmbientSound(AmmoSound,  vecOrigin, client);

			// Now properly give a pistol to player, and set it ammo
			EquipPlayerWeapon(client, pistol);
			SetPistolAmmo(client, pistol, ammotype:pickup);

			// Unhook it now, because entity was equipped, not killed
			SDKUnhook(pistol, SDKHook_Touch, OnPistolTouched);

			HasPistol[client] = true;
		}

		// Otherwise dont allow player to pick it
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

/* SetAmmo()
 *
 * Adds magazines to a specified weapons.
 * ------------------------------------------------------------------------------------------------------ */
SetPistolAmmo(client, weapon, type)
{
	// Get the weapon indexes (0 = nothing, 1 = colt, 2 = p38...)
	new WeaponID = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");

	// Retrieve the type for ammunition
	switch (type)
	{
		// When player is dropped pistol, set unused m_iClip2 value to current player's ammo for this pistol
		case drop:   SetEntProp(weapon, Prop_Send, "m_iClip2", GetEntData(client, m_iAmmo + pistoloffs[WeaponID]));

		// When player is picked up pistol, set his ammo equal to m_iClip2 pistol's property
		case pickup: SetEntData(client, m_iAmmo + pistoloffs[WeaponID], GetEntProp(weapon, Prop_Send, "m_iClip2"));
	}
}

/* OnGrenadeTouched()
 *
 * When the grenade is touched.
 * ------------------------------------------------------------------------------------------------------ */
public OnGrenadeTouched(nade, client)
{
	if (IsValidClient(client))
	{
		decl String:weapon[MAX_WEAPON_LENGTH], Float:vecOrigin[3];
		GetClientEyePosition(client, vecOrigin);

		// For optimizations its better initialize m_iAmmo data for grenades right now
		new grenade  = GetPlayerWeaponSlot(client, SLOT_GRENADE);
		new gren_us  = GetEntData(client, m_iAmmo + grenadeoffs[frag_us]);
		new gren_ger = GetEntData(client, m_iAmmo + grenadeoffs[frag_ger]);

		if (IsValidEntity(grenade))
		{
			// If player is already having grenades, get the classname of them to increase amount if player took same type of grenade
			GetEdictClassname(grenade, weapon, sizeof(weapon));
		}

		switch (GetEntProp(nade, Prop_Send, "m_nBody"))
		{
			case frag_us:
			{
				// Increase amount of frag greandes by 1 on pickup
				SetEntData(client, m_iAmmo + grenadeoffs[frag_us], gren_us + 1);
				if (!StrEqual(weapon, Grenades[frag_us]) && !gren_us)
				{
					// If player is not having it, just give grenade itself
					GivePlayerItem(client, Grenades[frag_us]);
					SetEntData(client, m_iAmmo + grenadeoffs[frag_us], true);
				}
			}
			case frag_ger:
			{
				SetEntData(client, m_iAmmo + grenadeoffs[frag_ger], gren_ger + 1);
				if (!StrEqual(weapon, Grenades[frag_ger]) && !gren_ger)
				{
					GivePlayerItem(client, Grenades[frag_ger]);

					// Originally GivePlayerItem 'grenade' gives two grenades, so I have to decrease it by 1
					SetEntData(client, m_iAmmo + grenadeoffs[frag_ger], true);
				}
			}
		}

		// No pickup rule here, no restrictions at all, so just remove it
		RemoveEntity(nade);

		// Emit new sound when player picked grenade
		EmitAmbientSound(PickSound, vecOrigin, client);

		HasNade[client] = true;
	}
}

/* SpawnGrenade()
 *
 * Spawns a grenade in front of player.
 * ------------------------------------------------------------------------------------------------------ */
SpawnGrenade(nade, client, bool:IsAlivePlayer)
{
	new grenade = GetPlayerWeaponSlot(client, SLOT_GRENADE);

	// Because we cant drop invalid grenade
	if (IsValidEntity(grenade))
	{
		// Retrieve the player's ammo offsets for grenades
		new gren_us  = GetEntData(client, m_iAmmo + grenadeoffs[frag_us]);
		new gren_ger = GetEntData(client, m_iAmmo + grenadeoffs[frag_ger]);

		// Since checking for valid grenade is performed, we can easily get the classname of it
		decl String:weapon[MAX_WEAPON_LENGTH];
		GetEdictClassname(grenade, weapon, sizeof(weapon));

		if (StrEqual(weapon, Grenades[frag_us]))
		{
			// If player is having more than 1 grenade in inventory, decrease amount by one grenade
			if (gren_us > 1)
			{
				SetEntData(client, m_iAmmo + grenadeoffs[frag_us], gren_us - 1);
			}
			else if (IsAlivePlayer)
			{
				HasNade[client] = false;

				CreateTimer(SMALLEST_INTERVAL, Timer_ChangeWeapon, client, TIMER_FLAG_NO_MAPCHANGE);

				// It fixes a problem when player picked more than 2 grenades while was holding another grenade
				SetEntData(client, m_iAmmo + grenadeoffs[frag_us], false);
				RemoveWeapon(client, grenade);
			}

			// Set appropriately grenade model
			SetEntityModel(nade, GrenadeModels[frag_us]);
			SetEntProp(nade, Prop_Send, "m_nBody", frag_us);
		}
		else if (StrEqual(weapon, Grenades[frag_ger]))
		{
			if (gren_ger > 1)
			{
				SetEntData(client, m_iAmmo + grenadeoffs[frag_ger], gren_ger - 1);
			}

			// Otherwise remove weapon at all (if player is also alive)
			else if (IsAlivePlayer)
			{
				HasNade[client] = false;

				CreateTimer(SMALLEST_INTERVAL, Timer_ChangeWeapon, client, TIMER_FLAG_NO_MAPCHANGE);

				// Change player's grenade amount and remove them at all
				SetEntData(client, m_iAmmo + grenadeoffs[frag_ger], false);
				RemoveWeapon(client, grenade);
			}

			// And unique index
			SetEntityModel(nade, GrenadeModels[frag_ger]);
			SetEntProp(nade, Prop_Send, "m_nBody", frag_ger);
		}

		// SDKHooks_DropWeapon is bad for grenades, so I have to use DispatchSpawn
		if (DispatchSpawn(nade))
		{
			// When its dropped, set the index to Grenade to hook touch functions properly
			SetEntProp(nade, Prop_Data, "m_iHammerID", Grenade);
		}
	}
}

/* Timer_ChangeWeapon()
 *
 * Equips new player weapon after dropping grenades or pistols.
 * ------------------------------------------------------------------------------------------------------ */
public Action:Timer_ChangeWeapon(Handle:timer, any:client)
{
	if (IsValidClient(client))
	{
		new PrimaryWeapon   = GetPlayerWeaponSlot(client, SLOT_PRIMARY);
		new SecondaryWeapon = GetPlayerWeaponSlot(client, SLOT_SECONDARY);
		new MeleeWeapon     = GetPlayerWeaponSlot(client, SLOT_MELEE);
		new GrenadeSlot     = GetPlayerWeaponSlot(client, SLOT_GRENADE);

		// If primary weapon is avalible, switch client's weapon to primary
		if (IsValidEntity(PrimaryWeapon))
		{
			SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", PrimaryWeapon);
		}

		// But if primary weapon is not avalible, use secondary then; otherwise melee
		else if (IsValidEntity(SecondaryWeapon) && HasPistol[client] == true)
		{
			SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", SecondaryWeapon);
		}
		else if (IsValidEntity(MeleeWeapon))
		{
			SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", MeleeWeapon);
		}

		// Or even a grenade
		else if (IsValidEntity(GrenadeSlot))
		{
			SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", GrenadeSlot);
		}
	}
}