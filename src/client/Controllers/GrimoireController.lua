-- The Grimoire: an in-game encyclopedia that explains how to play and how to craft spells,
-- and lists every spell part, premade spell and class. Open with H, the Grimoire button,
-- or by reading one of the lecterns in the hub or the library.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Classes = require(Shared.Classes)
local Cosmetics = require(Shared.Cosmetics)
local Rarity = require(Shared.Rarity)
local Consumables = require(Shared.Consumables)
local SpellParts = require(Shared.Spells.SpellParts)
local SpellBuilder = require(Shared.Spells.SpellBuilder)
local SpellTypes = require(Shared.Spells.SpellTypes)
local PremadeSpells = require(Shared.Spells.PremadeSpells)
local UI = script.Parent.Parent.UI
local Create = require(UI.Create)
local Theme = require(UI.Theme)
local Widgets = require(UI.Widgets)
local ItemInfo = require(UI.ItemInfo)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local GrimoireController = {}

GrimoireController.onReplayTutorial = nil :: (() -> ())?

local C = Theme.Colors
local COVER = Color3.fromRGB(70, 38, 30)
local PAGE = Color3.fromRGB(242, 230, 202)
local INK = Color3.fromRGB(58, 38, 28)
local INK_SOFT = Color3.fromRGB(110, 85, 65)
local RUBRIC = Color3.fromRGB(130, 50, 150)

local gui: ScreenGui
local chapterList: Frame
local content: ScrollingFrame
local isOpen = false
local currentChapter = "Welcome"
local closeBook: () -> () -- assigned below (chapters are declared before the open/close functions)

---------------------------------------------------------------------------
-- Writing helpers (dark ink on parchment)
---------------------------------------------------------------------------

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function heading(text: string)
	Widgets.label({
		Text = text,
		Font = Theme.Title,
		TextSize = 30,
		TextColor3 = RUBRIC,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

local function subheading(text: string)
	Widgets.label({
		Text = text,
		Font = Theme.Black,
		TextSize = 17,
		TextColor3 = INK,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

local function para(text: string)
	Widgets.label({
		Text = text,
		RichText = true,
		TextWrapped = true,
		TextSize = 15,
		TextColor3 = INK,
		Font = Theme.Font,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 18),
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

local function spacer(h: number?)
	Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, h or 8),
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

local function partTile(id: string, size: number, parent: Instance, layoutOrder: number)
	local part = SpellParts.ById[id]
	Widgets.tile({
		size = size,
		icon = part.icon,
		iconColor = Theme.CategoryColors[part.category],
		border = Theme.rarity(part.rarity),
		layoutOrder = layoutOrder,
		info = function()
			return ItemInfo.part(id)
		end,
		parent = parent,
	})
end

local function plusSign(parent: Instance, text: string, layoutOrder: number)
	Widgets.label({
		Text = text,
		Font = Theme.Black,
		TextSize = 20,
		TextColor3 = INK_SOFT,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(if #text > 2 then 34 else 18, 44),
		LayoutOrder = layoutOrder,
		Parent = parent,
	})
end

-- A visual recipe: [Bolt] + [Fire] + [Explosive]  =  Fireball
local function recipeRow(recipe: SpellTypes.Recipe, label: string?)
	local row = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = nextOrder(),
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	})
	local n = 0
	local function add(id: string?)
		if not id then
			return
		end
		if n > 0 then
			n += 1
			plusSign(row, "+", n)
		end
		n += 1
		partTile(id, 42, row, n)
	end
	add(recipe.form)
	add(recipe.element)
	for _, m in (recipe.mods or {}) :: { string } do
		add(m)
	end
	if recipe.trigger and recipe.payload then
		add(recipe.trigger)
		n += 1
		plusSign(row, "→", n)
		local payload = recipe.payload :: SpellTypes.Recipe
		local ids = { payload.form }
		if payload.element then
			table.insert(ids, payload.element)
		end
		for _, m in (payload.mods or {}) :: { string } do
			table.insert(ids, m)
		end
		for i, id in ids do
			if i > 1 then
				n += 1
				plusSign(row, "+", n)
			end
			n += 1
			partTile(id, 34, row, n)
		end
	end
	local spec = SpellBuilder.compile(recipe)
	n += 1
	Widgets.label({
		Text = "  =  " .. (label or (if spec then spec.name else "?")),
		Font = Theme.Bold,
		TextSize = 16,
		TextColor3 = RUBRIC,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 44),
		LayoutOrder = n,
		Parent = row,
	})
end

---------------------------------------------------------------------------
-- Chapters
---------------------------------------------------------------------------

local chapters: { { id: string, title: string, build: () -> () } } = {}

local function chapter(id: string, title: string, build: () -> ())
	table.insert(chapters, { id = id, title = title, build = build })
end

chapter("Welcome", "📖  Welcome", function()
	heading("Welcome, Mage")
	para(
		"<b>Mana Wars</b> is a survival-games battle royale. Up to "
			.. Config.Match.MaxParticipants
			.. " mages drop onto an island, loot chests, craft spells, and fight until one is left standing."
	)
	subheading("How a match plays out")
	para(
		"<b>1. Join.</b> Everyone starts in <b>Arcanum Plaza</b>, the hub. Practise as long as you like, then walk through the <b>portal</b> (or press <b>⚔ Join Game</b>) to join the queue.\n"
			.. "<b>2. Vote.</b> The portal takes you to the library, the <b>Arcane Athenaeum</b>. Vote for the next map on the right of your screen.\n"
			.. "<b>3. Pedestals.</b> Everyone is placed around the <b>cornucopia</b>, the ring of chests in the middle. Wait for the gong!\n"
			.. "<b>4. Grace period.</b> For the first "
			.. Config.Match.GracePeriod
			.. " seconds nobody can hurt anybody. Then it's on: fight for the cornucopia's loot, or run for the woods.\n"
			.. "<b>5. Battle.</b> Spells now hurt. Chests are scattered across the island, and every chest <b>refills</b> halfway through.\n"
			.. "<b>6. The Mana Storm.</b> A purple wall closes in. Stay inside it or burn.\n"
			.. "<b>7. Last mage standing wins.</b> Fallen mages drop a satchel with everything they carried. You go back to the library, still in the queue for the next match. Use the library's portal (or <b>Leave queue</b>) to return to the Plaza."
	)
	subheading("What's in the chests")
	para(
		"<b>Wands</b> cast your spells. <b>Spells</b> go into wand slots. <b>Spell parts</b> are ingredients: combine them in the <b>Spellforge</b> to create your own spells. <b>Potions</b> heal, restore mana or speed you up."
	)
	subheading("Practise first!")
	para(
		"Outside a match you carry a <b>Spell Lab</b> kit with every spell part, so you can try anything on the training dummies: on the <b>Practice Range</b> east of the Plaza (some of its dummies move!), or on the library's <b>Practice Terrace</b> through its north arch. Nothing you do there carries into the match."
	)
end)

chapter("Crafting", "✨  Spellcrafting", function()
	heading("Spellcrafting")
	para(
		"Every spell is built from <b>parts</b>. Open your <b>Spellbook (B)</b> and look at the <b>Spellforge</b> on the right."
	)
	subheading("The four kinds of parts")
	para(
		"<b>Form</b> (required): what the spell physically is: a bolt, an orb, a beam, a mine, a meteor, a teleport, a shield...\n"
			.. "<b>Element</b> (optional): what it's made of. Fire burns, Frost slows and freezes, Lightning arcs, Poison stacks, Void heals you...\n"
			.. "<b>Modifiers</b> (up to "
			.. Config.Spell.MaxModifiers
			.. "): how it behaves. Homing, Twin, Triple, Explosive, Bounce, Pierce, Orbit... Add the same one twice to stack it.\n"
			.. "<b>Trigger + Payload</b> (optional): makes your spell cast a <i>whole second spell</i> when it hits something, when it ends, after a timer, or every pulse."
	)
	subheading("Forging a spell, step by step")
	para(
		"<b>1.</b> Click a <b>Form</b> part in your bag. It jumps into the FORM slot.\n"
			.. "<b>2.</b> Click an <b>Element</b> part, then any <b>Modifiers</b> you like.\n"
			.. "<b>3.</b> Check the preview: name, damage, mana cost.\n"
			.. "<b>4.</b> Press <b>Forge Spell</b>. The parts are used up and the new spell appears in your bag.\n"
			.. "<b>5.</b> Click the new spell, then click an <b>empty wand slot</b> to equip it."
	)
	subheading("Examples")
	recipeRow({ form = "Bolt", element = "Fire", mods = { "Explosive" } }, "Fireball")
	recipeRow({ form = "Spark", element = "Arcane", mods = { "Homing", "Triple" } }, "Magic Missile")
	recipeRow({ form = "Orb", element = "Frost", mods = { "Enlarge" } }, "Frost Orb")
	recipeRow({ form = "Mine", element = "Poison", mods = { "Lingering" } }, "Tick Bomb")
	subheading("Spells inside spells (triggers)")
	para(
		"Add a <b>Trigger</b> part, then pick a <b>payload</b>: select any spell in your bag and press <b>Use as payload</b> (or click the PAYLOAD slot). When your spell hits or ends, it casts the payload from that spot. Payloads can carry their own triggers, up to "
			.. Config.Spell.MaxDepth
			.. " spells deep!"
	)
	recipeRow({
		form = "Grenade",
		element = "Fire",
		trigger = "OnExpire",
		payload = { form = "Spray", element = "Fire" },
	}, "Cluster Bomb")
	recipeRow({
		form = "Blink",
		element = "Void",
		trigger = "OnHit",
		payload = { form = "Nova", element = "Void" },
	}, "Blink Strike")
	subheading("Dismantling")
	para(
		"Select a spell in your bag and press <b>Dismantle</b> to break it back into parts (its payload comes back as its own spell). Rare spells from chests are a great source of rare parts!"
	)
	subheading("Mana")
	para(
		"Every part adds to the spell's <b>mana</b> cost, and payloads are paid for up front. If your wand runs out of mana it fizzles until it regenerates. The <b>Efficient</b> modifier makes the whole spell cheaper."
	)
end)

chapter("Wands", "🔮  Wands", function()
	heading("Wands")
	para(
		"A wand is a <b>deck of spells</b>. Each time you cast, it fires the next spell in its slots, <b>left to right</b>. After the last slot it <b>recharges</b> and starts again from the first."
	)
	subheading("Wand stats")
	para(
		"<b>Mana / regen:</b> how much the wand can spend, and how fast it refills. Every wand has its own mana, so swapping wands is a real trick.\n"
			.. "<b>Cast delay:</b> wait between casts. Spells add their own delay too.\n"
			.. "<b>Recharge:</b> wait after the last spell before the deck starts over.\n"
			.. "<b>Spell slots:</b> how many spells it holds.\n"
			.. "<b>Spells per cast:</b> multicast wands fire 2-3 spells at once.\n"
			.. "<b>Spread:</b> how inaccurate it is.\n"
			.. "<b>Shuffled:</b> fires its spells in a random order instead of left to right.\n"
			.. "<b>Damage / speed:</b> multiplies every spell it casts."
	)
	subheading("Perks (rare wands)")
	para(
		"<b>Affinity:</b> bonus damage for one element.  <b>Always casts:</b> adds a free modifier to every spell.  <b>Siphon:</b> restores mana when you hit.  <b>Vampiric:</b> heals you for part of the damage."
	)
	subheading("Tips")
	para(
		"• Put a cheap, fast spell (like Spark Bolt) between big expensive ones.\n"
			.. "• Keep a utility wand with Blink or Aegis on key 2-4 for emergencies.\n"
			.. "• Rarer wands (green → blue → purple → orange → red) have better stats."
	)
end)

local function partCatalog(category: string, title: string, intro: string)
	heading(title)
	para(intro)
	local holder = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
	local grid = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.56, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = holder,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(84, 92),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local detail = Widgets.panel({
		Size = UDim2.new(0.42, 0, 0, 320),
		Position = UDim2.fromScale(0.58, 0),
		BackgroundColor3 = C.Panel,
		Parent = holder,
	})
	local detailInfo = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 1, -16),
		Position = UDim2.fromOffset(10, 8),
		Parent = detail,
	})
	local list = table.clone(SpellParts.ByCategory[category])
	local function show(id: string)
		Widgets.fillInfo(detailInfo, ItemInfo.part(id))
	end
	for i, part in list do
		local cell = Create("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Parent = grid })
		Widgets.tile({
			size = 64,
			icon = part.icon,
			iconColor = Theme.CategoryColors[category],
			border = Theme.rarity(part.rarity),
			onClick = function()
				Sounds.play("Click")
				show(part.id)
			end,
			parent = cell,
		}).Position =
			UDim2.fromOffset(10, 0)
		Widgets.label({
			Text = part.name,
			Font = Theme.Bold,
			TextSize = 12,
			TextColor3 = INK,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 68),
			Parent = cell,
		})
	end
	show(list[1].id)
end

chapter("Forms", "🔹  Forms", function()
	partCatalog("Form", "Forms", "The shape of a spell. Every spell needs exactly one. Click a part to read about it.")
end)

chapter("Elements", "🔥  Elements", function()
	partCatalog("Element", "Elements", "What a spell is made of. Optional, but each element adds a powerful effect.")
end)

chapter("Modifiers", "💥  Modifiers", function()
	partCatalog(
		"Modifier",
		"Modifiers",
		"Up to " .. Config.Spell.MaxModifiers .. " per spell. Stack the same modifier for a bigger effect."
	)
end)

chapter("Triggers", "🎇  Triggers", function()
	partCatalog(
		"Trigger",
		"Triggers",
		"A trigger needs a PAYLOAD spell. Select a spell in your bag and press 'Use as payload' in the Spellbook."
	)
end)

chapter("Library", "📚  Spell Library", function()
	heading("Spell Library")
	para("Every hand-made spell you can find in chests. Hover the parts to read them.")
	for _, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		local any = false
		for _, premade in PremadeSpells.List do
			if premade.rarity == rarity then
				if not any then
					subheading(rarity)
					any = true
				end
				recipeRow(premade.recipe, premade.name)
				para('<font color="#6e5541"><i>' .. premade.flavor .. "</i></font>")
			end
		end
	end
end)

chapter("Classes", "🎓  Kits", function()
	heading("Kits")
	para(
		"Your kit (class) decides the wands, spells, parts and potions you start each match with. Pick one at the <b>Class Altar</b> (in the Plaza's gazebo, or in the library). The Apprentice is free; the others are sold in tiers. Cheap tiers are mostly flavour, the top tiers are a real head start. The best gear is still in the chests."
	)
	para(
		"<b>Bonus part:</b> every kit also gives you <b>one random spell part</b> each match. The higher the tier, the rarer it can be:"
	)
	for tier = 0, #Classes.Tiers - 1 do
		local info = Classes.tierInfo(tier)
		para(
			"<b>"
				.. info.name
				.. "</b> ("
				.. (if info.robux > 0 then "R$" .. info.robux .. ", about " .. info.usd else "free")
				.. "): "
				.. Classes.oddsText(tier)
		)
	end
	for _, class in Classes.List do
		local info = Classes.tierInfo(class.tier)
		subheading(class.icon .. "  " .. class.name .. "  (" .. info.name .. ")")
		local spells = {}
		for _, w in class.kit.wands do
			for _, id in w.spells do
				table.insert(spells, PremadeSpells.ById[id].name)
			end
		end
		local parts = {}
		for id, n in (class.kit.parts or {}) :: { [string]: number } do
			table.insert(parts, SpellParts.ById[id].name .. (if n > 1 then " x" .. n else ""))
		end
		table.sort(parts)
		local wands = {}
		for _, w in class.kit.wands do
			table.insert(wands, w.template.name .. " (" .. w.template.rarity .. ")")
		end
		para(
			class.tagline
				.. "\n<b>Wands:</b> "
				.. table.concat(wands, ", ")
				.. "\n<b>Spells:</b> "
				.. table.concat(spells, ", ")
				.. "\n<b>Parts:</b> "
				.. table.concat(parts, ", ")
				.. " + 1 random"
		)
	end
end)

chapter("Wardrobe", "👘  Robes & Coins", function()
	heading("Robes, Hats & Coins")
	para(
		"Every match pays out <b>Enchanted Coins</b> by finishing place: 1st gets <b>"
			.. Config.Economy.CoinsForFirst
			.. "</b>, 2nd gets "
			.. Config.Economy.CoinsForFirst - 1
			.. " ... all the way down to 1 for 12th. New mages start with "
			.. Config.Economy.StarterCoins
			.. " coins and a plain robe and hat."
	)
	subheading("Coffers")
	para(
		"Spend coins on <b>Coffers</b> at the Coffer stall in the Plaza (or the 👘 Wardrobe button). Each holds robe and hat parts; pricier coffers roll rarer parts, and some designs only come from one coffer."
	)
	for _, box in Cosmetics.Boxes do
		para(
			box.icon
				.. " <b>"
				.. box.name
				.. "</b> (🪙 "
				.. box.price
				.. ", "
				.. box.parts
				.. (if box.parts == 1 then " part" else " parts")
				.. "): "
				.. Cosmetics.boxOddsText(box)
		)
	end
	subheading("The Tailor's Loom")
	para(
		"A <b>robe</b> is stitched from a <b>Cloth</b>, a <b>Trim</b> and a <b>Sigil</b>. A <b>hat</b> is a <b>Hat shape</b>, a <b>Band</b> and a <b>Gem</b>. Every part rolls its own design, colour, material, enchantments and (Sigils and Gems) an aura, so no two outfits look alike: there are over "
			.. math.floor(Cosmetics.varietyCount() / 1000)
			.. " thousand different parts."
	)
	subheading("Auras and resonance")
	para(
		"High-rarity Sigils and Gems carry an <b>aura</b>: embers, frost, lightning, smoke, stardust... A garment's <b>resonance</b> is the average rarity of its three parts, and its aura can only shine <b>one tier above</b> it. A Legendary gem on a Common hat barely glows; put it on Epic or Legendary parts and it shines at full strength. Auras show from Rare strength and add an extra flourish at Mythic; glowing ones (frost, lightning, holy light, inferno...) light up the area from Epic.\n"
			.. "Wear a robe and a hat with the <b>same aura</b>, both at Epic strength or better, and you leave a <b>trail</b> of it behind you."
	)
	subheading("Enchantments")
	local lines = {}
	for _, def in Cosmetics.Enchants do
		table.insert(
			lines,
			"<b>" .. def.name .. "</b>: up to " .. Cosmetics.enchantText({ stat = def.id, amount = def.cap })
		)
	end
	para(
		"Parts carry small bonuses that work in matches (rarer parts have more and bigger ones). Each stat is capped, so a full Mythic outfit is an edge, not an auto-win.\n"
			.. table.concat(lines, "\n")
	)
	subheading("Trading")
	para(
		"The <b>Gilded Gavel</b> (the auction house pavilion in the Plaza) lets you sell loose parts or finished robes and hats to other players for coins. The house keeps "
			.. math.floor(Config.Economy.AuctionFee * 100 + 0.5)
			.. "%. Unsold items come back after "
			.. Config.Economy.AuctionHours
			.. " hours, and you can take a listing back any time before it sells. Unwanted parts can also be <b>salvaged</b> for a few coins ("
			.. Rarity.Order[1]
			.. " "
			.. Cosmetics.SalvageValue[1]
			.. ", up to "
			.. Rarity.Order[#Rarity.Order]
			.. " "
			.. Cosmetics.SalvageValue[#Cosmetics.SalvageValue]
			.. ")."
	)
end)

chapter("Controls", "🎮  Controls", function()
	heading("Controls")
	local potions = {}
	for _, c in Consumables.List do
		table.insert(potions, c.key .. " " .. c.name)
	end
	para(
		"<b>Cast:</b> hold Left Mouse (mobile: the Cast button, gamepad: R2)\n"
			.. "<b>Switch wand:</b> 1-4, or Q to cycle (gamepad: L1/R1)\n"
			.. "<b>Spellbook & Spellforge:</b> B (gamepad: Y)\n"
			.. "<b>Grimoire:</b> H\n"
			.. "<b>Join the game:</b> walk through the Plaza's portal, or press ⚔ Join Game\n"
			.. "<b>Open chests:</b> E (hold).  <b>Take everything:</b> F\n"
			.. "<b>Potions:</b> "
			.. table.concat(potions, ",  ")
			.. "\n<b>Unslot a spell:</b> right-click it in the Spellbook\n"
			.. "<b>Camera:</b> hold right mouse and drag"
	)
	spacer(10)
	Widgets.button("▶  Replay the tutorial", {
		size = UDim2.fromOffset(240, 40),
		layoutOrder = nextOrder(),
		color = RUBRIC,
		onClick = function()
			closeBook()
			if GrimoireController.onReplayTutorial then
				GrimoireController.onReplayTutorial()
			end
		end,
		parent = content,
	})
end)

---------------------------------------------------------------------------
-- Book UI
---------------------------------------------------------------------------

local function showChapter(id: string)
	currentChapter = id
	Widgets.clear(content, true)
	order = 0
	for _, ch in chapters do
		if ch.id == id then
			ch.build()
		end
	end
	content.CanvasPosition = Vector2.zero
	for _, button in chapterList:GetChildren() do
		if button:IsA("TextButton") then
			button.BackgroundTransparency = if button.Name == id then 0 else 1
		end
	end
end

local function build()
	gui = Widgets.screen("Grimoire", 12)
	gui.Enabled = false
	local root = Widgets.scaledRoot(gui)
	local book = Create("Frame", {
		Size = UDim2.fromOffset(1140, 630),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COVER,
		Parent = root,
	}, { Create.corner(14), Create.stroke(Color3.fromRGB(212, 175, 55), 3) })

	local left = Create("Frame", {
		Size = UDim2.new(0, 270, 1, -30),
		Position = UDim2.fromOffset(15, 15),
		BackgroundColor3 = PAGE:Lerp(Color3.new(0, 0, 0), 0.06),
		Parent = book,
	}, { Create.corner(8) })
	Widgets.label({
		Text = "THE GRIMOIRE",
		Font = Theme.Title,
		TextSize = 30,
		TextColor3 = RUBRIC,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, 10),
		Parent = left,
	})
	chapterList = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, -80),
		Position = UDim2.fromOffset(12, 68),
		Parent = left,
	}, { Create.list(Enum.FillDirection.Vertical, 4) })
	for i, ch in chapters do
		local button = Create("TextButton", {
			Name = ch.id,
			Text = "  " .. ch.title,
			Font = Theme.Bold,
			TextSize = 17,
			TextColor3 = INK,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(225, 205, 165),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 36),
			LayoutOrder = i,
			Parent = chapterList,
		}, { Create.corner(6) })
		button.Activated:Connect(function()
			Sounds.play("Click")
			showChapter(ch.id)
		end)
	end

	local right = Create("Frame", {
		Size = UDim2.new(1, -315, 1, -30),
		Position = UDim2.fromOffset(300, 15),
		BackgroundColor3 = PAGE,
		Parent = book,
	}, { Create.corner(8) })
	content = Create("ScrollingFrame", {
		Name = "Page",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -40, 1, -30),
		Position = UDim2.fromOffset(24, 15),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = INK_SOFT,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = right,
	}, { Create.list(Enum.FillDirection.Vertical, 8) })

	Widgets.button("✕", {
		size = UDim2.fromOffset(36, 36),
		position = UDim2.new(1, -30, 0, -12),
		color = COVER:Lerp(Color3.new(1, 1, 1), 0.15),
		onClick = function()
			GrimoireController.close()
		end,
		parent = book,
	})
end

function GrimoireController.open(chapterId: string?)
	if not isOpen then
		isOpen = true
		gui.Enabled = true
		State.setMenu("grimoire", true)
		Sounds.play("Click")
	end
	showChapter(chapterId or currentChapter)
end

function GrimoireController.close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	Widgets.hideTooltip()
	State.setMenu("grimoire", false)
end

closeBook = GrimoireController.close

function GrimoireController.toggle()
	if isOpen then
		GrimoireController.close()
	else
		GrimoireController.open()
	end
end

function GrimoireController.isOpen(): boolean
	return isOpen
end

function GrimoireController.init()
	build()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape and isOpen and not processed then
			GrimoireController.close()
		end
	end)
end

return GrimoireController
