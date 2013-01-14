// ====[ VARIABLES ]================================================================
new Handle:lifetimer_tnt[MAXENTITIES + 1],
	Handle:allowtnt,
	Handle:tntpickuprule,
	Handle:tntmaxdrops;

new bool:HasTNT[DOD_MAXPLAYERS + 1], BombsDropped[DOD_MAXPLAYERS + 1];
new const String:TNTModel[] = { "models/weapons/w_tnt.mdl" }, String:TNTSound[] = { "weapons/c4_pickup.wav" };

/* OnBombTouched()
 *
 * When the TNT bomb is touched.
 * --------------------------------------------------------------------------------- */
public Action:OnBombTouched(tnt, client)
{
	if (IsValidClient(client) && IsValidEntity(tnt))
	{
		decl Float:vecOrigin[3]; GetClientEyePosition(client, vecOrigin);

		// If player is dont have a bomb (weapon in 4th slot) - perform TNT equip
		if (!IsValidEntity(GetPlayerWeaponSlot(client, slot:Explosive)))
		{
			new pickuprule = GetConVarInt(tntpickuprule);
			new clteam     = GetClientTeam(client);
			new bombteam   = GetEntProp(tnt, Prop_Send, "m_nSkin");

			// Perform healing depends on pickup rule
			if ((pickuprule == 0)
			||  (pickuprule == 1 && bombteam == clteam)
			||  (pickuprule == 2 && bombteam != clteam))
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
	}
	return Plugin_Handled;
}

/* SpawnTNT()
 *
 * Spawns a TNT bomb in front of player.
 * --------------------------------------------------------------------------------- */
SpawnTNT(tnt, client)
{
	// Get bomb slot
	new bomb = GetPlayerWeaponSlot(client, slot:Explosive);

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
		ScaleVector(velocity, 370.0);

		// Set TNT model and spawn it
		DispatchKeyValue(tnt, "model", TNTModel);

		if (DispatchSpawn(tnt))
		{
			SetEntProp(tnt, Prop_Send, "m_nSkin", Teams:GetClientTeam(client));
			SetEntProp(tnt, Prop_Send, "m_usSolidFlags",  152);
			SetEntProp(tnt, Prop_Send, "m_CollisionGroup", 11);

			if (GetClientHealth(client) > 1 && BombsDropped[client] < GetConVarInt(tntmaxdrops))
			{
				origin[2] += 45.0;
				TeleportEntity(tnt, origin, angles, velocity);

				BombsDropped[client]++;
				RemoveWeapon(client, bomb);
			}
			else if (GetClientHealth(client) < 1)
			{
				origin[2] += 5.0;
				TeleportEntity(tnt, origin, NULL_VECTOR, NULL_VECTOR);
			}

			CreateTimer(0.5, HookBombTouch, tnt);

			// Create timer depends on lifetime value to remove bomb from map after X seconds
			lifetimer_tnt[tnt] = CreateTimer(GetConVarFloat(itemlifetime), RemoveDroppedTnT, tnt, TIMER_FLAG_NO_MAPCHANGE);
			HasTNT[client] = false;
		}
	}
}

/* HookBombTouch()
 *
 * Makes TNT able to be touched by player.
 * --------------------------------------------------------------------------------- */
public Action:HookBombTouch(Handle:timer, any:tnt)
{
	if (IsValidEntity(tnt)) SDKHook(tnt, SDKHook_Touch, OnBombTouched);
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
		// Removes this entity and all its children from the world
		decl String:model[PLATFORM_MAX_PATH];
		Format(model, PLATFORM_MAX_PATH, NULL_STRING);
		GetEntPropString(tnt, Prop_Data, "m_ModelName", model, PLATFORM_MAX_PATH);

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