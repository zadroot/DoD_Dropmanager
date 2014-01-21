/**
 * ------------------------------------------------------------------------------------------------------
 *      __ __
 *     / // /__   ____ ___ _____
 *    / / __/ _ \/ __ `__ \ ___/
 *   / / /_/  __/ / / / / (__  )
 *  /_/\__/\___/_/ /_/ /_/____/
 *
 * ------------------------------------------------------------------------------------------------------
*/

enum ammotype
{
	check,
	drop,
	pickup
}

new	bool:HasAmmoBox[DOD_MAXPLAYERS + 1],
	ammo_offset[]   = { 16, 20, 32, 32, 36, 32, 28, 20,  40,  44, 48, 48 },
	ammo_clipsize[] = { 8,   5, 30, 30, 20, 30,  5,  5, 150, 250,  1,  1 },
	m_iAmmo;

new	const
	String:AmmoSound[]       = { "items/ammo_pickup.wav" },
	String:AxisAmmoModel[]   = { "models/ammo/ammo_axis.mdl" },
	String:AlliesAmmoModel[] = { "models/ammo/ammo_us.mdl" },
	String:Weapons[][]       =
{
	"garand", "k98",        "thompson",  "mp40", "bar",     "mp44",
	"spring", "k98_scoped", "30cal",     "mg42", "bazooka", "pschreck"
};

/* OnAmmoBoxTouched()
 *
 * When the ammo box is touched.
 * ------------------------------------------------------------------------------------------------------ */
public Action:OnAmmoBoxTouched(ammobox, client)
{
	if (IsValidClient(client))
	{
		// Make sure client is having a weapon, because plugin wont equip ammo for unexist weapon
		if (IsValidEntity(GetPlayerWeaponSlot(client, SLOT_PRIMARY)))
		{
			decl Float:vecOrigin[3]; GetClientEyePosition(client, vecOrigin);

			// When player just touched his own ammo box
			if (GetEntPropEnt(ammobox, Prop_Data, "m_hBreaker") == client && HasAmmoBox[client] == false)
			{
				RemoveEntity(ammobox);
				EmitAmbientSound(AmmoSound, vecOrigin, client);

				// Since owner touched his ammo box, equip it
				HasAmmoBox[client] = true;
				return Plugin_Handled;
			}

			new pickuprule = GetConVar[AmmoBox_PickupRule][Value];
			new clteam     = GetClientTeam(client);
			new ammoteam   = GetEntProp(ammobox, Prop_Send, "m_iTeamNum");

			// Check ammo box team, client team and perform touch/ammunition/whatever depends on their teams and pickup rule
			if ((pickuprule == allteams)
			||  (pickuprule == mates   && ammoteam == clteam)
			||  (pickuprule == enemies && ammoteam != clteam))
			{
#if defined REALISM
				if (!GetConVar[AmmoBox_ClipLimit][Value])
				{
#endif
					RemoveEntity(ammobox);

					// Emit sound on touch
					EmitAmbientSound(AmmoSound, vecOrigin, client);

					// Set ammunition mode to 'pickup'
					PerformAmmunition(client, ammotype:pickup);
					return Plugin_Handled;
#if defined REALISM
				}
				else
				{
					// Check for ammo limits
					if ((GetEntData(client, m_iAmmo + 16) < 56)  // Garand
					&&  (GetEntData(client, m_iAmmo + 20) < 35)  // K98 + scoped
					&&  (GetEntData(client, m_iAmmo + 28) < 35)  // Spring
					&&  (GetEntData(client, m_iAmmo + 32) < 210) // Thompson+MP40+MP44
					&&  (GetEntData(client, m_iAmmo + 36) < 140) // Bar
					&&  (GetEntData(client, m_iAmmo + 40) < 450) // 30cal
					&&  (GetEntData(client, m_iAmmo + 44) < 750) // MG42
					&&  (GetEntData(client, m_iAmmo + 48) < 5))  // Rocket
					{
						RemoveEntity(ammobox);
						EmitAmbientSound(AmmoSound, vecOrigin, client);
						PerformAmmunition(client, ammotype:pickup);
						return Plugin_Handled;
					}
					return Plugin_Handled;
				}
#endif
			}
		}
	}
	return Plugin_Handled;
}

/* SpawnAmmoBox()
 *
 * Spawns an ammobox in front of player.
 * ------------------------------------------------------------------------------------------------------ */
SpawnAmmoBox(ammobox, client, bool:IsAlivePlayer)
{
	// Make sure that weapon is valid
	if (IsValidEntity(GetPlayerWeaponSlot(client, SLOT_PRIMARY)))
	{
		// Set ammo box model and ammo box team depends on team
		switch (GetClientTeam(client))
		{
			case Allies: SetEntityModel(ammobox, AlliesAmmoModel);
			case Axis:   SetEntityModel(ammobox, AxisAmmoModel);
		}

		// Spawn ammo box, because entity just were created, but not yet spawned
		if (DispatchSpawn(ammobox))
		{
			SetEntProp(ammobox, Prop_Data, "m_iHammerID", Ammobox);

			// Use voice command if this feature is enabled
			if (GetConVar[AmmoBox_UseVoice][Value]) ClientCommand(client, "voice_takeammo");

			// Realism mode is enabled > reduce amount of ammo depends on clipsize value (drop mode)
			if (GetConVar[AmmoBox_Realism][Value]) PerformAmmunition(client, ammotype:drop);
			else if (IsAlivePlayer)                SetEntPropEnt(ammobox, Prop_Data, "m_hBreaker", client);

			HasAmmoBox[client] = false;
		}
	}
}

/* PerformAmmunition()
 *
 * Performs all ammunition stuff (ammo check, ammo dropping & touch)
 * ------------------------------------------------------------------------------------------------------ */
PerformAmmunition(client, ammotype:index)
{
	// Perform ammunition only for primary weapon
	new PrimaryWeapon = GetPlayerWeaponSlot(client, SLOT_PRIMARY);

	// Weapon is valid?
	if (IsValidEntity(PrimaryWeapon))
	{
		// Retrieve a weapon classname
		decl String:Weapon[MAX_WEAPON_LENGTH];
		GetEdictClassname(PrimaryWeapon, Weapon, sizeof(Weapon));

		// Prepare weapon id. Needed to find weapon, ammo & clipsize from tables
		new WeaponID = INVALID_ITEM;
		for (new i; i < sizeof(Weapons); i++)
		{
			// Skip the first 7 characters in weapon string to avoid comparing the "weapon_" prefix
			if (StrEqual(Weapon[7], Weapons[i]))
			{
				WeaponID = i;
				break;
			}
		}

		// When WeaponID is found from table >>
		if (WeaponID != INVALID_ITEM)
		{
			// Get ammo offset
			new WeaponAmmo = m_iAmmo + ammo_offset[WeaponID];

			// Get current amount of ammo using ammo offset
			new currammo   = GetEntData(client, WeaponAmmo);

			// Get clip size value
			new clipsize   = GetConVar[AmmoBox_ClipSize][Value];

			// Get max clipsize of weapon and multiply to clipsize value
			new newammo    = ammo_clipsize[WeaponID] * clipsize;

			// Get type of ammunition stuff
			switch (index)
			{
				// Checking current ammo size
				case check:
				{
					if (GetConVar[AmmoBox_Realism][Value])
					{
						// If ammo which should be dropped is more than current ammo, disable ammo dropping
						if (newammo > currammo) HasAmmoBox[client] = false;
						else                    HasAmmoBox[client] = true;
					}
				}
				case drop:   SetEntData(client, WeaponAmmo, currammo - newammo);
				case pickup: SetEntData(client, WeaponAmmo, currammo + newammo);
			}
		}
	}
}