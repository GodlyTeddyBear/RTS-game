--!strict

--[[
	RemoteLotConfig — defines which zones live on the remote lot
	and the spawn offset for each player's remote lot area.

	Remote lots are placed in a grid on the remote terrain.
	Each player gets their own offset slot so lots don't overlap.

	Studio setup:
	  - Place the remote terrain area starting at RemoteLotOrigin
	  - Each player's remote lot template is cloned and positioned at
	    RemoteLotOrigin + (slotIndex * SlotStride) along the X axis
	  - The remote lot template lives at:
	    ReplicatedStorage/Assets/RemoteLots/Default/Model
	    with this structure:
	      Model/
	      ├── Base            ← anchor Part (same as village lot)
	      ├── Farm/
	      │   ├── BuildSlot_1
	      │   ├── BuildSlot_2
	      │   ├── BuildSlot_3
	      │   └── BuildSlot_4
	      ├── Garden/
	      │   ├── BuildSlot_1 → BuildSlot_4
	      ├── Forest/
	      │   ├── BuildSlot_1 → BuildSlot_3
	      └── Mines/
	          ├── BuildSlot_1 → BuildSlot_3
]]

return {
	-- World origin for the remote lot grid (set this to your remote terrain location)
	RemoteLotOrigin = CFrame.new(500, 80, 1000),

	-- How far apart each player's remote lot is along the X axis
	SlotStride = Vector3.new(300, 0, 0),

	-- Which zones live on the remote lot (must match folder names in the template)
	RemoteZones = { "Farm", "Garden", "Forest", "Mines" },
}
