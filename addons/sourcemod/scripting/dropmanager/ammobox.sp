// ====[ VARIABLES ]================================================================
enum ammotype
{
	check,
	drop,
	pickup
}

new Handle:lifetimer_ammo[MAXENTITIES + 1],
	AmmoBoxOwner[MAXENTITIES + 1],
	bool:HasAmmoBox[DOD_MAXPLAYERS + 1],
	ammo_offset[]   = { 16, 20, 32, 32, 36, 32, 28, 20,  40,  44, 48, 48},
	ammo_clipsize[] = { 8,   5, 30, 30, 20, 30,  5,  5, 150, 250, 1,   1},
	m_iAmmo;

new const
	String:AmmoSound[]       = { "items/ammo_pickup.wav" },
	String:AxisAmmoModel[]   = { "models/ammo/ammo_axis.mdl" },
	String:AlliesAmmoModel[] = { "models/ammo/ammo_us.mdl" },
	String:Weapons[][]       =
{
	"weapon_garand", "weapon_k98",        "weapon_thompson", "weapon_mp40", "weapon_bar",     "weapon_mp44",
	"weapon_spring", "weapon_k98_scoped", "weapon_30cal",    "weapon_mg42", "weapon_bazooka", "weapon_pschreck"
};

/* OnAmmoBoxTouched()
 *
 * When the ammo box is touched.
 * --------------------------------------------------------------------------------- */
public Action:OnAmmoBoxTouched(ammobox, client)
{
	if (IsValidClient(client) && IsValidEntity(ammobox))
	{
		// Make sure client is having a weapon, because we wont equip ammo for unexist weapon
		if (IsValidEntity(GetPlayerWeaponSlot(client, SLOT_PRIMARY)))
		{
			decl Float:vecOrigin[3]; GetClientEyePosition(client, vecOrigin);

			// When player just touched his own ammo box
			if (AmmoBoxOwner[ammobox] == client && HasAmmoBox[client] == false)
			{
				// Kill timer and remove ammo box model from ground
				KillAmmoBoxTimer(ammobox);
				RemoveAmmoBox(ammobox);

				EmitAmbientSound(AmmoSound, vecOrigin, client);

				// Since owner touched his ammo box, make sure he is having it right now
				HasAmmoBox[client] = true;
				return Plugin_Handled;
			}

			new pickuprule = GetConVar[AmmoBox_PickupRule][Value];
			new clteam     = GetClientTeam(client);
			new ammoteam   = GetEntProp(ammobox, Prop_Send, "m_nSkin");

			// Check ammo box team, client team and perform stuff (touch, ammunition etc) depends on their teams and pickup rule
			if ((pickuprule == 0)
			||  (pickuprule == 1 && ammoteam == clteam)
			||  (pickuprule == 2 && ammoteam != clteam))
			{
				KillAmmoBoxTimer(ammobox);
				RemoveAmmoBox(ammobox);

				// Play equip sound on touch
				EmitAmbientSound(AmmoSound, vecOrigin, client);

				// Set ammunition mode to 'pickup'
				PerformAmmunition(client, ammotype:pickup);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Handled;
}

/* SpawnAmmoBox()
 *
 * Spawns an ammobox in front of player.
 * --------------------------------------------------------------------------------- */
SpawnAmmoBox(ammobox, client)
{
	// Make sure that weapon is valid
	if (IsValidEntity(GetPlayerWeaponSlot(client, SLOT_PRIMARY)))
	{
		// Store origin, angles and velocity to spawn ammo box correctly in a front of player
		decl Float:origin[3], Float:angles[3], Float:velocity[3];
		GetClientAbsOrigin(client, origin);
		GetClientEyeAngles(client, angles);
		GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(velocity, velocity);

		// Scale vector to a given value
		ScaleVector(velocity, 350.0);

		// Set ammo box model and ammo box team depends on team
		switch (GetClientTeam(client))
		{
			case Allies:
			{
				DispatchKeyValue(ammobox, "model", AlliesAmmoModel);
				SetEntProp(ammobox, Prop_Send, "m_nSkin", Teams:Allies);
			}
			case Axis:
			{
				DispatchKeyValue(ammobox, "model", AxisAmmoModel);
				SetEntProp(ammobox, Prop_Send, "m_nSkin", Teams:Axis);
			}
		}

		// Spawn ammo box, because entity just were created, but not yet spawned
		if (DispatchSpawn(ammobox))
		{
			SetEntProp(ammobox, Prop_Send, "m_usSolidFlags",  152);
			SetEntProp(ammobox, Prop_Send, "m_CollisionGroup", 11);

			if (GetClientHealth(client) > 0)
			{
				origin[2] += 45.0;
				TeleportEntity(ammobox, origin, angles, velocity);
			}

			// Client is no longer alive
			else
			{
				// Then change value for origin and spawn ammo box just around a weapon
				origin[2] += 5.0;
				TeleportEntity(ammobox, origin, NULL_VECTOR, NULL_VECTOR);
			}

			// Hook entity touch (in our case is ammobox)
			CreateTimer(0.5, HookAmmoBoxTouch, ammobox);

			lifetimer_ammo[ammobox] = CreateTimer(GetConVar[ItemLifeTime][Value], RemoveDroppedAmmoBox, ammobox, TIMER_FLAG_NO_MAPCHANGE);

			// Use voice command if this feature is enabled
			if (GetConVar[AmmoBox_UseVoice][Value]) ClientCommand(client, "voice_takeammo");

			// Realism mode is enabled > recude amount of ammo depends on clipsize value (drop mode)
			if (GetConVar[AmmoBox_Realism][Value]) PerformAmmunition(client, ammotype:drop);
			else if (GetClientHealth(client) > 1)  AmmoBoxOwner[ammobox] = client;

			HasAmmoBox[client] = false;
		}
	}
}

/* HookAmmoBoxTouch()
 *
 * Makes ammo box able to be touched by player.
 * --------------------------------------------------------------------------------- */
public Action:HookAmmoBoxTouch(Handle:timer, any:ammobox)
{
	// Make sure ammo box entity is valid
	if (IsValidEntity(ammobox)) SDKHook(ammobox, SDKHook_Touch, OnAmmoBoxTouched);
}

/* RemoveDroppedAmmoBox()
 *
 * Removes dropped ammobox after X seconds on a map.
 * --------------------------------------------------------------------------------- */
public Action:RemoveDroppedAmmoBox(Handle:timer, any:ammobox)
{
	lifetimer_ammo[ammobox] = INVALID_HANDLE;

	// Timer is killed, so now we can easily remove model from world
	RemoveAmmoBox(ammobox);
}

/* RemoveAmmoBox()
 *
 * Fully removes an ammo box model from map.
 * --------------------------------------------------------------------------------- */
RemoveAmmoBox(ammobox)
{
	if (IsValidEntity(ammobox))
	{
		decl String:model[PLATFORM_MAX_PATH];
		Format(model, PLATFORM_MAX_PATH, NULL_STRING);
		GetEntPropString(ammobox, Prop_Data, "m_ModelName", model, PLATFORM_MAX_PATH);

		if (StrEqual(model, AxisAmmoModel) || StrEqual(model, AlliesAmmoModel))
			AcceptEntityInput(ammobox, "KillHierarchy");
	}
}

/* PerformAmmunition()
 *
 * Performs all ammunition stuff (ammo check, ammo dropping & touch)
 * --------------------------------------------------------------------------------- */
PerformAmmunition(client, ammotype:index)
{
	// Perform ammunition only for primary weapon
	new PrimaryWeapon = GetPlayerWeaponSlot(client, SLOT_PRIMARY);

	// Now make sure weapon is valid
	if (IsValidEntity(PrimaryWeapon))
	{
		// Retrieve a weapon classname
		decl String:Weapon[32]; GetEdictClassname(PrimaryWeapon, Weapon, sizeof(Weapon));

		// Prepare weapon id. Needed to find weapon, ammo & clipsize from string tables
		new WeaponID = -1;
		for (new i = 0; i < sizeof(Weapons); i++)
		{
			// Weapon found
			if (StrEqual(Weapon, Weapons[i]))
			{
				WeaponID = i;
			}
		}

		// If weaponID is found from table
		if (WeaponID != -1)
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
				case drop:   SetEntData(client, WeaponAmmo, currammo - newammo, 4, true);
				case pickup: SetEntData(client, WeaponAmmo, currammo + newammo, 4, true);
			}
		}
	}
}

/* KillAmmoBoxTimer()
 *
 * Fully closing timer that removing ammo box after X seconds.
 * --------------------------------------------------------------------------------- */
KillAmmoBoxTimer(ammobox)
{
	if (lifetimer_ammo[ammobox] != INVALID_HANDLE)
	{
		// Close timer handle
		CloseHandle(lifetimer_ammo[ammobox]);
	}
	lifetimer_ammo[ammobox] = INVALID_HANDLE;
}