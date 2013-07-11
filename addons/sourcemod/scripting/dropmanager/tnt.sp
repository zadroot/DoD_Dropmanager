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

new	BombsDropped[DOD_MAXPLAYERS + 1], bool:HasTNT[DOD_MAXPLAYERS + 1];
new	const String:TNTModel[] = { "models/weapons/w_tnt.mdl" }, String:TNTSound[] = { "weapons/c4_pickup.wav" };

/* OnBombTouched()
 *
 * When the TNT bomb is touched.
 * ------------------------------------------------------------------------------------------------------ */
public OnBombTouched(tnt, client)
{
	if (IsValidClient(client))
	{
		// If player is dont have a bomb (weapon in 4th slot) - perform TNT equip
		if (!IsValidEntity(GetPlayerWeaponSlot(client, SLOT_EXPLOSIVE)))
		{
			new pickuprule = GetConVar[TNT_PickupRule][Value];
			new clteam     = GetClientTeam(client);
			new bombteam   = GetEntProp(tnt, Prop_Send, "m_iTeamNum");

			// Perform healing depends on pickup rule
			if ((pickuprule == allteams)
			||  (pickuprule == mates   && bombteam == clteam)
			||  (pickuprule == enemies && bombteam != clteam))
			{
				decl Float:vecOrigin[3]; GetClientEyePosition(client, vecOrigin);

				// Remove explosive
				RemoveEntity(tnt);

				// Play specified TNT touch sound
				EmitAmbientSound(TNTSound, vecOrigin, client);

				// Just give bomb to a client
				GivePlayerItem(client, "weapon_basebomb");
			}
		}
	}
}

/* SpawnTNT()
 *
 * Spawns a TNT bomb in front of player.
 * ------------------------------------------------------------------------------------------------------ */
SpawnTNT(tnt, client, bool:IsAlivePlayer)
{
	// Get bomb slot
	new bomb = GetPlayerWeaponSlot(client, SLOT_EXPLOSIVE);

	if (IsValidEntity(bomb))
	{
		// Set TNT model and spawn it
		SetEntityModel(tnt, TNTModel);

		if (DispatchSpawn(tnt))
		{
			if (IsAlivePlayer)
			{
				// Increase amount of dropped bombs
				BombsDropped[client]++;

				// And properly remove player's weapon after dropping bomb
				RemoveWeapon(client, bomb);
			}

			SetEntProp(tnt, Prop_Data, "m_iHammerID", Bomb);

			// Create timer depends on lifetime value to remove bomb from map after X seconds
			HasTNT[client] = false;
		}
	}
}