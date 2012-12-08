// ====[ VARIABLES ]================================================================
new Handle:lifetimer_healthkit[MAXENTITIES + 1],
	Handle:allowhealthkit,
	Handle:healthkitrule,
	Handle:healthkithealth,
	//Handle:healthkitselfheal, //Uncomment this to enable selfheal feature
	Handle:healthkitteamcolor;

new bool:HasHealthkit[DOD_MAXPLAYERS + 1], HealthkitTeam[4] = { 0, 0, 2, 1 }, HealthkitOwner[MAXENTITIES + 1];
new const String:HealthkitModel[] = { "models/props_misc/ration_box01.mdl" }, String:HealthkitSound[] = { "object/object_taken.wav" };

/* OnHealthKitTouched()
 *
 * When the healthkit is touched.
 * --------------------------------------------------------------------------------- */
public Action:OnHealthKitTouched(healthkit, client)
{
	// Make sure client and healthkit is valid
	if (IsValidClient(client) && IsValidEntity(healthkit))
	{
		// When storing make sure you don't include the index then returns the client's eye position
		decl Float:vecOrigin[3];
		GetClientEyePosition(client, vecOrigin);

		// If healthkit's owner just touched healthkit (and had more health than defined in selfheal, equip healthkit back)
		if (HealthkitOwner[healthkit] == client/*  && GetClientHealth(client) >= GetConVarInt(healthkitselfheal) */)
		{
			KillHealthKitTimer(healthkit);
			RemoveHealthkit(healthkit);

			// Play a pickup sound around player on pickup
			EmitAmbientSound(HealthkitSound, vecOrigin, client, _, _, 1.0);

			HasHealthkit[client] = true;
			return Plugin_Handled;
		}

		// Gettin' values that needed for healthkit
		new health       = GetClientHealth(client);
		new healthkitadd = GetConVarInt(healthkithealth);
		new pickuprule   = GetConVarInt(healthkitrule);
		new clteam       = GetClientTeam(client);
		new kitteam      = GetEntProp(healthkit, Prop_Send, "m_nSkin");

		// Perform healing depends on pickup rule
		if ((pickuprule == 0)
		||  (pickuprule == 1 && kitteam == HealthkitTeam[clteam])
		||  (pickuprule == 2 && kitteam != HealthkitTeam[clteam]))
		{
			// Check if client's health is less than max health
			if (health < MAXHEALTH)
			{
				// If current client health + healthkit is more than 100, just give player full health
				if (health + healthkitadd > MAXHEALTH)
				{
					SetEntityHealth(client, MAXHEALTH);
					PrintCenterText(client, "%i hp", MAXHEALTH);
				}
				else
				{
					// Otherwise add healing value to current client health, and notice about that in middle of a screen
					SetEntityHealth(client, health + healthkitadd);
					PrintCenterText(client, "+%i hp", healthkitadd);
				}

				KillHealthKitTimer(healthkit);
				RemoveHealthkit(healthkit);

				EmitAmbientSound(HealthkitSound, vecOrigin, client, _, _, 1.0);
				return Plugin_Handled;
			}
			return Plugin_Handled;
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

/* RemoveDroppedHealthKit()
 *
 * Removes dropped healthkit after X seconds on a map.
 * --------------------------------------------------------------------------------- */
public Action:RemoveDroppedHealthKit(Handle:timer, any:healthkit)
{
	// Kill timer
	lifetimer_healthkit[healthkit] = INVALID_HANDLE;
	RemoveHealthkit(healthkit);
}

/* CreateHealthkit()
 *
 * Spawns a healthkit in front of player.
 * --------------------------------------------------------------------------------- */
CreateHealthkit(healthkit, client)
{
	// Needed to get team for pickuprule and colorize stuff
	new team = GetClientTeam(client);

	decl Float:origin[3], Float:angles[3], Float:velocity[3];
	GetClientAbsOrigin(client, origin);
	GetClientEyeAngles(client, angles);
	GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);

	// Normalize vector
	NormalizeVector(velocity, velocity);
	ScaleVector(velocity, 350.0);

	// Set healthkit model
	SetEntityModel(healthkit, HealthkitModel);
	SetEntProp(healthkit, Prop_Send, "m_nSkin", HealthkitTeam[team]);
	DispatchSpawn(healthkit);

	// If player is alive, teleport entity using stored origin, angles and velocity
	if (GetClientHealth(client) > 1)
	{
		origin[2] += 55.0;
		TeleportEntity(healthkit, origin, angles, velocity);

		// Make client as a dropped healthkit owner
		HealthkitOwner[healthkit] = client;

		// Also do a stuff that client dont have a healthkit anymore
		HasHealthkit[client]      = false;
	}
	else
	{
		origin[2] += 5.0;
		TeleportEntity(healthkit, origin, NULL_VECTOR, NULL_VECTOR);
	}

	// Colorize a healthkit depends on team if needed
	if (GetConVarBool(healthkitteamcolor))
	{
		switch (team)
		{
			case DODTeam_Allies: SetEntityRenderColor(healthkit, 128, 255, 128, 255);
			case DODTeam_Axis:   SetEntityRenderColor(healthkit, 255, 128, 128, 255);
		}
	}

	SDKHook(healthkit, SDKHook_Touch, OnHealthKitTouched);

	lifetimer_healthkit[healthkit] = CreateTimer(GetConVarFloat(itemlifetime), RemoveDroppedHealthKit, healthkit);
}

/* RemoveHealthkit()
 *
 * Fully removes a healthkit model from map.
 * --------------------------------------------------------------------------------- */
RemoveHealthkit(healthkit)
{
	// Healthkit is removed - unhook touch stuff
	SDKUnhook(healthkit, SDKHook_Touch, OnHealthKitTouched);

	if (IsValidEntity(healthkit)) AcceptEntityInput(healthkit, "Kill");
}

/* KillHealthKitTimer()
 *
 * Fully closing timer that removing healthkit after X seconds.
 * --------------------------------------------------------------------------------- */
KillHealthKitTimer(healthkit)
{
	// Check if timer is not yet killed, and then kill it
	if (lifetimer_healthkit[healthkit] != INVALID_HANDLE)
	{
		CloseHandle(lifetimer_healthkit[healthkit]);
	}
	lifetimer_healthkit[healthkit] = INVALID_HANDLE;
}