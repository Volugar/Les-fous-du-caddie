-- TidyConfig (ModuleScript)
-- Emplacement : ReplicatedStorage
-- Réglages partagés par le serveur (TidyManager, AgencyBuilder) et le joueur (TidyUI).
-- Tous les textes vus par le joueur sont en anglais.

local TidyConfig = {}

-- Nom du jeu (affiché dans le hall d'accueil) et nom de l'agence (premier niveau).
TidyConfig.GameTitle = "Tidy Up! Workplace Chaos"
TidyConfig.AgencyName = "Northfield Employment Agency"

---------------------------------------------------------------------------
-- Objets
---------------------------------------------------------------------------
-- DisplayName : nom d'un objet.          Plural : nom au pluriel (compteurs).
-- Section     : rayon / catégorie affiché sur la carte de l'objet en main.
-- Variants    : noms précis possibles (affichés sur la carte de l'objet).
-- PlaceName   : nom du meuble où il se range.   Hint : consigne quand il est en main.
-- Points      : points gagnés en le rangeant.   Icon : petit symbole de l'interface.
-- Height      : hauteur de l'objet debout (pour empiler les objets portés).
TidyConfig.ItemTypes = {
	Folder = {
		DisplayName = "Case Folder", Plural = "Case Folders", Section = "Office Supplies",
		Variants = { "Case Folder", "Client File", "Archive Folder", "Job Seeker File" },
		PlaceName = "Archive Shelf", Hint = "Follow the signs to an Archive Shelf.", Points = 10, Icon = "📁", Height = 0.3,
	},
	Paper = {
		DisplayName = "Stack of Papers", Plural = "Paper Stacks", Section = "Office Supplies",
		Variants = { "Stack of Papers", "Application Forms", "Printed Reports", "Meeting Notes" },
		PlaceName = "Document Tray", Hint = "Put it in a Document Tray (desks, counters, printers).", Points = 10, Icon = "📄", Height = 0.35,
	},
	Chair = {
		DisplayName = "Chair", Plural = "Chairs", Section = "Furniture",
		Variants = { "Office Chair", "Visitor Chair", "Meeting Chair" },
		PlaceName = "Chair Spot", Hint = "Put it back in a free Chair Spot (green outline).", Points = 20, Icon = "🪑", Height = 4,
	},
	Box = {
		DisplayName = "Cardboard Box", Plural = "Boxes", Section = "Storage",
		Variants = { "Cardboard Box", "Supply Box", "Moving Box", "Archive Box" },
		PlaceName = "Storage Shelf", Hint = "Follow the signs to a Storage Shelf.", Points = 15, Icon = "📦", Height = 1.6,
	},
	Mug = {
		DisplayName = "Mug", Plural = "Mugs", Section = "Kitchen",
		Variants = { "Coffee Mug", "Tea Cup", "Office Mug", "\"World's Best Boss\" Mug" },
		PlaceName = "Cupboard", Hint = "Put it in a Cupboard (break room, café).", Points = 10, Icon = "☕", Height = 0.6,
	},
	Plant = {
		DisplayName = "Potted Plant", Plural = "Plants", Section = "Decor",
		Variants = { "Potted Plant", "Fern", "Rubber Plant", "Little Succulent" },
		PlaceName = "Planter", Hint = "Put it on a Planter.", Points = 15, Icon = "🪴", Height = 1.9,
	},
	Book = {
		DisplayName = "Book", Plural = "Books", Section = "Library",
		Variants = { "Book", "Guide", "Handbook", "Workbook" },
		PlaceName = "Bookcase", Hint = "Put it on the Bookcase with the same colored label.", Points = 8, Icon = "📘", Height = 1.1,
	},
	Parcel = {
		DisplayName = "Parcel", Plural = "Parcels", Section = "Mail & Shipping",
		Variants = { "Parcel", "Small Package", "Express Parcel", "Padded Parcel" },
		PlaceName = "Parcel Shelf", Hint = "Put it on the shelf with the same colored label.", Points = 12, Icon = "📮", Height = 0.6,
	},
	Laptop = {
		DisplayName = "Laptop", Plural = "Laptops", Section = "IT Equipment",
		Variants = { "Laptop", "Work Laptop", "Ultrabook" },
		PlaceName = "Charging Cart", Hint = "Put it in a Charging Cart.", Points = 12, Icon = "💻", Height = 0.15,
	},
	Cushion = {
		DisplayName = "Cushion", Plural = "Cushions", Section = "Furniture",
		Variants = { "Cushion", "Sofa Pillow", "Velvet Cushion" },
		PlaceName = "Sofa", Hint = "Put it back on a Sofa.", Points = 8, Icon = "🛋️", Height = 0.45,
	},
	ShoeBox = {
		DisplayName = "Shoe Box", Plural = "Shoe Boxes", Section = "Footwear",
		Variants = { "Running Shoes", "Sneakers", "Leather Boots", "Sandals", "Kids' Shoes", "Hiking Boots" },
		PlaceName = "Footwear Rack", Hint = "Follow the hanging signs to the FOOTWEAR racks.", Points = 10, Icon = "👟", Height = 0.85,
	},
	Toy = {
		DisplayName = "Toy", Plural = "Toys", Section = "Toys & Games",
		Variants = { "Teddy Bear", "Toy Car", "Beach Ball", "Toy Robot" },
		PlaceName = "Toy Rack", Hint = "Follow the hanging signs to the TOYS racks.", Points = 12, Icon = "🧸", Height = 1.4,
	},
	Bottle = {
		DisplayName = "Bottle", Plural = "Bottles", Section = "Household & Cleaning",
		Variants = { "Laundry Detergent", "Dish Soap", "Glass Cleaner", "Fabric Softener" },
		PlaceName = "Household Rack", Hint = "Follow the hanging signs to the HOUSEHOLD racks.", Points = 10, Icon = "🧴", Height = 1.4,
	},
	Can = {
		DisplayName = "Canned Food", Plural = "Cans", Section = "Pantry",
		Variants = { "Tomato Soup", "Baked Beans", "Sweetcorn", "Chickpeas", "Peaches in Syrup" },
		PlaceName = "Pantry Rack", Hint = "Follow the hanging signs to the PANTRY racks.", Points = 8, Icon = "🥫", Height = 0.65,
	},
	Gadget = {
		DisplayName = "Electronics Box", Plural = "Electronics", Section = "Electronics",
		Variants = { "Headphones", "Smartphone", "Game Controller", "Smart Speaker" },
		PlaceName = "Electronics Rack", Hint = "Follow the hanging signs to the ELECTRONICS racks.", Points = 15, Icon = "🎧", Height = 1.2,
	},
	Tape = {
		DisplayName = "Tape Roll", Plural = "Tape Rolls", Section = "Packaging",
		Variants = { "Packing Tape", "Fragile Tape", "Masking Tape" },
		PlaceName = "Packaging Rack", Hint = "Follow the hanging signs to the PACKAGING racks.", Points = 8, Icon = "🧻", Height = 0.45,
	},
	Trophy = {
		DisplayName = "Trophy", Plural = "Trophies", Section = "Awards",
		Variants = { "Gold Trophy", "Silver Trophy", "Bronze Trophy", "Employee of the Month Cup" },
		PlaceName = "Trophy Cabinet", Hint = "Put it in a Trophy Cabinet in the Hall of Fame.", Points = 15, Icon = "🏆", Height = 1.4,
	},
	Frame = {
		DisplayName = "Photo Frame", Plural = "Photo Frames", Section = "Decor",
		Variants = { "Team Photo", "Landscape Print", "Award Certificate", "Founder Portrait" },
		PlaceName = "Frame Shelf", Hint = "Put it on a Frame Shelf.", Points = 12, Icon = "🖼️", Height = 0.95,
	},
	Binder = {
		DisplayName = "Ring Binder", Plural = "Binders", Section = "Records",
		Variants = { "Ring Binder", "Annual Report", "Contracts Binder", "Policy Binder" },
		PlaceName = "Records Shelf", Hint = "Put it on the Records Shelf with the same colored label.", Points = 10, Icon = "📗", Height = 1.3,
	},
}

-- Ordre d'affichage des types d'objets.
TidyConfig.TypeOrder = {
	"Folder", "Paper", "Chair", "Box", "Mug", "Plant", "Book", "Parcel", "Laptop", "Cushion",
	"ShoeBox", "Toy", "Bottle", "Can", "Gadget", "Tape", "Trophy", "Frame", "Binder",
}

-- Sous-catégories : ces objets doivent aller sur le meuble de LEUR couleur.
TidyConfig.Categories = {
	Book = {
		{ Id = "CV", Name = "CV & Cover Letters", Color = Color3.fromRGB(214, 64, 56) },
		{ Id = "Interview", Name = "Interview Skills", Color = Color3.fromRGB(52, 112, 210) },
		{ Id = "Training", Name = "Training & Courses", Color = Color3.fromRGB(56, 160, 86) },
		{ Id = "Careers", Name = "Careers & Sectors", Color = Color3.fromRGB(236, 176, 40) },
	},
	Parcel = {
		{ Id = "Red", Name = "Red Label", Color = Color3.fromRGB(226, 62, 52) },
		{ Id = "Blue", Name = "Blue Label", Color = Color3.fromRGB(46, 116, 222) },
		{ Id = "Green", Name = "Green Label", Color = Color3.fromRGB(52, 170, 86) },
		{ Id = "Yellow", Name = "Yellow Label", Color = Color3.fromRGB(246, 196, 40) },
	},
	Binder = {
		{ Id = "Finance", Name = "Finance", Color = Color3.fromRGB(46, 150, 96) },
		{ Id = "Legal", Name = "Legal", Color = Color3.fromRGB(44, 70, 150) },
		{ Id = "HR", Name = "Human Resources", Color = Color3.fromRGB(150, 70, 180) },
		{ Id = "Marketing", Name = "Marketing", Color = Color3.fromRGB(240, 120, 40) },
	},
}

---------------------------------------------------------------------------
-- Niveaux (cartes), dans l'ordre. Requires = niveau qu'il faut avoir terminé pour débloquer celui-ci.
---------------------------------------------------------------------------
TidyConfig.Maps = {
	{
		Id = "Warehouse",
		Name = "Distribution Warehouse",
		Short = "Warehouse",
		Requires = nil,
		Icon = "🏭",
		Color = Color3.fromRGB(240, 150, 40),
		Spawn = Vector3.new(1000, 1, 112),
	},
	{
		Id = "Agency",
		Name = "Employment Agency",
		Short = "Agency",
		Requires = "Warehouse",
		Icon = "🏢",
		Color = Color3.fromRGB(64, 150, 230),
		Spawn = Vector3.new(0, 1, 54),
	},
	{
		Id = "Headquarters",
		Name = "Corporate Offices",
		Short = "Offices",
		Requires = "Agency",
		Icon = "🏙️",
		Color = Color3.fromRGB(150, 110, 230),
		Spawn = Vector3.new(-1030, 200, 94), -- dernier étage de la tour
	},
}

-- Hauteur du sol de chaque étage de l'agence (rez-de-chaussée et étage).
TidyConfig.FloorHeights = { 1, 15 }

---------------------------------------------------------------------------
-- Pièces de chaque niveau
---------------------------------------------------------------------------
-- Map     : niveau de la pièce.          Floor : étage (agence seulement).
-- Unlock  : la pièce s'ouvre toute seule quand le joueur a GAGNÉ ce total de points
--           sur ce niveau (les points dépensés comptent aussi : rien n'est perdu).
-- Requires: pièce qu'il faut avoir ouverte avant.
-- Items   : objets qui traînent dans la pièce à chaque journée de travail.
TidyConfig.Rooms = {
	-- Agence pour l'emploi (rez-de-chaussée)
	{ Id = "Reception", Map = "Agency", Name = "Reception", MinX = -30, MaxX = 30, MinZ = 20, MaxZ = 60, Unlock = 0, Items = { Paper = 12, Chair = 18 } },
	{ Id = "SelfService", Map = "Agency", Name = "Self-Service Area", MinX = 0, MaxX = 80, MinZ = -10, MaxZ = 20, Unlock = 0, Items = { Chair = 12, Paper = 6, Plant = 12 } },
	{ Id = "Offices", Map = "Agency", Name = "Advisor Offices", MinX = -80, MaxX = 0, MinZ = -60, MaxZ = 20, Unlock = 800, Items = { Paper = 36, Plant = 12 } },
	{ Id = "BreakRoom", Map = "Agency", Name = "Break Room", MinX = -80, MaxX = -30, MinZ = 20, MaxZ = 60, Unlock = 1300, Items = { Mug = 72, Chair = 16 } },
	{ Id = "Archives", Map = "Agency", Name = "Archives", MinX = 0, MaxX = 50, MinZ = -60, MaxZ = -10, Unlock = 2200, Items = { Folder = 144 } },
	{ Id = "Storage", Map = "Agency", Name = "Storage", MinX = 50, MaxX = 80, MinZ = -60, MaxZ = -10, Unlock = 3300, Items = { Box = 54 } },
	{ Id = "Training", Map = "Agency", Name = "Workshop Room", MinX = 30, MaxX = 80, MinZ = 20, MaxZ = 60, Unlock = 4000, Items = { Chair = 20, Paper = 6, Plant = 6 } },
	{ Id = "Booths", Map = "Agency", Name = "Interview Booths", MinX = -80, MaxX = -20, MinZ = -100, MaxZ = -60, Unlock = 4500, Items = { Chair = 16, Paper = 24 } },
	{ Id = "Library", Map = "Agency", Name = "Resource Library", MinX = -20, MaxX = 30, MinZ = -100, MaxZ = -60, Unlock = 5000, Items = { Book = 192 } },
	{ Id = "MailRoom", Map = "Agency", Name = "Mail Room", MinX = 30, MaxX = 80, MinZ = -100, MaxZ = -60, Unlock = 6200, Items = { Parcel = 144 } },
	-- Agence (étage, par l'ascenseur)
	{ Id = "UpperHall", Map = "Agency", Name = "Upper Hall", Floor = 2, MinX = -20, MaxX = 20, MinZ = 20, MaxZ = 60, Unlock = 7600, Items = { Chair = 8, Plant = 6 } },
	{ Id = "Lounge", Map = "Agency", Name = "Employer Lounge", Floor = 2, MinX = -80, MaxX = -20, MinZ = 20, MaxZ = 60, Unlock = 0, Requires = "UpperHall", Items = { Cushion = 48, Plant = 6 } },
	{ Id = "Conference", Map = "Agency", Name = "Conference Rooms", Floor = 2, MinX = 20, MaxX = 80, MinZ = 20, MaxZ = 60, Unlock = 0, Requires = "UpperHall", Items = { Chair = 28, Paper = 12 } },
	{ Id = "Workspace", Map = "Agency", Name = "Open Workspace", Floor = 2, MinX = -20, MaxX = 20, MinZ = -60, MaxZ = 20, Unlock = 0, Requires = "UpperHall", Items = { Chair = 8, Paper = 24, Plant = 6 } },
	{ Id = "ITRoom", Map = "Agency", Name = "IT Room", Floor = 2, MinX = 20, MaxX = 80, MinZ = -60, MaxZ = 20, Unlock = 0, Requires = "UpperHall", Items = { Laptop = 72, Box = 18 } },
	{ Id = "Director", Map = "Agency", Name = "Director's Office", Floor = 2, MinX = -80, MaxX = -20, MinZ = -60, MaxZ = 20, Unlock = 0, Requires = "UpperHall", Items = { Folder = 72, Paper = 6, Plant = 6 } },
	-- Agence (aile est du rez-de-chaussée : un grand couloir et 8 pièces)
	{ Id = "EastHall", Map = "Agency", Name = "East Wing Hall", MinX = 80, MaxX = 240, MinZ = -10, MaxZ = 20, Unlock = 10100, Items = { Paper = 30, Chair = 24, Plant = 18 } },
	{ Id = "StaffCafe", Map = "Agency", Name = "Staff Café", MinX = 80, MaxX = 120, MinZ = 20, MaxZ = 60, Unlock = 10900, Items = { Chair = 16, Mug = 126 } },
	{ Id = "RecordsHall", Map = "Agency", Name = "Records Hall", MinX = 80, MaxX = 120, MinZ = -100, MaxZ = -10, Unlock = 12200, Items = { Folder = 240 } },
	{ Id = "JobClub", Map = "Agency", Name = "Job Club Lounge", MinX = 120, MaxX = 160, MinZ = 20, MaxZ = 60, Unlock = 14000, Items = { Plant = 12, Cushion = 66 } },
	{ Id = "CareerLibrary", Map = "Agency", Name = "Career Library", MinX = 120, MaxX = 160, MinZ = -100, MaxZ = -10, Unlock = 14600, Items = { Book = 288 } },
	{ Id = "ComputerLab", Map = "Agency", Name = "Computer Lab", MinX = 160, MaxX = 200, MinZ = 20, MaxZ = 60, Unlock = 16400, Items = { Paper = 24, Laptop = 132 } },
	{ Id = "ParcelDepot", Map = "Agency", Name = "Parcel Depot", MinX = 160, MaxX = 200, MinZ = -100, MaxZ = -10, Unlock = 17800, Items = { Parcel = 288 } },
	{ Id = "SupplyRoom", Map = "Agency", Name = "Supply Room", MinX = 200, MaxX = 240, MinZ = 20, MaxZ = 60, Unlock = 20400, Items = { Paper = 18, Box = 72 } },
	{ Id = "Stockroom", Map = "Agency", Name = "Stockroom", MinX = 200, MaxX = 240, MinZ = -100, MaxZ = -10, Unlock = 21400, Items = { Box = 124 } },

	-- Entrepôt de distribution (un immense hall découpé en sections, sans murs)
	{ Id = "WReceiving", Map = "Warehouse", Name = "Receiving Dock", MinX = 820, MaxX = 1180, MinZ = 80, MaxZ = 120, Unlock = 0, Items = { Box = 90 } },
	{ Id = "WFootwear", Map = "Warehouse", Name = "Footwear", MinX = 820, MaxX = 910, MinZ = -20, MaxZ = 80, Unlock = 0, Items = { ShoeBox = 240, Box = 20 } },
	{ Id = "WToys", Map = "Warehouse", Name = "Toys & Games", MinX = 910, MaxX = 1000, MinZ = -20, MaxZ = 80, Unlock = 3100, Items = { Toy = 260, ShoeBox = 30 } },
	{ Id = "WHousehold", Map = "Warehouse", Name = "Household & Cleaning", MinX = 1000, MaxX = 1090, MinZ = -20, MaxZ = 80, Unlock = 5800, Items = { Bottle = 260, Toy = 30 } },
	{ Id = "WPantry", Map = "Warehouse", Name = "Pantry", MinX = 1090, MaxX = 1180, MinZ = -20, MaxZ = 80, Unlock = 8100, Items = { Can = 300, Bottle = 30 } },
	{ Id = "WElectronics", Map = "Warehouse", Name = "Electronics", MinX = 1090, MaxX = 1180, MinZ = -120, MaxZ = -20, Unlock = 10200, Items = { Gadget = 240, Box = 20 } },
	{ Id = "WPackaging", Map = "Warehouse", Name = "Packaging", MinX = 1000, MaxX = 1090, MinZ = -120, MaxZ = -20, Unlock = 13200, Items = { Tape = 240, Gadget = 20 } },
	{ Id = "WOutbound", Map = "Warehouse", Name = "Outbound Shipping", MinX = 910, MaxX = 1000, MinZ = -120, MaxZ = -20, Unlock = 14900, Items = { Parcel = 320, Tape = 20 } },
	{ Id = "WReturns", Map = "Warehouse", Name = "Returns", MinX = 820, MaxX = 910, MinZ = -120, MaxZ = -20, Unlock = 18000, Items = { ShoeBox = 40, Toy = 40, Bottle = 40, Can = 40, Gadget = 40 } },

	-- Siège social (bureaux de direction luxueux, au dernier étage d'une tour)
	{ Id = "HLobby", Map = "Headquarters", Name = "Grand Lobby", MinX = -1080, MaxX = -980, MinZ = 20, MaxZ = 100, Unlock = 0, Items = { Chair = 30, Plant = 20, Paper = 30 } },
	{ Id = "HAtrium", Map = "Headquarters", Name = "Atrium", MinX = -1080, MaxX = -980, MinZ = -40, MaxZ = 20, Unlock = 0, Items = { Plant = 20, Paper = 20, Frame = 10 } },
	{ Id = "HOpenOffice", Map = "Headquarters", Name = "Open Office", MinX = -1180, MaxX = -1080, MinZ = 20, MaxZ = 100, Unlock = 1500, Items = { Paper = 80, Chair = 40, Mug = 60 } },
	{ Id = "HCafe", Map = "Headquarters", Name = "Executive Café", MinX = -980, MaxX = -880, MinZ = 20, MaxZ = 100, Unlock = 3200, Items = { Mug = 120, Cushion = 60, Chair = 24 } },
	{ Id = "HTrophy", Map = "Headquarters", Name = "Hall of Fame", MinX = -1180, MaxX = -1080, MinZ = -40, MaxZ = 20, Unlock = 4900, Items = { Trophy = 180, Frame = 110 } },
	{ Id = "HBoard", Map = "Headquarters", Name = "Boardroom", MinX = -980, MaxX = -880, MinZ = -40, MaxZ = 20, Unlock = 8000, Items = { Chair = 48, Paper = 60, Laptop = 60 } },
	{ Id = "HArchive", Map = "Headquarters", Name = "Records Vault", MinX = -1180, MaxX = -1080, MinZ = -100, MaxZ = -40, Unlock = 9800, Items = { Binder = 240, Folder = 120 } },
	{ Id = "HExecutive", Map = "Headquarters", Name = "CEO Suite", MinX = -1080, MaxX = -980, MinZ = -100, MaxZ = -40, Unlock = 12500, Items = { Folder = 100, Frame = 60, Cushion = 30, Plant = 12 } },
	{ Id = "HServer", Map = "Headquarters", Name = "Server Hub", MinX = -980, MaxX = -880, MinZ = -100, MaxZ = -40, Unlock = 14200, Items = { Laptop = 140, Box = 40 } },
	-- Siège social (rangée nord ajoutée, face à la ville)
	{ Id = "HSkyLounge", Map = "Headquarters", Name = "Sky Lounge", MinX = -1105, MaxX = -1030, MinZ = -200, MaxZ = -100, Unlock = 15900, Items = { Chair = 20, Mug = 108, Plant = 40, Cushion = 108 } },
	{ Id = "HLegal", Map = "Headquarters", Name = "Legal Department", MinX = -1180, MaxX = -1105, MinZ = -200, MaxZ = -100, Unlock = 18200, Items = { Folder = 72, Paper = 30, Binder = 240 } },
	{ Id = "HMarketing", Map = "Headquarters", Name = "Marketing Studio", MinX = -1030, MaxX = -955, MinZ = -200, MaxZ = -100, Unlock = 20800, Items = { Paper = 48, Chair = 48, Trophy = 40, Frame = 150 } },
	{ Id = "HLab", Map = "Headquarters", Name = "Innovation Lab", MinX = -955, MaxX = -880, MinZ = -200, MaxZ = -100, Unlock = 23800, Items = { Paper = 30, Chair = 40, Box = 72, Laptop = 240 } },
}

-- Points bonus quand toute une pièce est rangée, et quand tout le niveau est rangé.
TidyConfig.RoomBonus = 100
TidyConfig.DayBonus = 1000

-- Distance maximale (en studs) pour ramasser ou ranger d'un clic.
TidyConfig.ReachDistance = 14
-- Marge supplémentaire utilisée par le serveur quand il revérifie la distance.
TidyConfig.ServerDistanceMargin = 4

-- Sac et vitesse de départ.
TidyConfig.BaseCapacity = 5
TidyConfig.BaseWalkSpeed = 16

-- Aimant : portée au niveau 1, puis gain de portée par niveau.
TidyConfig.MagnetBaseRadius = 10
TidyConfig.MagnetRadiusPerLevel = 4

-- Améliorations achetées avec les points. Prix = BaseCost x (niveau visé).
TidyConfig.Upgrades = {
	{ Id = "Capacity", Name = "Bigger Basket", Icon = "🧺", Description = "Carry one more item", MaxLevel = 12, BaseCost = 60 },
	{ Id = "Speed", Name = "Comfy Sneakers", Icon = "👟", Description = "Walk a little faster", MaxLevel = 6, BaseCost = 90 },
	{ Id = "Magnet", Name = "Magnet", Icon = "🧲", Description = "Unlocks tool 2, then more range", MaxLevel = 6, BaseCost = 150 },
}

---------------------------------------------------------------------------
-- Boutique Robux
---------------------------------------------------------------------------
-- Créez les pass et les produits sur le Creator Hub, puis collez leur numéro ici
-- (GamePassId / ProductId). Tant que le numéro vaut 0, l'article est "bientôt disponible"
-- dans le jeu publié ; dans Studio, il est offert pour la session afin de le tester.
-- Price = prix conseillé en Robux (affiché dans la boutique ; le vrai prix est celui du Creator Hub).
TidyConfig.GamePasses = {
	{ Id = "DoublePoints", Name = "x2 Points", Icon = "💰", Description = "Earn double points for everything, forever.", Price = 199, GamePassId = 0, Best = true },
	{ Id = "Carry15", Name = "Big Basket", Icon = "🧺", Description = "Carry 15 more items at once, forever.", Price = 149, GamePassId = 0 },
	{ Id = "InfiniteMagnet", Name = "Super Magnet", Icon = "🧲", Description = "Magnet unlocked with a huge 60-stud range.", Price = 249, GamePassId = 0 },
	{ Id = "VIP", Name = "VIP", Icon = "👑", Description = "Gold VIP tag, +25% points and x2 daily bonus.", Price = 399, GamePassId = 0 },
}

-- Produits (achats répétables, sauf l'offre de départ).
TidyConfig.Products = {
	{ Id = "Deal", Name = "Starter Deal", Icon = "🎁", Description = "3,000 points + permanent +3 carry. One time only!", Price = 49, ProductId = 0, Points = 3000, OneTime = true },
	{ Id = "Points2", Name = "Points Pack", Icon = "💎", Description = "10,000 points to spend on upgrades.", Price = 99, ProductId = 0, Points = 10000 },
	{ Id = "Helper", Name = "Tidy Helper", Icon = "🤖", Description = "Instantly puts away 50 items in open rooms (you get the points).", Price = 25, ProductId = 0, HelperItems = 50 },
}

-- Offre limitée (badge "DEAL" en haut à droite) : durée de l'offre à chaque session, en secondes.
TidyConfig.DealDuration = 5 * 60
TidyConfig.DealCarryBonus = 3

-- Effets des pass.
TidyConfig.PassEffects = {
	Carry5 = 5,
	Carry15 = 15,
	MaxSpeedBonus = 4,
	InfiniteMagnetRadius = 60,
	DoublePoints = 2,
	VIPPoints = 1.25,
	VIPDaily = 2,
}

---------------------------------------------------------------------------
-- Rangs, bonus quotidien, quêtes du jour
---------------------------------------------------------------------------
-- Rangs du joueur, selon le nombre total d'objets rangés (sauvegardé).
TidyConfig.Ranks = {
	{ Name = "Intern", Items = 0 },
	{ Name = "Office Assistant", Items = 100 },
	{ Name = "Filing Clerk", Items = 300 },
	{ Name = "Stock Keeper", Items = 700 },
	{ Name = "Records Officer", Items = 1500 },
	{ Name = "Team Leader", Items = 3000 },
	{ Name = "Office Manager", Items = 6000 },
	{ Name = "Operations Director", Items = 10000 },
	{ Name = "CEO", Items = 20000 },
}

-- Bonus quotidien : points par jour de suite (plafonné à 7 jours).
TidyConfig.DailyBonusPerDay = 100
TidyConfig.DailyBonusMaxDays = 7

-- Quêtes du jour : 3 quêtes tirées chaque jour parmi ces modèles.
-- Kind : Place (ranger N objets), PlaceType (ranger N objets d'un type), Room (finir N pièces), Earn (gagner N points).
TidyConfig.QuestTemplates = {
	{ Kind = "Place", Target = 100, Reward = 300, Text = "Put away %d items" },
	{ Kind = "Place", Target = 300, Reward = 900, Text = "Put away %d items" },
	{ Kind = "PlaceType", ItemType = "Chair", Target = 30, Reward = 300, Text = "Put away %d chairs" },
	{ Kind = "PlaceType", ItemType = "Paper", Target = 40, Reward = 300, Text = "Put away %d paper stacks" },
	{ Kind = "PlaceType", ItemType = "Box", Target = 30, Reward = 350, Text = "Put away %d boxes" },
	{ Kind = "PlaceType", ItemType = "Parcel", Target = 50, Reward = 450, Text = "Put away %d parcels" },
	{ Kind = "Room", Target = 2, Reward = 500, Text = "Fully tidy %d rooms" },
	{ Kind = "Room", Target = 4, Reward = 1000, Text = "Fully tidy %d rooms" },
	{ Kind = "Earn", Target = 2000, Reward = 500, Text = "Earn %d points" },
	{ Kind = "Earn", Target = 6000, Reward = 1200, Text = "Earn %d points" },
}
TidyConfig.QuestsPerDay = 0 -- quêtes du jour désactivées

---------------------------------------------------------------------------
-- Hall d'accueil : files d'attente pour partir à plusieurs
---------------------------------------------------------------------------
TidyConfig.MaxPartySize = 4
TidyConfig.QueueCountdown = 5

-- Éclairage du jeu : 1 = normal (doux). Mettez par exemple 0.8 si c'est encore trop lumineux,
-- ou 1.2 si c'est trop sombre. Agit sur le soleil, l'ambiance et toutes les lampes.
TidyConfig.LightLevel = 1

-- MODE TEST (dans Roblox Studio seulement, jamais dans le jeu publié) :
-- true = tous les niveaux et toutes les pièces sont ouverts et vous avez TestPoints points
-- pour tout essayer. Rien n'est sauvegardé pendant ce mode. Mettez false pour jouer "normalement" dans Studio.
TidyConfig.TestUnlockAll = true
TidyConfig.TestPoints = 1000000

-- Musique d'ambiance. Mettez ici l'identifiant de la musique après l'avoir importée sur Roblox,
-- au format "rbxassetid://123456789" pour remplacer les musiques ci-dessous (vide = musiques par niveau).
TidyConfig.MusicSoundId = ""
-- Musiques d'ambiance libres de droits de la bibliothèque audio de Roblox (utilisables dans tous les jeux).
-- Une musique pour le hall et une par niveau. Pour en changer : collez un autre numéro "rbxassetid://...".
-- Si MusicSoundId est rempli, il remplace toutes ces musiques.
TidyConfig.Music = {
	Lobby = "rbxassetid://1841998846", -- Lobby Soirée
	Warehouse = "rbxassetid://1836057733", -- Leisure Simulation Game
	Agency = "rbxassetid://9044565954", -- Smooth Vibes
	Headquarters = "rbxassetid://1841647093", -- Life in an Elevator
}
-- Images des cartes du choix de niveau (facultatif) : collez le numéro d'une image importée, sinon
-- la carte affiche une illustration faite avec l'interface.
TidyConfig.MapImages = { Warehouse = "", Agency = "", Headquarters = "" }
TidyConfig.MusicVolume = 0.3

-- Son joué quand un objet est rangé (son intégré à Roblox).
TidyConfig.PlaceSoundId = "rbxasset://sounds/electronicpingshort.wav"

-- Codes pour rejoindre la partie d'un ami : durée de vie d'un code, en secondes.
TidyConfig.RoomCodeLifetime = 6 * 3600

-- Noms partagés entre les scripts. Ne les changez pas, sauf partout à la fois.
TidyConfig.ItemTag = "TidyItem"
TidyConfig.SlotTag = "TidySlot"
TidyConfig.ZoneTag = "TidyZone"
TidyConfig.DoorTag = "TidyDoor"

---------------------------------------------------------------------------
-- Fonctions utiles
---------------------------------------------------------------------------

-- Prix d'une amélioration pour passer au niveau suivant.
function TidyConfig.GetUpgradeCost(upgrade, currentLevel)
	return upgrade.BaseCost * (currentLevel + 1)
end

local function findById(list, id)
	for _, entry in list do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

function TidyConfig.GetUpgrade(id)
	return findById(TidyConfig.Upgrades, id)
end

function TidyConfig.GetRoom(id)
	return findById(TidyConfig.Rooms, id)
end

function TidyConfig.GetMap(id)
	return findById(TidyConfig.Maps, id)
end

function TidyConfig.GetPass(id)
	return findById(TidyConfig.GamePasses, id)
end

function TidyConfig.GetProduct(id)
	return findById(TidyConfig.Products, id)
end

-- Pièces d'un niveau, dans l'ordre de la liste.
function TidyConfig.GetMapRooms(mapId)
	local rooms = {}
	for _, room in TidyConfig.Rooms do
		if room.Map == mapId then
			table.insert(rooms, room)
		end
	end
	return rooms
end

-- Étage d'une position dans l'agence (1 = rez-de-chaussée, 2 = étage).
function TidyConfig.GetFloorAt(position)
	if position.Y >= TidyConfig.FloorHeights[2] - 1 then
		return 2
	end
	return 1
end

-- Renvoie la pièce qui contient une position (ou nil). Les niveaux sont à des endroits
-- différents du monde, donc une position ne peut être que dans un seul niveau.
function TidyConfig.GetRoomAt(position)
	local floor = TidyConfig.GetFloorAt(position)
	for _, room in TidyConfig.Rooms do
		if position.X >= room.MinX and position.X <= room.MaxX and position.Z >= room.MinZ and position.Z <= room.MaxZ then
			if room.Map ~= "Agency" or (room.Floor or 1) == floor then
				return room
			end
		end
	end
	return nil
end

-- Cherche une sous-catégorie (livres, colis, classeurs) par son identifiant.
function TidyConfig.GetCategory(itemType, categoryId)
	for _, category in TidyConfig.Categories[itemType] or {} do
		if category.Id == categoryId then
			return category
		end
	end
	return nil
end

-- Rang correspondant à un nombre total d'objets rangés.
function TidyConfig.GetRank(lifetimeItems)
	local current = TidyConfig.Ranks[1]
	for _, rank in TidyConfig.Ranks do
		if lifetimeItems >= rank.Items then
			current = rank
		end
	end
	return current
end

-- Nom précis d'un objet selon son numéro (ex. "Tomato Soup").
-- Un niveau est-il débloqué ? cleared = table { [idDuNiveau] = true } des niveaux terminés.
function TidyConfig.IsMapUnlocked(map, cleared)
	return map.Requires == nil or (cleared ~= nil and cleared[map.Requires] == true)
end

function TidyConfig.GetVariantName(itemType, index)
	local info = TidyConfig.ItemTypes[itemType]
	if not info then
		return itemType
	end
	local variants = info.Variants
	if not variants or #variants == 0 then
		return info.DisplayName
	end
	return variants[(index - 1) % #variants + 1]
end

-- Les 3 quêtes du jour (les mêmes pour un joueur toute la journée).
function TidyConfig.GetDailyQuests(userId, day)
	local rng = Random.new(day * 7919 + (userId % 100000))
	local pool = {}
	for index in TidyConfig.QuestTemplates do
		table.insert(pool, index)
	end
	local chosen = {}
	local usedKinds = {}
	while #chosen < TidyConfig.QuestsPerDay and #pool > 0 do
		local pick = rng:NextInteger(1, #pool)
		local index = table.remove(pool, pick)
		local template = TidyConfig.QuestTemplates[index]
		local kindKey = template.Kind .. (template.ItemType or "")
		if not usedKinds[kindKey] then
			usedKinds[kindKey] = true
			table.insert(chosen, index)
		end
	end
	table.sort(chosen)
	return chosen
end

function TidyConfig.FormatNumber(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

return TidyConfig
