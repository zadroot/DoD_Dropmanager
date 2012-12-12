// ====[ VARIABLES ]================================================================
enum ammotype
{
	check,
	drop,
	pickup
}

new Handle:lifetimer_ammo[MAXENTITIES + 1],
	Handle:allowammobox,
	Handle:ammopickuprule,
	Handle:ammosize,
	Handle:ammorealism,
	Handle:ammovoice;

new bool:HasAmmoBox[DOD_MAXPLAYERS + 1],
	ammo_offset[]   = { 16, 20, 32, 32, 36, 32, 28, 20,  40,  44, 48, 48},
	ammo_clipsize[] = { 8,   5, 30, 30, 20, 30,  5,  5, 150, 250, 1,   1},
	AmmoBoxTeam[4]  = { 0, 0, 2, 1 },
	AmmoBoxOwner[MAXENTITIES + 1],
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
		decl Float:vecOrigin[3];
		GetClientEyePosition(client, vecOrigin);

		// Make sure client is having a weapon, because we wont equip ammo for unexist weapon
		if (GetPlayerWeaponSlot(client, Slot_Primary) != -1)
		{
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

			new pickuprule = GetConVarInt(ammopickuprule);
			new clteam     = GetClientTeam(client);
			new ammoteam   = GetEntProp(ammobox, Prop_Send, "m_nSkin");

			// Check ammo box team, client team and perform stuff (touch, ammunition etc) depends on their teams and pickup rule
			if ((pickuprule == 0)
			||  (pickuprule == 1 && ammoteam == AmmoBoxTeam[clteam])
			||  (pickuprule == 2 && ammoteam != AmmoBoxTeam[clteam]))
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

/* CreateAmmoBox()
 *
 * Spawns an ammobox in front of player.
 * --------------------------------------------------------------------------------- */
CreateAmmoBox(ammobox, client)
{
	// Make sure that weapon is valid
	if (GetPlayerWeaponSlot(client, Slot_Primary) != -1)
	{
		new team = GetClientTeam(client);

		// Store origin, angles and velocity to spawn ammo box correctly in a front of player
		decl Float:origin[3], Float:angles[3], Float:velocity[3];
		GetClientAbsOrigin(client, origin);
		GetClientEyeAngles(client, angles);
		GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(velocity, velocity);

		// Scale vector to a given value
		ScaleVector(velocity, 400.0);

		// Set ammo box model and ammo box team depends on team
		switch (team)
		{
			case DODTeam_Allies:
			{
				SetEntProp(ammobox, Prop_Send, "m_nSkin", AmmoBoxTeam[DODTeam_Allies]);
				DispatchKeyValue(ammobox, "model", AlliesAmmoModel);
			}
			case DODTeam_Axis:
			{
				SetEntProp(ammobox, Prop_Send, "m_nSkin", AmmoBoxTeam[DODTeam_Axis]);
				DispatchKeyValue(ammobox, "model", AxisAmmoModel);
			}
		}

		// Spawn ammo box, because entity just were created, but not yet spawned
		DispatchSpawn(ammobox);

		if (GetClientHealth(client) > 1)
		{
			origin[2] += 55.0;
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

		lifetimer_ammo[ammobox] = CreateTimer(GetConVarFloat(itemlifetime), RemoveDroppedAmmoBox, ammobox, TIMER_FLAG_NO_MAPCHANGE);

		// Use voice command if this feature is enabled
		if (GetConVarBool(ammovoice)) ClientCommand(client, "voice_takeammo");

		// Realism mode is enabled > recude amount of ammo depends on clipsize value (drop mode)
		if (GetConVarBool(ammorealism))
		{
			PerformAmmunition(client, ammotype:drop);
			HasAmmoBox[client] = false;
		}

		// Realism mode is disabled AND player is still alive
		else if (GetClientHealth(client) > 1)
		{
			// Because I want to give more ammo on pickup own ammo box after death
			AmmoBoxOwner[ammobox] = client;
			HasAmmoBox[client]    = false;
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
	if (IsValidEntity(ammobox))
	{
		SetEntProp(ammobox, Prop_Send, "m_CollisionGroup", COLLISIONGROUP);

		// Possibly memory leak issue should be corrected in the OnStartTouch entity hook
		SDKHook(ammobox, SDKHook_StartTouch, OnAmmoBoxTouched);
	}
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
		SDKUnhook(ammobox, SDKHook_StartTouch, OnAmmoBoxTouched);

		decl String:model[PLATFORM_MAX_PATH];
		Format(model, PLATFORM_MAX_PATH, NULL_STRING);
		GetEntPropString(ammobox,  Prop_Data, "m_ModelName", model, PLATFORM_MAX_PATH);

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
	new PrimaryWeapon = GetPlayerWeaponSlot(client, Slot_Primary);

	// Now make sure weapon is valid
	if (IsValidEntity(PrimaryWeapon))
	{
		// Retrieve a weapon classname
		decl String:Weapon[32];
		GetEdictClassname(PrimaryWeapon, Weapon, sizeof(Weapon));

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
			new clipsize   = GetConVarInt(ammosize);

			// Get max clipsize of weapon and multiply to clipsize value
			new newammo    = ammo_clipsize[WeaponID] * clipsize;

			// Get type of ammunition stuff
			switch (index)
			{
				// Checking current ammo size
				case check:
				{
					// If ammo which should be dropped is more than current ammo, disable ammo dropping
					if (newammo > currammo) HasAmmoBox[client] = false;

					// Otherwise if its a realism mode, enable dropping again
					else if (GetConVarBool(ammorealism)) HasAmmoBox[client] = true;
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