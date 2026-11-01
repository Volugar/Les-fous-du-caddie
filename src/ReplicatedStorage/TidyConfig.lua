-- TidyConfig (ModuleScript)
-- Location: ReplicatedStorage
-- Shared settings used by the server (TidyManager, AgencyBuilder) and the client (TidyUI).

local TidyConfig = {}

-- Name of the fictional agency, shown on signs and in the interface.
TidyConfig.AgencyName = "Northfield Employment Agency"

-- Every kind of object the player can tidy up.
-- DisplayName : name shown above the object.
-- PlaceName   : name shown above the spot where it belongs.
-- Hint        : instruction shown while the player carries the object.
-- CarryOffset : where the object is held, relative to the player's body.
TidyConfig.ItemTypes = {
	Folder = {
		DisplayName = "Case Folder",
		PlaceName = "Archive Shelf",
		Hint = "Put it on the archive shelf against the back wall.",
		CarryOffset = CFrame.new(0, 0, -1.6),
	},
	Paper = {
		DisplayName = "Stack of Papers",
		PlaceName = "Document Tray",
		Hint = "Put it in an empty document tray on a desk.",
		CarryOffset = CFrame.new(0, 0, -1.6),
	},
	Chair = {
		DisplayName = "Chair",
		PlaceName = "Waiting Area",
		Hint = "Put it back in the waiting area, facing the screen.",
		CarryOffset = CFrame.new(0, 0.3, -2.4),
	},
	Box = {
		DisplayName = "Cardboard Box",
		PlaceName = "Storage Shelf",
		Hint = "Put it on a shelf in the storage room.",
		CarryOffset = CFrame.new(0, 0.2, -2),
	},
}

-- How close (in studs) the player must be to pick up or put away an object.
TidyConfig.MaxDistance = 8

-- Extra tolerance used by the server when it double-checks the distance.
TidyConfig.ServerDistanceMargin = 6

-- Names shared between scripts. Do not change unless you change them everywhere.
TidyConfig.ItemTag = "TidyItem"
TidyConfig.SlotTag = "TidySlot"

return TidyConfig
