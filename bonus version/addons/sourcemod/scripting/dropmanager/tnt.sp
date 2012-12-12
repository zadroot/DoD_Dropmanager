// ====[ VARIABLES ]================================================================
new Handle:lifetimer_tnt[MAXENTITIES + 1], Handle:allowtnt;
new bool:HasTNT[DOD_MAXPLAYERS + 1];
new const String:TNTModel[] = { "models/weapons/w_tnt.mdl" }, String:TNTSound[] = { "weapons/c4_pickup.wav" };

/* OnBombTouched()
 *
 * When the TNT bomb is touched.
 * --------------------------------------------------------------------------------- */
public Action:OnBombTouched(tnt, client)
{
	if (IsValidClient(client) && IsValidEntity(tnt))
	{
		decl Float:vecOrigin[3];
		GetClientEyePosition(client, vecOrigin);

		// If player is dont have a bomb (weapon in 4th slot) - perform TNT equip
		if (GetPlayerWeaponSlot(client, Slot_Bomb) == -1)
		{
			// Just give bomb to a client
			GivePlayerItem(client, "weapon_basebomb");

			// Kill timer and remove bomb from map
			KillBombTimer(tnt);
			RemoveTNT(tnt);

			// Play specified TNT touch sound
			EmitAmbientSound(TNTSound, vecOrigin, client);

			// Client has a TNT right now
			HasTNT[client] = true;
		}
	}
	return Plugin_Handled;
}

/* CreateTNT()
 *
 * Spawns a TNT bomb in front of player.
 * --------------------------------------------------------------------------------- */
CreateTNT(tnt, client)
{
	// Get bomb slot
	new bomb = GetPlayerWeaponSlot(client, Slot_Bomb);

	if (IsValidEntity(bomb))
	{
		decl Float:origin[3], Float:angles[3], Float:velocity[3];

		// Get client origin vector
		GetClientAbsOrigin(client, origin);

		// Get client eye angles (not direction player looking)
		GetClientEyeAngles(client, angles);

		// Get vectors in the direction of an angle
		GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);

		NormalizeVector(velocity, velocity);
		ScaleVector(velocity, 400.0);

		// Set TNT model and spawn it
		DispatchKeyValue(tnt, "model", TNTModel);
		DispatchSpawn(tnt);

		if (GetClientHealth(client) > 1)
		{
			origin[2] += 55.0;
			TeleportEntity(tnt, origin, angles, velocity);

			// No need to remove bomb from dead player
			RemoveWeapon(client, bomb);
		}
		else
		{
			origin[2] += 5.0;
			TeleportEntity(tnt, origin, NULL_VECTOR, NULL_VECTOR);
		}

		CreateTimer(0.5, HookBombTouch, tnt);

		// Create timer depends on lifetime value to remove bomb from map after X seconds
		lifetimer_tnt[tnt] = CreateTimer(GetConVarFloat(itemlifetime), RemoveDroppedTnT, tnt, TIMER_FLAG_NO_MAPCHANGE);
	}

	// Client is no longer have tnt
	HasTNT[client] = false;
}

/* HookBombTouch()
 *
 * Makes TNT able to be touched by player.
 * --------------------------------------------------------------------------------- */
public Action:HookBombTouch(Handle:timer, any:tnt)
{
	if (IsValidEntity(tnt))
	{
		SetEntProp(tnt, Prop_Send, "m_CollisionGroup", COLLISIONGROUP);
		SDKHook(tnt, SDKHook_StartTouch, OnBombTouched);
	}
}

/* RemoveDroppedTnT()
 *
 * Removes dropped TNT after X seconds on a map.
 * --------------------------------------------------------------------------------- */
public Action:RemoveDroppedTnT(Handle:timer, any:tnt)
{
	lifetimer_tnt[tnt] = INVALID_HANDLE;
	RemoveTNT(tnt);
}

/* RemoveTNT()
 *
 * Fully removes a TNT model from map.
 * --------------------------------------------------------------------------------- */
RemoveTNT(tnt)
{
	// Make sure that entity is valid
	if (IsValidEntity(tnt))
	{
		SDKUnhook(tnt, SDKHook_StartTouch, OnBombTouched);

		// Removes this entity and all its children from the world
		decl String:model[PLATFORM_MAX_PATH];
		Format(model, PLATFORM_MAX_PATH, NULL_STRING);
		GetEntPropString(tnt,  Prop_Data, "m_ModelName", model, PLATFORM_MAX_PATH);

		if (StrEqual(model, TNTModel)) AcceptEntityInput(tnt, "KillHierarchy");
	}
}

/* RemoveWeapon()
 *
 * Removes weapon (bomb) from player's slot.
 * --------------------------------------------------------------------------------- */
RemoveWeapon(client, bomb)
{
	// Remove bomb from slot
	RemovePlayerItem(client, bomb);

	// Because RemoveEdict isn't safe to use at all
	AcceptEntityInput(bomb, "Kill");
}

/* KillBombTimer()
 *
 * Fully closing timer that removing TNT after X seconds.
 * --------------------------------------------------------------------------------- */
KillBombTimer(tnt)
{
	if (lifetimer_tnt[tnt] != INVALID_HANDLE)
	{
		CloseHandle(lifetimer_tnt[tnt]);
	}

	// Make sure life timer for tnt is invalid now
	lifetimer_tnt[tnt] = INVALID_HANDLE;
}