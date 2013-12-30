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

new	bool:HasHealthkit[DOD_MAXPLAYERS + 1];
new	const
	String:HealthkitModel[]   = { "models/props_misc/ration_box01.mdl" },
	String:HealthkitModel2[]  = { "models/props_misc/ration_box02.mdl" },
	String:HealthkitSound[]   = { "object/object_taken.wav" },
#if !defined REALISM
	String:HealSound[]        = { "items/smallmedkit1.wav" },
#endif
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
 * ------------------------------------------------------------------------------------------------------ */
public Action:OnHealthKitTouched(healthkit, client)
{
	// Make sure client is valid
	if (IsValidClient(client))
	{
		// When storing make sure you don't include the index then returns the client's eye position
		decl Float:vecOrigin[3]; GetClientEyePosition(client, vecOrigin);

		new health = GetClientHealth(client);

		// If healthkit's owner just touched healthkit (and had more health than defined in selfheal) equip healthkit back
		if (GetEntPropEnt(healthkit, Prop_Data, "m_hBreaker") == client
		&&  health > GetConVar[Healthkit_SelfHeal][Value]
		&&  HasHealthkit[client] == false)
		{
			// Kill it from world
			RemoveEntity(healthkit);

			EmitAmbientSound(HealthkitSound, vecOrigin, client);

			HasHealthkit[client] = true;
			return Plugin_Handled;
		}

		// Get the values that needed for healthkit
		new healthkitadd = GetConVar[Healthkit_AddHealth][Value];
		new pickuprule   = GetConVar[Healthkit_PickupRule][Value];
		new clteam       = GetClientTeam(client);
		new kitteam      = GetEntProp(healthkit, Prop_Send, "m_iTeamNum");

		// Perform healing depends on pickup rule
		if ((pickuprule == allteams)
		||  (pickuprule == mates   && kitteam == clteam)
		||  (pickuprule == enemies && kitteam != clteam))
		{
			// Check if client's health is less than max health
			if (health < MAXHEALTH)
			{
				// Kill it immediately (fix for 'infinite heal')
				RemoveEntity(healthkit);
#if defined REALISM
				EmitAmbientSound(HealthkitSound, vecOrigin, client);
#else
				// Emit heal sound on normal dropmanager, but dont make any noice in realism!
				EmitAmbientSound(HealSound, vecOrigin, client);
#endif
				// If current client health + healthkit is more than 100, just give player full health
				if (health + healthkitadd >= MAXHEALTH)
				{
					SetEntityHealth(client, MAXHEALTH);
					PrintCenterText(client, "%t", "Full hp");
				}
				else
				{
					// Otherwise add healing value to current client health, and notice about that in middle of a screen
					SetEntityHealth(client,  health + healthkitadd);
					PrintCenterText(client, "+%i hp", healthkitadd);
				}
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Handled;
}

/* SpawnHealthkit()
 *
 * Spawns a healthkit in front of player.
 * ------------------------------------------------------------------------------------------------------ */
SpawnHealthkit(healthkit, client, bool:IsAlivePlayer)
{
	// Set healthkit model
	if (GetConVar[Healthkit_NewModel][Value])
		 SetEntityModel(healthkit, HealthkitModel2);
	else SetEntityModel(healthkit, HealthkitModel);

	if (DispatchSpawn(healthkit))
	{
		if (IsAlivePlayer)
		{
			// Make client as a dropped healthkit owner
			SetEntPropEnt(healthkit, Prop_Data, "m_hBreaker", client);

			// Also do a stuff that client dont have a healthkit anymore
			HasHealthkit[client] = false;
		}

		SetEntProp(healthkit, Prop_Data, "m_iHammerID", Healthkit);

		// Colorize a healthkit depends on team if needed
		if (GetConVar[Healthkit_TeamColor][Value])
		{
			switch (GetClientTeam(client))
			{
				case Allies: SetEntityRenderColor(healthkit, 128, 255, 128, 255);
				case Axis:   SetEntityRenderColor(healthkit, 255, 128, 128, 255);
			}
		}
	}
}