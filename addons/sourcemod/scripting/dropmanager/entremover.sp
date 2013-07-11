/**
 * ------------------------------------------------------------------------------------------------------
 *    _______
 *   /_  __(_)____ ___  ___  _____
 *    / / / // __ `__ \/ _ \/ ___/
 *   / / / // / / / / /  __/ /
 *  /_/ /_//_/ /_/ /_/\___/_/
 *
 * ------------------------------------------------------------------------------------------------------
*/

enum
{
	DropEntInfo_EntRef,		// Entity reference of the drop entity
	DropEntInfo_TimeAdded,	// Timestamp when the entity was added

	DropEntInfo_Size
};

new Handle:DropEntsArray;

/* DropEntRemover_AddDropEnt()
 *
 * Adds dropped item to the removing queue.
 * ------------------------------------------------------------------------------------------------------ */
DropEntRemover_AddDropEnt(entity)
{
	new any:dropEntInfo[DropEntInfo_Size];

	// Convert entity index to reference, because we're going to use timer
	dropEntInfo[DropEntInfo_EntRef]    = EntIndexToEntRef(entity);

	// Save timestamp when entity was removed
	dropEntInfo[DropEntInfo_TimeAdded] = any:GetGameTime();

	// Push entity reference to queue
	PushArrayArray(DropEntsArray, dropEntInfo, DropEntInfo_Size);
}

/* DropEntRemover_AddDropEnt()
 *
 * Adds dropped item to the removing queue.
 * ------------------------------------------------------------------------------------------------------ */
public Action:DropEntRemover_Think(Handle:timer)
{
	// Get all dropped items
	new size = GetArraySize(DropEntsArray);

	// Make sure array isnt empty
	if (size != 0)
	{
		// Loop through all items in array
		for (new i = 0; i < size; i++)
		{
			// Convert entity reference to entity index back, because we're going to remove this
			new entity = EntRefToEntIndex(GetArrayCell(DropEntsArray, i, DropEntInfo_EntRef));

			// Make sure converted entity is valid
			if (entity != INVALID_ENT_REFERENCE)
			{
				// Retrieves a cell value from an array, because entity index is integer (I guess)
				new Float:timeAdded = GetArrayCell(DropEntsArray, i, DropEntInfo_TimeAdded);

				// When time is expired
				if (GetGameTime() - timeAdded >= GetConVar[ItemLifeTime][Value])
				{
					// Removes this entity and all its children from the world
					RemoveEntity(entity);

					// Its pointless now
					RemoveFromArray(DropEntsArray, i);
					size--;
				}
			}

			// If not, just remove it
			else
			{
				RemoveFromArray(DropEntsArray, i);

				// Hotfix
				size--;
			}
		}
	}
}