-- TidyConfig (ModuleScript)
-- Emplacement : ReplicatedStorage
-- Réglages partagés par le serveur (TidyManager, AgencyBuilder) et le joueur (TidyUI).
-- Tous les textes du jeu visibles par le joueur sont en français.

local TidyConfig = {}

-- Nom de l'agence fictive, affiché sur les panneaux et dans l'interface.
TidyConfig.AgencyName = "Agence pour l'emploi de Valmont"

-- Chaque type d'objet que le joueur peut ranger.
-- DisplayName : nom affiché au-dessus de l'objet.
-- PlaceName   : nom affiché au-dessus de l'emplacement où il va.
-- Hint        : consigne affichée pendant que le joueur porte l'objet.
-- CarryOffset : position de l'objet porté, par rapport au corps du joueur.
TidyConfig.ItemTypes = {
	Folder = {
		DisplayName = "Dossier",
		PlaceName = "Étagère des dossiers",
		Hint = "Rangez-le sur l'étagère des dossiers, contre le mur du fond.",
		CarryOffset = CFrame.new(0, 0, -1.6),
	},
	Paper = {
		DisplayName = "Pile de papiers",
		PlaceName = "Bac à documents",
		Hint = "Rangez-la dans un bac à documents vide, sur un bureau.",
		CarryOffset = CFrame.new(0, 0, -1.6),
	},
	Chair = {
		DisplayName = "Chaise",
		PlaceName = "Salle d'attente",
		Hint = "Remettez-la dans la salle d'attente, face à l'écran.",
		CarryOffset = CFrame.new(0, 0.3, -2.4),
	},
	Box = {
		DisplayName = "Carton",
		PlaceName = "Étagère de la réserve",
		Hint = "Rangez-le sur une étagère de la réserve.",
		CarryOffset = CFrame.new(0, 0.2, -2),
	},
}

-- Textes des boutons d'action affichés au-dessus des objets et des emplacements.
TidyConfig.PickupText = "Ramasser"
TidyConfig.PutAwayText = "Ranger"

-- Distance maximale (en studs) pour ramasser ou ranger un objet.
TidyConfig.MaxDistance = 8

-- Marge supplémentaire utilisée par le serveur quand il revérifie la distance.
TidyConfig.ServerDistanceMargin = 6

-- Noms partagés entre les scripts. Ne les changez pas, sauf partout à la fois.
TidyConfig.ItemTag = "TidyItem"
TidyConfig.SlotTag = "TidySlot"

return TidyConfig
