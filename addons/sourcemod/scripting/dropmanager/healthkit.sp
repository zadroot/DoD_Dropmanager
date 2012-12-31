// ====[ VARIABLES ]================================================================
new Handle:lifetimer_healthkit[MAXENTITIES + 1],
	Handle:allowhealthkit,
	Handle:healthkitrule,
	Handle:healthkithealth,
	Handle:healthkitselfheal,
	Handle:healthkitteamcolor,
	Handle:healthkitcustom;

new bool:HasHealthkit[DOD_MAXPLAYERS + 1], HealthkitOwner[MAXENTITIES + 1];

new const
	String:HealthkitModel[]   = { "models/props_misc/ration_box01.mdl" },
	String:HealthkitModel2[]  = { "models/props_misc/ration_box02.mdl" },
	String:HealthkitSound[]   = { "object/object_taken.wav" },
	String:HealSound[]        = { "items/smallmedkit1.wav" },
	String:HealthkitFiles[][] =
{
	"models/props_misc/ration_box02.dx80.vtx",
	"models/props_misc/ration_box02.dx90.vtx",
	"models/props_misc/ration_box02.mdl",
	"models/props_misc/ration_box02.phy",
	"models/props_misc/ration_box02.sw.vtx",
	"models/props_misc/ration_box02.vvd",
	"materials/models/props_misc/ration_box02.vmt",
	"materials/models/props_misc/ration_box02.vtf",
	"materials/models/props_misc/ration_box02_ger.vmt",
	"materials/models/props_misc/ration_box02_ger.vtf"
};

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

		// If healthkit's owner just touched healthkit (and had more health than defined in selfheal) equip healthkit back
		if (HealthkitOwner[healthkit] == client && GetClientHealth(client) > GetConVarInt(healthkitselfheal))
		{
			if (HasHealthkit[client] == false)
			{
				KillHealthKitTimer(healthkit);
				RemoveHealthkit(healthkit);

				// Play a pickup sound around player on pickup
				EmitAmbientSound(HealthkitSound, vecOrigin, client);

				HasHealthkit[client] = true;
				return Plugin_Handled;
			}
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
		||  (pickuprule == 1 && kitteam == clteam)
		||  (pickuprule == 2 && kitteam != clteam))
		{
			// Check if client's health is less than max health
			if (health < MAXHEALTH)
			{
				// If current client health + healthkit is more than 100, just give player full health
				if (health + healthkitadd >= MAXHEALTH)
				{
					SetEntityHealth(client, MAXHEALTH);
					PrintCenterText(client, "100 hp");
				}
				else
				{
					// Otherwise add healing value to current client health, and notice about that in middle of a screen
					SetEntityHealth(client, health + healthkitadd);
					PrintCenterText(client, "+%i hp", healthkitadd);
				}

				KillHealthKitTimer(healthkit);
				RemoveHealthkit(healthkit);

				EmitAmbientSound(HealSound, vecOrigin, client);
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

/* SpawnHealthkit()
 *
 * Spawns a healthkit in front of player.
 * --------------------------------------------------------------------------------- */
SpawnHealthkit(healthkit, client)
{
	// Needed to get team for pickuprule and colorize stuff
	new team = GetClientTeam(client);

	decl Float:origin[3], Float:angles[3], Float:velocity[3];
	GetClientAbsOrigin(client, origin);
	GetClientEyeAngles(client, angles);
	GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);

	// Normalize vector
	NormalizeVector(velocity, velocity);
	ScaleVector(velocity, 450.0);

	// Set healthkit model
	if (GetConVarBool(healthkitcustom))
		 DispatchKeyValue(healthkit, "model", HealthkitModel2);
	else DispatchKeyValue(healthkit, "model", HealthkitModel);

	if (DispatchSpawn(healthkit))
	{
		SetEntProp(healthkit, Prop_Send, "m_nSkin", team);
		SetEntProp(healthkit, Prop_Send, "m_usSolidFlags",  152);
		SetEntProp(healthkit, Prop_Send, "m_CollisionGroup", 11);
	}

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

	CreateTimer(0.5, HookHealthKitTouch, healthkit);

	lifetimer_healthkit[healthkit] = CreateTimer(GetConVarFloat(itemlifetime), RemoveDroppedHealthKit, healthkit);
}

/* HookHealthKitTouch()
 *
 * Makes healthkit able to be touched by player.
 * --------------------------------------------------------------------------------- */
public Action:HookHealthKitTouch(Handle:timer, any:healthkit)
{
	if (IsValidEntity(healthkit))
	{
		// Change to proper collision group for making healthkit pickup'ble
		SDKHook(healthkit, SDKHook_StartTouch, OnHealthKitTouched);
	}
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

/* RemoveHealthkit()
 *
 * Fully removes a healthkit model from map.
 * --------------------------------------------------------------------------------- */
RemoveHealthkit(healthkit)
{
	if (IsValidEntity(healthkit))
	{
		// Entity removed - unhook touching
		SDKUnhook(healthkit, SDKHook_StartTouch, OnHealthKitTouched);

		decl String:model[PLATFORM_MAX_PATH];
		Format(model, PLATFORM_MAX_PATH, NULL_STRING);
		GetEntPropString(healthkit, Prop_Data, "m_ModelName", model, PLATFORM_MAX_PATH);

		if (StrEqual(model, HealthkitModel) || StrEqual(model, HealthkitModel2))
			AcceptEntityInput(healthkit, "KillHierarchy");
	}
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