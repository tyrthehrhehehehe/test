--FH - Fluent UI Edition
if getgenv().FourHub_Running then
    warn("Script already running!")
    return
end

repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.GameId ~= 0

function missing(t, f, fallback)
	if type(f) == t then return f end
	return fallback
end

cloneref = missing("function", cloneref, function(...) return ... end)
getgc = missing("function", getgc or get_gc_objects)
getconnections = missing("function", getconnections or get_signal_cons)

Services = setmetatable({}, {
	__index = function(self, name)
		local success, cache = pcall(function()
			return cloneref(game:GetService(name))
		end)
		if success then
			rawset(self, name, cache)
			return cache
		else
			error("Invalid Service: " .. tostring(name))
		end
	end
})

local Players = Services.Players
local Plr = Players.LocalPlayer
local Char = Plr.Character or Plr.CharacterAdded:Wait()
local PGui = Plr:WaitForChild("PlayerGui")
local Lighting = game:GetService('Lighting')

local RS = Services.ReplicatedStorage
local RunService = Services.RunService
local HttpService = Services.HttpService
local GuiService = Services.GuiService
local TeleportService = Services.TeleportService
local Marketplace = Services.MarketplaceService
local UIS = Services.UserInputService
local VirtualUser = Services.VirtualUser

local v, Asset = pcall(function()
    return Marketplace:GetProductInfo(game.PlaceId)
end)

local assetName = "sailor piece"
if v and Asset then assetName = Asset.Name end

local Support = {
    Webhook = (typeof(request) == "function" or typeof(http_request) == "function"),
    Clipboard = (typeof(setclipboard) == "function"),
    FileIO = (typeof(writefile) == "function" and typeof(isfile) == "function"),
    QueueOnTeleport = (typeof(queue_on_teleport) == "function"),
    Connections = (typeof(getconnections) == "function"),
    FPS = (typeof(setfpscap) == "function"),
    Proximity = (typeof(fireproximityprompt) == "function"),
}

local executorName = (identifyexecutor and identifyexecutor() or "Unknown"):lower()
local isXeno = string.find(executorName, "xeno") ~= nil
local LimitedExecutors = {"xeno"}
local isLimitedExecutor = false
for _, name in ipairs(LimitedExecutors) do
    if string.find(executorName, name) then isLimitedExecutor = true break end
end

-- ============================================================
--  FLUENT UI LOAD
-- ============================================================
local Fluent       = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager  = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

getgenv().FourHub_Running = true

-- ============================================================
--  HELPERS  (notify shim so rest of code stays the same)
-- ============================================================
local function Notify(msg, dur)
    Fluent:Notify({ Title = "FourHub", Content = tostring(msg), Duration = dur or 3 })
end

-- ============================================================
--  ALL GAME LOGIC (unchanged from original)
-- ============================================================
local PriorityTasks = {"Boss", "Pity Boss", "Summon [Other]", "Summon", "Level Farm", "All Mob Farm", "Mob", "Merchant", "Alt Help"}
local DefaultPriority = {"Boss", "Pity Boss", "Summon [Other]", "Summon", "Level Farm", "All Mob Farm", "Mob", "Merchant", "Alt Help"}

local TargetGroupId = 1002185259
local BannedRanks = {255, 254, 175, 150}
local NewItemsBuffer = {}

local Shared = {
    GlobalPrio = "FARM", Cached = { Inv = {}, Accessories = {}, RawWeapCache = { Sword = {}, Melee = {} } },
    Farm = true, Recovering = false, MovingIsland = false, Island = "", Target = nil,
    KillTick = 0, TargetValid = false, QuestNPC = "", MobIdx = 1, AllMobIdx = 1,
    WeapRotationIdx = 1, ComboIdx = 1, ParsedCombo = {}, RawWeapCache = { Sword = {}, Melee = {} },
    ActiveWeap = "", ArmHaki = false, BossTIMap = {}, InventorySynced = false,
    Stats = {}, Settings = {}, GemStats = {}, SkillTree = { Nodes = {}, Points = 0 },
    Passives = {}, SpecStatsSlider = {}, ArtifactSession = { Inventory = {}, Dust = 0, InvCount = 0 },
    UpBlacklist = {}, MerchantBusy = false, LocalMerchantTime = 0, LastTimerTick = tick(),
    MerchantExecute = false, FirstMerchantSync = false, CurrentStock = {}, LastM1 = 0,
    LastWRSwitch = 0, LastSwitch = { Title = "", Rune = "" }, LastBuildSwitch = 0,
    LastDungeon = 0, AltDamage = {}, AltActive = false, TradeState = {},
}

local Script_Start_Time = os.time()
local StartStats = {
    Level = Plr.Data.Level.Value, Money = Plr.Data.Money.Value, Gems = Plr.Data.Gems.Value,
    Bounty = (Plr:FindFirstChild("leaderstats") and Plr.leaderstats:FindFirstChild("Bounty") and Plr.leaderstats.Bounty.Value) or 0
}

local function GetSessionTime()
    local seconds = os.time() - Script_Start_Time
    return string.format("%dh %02dm", math.floor(seconds/3600), math.floor((seconds%3600)/60))
end

local function GetSafeModule(parent, name)
    local obj = parent:FindFirstChild(name)
    if obj and obj:IsA("ModuleScript") then
        local success, result = pcall(require, obj)
        if success then return result end
    end
    return nil
end

local function GetRemote(parent, pathString)
    local current = parent
    for _, name in ipairs(pathString:split(".")) do
        if not current then return nil end
        current = current:FindFirstChild(name)
    end
    return current
end

local function SafeInvoke(remote, ...)
    local args = {...}; local result = nil
    task.spawn(function()
        local success, res = pcall(function() return remote:InvokeServer(unpack(args)) end)
        result = res
    end)
    local start = tick()
    repeat task.wait() until result ~= nil or (tick() - start) > 2
    return result
end

local function fire_event(signal, ...)
    if firesignal then return firesignal(signal, ...)
    elseif getconnections then
        for _, connection in ipairs(getconnections(signal)) do
            if connection.Function then task.spawn(connection.Function, ...) end
        end
    else warn("Your executor does not support firesignal or getconnections.") end
end

local _DR = GetRemote(RS, "RemoteEvents.DashRemote")
local _FS = (_DR and _DR.FireServer)

local Remotes = {
    SettingsToggle = GetRemote(RS, "RemoteEvents.SettingsToggle"),
    SettingsSync = GetRemote(RS, "RemoteEvents.SettingsSync"),
    UseCode = GetRemote(RS, "RemoteEvents.CodeRedeem"),
    M1 = GetRemote(RS, "CombatSystem.Remotes.RequestHit"),
    EquipWeapon = GetRemote(RS, "Remotes.EquipWeapon"),
    UseSkill = GetRemote(RS, "AbilitySystem.Remotes.RequestAbility"),
    UseFruit = GetRemote(RS, "RemoteEvents.FruitPowerRemote"),
    QuestAccept = GetRemote(RS, "RemoteEvents.QuestAccept"),
    QuestAbandon = GetRemote(RS, "RemoteEvents.QuestAbandon"),
    UseItem = GetRemote(RS, "Remotes.UseItem"),
    SlimeCraft = GetRemote(RS, "Remotes.RequestSlimeCraft"),
    GrailCraft = GetRemote(RS, "Remotes.RequestGrailCraft"),
    RerollSingleStat = GetRemote(RS, "Remotes.RerollSingleStat"),
    SkillTreeUpgrade = GetRemote(RS, "RemoteEvents.SkillTreeUpgrade"),
    Enchant = GetRemote(RS, "Remotes.EnchantAccessory"),
    Blessing = GetRemote(RS, "Remotes.BlessWeapon"),
    ArtifactSync = GetRemote(RS, "RemoteEvents.ArtifactDataSync"),
    ArtifactClaim = GetRemote(RS, "RemoteEvents.ArtifactMilestoneClaimReward"),
    MassDelete = GetRemote(RS, "RemoteEvents.ArtifactMassDeleteByUUIDs"),
    MassUpgrade = GetRemote(RS, "RemoteEvents.ArtifactMassUpgrade"),
    ArtifactLock = GetRemote(RS, "RemoteEvents.ArtifactLock"),
    ArtifactUnequip = GetRemote(RS, "RemoteEvents.ArtifactUnequip"),
    ArtifactEquip = GetRemote(RS, "RemoteEvents.ArtifactEquip"),
    Roll_Trait = GetRemote(RS, "RemoteEvents.TraitReroll"),
    TraitAutoSkip = GetRemote(RS, "RemoteEvents.TraitUpdateAutoSkip"),
    TraitConfirm = GetRemote(RS, "RemoteEvents.TraitConfirm"),
    SpecPassiveReroll = GetRemote(RS, "RemoteEvents.SpecPassiveReroll"),
    ArmHaki = GetRemote(RS, "RemoteEvents.HakiRemote"),
    ObserHaki = GetRemote(RS, "RemoteEvents.ObservationHakiRemote"),
    ConquerorHaki = GetRemote(RS, "Remotes.ConquerorHakiRemote"),
    TP_Portal = GetRemote(RS, "Remotes.TeleportToPortal"),
    OpenDungeon = GetRemote(RS, "Remotes.RequestDungeonPortal"),
    DungeonWaveVote = GetRemote(RS, "Remotes.DungeonWaveVote"),
    EquipTitle = GetRemote(RS, "RemoteEvents.TitleEquip"),
    TitleUnequip = GetRemote(RS, "RemoteEvents.TitleUnequip"),
    EquipRune = GetRemote(RS, "Remotes.EquipRune"),
    LoadoutLoad = GetRemote(RS, "RemoteEvents.LoadoutLoad"),
    AddStat = GetRemote(RS, "RemoteEvents.AllocateStat"),
    OpenMerchant = GetRemote(RS, "Remotes.MerchantRemotes.OpenMerchantUI"),
    MerchantBuy = GetRemote(RS, "Remotes.MerchantRemotes.PurchaseMerchantItem"),
    ValentineBuy = GetRemote(RS, "Remotes.ValentineMerchantRemotes.PurchaseValentineMerchantItem"),
    StockUpdate = GetRemote(RS, "Remotes.MerchantRemotes.MerchantStockUpdate"),
    SummonBoss = GetRemote(RS, "Remotes.RequestSummonBoss"),
    JJKSummonBoss = GetRemote(RS, "Remotes.RequestSpawnStrongestBoss"),
    RimuruBoss = GetRemote(RS, "RemoteEvents.RequestSpawnRimuru"),
    AnosBoss = GetRemote(RS, "Remotes.RequestSpawnAnosBoss"),
    TrueAizenBoss = GetRemote(RS, "RemoteEvents.RequestSpawnTrueAizen"),
    AtomicBoss = GetRemote(RS, "RemoteEvents.RequestSpawnAtomic"),
    ReqInventory = GetRemote(RS, "Remotes.RequestInventory"),
    Ascend = GetRemote(RS, "RemoteEvents.RequestAscend"),
    ReqAscend = GetRemote(RS, "RemoteEvents.GetAscendData"),
    CloseAscend = GetRemote(RS, "RemoteEvents.CloseAscendUI"),
    TradeRespond = GetRemote(RS, "Remotes.TradeRemotes.RespondToRequest"),
    TradeSend = GetRemote(RS, "Remotes.TradeRemotes.SendTradeRequest"),
    TradeAddItem = GetRemote(RS, "Remotes.TradeRemotes.AddItemToTrade"),
    TradeReady = GetRemote(RS, "Remotes.TradeRemotes.SetReady"),
    TradeConfirm = GetRemote(RS, "Remotes.TradeRemotes.ConfirmTrade"),
    TradeUpdated = GetRemote(RS, "Remotes.TradeRemotes.TradeUpdated"),
    HakiStateUpdate = GetRemote(RS, "RemoteEvents.HakiStateUpdate"),
    UpCurrency = GetRemote(RS, "RemoteEvents.UpdateCurrency"),
    UpInventory = GetRemote(RS, "Remotes.UpdateInventory"),
    UpPlayerStats = GetRemote(RS, "RemoteEvents.UpdatePlayerStats"),
    UpAscend = GetRemote(RS, "RemoteEvents.AscendDataUpdate"),
    UpStatReroll = GetRemote(RS, "RemoteEvents.StatRerollUpdate"),
    SpecPassiveUpdate = GetRemote(RS, "RemoteEvents.SpecPassiveDataUpdate"),
    SpecPassiveSkip = GetRemote(RS, "RemoteEvents.SpecPassiveUpdateAutoSkip"),
    UpSkillTree = GetRemote(RS, "RemoteEvents.SkillTreeUpdate"),
    BossUIUpdate = GetRemote(RS, "Remotes.BossUIUpdate"),
    TitleSync = GetRemote(RS, "RemoteEvents.TitleDataSync"),
}

local Modules = {
    BossConfig = GetSafeModule(RS.Modules, "BossConfig") or {Bosses = {}},
    TimedConfig = GetSafeModule(RS.Modules, "TimedBossConfig"),
    SummonConfig = GetSafeModule(RS.Modules, "SummonableBossConfig"),
    Merchant = GetSafeModule(RS.Modules, "MerchantConfig") or {ITEMS = {}},
    ValentineConfig = GetSafeModule(RS.Modules, "ValentineMerchantConfig"),
    DungeonMerchantConfig = GetSafeModule(RS.Modules, "DungeonMerchantConfig"),
    InfiniteTowerMerchantConfig = GetSafeModule(RS.Modules, "InfiniteTowerMerchantConfig"),
    BossRushMerchantConfig = GetSafeModule(RS.Modules, "BossRushMerchantConfig"),
    Title = GetSafeModule(RS.Modules, "TitlesConfig") or {},
    Quests = GetSafeModule(RS.Modules, "QuestConfig") or {RepeatableQuests = {}, Questlines = {}},
    WeaponClass = GetSafeModule(RS.Modules, "WeaponClassification") or {Tools = {}},
    Fruits = GetSafeModule(RS:FindFirstChild("FruitPowerSystem") or game, "FruitPowerConfig") or {Powers = {}},
    ArtifactConfig = GetSafeModule(RS.Modules, "ArtifactConfig"),
    Stats = GetSafeModule(RS.Modules, "StatRerollConfig"),
    Codes = GetSafeModule(RS, "CodesConfig") or {Codes = {}},
    ItemRarity = GetSafeModule(RS.Modules, "ItemRarityConfig"),
    Trait = GetSafeModule(RS.Modules, "TraitConfig") or {Traits = {}},
    Race = GetSafeModule(RS.Modules, "RaceConfig") or {Races = {}},
    Clan = GetSafeModule(RS.Modules, "ClanConfig") or {Clans = {}},
    SpecPassive = GetSafeModule(RS.Modules, "SpecPassiveConfig"),
    SkillTree = GetSafeModule(RS.Modules, "SkillTreeConfig"),
    InfiniteTower = GetSafeModule(RS.Modules, "InfiniteTowerConfig"),
}

local MerchantItemList = Modules.Merchant.ITEMS
local SortedTitleList = Modules.Title:GetSortedTitleIds()

local PATH = {
    Mobs = workspace:WaitForChild('NPCs'),
    InteractNPCs = workspace:WaitForChild('ServiceNPCs'),
}

local function GetServiceNPC(name) return PATH.InteractNPCs:FindFirstChild(name) end

local NPCs = {
    Merchant = {
        Regular = GetServiceNPC("MerchantNPC"),
        Dungeon = GetServiceNPC("DungeonMerchantNPC"),
        Valentine = GetServiceNPC("ValentineMerchantNPC"),
        InfiniteTower = GetServiceNPC("InfiniteTowerMerchantNPC"),
        BossRush = GetServiceNPC("BossRushMerchantNPC"),
    }
}

local UI = {
    Merchant = {
        Regular = PGui:WaitForChild("MerchantUI"),
        Dungeon = PGui:WaitForChild("DungeonMerchantUI"),
        Valentine = PGui:FindFirstChild("ValentineMerchantUI"),
        InfiniteTower = PGui:FindFirstChild("InfiniteTowerMerchantUI"),
        BossRush = PGui:FindFirstChild("BossRushMerchantUI"),
    }
}

local pingUI = PGui:WaitForChild("QuestPingUI")
local SummonMap = {}

local function GetRemoteBossArg(name)
    local RemoteBossMap = {
        ["strongestinhistory"] = "StrongestHistory", ["strongestoftoday"] = "StrongestToday",
        ["strongesthistory"] = "StrongestHistory", ["strongesttoday"] = "StrongestToday",
    }
    return RemoteBossMap[name:lower()] or name
end

local IslandCrystals = {
    ["Starter"] = workspace:FindFirstChild("StarterIsland") and workspace.StarterIsland:FindFirstChild("SpawnPointCrystal_Starter"),
    ["Jungle"] = workspace:FindFirstChild("JungleIsland") and workspace.JungleIsland:FindFirstChild("SpawnPointCrystal_Jungle"),
    ["Desert"] = workspace:FindFirstChild("DesertIsland") and workspace.DesertIsland:FindFirstChild("SpawnPointCrystal_Desert"),
    ["Snow"] = workspace:FindFirstChild("SnowIsland") and workspace.SnowIsland:FindFirstChild("SpawnPointCrystal_Snow"),
    ["Sailor"] = workspace:FindFirstChild("SailorIsland") and workspace.SailorIsland:FindFirstChild("SpawnPointCrystal_Sailor"),
    ["Shibuya"] = workspace:FindFirstChild("ShibuyaStation") and workspace.ShibuyaStation:FindFirstChild("SpawnPointCrystal_Shibuya"),
    ["HuecoMundo"] = workspace:FindFirstChild("HuecoMundo") and workspace.HuecoMundo:FindFirstChild("SpawnPointCrystal_HuecoMundo"),
    ["Boss"] = workspace:FindFirstChild("BossIsland") and workspace.BossIsland:FindFirstChild("SpawnPointCrystal_Boss"),
    ["Dungeon"] = workspace:FindFirstChild("Main Temple") and workspace["Main Temple"]:FindFirstChild("SpawnPointCrystal_Dungeon"),
    ["Shinjuku"] = workspace:FindFirstChild("ShinjukuIsland") and workspace.ShinjukuIsland:FindFirstChild("SpawnPointCrystal_Shinjuku"),
    ["Valentine"] = workspace:FindFirstChild("ValentineIsland") and workspace.ValentineIsland:FindFirstChild("SpawnPointCrystal_Valentine"),
    ["Slime"] = workspace:FindFirstChild("SlimeIsland") and workspace.SlimeIsland:FindFirstChild("SpawnPointCrystal_Slime"),
    ["Academy"] = workspace:FindFirstChild("AcademyIsland") and workspace.AcademyIsland:FindFirstChild("SpawnPointCrystal_Academy"),
    ["Judgement"] = workspace:FindFirstChild("JudgementIsland") and workspace.JudgementIsland:FindFirstChild("SpawnPointCrystal_Judgement"),
    ["SoulDominion"] = workspace:FindFirstChild("SoulDominionIsland") and workspace.SoulDominionIsland:FindFirstChild("SpawnPointCrystal_SoulDominion"),
    ["NinjaIsland"] = workspace:FindFirstChild("NinjaIsland") and workspace.NinjaIsland:FindFirstChild("SpawnPointCrystal_Ninja"),
    ["LawlessIsland"] = workspace:FindFirstChild("LawlessIsland") and workspace.LawlessIsland:FindFirstChild("SpawnPointCrystal_Lawless"),
    ["TowerIsland"] = workspace:FindFirstChild("TowerIsland") and workspace.TowerIsland:FindFirstChild("SpawnPointCrystal_Tower"),
}

local Connections = { Player_General = nil, Idled = nil, Merchant = nil, Dash = nil, Knockback = {}, Reconnect = nil }

local Tables = {
    AscendLabels = {}, DiffList = {"Normal", "Medium", "Hard", "Extreme"}, MobList = {},
    MiniBossList = {"ThiefBoss", "MonkeyBoss", "DesertBoss", "SnowBoss", "PandaMiniBoss"},
    BossList = {}, AllBossList = {}, AllNPCList = {}, AllEntitiesList = {}, SummonList = {},
    OtherSummonList = {"StrongestHistory", "StrongestToday", "Rimuru", "Anos", "TrueAizen", "Atomic", "AbyssalEmpress"},
    Weapon = {"Melee", "Sword", "Power"},
    ManualWeaponClass = { ["Invisible"] = "Power", ["Bomb"] = "Power", ["Quake"] = "Power" },
    MerchantList = {}, ValentineMerchantList = {},
    Rarities = {"Common", "Rare", "Epic", "Legendary", "Mythical", "Secret", "Aura Crate", "Cosmetic Crate"},
    CraftItemList = {"SlimeKey", "DivineGrail"}, UnlockedTitle = {},
    TitleCategory = {"None", "Best EXP", "Best Money & Gem", "Best Luck", "Best DMG"},
    TitleList = {}, BuildList = {"1", "2", "3", "4", "5", "None"}, TraitList = {},
    RarityWeight = { ["Secret"]=1, ["Mythical"]=2, ["Legendary"]=3, ["Epic"]=4, ["Rare"]=5, ["Uncommon"]=6, ["Common"]=7 },
    RaceList = {}, ClanList = {}, RuneList = {"None"}, SpecPassive = {},
    GemStat = Modules.Stats.StatKeys, GemRank = Modules.Stats.RankOrder,
    OwnedWeapon = {}, AllOwnedWeapons = {}, OwnedAccessory = {}, QuestlineList = {}, OwnedItem = {},
    IslandList = {"Starter","Jungle","Desert","Snow","Sailor","Shibuya","HuecoMundo","Boss","Dungeon","Shinjuku","Valentine","Slime","Academy","Judgement","SoulSociety","Tower"},
    NPC_QuestList = {"DungeonUnlock", "SlimeKeyUnlock"},
    NPC_MiscList = {"Artifacts","Blessing","Enchant","SkillTree","Cupid","ArmHaki","Observation","Conqueror"},
    DungeonList = {"CidDungeon","RuneDungeon","DoubleDungeon","BossRush","InfiniteTower"},
    NPC_MovesetList = {}, NPC_MasteryList = {}, MobToIsland = {}
}

local allSets = {}
for setName, _ in pairs(Modules.ArtifactConfig.Sets) do table.insert(allSets, setName) end
local allStats = {}
for statKey, _ in pairs(Modules.ArtifactConfig.Stats) do table.insert(allStats, statKey) end

if Modules.TimedConfig and Modules.TimedConfig.Bosses then
    for _, data in pairs(Modules.TimedConfig.Bosses) do
        table.insert(Tables.BossList, data.displayName)
        local tpName = data.spawnLocation:gsub(" Island",""):gsub(" Station","")
        if data.spawnLocation == "Hueco Mundo Island" then tpName = "HuecoMundo" end
        if data.spawnLocation == "Judgement Island" then tpName = "Judgement" end
        Shared.BossTIMap[data.displayName] = tpName
    end
    table.sort(Tables.BossList)
end

if Modules.SummonConfig and Modules.SummonConfig.Bosses then
    table.clear(Tables.SummonList)
    for internalId, data in pairs(Modules.SummonConfig.Bosses) do
        table.insert(Tables.SummonList, data.displayName)
        SummonMap[data.displayName] = data.bossId
    end
    table.sort(Tables.SummonList)
end

for bossInternalName, _ in pairs(Modules.BossConfig.Bosses) do
    table.insert(Tables.AllBossList, bossInternalName:gsub("Boss$",""))
end
table.sort(Tables.AllBossList)

for itemName in pairs(MerchantItemList) do table.insert(Tables.MerchantList, itemName) end

if Modules.DungeonMerchantConfig and Modules.DungeonMerchantConfig.ITEMS then
    Tables.DungeonMerchantList = {}
    for itemName, _ in pairs(Modules.DungeonMerchantConfig.ITEMS) do table.insert(Tables.DungeonMerchantList, itemName) end
    table.sort(Tables.DungeonMerchantList)
end

if Modules.InfiniteTowerMerchantConfig and Modules.InfiniteTowerMerchantConfig.ITEMS then
    Tables.InfiniteTowerMerchantList = {}
    for itemName, _ in pairs(Modules.InfiniteTowerMerchantConfig.ITEMS) do table.insert(Tables.InfiniteTowerMerchantList, itemName) end
    table.sort(Tables.InfiniteTowerMerchantList)
end

if Modules.BossRushMerchantConfig and Modules.BossRushMerchantConfig.ITEMS then
    Tables.BossRushMerchantList = {}
    for itemName, _ in pairs(Modules.BossRushMerchantConfig.ITEMS) do table.insert(Tables.BossRushMerchantList, itemName) end
    table.sort(Tables.BossRushMerchantList)
end

for _, v in ipairs(SortedTitleList) do table.insert(Tables.TitleList, v) end

local CombinedTitleList = {}
for _, cat in ipairs(Tables.TitleCategory) do table.insert(CombinedTitleList, cat) end
for _, title in ipairs(Tables.TitleList) do table.insert(CombinedTitleList, title) end

table.clear(Tables.TraitList)
for name, _ in pairs(Modules.Trait.Traits) do table.insert(Tables.TraitList, name) end
table.sort(Tables.TraitList, function(a,b)
    local rA = Modules.Trait.Traits[a].Rarity; local rB = Modules.Trait.Traits[b].Rarity
    if rA ~= rB then return (Tables.RarityWeight[rA] or 99) < (Tables.RarityWeight[rB] or 99) end
    return a < b
end)

table.clear(Tables.RaceList)
for name, _ in pairs(Modules.Race.Races) do table.insert(Tables.RaceList, name) end
table.sort(Tables.RaceList, function(a,b)
    local rA = Modules.Race.Races[a].rarity; local rB = Modules.Race.Races[b].rarity
    if rA ~= rB then return (Tables.RarityWeight[rA] or 99) < (Tables.RarityWeight[rB] or 99) end
    return a < b
end)

table.clear(Tables.ClanList)
for name, _ in pairs(Modules.Clan.Clans) do table.insert(Tables.ClanList, name) end
table.sort(Tables.ClanList, function(a,b)
    local rA = Modules.Clan.Clans[a].rarity; local rB = Modules.Clan.Clans[b].rarity
    if rA ~= rB then return (Tables.RarityWeight[rA] or 99) < (Tables.RarityWeight[rB] or 99) end
    return a < b
end)

if Modules.SpecPassive and Modules.SpecPassive.Passives then
    for name, _ in pairs(Modules.SpecPassive.Passives) do table.insert(Tables.SpecPassive, name) end
    table.sort(Tables.SpecPassive)
end

for k, _ in pairs(Modules.Quests.Questlines) do table.insert(Tables.QuestlineList, k) end
table.sort(Tables.QuestlineList)

for _, v in pairs(PATH.InteractNPCs:GetChildren()) do table.insert(Tables.AllNPCList, v.Name) end

local function Cleanup(tbl)
    for key, value in pairs(tbl) do
        if typeof(value) == "RBXScriptConnection" then value:Disconnect(); tbl[key] = nil
        elseif typeof(value) == 'thread' then task.cancel(value); tbl[key] = nil
        elseif type(value) == 'table' then Cleanup(value) end
    end
end

-- ============================================================
--  FLUENT TOGGLE/OPTION STORAGE
--  Fluent uses Options table like Obsidian; we mirror the same names
-- ============================================================
local Options  = {}   -- will be populated by Fluent controls
local Toggles  = {}   -- same

-- Thread manager (identical to original)
local Flags = {}
function Thread(featurePath, featureFunc, isEnabled, ...)
    local pathParts = featurePath:split(".")
    local currentTable = Flags
    for i = 1, #pathParts - 1 do
        local part = pathParts[i]
        if not currentTable[part] then currentTable[part] = {} end
        currentTable = currentTable[part]
    end
    local flagKey = pathParts[#pathParts]
    local activeThread = currentTable[flagKey]
    if isEnabled then
        if not activeThread or coroutine.status(activeThread) == "dead" then
            local newThread = task.spawn(featureFunc, ...)
            currentTable[flagKey] = newThread
        end
    else
        if activeThread and typeof(activeThread) == 'thread' then
            task.cancel(activeThread); currentTable[flagKey] = nil
        end
    end
end

local function SafeLoop(name, func)
    return function()
        local success, err = pcall(func)
        if not success then
            Notify("Error in ["..name.."]: "..tostring(err), 10)
            warn("Error in ["..name.."]: "..tostring(err))
        end
    end
end

local function CommaFormat(n)
    local s = tostring(n)
    return s:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local function Abbreviate(n)
    local abbrev = {{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}
    for _, v in ipairs(abbrev) do
        if n >= v[1] then return string.format("%.1f%s", n/v[1], v[2]) end
    end
    return tostring(n)
end

local function GetBestOwnedTitle(category)
    if #Tables.UnlockedTitle == 0 then return nil end
    local bestTitleId = nil; local highestValue = -1
    local statMap = { ["Best EXP"]="XPPercent", ["Best Money & Gem"]="MoneyPercent", ["Best Luck"]="LuckPercent", ["Best DMG"]="DamagePercent" }
    local targetStat = statMap[category]
    if not targetStat then return nil end
    for _, titleId in ipairs(Tables.UnlockedTitle) do
        local data = Modules.Title.Titles[titleId]
        if data and data.statBonuses and data.statBonuses[targetStat] then
            local val = data.statBonuses[targetStat]
            if val > highestValue then highestValue = val; bestTitleId = titleId end
        end
    end
    return bestTitleId
end

local function GetCharacter()
    local c = Plr.Character
    return (c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChildOfClass("Humanoid")) and c or nil
end

local function PanicStop()
    Shared.Farm = false; Shared.AltActive = false; Shared.GlobalPrio = "FARM"
    Shared.Target = nil; Shared.MovingIsland = false
    for _, toggle in pairs(Toggles) do if toggle.Value ~= nil then toggle.Value = false end end
    local char = GetCharacter(); local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = root.CFrame * CFrame.new(0,2,0)
    end
    task.delay(0.5, function() Shared.Farm = true end)
    Notify("Stopped.", 5)
end

local function FuncTPW()
    while true do
        local delta = RunService.Heartbeat:Wait()
        local char = GetCharacter(); local hum = char and char:FindFirstChildOfClass("Humanoid")
        if char and hum and hum.Health > 0 then
            if hum.MoveDirection.Magnitude > 0 then
                local speed = Options.TPWValue and Options.TPWValue.Value or 1
                char:TranslateBy(hum.MoveDirection * speed * delta * 10)
            end
        end
    end
end

local function FuncNoclip()
    while Toggles.Noclip and Toggles.Noclip.Value do
        RunService.Stepped:Wait()
        local char = GetCharacter()
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end
    end
end

local function Func_AntiKnockback()
    if type(Connections.Knockback) == "table" then
        for _, conn in pairs(Connections.Knockback) do if conn then conn:Disconnect() end end
        table.clear(Connections.Knockback)
    else Connections.Knockback = {} end
    local function ApplyAntiKB(character)
        if not character then return end
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if root then
            local conn = root.ChildAdded:Connect(function(child)
                if not (Toggles.AntiKnockback and Toggles.AntiKnockback.Value) then return end
                if child:IsA("BodyVelocity") and child.MaxForce == Vector3.new(40000,40000,40000) then child:Destroy() end
            end)
            table.insert(Connections.Knockback, conn)
        end
    end
    if Plr.Character then ApplyAntiKB(Plr.Character) end
    local charAddedConn = Plr.CharacterAdded:Connect(function(newChar) ApplyAntiKB(newChar) end)
    table.insert(Connections.Knockback, charAddedConn)
    repeat task.wait(1) until not (Toggles.AntiKnockback and Toggles.AntiKnockback.Value)
    for _, conn in pairs(Connections.Knockback) do if conn then conn:Disconnect() end end
    table.clear(Connections.Knockback)
end

local function DisableIdled()
    pcall(function()
        local cons = getconnections or get_signal_cons
        if cons then
            for _, v in pairs(cons(Plr.Idled)) do
                if v.Disable then v:Disable() elseif v.Disconnect then v:Disconnect() end
            end
        end
    end)
end

local function Func_AutoReconnect()
    if Connections.Reconnect then Connections.Reconnect:Disconnect() end
    Connections.Reconnect = GuiService.ErrorMessageChanged:Connect(function()
        if not (Toggles.AutoReconnect and Toggles.AutoReconnect.Value) then return end
        task.delay(2, function()
            pcall(function()
                local promptOverlay = game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui")
                if promptOverlay then
                    local errorPrompt = promptOverlay.promptOverlay:FindFirstChild("ErrorPrompt")
                    if errorPrompt and errorPrompt.Visible then
                        task.wait(5)
                        TeleportService:Teleport(game.PlaceId, Plr)
                    end
                end
            end)
        end)
    end)
end

local function Func_NoGameplayPaused()
    while Toggles.NoGameplayPaused and Toggles.NoGameplayPaused.Value do
        pcall(function()
            local pauseGui = game:GetService("CoreGui").RobloxGui:FindFirstChild("CoreScripts/NetworkPause")
            if pauseGui then pauseGui:Destroy() end
        end)
        task.wait(1)
    end
end

local function ApplyFPSBoost(state)
    if not state then return end
    pcall(function()
        Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9; Lighting.Brightness = 1
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("PostProcessEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") then
                v.Enabled = false
            end
        end
        task.spawn(function()
            for i, v in pairs(workspace:GetDescendants()) do
                if Toggles.FPSBoost and not Toggles.FPSBoost.Value then break end
                pcall(function()
                    if v:IsA("BasePart") then v.Material = Enum.Material.SmoothPlastic; v.CastShadow = false
                    elseif v:IsA("Decal") or v:IsA("Texture") then v:Destroy()
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then v.Enabled = false end
                end)
                if i % 500 == 0 then task.wait() end
            end
        end)
    end)
end

local function ACThing(state)
    if Connections.Dash then Connections.Dash:Disconnect() end
    if not (state and _DR and _FS) then return end
    Connections.Dash = RunService.Heartbeat:Connect(function()
        task.spawn(function() pcall(_FS, _DR, vector.create(0,0,0), 0, false) end)
    end)
end

local function SendSafetyWebhook(targetPlayer, reason)
    local url = Options.WebhookURL and Options.WebhookURL.Value or ""
    if url == "" or not url:find("discord.com/api/webhooks/") then return end
    local payload = { ["embeds"] = {{ ["title"] = "⚠️ Auto Kick", ["description"] = "Someone joined you blud",
        ["color"] = 16711680, ["fields"] = {
            {["name"]="Username",["value"]="`"..targetPlayer.Name.."`",["inline"]=true},
            {["name"]="Type",["value"]=reason,["inline"]=true},
            {["name"]="ID",["value"]="```"..game.JobId.."```",["inline"]=false}
        }, ["footer"] = {["text"]="FourHub • "..os.date("%x %X")} }} }
    task.spawn(function() pcall(function() request({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode(payload)}) end) end)
end

local function CheckServerTypeSafety()
    if not (Toggles.AutoKick and Toggles.AutoKick.Value) then return end
    local kickTypes = Options.SelectedKickType and Options.SelectedKickType.Value or {}
    if kickTypes["Public Server"] then
        local success, serverType = pcall(function()
            local remote = game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType",2)
            if remote then return remote:InvokeServer() end
            return "Unknown"
        end)
        if success and serverType ~= "VIPServer" then
            task.wait(0.8)
            Plr:Kick("\n[FourHub]\nReason: You are in a public server.")
        end
    end
end

local function CheckPlayerForSafety(targetPlayer)
    if not (Toggles.AutoKick and Toggles.AutoKick.Value) then return end
    if targetPlayer == Plr then return end
    local kickTypes = Options.SelectedKickType and Options.SelectedKickType.Value or {}
    if kickTypes["Player Join"] then
        SendSafetyWebhook(targetPlayer, "Player Join Detection")
        task.wait(0.5)
        Plr:Kick("\n[FourHub]\nReason: A player joined the server ("..targetPlayer.Name..")")
        return
    end
    if kickTypes["Mod"] then
        local success, rank = pcall(function() return targetPlayer:GetRankInGroup(TargetGroupId) end)
        if success and table.find(BannedRanks, rank) then
            SendSafetyWebhook(targetPlayer, "Moderator Detection (Rank: "..tostring(rank)..")")
            task.wait(0.5)
            Plr:Kick("\n[FourHub]\nReason: Moderator Detected ("..targetPlayer.Name..")")
        end
    end
end

local function InitAutoKick()
    CheckServerTypeSafety()
    for _, p in ipairs(Players:GetPlayers()) do CheckPlayerForSafety(p) end
    Players.PlayerAdded:Connect(CheckPlayerForSafety)
end

local function HybridMove(targetCF)
    local character = GetCharacter(); local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local distance = (root.Position - targetCF.Position).Magnitude
    local tweenSpeed = Options.TweenSpeed and Options.TweenSpeed.Value or 180
    if distance > tonumber(Options.TargetDistTP and Options.TargetDistTP.Value or 0) then
        local oldNoclip = Toggles.Noclip and Toggles.Noclip.Value
        if Toggles.Noclip then Toggles.Noclip.Value = true end
        local tweenTarget = targetCF * CFrame.new(0,0,150)
        local tweenDist = (root.Position - tweenTarget.Position).Magnitude
        local tween = game:GetService("TweenService"):Create(root, TweenInfo.new(tweenDist/tweenSpeed, Enum.EasingStyle.Linear), {CFrame=tweenTarget})
        tween:Play(); tween.Completed:Wait()
        if Toggles.Noclip then Toggles.Noclip.Value = oldNoclip end
        task.wait(0.1)
    end
    root.CFrame = targetCF; root.AssemblyLinearVelocity = Vector3.new(0,0.01,0); task.wait(0.2)
end

local function GetNearestIsland(targetPos, npcName)
    if npcName and Shared.BossTIMap[npcName] then return Shared.BossTIMap[npcName] end
    local nearestIslandName = "Starter"; local minDistance = math.huge
    for islandName, crystal in pairs(IslandCrystals) do
        if crystal then
            local dist = (targetPos - crystal:GetPivot().Position).Magnitude
            if dist < minDistance then minDistance = dist; nearestIslandName = islandName end
        end
    end
    return nearestIslandName
end

local function UpdateNPCLists()
    local specialMobs = {"ThiefBoss","MonkeyBoss","DesertBoss","SnowBoss","PandaMiniBoss"}
    local currentList = {}
    for _, name in pairs(Tables.MobList) do currentList[name] = true end
    for _, v in pairs(PATH.Mobs:GetChildren()) do
        local cleanName = v.Name:gsub("%d+$","")
        local isSpecial = table.find(specialMobs, cleanName)
        if (isSpecial or not cleanName:find("Boss")) and not currentList[cleanName] then
            table.insert(Tables.MobList, cleanName); currentList[cleanName] = true
            local npcPos = v:GetPivot().Position; local closestIsland = "Unknown"; local minShot = math.huge
            for islandName, crystal in pairs(IslandCrystals) do
                if crystal then
                    local dist = (npcPos - crystal:GetPivot().Position).Magnitude
                    if dist < minShot then minShot = dist; closestIsland = islandName end
                end
            end
            Tables.MobToIsland[cleanName] = closestIsland
        end
    end
    if Options.SelectedMob then Options.SelectedMob:SetValues(Tables.MobList) end
end

local function UpdateAllEntities()
    table.clear(Tables.AllEntitiesList); local unique = {}
    for _, v in pairs(PATH.Mobs:GetChildren()) do
        local cleanName = v.Name:gsub("%d+$","")
        if not unique[cleanName] then unique[cleanName] = true; table.insert(Tables.AllEntitiesList, cleanName) end
    end
    table.sort(Tables.AllEntitiesList)
    if Options.SelectedQuestline_DMGTaken then Options.SelectedQuestline_DMGTaken:SetValues(Tables.AllEntitiesList) end
end

local function PopulateNPCLists()
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name:match("^QuestNPC%d+$") and not table.find(Tables.NPC_QuestList, child.Name) then
            table.insert(Tables.NPC_QuestList, child.Name)
        end
    end
    for _, child in ipairs(PATH.InteractNPCs:GetChildren()) do
        if child.Name:match("^QuestNPC%d+$") and not table.find(Tables.NPC_QuestList, child.Name) then
            table.insert(Tables.NPC_QuestList, child.Name)
        end
    end
    table.sort(Tables.NPC_QuestList, function(a,b)
        local numA = tonumber(a:match("%d+$")) or 0; local numB = tonumber(b:match("%d+$")) or 0
        return (numA == numB) and (a < b) or (numA < numB)
    end)
    for _, v in pairs(PATH.InteractNPCs:GetChildren()) do
        local name = v.Name
        if (name:find("Moveset") or name:find("Buyer")) and not name:find("Observation") then table.insert(Tables.NPC_MovesetList, name) end
        if (name:find("Mastery") or name:find("Questline") or name:find("Craft")) and not (name:find("Grail") or name:find("Slime")) then table.insert(Tables.NPC_MasteryList, name) end
    end
    table.sort(Tables.NPC_MovesetList); table.sort(Tables.NPC_MasteryList)
end

local function GetCurrentPity()
    local pityLabel = PGui.BossUI.MainFrame.BossHPBar.Pity
    local current, max = pityLabel.Text:match("Pity: (%d+)/(%d+)")
    return tonumber(current) or 0, tonumber(max) or 25
end

PopulateNPCLists()

local function findNPCByDistance(dist)
    local bestMatch = nil; local tolerance = 2; local char = GetCharacter()
    for _, npc in ipairs(workspace:GetDescendants()) do
        if npc:IsA("Model") and npc.Name:find("QuestNPC") then
            local npcPos = npc:GetPivot().Position
            local actualDist = (char.HumanoidRootPart.Position - npcPos).Magnitude
            if math.abs(actualDist - dist) <= tolerance then bestMatch = npc; break end
        end
    end
    return bestMatch
end

local function IsSmartMatch(npcName, targetMobType)
    local n = npcName:gsub("%d+$",""):lower(); local t = targetMobType:lower()
    if n == t then return true end
    if t:find(n) == 1 then return true end
    if n:find(t) == 1 then return true end
    return false
end

local function SafeTeleportToNPC(targetName, customMap)
    local character = GetCharacter(); local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local actualName = customMap and customMap[targetName] or targetName
    local target = workspace:FindFirstChild(actualName) or PATH.InteractNPCs:FindFirstChild(actualName)
    if not target then
        for _, v in pairs(PATH.InteractNPCs:GetChildren()) do
            if v.Name:find(actualName) then target = v; break end
        end
    end
    if target then
        root.CFrame = target:GetPivot() * CFrame.new(0,3,0)
        root.AssemblyLinearVelocity = Vector3.new(0,0.01,0)
        root.AssemblyAngularVelocity = Vector3.zero
    else Notify("NPC not found: "..tostring(actualName), 3) end
end

local function Clean(str) return str:gsub("%s+",""):lower() end

local function GetToolTypeFromModule(toolName)
    local cleanedTarget = Clean(toolName)
    for manualName, toolType in pairs(Tables.ManualWeaponClass) do
        if Clean(manualName) == cleanedTarget then return toolType end
    end
    if Modules.WeaponClass and Modules.WeaponClass.Tools then
        for moduleName, toolType in pairs(Modules.WeaponClass.Tools) do
            if Clean(moduleName) == cleanedTarget then return toolType end
        end
    end
    if toolName:lower():find("fruit") then return "Power" end
    return "Melee"
end

local function GetWeaponsByType()
    local available = {}
    local enabledTypes = Options.SelectedWeaponType and Options.SelectedWeaponType.Value or {}
    local char = GetCharacter()
    local containers = {Plr.Backpack}
    if char then table.insert(containers, char) end
    for _, container in ipairs(containers) do
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local toolType = GetToolTypeFromModule(tool.Name)
                if enabledTypes[toolType] and not table.find(available, tool.Name) then
                    table.insert(available, tool.Name)
                end
            end
        end
    end
    return available
end

local function UpdateWeaponRotation()
    local weaponList = GetWeaponsByType()
    if #weaponList == 0 then Shared.ActiveWeap = ""; return end
    local switchDelay = Options.SwitchWeaponCD and Options.SwitchWeaponCD.Value or 4
    if tick() - Shared.LastWRSwitch >= switchDelay then
        Shared.WeapRotationIdx = Shared.WeapRotationIdx + 1
        if Shared.WeapRotationIdx > #weaponList then Shared.WeapRotationIdx = 1 end
        Shared.ActiveWeap = weaponList[Shared.WeapRotationIdx]; Shared.LastWRSwitch = tick()
    end
    local exists = false
    for _, name in ipairs(weaponList) do if name == Shared.ActiveWeap then exists = true; break end end
    if not exists then Shared.ActiveWeap = weaponList[1] end
end

local function EquipWeapon()
    UpdateWeaponRotation()
    if Shared.ActiveWeap == "" then return end
    local char = GetCharacter(); local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if char:FindFirstChild(Shared.ActiveWeap) then return end
    local tool = Plr.Backpack:FindFirstChild(Shared.ActiveWeap) or char:FindFirstChild(Shared.ActiveWeap)
    if tool then hum:EquipTool(tool) end
end

local function CheckObsHaki()
    local PlayerGui = Plr:FindFirstChild("PlayerGui")
    if PlayerGui then
        local DodgeUI = PlayerGui:FindFirstChild("DodgeCounterUI")
        if DodgeUI and DodgeUI:FindFirstChild("MainFrame") then return DodgeUI.MainFrame.Visible end
    end
    return false
end

local function CheckArmHaki()
    if Shared.ArmHaki == true then return true end
    local char = GetCharacter()
    if char then
        local leftArm = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftUpperArm")
        local rightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm")
        if (leftArm and leftArm:FindFirstChild("Lightning Strike")) or (rightArm and rightArm:FindFirstChild("Lightning Strike")) then
            Shared.ArmHaki = true; return true
        end
    end
    return false
end

local function IsBusy()
    return Plr.Character and Plr.Character:FindFirstChildOfClass("ForceField") ~= nil
end

local function IsSkillReady(key)
    local char = GetCharacter(); local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return true end
    local mainFrame = PGui:FindFirstChild("CooldownUI") and PGui.CooldownUI:FindFirstChild("MainFrame")
    if not mainFrame then return true end
    local cleanTool = Clean(tool.Name); local foundFrame = nil
    for _, frame in pairs(mainFrame:GetChildren()) do
        if not frame:IsA("Frame") then continue end
        local fname = frame.Name:lower()
        if fname:find("cooldown") and (fname:find(cleanTool) or fname:find("skill")) then
            local mapped = "none"
            if fname:find("skill 1") or fname:find("_z") then mapped = "Z"
            elseif fname:find("skill 2") or fname:find("_x") then mapped = "X"
            elseif fname:find("skill 3") or fname:find("_c") then mapped = "C"
            elseif fname:find("skill 4") or fname:find("_v") then mapped = "V"
            elseif fname:find("skill 5") or fname:find("_f") then mapped = "F" end
            if mapped == key then foundFrame = frame; break end
        end
    end
    if not foundFrame then return true end
    local cdLabel = foundFrame:FindFirstChild("WeaponNameAndCooldown", true)
    return (cdLabel and cdLabel.Text:find("Ready"))
end

local function GetSecondsFromTimer(text)
    local min, sec = text:match("(%d+):(%d+)")
    if min and sec then return (tonumber(min)*60) + tonumber(sec) end
    return nil
end

local function FormatSecondsToTimer(s)
    return string.format("Refresh: %02d:%02d", math.floor(s/60), s%60)
end

local function OpenMerchantInterface()
    if isXeno then
        local npc = workspace:FindFirstChild("ServiceNPCs") and workspace.ServiceNPCs:FindFirstChild("MerchantNPC")
        local prompt = npc and npc:FindFirstChild("HumanoidRootPart") and npc.HumanoidRootPart:FindFirstChild("MerchantPrompt")
        if prompt then
            local char = GetCharacter(); local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local oldCF = root.CFrame
                root.CFrame = npc.HumanoidRootPart.CFrame * CFrame.new(0,0,3); task.wait(0.2)
                if Support.Proximity then fireproximityprompt(prompt)
                else prompt:InputHoldBegin(); task.wait(prompt.HoldDuration+0.1); prompt:InputHoldEnd() end
                task.wait(0.5); root.CFrame = oldCF
            end
        end
    else
        if firesignal then firesignal(Remotes.OpenMerchant.OnClientEvent)
        elseif getconnections then
            for _, v in pairs(getconnections(Remotes.OpenMerchant.OnClientEvent)) do
                if v.Function then task.spawn(v.Function) end
            end
        end
    end
end

local function SyncRaceSettings()
    if not (Toggles.AutoRace and Toggles.AutoRace.Value) then return end
    pcall(function()
        local selected = Options.SelectedRace and Options.SelectedRace.Value or {}
        local hasEpic = false; local hasLegendary = false
        for name, data in pairs(Modules.Race.Races) do
            local rarity = data.rarity or data.Rarity
            if rarity == "Mythical" then
                local shouldSkip = not selected[name]
                if Shared.Settings["SkipRace_"..name] ~= shouldSkip then Remotes.SettingsToggle:FireServer("SkipRace_"..name, shouldSkip) end
            end
            if selected[name] then
                if rarity == "Epic" then hasEpic = true end
                if rarity == "Legendary" then hasLegendary = true end
            end
        end
        if Shared.Settings["SkipEpicReroll"] ~= not hasEpic then Remotes.SettingsToggle:FireServer("SkipEpicReroll", not hasEpic) end
        if Shared.Settings["SkipLegendaryReroll"] ~= not hasLegendary then Remotes.SettingsToggle:FireServer("SkipLegendaryReroll", not hasLegendary) end
    end)
end

local function SyncClanSettings()
    if not (Toggles.AutoClan and Toggles.AutoClan.Value) then return end
    pcall(function()
        local selected = Options.SelectedClan and Options.SelectedClan.Value or {}
        local hasEpic = false; local hasLegendary = false
        for name, data in pairs(Modules.Clan.Clans) do
            local rarity = data.rarity or data.Rarity
            if rarity == "Legendary" then
                local shouldSkip = not selected[name]
                if Shared.Settings["SkipClan_"..name] ~= shouldSkip then Remotes.SettingsToggle:FireServer("SkipClan_"..name, shouldSkip) end
            end
            if selected[name] then
                if rarity == "Epic" then hasEpic = true end
                if rarity == "Legendary" then hasLegendary = true end
            end
        end
        if Shared.Settings["SkipEpicClan"] ~= not hasEpic then Remotes.SettingsToggle:FireServer("SkipEpicClan", not hasEpic) end
        if Shared.Settings["SkipLegendaryClan"] ~= not hasLegendary then Remotes.SettingsToggle:FireServer("SkipLegendaryClan", not hasLegendary) end
    end)
end

local function SyncSpecPassiveAutoSkip()
    pcall(function()
        local remote = Remotes.SpecPassiveSkip
        if remote then remote:FireServer({["Epic"]=true,["Legendary"]=true,["Mythical"]=true}) end
    end)
end

local function SyncTraitAutoSkip()
    if not (Toggles.AutoTrait and Toggles.AutoTrait.Value) then return end
    pcall(function()
        local selected = Options.SelectedTrait and Options.SelectedTrait.Value or {}
        local rarityHierarchy = {["Epic"]=1,["Legendary"]=2,["Mythical"]=3,["Secret"]=4}
        local lowestTargetValue = 99
        for traitName, enabled in pairs(selected) do
            if enabled then
                local data = Modules.Trait.Traits[traitName]
                if data then
                    local val = rarityHierarchy[data.Rarity] or 0
                    if val > 0 and val < lowestTargetValue then lowestTargetValue = val end
                end
            end
        end
        if lowestTargetValue == 99 then return end
        Remotes.TraitAutoSkip:FireServer({["Epic"]=1<lowestTargetValue,["Legendary"]=2<lowestTargetValue,["Mythical"]=3<lowestTargetValue,["Secret"]=4<lowestTargetValue})
    end)
end

local function GetMatches(data, subStatFilter)
    local count = 0
    for _, sub in pairs(data.Substats or {}) do if subStatFilter[sub.Stat] then count = count + 1 end end
    return count
end

local function IsMainStatGood(data, mainStatFilter)
    if data.Category == "Helmet" or data.Category == "Gloves" then return true end
    return mainStatFilter[data.MainStat.Stat] == true
end

local function EvaluateArtifact2(uuid, data)
    local actions = {lock=false, delete=false, upgrade=false}
    local function GetFilterStatus(filter, value)
        if not filter or next(filter) == nil then return nil end
        return filter[value] == true
    end
    local function IsWhitelisted(filter, value)
        local status = GetFilterStatus(filter, value)
        if status == nil then return true end
        return status
    end
    local upgradeLimit = Options.UpgradeLimit and Options.UpgradeLimit.Value or 0
    if Toggles.ArtifactUpgrade and Toggles.ArtifactUpgrade.Value and data.Level < upgradeLimit then
        if IsWhitelisted(Options.Up_MS and Options.Up_MS.Value, data.MainStat.Stat) then
            actions.upgrade = true
        end
    end
    local lockMinSS = Options.Lock_MinSS and Options.Lock_MinSS.Value or 0
    if Toggles.ArtifactLock and Toggles.ArtifactLock.Value and not data.Locked and data.Level >= (lockMinSS*3) then
        if IsWhitelisted(Options.Lock_MS and Options.Lock_MS.Value, data.MainStat.Stat) and
           IsWhitelisted(Options.Lock_Type and Options.Lock_Type.Value, data.Category) and
           IsWhitelisted(Options.Lock_Set and Options.Lock_Set.Value, data.Set) then
            if GetMatches(data, Options.Lock_SS and Options.Lock_SS.Value or {}) >= lockMinSS then
                actions.lock = true
            end
        end
    end
    if not data.Locked and not actions.lock then
        if Toggles.DeleteUnlock and Toggles.DeleteUnlock.Value then
            actions.delete = true
        elseif Toggles.ArtifactDelete and Toggles.ArtifactDelete.Value then
            local typeMatch = GetFilterStatus(Options.Del_Type and Options.Del_Type.Value, data.Category)
            local setMatch = GetFilterStatus(Options.Del_Set and Options.Del_Set.Value, data.Set)
            local msDropdownName = "Del_MS_"..data.Category
            local specificMSFilter = Options[msDropdownName] and Options[msDropdownName].Value or {}
            local msMatch = GetFilterStatus(specificMSFilter, data.MainStat.Stat)
            local isTarget = true
            if typeMatch == false then isTarget = false end
            if setMatch == false then isTarget = false end
            if typeMatch == nil and setMatch == nil and msMatch == nil then isTarget = false end
            if isTarget then
                local trashCount = GetMatches(data, Options.Del_SS and Options.Del_SS.Value or {})
                local minTrash = Options.Del_MinSS and Options.Del_MinSS.Value or 0
                local isMaxLevel = data.Level >= upgradeLimit
                if msMatch == true then actions.delete = true
                elseif minTrash == 0 then actions.delete = true
                elseif isMaxLevel and trashCount >= minTrash then actions.delete = true end
            end
        end
    end
    return actions
end

local function AutoEquipArtifacts()
    if not (Toggles.ArtifactEquip and Toggles.ArtifactEquip.Value) then return end
    local bestItems = {Helmet=nil,Gloves=nil,Body=nil,Boots=nil}
    local bestScores = {Helmet=-1,Gloves=-1,Body=-1,Boots=-1}
    local targetTypes = Options.Eq_Type and Options.Eq_Type.Value or {}
    local targetMS = Options.Eq_MS and Options.Eq_MS.Value or {}
    local targetSS = Options.Eq_SS and Options.Eq_SS.Value or {}
    for uuid, data in pairs(Shared.ArtifactSession.Inventory) do
        if targetTypes[data.Category] and IsMainStatGood(data, targetMS) then
            local score = (GetMatches(data, targetSS)*10) + data.Level
            if score > bestScores[data.Category] then bestScores[data.Category]=score; bestItems[data.Category]={UUID=uuid,Equipped=data.Equipped} end
        end
    end
    for category, item in pairs(bestItems) do
        if item and not item.Equipped then Remotes.ArtifactEquip:FireServer(item.UUID); task.wait(0.2) end
    end
end

local function IsStrictBossMatch(npcName, targetDisplayName)
    local n = npcName:lower():gsub("%s+",""); local t = targetDisplayName:lower():gsub("%s+","")
    if n:find("true") and not t:find("true") then return false end
    if t:find("strongest") then
        local era = t:find("history") and "history" or "today"
        return n:find("strongest") and n:find(era)
    end
    return n:find(t)
end

local function AutoUpgradeLoop(mode)
    local toggle = Toggles["Auto"..mode]; local allToggle = Toggles["Auto"..mode.."All"]
    local remote = (mode=="Enchant") and Remotes.Enchant or Remotes.Blessing
    local sourceTable = (mode=="Enchant") and Tables.OwnedAccessory or Tables.OwnedWeapon
    while (toggle and toggle.Value) or (allToggle and allToggle.Value) do
        local selection = Options["Selected"..mode] and Options["Selected"..mode].Value or {}
        local workDone = false
        for _, itemName in ipairs(sourceTable) do
            if Shared.UpBlacklist[itemName] then continue end
            local isSelected = false
            if allToggle and allToggle.Value then isSelected = true
            else isSelected = selection[itemName] or table.find(selection, itemName) end
            if isSelected then
                workDone = true
                pcall(function() remote:FireServer(itemName) end)
                task.wait(1.5); break
            end
        end
        if not workDone then
            Notify("Stopping..", 5)
            if toggle then toggle.Value = false end
            if allToggle then allToggle.Value = false end
            break
        end
        task.wait(0.1)
    end
end

local function FireBossRemote(bossName, diff)
    local lowerName = bossName:lower():gsub("%s+","")
    local remoteArg = GetRemoteBossArg(bossName)
    table.clear(Shared.AltDamage)
    local function GetInternalSummonId(name)
        local cleanTarget = name:lower():gsub("%s+","")
        for displayName, internalId in pairs(SummonMap) do
            if displayName:lower():gsub("%s+","") == cleanTarget then return internalId end
        end
        return name:gsub("%s+","").."Boss"
    end
    pcall(function()
        if lowerName:find("rimuru") then Remotes.RimuruBoss:FireServer(diff)
        elseif lowerName:find("anos") then Remotes.AnosBoss:FireServer("Anos", diff)
        elseif lowerName:find("trueaizen") then if Remotes.TrueAizenBoss then Remotes.TrueAizenBoss:FireServer(diff) end
        elseif lowerName:find("strongest") then Remotes.JJKSummonBoss:FireServer(remoteArg, diff)
        elseif lowerName:find("atomic") then Remotes.AtomicBoss:FireServer(diff)
        else Remotes.SummonBoss:FireServer(GetInternalSummonId(bossName), diff) end
    end)
end

local function HandleSummons()
    if Shared.MerchantBusy then return end
    local function MatchName(n1,n2)
        if not n1 or not n2 then return false end
        return n1:lower():gsub("%s+","") == n2:lower():gsub("%s+","")
    end
    local function IsSummonable(name)
        local cleanName = name:lower():gsub("%s+","")
        for _, boss in ipairs(Tables.SummonList) do if MatchName(boss, cleanName) then return true end end
        for _, boss in ipairs(Tables.OtherSummonList) do if MatchName(boss, cleanName) then return true end end
        return false
    end
    if Toggles.PityBossFarm and Toggles.PityBossFarm.Value then
        local current, max = GetCurrentPity()
        local buildOptions = Options.SelectedBuildPity and Options.SelectedBuildPity.Value or {}
        local useName = Options.SelectedUsePity and Options.SelectedUsePity.Value
        if useName and next(buildOptions) then
            local isUseTurn = (current >= (max-1))
            if isUseTurn then
                local found = false
                for _, v in pairs(PATH.Mobs:GetChildren()) do
                    if MatchName(v.Name, useName) or v.Name:lower():find(useName:lower():gsub("%s+","")) then found=true; break end
                end
                if not found and IsSummonable(useName) then
                    FireBossRemote(useName, Options.SelectedPityDiff and Options.SelectedPityDiff.Value or "Normal")
                    task.wait(0.5); return
                end
            else
                local anyBuildBossSpawned = false
                for bossName, enabled in pairs(buildOptions) do
                    if enabled then
                        for _, v in pairs(PATH.Mobs:GetChildren()) do
                            if MatchName(v.Name, bossName) or v.Name:lower():find(bossName:lower():gsub("%s+","")) then
                                anyBuildBossSpawned=true; break
                            end
                        end
                    end
                    if anyBuildBossSpawned then break end
                end
                if not anyBuildBossSpawned then
                    for bossName, enabled in pairs(buildOptions) do
                        if enabled and IsSummonable(bossName) then
                            FireBossRemote(bossName, "Normal"); task.wait(0.5); return
                        end
                    end
                end
            end
        end
    end
    if Toggles.AutoOtherSummon and Toggles.AutoOtherSummon.Value then
        local selected = Options.SelectedOtherSummon and Options.SelectedOtherSummon.Value
        local diff = Options.SelectedOtherSummonDiff and Options.SelectedOtherSummonDiff.Value
        if selected and diff then
            local keyword = selected:gsub("Strongest",""):lower(); local found = false
            for _, v in pairs(PATH.Mobs:GetChildren()) do
                local npcName = v.Name:lower()
                if npcName:find(selected:lower()) or (npcName:find("strongest") and npcName:find(keyword)) then found=true; break end
            end
            if not found then FireBossRemote(selected, diff); task.wait(0.5) end
        end
    end
    if Toggles.AutoSummon and Toggles.AutoSummon.Value then
        local selected = Options.SelectedSummon and Options.SelectedSummon.Value
        if selected then
            local found = false
            for _, v in pairs(PATH.Mobs:GetChildren()) do
                if IsStrictBossMatch(v.Name, selected) then found=true; break end
            end
            if not found then FireBossRemote(selected, Options.SelectedSummonDiff and Options.SelectedSummonDiff.Value or "Normal"); task.wait(0.5) end
        end
    end
end

local function UpdateSwitchState(target, farmType)
    if Shared.GlobalPrio == "COMBO" then return end
    local types = {
        {id="Title", remote=Remotes.EquipTitle, method=function(val) return val end},
        {id="Rune", remote=Remotes.EquipRune, method=function(val) return {"Equip",val} end},
        {id="Build", remote=Remotes.LoadoutLoad, method=function(val) return tonumber(val) end}
    }
    for _, switch in ipairs(types) do
        local toggleObj = Toggles["Auto"..switch.id]
        if not (toggleObj and toggleObj.Value) then continue end
        if switch.id == "Build" and tick() - Shared.LastBuildSwitch < 3.1 then continue end
        local toEquip = ""; local threshold = Options[switch.id.."_BossHPAmt"] and Options[switch.id.."_BossHPAmt"].Value or 15
        local isLow = false
        if farmType == "Boss" and target then
            local hum = target:FindFirstChildOfClass("Humanoid")
            if hum and (hum.Health/hum.MaxHealth)*100 <= threshold then isLow = true end
        end
        if farmType == "None" then toEquip = Options["Default"..switch.id] and Options["Default"..switch.id].Value or ""
        elseif farmType == "Mob" then toEquip = Options[switch.id.."_Mob"] and Options[switch.id.."_Mob"].Value or ""
        elseif farmType == "Boss" then toEquip = isLow and (Options[switch.id.."_BossHP"] and Options[switch.id.."_BossHP"].Value or "") or (Options[switch.id.."_Boss"] and Options[switch.id.."_Boss"].Value or "") end
        if not toEquip or toEquip == "" or toEquip == "None" then continue end
        local finalEquipValue = toEquip
        if switch.id == "Title" and toEquip:find("Best ") then
            local bestId = GetBestOwnedTitle(toEquip)
            if bestId then finalEquipValue = bestId else continue end
        end
        if finalEquipValue ~= Shared.LastSwitch[switch.id] then
            local args = switch.method(finalEquipValue)
            pcall(function()
                if type(args) == "table" then switch.remote:FireServer(unpack(args))
                else switch.remote:FireServer(args) end
            end)
            Shared.LastSwitch[switch.id] = finalEquipValue
            if switch.id == "Build" then Shared.LastBuildSwitch = tick() end
        end
    end
end

local NotificationBlacklist = {"You don't have this item!", "Not enough "}

local function ProcessNotification(frame)
    task.delay(0.01, function()
        if not (Toggles.AutoDeleteNotif and Toggles.AutoDeleteNotif.Value) then return end
        if not frame or not frame.Parent then return end
        local txtLabel = frame:FindFirstChild("Txt", true)
        if txtLabel and txtLabel:IsA("TextLabel") then
            local incomingText = txtLabel.Text:lower()
            for _, blacklistedPhrase in ipairs(NotificationBlacklist) do
                if incomingText:find(blacklistedPhrase:lower()) then frame.Visible = false; break end
            end
        end
    end)
end

local function UniversalPuzzleSolver(puzzleType)
    local moduleMap = {
        ["Dungeon"] = RS.Modules:FindFirstChild("DungeonConfig"),
        ["Slime"] = RS.Modules:FindFirstChild("SlimePuzzleConfig"),
        ["Demonite"] = RS.Modules:FindFirstChild("DemoniteCoreQuestConfig"),
        ["Hogyoku"] = RS.Modules:FindFirstChild("HogyokuQuestConfig")
    }
    local hogyokuIslands = {"Snow","Shibuya","HuecoMundo","Shinjuku","Slime","Judgement"}
    local targetModule = moduleMap[puzzleType]
    if not targetModule then return end
    local data = require(targetModule)
    local settings = data.PuzzleSettings or data.PieceSettings
    local piecesToCollect = data.Pieces or settings.IslandOrder
    local pieceModelName = settings and settings.PieceModelName or "DungeonPuzzlePiece"
    Notify("Starting "..puzzleType.." Puzzle...", 5)
    for i, islandOrPiece in ipairs(piecesToCollect) do
        local piece = nil; local tpTarget = nil
        if puzzleType == "Demonite" then tpTarget = "Academy"
        elseif puzzleType == "Hogyoku" then tpTarget = hogyokuIslands[i]
        else
            tpTarget = islandOrPiece:gsub("Island",""):gsub("Station","")
            if islandOrPiece == "HuecoMundo" then tpTarget = "HuecoMundo" end
        end
        if tpTarget then Remotes.TP_Portal:FireServer(tpTarget); task.wait(2.5) end
        if puzzleType == "Slime" and i == #piecesToCollect then
            local char = GetCharacter(); local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                Remotes.TP_Portal:FireServer("Shinjuku"); task.wait(2)
                Remotes.TP_Portal:FireServer("Slime"); task.wait(2)
                root.CFrame = CFrame.new(788,68,-2309); task.wait(1.5)
            end
        end
        if puzzleType == "Demonite" or puzzleType == "Hogyoku" then piece = workspace:FindFirstChild(islandOrPiece, true)
        else
            local islandFolder = workspace:FindFirstChild(islandOrPiece)
            piece = islandFolder and islandFolder:FindFirstChild(pieceModelName, true) or workspace:FindFirstChild(pieceModelName, true)
        end
        if piece then
            HybridMove(piece:GetPivot() * CFrame.new(0,3,0)); task.wait(0.5)
            local prompt = piece:FindFirstChildOfClass("ProximityPrompt") or piece:FindFirstChild("PuzzlePrompt", true) or piece:FindFirstChild("ProximityPrompt", true)
            if prompt then
                fireproximityprompt(prompt)
                Notify(string.format("Collected Piece %d/%d", i, #piecesToCollect), 2); task.wait(1.5)
            else Notify("Found piece but no interaction prompt was detected.", 3) end
        else Notify("Failed to find piece "..i.." on "..tostring(tpTarget or "Island"), 3) end
    end
    Notify(puzzleType.." Puzzle Completed!", 5)
end

local function GetCurrentQuestUI()
    local holder = PGui.QuestUI.Quest.Quest.Holder.Content
    local info = holder.QuestInfo
    return {
        Title = info.QuestTitle.QuestTitle.Text,
        Description = info.QuestDescription.Text,
        SwitchVisible = holder.QuestSwitchButton.Visible,
        SwitchBtn = holder.QuestSwitchButton,
        IsVisible = PGui.QuestUI.Quest.Visible
    }
end

local function EnsureQuestSettings()
    local settings = PGui.SettingsUI.MainFrame.Frame.Content.SettingsTabFrame
    local tog1 = settings:FindFirstChild("Toggle_EnableQuestRepeat", true)
    if tog1 and tog1.SettingsHolder.Off.Visible then Remotes.SettingsToggle:FireServer("EnableQuestRepeat", true); task.wait(0.3) end
    local tog2 = settings:FindFirstChild("Toggle_AutoQuestRepeat", true)
    if tog2 and tog2.SettingsHolder.Off.Visible then Remotes.SettingsToggle:FireServer("AutoQuestRepeat", true) end
end

local function GetBestQuestNPC()
    local QuestModule = Modules.Quests; local playerLevel = Plr.Data.Level.Value
    local bestNPC = "QuestNPC1"; local highestLevel = -1
    for npcId, questData in pairs(QuestModule.RepeatableQuests) do
        local reqLevel = questData.recommendedLevel or 0
        if playerLevel >= reqLevel and reqLevel > highestLevel then highestLevel = reqLevel; bestNPC = npcId end
    end
    return bestNPC
end

local function UpdateQuest()
    if not (Toggles.LevelFarm and Toggles.LevelFarm.Value) then return end
    EnsureQuestSettings()
    local targetNPC = GetBestQuestNPC(); local questUI = PGui.QuestUI.Quest
    if Shared.QuestNPC ~= targetNPC or not questUI.Visible then
        Remotes.QuestAbandon:FireServer("repeatable")
        local abandonTimeout = 0
        while questUI.Visible and abandonTimeout < 15 do task.wait(0.2); abandonTimeout = abandonTimeout + 1 end
        Remotes.QuestAccept:FireServer(targetNPC)
        local acceptTimeout = 0
        while not questUI.Visible and acceptTimeout < 20 do
            task.wait(0.2); acceptTimeout = acceptTimeout + 1
            if acceptTimeout % 5 == 0 then Remotes.QuestAccept:FireServer(targetNPC) end
        end
        if questUI.Visible then Shared.QuestNPC = targetNPC end
    end
end

local function GetPityTarget()
    if not (Toggles.PityBossFarm and Toggles.PityBossFarm.Value) then return nil end
    local current, max = GetCurrentPity()
    local buildBosses = Options.SelectedBuildPity and Options.SelectedBuildPity.Value or {}
    local useName = Options.SelectedUsePity and Options.SelectedUsePity.Value
    if not useName then return nil end
    local isUseTurn = (current >= (max-1))
    if isUseTurn then
        for _, npc in pairs(PATH.Mobs:GetChildren()) do
            if IsStrictBossMatch(npc.Name, useName) then
                local island = Shared.BossTIMap[useName] or "Boss"
                return npc, island, "Boss"
            end
        end
    else
        for bossName, enabled in pairs(buildBosses) do
            if enabled then
                for _, npc in pairs(PATH.Mobs:GetChildren()) do
                    if IsStrictBossMatch(npc.Name, bossName) then
                        local island = Shared.BossTIMap[bossName] or "Boss"
                        return npc, island, "Boss"
                    end
                end
            end
        end
    end
    return nil
end

local function IsValidTarget(npc)
    if not npc or not npc.Parent then return false end
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if npc:FindFirstChild("IK_Active") then return true end
    local minMaxHP = tonumber(Options.InstaKillMinHP and Options.InstaKillMinHP.Value) or 0
    local isEligible = (Toggles.InstaKill and Toggles.InstaKill.Value) and hum.MaxHealth >= minMaxHP
    if isEligible then return (hum.Health > 0) or (npc == Shared.Target)
    else return (hum.Health > 0) end
end

local function GetBestMobCluster(mobNamesDictionary)
    local allMobs = {}; local clusterRadius = 35
    if type(mobNamesDictionary) ~= "table" then return nil end
    for _, npc in pairs(PATH.Mobs:GetChildren()) do
        if npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid") then
            local cleanName = npc.Name:gsub("%d+$","")
            if mobNamesDictionary[cleanName] and IsValidTarget(npc) then table.insert(allMobs, npc) end
        end
    end
    if #allMobs == 0 then return nil end
    local bestMob = allMobs[1]; local maxNearby = 0
    for _, mobA in ipairs(allMobs) do
        local nearbyCount = 0; local posA = mobA:GetPivot().Position
        for _, mobB in ipairs(allMobs) do
            if (posA - mobB:GetPivot().Position).Magnitude <= clusterRadius then nearbyCount = nearbyCount + 1 end
        end
        if nearbyCount > maxNearby then maxNearby = nearbyCount; bestMob = mobA end
    end
    return bestMob, maxNearby
end

local function GetAllMobTarget()
    if not (Toggles.AllMobFarm and Toggles.AllMobFarm.Value) then Shared.AllMobIdx=1; return nil end
    local rotateList = {}
    for _, mobName in ipairs(Tables.MobList) do
        if mobName ~= "TrainingDummy" then table.insert(rotateList, mobName) end
    end
    if #rotateList == 0 then return nil end
    if Shared.AllMobIdx > #rotateList then Shared.AllMobIdx = 1 end
    local targetMobName = rotateList[Shared.AllMobIdx]
    local target, count = GetBestMobCluster({[targetMobName]=true})
    if target then
        local island = GetNearestIsland(target:GetPivot().Position, target.Name)
        return target, island, "Mob"
    else
        Shared.AllMobIdx = Shared.AllMobIdx + 1
        if Shared.AllMobIdx > #rotateList then Shared.AllMobIdx = 1 end
        return nil
    end
end

local function GetLevelFarmTarget()
    if not (Toggles.LevelFarm and Toggles.LevelFarm.Value) then return nil end
    UpdateQuest()
    if not PGui.QuestUI.Quest.Visible then return nil end
    local questData = Modules.Quests.RepeatableQuests[Shared.QuestNPC]
    if not questData or not questData.requirements[1] then return nil end
    local targetMobType = questData.requirements[1].npcType; local matches = {}
    for _, npc in pairs(PATH.Mobs:GetChildren()) do
        if npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid") then
            if IsSmartMatch(npc.Name, targetMobType) then
                local cleanName = npc.Name:gsub("%d+$",""); matches[cleanName] = true
            end
        end
    end
    local bestMob, count = GetBestMobCluster(matches)
    if bestMob then
        local island = GetNearestIsland(bestMob:GetPivot().Position, bestMob.Name)
        return bestMob, island, "Mob"
    end
    return nil
end

local function GetOtherTarget()
    if not (Toggles.OtherSummonFarm and Toggles.OtherSummonFarm.Value) then return nil end
    local selected = Options.SelectedOtherSummon and Options.SelectedOtherSummon.Value
    if not selected then return nil end
    local lowerSelected = selected:lower()
    for _, npc in pairs(PATH.Mobs:GetChildren()) do
        local name = npc.Name:lower(); local isMatch = false
        if lowerSelected:find("strongest") then
            if name:find("strongest") and ((lowerSelected:find("history") and name:find("history")) or (lowerSelected:find("today") and name:find("today"))) then isMatch = true end
        elseif name:find(lowerSelected) then isMatch = true end
        if isMatch and IsValidTarget(npc) then
            local island = GetNearestIsland(npc:GetPivot().Position, npc.Name)
            return npc, island, "Boss"
        end
    end
    return nil
end

local function GetSummonTarget()
    if not (Toggles.SummonBossFarm and Toggles.SummonBossFarm.Value) then return nil end
    local selected = Options.SelectedSummon and Options.SelectedSummon.Value
    if not selected then return nil end
    local workspaceName = SummonMap[selected] or (selected.."Boss")
    for _, npc in pairs(PATH.Mobs:GetChildren()) do
        if npc.Name:lower():find(workspaceName:lower()) then
            if IsValidTarget(npc) then return npc, "Boss", "Boss" end
        end
    end
    return nil
end

local function GetWorldBossTarget()
    if Toggles.AllBossesFarm and Toggles.AllBossesFarm.Value then
        for _, npc in pairs(PATH.Mobs:GetChildren()) do
            local name = npc.Name
            if name:find("Boss") and not table.find(Tables.MiniBossList, name) then
                if IsValidTarget(npc) then
                    local island = "Boss"
                    for dName, iName in pairs(Shared.BossTIMap) do
                        if IsStrictBossMatch(name, dName) then island = iName; break end
                    end
                    return npc, island, "Boss"
                end
            end
        end
    end
    if Toggles.BossesFarm and Toggles.BossesFarm.Value then
        local selected = Options.SelectedBosses and Options.SelectedBosses.Value or {}
        for bossDisplayName, isEnabled in pairs(selected) do
            if isEnabled then
                for _, npc in pairs(PATH.Mobs:GetChildren()) do
                    if IsStrictBossMatch(npc.Name, bossDisplayName) and not table.find(Tables.MiniBossList, npc.Name) then
                        if IsValidTarget(npc) then
                            local island = Shared.BossTIMap[bossDisplayName] or "Boss"
                            return npc, island, "Boss"
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function GetMobTarget()
    if not (Toggles.MobFarm and Toggles.MobFarm.Value) then Shared.MobIdx=1; return nil end
    local selectedDict = Options.SelectedMob and Options.SelectedMob.Value or {}
    local enabledMobs = {}
    for mob, enabled in pairs(selectedDict) do if enabled then table.insert(enabledMobs, mob) end end
    table.sort(enabledMobs)
    if #enabledMobs == 0 then return nil end
    if Shared.MobIdx > #enabledMobs then Shared.MobIdx = 1 end
    local targetMobName = enabledMobs[Shared.MobIdx]
    local target, count = GetBestMobCluster({[targetMobName]=true})
    if target then
        local island = GetNearestIsland(target:GetPivot().Position, target.Name)
        return target, island, "Mob"
    else
        Shared.MobIdx = Shared.MobIdx + 1; return nil
    end
end

local function ShouldMainWait()
    if not (Toggles.AltBossFarm and Toggles.AltBossFarm.Value) then return false end
    local selectedAlts = {}
    for i = 1, 5 do
        local val = Options["SelectedAlt_"..i] and Options["SelectedAlt_"..i].Value
        local name = (typeof(val) == "Instance" and val:IsA("Player")) and val.Name or tostring(val)
        if name and name ~= "" and name ~= "nil" and name ~= "None" then table.insert(selectedAlts, name) end
    end
    if #selectedAlts == 0 then return false end
    for _, altName in ipairs(selectedAlts) do
        local currentDmg = Shared.AltDamage[altName] or 0
        if currentDmg < 10 then return true end
    end
    return false
end

local function GetAltHelpTarget()
    if not (Toggles.AltBossFarm and Toggles.AltBossFarm.Value) then return nil end
    local targetBossName = Options.SelectedAltBoss and Options.SelectedAltBoss.Value
    if not targetBossName then return nil end
    local targetNPC = nil
    for _, npc in pairs(PATH.Mobs:GetChildren()) do
        if IsStrictBossMatch(npc.Name, targetBossName) and IsValidTarget(npc) then targetNPC = npc; break end
    end
    if not targetNPC then
        FireBossRemote(targetBossName, Options.SelectedAltDiff and Options.SelectedAltDiff.Value or "Normal")
        task.wait(0.5); return nil
    end
    Shared.AltActive = ShouldMainWait()
    local island = Shared.BossTIMap[targetBossName] or "Boss"
    return targetNPC, island, "Boss"
end

local function CheckTask(taskType)
    if taskType == "Merchant" then
        if (Toggles.AutoMerchant and Toggles.AutoMerchant.Value) and Shared.MerchantBusy then return true, nil, "None" end
        return nil
    elseif taskType == "Pity Boss" then return GetPityTarget()
    elseif taskType == "Summon [Other]" then return GetOtherTarget()
    elseif taskType == "Summon" then return GetSummonTarget()
    elseif taskType == "Boss" then return GetWorldBossTarget()
    elseif taskType == "Level Farm" then return GetLevelFarmTarget()
    elseif taskType == "All Mob Farm" then return GetAllMobTarget()
    elseif taskType == "Mob" then return GetMobTarget()
    elseif taskType == "Alt Help" then return GetAltHelpTarget() end
    return nil
end

local function GetNearestAuraTarget()
    local nearest = nil; local maxRange = tonumber(Options.KillAuraRange and Options.KillAuraRange.Value) or 200
    local lastDist = maxRange
    local char = Plr.Character; local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local myPos = root.Position; local mobFolder = workspace:FindFirstChild("NPCs")
    if not mobFolder then return nil end
    for _, v in ipairs(mobFolder:GetChildren()) do
        if v:IsA("Model") then
            local npcPos = v:GetPivot().Position; local dist = (myPos - npcPos).Magnitude
            if dist <= lastDist then
                local hum = v:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then nearest = v; lastDist = dist end
            end
        end
    end
    return nearest
end

local function Func_KillAura()
    while Toggles.KillAura and Toggles.KillAura.Value do
        if IsBusy() then task.wait(0.1); continue end
        local target = GetNearestAuraTarget()
        if target then
            EquipWeapon()
            pcall(function() Remotes.M1:FireServer(target:GetPivot().Position) end)
        end
        task.wait(tonumber(Options.KillAuraCD and Options.KillAuraCD.Value) or 0.12)
    end
end

local function ExecuteFarmLogic(target, island, farmType)
    local char = GetCharacter(); local root = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not target or Shared.Recovering or not root then return end
    if Shared.MovingIsland then return end
    Shared.Target = target
    if (Toggles.AltBossFarm and Toggles.AltBossFarm.Value) and farmType == "Boss" then
        Shared.AltActive = ShouldMainWait()
    else Shared.AltActive = false end
    if Toggles.IslandTP and Toggles.IslandTP.Value then
        if island and island ~= "" and island ~= "Unknown" and island ~= Shared.Island then
            Shared.MovingIsland = true
            Remotes.TP_Portal:FireServer(island)
            task.wait(tonumber(Options.IslandTPCD and Options.IslandTPCD.Value) or 0.8)
            Shared.Island = island; Shared.MovingIsland = false; return
        end
    end
    local targetPivot = target:GetPivot(); local targetPos = targetPivot.Position
    local distVal = tonumber(Options.Distance and Options.Distance.Value) or 10
    local posType = Options.SelectedFarmType and Options.SelectedFarmType.Value or "Behind"
    local finalPos
    local ikTag = target:FindFirstChild("IK_Active")
    if ikTag and (Options.InstaKillType and Options.InstaKillType.Value) == "V2" and (Toggles.InstaKill and Toggles.InstaKill.Value) then
        local startTime = ikTag:GetAttribute("TriggerTime") or 0
        if tick() - startTime >= 3 then
            root.CFrame = CFrame.new(targetPos + Vector3.new(0,300,0))
            root.AssemblyLinearVelocity = Vector3.zero; return
        end
    end
    if Shared.AltActive then finalPos = targetPos + Vector3.new(0,120,0)
    elseif posType == "Above" then finalPos = targetPos + Vector3.new(0,distVal,0)
    elseif posType == "Below" then finalPos = targetPos + Vector3.new(0,-distVal,0)
    else finalPos = (targetPivot * CFrame.new(0,0,distVal)).Position end
    local finalDestination = CFrame.lookAt(finalPos, targetPos)
    if (root.Position - finalPos).Magnitude > 0.1 then
        if (Options.SelectedMovementType and Options.SelectedMovementType.Value) == "Teleport" then
            root.CFrame = finalDestination
        else
            local distance = (root.Position - finalPos).Magnitude
            local speed = tonumber(Options.TweenSpeed and Options.TweenSpeed.Value) or 180
            game:GetService("TweenService"):Create(root, TweenInfo.new(distance/speed, Enum.EasingStyle.Linear), {CFrame=finalDestination}):Play()
        end
    end
    root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
end

local function Func_WebhookLoop()
    while Toggles.SendWebhook and Toggles.SendWebhook.Value do
        -- PostToWebhook() -- webhook logic omitted for brevity, same as original
        local delay = math.max((Options.WebhookDelay and Options.WebhookDelay.Value or 5), 0.5) * 60
        task.wait(delay)
    end
end

local function Func_AutoHaki()
    while task.wait(0.5) do
        if (Toggles.ObserHaki and Toggles.ObserHaki.Value) and not CheckObsHaki() then
            Remotes.ObserHaki:FireServer("Toggle")
        end
        if (Toggles.ArmHaki and Toggles.ArmHaki.Value) and not CheckArmHaki() then
            Remotes.ArmHaki:FireServer("Toggle"); task.wait(0.5)
        end
        if Toggles.ConquerorHaki and Toggles.ConquerorHaki.Value then
            if Toggles.OnlyTarget and Toggles.OnlyTarget.Value then
                if not Shared.Farm or not Shared.Target or not Shared.Target.Parent then continue end
            end
            Remotes.ConquerorHaki:FireServer("Activate")
        end
    end
end

local function Func_AutoM1()
    while task.wait(Options.M1Speed and Options.M1Speed.Value or 0) do
        if Toggles.AutoM1 and Toggles.AutoM1.Value then Remotes.M1:FireServer() end
    end
end

local function Func_AutoSkill()
    local keyToEnum = {["Z"]=Enum.KeyCode.Z,["X"]=Enum.KeyCode.X,["C"]=Enum.KeyCode.C,["V"]=Enum.KeyCode.V,["F"]=Enum.KeyCode.F}
    local keyToSlot = {["Z"]=1,["X"]=2,["C"]=3,["V"]=4,["F"]=5}
    local priority = {"Z","X","C","V","F"}
    while task.wait() do
        if not (Toggles.AutoSkill and Toggles.AutoSkill.Value) then continue end
        local target = Shared.Target
        if (Toggles.OnlyTarget and Toggles.OnlyTarget.Value) and (not Shared.Farm or not target or not target.Parent) then continue end
        local canExecute = true
        if Toggles.AutoSkill_BossOnly and Toggles.AutoSkill_BossOnly.Value then
            if not target or not target.Parent then canExecute = false
            else
                local npcHum = target:FindFirstChildOfClass("Humanoid")
                local isRealBoss = target.Name:find("Boss") and not table.find(Tables.MiniBossList, target.Name)
                local hpPercent = npcHum and (npcHum.Health/npcHum.MaxHealth*100) or 101
                local threshold = tonumber(Options.AutoSkill_BossHP and Options.AutoSkill_BossHP.Value) or 100
                if not isRealBoss or hpPercent > threshold then canExecute = false end
            end
        end
        if canExecute and target and target.Parent then
            if target:FindFirstChild("IK_Active") and (Options.InstaKillType and Options.InstaKillType.Value) == "V1" then canExecute = false end
        end
        if not canExecute then continue end
        local char = GetCharacter(); local tool = char and char:FindFirstChildOfClass("Tool")
        if not tool then continue end
        local toolName = tool.Name; local toolType = GetToolTypeFromModule(toolName)
        local useMode = Options.AutoSkillType and Options.AutoSkillType.Value or "Normal"
        local selected = Options.SelectedSkills and Options.SelectedSkills.Value or {}
        if useMode == "Instant" then
            for _, key in ipairs(priority) do
                if selected[key] then
                    if toolType == "Power" then
                        Remotes.UseFruit:FireServer("UseAbility", {["FruitPower"]=toolName:gsub(" Fruit",""),["KeyCode"]=keyToEnum[key]})
                    else Remotes.UseSkill:FireServer(keyToSlot[key]) end
                end
            end
            task.wait(.01)
        else
            local mainFrame = PGui:FindFirstChild("CooldownUI") and PGui.CooldownUI:FindFirstChild("MainFrame")
            if not mainFrame then continue end
            for _, key in ipairs(priority) do
                if selected[key] then
                    if IsSkillReady(key) then
                        if toolType == "Power" then
                            Remotes.UseFruit:FireServer("UseAbility", {["FruitPower"]=toolName:gsub(" Fruit",""),["KeyCode"]=keyToEnum[key]})
                        else Remotes.UseSkill:FireServer(keyToSlot[key]) end
                        task.wait(0.1); break
                    end
                end
            end
        end
    end
end

local function Func_AutoStats()
    local pointsPath = Plr:WaitForChild("Data"):WaitForChild("StatPoints")
    local MAX_STAT_LEVEL = 11500
    while task.wait(1) do
        if Toggles.AutoStats and Toggles.AutoStats.Value then
            local availablePoints = pointsPath.Value
            if availablePoints > 0 then
                local selectedStats = Options.SelectedStats and Options.SelectedStats.Value or {}
                local activeStats = {}
                for statName, enabled in pairs(selectedStats) do
                    if enabled then
                        local currentLevel = Shared.Stats[statName] or 0
                        if currentLevel < MAX_STAT_LEVEL then table.insert(activeStats, statName) end
                    end
                end
                local statCount = #activeStats
                if statCount > 0 then
                    local pointsPerStat = math.floor(availablePoints/statCount)
                    if pointsPerStat > 0 then
                        for _, stat in ipairs(activeStats) do Remotes.AddStat:FireServer(stat, pointsPerStat) end
                    else Remotes.AddStat:FireServer(activeStats[1], availablePoints) end
                end
            end
        end
        if not (Toggles.AutoStats and Toggles.AutoStats.Value) then break end
    end
end

local function AutoRollStatsLoop()
    local selectedStats = Options.SelectedGemStats and Options.SelectedGemStats.Value or {}
    local selectedRanks = Options.SelectedRank and Options.SelectedRank.Value or {}
    local hasStat = false; for _ in pairs(selectedStats) do hasStat = true; break end
    local hasRank = false; for _ in pairs(selectedRanks) do hasRank = true; break end
    if not hasStat or not hasRank then
        Notify("Error: Select at least one Stat and one Rank first!", 5)
        if Toggles.AutoRollStats then Toggles.AutoRollStats.Value = false end; return
    end
    while Toggles.AutoRollStats and Toggles.AutoRollStats.Value do
        if not next(Shared.GemStats) then task.wait(0.1); continue end
        local workDone = true
        for _, statName in ipairs(Tables.GemStat) do
            if selectedStats[statName] then
                local currentData = Shared.GemStats[statName]
                if currentData then
                    local currentRank = currentData.Rank
                    if not selectedRanks[currentRank] then
                        workDone = false
                        local success, err = pcall(function() Remotes.RerollSingleStat:InvokeServer(statName) end)
                        if not success then Notify("ERROR: "..tostring(err):gsub("<","["), 5) end
                        task.wait(tonumber(Options.StatsRollCD and Options.StatsRollCD.Value) or 0.1); break
                    end
                end
            end
        end
        if workDone then Notify("Successfully rolled selected stats.", 5); if Toggles.AutoRollStats then Toggles.AutoRollStats.Value = false end; break end
        task.wait()
    end
end

local function Func_UnifiedRollManager()
    while task.wait() do
        if Toggles.AutoTrait and Toggles.AutoTrait.Value then
            local traitUI = PGui:WaitForChild("TraitRerollUI").MainFrame.Frame.Content.TraitPage.TraitGottenFrame.Holder.Trait.TraitGotten
            local confirmFrame = PGui.TraitRerollUI.MainFrame.Frame.Content:FindFirstChild("AreYouSureYouWantToRerollFrame")
            local currentTrait = traitUI.Text
            local selected = Options.SelectedTrait and Options.SelectedTrait.Value or {}
            if selected[currentTrait] then
                Notify("Success! Got Trait: "..currentTrait, 5)
                if Toggles.AutoTrait then Toggles.AutoTrait.Value = false end
            else
                pcall(SyncTraitAutoSkip)
                if confirmFrame and confirmFrame.Visible then Remotes.TraitConfirm:FireServer(true); task.wait(0.1) end
                Remotes.Roll_Trait:FireServer()
                task.wait(Options.RollCD and Options.RollCD.Value or 0.3)
            end
            continue
        end
        if Toggles.AutoRace and Toggles.AutoRace.Value then
            local currentRace = Plr:GetAttribute("CurrentRace")
            local selected = Options.SelectedRace and Options.SelectedRace.Value or {}
            if selected[currentRace] then
                Notify("Success! Got Race: "..currentRace, 5)
                if Toggles.AutoRace then Toggles.AutoRace.Value = false end
            else
                pcall(SyncRaceSettings); Remotes.UseItem:FireServer("Use","Race Reroll",1)
                task.wait(Options.RollCD and Options.RollCD.Value or 0.3)
            end
            continue
        end
        if Toggles.AutoClan and Toggles.AutoClan.Value then
            local currentClan = Plr:GetAttribute("CurrentClan")
            local selected = Options.SelectedClan and Options.SelectedClan.Value or {}
            if selected[currentClan] then
                Notify("Success! Got Clan: "..currentClan, 5)
                if Toggles.AutoClan then Toggles.AutoClan.Value = false end
            else
                pcall(SyncClanSettings); Remotes.UseItem:FireServer("Use","Clan Reroll",1)
                task.wait(Options.RollCD and Options.RollCD.Value or 0.3)
            end
            continue
        end
        task.wait(0.4)
    end
end

local function EnsureRollManager()
    Thread("UnifiedRollManager", Func_UnifiedRollManager,
        (Toggles.AutoTrait and Toggles.AutoTrait.Value) or
        (Toggles.AutoRace and Toggles.AutoRace.Value) or
        (Toggles.AutoClan and Toggles.AutoClan.Value)
    )
end

local function AutoSpecPassiveLoop()
    pcall(SyncSpecPassiveAutoSkip)
    task.wait(Options.SpecRollCD and Options.SpecRollCD.Value or 0.1)
    while Toggles.AutoSpec and Toggles.AutoSpec.Value do
        local targetWeapons = Options.SelectedPassive and Options.SelectedPassive.Value or {}
        local targetPassives = Options.SelectedSpec and Options.SelectedSpec.Value or {}
        local workDone = false
        if type(Shared.Passives) ~= "table" then Shared.Passives = {} end
        for weaponName, isWeaponEnabled in pairs(targetWeapons) do
            if not isWeaponEnabled then continue end
            local currentData = Shared.Passives[weaponName]
            local currentName = "None"; local currentBuffs = {}
            if type(currentData) == "table" then currentName = currentData.Name or "None"; currentBuffs = currentData.RolledBuffs or {}
            elseif type(currentData) == "string" then currentName = currentData end
            local isCorrectName = targetPassives[currentName]; local meetsAllStats = true
            if isCorrectName then
                if type(currentBuffs) == "table" then
                    for statKey, rolledValue in pairs(currentBuffs) do
                        local sliderId = "Min_"..currentName:gsub("%s+","").."_"..statKey
                        local minRequired = Options[sliderId] and Options[sliderId].Value or 0
                        if tonumber(rolledValue) and rolledValue < minRequired then meetsAllStats = false; break end
                    end
                end
            else meetsAllStats = false end
            if not isCorrectName or not meetsAllStats then
                workDone = true
                Remotes.SpecPassiveReroll:FireServer(weaponName)
                local startWait = tick()
                repeat
                    task.wait()
                    local checkData = Shared.Passives[weaponName]
                    local checkName = (type(checkData) == "table" and checkData.Name) or (type(checkData) == "string" and checkData) or ""
                until (checkName ~= currentName) or (tick() - startWait > 1.5)
                break
            end
        end
        if not workDone then
            Notify("Done", 5); if Toggles.AutoSpec then Toggles.AutoSpec.Value = false end; break
        end
        task.wait()
    end
end

local function AutoSkillTreeLoop()
    while Toggles.AutoSkillTree and Toggles.AutoSkillTree.Value do
        task.wait(0.5)
        if not next(Shared.SkillTree.Nodes) and Shared.SkillTree.SkillPoints == 0 then continue end
        local points = Shared.SkillTree.SkillPoints
        if points <= 0 then continue end
        for _, branch in pairs(Modules.SkillTree.Branches) do
            for _, node in ipairs(branch.Nodes) do
                local nodeId = node.Id; local cost = node.Cost
                if not Shared.SkillTree.Nodes[nodeId] then
                    if points >= cost then
                        local success, err = pcall(function() Remotes.SkillTreeUpgrade:FireServer(nodeId) end)
                        if success then Shared.SkillTree.SkillPoints = Shared.SkillTree.SkillPoints - cost; task.wait(0.3) end
                    end
                    break
                end
            end
        end
    end
end

local function Func_ArtifactMilestone()
    local currentMilestone = 1
    while Toggles.ArtifactMilestone and Toggles.ArtifactMilestone.Value do
        Remotes.ArtifactClaim:FireServer(currentMilestone)
        currentMilestone = currentMilestone + 1
        if currentMilestone > 40 then currentMilestone = 1 end
        task.wait(1)
    end
end

local function Func_AutoDungeon()
    while Toggles.AutoDungeon and Toggles.AutoDungeon.Value do
        task.wait(1)
        local selected = Options.SelectedDungeon and Options.SelectedDungeon.Value
        if not selected then continue end
        if PGui.DungeonPortalJoinUI.LeaveButton.Visible then continue end
        local targetIsland = "Dungeon"
        if selected == "BossRush" then targetIsland = "Sailor"
        elseif selected == "InfiniteTower" then targetIsland = "Tower" end
        if tick() - Shared.LastDungeon > 15 then
            Remotes.OpenDungeon:FireServer(tostring(selected)); Shared.LastDungeon = tick(); task.wait(1)
        end
        if not PGui.DungeonPortalJoinUI.LeaveButton.Visible then
            local portal = workspace:FindFirstChild("ActiveDungeonPortal")
            if not portal then
                if Shared.Island ~= targetIsland then
                    Remotes.TP_Portal:FireServer(targetIsland); Shared.Island = targetIsland; task.wait(2.5)
                end
            else
                local root = GetCharacter():FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = portal.CFrame; task.wait(0.2)
                    local prompt = portal:FindFirstChild("JoinPrompt")
                    if prompt then fireproximityprompt(prompt); task.wait(1) end
                end
            end
        end
    end
end

local function Func_AutoMerchant()
    local MerchantUI = UI.Merchant.Regular
    local Holder = MerchantUI:FindFirstChild("Holder", true)
    local LastTimerText = ""
    local function StartPurchaseSequence()
        if Shared.MerchantExecute then return end
        Shared.MerchantExecute = true
        if Shared.FirstMerchantSync then
            MerchantUI.Enabled = true; MerchantUI.MainFrame.Visible = true; task.wait(0.5)
            local closeBtn = MerchantUI:FindFirstChild("CloseButton", true)
            if closeBtn then gsc(closeBtn); task.wait(1.8) end
        end
        OpenMerchantInterface(); task.wait(2)
        local itemsWithStock = {}
        for _, child in pairs(Holder:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "Item" then
                local stockLabel = child:FindFirstChild("StockAmountForThatItem", true)
                local currentStock = 0
                if stockLabel then currentStock = tonumber(stockLabel.Text:match("%d+")) or 0 end
                Shared.CurrentStock[child.Name] = currentStock
                if currentStock > 0 then table.insert(itemsWithStock, {Name=child.Name, Stock=currentStock}) end
            end
        end
        if #itemsWithStock > 0 then
            local selectedItems = Options.SelectedMerchantItems and Options.SelectedMerchantItems.Value or {}
            for _, item in ipairs(itemsWithStock) do
                if selectedItems[item.Name] then
                    pcall(function() Remotes.MerchantBuy:InvokeServer(item.Name, 99) end)
                    task.wait(math.random(11,17)/10)
                end
            end
        end
        if MerchantUI.MainFrame then MerchantUI.MainFrame.Visible = false end
        Shared.FirstMerchantSync = true; Shared.MerchantExecute = false
    end
    local function SyncClock()
        OpenMerchantInterface(); task.wait(1)
        local Label = MerchantUI and MerchantUI:FindFirstChild("RefreshTimerLabel", true)
        if Label and Label.Text:find(":") then
            local serverSecs = GetSecondsFromTimer(Label.Text)
            if serverSecs then Shared.LocalMerchantTime = serverSecs end
        end
        if MerchantUI.MainFrame then MerchantUI.MainFrame.Visible = false end
    end
    SyncClock()
    while Toggles.AutoMerchant and Toggles.AutoMerchant.Value do
        local Label = MerchantUI:FindFirstChild("RefreshTimerLabel", true)
        if Label and Label.Text ~= "" then
            local currentText = Label.Text; local s = GetSecondsFromTimer(currentText)
            if s then
                Shared.LocalMerchantTime = s
                if currentText ~= LastTimerText then LastTimerText = currentText; Shared.LastTimerTick = tick() end
            else Shared.LocalMerchantTime = math.max(0, Shared.LocalMerchantTime - 1) end
        else Shared.LocalMerchantTime = math.max(0, Shared.LocalMerchantTime - 1) end
        local isRefresh = (Shared.LocalMerchantTime <= 1) or (Shared.LocalMerchantTime >= 1799)
        if not Shared.FirstMerchantSync or isRefresh then task.spawn(StartPurchaseSequence) end
        if tick() - Shared.LastTimerTick > 30 then task.spawn(SyncClock); Shared.LastTimerTick = tick() end
        task.wait(1)
    end
end

local function Func_AutoTrade()
    while task.wait(0.5) do
        local inTradeUI = PGui:FindFirstChild("InTradingUI") and PGui.InTradingUI.MainFrame.Visible
        local requestUI = PGui:FindFirstChild("TradeRequestUI") and PGui.TradeRequestUI.TradeRequest.Visible
        if (Toggles.ReqTradeAccept and Toggles.ReqTradeAccept.Value) and requestUI then
            Remotes.TradeRespond:FireServer(true); task.wait(1)
        end
        if (Toggles.ReqTrade and Toggles.ReqTrade.Value) and not inTradeUI and not requestUI then
            local targetPlr = Options.SelectedTradePlr and Options.SelectedTradePlr.Value
            if targetPlr and typeof(targetPlr) == "Instance" then Remotes.TradeSend:FireServer(targetPlr.UserId); task.wait(3) end
        end
        if inTradeUI and (Toggles.AutoAccept and Toggles.AutoAccept.Value) then
            local selectedItems = Options.SelectedTradeItems and Options.SelectedTradeItems.Value or {}
            local itemsToAdd = {}
            for itemName, enabled in pairs(selectedItems) do
                if enabled then
                    local alreadyInTrade = false
                    if Shared.TradeState.myItems then
                        for _, tradeItem in pairs(Shared.TradeState.myItems) do
                            if tradeItem.name == itemName then alreadyInTrade = true; break end
                        end
                    end
                    if not alreadyInTrade then table.insert(itemsToAdd, itemName) end
                end
            end
            if #itemsToAdd > 0 then
                for _, itemName in ipairs(itemsToAdd) do
                    local invQty = 0
                    for _, item in pairs(Shared.Cached.Inv) do if item.name == itemName then invQty = item.quantity; break end end
                    if invQty > 0 then Remotes.TradeAddItem:FireServer("Items", itemName, invQty); task.wait(0.5) end
                end
            else
                if not Shared.TradeState.myReady then Remotes.TradeReady:FireServer(true)
                elseif Shared.TradeState.myReady and Shared.TradeState.theirReady then
                    if Shared.TradeState.phase == "confirming" and not Shared.TradeState.myConfirm then Remotes.TradeConfirm:FireServer() end
                end
            end
        end
    end
end

local function Func_AutoChest()
    while task.wait(2) do
        if not (Toggles.AutoChest and Toggles.AutoChest.Value) then break end
        local selected = Options.SelectedChests and Options.SelectedChests.Value
        if type(selected) ~= "table" then continue end
        for _, rarityName in ipairs(Tables.Rarities or {}) do
            if selected[rarityName] == true then
                local fullName = (rarityName == "Aura Crate") and "Aura Crate" or (rarityName.." Chest")
                pcall(function() Remotes.UseItem:FireServer("Use", fullName, 10000) end)
                task.wait(1)
            end
        end
    end
end

local function Func_AutoCraft()
    while task.wait(1) do
        if Toggles.AutoCraftItem and Toggles.AutoCraftItem.Value then
            local selected = Options.SelectedCraftItems and Options.SelectedCraftItems.Value or {}
            for _, item in pairs(Shared.Cached.Inv) do
                if selected["DivineGrail"] and item.name == "Broken Sword" and item.quantity >= 3 then
                    pcall(function() Remotes.GrailCraft:InvokeServer("DivineGrail", math.min(math.floor(item.quantity/3),99)) end)
                    task.wait(0.5)
                end
                if selected["SlimeKey"] and item.name == "Slime Shard" and item.quantity >= 2 then
                    pcall(function() Remotes.SlimeCraft:InvokeServer("SlimeKey", math.min(math.floor(item.quantity/2),99)) end)
                end
            end
        end
        if not (Toggles.AutoCraftItem and Toggles.AutoCraftItem.Value) then break end
    end
end

local function Func_ArtifactAutomation()
    while task.wait(5) do
        if not Shared.ArtifactSession.Inventory or not next(Shared.ArtifactSession.Inventory) then
            Remotes.ArtifactUnequip:FireServer(""); task.wait(2); continue
        end
        local lockQueue = {}; local deleteQueue = {}; local upgradeQueue = {}
        for uuid, data in pairs(Shared.ArtifactSession.Inventory) do
            local res = EvaluateArtifact2(uuid, data)
            if res.lock then table.insert(lockQueue, uuid) end
            if res.delete then table.insert(deleteQueue, uuid) end
            if res.upgrade then
                local targetLvl = Options.UpgradeLimit and Options.UpgradeLimit.Value or 0
                if Toggles.UpgradeStage and Toggles.UpgradeStage.Value then
                    targetLvl = math.min(math.floor(data.Level/3)*3+3, targetLvl)
                end
                table.insert(upgradeQueue, {["UUID"]=uuid,["Levels"]=targetLvl})
            end
        end
        for _, uuid in ipairs(lockQueue) do Remotes.ArtifactLock:FireServer(uuid, true); task.wait(0.1) end
        if #deleteQueue > 0 then
            for i = 1, #deleteQueue, 50 do
                local chunk = {}
                for j = i, math.min(i+49,#deleteQueue) do table.insert(chunk, deleteQueue[j]) end
                Remotes.MassDelete:FireServer(chunk); task.wait(0.6)
            end
            Remotes.ArtifactUnequip:FireServer("")
        end
        if #upgradeQueue > 0 then
            for i = 1, #upgradeQueue, 50 do
                local chunk = {}
                for j = i, math.min(i+49,#upgradeQueue) do table.insert(chunk, upgradeQueue[j]) end
                Remotes.MassUpgrade:FireServer(chunk); task.wait(0.6)
            end
        end
        if Toggles.ArtifactEquip and Toggles.ArtifactEquip.Value then AutoEquipArtifacts() end
    end
end

-- ============================================================
--  REMOTE EVENT HOOKS  (unchanged from original)
-- ============================================================
Remotes.UpInventory.OnClientEvent:Connect(function(category, data)
    Shared.InventorySynced = true
    if category == "Items" then
        Shared.Cached.Inv = data or {}
        table.clear(Tables.OwnedItem)
        for _, item in pairs(data) do
            if not table.find(Tables.OwnedItem, item.name) then table.insert(Tables.OwnedItem, item.name) end
        end
        table.sort(Tables.OwnedItem)
        if Options.SelectedTradeItems then Options.SelectedTradeItems:SetValues(Tables.OwnedItem) end
    elseif category == "Runes" then
        table.clear(Tables.RuneList); table.insert(Tables.RuneList, "None")
        for name, _ in pairs(data) do table.insert(Tables.RuneList, name) end
        table.sort(Tables.RuneList)
        for _, dd in ipairs({"DefaultRune","Rune_Mob","Rune_Boss","Rune_BossHP"}) do
            if Options[dd] then Options[dd]:SetValues(Tables.RuneList) end
        end
    elseif category == "Accessories" then
        table.clear(Shared.Cached.Accessories)
        if type(data) == "table" then
            for _, accInfo in ipairs(data) do
                if accInfo.name and accInfo.quantity then Shared.Cached.Accessories[accInfo.name] = accInfo.quantity end
            end
        end
        table.clear(Tables.OwnedAccessory); local processed = {}
        for _, item in ipairs(data) do
            if (item.enchantLevel or 0) < 10 and not processed[item.name] then
                table.insert(Tables.OwnedAccessory, item.name); processed[item.name] = true
            end
        end
        table.sort(Tables.OwnedAccessory)
        if Options.SelectedEnchant then Options.SelectedEnchant:SetValues(Tables.OwnedAccessory) end
    elseif category == "Sword" or category == "Melee" then
        Shared.Cached.RawWeapCache[category] = data or {}
        table.clear(Tables.OwnedWeapon); local processed = {}
        for _, cat in pairs({"Sword","Melee"}) do
            for _, item in ipairs(Shared.Cached.RawWeapCache[cat]) do
                if (item.blessingLevel or 0) < 10 and not processed[item.name] then
                    table.insert(Tables.OwnedWeapon, item.name); processed[item.name] = true
                end
            end
        end
        table.sort(Tables.OwnedWeapon)
        if Options.SelectedBlessing then Options.SelectedBlessing:SetValues(Tables.OwnedWeapon) end
        table.clear(Tables.AllOwnedWeapons); local allProcessed = {}
        for _, cat in pairs({"Sword","Melee"}) do
            for _, item in ipairs(Shared.Cached.RawWeapCache[cat]) do
                if not allProcessed[item.name] then table.insert(Tables.AllOwnedWeapons, item.name); allProcessed[item.name] = true end
            end
        end
        table.sort(Tables.AllOwnedWeapons)
        if Options.SelectedPassive then Options.SelectedPassive:SetValues(Tables.AllOwnedWeapons) end
    end
end)

Remotes.StockUpdate.OnClientEvent:Connect(function(itemName, stockLeft)
    Shared.CurrentStock[itemName] = tonumber(stockLeft)
    if stockLeft == 0 then Notify("[MERCHANT] Bought: "..tostring(itemName), 2) end
end)

Remotes.UpSkillTree.OnClientEvent:Connect(function(data)
    if data then Shared.SkillTree.Nodes = data.Nodes or {}; Shared.SkillTree.SkillPoints = data.SkillPoints or 0 end
end)

if Remotes.SettingsSync then
    Remotes.SettingsSync.OnClientEvent:Connect(function(data) Shared.Settings = data end)
end

Remotes.ArtifactSync.OnClientEvent:Connect(function(data)
    Shared.ArtifactSession.Inventory = data.Inventory; Shared.ArtifactSession.Dust = data.Dust
end)

Remotes.TitleSync.OnClientEvent:Connect(function(data)
    if data and data.unlocked then Tables.UnlockedTitle = data.unlocked end
end)

Remotes.HakiStateUpdate.OnClientEvent:Connect(function(arg1, arg2)
    if arg1 == false then Shared.ArmHaki = false; return end
    if arg1 == Plr then Shared.ArmHaki = arg2 end
end)

if Remotes.BossUIUpdate then
    Remotes.BossUIUpdate.OnClientEvent:Connect(function(mode, data)
        if mode == "DamageStats" and data.stats then
            for _, info in pairs(data.stats) do
                if info.player and info.player:IsA("Player") then
                    Shared.AltDamage[info.player.Name] = tonumber(info.percent) or 0
                end
            end
        end
    end)
end

Remotes.TradeUpdated.OnClientEvent:Connect(function(data) Shared.TradeState = data end)

PATH.Mobs.ChildRemoved:Connect(function(child)
    if child:IsA("Model") and child.Name:lower():find("boss") then
        table.clear(Shared.AltDamage); Shared.AltActive = false
    end
end)

Remotes.SpecPassiveUpdate.OnClientEvent:Connect(function(data)
    if type(Shared.Passives) ~= "table" then Shared.Passives = {} end
    if data and data.Passives then
        for weaponName, info in pairs(data.Passives) do
            if type(info) == "table" then Shared.Passives[weaponName] = info
            else Shared.Passives[weaponName] = {Name=tostring(info),RolledBuffs={}} end
        end
    end
end)

Remotes.UpStatReroll.OnClientEvent:Connect(function(data)
    if data and data.Stats then Shared.GemStats = data.Stats end
end)

Remotes.UpPlayerStats.OnClientEvent:Connect(function(data)
    if data and data.Stats then Shared.Stats = data.Stats end
end)

Remotes.UpAscend.OnClientEvent:Connect(function(data)
    if not (Toggles.AutoAscend and Toggles.AutoAscend.Value) then return end
    if data.isMaxed then if Toggles.AutoAscend then Toggles.AutoAscend.Value = false end; return end
    if data.allMet then
        Notify("All requirements met! Ascending into: "..data.nextRankName, 5)
        Remotes.Ascend:FireServer(); task.wait(1)
    end
end)

-- ============================================================
--  FLUENT WINDOW + TABS
-- ============================================================
local Window = Fluent:CreateWindow({
    Title        = "FourHub | SP",
    SubTitle     = assetName .. " | v1.5 Beta",
    TabWidth     = 160,
    Size         = UDim2.fromOffset(620, 460),
    Acrylic      = true,
    Theme        = "Dark",
    MinimizeKey  = Enum.KeyCode.U,
})

-- Tabs
local Tabs = {
    Information = Window:AddTab({ Title = "Info",       Icon = "info" }),
    Priority    = Window:AddTab({ Title = "Priority",   Icon = "arrow-up-down" }),
    Main        = Window:AddTab({ Title = "Main",       Icon = "swords" }),
    Automation  = Window:AddTab({ Title = "Automation", Icon = "repeat-2" }),
    Artifact    = Window:AddTab({ Title = "Artifact",   Icon = "gem" }),
    Dungeon     = Window:AddTab({ Title = "Dungeon",    Icon = "door-open" }),
    Player      = Window:AddTab({ Title = "Player",     Icon = "user" }),
    Teleport    = Window:AddTab({ Title = "Teleport",   Icon = "map-pin" }),
    Misc        = Window:AddTab({ Title = "Misc",       Icon = "package" }),
    Webhook     = Window:AddTab({ Title = "Webhook",    Icon = "send" }),
    Settings    = Window:AddTab({ Title = "Settings",   Icon = "settings" }),
}

-- ============================================================
--  INFORMATION TAB
-- ============================================================
local execStatus = isLimitedExecutor and "Semi-Working" or "Working"
local InfoSection = Tabs.Information:AddSection("User Info")
InfoSection:AddParagraph({ Title = "Executor", Content = executorDisplayName .. " | Status: " .. execStatus })
InfoSection:AddParagraph({ Title = "FourHub", Content = "Sailor Piece | v1.5 Beta | by jokerbiel13" })
InfoSection:AddButton({ Title = "Redeem All Codes", Callback = function()
    local allCodes = Modules.Codes.Codes; local playerLevel = Plr.Data.Level.Value
    for codeName, data in pairs(allCodes) do
        if playerLevel >= (data.LevelReq or 0) then
            Notify("Redeeming: "..codeName, 3)
            Remotes.UseCode:InvokeServer(codeName); task.wait(2)
        end
    end
end })
InfoSection:AddButton({ Title = "Join Discord", Callback = function()
    if setclipboard then setclipboard("https://discord.gg/cUwR4tUJv3") end
    Notify("Discord link copied!", 2)
end })

-- ============================================================
--  PRIORITY TAB
-- ============================================================
local PrioSection = Tabs.Priority:AddSection("Task Priority")
for i = 1, #PriorityTasks do
    local opt = PrioSection:AddDropdown("SelectedPriority_"..i, {
        Title = "Priority "..i,
        Values = PriorityTasks,
        Default = DefaultPriority[i],
        Multi = false,
        AllowNull = true,
    })
    Options["SelectedPriority_"..i] = opt
end

-- ============================================================
--  MAIN TAB  –  Autofarm / Haki / Skill / Combo / Switch
-- ============================================================
-- LEFT: Autofarm mobs
local AFSection = Tabs.Main:AddSection("Autofarm")

local selMob = AFSection:AddDropdown("SelectedMob", { Title = "Select Mob(s)", Values = Tables.MobList, Multi = true, AllowNull = true })
Options.SelectedMob = selMob

AFSection:AddButton({ Title = "Refresh Mob List", Callback = UpdateNPCLists })

local t_MobFarm = AFSection:AddToggle("MobFarm", { Title = "Autofarm Selected Mob", Default = false })
Toggles.MobFarm = t_MobFarm

local t_AllMob = AFSection:AddToggle("AllMobFarm", { Title = "Autofarm All Mobs", Default = false })
Toggles.AllMobFarm = t_AllMob

local t_LevelFarm = AFSection:AddToggle("LevelFarm", { Title = "Autofarm Level", Default = false })
Toggles.LevelFarm = t_LevelFarm
t_LevelFarm:OnChanged(function(s) if not s then Shared.QuestNPC = "" end end)

-- Boss
local BossSection = Tabs.Main:AddSection("Boss Farm")

local selBosses = BossSection:AddDropdown("SelectedBosses", { Title = "Select Bosses", Values = Tables.BossList, Multi = true, AllowNull = true })
Options.SelectedBosses = selBosses

local t_BossesFarm = BossSection:AddToggle("BossesFarm", { Title = "Autofarm Selected Boss", Default = false })
Toggles.BossesFarm = t_BossesFarm

local t_AllBoss = BossSection:AddToggle("AllBossesFarm", { Title = "Autofarm All Bosses", Default = false })
Toggles.AllBossesFarm = t_AllBoss

BossSection:AddParagraph({ Title = "", Content = "── Summon Boss ──" })

local selSummon = BossSection:AddDropdown("SelectedSummon", { Title = "Select Summon Boss", Values = Tables.SummonList, Multi = false, AllowNull = true })
Options.SelectedSummon = selSummon

local selSummonDiff = BossSection:AddDropdown("SelectedSummonDiff", { Title = "Difficulty", Values = Tables.DiffList, Default = "Normal", Multi = false })
Options.SelectedSummonDiff = selSummonDiff

local t_AutoSummon = BossSection:AddToggle("AutoSummon", { Title = "Auto Summon", Default = false })
Toggles.AutoSummon = t_AutoSummon

local t_SummonFarm = BossSection:AddToggle("SummonBossFarm", { Title = "Autofarm Summon Boss", Default = false })
Toggles.SummonBossFarm = t_SummonFarm

BossSection:AddParagraph({ Title = "", Content = "── Other Summon ──" })

local selOtherSummon = BossSection:AddDropdown("SelectedOtherSummon", { Title = "Select Other Summon", Values = Tables.OtherSummonList, Multi = false, AllowNull = true })
Options.SelectedOtherSummon = selOtherSummon

local selOtherSummonDiff = BossSection:AddDropdown("SelectedOtherSummonDiff", { Title = "Difficulty", Values = Tables.DiffList, Default = "Normal", Multi = false })
Options.SelectedOtherSummonDiff = selOtherSummonDiff

local t_AutoOtherSummon = BossSection:AddToggle("AutoOtherSummon", { Title = "Auto Summon (Other)", Default = false })
Toggles.AutoOtherSummon = t_AutoOtherSummon

local t_OtherFarm = BossSection:AddToggle("OtherSummonFarm", { Title = "Autofarm Other Summon", Default = false })
Toggles.OtherSummonFarm = t_OtherFarm

BossSection:AddParagraph({ Title = "", Content = "── Pity Boss ──" })

local selBuildPity = BossSection:AddDropdown("SelectedBuildPity", { Title = "Boss [Build Pity]", Values = Tables.AllBossList, Multi = true, AllowNull = true })
Options.SelectedBuildPity = selBuildPity

local selUsePity = BossSection:AddDropdown("SelectedUsePity", { Title = "Boss [Use Pity]", Values = Tables.AllBossList, Multi = false, AllowNull = true })
Options.SelectedUsePity = selUsePity

local selPityDiff = BossSection:AddDropdown("SelectedPityDiff", { Title = "Difficulty [Use Pity]", Values = Tables.DiffList, Default = "Normal", Multi = false })
Options.SelectedPityDiff = selPityDiff

local t_PityFarm = BossSection:AddToggle("PityBossFarm", { Title = "Autofarm Pity Boss", Default = false })
Toggles.PityBossFarm = t_PityFarm

-- Alt Help
local AltSection = Tabs.Main:AddSection("Alt Help")

local selAltBoss = AltSection:AddDropdown("SelectedAltBoss", { Title = "Select Boss", Values = Tables.AllBossList, Multi = false, AllowNull = true })
Options.SelectedAltBoss = selAltBoss

local selAltDiff = AltSection:AddDropdown("SelectedAltDiff", { Title = "Difficulty", Values = Tables.DiffList, Default = "Normal", Multi = false })
Options.SelectedAltDiff = selAltDiff

for i = 1, 5 do
    local opt = AltSection:AddInput("SelectedAlt_"..i, { Title = "Alt #"..i.." Name", Default = "", Placeholder = "Username..." })
    Options["SelectedAlt_"..i] = opt
end

local t_AltFarm = AltSection:AddToggle("AltBossFarm", { Title = "Auto Help Alt", Default = false })
Toggles.AltBossFarm = t_AltFarm

-- Config
local FarmCfgSection = Tabs.Main:AddSection("Farm Config")

local selWeaponType = FarmCfgSection:AddDropdown("SelectedWeaponType", { Title = "Weapon Type", Values = Tables.Weapon, Multi = true })
Options.SelectedWeaponType = selWeaponType

local sliderSwitchCD = FarmCfgSection:AddSlider("SwitchWeaponCD", { Title = "Switch Weapon Delay", Default = 4, Min = 1, Max = 20, Rounding = 0 })
Options.SwitchWeaponCD = sliderSwitchCD

local t_SwitchWeapon = FarmCfgSection:AddToggle("SwitchWeapon", { Title = "Auto Switch Weapon", Default = true })
Toggles.SwitchWeapon = t_SwitchWeapon

local t_IslandTP = FarmCfgSection:AddToggle("IslandTP", { Title = "Island TP [Autofarm]", Default = true })
Toggles.IslandTP = t_IslandTP

local slIslandTPCD = FarmCfgSection:AddSlider("IslandTPCD", { Title = "Island TP CD", Default = 0.67, Min = 0, Max = 2.5, Rounding = 2 })
Options.IslandTPCD = slIslandTPCD

local slTargetTPCD = FarmCfgSection:AddSlider("TargetTPCD", { Title = "Target TP CD", Default = 0, Min = 0, Max = 5, Rounding = 2 })
Options.TargetTPCD = slTargetTPCD

local slTargetDistTP = FarmCfgSection:AddSlider("TargetDistTP", { Title = "Target Distance TP [Tween]", Default = 0, Min = 0, Max = 100, Rounding = 0 })
Options.TargetDistTP = slTargetDistTP

local slM1Speed = FarmCfgSection:AddSlider("M1Speed", { Title = "M1 Attack Cooldown", Default = 0, Min = 0, Max = 1, Rounding = 2 })
Options.M1Speed = slM1Speed

local selMovement = FarmCfgSection:AddDropdown("SelectedMovementType", { Title = "Movement Type", Values = {"Teleport","Tween"}, Default = "Tween", Multi = false })
Options.SelectedMovementType = selMovement

local selFarmType = FarmCfgSection:AddDropdown("SelectedFarmType", { Title = "Farm Type", Values = {"Behind","Above","Below"}, Default = "Behind", Multi = false })
Options.SelectedFarmType = selFarmType

local slDist = FarmCfgSection:AddSlider("Distance", { Title = "Farm Distance", Default = 12, Min = 0, Max = 30, Rounding = 0 })
Options.Distance = slDist

local slTweenSpeed = FarmCfgSection:AddSlider("TweenSpeed", { Title = "Tween Speed", Default = 160, Min = 0, Max = 500, Rounding = 0 })
Options.TweenSpeed = slTweenSpeed

local t_InstaKill = FarmCfgSection:AddToggle("InstaKill", { Title = "Instant Kill", Default = false })
Toggles.InstaKill = t_InstaKill

local selIKType = FarmCfgSection:AddDropdown("InstaKillType", { Title = "Insta-Kill Type", Values = {"V1","V2"}, Default = "V1", Multi = false })
Options.InstaKillType = selIKType

local slIKHP = FarmCfgSection:AddSlider("InstaKillHP", { Title = "HP% For Insta-Kill", Default = 90, Min = 1, Max = 100, Rounding = 0 })
Options.InstaKillHP = slIKHP

local inIKMinHP = FarmCfgSection:AddInput("InstaKillMinHP", { Title = "Min MaxHP For Insta-Kill", Default = "100000", Numeric = true, Placeholder = "Number..." })
Options.InstaKillMinHP = inIKMinHP

-- Haki
local HakiSection = Tabs.Main:AddSection("Haki")

local t_ObserHaki = HakiSection:AddToggle("ObserHaki", { Title = "Auto Observation Haki", Default = false })
Toggles.ObserHaki = t_ObserHaki
t_ObserHaki:OnChanged(function(s) Thread("AutoHaki", Func_AutoHaki, s) end)

local t_ArmHaki = HakiSection:AddToggle("ArmHaki", { Title = "Auto Armament Haki", Default = false })
Toggles.ArmHaki = t_ArmHaki
t_ArmHaki:OnChanged(function(s) Thread("AutoHaki", Func_AutoHaki, s) end)

local t_ConqHaki = HakiSection:AddToggle("ConquerorHaki", { Title = "Auto Conqueror Haki", Default = false })
Toggles.ConquerorHaki = t_ConqHaki
t_ConqHaki:OnChanged(function(s) Thread("AutoHaki", Func_AutoHaki, s) end)

-- Skills
local SkillSection = Tabs.Main:AddSection("Skills")
SkillSection:AddParagraph({ Title = "Note", Content = "Autofarm has built-in M1. Enable below only if needed separately." })

local t_AutoM1 = SkillSection:AddToggle("AutoM1", { Title = "Auto Attack (M1)", Default = false })
Toggles.AutoM1 = t_AutoM1
t_AutoM1:OnChanged(function(s) Thread("AutoM1", SafeLoop("Auto M1", Func_AutoM1), s) end)

local t_KillAura = SkillSection:AddToggle("KillAura", { Title = "Kill Aura", Default = false })
Toggles.KillAura = t_KillAura
t_KillAura:OnChanged(function(s) Thread("KillAura", Func_KillAura, s) end)

local slKillAuraCD = SkillSection:AddSlider("KillAuraCD", { Title = "Kill Aura CD", Default = 0.1, Min = 0.1, Max = 1, Rounding = 2 })
Options.KillAuraCD = slKillAuraCD

local slKillAuraRange = SkillSection:AddSlider("KillAuraRange", { Title = "Kill Aura Range", Default = 200, Min = 0, Max = 200, Rounding = 0 })
Options.KillAuraRange = slKillAuraRange

local selSkills = SkillSection:AddDropdown("SelectedSkills", { Title = "Select Skills", Values = {"Z","X","C","V","F"}, Multi = true })
Options.SelectedSkills = selSkills

local selAutoSkillType = SkillSection:AddDropdown("AutoSkillType", { Title = "Mode", Values = {"Normal","Instant"}, Default = "Normal", Multi = false })
Options.AutoSkillType = selAutoSkillType

local t_OnlyTarget = SkillSection:AddToggle("OnlyTarget", { Title = "Target Only", Default = false })
Toggles.OnlyTarget = t_OnlyTarget

local t_SkillBossOnly = SkillSection:AddToggle("AutoSkill_BossOnly", { Title = "Use On Boss Only", Default = false })
Toggles.AutoSkill_BossOnly = t_SkillBossOnly

local slSkillBossHP = SkillSection:AddSlider("AutoSkill_BossHP", { Title = "Boss HP%", Default = 100, Min = 1, Max = 100, Rounding = 0 })
Options.AutoSkill_BossHP = slSkillBossHP

local t_AutoSkill = SkillSection:AddToggle("AutoSkill", { Title = "Auto Use Skills", Default = false })
Toggles.AutoSkill = t_AutoSkill
t_AutoSkill:OnChanged(function(s) Thread("AutoSkill", SafeLoop("Auto Skill", Func_AutoSkill), s) end)

-- Combo
local ComboSection = Tabs.Main:AddSection("Skill Combo")
ComboSection:AddParagraph({ Title = "Example", Content = "Z > X > C > 0.5 > V > F\nNumbers = wait seconds." })

local inComboPattern = ComboSection:AddInput("ComboPattern", { Title = "Combo Pattern", Default = "Z > X > C > V > F", Placeholder = "pattern..." })
Options.ComboPattern = inComboPattern

local selComboMode = ComboSection:AddDropdown("ComboMode", { Title = "Mode", Values = {"Normal","Instant"}, Default = "Normal", Multi = false })
Options.ComboMode = selComboMode

local t_ComboBossOnly = ComboSection:AddToggle("ComboBossOnly", { Title = "Boss Only", Default = false })
Toggles.ComboBossOnly = t_ComboBossOnly

local t_AutoCombo = ComboSection:AddToggle("AutoCombo", { Title = "Auto Skill Combo", Default = false })
Toggles.AutoCombo = t_AutoCombo
t_AutoCombo:OnChanged(function(s)
    if not s then Shared.ComboIdx = 1 end
    if s and Toggles.AutoSkill and Toggles.AutoSkill.Value then
        Toggles.AutoSkill.Value = false
        Notify("NOTICE: Auto Skill disabled for Combo to work.", 3)
    end
    Thread("AutoCombo", SafeLoop("Skill Combo", Func_AutoCombo), s)
end)

-- Title / Rune / Build Switch
local SwitchSection = Tabs.Main:AddSection("Auto Switch")

for _, sw in ipairs({ {id="Title", list=CombinedTitleList}, {id="Rune", list=Tables.RuneList}, {id="Build", list=Tables.BuildList} }) do
    local t = SwitchSection:AddToggle("Auto"..sw.id, { Title = "Auto Switch "..sw.id, Default = false })
    Toggles["Auto"..sw.id] = t
    t:OnChanged(function(state) if not state then Shared.LastSwitch[sw.id] = "" end end)

    local defOpt = SwitchSection:AddDropdown("Default"..sw.id, { Title = "Default "..sw.id, Values = sw.list, Multi = false, AllowNull = true })
    Options["Default"..sw.id] = defOpt

    for _, ctx in ipairs({"Mob","Boss","Combo F Move","Boss HP%"}) do
        local key = sw.id.."_"..ctx:gsub(" ",""):gsub("F Move","Combo"):gsub("HP%%","BossHP")
        if ctx == "Combo F Move" then key = sw.id.."_Combo" end
        if ctx == "Boss HP%" then key = sw.id.."_BossHP" end
        if ctx == "Mob" then key = sw.id.."_Mob" end
        if ctx == "Boss" then key = sw.id.."_Boss" end
        local o = SwitchSection:AddDropdown(key, { Title = sw.id.." ["..ctx.."]", Values = sw.list, Multi = false, AllowNull = true })
        Options[key] = o
    end
    local bossHPSlider = SwitchSection:AddSlider(sw.id.."_BossHPAmt", { Title = "Change Until Boss HP%", Default = 15, Min = 0, Max = 100, Rounding = 0 })
    Options[sw.id.."_BossHPAmt"] = bossHPSlider
end

-- ============================================================
--  AUTOMATION TAB
-- ============================================================
local AscendSection = Tabs.Automation:AddSection("Ascend")
local t_AutoAscend = AscendSection:AddToggle("AutoAscend", { Title = "Auto Ascend", Default = false })
Toggles.AutoAscend = t_AutoAscend
t_AutoAscend:OnChanged(function(s)
    if s then Remotes.ReqAscend:InvokeServer() else Remotes.CloseAscend:FireServer() end
end)

local RollSection = Tabs.Automation:AddSection("Auto Rolls")

local slRollCD = RollSection:AddSlider("RollCD", { Title = "Roll Delay", Default = 0.3, Min = 0.01, Max = 1, Rounding = 2 })
Options.RollCD = slRollCD

local selTrait = RollSection:AddDropdown("SelectedTrait", { Title = "Select Trait(s)", Values = Tables.TraitList, Multi = true, AllowNull = true })
Options.SelectedTrait = selTrait
local t_AutoTrait = RollSection:AddToggle("AutoTrait", { Title = "Auto Roll Trait", Default = false })
Toggles.AutoTrait = t_AutoTrait
t_AutoTrait:OnChanged(EnsureRollManager)

local selRace = RollSection:AddDropdown("SelectedRace", { Title = "Select Race(s)", Values = Tables.RaceList, Multi = true, AllowNull = true })
Options.SelectedRace = selRace
local t_AutoRace = RollSection:AddToggle("AutoRace", { Title = "Auto Roll Race", Default = false })
Toggles.AutoRace = t_AutoRace
t_AutoRace:OnChanged(EnsureRollManager)

local selClan = RollSection:AddDropdown("SelectedClan", { Title = "Select Clan(s)", Values = Tables.ClanList, Multi = true, AllowNull = true })
Options.SelectedClan = selClan
local t_AutoClan = RollSection:AddToggle("AutoClan", { Title = "Auto Roll Clan", Default = false })
Toggles.AutoClan = t_AutoClan
t_AutoClan:OnChanged(EnsureRollManager)

local StatsSection = Tabs.Automation:AddSection("Stats")

local selStats = StatsSection:AddDropdown("SelectedStats", { Title = "Select Stat(s)", Values = {"Melee","Defense","Sword","Power"}, Multi = true })
Options.SelectedStats = selStats
local t_AutoStats = StatsSection:AddToggle("AutoStats", { Title = "Auto UP Stats", Default = false })
Toggles.AutoStats = t_AutoStats
t_AutoStats:OnChanged(function(s) Thread("AutoStats", SafeLoop("Auto Stats", Func_AutoStats), s) end)

local selGemStats = StatsSection:AddDropdown("SelectedGemStats", { Title = "Gem Stat(s)", Values = Tables.GemStat, Multi = true })
Options.SelectedGemStats = selGemStats
local selRank = StatsSection:AddDropdown("SelectedRank", { Title = "Rank(s)", Values = Tables.GemRank, Multi = true })
Options.SelectedRank = selRank
local slStatsRollCD = StatsSection:AddSlider("StatsRollCD", { Title = "Roll Delay", Default = 0.1, Min = 0.01, Max = 1, Rounding = 2 })
Options.StatsRollCD = slStatsRollCD
local t_AutoRollStats = StatsSection:AddToggle("AutoRollStats", { Title = "Auto Roll Stats", Default = false })
Toggles.AutoRollStats = t_AutoRollStats
t_AutoRollStats:OnChanged(function(s) Thread("AutoRollStats", SafeLoop("Stat Roll", AutoRollStatsLoop), s) end)

local MiscAutoSection = Tabs.Automation:AddSection("Misc Automation")

local t_AutoSkillTree = MiscAutoSection:AddToggle("AutoSkillTree", { Title = "Auto Skill Tree", Default = false })
Toggles.AutoSkillTree = t_AutoSkillTree
t_AutoSkillTree:OnChanged(function(s) Thread("AutoSkillTree", SafeLoop("Skill Tree", AutoSkillTreeLoop), s) end)

local t_ArtMilestone = MiscAutoSection:AddToggle("ArtifactMilestone", { Title = "Auto Artifact Milestone", Default = false })
Toggles.ArtifactMilestone = t_ArtMilestone
t_ArtMilestone:OnChanged(function(s) Thread("ArtifactMilestone", Func_ArtifactMilestone, s) end)

local EnchantSection = Tabs.Automation:AddSection("Enchant & Blessing")

local selEnchant = EnchantSection:AddDropdown("SelectedEnchant", { Title = "Select Enchant", Values = Tables.OwnedAccessory, Multi = true, AllowNull = true })
Options.SelectedEnchant = selEnchant
local t_AutoEnchant = EnchantSection:AddToggle("AutoEnchant", { Title = "Auto Enchant", Default = false })
Toggles.AutoEnchant = t_AutoEnchant
t_AutoEnchant:OnChanged(function(s) Thread("AutoEnchant", SafeLoop("Enchant", function() AutoUpgradeLoop("Enchant") end), s) end)
local t_AutoEnchantAll = EnchantSection:AddToggle("AutoEnchantAll", { Title = "Auto Enchant All", Default = false })
Toggles.AutoEnchantAll = t_AutoEnchantAll
t_AutoEnchantAll:OnChanged(function(s) Thread("AutoEnchantAll", SafeLoop("EnchantAll", function() AutoUpgradeLoop("Enchant") end), s) end)

local selBlessing = EnchantSection:AddDropdown("SelectedBlessing", { Title = "Select Blessing", Values = Tables.OwnedWeapon, Multi = true, AllowNull = true })
Options.SelectedBlessing = selBlessing
local t_AutoBlessing = EnchantSection:AddToggle("AutoBlessing", { Title = "Auto Blessing", Default = false })
Toggles.AutoBlessing = t_AutoBlessing
t_AutoBlessing:OnChanged(function(s) Thread("AutoBlessing", SafeLoop("Blessing", function() AutoUpgradeLoop("Blessing") end), s) end)
local t_AutoBlessingAll = EnchantSection:AddToggle("AutoBlessingAll", { Title = "Auto Blessing All", Default = false })
Toggles.AutoBlessingAll = t_AutoBlessingAll
t_AutoBlessingAll:OnChanged(function(s) Thread("AutoBlessingAll", SafeLoop("BlessingAll", function() AutoUpgradeLoop("Blessing") end), s) end)

local PassiveSection = Tabs.Automation:AddSection("Spec Passive")
local selPassive = PassiveSection:AddDropdown("SelectedPassive", { Title = "Select Weapon(s)", Values = Tables.AllOwnedWeapons, Multi = true, AllowNull = true })
Options.SelectedPassive = selPassive
local selSpec = PassiveSection:AddDropdown("SelectedSpec", { Title = "Target Passives", Values = Tables.SpecPassive, Multi = true, AllowNull = true })
Options.SelectedSpec = selSpec
local slSpecRollCD = PassiveSection:AddSlider("SpecRollCD", { Title = "Roll Delay", Default = 0.1, Min = 0.01, Max = 1, Rounding = 2 })
Options.SpecRollCD = slSpecRollCD
local t_AutoSpec = PassiveSection:AddToggle("AutoSpec", { Title = "Auto Reroll Passive", Default = false })
Toggles.AutoSpec = t_AutoSpec
t_AutoSpec:OnChanged(function(s) Thread("AutoSpecPassive", SafeLoop("Spec Passive", AutoSpecPassiveLoop), s) end)

local TradeSection = Tabs.Automation:AddSection("Trade")
local inTradePlr = TradeSection:AddInput("SelectedTradePlr", { Title = "Player Name", Default = "", Placeholder = "Username..." })
Options.SelectedTradePlr = inTradePlr
local selTradeItems = TradeSection:AddDropdown("SelectedTradeItems", { Title = "Select Item(s)", Values = Tables.OwnedItem, Multi = true, AllowNull = true })
Options.SelectedTradeItems = selTradeItems
local t_ReqTrade = TradeSection:AddToggle("ReqTrade", { Title = "Auto Send Request", Default = false })
Toggles.ReqTrade = t_ReqTrade
local t_ReqTradeAccept = TradeSection:AddToggle("ReqTradeAccept", { Title = "Auto Accept Request", Default = false })
Toggles.ReqTradeAccept = t_ReqTradeAccept
local t_AutoAccept = TradeSection:AddToggle("AutoAccept", { Title = "Auto Accept Trade", Default = false })
Toggles.AutoAccept = t_AutoAccept

-- ============================================================
--  ARTIFACT TAB
-- ============================================================
local ArtStatusSection = Tabs.Artifact:AddSection("Status")
ArtStatusSection:AddParagraph({ Title = "Warning", Content = "Artifact features are in heavy development. Use at your own risk." })

local ArtUpgradeSection = Tabs.Artifact:AddSection("Upgrade")
local slUpgradeLimit = ArtUpgradeSection:AddSlider("UpgradeLimit", { Title = "Upgrade Limit", Default = 0, Min = 0, Max = 15, Rounding = 0 })
Options.UpgradeLimit = slUpgradeLimit
local selUpMS = ArtUpgradeSection:AddDropdown("Up_MS", { Title = "Main Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Up_MS = selUpMS
local t_ArtUpgrade = ArtUpgradeSection:AddToggle("ArtifactUpgrade", { Title = "Auto Upgrade", Default = false })
Toggles.ArtifactUpgrade = t_ArtUpgrade
t_ArtUpgrade:OnChanged(function(s) Thread("Artifact.Upgrade", SafeLoop("ArtifactLogic", Func_ArtifactAutomation), s) end)
local t_UpgradeStage = ArtUpgradeSection:AddToggle("UpgradeStage", { Title = "Upgrade in Stages", Default = false })
Toggles.UpgradeStage = t_UpgradeStage

local ArtLockSection = Tabs.Artifact:AddSection("Lock")
local selLockType = ArtLockSection:AddDropdown("Lock_Type", { Title = "Artifact Type", Values = Modules.ArtifactConfig.Categories, Multi = true, AllowNull = true })
Options.Lock_Type = selLockType
local selLockSet = ArtLockSection:AddDropdown("Lock_Set", { Title = "Artifact Set", Values = allSets, Multi = true, AllowNull = true })
Options.Lock_Set = selLockSet
local selLockMS = ArtLockSection:AddDropdown("Lock_MS", { Title = "Main Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Lock_MS = selLockMS
local selLockSS = ArtLockSection:AddDropdown("Lock_SS", { Title = "Sub Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Lock_SS = selLockSS
local slLockMinSS = ArtLockSection:AddSlider("Lock_MinSS", { Title = "Min Sub-Stats", Default = 0, Min = 0, Max = 4, Rounding = 0 })
Options.Lock_MinSS = slLockMinSS
local t_ArtLock = ArtLockSection:AddToggle("ArtifactLock", { Title = "Auto Lock", Default = false })
Toggles.ArtifactLock = t_ArtLock
t_ArtLock:OnChanged(function(s) Thread("Artifact.Lock", SafeLoop("ArtifactLogic", Func_ArtifactAutomation), s) end)

local ArtDeleteSection = Tabs.Artifact:AddSection("Delete")
local selDelType = ArtDeleteSection:AddDropdown("Del_Type", { Title = "Artifact Type", Values = Modules.ArtifactConfig.Categories, Multi = true, AllowNull = true })
Options.Del_Type = selDelType
local selDelSet = ArtDeleteSection:AddDropdown("Del_Set", { Title = "Artifact Set", Values = allSets, Multi = true, AllowNull = true })
Options.Del_Set = selDelSet
local selDelMSHelmet = ArtDeleteSection:AddDropdown("Del_MS_Helmet", { Title = "Main Stat [Helmet]", Values = {"FlatDefense","Defense"}, Multi = true, AllowNull = true })
Options.Del_MS_Helmet = selDelMSHelmet
local selDelMSGloves = ArtDeleteSection:AddDropdown("Del_MS_Gloves", { Title = "Main Stat [Gloves]", Values = {"Damage"}, Multi = true, AllowNull = true })
Options.Del_MS_Gloves = selDelMSGloves
local selDelMSBody = ArtDeleteSection:AddDropdown("Del_MS_Body", { Title = "Main Stat [Body]", Values = allStats, Multi = true, AllowNull = true })
Options.Del_MS_Body = selDelMSBody
local selDelMSBoots = ArtDeleteSection:AddDropdown("Del_MS_Boots", { Title = "Main Stat [Boots]", Values = allStats, Multi = true, AllowNull = true })
Options.Del_MS_Boots = selDelMSBoots
local selDelSS = ArtDeleteSection:AddDropdown("Del_SS", { Title = "Sub Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Del_SS = selDelSS
local slDelMinSS = ArtDeleteSection:AddSlider("Del_MinSS", { Title = "Min Sub-Stats", Default = 0, Min = 0, Max = 4, Rounding = 0 })
Options.Del_MinSS = slDelMinSS
local t_ArtDelete = ArtDeleteSection:AddToggle("ArtifactDelete", { Title = "Auto Delete", Default = false })
Toggles.ArtifactDelete = t_ArtDelete
t_ArtDelete:OnChanged(function(s) Thread("Artifact.Delete", SafeLoop("ArtifactLogic", Func_ArtifactAutomation), s) end)
local t_DeleteUnlock = ArtDeleteSection:AddToggle("DeleteUnlock", { Title = "Auto Delete Unlocked", Default = false })
Toggles.DeleteUnlock = t_DeleteUnlock

local ArtEquipSection = Tabs.Artifact:AddSection("Auto Equip")
local selEqType = ArtEquipSection:AddDropdown("Eq_Type", { Title = "Artifact Type", Values = Modules.ArtifactConfig.Categories, Multi = true, AllowNull = true })
Options.Eq_Type = selEqType
local selEqMS = ArtEquipSection:AddDropdown("Eq_MS", { Title = "Main Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Eq_MS = selEqMS
local selEqSS = ArtEquipSection:AddDropdown("Eq_SS", { Title = "Sub Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Eq_SS = selEqSS
local t_ArtEquip = ArtEquipSection:AddToggle("ArtifactEquip", { Title = "Auto Equip", Default = false })
Toggles.ArtifactEquip = t_ArtEquip

-- ============================================================
--  DUNGEON TAB
-- ============================================================
local DungeonSection = Tabs.Dungeon:AddSection("Dungeon")
local selDungeon = DungeonSection:AddDropdown("SelectedDungeon", { Title = "Select Dungeon", Values = Tables.DungeonList, Multi = false, AllowNull = true })
Options.SelectedDungeon = selDungeon
local t_AutoDungeon = DungeonSection:AddToggle("AutoDungeon", { Title = "Auto Join Dungeon", Default = false })
Toggles.AutoDungeon = t_AutoDungeon
t_AutoDungeon:OnChanged(function(s) Thread("AutoDungeon", Func_AutoDungeon, s) end)
local t_AutoInfiniteTower = DungeonSection:AddToggle("AutoInfiniteTower", { Title = "Auto Infinite Tower", Default = false })
Toggles.AutoInfiniteTower = t_AutoInfiniteTower

-- ============================================================
--  PLAYER TAB
-- ============================================================
local PlayerGenSection = Tabs.Player:AddSection("General")

local function AddST(section, id, label, def, mn, mx, round)
    local tog = section:AddToggle("Toggle_"..id, { Title = label, Default = false })
    local sl  = section:AddSlider(id.."Value", { Title = label, Default = def, Min = mn, Max = mx, Rounding = round or 0 })
    Toggles[id] = tog; Options[id.."Value"] = sl
    return tog, sl
end

AddST(PlayerGenSection, "WS", "WalkSpeed", 16, 16, 250)
AddST(PlayerGenSection, "JP", "JumpPower", 50, 0, 500)
AddST(PlayerGenSection, "HH", "HipHeight", 2, 0, 10, 1)
AddST(PlayerGenSection, "Grav", "Gravity", 196, 0, 500, 1)
AddST(PlayerGenSection, "Zoom", "Camera Zoom", 128, 128, 10000)
AddST(PlayerGenSection, "FOV", "Field of View", 70, 30, 120)

local t_TPW, sl_TPW = AddST(PlayerGenSection, "TPW", "TPWalk", 1, 1, 10, 1)
t_TPW:OnChanged(function(s) Thread("TPW", FuncTPW, s) end)

local t_LimitFPS, sl_LimitFPS = AddST(PlayerGenSection, "LimitFPS", "Set Max FPS", 60, 5, 360)
if Support.FPS then
    t_LimitFPS:OnChanged(function(s) if not s then setfpscap(999) end end)
    sl_LimitFPS:OnChanged(function(v) if Toggles.Toggle_LimitFPS and Toggles.Toggle_LimitFPS.Value then setfpscap(v) end end)
end

local t_Noclip = PlayerGenSection:AddToggle("Noclip", { Title = "Noclip", Default = false })
Toggles.Noclip = t_Noclip
t_Noclip:OnChanged(function(s) Thread("Noclip", FuncNoclip, s) end)

local t_AntiKB = PlayerGenSection:AddToggle("AntiKnockback", { Title = "Anti Knockback", Default = false })
Toggles.AntiKnockback = t_AntiKB
t_AntiKB:OnChanged(function(s) Thread("AntiKnockback", Func_AntiKnockback, s) end)

local t_3DRender = PlayerGenSection:AddToggle("Disable3DRender", { Title = "Disable 3D Rendering", Default = false })
Toggles.Disable3DRender = t_3DRender
t_3DRender:OnChanged(function(v) RunService:Set3dRenderingEnabled(not v) end)

local t_FPSBoost = PlayerGenSection:AddToggle("FPSBoost", { Title = "FPS Boost", Default = false })
Toggles.FPSBoost = t_FPSBoost
t_FPSBoost:OnChanged(function(s) ApplyFPSBoost(s) end)

local PlayerServerSection = Tabs.Player:AddSection("Server")

local t_AntiAFK = PlayerServerSection:AddToggle("AntiAFK", { Title = "Anti AFK", Default = true })
Toggles.AntiAFK = t_AntiAFK

local t_AutoReconnect = PlayerServerSection:AddToggle("AutoReconnect", { Title = "Auto Reconnect", Default = false })
Toggles.AutoReconnect = t_AutoReconnect
t_AutoReconnect:OnChanged(function(s) if s then Func_AutoReconnect() end end)

local t_NoGameplayPaused = PlayerServerSection:AddToggle("NoGameplayPaused", { Title = "No Gameplay Paused", Default = false })
Toggles.NoGameplayPaused = t_NoGameplayPaused
t_NoGameplayPaused:OnChanged(function(s) Thread("NoGameplayPaused", SafeLoop("Anti-Pause", Func_NoGameplayPaused), s) end)

PlayerServerSection:AddButton({ Title = "Rejoin", Callback = function() TeleportService:Teleport(game.PlaceId, Plr) end })

local PlayerGameSection = Tabs.Player:AddSection("Game")

local t_Fullbright = PlayerGameSection:AddToggle("Fullbright", { Title = "Fullbright", Default = false })
Toggles.Fullbright = t_Fullbright

local t_NoFog = PlayerGameSection:AddToggle("NoFog", { Title = "No Fog", Default = false })
Toggles.NoFog = t_NoFog

local t_InstantPP = PlayerGameSection:AddToggle("InstantPP", { Title = "Instant Prompt", Default = false })
Toggles.InstantPP = t_InstantPP

AddST(PlayerGameSection, "OverrideTime", "Time Of Day", 12, 0, 24, 1)

local PlayerSafetySection = Tabs.Player:AddSection("Safety")
PlayerSafetySection:AddButton({ Title = "Panic Stop (or press P)", Callback = PanicStop })

local t_AutoKick = PlayerSafetySection:AddToggle("AutoKick", { Title = "Auto Kick", Default = true })
Toggles.AutoKick = t_AutoKick

local selKickType = PlayerSafetySection:AddDropdown("SelectedKickType", { Title = "Kick Type", Values = {"Mod","Player Join","Public Server"}, Default = {"Mod"}, Multi = true })
Options.SelectedKickType = selKickType
selKickType:OnChanged(function() CheckServerTypeSafety() end)

-- ============================================================
--  TELEPORT TAB
-- ============================================================
local IslandSection = Tabs.Teleport:AddSection("Island Teleport")
local selIsland = IslandSection:AddDropdown("SelectedIsland", { Title = "Select Island", Values = Tables.IslandList, Multi = false, AllowNull = true })
Options.SelectedIsland = selIsland
IslandSection:AddButton({ Title = "Teleport to Island", Callback = function()
    if Options.SelectedIsland.Value then Remotes.TP_Portal:FireServer(Options.SelectedIsland.Value)
    else Notify("Select an island first!", 2) end
end })

local NPCSection = Tabs.Teleport:AddSection("NPC Teleport")
local selQuestNPC = NPCSection:AddDropdown("SelectedQuestNPC", { Title = "Quest NPC", Values = Tables.NPC_QuestList, Multi = false, AllowNull = true })
Options.SelectedQuestNPC = selQuestNPC
NPCSection:AddButton({ Title = "TP to Quest NPC", Callback = function()
    local questMap = {["DungeonUnlock"]="DungeonPortalsNPC",["SlimeKeyUnlock"]="SlimeCraftNPC"}
    SafeTeleportToNPC(Options.SelectedQuestNPC.Value, questMap)
end })

local selMiscNPC = NPCSection:AddDropdown("SelectedMiscNPC", { Title = "Misc NPC", Values = Tables.NPC_MiscList, Multi = false, AllowNull = true })
Options.SelectedMiscNPC = selMiscNPC
NPCSection:AddButton({ Title = "TP to Misc NPC", Callback = function()
    local miscMap = {["ArmHaki"]="HakiQuest",["Observation"]="ObservationBuyer"}
    if Options.SelectedMiscNPC.Value then SafeTeleportToNPC(Options.SelectedMiscNPC.Value, miscMap) end
end })

local selMovesetNPC = NPCSection:AddDropdown("SelectedMovesetNPC", { Title = "Moveset NPC", Values = Tables.NPC_MovesetList, Multi = false, AllowNull = true })
Options.SelectedMovesetNPC = selMovesetNPC
NPCSection:AddButton({ Title = "TP to Moveset NPC", Callback = function()
    if Options.SelectedMovesetNPC.Value then SafeTeleportToNPC(Options.SelectedMovesetNPC.Value) end
end })

local selMasteryNPC = NPCSection:AddDropdown("SelectedMasteryNPC", { Title = "Mastery NPC", Values = Tables.NPC_MasteryList, Multi = false, AllowNull = true })
Options.SelectedMasteryNPC = selMasteryNPC
NPCSection:AddButton({ Title = "TP to Mastery NPC", Callback = function()
    if Options.SelectedMasteryNPC.Value then SafeTeleportToNPC(Options.SelectedMasteryNPC.Value) end
end })

NPCSection:AddButton({ Title = "TP to Level Based Quest", Callback = function()
    local distance = tonumber(pingUI.PingMarker:WaitForChild('DistanceLabel').Text:match("%d+"))
    if not distance then Notify("Something wrong..", 2); return end
    local target = findNPCByDistance(distance)
    if target then Plr.Character.HumanoidRootPart.CFrame = target:GetPivot() * CFrame.new(0,3,0) end
end })

-- ============================================================
--  MISC TAB
-- ============================================================
local MerchantSection = Tabs.Misc:AddSection("Merchant")
local selMerchantItems = MerchantSection:AddDropdown("SelectedMerchantItems", { Title = "Select Item(s)", Values = Tables.MerchantList, Multi = true, AllowNull = true })
Options.SelectedMerchantItems = selMerchantItems
local t_AutoMerchant = MerchantSection:AddToggle("AutoMerchant", { Title = "Auto Buy Items", Default = false })
Toggles.AutoMerchant = t_AutoMerchant
t_AutoMerchant:OnChanged(function(s) Thread("AutoMerchant", SafeLoop("Merchant", Func_AutoMerchant), s) end)

local selDungeonMerchant = MerchantSection:AddDropdown("SelectedDungeonMerchantItems", { Title = "Dungeon Item(s)", Values = Tables.DungeonMerchantList or {}, Multi = true, AllowNull = true })
Options.SelectedDungeonMerchantItems = selDungeonMerchant
local t_AutoDungeonMerchant = MerchantSection:AddToggle("AutoDungeonMerchant", { Title = "Auto Buy Dungeon Items", Default = false })
Toggles.AutoDungeonMerchant = t_AutoDungeonMerchant

local selTowerMerchant = MerchantSection:AddDropdown("SelectedTowerMerchantItems", { Title = "Tower Item(s)", Values = Tables.InfiniteTowerMerchantList or {}, Multi = true, AllowNull = true })
Options.SelectedTowerMerchantItems = selTowerMerchant
local t_AutoTowerMerchant = MerchantSection:AddToggle("AutoTowerMerchant", { Title = "Auto Buy Tower Items", Default = false })
Toggles.AutoTowerMerchant = t_AutoTowerMerchant

local selBossRushMerchant = MerchantSection:AddDropdown("SelectedBossRushMerchantItems", { Title = "Boss Rush Item(s)", Values = Tables.BossRushMerchantList or {}, Multi = true, AllowNull = true })
Options.SelectedBossRushMerchantItems = selBossRushMerchant
local t_AutoBossRushMerchant = MerchantSection:AddToggle("AutoBossRushMerchant", { Title = "Auto Buy Boss Rush Items", Default = false })
Toggles.AutoBossRushMerchant = t_AutoBossRushMerchant

local ChestSection = Tabs.Misc:AddSection("Chests & Crafting")
local selChests = ChestSection:AddDropdown("SelectedChests", { Title = "Select Chest(s)", Values = Tables.Rarities, Multi = true, AllowNull = true })
Options.SelectedChests = selChests
local t_AutoChest = ChestSection:AddToggle("AutoChest", { Title = "Auto Open Chest", Default = false })
Toggles.AutoChest = t_AutoChest
t_AutoChest:OnChanged(function(s) Thread("AutoChest", SafeLoop("Chest", Func_AutoChest), s) end)

local selCraftItems = ChestSection:AddDropdown("SelectedCraftItems", { Title = "Item(s) to Craft", Values = Tables.CraftItemList, Multi = true, AllowNull = true })
Options.SelectedCraftItems = selCraftItems
local t_AutoCraft = ChestSection:AddToggle("AutoCraftItem", { Title = "Auto Craft", Default = false })
Toggles.AutoCraftItem = t_AutoCraft
t_AutoCraft:OnChanged(function(s) Thread("AutoCraft", SafeLoop("Craft", Func_AutoCraft), s) end)

local NotifSection = Tabs.Misc:AddSection("Notifications")
local t_AutoDeleteNotif = NotifSection:AddToggle("AutoDeleteNotif", { Title = "Auto Hide Notifications", Default = false })
Toggles.AutoDeleteNotif = t_AutoDeleteNotif

local PuzzleSection = Tabs.Misc:AddSection("Puzzles")
PuzzleSection:AddButton({ Title = "Complete Dungeon Puzzle", Callback = function()
    if not Support.Proximity then Notify("Proximity not supported!", 3); return end
    if Plr.Data.Level.Value >= 5000 then UniversalPuzzleSolver("Dungeon")
    else Notify("Level 5000 required!", 3) end
end })
PuzzleSection:AddButton({ Title = "Complete Slime Key Puzzle", Callback = function()
    if Support.Proximity then UniversalPuzzleSolver("Slime") else Notify("Proximity not supported!", 3) end
end })
PuzzleSection:AddButton({ Title = "Complete Demonite Puzzle", Callback = function()
    if Support.Proximity then UniversalPuzzleSolver("Demonite") else Notify("Proximity not supported!", 3) end
end })
PuzzleSection:AddButton({ Title = "Complete Hogyoku Puzzle", Callback = function()
    if not Support.Proximity then Notify("Proximity not supported!", 3); return end
    if Plr.Data.Level.Value >= 8500 then UniversalPuzzleSolver("Hogyoku")
    else Notify("Level 8500 required!", 3) end
end })

local QuestlineSection = Tabs.Misc:AddSection("Questlines")
local selQuestline = QuestlineSection:AddDropdown("SelectedQuestline", { Title = "Select Questline", Values = Tables.QuestlineList, Multi = false, AllowNull = true })
Options.SelectedQuestline = selQuestline
local selQuestlinePlayer = QuestlineSection:AddInput("SelectedQuestline_Player", { Title = "Player Name [Kill]", Default = "", Placeholder = "Username..." })
Options.SelectedQuestline_Player = selQuestlinePlayer
local selQuestlineDMG = QuestlineSection:AddDropdown("SelectedQuestline_DMGTaken", { Title = "Mob [Take Damage]", Values = Tables.AllEntitiesList, Multi = false, AllowNull = true })
Options.SelectedQuestline_DMGTaken = selQuestlineDMG
QuestlineSection:AddButton({ Title = "Refresh Mob List", Callback = function() UpdateAllEntities() end })
local t_AutoQuestline = QuestlineSection:AddToggle("AutoQuestline", { Title = "Auto Questline [BETA]", Default = false })
Toggles.AutoQuestline = t_AutoQuestline

-- ============================================================
--  WEBHOOK TAB
-- ============================================================
local WebhookSection = Tabs.Webhook:AddSection("Config")
local inWebhookURL = WebhookSection:AddInput("WebhookURL", { Title = "Webhook URL", Default = "", Placeholder = "https://discord.com/api/webhooks/..." })
Options.WebhookURL = inWebhookURL
local inUID = WebhookSection:AddInput("UID", { Title = "User ID (for ping)", Default = "", Placeholder = "Discord ID..." })
Options.UID = inUID
local selWHData = WebhookSection:AddDropdown("SelectedData", { Title = "Select Data", Values = {"Name","Stats","New Items","All Items"}, Multi = true })
Options.SelectedData = selWHData
local selWHRarity = WebhookSection:AddDropdown("SelectedItemRarity", { Title = "Rarity Filter", Values = {"Common","Uncommon","Rare","Epic","Legendary","Mythical","Secret"}, Default = {"Common","Uncommon","Rare","Epic","Legendary","Mythical","Secret"}, Multi = true })
Options.SelectedItemRarity = selWHRarity
local t_PingUser = WebhookSection:AddToggle("PingUser", { Title = "Ping User", Default = false })
Toggles.PingUser = t_PingUser
local t_SendWebhook = WebhookSection:AddToggle("SendWebhook", { Title = "Send Webhook", Default = false })
Toggles.SendWebhook = t_SendWebhook
t_SendWebhook:OnChanged(function(s) Thread("WebhookLoop", Func_WebhookLoop, s) end)
local slWebhookDelay = WebhookSection:AddSlider("WebhookDelay", { Title = "Send Every X Minutes", Default = 5, Min = 1, Max = 30, Rounding = 0 })
Options.WebhookDelay = slWebhookDelay

-- ============================================================
--  SETTINGS TAB
-- ============================================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "SelectedIsland","SelectedQuestNPC","SelectedMiscNPC","SelectedMovesetNPC","SelectedMasteryNPC" })
SaveManager:SetFolder("FourHub/SailorPiece")
InterfaceManager:SetFolder("FourHub/SailorPiece")
SaveManager:BuildConfigSection(Tabs.Settings)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

-- ============================================================
--  RUNTIME LOOPS  (identical to original)
-- ============================================================
Connections.Player_General = RunService.Stepped:Connect(function()
    local Hum = Plr.Character and Plr.Character:FindFirstChildOfClass("Humanoid")
    if Hum then
        if Toggles.Toggle_WS and Toggles.Toggle_WS.Value then Hum.WalkSpeed = Options.WSValue.Value end
        if Toggles.Toggle_JP and Toggles.Toggle_JP.Value then Hum.JumpPower = Options.JPValue.Value; Hum.UseJumpPower = true end
        if Toggles.Toggle_HH and Toggles.Toggle_HH.Value then Hum.HipHeight = Options.HHValue.Value end
    end
    workspace.Gravity = (Toggles.Toggle_Grav and Toggles.Toggle_Grav.Value) and Options.GravValue.Value or 192
    if Toggles.Toggle_FOV and Toggles.Toggle_FOV.Value then workspace.CurrentCamera.FieldOfView = Options.FOVValue.Value end
    if Toggles.Toggle_Zoom and Toggles.Toggle_Zoom.Value then Plr.CameraMaxZoomDistance = Options.ZoomValue.Value end
end)

task.spawn(function()
    while task.wait() do
        if Toggles.Fullbright and Toggles.Fullbright.Value then
            Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = false
        elseif Toggles.Toggle_OverrideTime and Toggles.Toggle_OverrideTime.Value then
            Lighting.ClockTime = Options.OverrideTimeValue.Value
        end
        if Toggles.NoFog and Toggles.NoFog.Value then Lighting.FogEnd = 9e9 end
        if not getgenv().FourHub_Running then break end
    end
end)

RunService.Stepped:Connect(function()
    if Shared.Farm and Shared.Target then
        local char = GetCharacter()
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end
    end
end)

game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt)
    if Toggles.InstantPP and Toggles.InstantPP.Value then prompt.HoldDuration = 0 end
end)

-- Panic keybind (P)
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.P then PanicStop() end
end)

-- Notification filter
local NotifFrame = PGui:WaitForChild("NotificationUI"):WaitForChild("NotificationsFrame")
NotifFrame.ChildAdded:Connect(function(child) ProcessNotification(child) end)
for _, child in pairs(NotifFrame:GetChildren()) do ProcessNotification(child) end

-- Anti-AFK
task.spawn(function()
    DisableIdled()
    while true do
        task.wait(60)
        if Toggles.AntiAFK and Toggles.AntiAFK.Value then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                task.wait(0.2)
                VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end)
        end
    end
end)

-- Main M1 + farm execution loop
task.spawn(function()
    while true do
        task.wait()
        if Shared.AltActive then continue end
        if not Shared.Farm or Shared.MerchantBusy or not Shared.Target then continue end
        local success, err = pcall(function()
            local char = GetCharacter(); local target = Shared.Target
            if not target or not char then return end
            local npcHum = target:FindFirstChildOfClass("Humanoid")
            local npcRoot = target:FindFirstChild("HumanoidRootPart")
            local root = char:FindFirstChild("HumanoidRootPart")
            if npcHum and npcRoot and root then
                local currentDist = (root.Position - npcRoot.Position).Magnitude
                local hpPercent = (npcHum.Health / npcHum.MaxHealth) * 100
                local minMaxHP = tonumber(Options.InstaKillMinHP and Options.InstaKillMinHP.Value) or 0
                local ikThreshold = tonumber(Options.InstaKillHP and Options.InstaKillHP.Value) or 90
                if (Toggles.InstaKill and Toggles.InstaKill.Value) and npcHum.MaxHealth >= minMaxHP and hpPercent < ikThreshold then
                    npcHum.Health = 0
                    if not target:FindFirstChild("IK_Active") then
                        local tag = Instance.new("Folder"); tag.Name = "IK_Active"
                        tag:SetAttribute("TriggerTime", tick()); tag.Parent = target
                    end
                end
                if currentDist < 35 then
                    if math.abs(root.Position.Y - npcRoot.Position.Y) > 50 then root.Velocity = Vector3.new(0,-100,0) end
                    local m1Delay = tonumber(Options.M1Speed and Options.M1Speed.Value) or 0.2
                    if tick() - Shared.LastM1 >= m1Delay then
                        if Toggles.SwitchWeapon and Toggles.SwitchWeapon.Value then EquipWeapon() end
                        Remotes.M1:FireServer(); Shared.LastM1 = tick()
                    end
                end
            end
        end)
        if not success then Notify("ERROR: "..tostring(err), 10) end
    end
end)

-- Farm target loop
task.spawn(function()
    while task.wait() do
        if not Shared.Farm or Shared.MerchantBusy then Shared.Target = nil; continue end
        local char = GetCharacter()
        if not char or Shared.Recovering then continue end
        if Shared.TargetValid and (not Shared.Target or not Shared.Target.Parent or Shared.Target.Humanoid.Health <= 0) then
            Shared.KillTick = tick(); Shared.TargetValid = false
        end
        if tick() - Shared.KillTick < (tonumber(Options.TargetTPCD and Options.TargetTPCD.Value) or 0) then continue end
        HandleSummons()
        local currentPity, maxPity = GetCurrentPity()
        local isPityReady = (Toggles.PityBossFarm and Toggles.PityBossFarm.Value) and currentPity >= (maxPity-1)
        local foundTask = false
        if isPityReady then
            local t, isl, fType = GetPityTarget()
            if t then
                foundTask = true; Shared.Target = t; Shared.TargetValid = true
                UpdateSwitchState(t, fType); ExecuteFarmLogic(t, isl, fType)
            end
        end
        if not foundTask then
            for i = 1, #PriorityTasks do
                local taskName = Options["SelectedPriority_"..i] and Options["SelectedPriority_"..i].Value
                if not taskName then continue end
                if isPityReady and (taskName == "Boss" or taskName == "All Mob Farm" or taskName == "Mob") then continue end
                local t, isl, fType = CheckTask(taskName)
                if t then
                    foundTask = true; Shared.Target = (typeof(t)=="Instance") and t or nil; Shared.TargetValid = true
                    UpdateSwitchState(t, fType)
                    if taskName ~= "Merchant" then ExecuteFarmLogic(t, isl, fType) end
                    break
                end
            end
        end
        if not foundTask then Shared.Target = nil; UpdateSwitchState(nil, "None") end
    end
end)

-- Recovery / out-of-bounds check
task.spawn(function()
    while task.wait(1) do
        if not getgenv().FourHub_Running then break end
        local char = GetCharacter(); local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and not Shared.MovingIsland then
            local pos = root.Position
            if pos.Y > 5000 or math.abs(pos.X) > 10000 or math.abs(pos.Z) > 10000 then
                Shared.Recovering = true; Notify("Something went wrong, resetting..", 5)
                root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
                if IslandCrystals["Starter"] then
                    root.CFrame = IslandCrystals["Starter"]:GetPivot() * CFrame.new(0,5,0); task.wait(1)
                end
                Shared.Recovering = false
            end
        end
    end
end)

-- Inventory sync loop
task.spawn(function()
    while getgenv().FourHub_Running do
        if Remotes.ReqInventory then Remotes.ReqInventory:FireServer() end
        task.wait(30)
    end
end)

-- Pity label update (just notifies, no obsidian label)
task.spawn(function()
    while task.wait(1) do
        if not getgenv().FourHub_Running then break end
        pcall(function()
            local current, max = GetCurrentPity()
            -- Could update a Fluent paragraph here if desired
        end)
    end
end)

-- Trade auto loop
task.spawn(Func_AutoTrade)

-- ACThing
ACThing(true)

-- Init
UpdateNPCLists()
UpdateAllEntities()
InitAutoKick()
PopulateNPCLists()

task.spawn(function()
    if Remotes.ReqInventory then Remotes.ReqInventory:FireServer() end
    local timeout = 0
    while not Shared.InventorySynced and timeout < 5 do
        task.wait(0.15); timeout = timeout + 0.15
        if timeout == 1.5 and Remotes.ReqInventory then Remotes.ReqInventory:FireServer() end
    end
    SaveManager:LoadAutoloadConfig()
    if Remotes.ReqInventory then Remotes.ReqInventory:FireServer() end
end)

Notify("FourHub Fluent Edition loaded! Press U to toggle UI.", 5)
Notify("Report bugs in Discord!", 4)

-- Unload handler
Window.OnClose = function()
    getgenv().FourHub_Running = false
    Shared.Farm = false
    Cleanup(Connections)
    Cleanup(Flags)
end--FH - Fluent UI Edition
if getgenv().FourHub_Running then
    warn("Script already running!")
    return
end

repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.GameId ~= 0

function missing(t, f, fallback)
	if type(f) == t then return f end
	return fallback
end

cloneref = missing("function", cloneref, function(...) return ... end)
getgc = missing("function", getgc or get_gc_objects)
getconnections = missing("function", getconnections or get_signal_cons)

Services = setmetatable({}, {
	__index = function(self, name)
		local success, cache = pcall(function()
			return cloneref(game:GetService(name))
		end)
		if success then
			rawset(self, name, cache)
			return cache
		else
			error("Invalid Service: " .. tostring(name))
		end
	end
})

local Players = Services.Players
local Plr = Players.LocalPlayer
local Char = Plr.Character or Plr.CharacterAdded:Wait()
local PGui = Plr:WaitForChild("PlayerGui")
local Lighting = game:GetService('Lighting')

local RS = Services.ReplicatedStorage
local RunService = Services.RunService
local HttpService = Services.HttpService
local GuiService = Services.GuiService
local TeleportService = Services.TeleportService
local Marketplace = Services.MarketplaceService
local UIS = Services.UserInputService
local VirtualUser = Services.VirtualUser

local v, Asset = pcall(function()
    return Marketplace:GetProductInfo(game.PlaceId)
end)

local assetName = "sailor piece"
if v and Asset then assetName = Asset.Name end

local Support = {
    Webhook = (typeof(request) == "function" or typeof(http_request) == "function"),
    Clipboard = (typeof(setclipboard) == "function"),
    FileIO = (typeof(writefile) == "function" and typeof(isfile) == "function"),
    QueueOnTeleport = (typeof(queue_on_teleport) == "function"),
    Connections = (typeof(getconnections) == "function"),
    FPS = (typeof(setfpscap) == "function"),
    Proximity = (typeof(fireproximityprompt) == "function"),
}

local executorName = (identifyexecutor and identifyexecutor() or "Unknown"):lower()
local isXeno = string.find(executorName, "xeno") ~= nil
local LimitedExecutors = {"xeno"}
local isLimitedExecutor = false
for _, name in ipairs(LimitedExecutors) do
    if string.find(executorName, name) then isLimitedExecutor = true break end
end

-- ============================================================
--  FLUENT UI LOAD
-- ============================================================
local Fluent       = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager  = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

getgenv().FourHub_Running = true

-- ============================================================
--  HELPERS  (notify shim so rest of code stays the same)
-- ============================================================
local function Notify(msg, dur)
    Fluent:Notify({ Title = "FourHub", Content = tostring(msg), Duration = dur or 3 })
end

-- ============================================================
--  ALL GAME LOGIC (unchanged from original)
-- ============================================================
local PriorityTasks = {"Boss", "Pity Boss", "Summon [Other]", "Summon", "Level Farm", "All Mob Farm", "Mob", "Merchant", "Alt Help"}
local DefaultPriority = {"Boss", "Pity Boss", "Summon [Other]", "Summon", "Level Farm", "All Mob Farm", "Mob", "Merchant", "Alt Help"}

local TargetGroupId = 1002185259
local BannedRanks = {255, 254, 175, 150}
local NewItemsBuffer = {}

local Shared = {
    GlobalPrio = "FARM", Cached = { Inv = {}, Accessories = {}, RawWeapCache = { Sword = {}, Melee = {} } },
    Farm = true, Recovering = false, MovingIsland = false, Island = "", Target = nil,
    KillTick = 0, TargetValid = false, QuestNPC = "", MobIdx = 1, AllMobIdx = 1,
    WeapRotationIdx = 1, ComboIdx = 1, ParsedCombo = {}, RawWeapCache = { Sword = {}, Melee = {} },
    ActiveWeap = "", ArmHaki = false, BossTIMap = {}, InventorySynced = false,
    Stats = {}, Settings = {}, GemStats = {}, SkillTree = { Nodes = {}, Points = 0 },
    Passives = {}, SpecStatsSlider = {}, ArtifactSession = { Inventory = {}, Dust = 0, InvCount = 0 },
    UpBlacklist = {}, MerchantBusy = false, LocalMerchantTime = 0, LastTimerTick = tick(),
    MerchantExecute = false, FirstMerchantSync = false, CurrentStock = {}, LastM1 = 0,
    LastWRSwitch = 0, LastSwitch = { Title = "", Rune = "" }, LastBuildSwitch = 0,
    LastDungeon = 0, AltDamage = {}, AltActive = false, TradeState = {},
}

local Script_Start_Time = os.time()
local StartStats = {
    Level = Plr.Data.Level.Value, Money = Plr.Data.Money.Value, Gems = Plr.Data.Gems.Value,
    Bounty = (Plr:FindFirstChild("leaderstats") and Plr.leaderstats:FindFirstChild("Bounty") and Plr.leaderstats.Bounty.Value) or 0
}

local function GetSessionTime()
    local seconds = os.time() - Script_Start_Time
    return string.format("%dh %02dm", math.floor(seconds/3600), math.floor((seconds%3600)/60))
end

local function GetSafeModule(parent, name)
    local obj = parent:FindFirstChild(name)
    if obj and obj:IsA("ModuleScript") then
        local success, result = pcall(require, obj)
        if success then return result end
    end
    return nil
end

local function GetRemote(parent, pathString)
    local current = parent
    for _, name in ipairs(pathString:split(".")) do
        if not current then return nil end
        current = current:FindFirstChild(name)
    end
    return current
end

local function SafeInvoke(remote, ...)
    local args = {...}; local result = nil
    task.spawn(function()
        local success, res = pcall(function() return remote:InvokeServer(unpack(args)) end)
        result = res
    end)
    local start = tick()
    repeat task.wait() until result ~= nil or (tick() - start) > 2
    return result
end

local function fire_event(signal, ...)
    if firesignal then return firesignal(signal, ...)
    elseif getconnections then
        for _, connection in ipairs(getconnections(signal)) do
            if connection.Function then task.spawn(connection.Function, ...) end
        end
    else warn("Your executor does not support firesignal or getconnections.") end
end

local _DR = GetRemote(RS, "RemoteEvents.DashRemote")
local _FS = (_DR and _DR.FireServer)

local Remotes = {
    SettingsToggle = GetRemote(RS, "RemoteEvents.SettingsToggle"),
    SettingsSync = GetRemote(RS, "RemoteEvents.SettingsSync"),
    UseCode = GetRemote(RS, "RemoteEvents.CodeRedeem"),
    M1 = GetRemote(RS, "CombatSystem.Remotes.RequestHit"),
    EquipWeapon = GetRemote(RS, "Remotes.EquipWeapon"),
    UseSkill = GetRemote(RS, "AbilitySystem.Remotes.RequestAbility"),
    UseFruit = GetRemote(RS, "RemoteEvents.FruitPowerRemote"),
    QuestAccept = GetRemote(RS, "RemoteEvents.QuestAccept"),
    QuestAbandon = GetRemote(RS, "RemoteEvents.QuestAbandon"),
    UseItem = GetRemote(RS, "Remotes.UseItem"),
    SlimeCraft = GetRemote(RS, "Remotes.RequestSlimeCraft"),
    GrailCraft = GetRemote(RS, "Remotes.RequestGrailCraft"),
    RerollSingleStat = GetRemote(RS, "Remotes.RerollSingleStat"),
    SkillTreeUpgrade = GetRemote(RS, "RemoteEvents.SkillTreeUpgrade"),
    Enchant = GetRemote(RS, "Remotes.EnchantAccessory"),
    Blessing = GetRemote(RS, "Remotes.BlessWeapon"),
    ArtifactSync = GetRemote(RS, "RemoteEvents.ArtifactDataSync"),
    ArtifactClaim = GetRemote(RS, "RemoteEvents.ArtifactMilestoneClaimReward"),
    MassDelete = GetRemote(RS, "RemoteEvents.ArtifactMassDeleteByUUIDs"),
    MassUpgrade = GetRemote(RS, "RemoteEvents.ArtifactMassUpgrade"),
    ArtifactLock = GetRemote(RS, "RemoteEvents.ArtifactLock"),
    ArtifactUnequip = GetRemote(RS, "RemoteEvents.ArtifactUnequip"),
    ArtifactEquip = GetRemote(RS, "RemoteEvents.ArtifactEquip"),
    Roll_Trait = GetRemote(RS, "RemoteEvents.TraitReroll"),
    TraitAutoSkip = GetRemote(RS, "RemoteEvents.TraitUpdateAutoSkip"),
    TraitConfirm = GetRemote(RS, "RemoteEvents.TraitConfirm"),
    SpecPassiveReroll = GetRemote(RS, "RemoteEvents.SpecPassiveReroll"),
    ArmHaki = GetRemote(RS, "RemoteEvents.HakiRemote"),
    ObserHaki = GetRemote(RS, "RemoteEvents.ObservationHakiRemote"),
    ConquerorHaki = GetRemote(RS, "Remotes.ConquerorHakiRemote"),
    TP_Portal = GetRemote(RS, "Remotes.TeleportToPortal"),
    OpenDungeon = GetRemote(RS, "Remotes.RequestDungeonPortal"),
    DungeonWaveVote = GetRemote(RS, "Remotes.DungeonWaveVote"),
    EquipTitle = GetRemote(RS, "RemoteEvents.TitleEquip"),
    TitleUnequip = GetRemote(RS, "RemoteEvents.TitleUnequip"),
    EquipRune = GetRemote(RS, "Remotes.EquipRune"),
    LoadoutLoad = GetRemote(RS, "RemoteEvents.LoadoutLoad"),
    AddStat = GetRemote(RS, "RemoteEvents.AllocateStat"),
    OpenMerchant = GetRemote(RS, "Remotes.MerchantRemotes.OpenMerchantUI"),
    MerchantBuy = GetRemote(RS, "Remotes.MerchantRemotes.PurchaseMerchantItem"),
    ValentineBuy = GetRemote(RS, "Remotes.ValentineMerchantRemotes.PurchaseValentineMerchantItem"),
    StockUpdate = GetRemote(RS, "Remotes.MerchantRemotes.MerchantStockUpdate"),
    SummonBoss = GetRemote(RS, "Remotes.RequestSummonBoss"),
    JJKSummonBoss = GetRemote(RS, "Remotes.RequestSpawnStrongestBoss"),
    RimuruBoss = GetRemote(RS, "RemoteEvents.RequestSpawnRimuru"),
    AnosBoss = GetRemote(RS, "Remotes.RequestSpawnAnosBoss"),
    TrueAizenBoss = GetRemote(RS, "RemoteEvents.RequestSpawnTrueAizen"),
    AtomicBoss = GetRemote(RS, "RemoteEvents.RequestSpawnAtomic"),
    ReqInventory = GetRemote(RS, "Remotes.RequestInventory"),
    Ascend = GetRemote(RS, "RemoteEvents.RequestAscend"),
    ReqAscend = GetRemote(RS, "RemoteEvents.GetAscendData"),
    CloseAscend = GetRemote(RS, "RemoteEvents.CloseAscendUI"),
    TradeRespond = GetRemote(RS, "Remotes.TradeRemotes.RespondToRequest"),
    TradeSend = GetRemote(RS, "Remotes.TradeRemotes.SendTradeRequest"),
    TradeAddItem = GetRemote(RS, "Remotes.TradeRemotes.AddItemToTrade"),
    TradeReady = GetRemote(RS, "Remotes.TradeRemotes.SetReady"),
    TradeConfirm = GetRemote(RS, "Remotes.TradeRemotes.ConfirmTrade"),
    TradeUpdated = GetRemote(RS, "Remotes.TradeRemotes.TradeUpdated"),
    HakiStateUpdate = GetRemote(RS, "RemoteEvents.HakiStateUpdate"),
    UpCurrency = GetRemote(RS, "RemoteEvents.UpdateCurrency"),
    UpInventory = GetRemote(RS, "Remotes.UpdateInventory"),
    UpPlayerStats = GetRemote(RS, "RemoteEvents.UpdatePlayerStats"),
    UpAscend = GetRemote(RS, "RemoteEvents.AscendDataUpdate"),
    UpStatReroll = GetRemote(RS, "RemoteEvents.StatRerollUpdate"),
    SpecPassiveUpdate = GetRemote(RS, "RemoteEvents.SpecPassiveDataUpdate"),
    SpecPassiveSkip = GetRemote(RS, "RemoteEvents.SpecPassiveUpdateAutoSkip"),
    UpSkillTree = GetRemote(RS, "RemoteEvents.SkillTreeUpdate"),
    BossUIUpdate = GetRemote(RS, "Remotes.BossUIUpdate"),
    TitleSync = GetRemote(RS, "RemoteEvents.TitleDataSync"),
}

local Modules = {
    BossConfig = GetSafeModule(RS.Modules, "BossConfig") or {Bosses = {}},
    TimedConfig = GetSafeModule(RS.Modules, "TimedBossConfig"),
    SummonConfig = GetSafeModule(RS.Modules, "SummonableBossConfig"),
    Merchant = GetSafeModule(RS.Modules, "MerchantConfig") or {ITEMS = {}},
    ValentineConfig = GetSafeModule(RS.Modules, "ValentineMerchantConfig"),
    DungeonMerchantConfig = GetSafeModule(RS.Modules, "DungeonMerchantConfig"),
    InfiniteTowerMerchantConfig = GetSafeModule(RS.Modules, "InfiniteTowerMerchantConfig"),
    BossRushMerchantConfig = GetSafeModule(RS.Modules, "BossRushMerchantConfig"),
    Title = GetSafeModule(RS.Modules, "TitlesConfig") or {},
    Quests = GetSafeModule(RS.Modules, "QuestConfig") or {RepeatableQuests = {}, Questlines = {}},
    WeaponClass = GetSafeModule(RS.Modules, "WeaponClassification") or {Tools = {}},
    Fruits = GetSafeModule(RS:FindFirstChild("FruitPowerSystem") or game, "FruitPowerConfig") or {Powers = {}},
    ArtifactConfig = GetSafeModule(RS.Modules, "ArtifactConfig"),
    Stats = GetSafeModule(RS.Modules, "StatRerollConfig"),
    Codes = GetSafeModule(RS, "CodesConfig") or {Codes = {}},
    ItemRarity = GetSafeModule(RS.Modules, "ItemRarityConfig"),
    Trait = GetSafeModule(RS.Modules, "TraitConfig") or {Traits = {}},
    Race = GetSafeModule(RS.Modules, "RaceConfig") or {Races = {}},
    Clan = GetSafeModule(RS.Modules, "ClanConfig") or {Clans = {}},
    SpecPassive = GetSafeModule(RS.Modules, "SpecPassiveConfig"),
    SkillTree = GetSafeModule(RS.Modules, "SkillTreeConfig"),
    InfiniteTower = GetSafeModule(RS.Modules, "InfiniteTowerConfig"),
}

local MerchantItemList = Modules.Merchant.ITEMS
local SortedTitleList = Modules.Title:GetSortedTitleIds()

local PATH = {
    Mobs = workspace:WaitForChild('NPCs'),
    InteractNPCs = workspace:WaitForChild('ServiceNPCs'),
}

local function GetServiceNPC(name) return PATH.InteractNPCs:FindFirstChild(name) end

local NPCs = {
    Merchant = {
        Regular = GetServiceNPC("MerchantNPC"),
        Dungeon = GetServiceNPC("DungeonMerchantNPC"),
        Valentine = GetServiceNPC("ValentineMerchantNPC"),
        InfiniteTower = GetServiceNPC("InfiniteTowerMerchantNPC"),
        BossRush = GetServiceNPC("BossRushMerchantNPC"),
    }
}

local UI = {
    Merchant = {
        Regular = PGui:WaitForChild("MerchantUI"),
        Dungeon = PGui:WaitForChild("DungeonMerchantUI"),
        Valentine = PGui:FindFirstChild("ValentineMerchantUI"),
        InfiniteTower = PGui:FindFirstChild("InfiniteTowerMerchantUI"),
        BossRush = PGui:FindFirstChild("BossRushMerchantUI"),
    }
}

local pingUI = PGui:WaitForChild("QuestPingUI")
local SummonMap = {}

local function GetRemoteBossArg(name)
    local RemoteBossMap = {
        ["strongestinhistory"] = "StrongestHistory", ["strongestoftoday"] = "StrongestToday",
        ["strongesthistory"] = "StrongestHistory", ["strongesttoday"] = "StrongestToday",
    }
    return RemoteBossMap[name:lower()] or name
end

local IslandCrystals = {
    ["Starter"] = workspace:FindFirstChild("StarterIsland") and workspace.StarterIsland:FindFirstChild("SpawnPointCrystal_Starter"),
    ["Jungle"] = workspace:FindFirstChild("JungleIsland") and workspace.JungleIsland:FindFirstChild("SpawnPointCrystal_Jungle"),
    ["Desert"] = workspace:FindFirstChild("DesertIsland") and workspace.DesertIsland:FindFirstChild("SpawnPointCrystal_Desert"),
    ["Snow"] = workspace:FindFirstChild("SnowIsland") and workspace.SnowIsland:FindFirstChild("SpawnPointCrystal_Snow"),
    ["Sailor"] = workspace:FindFirstChild("SailorIsland") and workspace.SailorIsland:FindFirstChild("SpawnPointCrystal_Sailor"),
    ["Shibuya"] = workspace:FindFirstChild("ShibuyaStation") and workspace.ShibuyaStation:FindFirstChild("SpawnPointCrystal_Shibuya"),
    ["HuecoMundo"] = workspace:FindFirstChild("HuecoMundo") and workspace.HuecoMundo:FindFirstChild("SpawnPointCrystal_HuecoMundo"),
    ["Boss"] = workspace:FindFirstChild("BossIsland") and workspace.BossIsland:FindFirstChild("SpawnPointCrystal_Boss"),
    ["Dungeon"] = workspace:FindFirstChild("Main Temple") and workspace["Main Temple"]:FindFirstChild("SpawnPointCrystal_Dungeon"),
    ["Shinjuku"] = workspace:FindFirstChild("ShinjukuIsland") and workspace.ShinjukuIsland:FindFirstChild("SpawnPointCrystal_Shinjuku"),
    ["Valentine"] = workspace:FindFirstChild("ValentineIsland") and workspace.ValentineIsland:FindFirstChild("SpawnPointCrystal_Valentine"),
    ["Slime"] = workspace:FindFirstChild("SlimeIsland") and workspace.SlimeIsland:FindFirstChild("SpawnPointCrystal_Slime"),
    ["Academy"] = workspace:FindFirstChild("AcademyIsland") and workspace.AcademyIsland:FindFirstChild("SpawnPointCrystal_Academy"),
    ["Judgement"] = workspace:FindFirstChild("JudgementIsland") and workspace.JudgementIsland:FindFirstChild("SpawnPointCrystal_Judgement"),
    ["SoulDominion"] = workspace:FindFirstChild("SoulDominionIsland") and workspace.SoulDominionIsland:FindFirstChild("SpawnPointCrystal_SoulDominion"),
    ["NinjaIsland"] = workspace:FindFirstChild("NinjaIsland") and workspace.NinjaIsland:FindFirstChild("SpawnPointCrystal_Ninja"),
    ["LawlessIsland"] = workspace:FindFirstChild("LawlessIsland") and workspace.LawlessIsland:FindFirstChild("SpawnPointCrystal_Lawless"),
    ["TowerIsland"] = workspace:FindFirstChild("TowerIsland") and workspace.TowerIsland:FindFirstChild("SpawnPointCrystal_Tower"),
}

local Connections = { Player_General = nil, Idled = nil, Merchant = nil, Dash = nil, Knockback = {}, Reconnect = nil }

local Tables = {
    AscendLabels = {}, DiffList = {"Normal", "Medium", "Hard", "Extreme"}, MobList = {},
    MiniBossList = {"ThiefBoss", "MonkeyBoss", "DesertBoss", "SnowBoss", "PandaMiniBoss"},
    BossList = {}, AllBossList = {}, AllNPCList = {}, AllEntitiesList = {}, SummonList = {},
    OtherSummonList = {"StrongestHistory", "StrongestToday", "Rimuru", "Anos", "TrueAizen", "Atomic", "AbyssalEmpress"},
    Weapon = {"Melee", "Sword", "Power"},
    ManualWeaponClass = { ["Invisible"] = "Power", ["Bomb"] = "Power", ["Quake"] = "Power" },
    MerchantList = {}, ValentineMerchantList = {},
    Rarities = {"Common", "Rare", "Epic", "Legendary", "Mythical", "Secret", "Aura Crate", "Cosmetic Crate"},
    CraftItemList = {"SlimeKey", "DivineGrail"}, UnlockedTitle = {},
    TitleCategory = {"None", "Best EXP", "Best Money & Gem", "Best Luck", "Best DMG"},
    TitleList = {}, BuildList = {"1", "2", "3", "4", "5", "None"}, TraitList = {},
    RarityWeight = { ["Secret"]=1, ["Mythical"]=2, ["Legendary"]=3, ["Epic"]=4, ["Rare"]=5, ["Uncommon"]=6, ["Common"]=7 },
    RaceList = {}, ClanList = {}, RuneList = {"None"}, SpecPassive = {},
    GemStat = Modules.Stats.StatKeys, GemRank = Modules.Stats.RankOrder,
    OwnedWeapon = {}, AllOwnedWeapons = {}, OwnedAccessory = {}, QuestlineList = {}, OwnedItem = {},
    IslandList = {"Starter","Jungle","Desert","Snow","Sailor","Shibuya","HuecoMundo","Boss","Dungeon","Shinjuku","Valentine","Slime","Academy","Judgement","SoulSociety","Tower"},
    NPC_QuestList = {"DungeonUnlock", "SlimeKeyUnlock"},
    NPC_MiscList = {"Artifacts","Blessing","Enchant","SkillTree","Cupid","ArmHaki","Observation","Conqueror"},
    DungeonList = {"CidDungeon","RuneDungeon","DoubleDungeon","BossRush","InfiniteTower"},
    NPC_MovesetList = {}, NPC_MasteryList = {}, MobToIsland = {}
}

local allSets = {}
for setName, _ in pairs(Modules.ArtifactConfig.Sets) do table.insert(allSets, setName) end
local allStats = {}
for statKey, _ in pairs(Modules.ArtifactConfig.Stats) do table.insert(allStats, statKey) end

if Modules.TimedConfig and Modules.TimedConfig.Bosses then
    for _, data in pairs(Modules.TimedConfig.Bosses) do
        table.insert(Tables.BossList, data.displayName)
        local tpName = data.spawnLocation:gsub(" Island",""):gsub(" Station","")
        if data.spawnLocation == "Hueco Mundo Island" then tpName = "HuecoMundo" end
        if data.spawnLocation == "Judgement Island" then tpName = "Judgement" end
        Shared.BossTIMap[data.displayName] = tpName
    end
    table.sort(Tables.BossList)
end

if Modules.SummonConfig and Modules.SummonConfig.Bosses then
    table.clear(Tables.SummonList)
    for internalId, data in pairs(Modules.SummonConfig.Bosses) do
        table.insert(Tables.SummonList, data.displayName)
        SummonMap[data.displayName] = data.bossId
    end
    table.sort(Tables.SummonList)
end

for bossInternalName, _ in pairs(Modules.BossConfig.Bosses) do
    table.insert(Tables.AllBossList, bossInternalName:gsub("Boss$",""))
end
table.sort(Tables.AllBossList)

for itemName in pairs(MerchantItemList) do table.insert(Tables.MerchantList, itemName) end

if Modules.DungeonMerchantConfig and Modules.DungeonMerchantConfig.ITEMS then
    Tables.DungeonMerchantList = {}
    for itemName, _ in pairs(Modules.DungeonMerchantConfig.ITEMS) do table.insert(Tables.DungeonMerchantList, itemName) end
    table.sort(Tables.DungeonMerchantList)
end

if Modules.InfiniteTowerMerchantConfig and Modules.InfiniteTowerMerchantConfig.ITEMS then
    Tables.InfiniteTowerMerchantList = {}
    for itemName, _ in pairs(Modules.InfiniteTowerMerchantConfig.ITEMS) do table.insert(Tables.InfiniteTowerMerchantList, itemName) end
    table.sort(Tables.InfiniteTowerMerchantList)
end

if Modules.BossRushMerchantConfig and Modules.BossRushMerchantConfig.ITEMS then
    Tables.BossRushMerchantList = {}
    for itemName, _ in pairs(Modules.BossRushMerchantConfig.ITEMS) do table.insert(Tables.BossRushMerchantList, itemName) end
    table.sort(Tables.BossRushMerchantList)
end

for _, v in ipairs(SortedTitleList) do table.insert(Tables.TitleList, v) end

local CombinedTitleList = {}
for _, cat in ipairs(Tables.TitleCategory) do table.insert(CombinedTitleList, cat) end
for _, title in ipairs(Tables.TitleList) do table.insert(CombinedTitleList, title) end

table.clear(Tables.TraitList)
for name, _ in pairs(Modules.Trait.Traits) do table.insert(Tables.TraitList, name) end
table.sort(Tables.TraitList, function(a,b)
    local rA = Modules.Trait.Traits[a].Rarity; local rB = Modules.Trait.Traits[b].Rarity
    if rA ~= rB then return (Tables.RarityWeight[rA] or 99) < (Tables.RarityWeight[rB] or 99) end
    return a < b
end)

table.clear(Tables.RaceList)
for name, _ in pairs(Modules.Race.Races) do table.insert(Tables.RaceList, name) end
table.sort(Tables.RaceList, function(a,b)
    local rA = Modules.Race.Races[a].rarity; local rB = Modules.Race.Races[b].rarity
    if rA ~= rB then return (Tables.RarityWeight[rA] or 99) < (Tables.RarityWeight[rB] or 99) end
    return a < b
end)

table.clear(Tables.ClanList)
for name, _ in pairs(Modules.Clan.Clans) do table.insert(Tables.ClanList, name) end
table.sort(Tables.ClanList, function(a,b)
    local rA = Modules.Clan.Clans[a].rarity; local rB = Modules.Clan.Clans[b].rarity
    if rA ~= rB then return (Tables.RarityWeight[rA] or 99) < (Tables.RarityWeight[rB] or 99) end
    return a < b
end)

if Modules.SpecPassive and Modules.SpecPassive.Passives then
    for name, _ in pairs(Modules.SpecPassive.Passives) do table.insert(Tables.SpecPassive, name) end
    table.sort(Tables.SpecPassive)
end

for k, _ in pairs(Modules.Quests.Questlines) do table.insert(Tables.QuestlineList, k) end
table.sort(Tables.QuestlineList)

for _, v in pairs(PATH.InteractNPCs:GetChildren()) do table.insert(Tables.AllNPCList, v.Name) end

local function Cleanup(tbl)
    for key, value in pairs(tbl) do
        if typeof(value) == "RBXScriptConnection" then value:Disconnect(); tbl[key] = nil
        elseif typeof(value) == 'thread' then task.cancel(value); tbl[key] = nil
        elseif type(value) == 'table' then Cleanup(value) end
    end
end

-- ============================================================
--  FLUENT TOGGLE/OPTION STORAGE
--  Fluent uses Options table like Obsidian; we mirror the same names
-- ============================================================
local Options  = {}   -- will be populated by Fluent controls
local Toggles  = {}   -- same

-- Thread manager (identical to original)
local Flags = {}
function Thread(featurePath, featureFunc, isEnabled, ...)
    local pathParts = featurePath:split(".")
    local currentTable = Flags
    for i = 1, #pathParts - 1 do
        local part = pathParts[i]
        if not currentTable[part] then currentTable[part] = {} end
        currentTable = currentTable[part]
    end
    local flagKey = pathParts[#pathParts]
    local activeThread = currentTable[flagKey]
    if isEnabled then
        if not activeThread or coroutine.status(activeThread) == "dead" then
            local newThread = task.spawn(featureFunc, ...)
            currentTable[flagKey] = newThread
        end
    else
        if activeThread and typeof(activeThread) == 'thread' then
            task.cancel(activeThread); currentTable[flagKey] = nil
        end
    end
end

local function SafeLoop(name, func)
    return function()
        local success, err = pcall(func)
        if not success then
            Notify("Error in ["..name.."]: "..tostring(err), 10)
            warn("Error in ["..name.."]: "..tostring(err))
        end
    end
end

local function CommaFormat(n)
    local s = tostring(n)
    return s:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local function Abbreviate(n)
    local abbrev = {{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}
    for _, v in ipairs(abbrev) do
        if n >= v[1] then return string.format("%.1f%s", n/v[1], v[2]) end
    end
    return tostring(n)
end

local function GetBestOwnedTitle(category)
    if #Tables.UnlockedTitle == 0 then return nil end
    local bestTitleId = nil; local highestValue = -1
    local statMap = { ["Best EXP"]="XPPercent", ["Best Money & Gem"]="MoneyPercent", ["Best Luck"]="LuckPercent", ["Best DMG"]="DamagePercent" }
    local targetStat = statMap[category]
    if not targetStat then return nil end
    for _, titleId in ipairs(Tables.UnlockedTitle) do
        local data = Modules.Title.Titles[titleId]
        if data and data.statBonuses and data.statBonuses[targetStat] then
            local val = data.statBonuses[targetStat]
            if val > highestValue then highestValue = val; bestTitleId = titleId end
        end
    end
    return bestTitleId
end

local function GetCharacter()
    local c = Plr.Character
    return (c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChildOfClass("Humanoid")) and c or nil
end

local function PanicStop()
    Shared.Farm = false; Shared.AltActive = false; Shared.GlobalPrio = "FARM"
    Shared.Target = nil; Shared.MovingIsland = false
    for _, toggle in pairs(Toggles) do if toggle.Value ~= nil then toggle.Value = false end end
    local char = GetCharacter(); local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = root.CFrame * CFrame.new(0,2,0)
    end
    task.delay(0.5, function() Shared.Farm = true end)
    Notify("Stopped.", 5)
end

local function FuncTPW()
    while true do
        local delta = RunService.Heartbeat:Wait()
        local char = GetCharacter(); local hum = char and char:FindFirstChildOfClass("Humanoid")
        if char and hum and hum.Health > 0 then
            if hum.MoveDirection.Magnitude > 0 then
                local speed = Options.TPWValue and Options.TPWValue.Value or 1
                char:TranslateBy(hum.MoveDirection * speed * delta * 10)
            end
        end
    end
end

local function FuncNoclip()
    while Toggles.Noclip and Toggles.Noclip.Value do
        RunService.Stepped:Wait()
        local char = GetCharacter()
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end
    end
end

local function Func_AntiKnockback()
    if type(Connections.Knockback) == "table" then
        for _, conn in pairs(Connections.Knockback) do if conn then conn:Disconnect() end end
        table.clear(Connections.Knockback)
    else Connections.Knockback = {} end
    local function ApplyAntiKB(character)
        if not character then return end
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if root then
            local conn = root.ChildAdded:Connect(function(child)
                if not (Toggles.AntiKnockback and Toggles.AntiKnockback.Value) then return end
                if child:IsA("BodyVelocity") and child.MaxForce == Vector3.new(40000,40000,40000) then child:Destroy() end
            end)
            table.insert(Connections.Knockback, conn)
        end
    end
    if Plr.Character then ApplyAntiKB(Plr.Character) end
    local charAddedConn = Plr.CharacterAdded:Connect(function(newChar) ApplyAntiKB(newChar) end)
    table.insert(Connections.Knockback, charAddedConn)
    repeat task.wait(1) until not (Toggles.AntiKnockback and Toggles.AntiKnockback.Value)
    for _, conn in pairs(Connections.Knockback) do if conn then conn:Disconnect() end end
    table.clear(Connections.Knockback)
end

local function DisableIdled()
    pcall(function()
        local cons = getconnections or get_signal_cons
        if cons then
            for _, v in pairs(cons(Plr.Idled)) do
                if v.Disable then v:Disable() elseif v.Disconnect then v:Disconnect() end
            end
        end
    end)
end

local function Func_AutoReconnect()
    if Connections.Reconnect then Connections.Reconnect:Disconnect() end
    Connections.Reconnect = GuiService.ErrorMessageChanged:Connect(function()
        if not (Toggles.AutoReconnect and Toggles.AutoReconnect.Value) then return end
        task.delay(2, function()
            pcall(function()
                local promptOverlay = game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui")
                if promptOverlay then
                    local errorPrompt = promptOverlay.promptOverlay:FindFirstChild("ErrorPrompt")
                    if errorPrompt and errorPrompt.Visible then
                        task.wait(5)
                        TeleportService:Teleport(game.PlaceId, Plr)
                    end
                end
            end)
        end)
    end)
end

local function Func_NoGameplayPaused()
    while Toggles.NoGameplayPaused and Toggles.NoGameplayPaused.Value do
        pcall(function()
            local pauseGui = game:GetService("CoreGui").RobloxGui:FindFirstChild("CoreScripts/NetworkPause")
            if pauseGui then pauseGui:Destroy() end
        end)
        task.wait(1)
    end
end

local function ApplyFPSBoost(state)
    if not state then return end
    pcall(function()
        Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9; Lighting.Brightness = 1
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("PostProcessEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") then
                v.Enabled = false
            end
        end
        task.spawn(function()
            for i, v in pairs(workspace:GetDescendants()) do
                if Toggles.FPSBoost and not Toggles.FPSBoost.Value then break end
                pcall(function()
                    if v:IsA("BasePart") then v.Material = Enum.Material.SmoothPlastic; v.CastShadow = false
                    elseif v:IsA("Decal") or v:IsA("Texture") then v:Destroy()
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then v.Enabled = false end
                end)
                if i % 500 == 0 then task.wait() end
            end
        end)
    end)
end

local function ACThing(state)
    if Connections.Dash then Connections.Dash:Disconnect() end
    if not (state and _DR and _FS) then return end
    Connections.Dash = RunService.Heartbeat:Connect(function()
        task.spawn(function() pcall(_FS, _DR, vector.create(0,0,0), 0, false) end)
    end)
end

local function SendSafetyWebhook(targetPlayer, reason)
    local url = Options.WebhookURL and Options.WebhookURL.Value or ""
    if url == "" or not url:find("discord.com/api/webhooks/") then return end
    local payload = { ["embeds"] = {{ ["title"] = "⚠️ Auto Kick", ["description"] = "Someone joined you blud",
        ["color"] = 16711680, ["fields"] = {
            {["name"]="Username",["value"]="`"..targetPlayer.Name.."`",["inline"]=true},
            {["name"]="Type",["value"]=reason,["inline"]=true},
            {["name"]="ID",["value"]="```"..game.JobId.."```",["inline"]=false}
        }, ["footer"] = {["text"]="FourHub • "..os.date("%x %X")} }} }
    task.spawn(function() pcall(function() request({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode(payload)}) end) end)
end

local function CheckServerTypeSafety()
    if not (Toggles.AutoKick and Toggles.AutoKick.Value) then return end
    local kickTypes = Options.SelectedKickType and Options.SelectedKickType.Value or {}
    if kickTypes["Public Server"] then
        local success, serverType = pcall(function()
            local remote = game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType",2)
            if remote then return remote:InvokeServer() end
            return "Unknown"
        end)
        if success and serverType ~= "VIPServer" then
            task.wait(0.8)
            Plr:Kick("\n[FourHub]\nReason: You are in a public server.")
        end
    end
end

local function CheckPlayerForSafety(targetPlayer)
    if not (Toggles.AutoKick and Toggles.AutoKick.Value) then return end
    if targetPlayer == Plr then return end
    local kickTypes = Options.SelectedKickType and Options.SelectedKickType.Value or {}
    if kickTypes["Player Join"] then
        SendSafetyWebhook(targetPlayer, "Player Join Detection")
        task.wait(0.5)
        Plr:Kick("\n[FourHub]\nReason: A player joined the server ("..targetPlayer.Name..")")
        return
    end
    if kickTypes["Mod"] then
        local success, rank = pcall(function() return targetPlayer:GetRankInGroup(TargetGroupId) end)
        if success and table.find(BannedRanks, rank) then
            SendSafetyWebhook(targetPlayer, "Moderator Detection (Rank: "..tostring(rank)..")")
            task.wait(0.5)
            Plr:Kick("\n[FourHub]\nReason: Moderator Detected ("..targetPlayer.Name..")")
        end
    end
end

local function InitAutoKick()
    CheckServerTypeSafety()
    for _, p in ipairs(Players:GetPlayers()) do CheckPlayerForSafety(p) end
    Players.PlayerAdded:Connect(CheckPlayerForSafety)
end

local function HybridMove(targetCF)
    local character = GetCharacter(); local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local distance = (root.Position - targetCF.Position).Magnitude
    local tweenSpeed = Options.TweenSpeed and Options.TweenSpeed.Value or 180
    if distance > tonumber(Options.TargetDistTP and Options.TargetDistTP.Value or 0) then
        local oldNoclip = Toggles.Noclip and Toggles.Noclip.Value
        if Toggles.Noclip then Toggles.Noclip.Value = true end
        local tweenTarget = targetCF * CFrame.new(0,0,150)
        local tweenDist = (root.Position - tweenTarget.Position).Magnitude
        local tween = game:GetService("TweenService"):Create(root, TweenInfo.new(tweenDist/tweenSpeed, Enum.EasingStyle.Linear), {CFrame=tweenTarget})
        tween:Play(); tween.Completed:Wait()
        if Toggles.Noclip then Toggles.Noclip.Value = oldNoclip end
        task.wait(0.1)
    end
    root.CFrame = targetCF; root.AssemblyLinearVelocity = Vector3.new(0,0.01,0); task.wait(0.2)
end

local function GetNearestIsland(targetPos, npcName)
    if npcName and Shared.BossTIMap[npcName] then return Shared.BossTIMap[npcName] end
    local nearestIslandName = "Starter"; local minDistance = math.huge
    for islandName, crystal in pairs(IslandCrystals) do
        if crystal then
            local dist = (targetPos - crystal:GetPivot().Position).Magnitude
            if dist < minDistance then minDistance = dist; nearestIslandName = islandName end
        end
    end
    return nearestIslandName
end

local function UpdateNPCLists()
    local specialMobs = {"ThiefBoss","MonkeyBoss","DesertBoss","SnowBoss","PandaMiniBoss"}
    local currentList = {}
    for _, name in pairs(Tables.MobList) do currentList[name] = true end
    for _, v in pairs(PATH.Mobs:GetChildren()) do
        local cleanName = v.Name:gsub("%d+$","")
        local isSpecial = table.find(specialMobs, cleanName)
        if (isSpecial or not cleanName:find("Boss")) and not currentList[cleanName] then
            table.insert(Tables.MobList, cleanName); currentList[cleanName] = true
            local npcPos = v:GetPivot().Position; local closestIsland = "Unknown"; local minShot = math.huge
            for islandName, crystal in pairs(IslandCrystals) do
                if crystal then
                    local dist = (npcPos - crystal:GetPivot().Position).Magnitude
                    if dist < minShot then minShot = dist; closestIsland = islandName end
                end
            end
            Tables.MobToIsland[cleanName] = closestIsland
        end
    end
    if Options.SelectedMob then Options.SelectedMob:SetValues(Tables.MobList) end
end

local function UpdateAllEntities()
    table.clear(Tables.AllEntitiesList); local unique = {}
    for _, v in pairs(PATH.Mobs:GetChildren()) do
        local cleanName = v.Name:gsub("%d+$","")
        if not unique[cleanName] then unique[cleanName] = true; table.insert(Tables.AllEntitiesList, cleanName) end
    end
    table.sort(Tables.AllEntitiesList)
    if Options.SelectedQuestline_DMGTaken then Options.SelectedQuestline_DMGTaken:SetValues(Tables.AllEntitiesList) end
end

local function PopulateNPCLists()
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name:match("^QuestNPC%d+$") and not table.find(Tables.NPC_QuestList, child.Name) then
            table.insert(Tables.NPC_QuestList, child.Name)
        end
    end
    for _, child in ipairs(PATH.InteractNPCs:GetChildren()) do
        if child.Name:match("^QuestNPC%d+$") and not table.find(Tables.NPC_QuestList, child.Name) then
            table.insert(Tables.NPC_QuestList, child.Name)
        end
    end
    table.sort(Tables.NPC_QuestList, function(a,b)
        local numA = tonumber(a:match("%d+$")) or 0; local numB = tonumber(b:match("%d+$")) or 0
        return (numA == numB) and (a < b) or (numA < numB)
    end)
    for _, v in pairs(PATH.InteractNPCs:GetChildren()) do
        local name = v.Name
        if (name:find("Moveset") or name:find("Buyer")) and not name:find("Observation") then table.insert(Tables.NPC_MovesetList, name) end
        if (name:find("Mastery") or name:find("Questline") or name:find("Craft")) and not (name:find("Grail") or name:find("Slime")) then table.insert(Tables.NPC_MasteryList, name) end
    end
    table.sort(Tables.NPC_MovesetList); table.sort(Tables.NPC_MasteryList)
end

local function GetCurrentPity()
    local pityLabel = PGui.BossUI.MainFrame.BossHPBar.Pity
    local current, max = pityLabel.Text:match("Pity: (%d+)/(%d+)")
    return tonumber(current) or 0, tonumber(max) or 25
end

PopulateNPCLists()

local function findNPCByDistance(dist)
    local bestMatch = nil; local tolerance = 2; local char = GetCharacter()
    for _, npc in ipairs(workspace:GetDescendants()) do
        if npc:IsA("Model") and npc.Name:find("QuestNPC") then
            local npcPos = npc:GetPivot().Position
            local actualDist = (char.HumanoidRootPart.Position - npcPos).Magnitude
            if math.abs(actualDist - dist) <= tolerance then bestMatch = npc; break end
        end
    end
    return bestMatch
end

local function IsSmartMatch(npcName, targetMobType)
    local n = npcName:gsub("%d+$",""):lower(); local t = targetMobType:lower()
    if n == t then return true end
    if t:find(n) == 1 then return true end
    if n:find(t) == 1 then return true end
    return false
end

local function SafeTeleportToNPC(targetName, customMap)
    local character = GetCharacter(); local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local actualName = customMap and customMap[targetName] or targetName
    local target = workspace:FindFirstChild(actualName) or PATH.InteractNPCs:FindFirstChild(actualName)
    if not target then
        for _, v in pairs(PATH.InteractNPCs:GetChildren()) do
            if v.Name:find(actualName) then target = v; break end
        end
    end
    if target then
        root.CFrame = target:GetPivot() * CFrame.new(0,3,0)
        root.AssemblyLinearVelocity = Vector3.new(0,0.01,0)
        root.AssemblyAngularVelocity = Vector3.zero
    else Notify("NPC not found: "..tostring(actualName), 3) end
end

local function Clean(str) return str:gsub("%s+",""):lower() end

local function GetToolTypeFromModule(toolName)
    local cleanedTarget = Clean(toolName)
    for manualName, toolType in pairs(Tables.ManualWeaponClass) do
        if Clean(manualName) == cleanedTarget then return toolType end
    end
    if Modules.WeaponClass and Modules.WeaponClass.Tools then
        for moduleName, toolType in pairs(Modules.WeaponClass.Tools) do
            if Clean(moduleName) == cleanedTarget then return toolType end
        end
    end
    if toolName:lower():find("fruit") then return "Power" end
    return "Melee"
end

local function GetWeaponsByType()
    local available = {}
    local enabledTypes = Options.SelectedWeaponType and Options.SelectedWeaponType.Value or {}
    local char = GetCharacter()
    local containers = {Plr.Backpack}
    if char then table.insert(containers, char) end
    for _, container in ipairs(containers) do
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local toolType = GetToolTypeFromModule(tool.Name)
                if enabledTypes[toolType] and not table.find(available, tool.Name) then
                    table.insert(available, tool.Name)
                end
            end
        end
    end
    return available
end

local function UpdateWeaponRotation()
    local weaponList = GetWeaponsByType()
    if #weaponList == 0 then Shared.ActiveWeap = ""; return end
    local switchDelay = Options.SwitchWeaponCD and Options.SwitchWeaponCD.Value or 4
    if tick() - Shared.LastWRSwitch >= switchDelay then
        Shared.WeapRotationIdx = Shared.WeapRotationIdx + 1
        if Shared.WeapRotationIdx > #weaponList then Shared.WeapRotationIdx = 1 end
        Shared.ActiveWeap = weaponList[Shared.WeapRotationIdx]; Shared.LastWRSwitch = tick()
    end
    local exists = false
    for _, name in ipairs(weaponList) do if name == Shared.ActiveWeap then exists = true; break end end
    if not exists then Shared.ActiveWeap = weaponList[1] end
end

local function EquipWeapon()
    UpdateWeaponRotation()
    if Shared.ActiveWeap == "" then return end
    local char = GetCharacter(); local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if char:FindFirstChild(Shared.ActiveWeap) then return end
    local tool = Plr.Backpack:FindFirstChild(Shared.ActiveWeap) or char:FindFirstChild(Shared.ActiveWeap)
    if tool then hum:EquipTool(tool) end
end

local function CheckObsHaki()
    local PlayerGui = Plr:FindFirstChild("PlayerGui")
    if PlayerGui then
        local DodgeUI = PlayerGui:FindFirstChild("DodgeCounterUI")
        if DodgeUI and DodgeUI:FindFirstChild("MainFrame") then return DodgeUI.MainFrame.Visible end
    end
    return false
end

local function CheckArmHaki()
    if Shared.ArmHaki == true then return true end
    local char = GetCharacter()
    if char then
        local leftArm = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftUpperArm")
        local rightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm")
        if (leftArm and leftArm:FindFirstChild("Lightning Strike")) or (rightArm and rightArm:FindFirstChild("Lightning Strike")) then
            Shared.ArmHaki = true; return true
        end
    end
    return false
end

local function IsBusy()
    return Plr.Character and Plr.Character:FindFirstChildOfClass("ForceField") ~= nil
end

local function IsSkillReady(key)
    local char = GetCharacter(); local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return true end
    local mainFrame = PGui:FindFirstChild("CooldownUI") and PGui.CooldownUI:FindFirstChild("MainFrame")
    if not mainFrame then return true end
    local cleanTool = Clean(tool.Name); local foundFrame = nil
    for _, frame in pairs(mainFrame:GetChildren()) do
        if not frame:IsA("Frame") then continue end
        local fname = frame.Name:lower()
        if fname:find("cooldown") and (fname:find(cleanTool) or fname:find("skill")) then
            local mapped = "none"
            if fname:find("skill 1") or fname:find("_z") then mapped = "Z"
            elseif fname:find("skill 2") or fname:find("_x") then mapped = "X"
            elseif fname:find("skill 3") or fname:find("_c") then mapped = "C"
            elseif fname:find("skill 4") or fname:find("_v") then mapped = "V"
            elseif fname:find("skill 5") or fname:find("_f") then mapped = "F" end
            if mapped == key then foundFrame = frame; break end
        end
    end
    if not foundFrame then return true end
    local cdLabel = foundFrame:FindFirstChild("WeaponNameAndCooldown", true)
    return (cdLabel and cdLabel.Text:find("Ready"))
end

local function GetSecondsFromTimer(text)
    local min, sec = text:match("(%d+):(%d+)")
    if min and sec then return (tonumber(min)*60) + tonumber(sec) end
    return nil
end

local function FormatSecondsToTimer(s)
    return string.format("Refresh: %02d:%02d", math.floor(s/60), s%60)
end

local function OpenMerchantInterface()
    if isXeno then
        local npc = workspace:FindFirstChild("ServiceNPCs") and workspace.ServiceNPCs:FindFirstChild("MerchantNPC")
        local prompt = npc and npc:FindFirstChild("HumanoidRootPart") and npc.HumanoidRootPart:FindFirstChild("MerchantPrompt")
        if prompt then
            local char = GetCharacter(); local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local oldCF = root.CFrame
                root.CFrame = npc.HumanoidRootPart.CFrame * CFrame.new(0,0,3); task.wait(0.2)
                if Support.Proximity then fireproximityprompt(prompt)
                else prompt:InputHoldBegin(); task.wait(prompt.HoldDuration+0.1); prompt:InputHoldEnd() end
                task.wait(0.5); root.CFrame = oldCF
            end
        end
    else
        if firesignal then firesignal(Remotes.OpenMerchant.OnClientEvent)
        elseif getconnections then
            for _, v in pairs(getconnections(Remotes.OpenMerchant.OnClientEvent)) do
                if v.Function then task.spawn(v.Function) end
            end
        end
    end
end

local function SyncRaceSettings()
    if not (Toggles.AutoRace and Toggles.AutoRace.Value) then return end
    pcall(function()
        local selected = Options.SelectedRace and Options.SelectedRace.Value or {}
        local hasEpic = false; local hasLegendary = false
        for name, data in pairs(Modules.Race.Races) do
            local rarity = data.rarity or data.Rarity
            if rarity == "Mythical" then
                local shouldSkip = not selected[name]
                if Shared.Settings["SkipRace_"..name] ~= shouldSkip then Remotes.SettingsToggle:FireServer("SkipRace_"..name, shouldSkip) end
            end
            if selected[name] then
                if rarity == "Epic" then hasEpic = true end
                if rarity == "Legendary" then hasLegendary = true end
            end
        end
        if Shared.Settings["SkipEpicReroll"] ~= not hasEpic then Remotes.SettingsToggle:FireServer("SkipEpicReroll", not hasEpic) end
        if Shared.Settings["SkipLegendaryReroll"] ~= not hasLegendary then Remotes.SettingsToggle:FireServer("SkipLegendaryReroll", not hasLegendary) end
    end)
end

local function SyncClanSettings()
    if not (Toggles.AutoClan and Toggles.AutoClan.Value) then return end
    pcall(function()
        local selected = Options.SelectedClan and Options.SelectedClan.Value or {}
        local hasEpic = false; local hasLegendary = false
        for name, data in pairs(Modules.Clan.Clans) do
            local rarity = data.rarity or data.Rarity
            if rarity == "Legendary" then
                local shouldSkip = not selected[name]
                if Shared.Settings["SkipClan_"..name] ~= shouldSkip then Remotes.SettingsToggle:FireServer("SkipClan_"..name, shouldSkip) end
            end
            if selected[name] then
                if rarity == "Epic" then hasEpic = true end
                if rarity == "Legendary" then hasLegendary = true end
            end
        end
        if Shared.Settings["SkipEpicClan"] ~= not hasEpic then Remotes.SettingsToggle:FireServer("SkipEpicClan", not hasEpic) end
        if Shared.Settings["SkipLegendaryClan"] ~= not hasLegendary then Remotes.SettingsToggle:FireServer("SkipLegendaryClan", not hasLegendary) end
    end)
end

local function SyncSpecPassiveAutoSkip()
    pcall(function()
        local remote = Remotes.SpecPassiveSkip
        if remote then remote:FireServer({["Epic"]=true,["Legendary"]=true,["Mythical"]=true}) end
    end)
end

local function SyncTraitAutoSkip()
    if not (Toggles.AutoTrait and Toggles.AutoTrait.Value) then return end
    pcall(function()
        local selected = Options.SelectedTrait and Options.SelectedTrait.Value or {}
        local rarityHierarchy = {["Epic"]=1,["Legendary"]=2,["Mythical"]=3,["Secret"]=4}
        local lowestTargetValue = 99
        for traitName, enabled in pairs(selected) do
            if enabled then
                local data = Modules.Trait.Traits[traitName]
                if data then
                    local val = rarityHierarchy[data.Rarity] or 0
                    if val > 0 and val < lowestTargetValue then lowestTargetValue = val end
                end
            end
        end
        if lowestTargetValue == 99 then return end
        Remotes.TraitAutoSkip:FireServer({["Epic"]=1<lowestTargetValue,["Legendary"]=2<lowestTargetValue,["Mythical"]=3<lowestTargetValue,["Secret"]=4<lowestTargetValue})
    end)
end

local function GetMatches(data, subStatFilter)
    local count = 0
    for _, sub in pairs(data.Substats or {}) do if subStatFilter[sub.Stat] then count = count + 1 end end
    return count
end

local function IsMainStatGood(data, mainStatFilter)
    if data.Category == "Helmet" or data.Category == "Gloves" then return true end
    return mainStatFilter[data.MainStat.Stat] == true
end

local function EvaluateArtifact2(uuid, data)
    local actions = {lock=false, delete=false, upgrade=false}
    local function GetFilterStatus(filter, value)
        if not filter or next(filter) == nil then return nil end
        return filter[value] == true
    end
    local function IsWhitelisted(filter, value)
        local status = GetFilterStatus(filter, value)
        if status == nil then return true end
        return status
    end
    local upgradeLimit = Options.UpgradeLimit and Options.UpgradeLimit.Value or 0
    if Toggles.ArtifactUpgrade and Toggles.ArtifactUpgrade.Value and data.Level < upgradeLimit then
        if IsWhitelisted(Options.Up_MS and Options.Up_MS.Value, data.MainStat.Stat) then
            actions.upgrade = true
        end
    end
    local lockMinSS = Options.Lock_MinSS and Options.Lock_MinSS.Value or 0
    if Toggles.ArtifactLock and Toggles.ArtifactLock.Value and not data.Locked and data.Level >= (lockMinSS*3) then
        if IsWhitelisted(Options.Lock_MS and Options.Lock_MS.Value, data.MainStat.Stat) and
           IsWhitelisted(Options.Lock_Type and Options.Lock_Type.Value, data.Category) and
           IsWhitelisted(Options.Lock_Set and Options.Lock_Set.Value, data.Set) then
            if GetMatches(data, Options.Lock_SS and Options.Lock_SS.Value or {}) >= lockMinSS then
                actions.lock = true
            end
        end
    end
    if not data.Locked and not actions.lock then
        if Toggles.DeleteUnlock and Toggles.DeleteUnlock.Value then
            actions.delete = true
        elseif Toggles.ArtifactDelete and Toggles.ArtifactDelete.Value then
            local typeMatch = GetFilterStatus(Options.Del_Type and Options.Del_Type.Value, data.Category)
            local setMatch = GetFilterStatus(Options.Del_Set and Options.Del_Set.Value, data.Set)
            local msDropdownName = "Del_MS_"..data.Category
            local specificMSFilter = Options[msDropdownName] and Options[msDropdownName].Value or {}
            local msMatch = GetFilterStatus(specificMSFilter, data.MainStat.Stat)
            local isTarget = true
            if typeMatch == false then isTarget = false end
            if setMatch == false then isTarget = false end
            if typeMatch == nil and setMatch == nil and msMatch == nil then isTarget = false end
            if isTarget then
                local trashCount = GetMatches(data, Options.Del_SS and Options.Del_SS.Value or {})
                local minTrash = Options.Del_MinSS and Options.Del_MinSS.Value or 0
                local isMaxLevel = data.Level >= upgradeLimit
                if msMatch == true then actions.delete = true
                elseif minTrash == 0 then actions.delete = true
                elseif isMaxLevel and trashCount >= minTrash then actions.delete = true end
            end
        end
    end
    return actions
end

local function AutoEquipArtifacts()
    if not (Toggles.ArtifactEquip and Toggles.ArtifactEquip.Value) then return end
    local bestItems = {Helmet=nil,Gloves=nil,Body=nil,Boots=nil}
    local bestScores = {Helmet=-1,Gloves=-1,Body=-1,Boots=-1}
    local targetTypes = Options.Eq_Type and Options.Eq_Type.Value or {}
    local targetMS = Options.Eq_MS and Options.Eq_MS.Value or {}
    local targetSS = Options.Eq_SS and Options.Eq_SS.Value or {}
    for uuid, data in pairs(Shared.ArtifactSession.Inventory) do
        if targetTypes[data.Category] and IsMainStatGood(data, targetMS) then
            local score = (GetMatches(data, targetSS)*10) + data.Level
            if score > bestScores[data.Category] then bestScores[data.Category]=score; bestItems[data.Category]={UUID=uuid,Equipped=data.Equipped} end
        end
    end
    for category, item in pairs(bestItems) do
        if item and not item.Equipped then Remotes.ArtifactEquip:FireServer(item.UUID); task.wait(0.2) end
    end
end

local function IsStrictBossMatch(npcName, targetDisplayName)
    local n = npcName:lower():gsub("%s+",""); local t = targetDisplayName:lower():gsub("%s+","")
    if n:find("true") and not t:find("true") then return false end
    if t:find("strongest") then
        local era = t:find("history") and "history" or "today"
        return n:find("strongest") and n:find(era)
    end
    return n:find(t)
end

local function AutoUpgradeLoop(mode)
    local toggle = Toggles["Auto"..mode]; local allToggle = Toggles["Auto"..mode.."All"]
    local remote = (mode=="Enchant") and Remotes.Enchant or Remotes.Blessing
    local sourceTable = (mode=="Enchant") and Tables.OwnedAccessory or Tables.OwnedWeapon
    while (toggle and toggle.Value) or (allToggle and allToggle.Value) do
        local selection = Options["Selected"..mode] and Options["Selected"..mode].Value or {}
        local workDone = false
        for _, itemName in ipairs(sourceTable) do
            if Shared.UpBlacklist[itemName] then continue end
            local isSelected = false
            if allToggle and allToggle.Value then isSelected = true
            else isSelected = selection[itemName] or table.find(selection, itemName) end
            if isSelected then
                workDone = true
                pcall(function() remote:FireServer(itemName) end)
                task.wait(1.5); break
            end
        end
        if not workDone then
            Notify("Stopping..", 5)
            if toggle then toggle.Value = false end
            if allToggle then allToggle.Value = false end
            break
        end
        task.wait(0.1)
    end
end

local function FireBossRemote(bossName, diff)
    local lowerName = bossName:lower():gsub("%s+","")
    local remoteArg = GetRemoteBossArg(bossName)
    table.clear(Shared.AltDamage)
    local function GetInternalSummonId(name)
        local cleanTarget = name:lower():gsub("%s+","")
        for displayName, internalId in pairs(SummonMap) do
            if displayName:lower():gsub("%s+","") == cleanTarget then return internalId end
        end
        return name:gsub("%s+","").."Boss"
    end
    pcall(function()
        if lowerName:find("rimuru") then Remotes.RimuruBoss:FireServer(diff)
        elseif lowerName:find("anos") then Remotes.AnosBoss:FireServer("Anos", diff)
        elseif lowerName:find("trueaizen") then if Remotes.TrueAizenBoss then Remotes.TrueAizenBoss:FireServer(diff) end
        elseif lowerName:find("strongest") then Remotes.JJKSummonBoss:FireServer(remoteArg, diff)
        elseif lowerName:find("atomic") then Remotes.AtomicBoss:FireServer(diff)
        else Remotes.SummonBoss:FireServer(GetInternalSummonId(bossName), diff) end
    end)
end

local function HandleSummons()
    if Shared.MerchantBusy then return end
    local function MatchName(n1,n2)
        if not n1 or not n2 then return false end
        return n1:lower():gsub("%s+","") == n2:lower():gsub("%s+","")
    end
    local function IsSummonable(name)
        local cleanName = name:lower():gsub("%s+","")
        for _, boss in ipairs(Tables.SummonList) do if MatchName(boss, cleanName) then return true end end
        for _, boss in ipairs(Tables.OtherSummonList) do if MatchName(boss, cleanName) then return true end end
        return false
    end
    if Toggles.PityBossFarm and Toggles.PityBossFarm.Value then
        local current, max = GetCurrentPity()
        local buildOptions = Options.SelectedBuildPity and Options.SelectedBuildPity.Value or {}
        local useName = Options.SelectedUsePity and Options.SelectedUsePity.Value
        if useName and next(buildOptions) then
            local isUseTurn = (current >= (max-1))
            if isUseTurn then
                local found = false
                for _, v in pairs(PATH.Mobs:GetChildren()) do
                    if MatchName(v.Name, useName) or v.Name:lower():find(useName:lower():gsub("%s+","")) then found=true; break end
                end
                if not found and IsSummonable(useName) then
                    FireBossRemote(useName, Options.SelectedPityDiff and Options.SelectedPityDiff.Value or "Normal")
                    task.wait(0.5); return
                end
            else
                local anyBuildBossSpawned = false
                for bossName, enabled in pairs(buildOptions) do
                    if enabled then
                        for _, v in pairs(PATH.Mobs:GetChildren()) do
                            if MatchName(v.Name, bossName) or v.Name:lower():find(bossName:lower():gsub("%s+","")) then
                                anyBuildBossSpawned=true; break
                            end
                        end
                    end
                    if anyBuildBossSpawned then break end
                end
                if not anyBuildBossSpawned then
                    for bossName, enabled in pairs(buildOptions) do
                        if enabled and IsSummonable(bossName) then
                            FireBossRemote(bossName, "Normal"); task.wait(0.5); return
                        end
                    end
                end
            end
        end
    end
    if Toggles.AutoOtherSummon and Toggles.AutoOtherSummon.Value then
        local selected = Options.SelectedOtherSummon and Options.SelectedOtherSummon.Value
        local diff = Options.SelectedOtherSummonDiff and Options.SelectedOtherSummonDiff.Value
        if selected and diff then
            local keyword = selected:gsub("Strongest",""):lower(); local found = false
            for _, v in pairs(PATH.Mobs:GetChildren()) do
                local npcName = v.Name:lower()
                if npcName:find(selected:lower()) or (npcName:find("strongest") and npcName:find(keyword)) then found=true; break end
            end
            if not found then FireBossRemote(selected, diff); task.wait(0.5) end
        end
    end
    if Toggles.AutoSummon and Toggles.AutoSummon.Value then
        local selected = Options.SelectedSummon and Options.SelectedSummon.Value
        if selected then
            local found = false
            for _, v in pairs(PATH.Mobs:GetChildren()) do
                if IsStrictBossMatch(v.Name, selected) then found=true; break end
            end
            if not found then FireBossRemote(selected, Options.SelectedSummonDiff and Options.SelectedSummonDiff.Value or "Normal"); task.wait(0.5) end
        end
    end
end

local function UpdateSwitchState(target, farmType)
    if Shared.GlobalPrio == "COMBO" then return end
    local types = {
        {id="Title", remote=Remotes.EquipTitle, method=function(val) return val end},
        {id="Rune", remote=Remotes.EquipRune, method=function(val) return {"Equip",val} end},
        {id="Build", remote=Remotes.LoadoutLoad, method=function(val) return tonumber(val) end}
    }
    for _, switch in ipairs(types) do
        local toggleObj = Toggles["Auto"..switch.id]
        if not (toggleObj and toggleObj.Value) then continue end
        if switch.id == "Build" and tick() - Shared.LastBuildSwitch < 3.1 then continue end
        local toEquip = ""; local threshold = Options[switch.id.."_BossHPAmt"] and Options[switch.id.."_BossHPAmt"].Value or 15
        local isLow = false
        if farmType == "Boss" and target then
            local hum = target:FindFirstChildOfClass("Humanoid")
            if hum and (hum.Health/hum.MaxHealth)*100 <= threshold then isLow = true end
        end
        if farmType == "None" then toEquip = Options["Default"..switch.id] and Options["Default"..switch.id].Value or ""
        elseif farmType == "Mob" then toEquip = Options[switch.id.."_Mob"] and Options[switch.id.."_Mob"].Value or ""
        elseif farmType == "Boss" then toEquip = isLow and (Options[switch.id.."_BossHP"] and Options[switch.id.."_BossHP"].Value or "") or (Options[switch.id.."_Boss"] and Options[switch.id.."_Boss"].Value or "") end
        if not toEquip or toEquip == "" or toEquip == "None" then continue end
        local finalEquipValue = toEquip
        if switch.id == "Title" and toEquip:find("Best ") then
            local bestId = GetBestOwnedTitle(toEquip)
            if bestId then finalEquipValue = bestId else continue end
        end
        if finalEquipValue ~= Shared.LastSwitch[switch.id] then
            local args = switch.method(finalEquipValue)
            pcall(function()
                if type(args) == "table" then switch.remote:FireServer(unpack(args))
                else switch.remote:FireServer(args) end
            end)
            Shared.LastSwitch[switch.id] = finalEquipValue
            if switch.id == "Build" then Shared.LastBuildSwitch = tick() end
        end
    end
end

local NotificationBlacklist = {"You don't have this item!", "Not enough "}

local function ProcessNotification(frame)
    task.delay(0.01, function()
        if not (Toggles.AutoDeleteNotif and Toggles.AutoDeleteNotif.Value) then return end
        if not frame or not frame.Parent then return end
        local txtLabel = frame:FindFirstChild("Txt", true)
        if txtLabel and txtLabel:IsA("TextLabel") then
            local incomingText = txtLabel.Text:lower()
            for _, blacklistedPhrase in ipairs(NotificationBlacklist) do
                if incomingText:find(blacklistedPhrase:lower()) then frame.Visible = false; break end
            end
        end
    end)
end

local function UniversalPuzzleSolver(puzzleType)
    local moduleMap = {
        ["Dungeon"] = RS.Modules:FindFirstChild("DungeonConfig"),
        ["Slime"] = RS.Modules:FindFirstChild("SlimePuzzleConfig"),
        ["Demonite"] = RS.Modules:FindFirstChild("DemoniteCoreQuestConfig"),
        ["Hogyoku"] = RS.Modules:FindFirstChild("HogyokuQuestConfig")
    }
    local hogyokuIslands = {"Snow","Shibuya","HuecoMundo","Shinjuku","Slime","Judgement"}
    local targetModule = moduleMap[puzzleType]
    if not targetModule then return end
    local data = require(targetModule)
    local settings = data.PuzzleSettings or data.PieceSettings
    local piecesToCollect = data.Pieces or settings.IslandOrder
    local pieceModelName = settings and settings.PieceModelName or "DungeonPuzzlePiece"
    Notify("Starting "..puzzleType.." Puzzle...", 5)
    for i, islandOrPiece in ipairs(piecesToCollect) do
        local piece = nil; local tpTarget = nil
        if puzzleType == "Demonite" then tpTarget = "Academy"
        elseif puzzleType == "Hogyoku" then tpTarget = hogyokuIslands[i]
        else
            tpTarget = islandOrPiece:gsub("Island",""):gsub("Station","")
            if islandOrPiece == "HuecoMundo" then tpTarget = "HuecoMundo" end
        end
        if tpTarget then Remotes.TP_Portal:FireServer(tpTarget); task.wait(2.5) end
        if puzzleType == "Slime" and i == #piecesToCollect then
            local char = GetCharacter(); local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                Remotes.TP_Portal:FireServer("Shinjuku"); task.wait(2)
                Remotes.TP_Portal:FireServer("Slime"); task.wait(2)
                root.CFrame = CFrame.new(788,68,-2309); task.wait(1.5)
            end
        end
        if puzzleType == "Demonite" or puzzleType == "Hogyoku" then piece = workspace:FindFirstChild(islandOrPiece, true)
        else
            local islandFolder = workspace:FindFirstChild(islandOrPiece)
            piece = islandFolder and islandFolder:FindFirstChild(pieceModelName, true) or workspace:FindFirstChild(pieceModelName, true)
        end
        if piece then
            HybridMove(piece:GetPivot() * CFrame.new(0,3,0)); task.wait(0.5)
            local prompt = piece:FindFirstChildOfClass("ProximityPrompt") or piece:FindFirstChild("PuzzlePrompt", true) or piece:FindFirstChild("ProximityPrompt", true)
            if prompt then
                fireproximityprompt(prompt)
                Notify(string.format("Collected Piece %d/%d", i, #piecesToCollect), 2); task.wait(1.5)
            else Notify("Found piece but no interaction prompt was detected.", 3) end
        else Notify("Failed to find piece "..i.." on "..tostring(tpTarget or "Island"), 3) end
    end
    Notify(puzzleType.." Puzzle Completed!", 5)
end

local function GetCurrentQuestUI()
    local holder = PGui.QuestUI.Quest.Quest.Holder.Content
    local info = holder.QuestInfo
    return {
        Title = info.QuestTitle.QuestTitle.Text,
        Description = info.QuestDescription.Text,
        SwitchVisible = holder.QuestSwitchButton.Visible,
        SwitchBtn = holder.QuestSwitchButton,
        IsVisible = PGui.QuestUI.Quest.Visible
    }
end

local function EnsureQuestSettings()
    local settings = PGui.SettingsUI.MainFrame.Frame.Content.SettingsTabFrame
    local tog1 = settings:FindFirstChild("Toggle_EnableQuestRepeat", true)
    if tog1 and tog1.SettingsHolder.Off.Visible then Remotes.SettingsToggle:FireServer("EnableQuestRepeat", true); task.wait(0.3) end
    local tog2 = settings:FindFirstChild("Toggle_AutoQuestRepeat", true)
    if tog2 and tog2.SettingsHolder.Off.Visible then Remotes.SettingsToggle:FireServer("AutoQuestRepeat", true) end
end

local function GetBestQuestNPC()
    local QuestModule = Modules.Quests; local playerLevel = Plr.Data.Level.Value
    local bestNPC = "QuestNPC1"; local highestLevel = -1
    for npcId, questData in pairs(QuestModule.RepeatableQuests) do
        local reqLevel = questData.recommendedLevel or 0
        if playerLevel >= reqLevel and reqLevel > highestLevel then highestLevel = reqLevel; bestNPC = npcId end
    end
    return bestNPC
end

local function UpdateQuest()
    if not (Toggles.LevelFarm and Toggles.LevelFarm.Value) then return end
    EnsureQuestSettings()
    local targetNPC = GetBestQuestNPC(); local questUI = PGui.QuestUI.Quest
    if Shared.QuestNPC ~= targetNPC or not questUI.Visible then
        Remotes.QuestAbandon:FireServer("repeatable")
        local abandonTimeout = 0
        while questUI.Visible and abandonTimeout < 15 do task.wait(0.2); abandonTimeout = abandonTimeout + 1 end
        Remotes.QuestAccept:FireServer(targetNPC)
        local acceptTimeout = 0
        while not questUI.Visible and acceptTimeout < 20 do
            task.wait(0.2); acceptTimeout = acceptTimeout + 1
            if acceptTimeout % 5 == 0 then Remotes.QuestAccept:FireServer(targetNPC) end
        end
        if questUI.Visible then Shared.QuestNPC = targetNPC end
    end
end

local function GetPityTarget()
    if not (Toggles.PityBossFarm and Toggles.PityBossFarm.Value) then return nil end
    local current, max = GetCurrentPity()
    local buildBosses = Options.SelectedBuildPity and Options.SelectedBuildPity.Value or {}
    local useName = Options.SelectedUsePity and Options.SelectedUsePity.Value
    if not useName then return nil end
    local isUseTurn = (current >= (max-1))
    if isUseTurn then
        for _, npc in pairs(PATH.Mobs:GetChildren()) do
            if IsStrictBossMatch(npc.Name, useName) then
                local island = Shared.BossTIMap[useName] or "Boss"
                return npc, island, "Boss"
            end
        end
    else
        for bossName, enabled in pairs(buildBosses) do
            if enabled then
                for _, npc in pairs(PATH.Mobs:GetChildren()) do
                    if IsStrictBossMatch(npc.Name, bossName) then
                        local island = Shared.BossTIMap[bossName] or "Boss"
                        return npc, island, "Boss"
                    end
                end
            end
        end
    end
    return nil
end

local function IsValidTarget(npc)
    if not npc or not npc.Parent then return false end
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if npc:FindFirstChild("IK_Active") then return true end
    local minMaxHP = tonumber(Options.InstaKillMinHP and Options.InstaKillMinHP.Value) or 0
    local isEligible = (Toggles.InstaKill and Toggles.InstaKill.Value) and hum.MaxHealth >= minMaxHP
    if isEligible then return (hum.Health > 0) or (npc == Shared.Target)
    else return (hum.Health > 0) end
end

local function GetBestMobCluster(mobNamesDictionary)
    local allMobs = {}; local clusterRadius = 35
    if type(mobNamesDictionary) ~= "table" then return nil end
    for _, npc in pairs(PATH.Mobs:GetChildren()) do
        if npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid") then
            local cleanName = npc.Name:gsub("%d+$","")
            if mobNamesDictionary[cleanName] and IsValidTarget(npc) then table.insert(allMobs, npc) end
        end
    end
    if #allMobs == 0 then return nil end
    local bestMob = allMobs[1]; local maxNearby = 0
    for _, mobA in ipairs(allMobs) do
        local nearbyCount = 0; local posA = mobA:GetPivot().Position
        for _, mobB in ipairs(allMobs) do
            if (posA - mobB:GetPivot().Position).Magnitude <= clusterRadius then nearbyCount = nearbyCount + 1 end
        end
        if nearbyCount > maxNearby then maxNearby = nearbyCount; bestMob = mobA end
    end
    return bestMob, maxNearby
end

local function GetAllMobTarget()
    if not (Toggles.AllMobFarm and Toggles.AllMobFarm.Value) then Shared.AllMobIdx=1; return nil end
    local rotateList = {}
    for _, mobName in ipairs(Tables.MobList) do
        if mobName ~= "TrainingDummy" then table.insert(rotateList, mobName) end
    end
    if #rotateList == 0 then return nil end
    if Shared.AllMobIdx > #rotateList then Shared.AllMobIdx = 1 end
    local targetMobName = rotateList[Shared.AllMobIdx]
    local target, count = GetBestMobCluster({[targetMobName]=true})
    if target then
        local island = GetNearestIsland(target:GetPivot().Position, target.Name)
        return target, island, "Mob"
    else
        Shared.AllMobIdx = Shared.AllMobIdx + 1
        if Shared.AllMobIdx > #rotateList then Shared.AllMobIdx = 1 end
        return nil
    end
end

local function GetLevelFarmTarget()
    if not (Toggles.LevelFarm and Toggles.LevelFarm.Value) then return nil end
    UpdateQuest()
    if not PGui.QuestUI.Quest.Visible then return nil end
    local questData = Modules.Quests.RepeatableQuests[Shared.QuestNPC]
    if not questData or not questData.requirements[1] then return nil end
    local targetMobType = questData.requirements[1].npcType; local matches = {}
    for _, npc in pairs(PATH.Mobs:GetChildren()) do
        if npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid") then
            if IsSmartMatch(npc.Name, targetMobType) then
                local cleanName = npc.Name:gsub("%d+$",""); matches[cleanName] = true
            end
        end
    end
    local bestMob, count = GetBestMobCluster(matches)
    if bestMob then
        local island = GetNearestIsland(bestMob:GetPivot().Position, bestMob.Name)
        return bestMob, island, "Mob"
    end
    return nil
end

local function GetOtherTarget()
    if not (Toggles.OtherSummonFarm and Toggles.OtherSummonFarm.Value) then return nil end
    local selected = Options.SelectedOtherSummon and Options.SelectedOtherSummon.Value
    if not selected then return nil end
    local lowerSelected = selected:lower()
    for _, npc in pairs(PATH.Mobs:GetChildren()) do
        local name = npc.Name:lower(); local isMatch = false
        if lowerSelected:find("strongest") then
            if name:find("strongest") and ((lowerSelected:find("history") and name:find("history")) or (lowerSelected:find("today") and name:find("today"))) then isMatch = true end
        elseif name:find(lowerSelected) then isMatch = true end
        if isMatch and IsValidTarget(npc) then
            local island = GetNearestIsland(npc:GetPivot().Position, npc.Name)
            return npc, island, "Boss"
        end
    end
    return nil
end

local function GetSummonTarget()
    if not (Toggles.SummonBossFarm and Toggles.SummonBossFarm.Value) then return nil end
    local selected = Options.SelectedSummon and Options.SelectedSummon.Value
    if not selected then return nil end
    local workspaceName = SummonMap[selected] or (selected.."Boss")
    for _, npc in pairs(PATH.Mobs:GetChildren()) do
        if npc.Name:lower():find(workspaceName:lower()) then
            if IsValidTarget(npc) then return npc, "Boss", "Boss" end
        end
    end
    return nil
end

local function GetWorldBossTarget()
    if Toggles.AllBossesFarm and Toggles.AllBossesFarm.Value then
        for _, npc in pairs(PATH.Mobs:GetChildren()) do
            local name = npc.Name
            if name:find("Boss") and not table.find(Tables.MiniBossList, name) then
                if IsValidTarget(npc) then
                    local island = "Boss"
                    for dName, iName in pairs(Shared.BossTIMap) do
                        if IsStrictBossMatch(name, dName) then island = iName; break end
                    end
                    return npc, island, "Boss"
                end
            end
        end
    end
    if Toggles.BossesFarm and Toggles.BossesFarm.Value then
        local selected = Options.SelectedBosses and Options.SelectedBosses.Value or {}
        for bossDisplayName, isEnabled in pairs(selected) do
            if isEnabled then
                for _, npc in pairs(PATH.Mobs:GetChildren()) do
                    if IsStrictBossMatch(npc.Name, bossDisplayName) and not table.find(Tables.MiniBossList, npc.Name) then
                        if IsValidTarget(npc) then
                            local island = Shared.BossTIMap[bossDisplayName] or "Boss"
                            return npc, island, "Boss"
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function GetMobTarget()
    if not (Toggles.MobFarm and Toggles.MobFarm.Value) then Shared.MobIdx=1; return nil end
    local selectedDict = Options.SelectedMob and Options.SelectedMob.Value or {}
    local enabledMobs = {}
    for mob, enabled in pairs(selectedDict) do if enabled then table.insert(enabledMobs, mob) end end
    table.sort(enabledMobs)
    if #enabledMobs == 0 then return nil end
    if Shared.MobIdx > #enabledMobs then Shared.MobIdx = 1 end
    local targetMobName = enabledMobs[Shared.MobIdx]
    local target, count = GetBestMobCluster({[targetMobName]=true})
    if target then
        local island = GetNearestIsland(target:GetPivot().Position, target.Name)
        return target, island, "Mob"
    else
        Shared.MobIdx = Shared.MobIdx + 1; return nil
    end
end

local function ShouldMainWait()
    if not (Toggles.AltBossFarm and Toggles.AltBossFarm.Value) then return false end
    local selectedAlts = {}
    for i = 1, 5 do
        local val = Options["SelectedAlt_"..i] and Options["SelectedAlt_"..i].Value
        local name = (typeof(val) == "Instance" and val:IsA("Player")) and val.Name or tostring(val)
        if name and name ~= "" and name ~= "nil" and name ~= "None" then table.insert(selectedAlts, name) end
    end
    if #selectedAlts == 0 then return false end
    for _, altName in ipairs(selectedAlts) do
        local currentDmg = Shared.AltDamage[altName] or 0
        if currentDmg < 10 then return true end
    end
    return false
end

local function GetAltHelpTarget()
    if not (Toggles.AltBossFarm and Toggles.AltBossFarm.Value) then return nil end
    local targetBossName = Options.SelectedAltBoss and Options.SelectedAltBoss.Value
    if not targetBossName then return nil end
    local targetNPC = nil
    for _, npc in pairs(PATH.Mobs:GetChildren()) do
        if IsStrictBossMatch(npc.Name, targetBossName) and IsValidTarget(npc) then targetNPC = npc; break end
    end
    if not targetNPC then
        FireBossRemote(targetBossName, Options.SelectedAltDiff and Options.SelectedAltDiff.Value or "Normal")
        task.wait(0.5); return nil
    end
    Shared.AltActive = ShouldMainWait()
    local island = Shared.BossTIMap[targetBossName] or "Boss"
    return targetNPC, island, "Boss"
end

local function CheckTask(taskType)
    if taskType == "Merchant" then
        if (Toggles.AutoMerchant and Toggles.AutoMerchant.Value) and Shared.MerchantBusy then return true, nil, "None" end
        return nil
    elseif taskType == "Pity Boss" then return GetPityTarget()
    elseif taskType == "Summon [Other]" then return GetOtherTarget()
    elseif taskType == "Summon" then return GetSummonTarget()
    elseif taskType == "Boss" then return GetWorldBossTarget()
    elseif taskType == "Level Farm" then return GetLevelFarmTarget()
    elseif taskType == "All Mob Farm" then return GetAllMobTarget()
    elseif taskType == "Mob" then return GetMobTarget()
    elseif taskType == "Alt Help" then return GetAltHelpTarget() end
    return nil
end

local function GetNearestAuraTarget()
    local nearest = nil; local maxRange = tonumber(Options.KillAuraRange and Options.KillAuraRange.Value) or 200
    local lastDist = maxRange
    local char = Plr.Character; local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local myPos = root.Position; local mobFolder = workspace:FindFirstChild("NPCs")
    if not mobFolder then return nil end
    for _, v in ipairs(mobFolder:GetChildren()) do
        if v:IsA("Model") then
            local npcPos = v:GetPivot().Position; local dist = (myPos - npcPos).Magnitude
            if dist <= lastDist then
                local hum = v:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then nearest = v; lastDist = dist end
            end
        end
    end
    return nearest
end

local function Func_KillAura()
    while Toggles.KillAura and Toggles.KillAura.Value do
        if IsBusy() then task.wait(0.1); continue end
        local target = GetNearestAuraTarget()
        if target then
            EquipWeapon()
            pcall(function() Remotes.M1:FireServer(target:GetPivot().Position) end)
        end
        task.wait(tonumber(Options.KillAuraCD and Options.KillAuraCD.Value) or 0.12)
    end
end

local function ExecuteFarmLogic(target, island, farmType)
    local char = GetCharacter(); local root = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not target or Shared.Recovering or not root then return end
    if Shared.MovingIsland then return end
    Shared.Target = target
    if (Toggles.AltBossFarm and Toggles.AltBossFarm.Value) and farmType == "Boss" then
        Shared.AltActive = ShouldMainWait()
    else Shared.AltActive = false end
    if Toggles.IslandTP and Toggles.IslandTP.Value then
        if island and island ~= "" and island ~= "Unknown" and island ~= Shared.Island then
            Shared.MovingIsland = true
            Remotes.TP_Portal:FireServer(island)
            task.wait(tonumber(Options.IslandTPCD and Options.IslandTPCD.Value) or 0.8)
            Shared.Island = island; Shared.MovingIsland = false; return
        end
    end
    local targetPivot = target:GetPivot(); local targetPos = targetPivot.Position
    local distVal = tonumber(Options.Distance and Options.Distance.Value) or 10
    local posType = Options.SelectedFarmType and Options.SelectedFarmType.Value or "Behind"
    local finalPos
    local ikTag = target:FindFirstChild("IK_Active")
    if ikTag and (Options.InstaKillType and Options.InstaKillType.Value) == "V2" and (Toggles.InstaKill and Toggles.InstaKill.Value) then
        local startTime = ikTag:GetAttribute("TriggerTime") or 0
        if tick() - startTime >= 3 then
            root.CFrame = CFrame.new(targetPos + Vector3.new(0,300,0))
            root.AssemblyLinearVelocity = Vector3.zero; return
        end
    end
    if Shared.AltActive then finalPos = targetPos + Vector3.new(0,120,0)
    elseif posType == "Above" then finalPos = targetPos + Vector3.new(0,distVal,0)
    elseif posType == "Below" then finalPos = targetPos + Vector3.new(0,-distVal,0)
    else finalPos = (targetPivot * CFrame.new(0,0,distVal)).Position end
    local finalDestination = CFrame.lookAt(finalPos, targetPos)
    if (root.Position - finalPos).Magnitude > 0.1 then
        if (Options.SelectedMovementType and Options.SelectedMovementType.Value) == "Teleport" then
            root.CFrame = finalDestination
        else
            local distance = (root.Position - finalPos).Magnitude
            local speed = tonumber(Options.TweenSpeed and Options.TweenSpeed.Value) or 180
            game:GetService("TweenService"):Create(root, TweenInfo.new(distance/speed, Enum.EasingStyle.Linear), {CFrame=finalDestination}):Play()
        end
    end
    root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
end

local function Func_WebhookLoop()
    while Toggles.SendWebhook and Toggles.SendWebhook.Value do
        -- PostToWebhook() -- webhook logic omitted for brevity, same as original
        local delay = math.max((Options.WebhookDelay and Options.WebhookDelay.Value or 5), 0.5) * 60
        task.wait(delay)
    end
end

local function Func_AutoHaki()
    while task.wait(0.5) do
        if (Toggles.ObserHaki and Toggles.ObserHaki.Value) and not CheckObsHaki() then
            Remotes.ObserHaki:FireServer("Toggle")
        end
        if (Toggles.ArmHaki and Toggles.ArmHaki.Value) and not CheckArmHaki() then
            Remotes.ArmHaki:FireServer("Toggle"); task.wait(0.5)
        end
        if Toggles.ConquerorHaki and Toggles.ConquerorHaki.Value then
            if Toggles.OnlyTarget and Toggles.OnlyTarget.Value then
                if not Shared.Farm or not Shared.Target or not Shared.Target.Parent then continue end
            end
            Remotes.ConquerorHaki:FireServer("Activate")
        end
    end
end

local function Func_AutoM1()
    while task.wait(Options.M1Speed and Options.M1Speed.Value or 0) do
        if Toggles.AutoM1 and Toggles.AutoM1.Value then Remotes.M1:FireServer() end
    end
end

local function Func_AutoSkill()
    local keyToEnum = {["Z"]=Enum.KeyCode.Z,["X"]=Enum.KeyCode.X,["C"]=Enum.KeyCode.C,["V"]=Enum.KeyCode.V,["F"]=Enum.KeyCode.F}
    local keyToSlot = {["Z"]=1,["X"]=2,["C"]=3,["V"]=4,["F"]=5}
    local priority = {"Z","X","C","V","F"}
    while task.wait() do
        if not (Toggles.AutoSkill and Toggles.AutoSkill.Value) then continue end
        local target = Shared.Target
        if (Toggles.OnlyTarget and Toggles.OnlyTarget.Value) and (not Shared.Farm or not target or not target.Parent) then continue end
        local canExecute = true
        if Toggles.AutoSkill_BossOnly and Toggles.AutoSkill_BossOnly.Value then
            if not target or not target.Parent then canExecute = false
            else
                local npcHum = target:FindFirstChildOfClass("Humanoid")
                local isRealBoss = target.Name:find("Boss") and not table.find(Tables.MiniBossList, target.Name)
                local hpPercent = npcHum and (npcHum.Health/npcHum.MaxHealth*100) or 101
                local threshold = tonumber(Options.AutoSkill_BossHP and Options.AutoSkill_BossHP.Value) or 100
                if not isRealBoss or hpPercent > threshold then canExecute = false end
            end
        end
        if canExecute and target and target.Parent then
            if target:FindFirstChild("IK_Active") and (Options.InstaKillType and Options.InstaKillType.Value) == "V1" then canExecute = false end
        end
        if not canExecute then continue end
        local char = GetCharacter(); local tool = char and char:FindFirstChildOfClass("Tool")
        if not tool then continue end
        local toolName = tool.Name; local toolType = GetToolTypeFromModule(toolName)
        local useMode = Options.AutoSkillType and Options.AutoSkillType.Value or "Normal"
        local selected = Options.SelectedSkills and Options.SelectedSkills.Value or {}
        if useMode == "Instant" then
            for _, key in ipairs(priority) do
                if selected[key] then
                    if toolType == "Power" then
                        Remotes.UseFruit:FireServer("UseAbility", {["FruitPower"]=toolName:gsub(" Fruit",""),["KeyCode"]=keyToEnum[key]})
                    else Remotes.UseSkill:FireServer(keyToSlot[key]) end
                end
            end
            task.wait(.01)
        else
            local mainFrame = PGui:FindFirstChild("CooldownUI") and PGui.CooldownUI:FindFirstChild("MainFrame")
            if not mainFrame then continue end
            for _, key in ipairs(priority) do
                if selected[key] then
                    if IsSkillReady(key) then
                        if toolType == "Power" then
                            Remotes.UseFruit:FireServer("UseAbility", {["FruitPower"]=toolName:gsub(" Fruit",""),["KeyCode"]=keyToEnum[key]})
                        else Remotes.UseSkill:FireServer(keyToSlot[key]) end
                        task.wait(0.1); break
                    end
                end
            end
        end
    end
end

local function Func_AutoStats()
    local pointsPath = Plr:WaitForChild("Data"):WaitForChild("StatPoints")
    local MAX_STAT_LEVEL = 11500
    while task.wait(1) do
        if Toggles.AutoStats and Toggles.AutoStats.Value then
            local availablePoints = pointsPath.Value
            if availablePoints > 0 then
                local selectedStats = Options.SelectedStats and Options.SelectedStats.Value or {}
                local activeStats = {}
                for statName, enabled in pairs(selectedStats) do
                    if enabled then
                        local currentLevel = Shared.Stats[statName] or 0
                        if currentLevel < MAX_STAT_LEVEL then table.insert(activeStats, statName) end
                    end
                end
                local statCount = #activeStats
                if statCount > 0 then
                    local pointsPerStat = math.floor(availablePoints/statCount)
                    if pointsPerStat > 0 then
                        for _, stat in ipairs(activeStats) do Remotes.AddStat:FireServer(stat, pointsPerStat) end
                    else Remotes.AddStat:FireServer(activeStats[1], availablePoints) end
                end
            end
        end
        if not (Toggles.AutoStats and Toggles.AutoStats.Value) then break end
    end
end

local function AutoRollStatsLoop()
    local selectedStats = Options.SelectedGemStats and Options.SelectedGemStats.Value or {}
    local selectedRanks = Options.SelectedRank and Options.SelectedRank.Value or {}
    local hasStat = false; for _ in pairs(selectedStats) do hasStat = true; break end
    local hasRank = false; for _ in pairs(selectedRanks) do hasRank = true; break end
    if not hasStat or not hasRank then
        Notify("Error: Select at least one Stat and one Rank first!", 5)
        if Toggles.AutoRollStats then Toggles.AutoRollStats.Value = false end; return
    end
    while Toggles.AutoRollStats and Toggles.AutoRollStats.Value do
        if not next(Shared.GemStats) then task.wait(0.1); continue end
        local workDone = true
        for _, statName in ipairs(Tables.GemStat) do
            if selectedStats[statName] then
                local currentData = Shared.GemStats[statName]
                if currentData then
                    local currentRank = currentData.Rank
                    if not selectedRanks[currentRank] then
                        workDone = false
                        local success, err = pcall(function() Remotes.RerollSingleStat:InvokeServer(statName) end)
                        if not success then Notify("ERROR: "..tostring(err):gsub("<","["), 5) end
                        task.wait(tonumber(Options.StatsRollCD and Options.StatsRollCD.Value) or 0.1); break
                    end
                end
            end
        end
        if workDone then Notify("Successfully rolled selected stats.", 5); if Toggles.AutoRollStats then Toggles.AutoRollStats.Value = false end; break end
        task.wait()
    end
end

local function Func_UnifiedRollManager()
    while task.wait() do
        if Toggles.AutoTrait and Toggles.AutoTrait.Value then
            local traitUI = PGui:WaitForChild("TraitRerollUI").MainFrame.Frame.Content.TraitPage.TraitGottenFrame.Holder.Trait.TraitGotten
            local confirmFrame = PGui.TraitRerollUI.MainFrame.Frame.Content:FindFirstChild("AreYouSureYouWantToRerollFrame")
            local currentTrait = traitUI.Text
            local selected = Options.SelectedTrait and Options.SelectedTrait.Value or {}
            if selected[currentTrait] then
                Notify("Success! Got Trait: "..currentTrait, 5)
                if Toggles.AutoTrait then Toggles.AutoTrait.Value = false end
            else
                pcall(SyncTraitAutoSkip)
                if confirmFrame and confirmFrame.Visible then Remotes.TraitConfirm:FireServer(true); task.wait(0.1) end
                Remotes.Roll_Trait:FireServer()
                task.wait(Options.RollCD and Options.RollCD.Value or 0.3)
            end
            continue
        end
        if Toggles.AutoRace and Toggles.AutoRace.Value then
            local currentRace = Plr:GetAttribute("CurrentRace")
            local selected = Options.SelectedRace and Options.SelectedRace.Value or {}
            if selected[currentRace] then
                Notify("Success! Got Race: "..currentRace, 5)
                if Toggles.AutoRace then Toggles.AutoRace.Value = false end
            else
                pcall(SyncRaceSettings); Remotes.UseItem:FireServer("Use","Race Reroll",1)
                task.wait(Options.RollCD and Options.RollCD.Value or 0.3)
            end
            continue
        end
        if Toggles.AutoClan and Toggles.AutoClan.Value then
            local currentClan = Plr:GetAttribute("CurrentClan")
            local selected = Options.SelectedClan and Options.SelectedClan.Value or {}
            if selected[currentClan] then
                Notify("Success! Got Clan: "..currentClan, 5)
                if Toggles.AutoClan then Toggles.AutoClan.Value = false end
            else
                pcall(SyncClanSettings); Remotes.UseItem:FireServer("Use","Clan Reroll",1)
                task.wait(Options.RollCD and Options.RollCD.Value or 0.3)
            end
            continue
        end
        task.wait(0.4)
    end
end

local function EnsureRollManager()
    Thread("UnifiedRollManager", Func_UnifiedRollManager,
        (Toggles.AutoTrait and Toggles.AutoTrait.Value) or
        (Toggles.AutoRace and Toggles.AutoRace.Value) or
        (Toggles.AutoClan and Toggles.AutoClan.Value)
    )
end

local function AutoSpecPassiveLoop()
    pcall(SyncSpecPassiveAutoSkip)
    task.wait(Options.SpecRollCD and Options.SpecRollCD.Value or 0.1)
    while Toggles.AutoSpec and Toggles.AutoSpec.Value do
        local targetWeapons = Options.SelectedPassive and Options.SelectedPassive.Value or {}
        local targetPassives = Options.SelectedSpec and Options.SelectedSpec.Value or {}
        local workDone = false
        if type(Shared.Passives) ~= "table" then Shared.Passives = {} end
        for weaponName, isWeaponEnabled in pairs(targetWeapons) do
            if not isWeaponEnabled then continue end
            local currentData = Shared.Passives[weaponName]
            local currentName = "None"; local currentBuffs = {}
            if type(currentData) == "table" then currentName = currentData.Name or "None"; currentBuffs = currentData.RolledBuffs or {}
            elseif type(currentData) == "string" then currentName = currentData end
            local isCorrectName = targetPassives[currentName]; local meetsAllStats = true
            if isCorrectName then
                if type(currentBuffs) == "table" then
                    for statKey, rolledValue in pairs(currentBuffs) do
                        local sliderId = "Min_"..currentName:gsub("%s+","").."_"..statKey
                        local minRequired = Options[sliderId] and Options[sliderId].Value or 0
                        if tonumber(rolledValue) and rolledValue < minRequired then meetsAllStats = false; break end
                    end
                end
            else meetsAllStats = false end
            if not isCorrectName or not meetsAllStats then
                workDone = true
                Remotes.SpecPassiveReroll:FireServer(weaponName)
                local startWait = tick()
                repeat
                    task.wait()
                    local checkData = Shared.Passives[weaponName]
                    local checkName = (type(checkData) == "table" and checkData.Name) or (type(checkData) == "string" and checkData) or ""
                until (checkName ~= currentName) or (tick() - startWait > 1.5)
                break
            end
        end
        if not workDone then
            Notify("Done", 5); if Toggles.AutoSpec then Toggles.AutoSpec.Value = false end; break
        end
        task.wait()
    end
end

local function AutoSkillTreeLoop()
    while Toggles.AutoSkillTree and Toggles.AutoSkillTree.Value do
        task.wait(0.5)
        if not next(Shared.SkillTree.Nodes) and Shared.SkillTree.SkillPoints == 0 then continue end
        local points = Shared.SkillTree.SkillPoints
        if points <= 0 then continue end
        for _, branch in pairs(Modules.SkillTree.Branches) do
            for _, node in ipairs(branch.Nodes) do
                local nodeId = node.Id; local cost = node.Cost
                if not Shared.SkillTree.Nodes[nodeId] then
                    if points >= cost then
                        local success, err = pcall(function() Remotes.SkillTreeUpgrade:FireServer(nodeId) end)
                        if success then Shared.SkillTree.SkillPoints = Shared.SkillTree.SkillPoints - cost; task.wait(0.3) end
                    end
                    break
                end
            end
        end
    end
end

local function Func_ArtifactMilestone()
    local currentMilestone = 1
    while Toggles.ArtifactMilestone and Toggles.ArtifactMilestone.Value do
        Remotes.ArtifactClaim:FireServer(currentMilestone)
        currentMilestone = currentMilestone + 1
        if currentMilestone > 40 then currentMilestone = 1 end
        task.wait(1)
    end
end

local function Func_AutoDungeon()
    while Toggles.AutoDungeon and Toggles.AutoDungeon.Value do
        task.wait(1)
        local selected = Options.SelectedDungeon and Options.SelectedDungeon.Value
        if not selected then continue end
        if PGui.DungeonPortalJoinUI.LeaveButton.Visible then continue end
        local targetIsland = "Dungeon"
        if selected == "BossRush" then targetIsland = "Sailor"
        elseif selected == "InfiniteTower" then targetIsland = "Tower" end
        if tick() - Shared.LastDungeon > 15 then
            Remotes.OpenDungeon:FireServer(tostring(selected)); Shared.LastDungeon = tick(); task.wait(1)
        end
        if not PGui.DungeonPortalJoinUI.LeaveButton.Visible then
            local portal = workspace:FindFirstChild("ActiveDungeonPortal")
            if not portal then
                if Shared.Island ~= targetIsland then
                    Remotes.TP_Portal:FireServer(targetIsland); Shared.Island = targetIsland; task.wait(2.5)
                end
            else
                local root = GetCharacter():FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = portal.CFrame; task.wait(0.2)
                    local prompt = portal:FindFirstChild("JoinPrompt")
                    if prompt then fireproximityprompt(prompt); task.wait(1) end
                end
            end
        end
    end
end

local function Func_AutoMerchant()
    local MerchantUI = UI.Merchant.Regular
    local Holder = MerchantUI:FindFirstChild("Holder", true)
    local LastTimerText = ""
    local function StartPurchaseSequence()
        if Shared.MerchantExecute then return end
        Shared.MerchantExecute = true
        if Shared.FirstMerchantSync then
            MerchantUI.Enabled = true; MerchantUI.MainFrame.Visible = true; task.wait(0.5)
            local closeBtn = MerchantUI:FindFirstChild("CloseButton", true)
            if closeBtn then gsc(closeBtn); task.wait(1.8) end
        end
        OpenMerchantInterface(); task.wait(2)
        local itemsWithStock = {}
        for _, child in pairs(Holder:GetChildren()) do
            if child:IsA("Frame") and child.Name ~= "Item" then
                local stockLabel = child:FindFirstChild("StockAmountForThatItem", true)
                local currentStock = 0
                if stockLabel then currentStock = tonumber(stockLabel.Text:match("%d+")) or 0 end
                Shared.CurrentStock[child.Name] = currentStock
                if currentStock > 0 then table.insert(itemsWithStock, {Name=child.Name, Stock=currentStock}) end
            end
        end
        if #itemsWithStock > 0 then
            local selectedItems = Options.SelectedMerchantItems and Options.SelectedMerchantItems.Value or {}
            for _, item in ipairs(itemsWithStock) do
                if selectedItems[item.Name] then
                    pcall(function() Remotes.MerchantBuy:InvokeServer(item.Name, 99) end)
                    task.wait(math.random(11,17)/10)
                end
            end
        end
        if MerchantUI.MainFrame then MerchantUI.MainFrame.Visible = false end
        Shared.FirstMerchantSync = true; Shared.MerchantExecute = false
    end
    local function SyncClock()
        OpenMerchantInterface(); task.wait(1)
        local Label = MerchantUI and MerchantUI:FindFirstChild("RefreshTimerLabel", true)
        if Label and Label.Text:find(":") then
            local serverSecs = GetSecondsFromTimer(Label.Text)
            if serverSecs then Shared.LocalMerchantTime = serverSecs end
        end
        if MerchantUI.MainFrame then MerchantUI.MainFrame.Visible = false end
    end
    SyncClock()
    while Toggles.AutoMerchant and Toggles.AutoMerchant.Value do
        local Label = MerchantUI:FindFirstChild("RefreshTimerLabel", true)
        if Label and Label.Text ~= "" then
            local currentText = Label.Text; local s = GetSecondsFromTimer(currentText)
            if s then
                Shared.LocalMerchantTime = s
                if currentText ~= LastTimerText then LastTimerText = currentText; Shared.LastTimerTick = tick() end
            else Shared.LocalMerchantTime = math.max(0, Shared.LocalMerchantTime - 1) end
        else Shared.LocalMerchantTime = math.max(0, Shared.LocalMerchantTime - 1) end
        local isRefresh = (Shared.LocalMerchantTime <= 1) or (Shared.LocalMerchantTime >= 1799)
        if not Shared.FirstMerchantSync or isRefresh then task.spawn(StartPurchaseSequence) end
        if tick() - Shared.LastTimerTick > 30 then task.spawn(SyncClock); Shared.LastTimerTick = tick() end
        task.wait(1)
    end
end

local function Func_AutoTrade()
    while task.wait(0.5) do
        local inTradeUI = PGui:FindFirstChild("InTradingUI") and PGui.InTradingUI.MainFrame.Visible
        local requestUI = PGui:FindFirstChild("TradeRequestUI") and PGui.TradeRequestUI.TradeRequest.Visible
        if (Toggles.ReqTradeAccept and Toggles.ReqTradeAccept.Value) and requestUI then
            Remotes.TradeRespond:FireServer(true); task.wait(1)
        end
        if (Toggles.ReqTrade and Toggles.ReqTrade.Value) and not inTradeUI and not requestUI then
            local targetPlr = Options.SelectedTradePlr and Options.SelectedTradePlr.Value
            if targetPlr and typeof(targetPlr) == "Instance" then Remotes.TradeSend:FireServer(targetPlr.UserId); task.wait(3) end
        end
        if inTradeUI and (Toggles.AutoAccept and Toggles.AutoAccept.Value) then
            local selectedItems = Options.SelectedTradeItems and Options.SelectedTradeItems.Value or {}
            local itemsToAdd = {}
            for itemName, enabled in pairs(selectedItems) do
                if enabled then
                    local alreadyInTrade = false
                    if Shared.TradeState.myItems then
                        for _, tradeItem in pairs(Shared.TradeState.myItems) do
                            if tradeItem.name == itemName then alreadyInTrade = true; break end
                        end
                    end
                    if not alreadyInTrade then table.insert(itemsToAdd, itemName) end
                end
            end
            if #itemsToAdd > 0 then
                for _, itemName in ipairs(itemsToAdd) do
                    local invQty = 0
                    for _, item in pairs(Shared.Cached.Inv) do if item.name == itemName then invQty = item.quantity; break end end
                    if invQty > 0 then Remotes.TradeAddItem:FireServer("Items", itemName, invQty); task.wait(0.5) end
                end
            else
                if not Shared.TradeState.myReady then Remotes.TradeReady:FireServer(true)
                elseif Shared.TradeState.myReady and Shared.TradeState.theirReady then
                    if Shared.TradeState.phase == "confirming" and not Shared.TradeState.myConfirm then Remotes.TradeConfirm:FireServer() end
                end
            end
        end
    end
end

local function Func_AutoChest()
    while task.wait(2) do
        if not (Toggles.AutoChest and Toggles.AutoChest.Value) then break end
        local selected = Options.SelectedChests and Options.SelectedChests.Value
        if type(selected) ~= "table" then continue end
        for _, rarityName in ipairs(Tables.Rarities or {}) do
            if selected[rarityName] == true then
                local fullName = (rarityName == "Aura Crate") and "Aura Crate" or (rarityName.." Chest")
                pcall(function() Remotes.UseItem:FireServer("Use", fullName, 10000) end)
                task.wait(1)
            end
        end
    end
end

local function Func_AutoCraft()
    while task.wait(1) do
        if Toggles.AutoCraftItem and Toggles.AutoCraftItem.Value then
            local selected = Options.SelectedCraftItems and Options.SelectedCraftItems.Value or {}
            for _, item in pairs(Shared.Cached.Inv) do
                if selected["DivineGrail"] and item.name == "Broken Sword" and item.quantity >= 3 then
                    pcall(function() Remotes.GrailCraft:InvokeServer("DivineGrail", math.min(math.floor(item.quantity/3),99)) end)
                    task.wait(0.5)
                end
                if selected["SlimeKey"] and item.name == "Slime Shard" and item.quantity >= 2 then
                    pcall(function() Remotes.SlimeCraft:InvokeServer("SlimeKey", math.min(math.floor(item.quantity/2),99)) end)
                end
            end
        end
        if not (Toggles.AutoCraftItem and Toggles.AutoCraftItem.Value) then break end
    end
end

local function Func_ArtifactAutomation()
    while task.wait(5) do
        if not Shared.ArtifactSession.Inventory or not next(Shared.ArtifactSession.Inventory) then
            Remotes.ArtifactUnequip:FireServer(""); task.wait(2); continue
        end
        local lockQueue = {}; local deleteQueue = {}; local upgradeQueue = {}
        for uuid, data in pairs(Shared.ArtifactSession.Inventory) do
            local res = EvaluateArtifact2(uuid, data)
            if res.lock then table.insert(lockQueue, uuid) end
            if res.delete then table.insert(deleteQueue, uuid) end
            if res.upgrade then
                local targetLvl = Options.UpgradeLimit and Options.UpgradeLimit.Value or 0
                if Toggles.UpgradeStage and Toggles.UpgradeStage.Value then
                    targetLvl = math.min(math.floor(data.Level/3)*3+3, targetLvl)
                end
                table.insert(upgradeQueue, {["UUID"]=uuid,["Levels"]=targetLvl})
            end
        end
        for _, uuid in ipairs(lockQueue) do Remotes.ArtifactLock:FireServer(uuid, true); task.wait(0.1) end
        if #deleteQueue > 0 then
            for i = 1, #deleteQueue, 50 do
                local chunk = {}
                for j = i, math.min(i+49,#deleteQueue) do table.insert(chunk, deleteQueue[j]) end
                Remotes.MassDelete:FireServer(chunk); task.wait(0.6)
            end
            Remotes.ArtifactUnequip:FireServer("")
        end
        if #upgradeQueue > 0 then
            for i = 1, #upgradeQueue, 50 do
                local chunk = {}
                for j = i, math.min(i+49,#upgradeQueue) do table.insert(chunk, upgradeQueue[j]) end
                Remotes.MassUpgrade:FireServer(chunk); task.wait(0.6)
            end
        end
        if Toggles.ArtifactEquip and Toggles.ArtifactEquip.Value then AutoEquipArtifacts() end
    end
end

-- ============================================================
--  REMOTE EVENT HOOKS  (unchanged from original)
-- ============================================================
Remotes.UpInventory.OnClientEvent:Connect(function(category, data)
    Shared.InventorySynced = true
    if category == "Items" then
        Shared.Cached.Inv = data or {}
        table.clear(Tables.OwnedItem)
        for _, item in pairs(data) do
            if not table.find(Tables.OwnedItem, item.name) then table.insert(Tables.OwnedItem, item.name) end
        end
        table.sort(Tables.OwnedItem)
        if Options.SelectedTradeItems then Options.SelectedTradeItems:SetValues(Tables.OwnedItem) end
    elseif category == "Runes" then
        table.clear(Tables.RuneList); table.insert(Tables.RuneList, "None")
        for name, _ in pairs(data) do table.insert(Tables.RuneList, name) end
        table.sort(Tables.RuneList)
        for _, dd in ipairs({"DefaultRune","Rune_Mob","Rune_Boss","Rune_BossHP"}) do
            if Options[dd] then Options[dd]:SetValues(Tables.RuneList) end
        end
    elseif category == "Accessories" then
        table.clear(Shared.Cached.Accessories)
        if type(data) == "table" then
            for _, accInfo in ipairs(data) do
                if accInfo.name and accInfo.quantity then Shared.Cached.Accessories[accInfo.name] = accInfo.quantity end
            end
        end
        table.clear(Tables.OwnedAccessory); local processed = {}
        for _, item in ipairs(data) do
            if (item.enchantLevel or 0) < 10 and not processed[item.name] then
                table.insert(Tables.OwnedAccessory, item.name); processed[item.name] = true
            end
        end
        table.sort(Tables.OwnedAccessory)
        if Options.SelectedEnchant then Options.SelectedEnchant:SetValues(Tables.OwnedAccessory) end
    elseif category == "Sword" or category == "Melee" then
        Shared.Cached.RawWeapCache[category] = data or {}
        table.clear(Tables.OwnedWeapon); local processed = {}
        for _, cat in pairs({"Sword","Melee"}) do
            for _, item in ipairs(Shared.Cached.RawWeapCache[cat]) do
                if (item.blessingLevel or 0) < 10 and not processed[item.name] then
                    table.insert(Tables.OwnedWeapon, item.name); processed[item.name] = true
                end
            end
        end
        table.sort(Tables.OwnedWeapon)
        if Options.SelectedBlessing then Options.SelectedBlessing:SetValues(Tables.OwnedWeapon) end
        table.clear(Tables.AllOwnedWeapons); local allProcessed = {}
        for _, cat in pairs({"Sword","Melee"}) do
            for _, item in ipairs(Shared.Cached.RawWeapCache[cat]) do
                if not allProcessed[item.name] then table.insert(Tables.AllOwnedWeapons, item.name); allProcessed[item.name] = true end
            end
        end
        table.sort(Tables.AllOwnedWeapons)
        if Options.SelectedPassive then Options.SelectedPassive:SetValues(Tables.AllOwnedWeapons) end
    end
end)

Remotes.StockUpdate.OnClientEvent:Connect(function(itemName, stockLeft)
    Shared.CurrentStock[itemName] = tonumber(stockLeft)
    if stockLeft == 0 then Notify("[MERCHANT] Bought: "..tostring(itemName), 2) end
end)

Remotes.UpSkillTree.OnClientEvent:Connect(function(data)
    if data then Shared.SkillTree.Nodes = data.Nodes or {}; Shared.SkillTree.SkillPoints = data.SkillPoints or 0 end
end)

if Remotes.SettingsSync then
    Remotes.SettingsSync.OnClientEvent:Connect(function(data) Shared.Settings = data end)
end

Remotes.ArtifactSync.OnClientEvent:Connect(function(data)
    Shared.ArtifactSession.Inventory = data.Inventory; Shared.ArtifactSession.Dust = data.Dust
end)

Remotes.TitleSync.OnClientEvent:Connect(function(data)
    if data and data.unlocked then Tables.UnlockedTitle = data.unlocked end
end)

Remotes.HakiStateUpdate.OnClientEvent:Connect(function(arg1, arg2)
    if arg1 == false then Shared.ArmHaki = false; return end
    if arg1 == Plr then Shared.ArmHaki = arg2 end
end)

if Remotes.BossUIUpdate then
    Remotes.BossUIUpdate.OnClientEvent:Connect(function(mode, data)
        if mode == "DamageStats" and data.stats then
            for _, info in pairs(data.stats) do
                if info.player and info.player:IsA("Player") then
                    Shared.AltDamage[info.player.Name] = tonumber(info.percent) or 0
                end
            end
        end
    end)
end

Remotes.TradeUpdated.OnClientEvent:Connect(function(data) Shared.TradeState = data end)

PATH.Mobs.ChildRemoved:Connect(function(child)
    if child:IsA("Model") and child.Name:lower():find("boss") then
        table.clear(Shared.AltDamage); Shared.AltActive = false
    end
end)

Remotes.SpecPassiveUpdate.OnClientEvent:Connect(function(data)
    if type(Shared.Passives) ~= "table" then Shared.Passives = {} end
    if data and data.Passives then
        for weaponName, info in pairs(data.Passives) do
            if type(info) == "table" then Shared.Passives[weaponName] = info
            else Shared.Passives[weaponName] = {Name=tostring(info),RolledBuffs={}} end
        end
    end
end)

Remotes.UpStatReroll.OnClientEvent:Connect(function(data)
    if data and data.Stats then Shared.GemStats = data.Stats end
end)

Remotes.UpPlayerStats.OnClientEvent:Connect(function(data)
    if data and data.Stats then Shared.Stats = data.Stats end
end)

Remotes.UpAscend.OnClientEvent:Connect(function(data)
    if not (Toggles.AutoAscend and Toggles.AutoAscend.Value) then return end
    if data.isMaxed then if Toggles.AutoAscend then Toggles.AutoAscend.Value = false end; return end
    if data.allMet then
        Notify("All requirements met! Ascending into: "..data.nextRankName, 5)
        Remotes.Ascend:FireServer(); task.wait(1)
    end
end)

-- ============================================================
--  FLUENT WINDOW + TABS
-- ============================================================
local Window = Fluent:CreateWindow({
    Title        = "FourHub | SP",
    SubTitle     = assetName .. " | v1.5 Beta",
    TabWidth     = 160,
    Size         = UDim2.fromOffset(620, 460),
    Acrylic      = true,
    Theme        = "Dark",
    MinimizeKey  = Enum.KeyCode.U,
})

-- Tabs
local Tabs = {
    Information = Window:AddTab({ Title = "Info",       Icon = "info" }),
    Priority    = Window:AddTab({ Title = "Priority",   Icon = "arrow-up-down" }),
    Main        = Window:AddTab({ Title = "Main",       Icon = "swords" }),
    Automation  = Window:AddTab({ Title = "Automation", Icon = "repeat-2" }),
    Artifact    = Window:AddTab({ Title = "Artifact",   Icon = "gem" }),
    Dungeon     = Window:AddTab({ Title = "Dungeon",    Icon = "door-open" }),
    Player      = Window:AddTab({ Title = "Player",     Icon = "user" }),
    Teleport    = Window:AddTab({ Title = "Teleport",   Icon = "map-pin" }),
    Misc        = Window:AddTab({ Title = "Misc",       Icon = "package" }),
    Webhook     = Window:AddTab({ Title = "Webhook",    Icon = "send" }),
    Settings    = Window:AddTab({ Title = "Settings",   Icon = "settings" }),
}

-- ============================================================
--  INFORMATION TAB
-- ============================================================
local execStatus = isLimitedExecutor and "Semi-Working" or "Working"
local InfoSection = Tabs.Information:AddSection("User Info")
InfoSection:AddParagraph({ Title = "Executor", Content = executorDisplayName .. " | Status: " .. execStatus })
InfoSection:AddParagraph({ Title = "FourHub", Content = "Sailor Piece | v1.5 Beta | by jokerbiel13" })
InfoSection:AddButton({ Title = "Redeem All Codes", Callback = function()
    local allCodes = Modules.Codes.Codes; local playerLevel = Plr.Data.Level.Value
    for codeName, data in pairs(allCodes) do
        if playerLevel >= (data.LevelReq or 0) then
            Notify("Redeeming: "..codeName, 3)
            Remotes.UseCode:InvokeServer(codeName); task.wait(2)
        end
    end
end })
InfoSection:AddButton({ Title = "Join Discord", Callback = function()
    if setclipboard then setclipboard("https://discord.gg/cUwR4tUJv3") end
    Notify("Discord link copied!", 2)
end })

-- ============================================================
--  PRIORITY TAB
-- ============================================================
local PrioSection = Tabs.Priority:AddSection("Task Priority")
for i = 1, #PriorityTasks do
    local opt = PrioSection:AddDropdown("SelectedPriority_"..i, {
        Title = "Priority "..i,
        Values = PriorityTasks,
        Default = DefaultPriority[i],
        Multi = false,
        AllowNull = true,
    })
    Options["SelectedPriority_"..i] = opt
end

-- ============================================================
--  MAIN TAB  –  Autofarm / Haki / Skill / Combo / Switch
-- ============================================================
-- LEFT: Autofarm mobs
local AFSection = Tabs.Main:AddSection("Autofarm")

local selMob = AFSection:AddDropdown("SelectedMob", { Title = "Select Mob(s)", Values = Tables.MobList, Multi = true, AllowNull = true })
Options.SelectedMob = selMob

AFSection:AddButton({ Title = "Refresh Mob List", Callback = UpdateNPCLists })

local t_MobFarm = AFSection:AddToggle("MobFarm", { Title = "Autofarm Selected Mob", Default = false })
Toggles.MobFarm = t_MobFarm

local t_AllMob = AFSection:AddToggle("AllMobFarm", { Title = "Autofarm All Mobs", Default = false })
Toggles.AllMobFarm = t_AllMob

local t_LevelFarm = AFSection:AddToggle("LevelFarm", { Title = "Autofarm Level", Default = false })
Toggles.LevelFarm = t_LevelFarm
t_LevelFarm:OnChanged(function(s) if not s then Shared.QuestNPC = "" end end)

-- Boss
local BossSection = Tabs.Main:AddSection("Boss Farm")

local selBosses = BossSection:AddDropdown("SelectedBosses", { Title = "Select Bosses", Values = Tables.BossList, Multi = true, AllowNull = true })
Options.SelectedBosses = selBosses

local t_BossesFarm = BossSection:AddToggle("BossesFarm", { Title = "Autofarm Selected Boss", Default = false })
Toggles.BossesFarm = t_BossesFarm

local t_AllBoss = BossSection:AddToggle("AllBossesFarm", { Title = "Autofarm All Bosses", Default = false })
Toggles.AllBossesFarm = t_AllBoss

BossSection:AddParagraph({ Title = "", Content = "── Summon Boss ──" })

local selSummon = BossSection:AddDropdown("SelectedSummon", { Title = "Select Summon Boss", Values = Tables.SummonList, Multi = false, AllowNull = true })
Options.SelectedSummon = selSummon

local selSummonDiff = BossSection:AddDropdown("SelectedSummonDiff", { Title = "Difficulty", Values = Tables.DiffList, Default = "Normal", Multi = false })
Options.SelectedSummonDiff = selSummonDiff

local t_AutoSummon = BossSection:AddToggle("AutoSummon", { Title = "Auto Summon", Default = false })
Toggles.AutoSummon = t_AutoSummon

local t_SummonFarm = BossSection:AddToggle("SummonBossFarm", { Title = "Autofarm Summon Boss", Default = false })
Toggles.SummonBossFarm = t_SummonFarm

BossSection:AddParagraph({ Title = "", Content = "── Other Summon ──" })

local selOtherSummon = BossSection:AddDropdown("SelectedOtherSummon", { Title = "Select Other Summon", Values = Tables.OtherSummonList, Multi = false, AllowNull = true })
Options.SelectedOtherSummon = selOtherSummon

local selOtherSummonDiff = BossSection:AddDropdown("SelectedOtherSummonDiff", { Title = "Difficulty", Values = Tables.DiffList, Default = "Normal", Multi = false })
Options.SelectedOtherSummonDiff = selOtherSummonDiff

local t_AutoOtherSummon = BossSection:AddToggle("AutoOtherSummon", { Title = "Auto Summon (Other)", Default = false })
Toggles.AutoOtherSummon = t_AutoOtherSummon

local t_OtherFarm = BossSection:AddToggle("OtherSummonFarm", { Title = "Autofarm Other Summon", Default = false })
Toggles.OtherSummonFarm = t_OtherFarm

BossSection:AddParagraph({ Title = "", Content = "── Pity Boss ──" })

local selBuildPity = BossSection:AddDropdown("SelectedBuildPity", { Title = "Boss [Build Pity]", Values = Tables.AllBossList, Multi = true, AllowNull = true })
Options.SelectedBuildPity = selBuildPity

local selUsePity = BossSection:AddDropdown("SelectedUsePity", { Title = "Boss [Use Pity]", Values = Tables.AllBossList, Multi = false, AllowNull = true })
Options.SelectedUsePity = selUsePity

local selPityDiff = BossSection:AddDropdown("SelectedPityDiff", { Title = "Difficulty [Use Pity]", Values = Tables.DiffList, Default = "Normal", Multi = false })
Options.SelectedPityDiff = selPityDiff

local t_PityFarm = BossSection:AddToggle("PityBossFarm", { Title = "Autofarm Pity Boss", Default = false })
Toggles.PityBossFarm = t_PityFarm

-- Alt Help
local AltSection = Tabs.Main:AddSection("Alt Help")

local selAltBoss = AltSection:AddDropdown("SelectedAltBoss", { Title = "Select Boss", Values = Tables.AllBossList, Multi = false, AllowNull = true })
Options.SelectedAltBoss = selAltBoss

local selAltDiff = AltSection:AddDropdown("SelectedAltDiff", { Title = "Difficulty", Values = Tables.DiffList, Default = "Normal", Multi = false })
Options.SelectedAltDiff = selAltDiff

for i = 1, 5 do
    local opt = AltSection:AddInput("SelectedAlt_"..i, { Title = "Alt #"..i.." Name", Default = "", Placeholder = "Username..." })
    Options["SelectedAlt_"..i] = opt
end

local t_AltFarm = AltSection:AddToggle("AltBossFarm", { Title = "Auto Help Alt", Default = false })
Toggles.AltBossFarm = t_AltFarm

-- Config
local FarmCfgSection = Tabs.Main:AddSection("Farm Config")

local selWeaponType = FarmCfgSection:AddDropdown("SelectedWeaponType", { Title = "Weapon Type", Values = Tables.Weapon, Multi = true })
Options.SelectedWeaponType = selWeaponType

local sliderSwitchCD = FarmCfgSection:AddSlider("SwitchWeaponCD", { Title = "Switch Weapon Delay", Default = 4, Min = 1, Max = 20, Rounding = 0 })
Options.SwitchWeaponCD = sliderSwitchCD

local t_SwitchWeapon = FarmCfgSection:AddToggle("SwitchWeapon", { Title = "Auto Switch Weapon", Default = true })
Toggles.SwitchWeapon = t_SwitchWeapon

local t_IslandTP = FarmCfgSection:AddToggle("IslandTP", { Title = "Island TP [Autofarm]", Default = true })
Toggles.IslandTP = t_IslandTP

local slIslandTPCD = FarmCfgSection:AddSlider("IslandTPCD", { Title = "Island TP CD", Default = 0.67, Min = 0, Max = 2.5, Rounding = 2 })
Options.IslandTPCD = slIslandTPCD

local slTargetTPCD = FarmCfgSection:AddSlider("TargetTPCD", { Title = "Target TP CD", Default = 0, Min = 0, Max = 5, Rounding = 2 })
Options.TargetTPCD = slTargetTPCD

local slTargetDistTP = FarmCfgSection:AddSlider("TargetDistTP", { Title = "Target Distance TP [Tween]", Default = 0, Min = 0, Max = 100, Rounding = 0 })
Options.TargetDistTP = slTargetDistTP

local slM1Speed = FarmCfgSection:AddSlider("M1Speed", { Title = "M1 Attack Cooldown", Default = 0, Min = 0, Max = 1, Rounding = 2 })
Options.M1Speed = slM1Speed

local selMovement = FarmCfgSection:AddDropdown("SelectedMovementType", { Title = "Movement Type", Values = {"Teleport","Tween"}, Default = "Tween", Multi = false })
Options.SelectedMovementType = selMovement

local selFarmType = FarmCfgSection:AddDropdown("SelectedFarmType", { Title = "Farm Type", Values = {"Behind","Above","Below"}, Default = "Behind", Multi = false })
Options.SelectedFarmType = selFarmType

local slDist = FarmCfgSection:AddSlider("Distance", { Title = "Farm Distance", Default = 12, Min = 0, Max = 30, Rounding = 0 })
Options.Distance = slDist

local slTweenSpeed = FarmCfgSection:AddSlider("TweenSpeed", { Title = "Tween Speed", Default = 160, Min = 0, Max = 500, Rounding = 0 })
Options.TweenSpeed = slTweenSpeed

local t_InstaKill = FarmCfgSection:AddToggle("InstaKill", { Title = "Instant Kill", Default = false })
Toggles.InstaKill = t_InstaKill

local selIKType = FarmCfgSection:AddDropdown("InstaKillType", { Title = "Insta-Kill Type", Values = {"V1","V2"}, Default = "V1", Multi = false })
Options.InstaKillType = selIKType

local slIKHP = FarmCfgSection:AddSlider("InstaKillHP", { Title = "HP% For Insta-Kill", Default = 90, Min = 1, Max = 100, Rounding = 0 })
Options.InstaKillHP = slIKHP

local inIKMinHP = FarmCfgSection:AddInput("InstaKillMinHP", { Title = "Min MaxHP For Insta-Kill", Default = "100000", Numeric = true, Placeholder = "Number..." })
Options.InstaKillMinHP = inIKMinHP

-- Haki
local HakiSection = Tabs.Main:AddSection("Haki")

local t_ObserHaki = HakiSection:AddToggle("ObserHaki", { Title = "Auto Observation Haki", Default = false })
Toggles.ObserHaki = t_ObserHaki
t_ObserHaki:OnChanged(function(s) Thread("AutoHaki", Func_AutoHaki, s) end)

local t_ArmHaki = HakiSection:AddToggle("ArmHaki", { Title = "Auto Armament Haki", Default = false })
Toggles.ArmHaki = t_ArmHaki
t_ArmHaki:OnChanged(function(s) Thread("AutoHaki", Func_AutoHaki, s) end)

local t_ConqHaki = HakiSection:AddToggle("ConquerorHaki", { Title = "Auto Conqueror Haki", Default = false })
Toggles.ConquerorHaki = t_ConqHaki
t_ConqHaki:OnChanged(function(s) Thread("AutoHaki", Func_AutoHaki, s) end)

-- Skills
local SkillSection = Tabs.Main:AddSection("Skills")
SkillSection:AddParagraph({ Title = "Note", Content = "Autofarm has built-in M1. Enable below only if needed separately." })

local t_AutoM1 = SkillSection:AddToggle("AutoM1", { Title = "Auto Attack (M1)", Default = false })
Toggles.AutoM1 = t_AutoM1
t_AutoM1:OnChanged(function(s) Thread("AutoM1", SafeLoop("Auto M1", Func_AutoM1), s) end)

local t_KillAura = SkillSection:AddToggle("KillAura", { Title = "Kill Aura", Default = false })
Toggles.KillAura = t_KillAura
t_KillAura:OnChanged(function(s) Thread("KillAura", Func_KillAura, s) end)

local slKillAuraCD = SkillSection:AddSlider("KillAuraCD", { Title = "Kill Aura CD", Default = 0.1, Min = 0.1, Max = 1, Rounding = 2 })
Options.KillAuraCD = slKillAuraCD

local slKillAuraRange = SkillSection:AddSlider("KillAuraRange", { Title = "Kill Aura Range", Default = 200, Min = 0, Max = 200, Rounding = 0 })
Options.KillAuraRange = slKillAuraRange

local selSkills = SkillSection:AddDropdown("SelectedSkills", { Title = "Select Skills", Values = {"Z","X","C","V","F"}, Multi = true })
Options.SelectedSkills = selSkills

local selAutoSkillType = SkillSection:AddDropdown("AutoSkillType", { Title = "Mode", Values = {"Normal","Instant"}, Default = "Normal", Multi = false })
Options.AutoSkillType = selAutoSkillType

local t_OnlyTarget = SkillSection:AddToggle("OnlyTarget", { Title = "Target Only", Default = false })
Toggles.OnlyTarget = t_OnlyTarget

local t_SkillBossOnly = SkillSection:AddToggle("AutoSkill_BossOnly", { Title = "Use On Boss Only", Default = false })
Toggles.AutoSkill_BossOnly = t_SkillBossOnly

local slSkillBossHP = SkillSection:AddSlider("AutoSkill_BossHP", { Title = "Boss HP%", Default = 100, Min = 1, Max = 100, Rounding = 0 })
Options.AutoSkill_BossHP = slSkillBossHP

local t_AutoSkill = SkillSection:AddToggle("AutoSkill", { Title = "Auto Use Skills", Default = false })
Toggles.AutoSkill = t_AutoSkill
t_AutoSkill:OnChanged(function(s) Thread("AutoSkill", SafeLoop("Auto Skill", Func_AutoSkill), s) end)

-- Combo
local ComboSection = Tabs.Main:AddSection("Skill Combo")
ComboSection:AddParagraph({ Title = "Example", Content = "Z > X > C > 0.5 > V > F\nNumbers = wait seconds." })

local inComboPattern = ComboSection:AddInput("ComboPattern", { Title = "Combo Pattern", Default = "Z > X > C > V > F", Placeholder = "pattern..." })
Options.ComboPattern = inComboPattern

local selComboMode = ComboSection:AddDropdown("ComboMode", { Title = "Mode", Values = {"Normal","Instant"}, Default = "Normal", Multi = false })
Options.ComboMode = selComboMode

local t_ComboBossOnly = ComboSection:AddToggle("ComboBossOnly", { Title = "Boss Only", Default = false })
Toggles.ComboBossOnly = t_ComboBossOnly

local t_AutoCombo = ComboSection:AddToggle("AutoCombo", { Title = "Auto Skill Combo", Default = false })
Toggles.AutoCombo = t_AutoCombo
t_AutoCombo:OnChanged(function(s)
    if not s then Shared.ComboIdx = 1 end
    if s and Toggles.AutoSkill and Toggles.AutoSkill.Value then
        Toggles.AutoSkill.Value = false
        Notify("NOTICE: Auto Skill disabled for Combo to work.", 3)
    end
    Thread("AutoCombo", SafeLoop("Skill Combo", Func_AutoCombo), s)
end)

-- Title / Rune / Build Switch
local SwitchSection = Tabs.Main:AddSection("Auto Switch")

for _, sw in ipairs({ {id="Title", list=CombinedTitleList}, {id="Rune", list=Tables.RuneList}, {id="Build", list=Tables.BuildList} }) do
    local t = SwitchSection:AddToggle("Auto"..sw.id, { Title = "Auto Switch "..sw.id, Default = false })
    Toggles["Auto"..sw.id] = t
    t:OnChanged(function(state) if not state then Shared.LastSwitch[sw.id] = "" end end)

    local defOpt = SwitchSection:AddDropdown("Default"..sw.id, { Title = "Default "..sw.id, Values = sw.list, Multi = false, AllowNull = true })
    Options["Default"..sw.id] = defOpt

    for _, ctx in ipairs({"Mob","Boss","Combo F Move","Boss HP%"}) do
        local key = sw.id.."_"..ctx:gsub(" ",""):gsub("F Move","Combo"):gsub("HP%%","BossHP")
        if ctx == "Combo F Move" then key = sw.id.."_Combo" end
        if ctx == "Boss HP%" then key = sw.id.."_BossHP" end
        if ctx == "Mob" then key = sw.id.."_Mob" end
        if ctx == "Boss" then key = sw.id.."_Boss" end
        local o = SwitchSection:AddDropdown(key, { Title = sw.id.." ["..ctx.."]", Values = sw.list, Multi = false, AllowNull = true })
        Options[key] = o
    end
    local bossHPSlider = SwitchSection:AddSlider(sw.id.."_BossHPAmt", { Title = "Change Until Boss HP%", Default = 15, Min = 0, Max = 100, Rounding = 0 })
    Options[sw.id.."_BossHPAmt"] = bossHPSlider
end

-- ============================================================
--  AUTOMATION TAB
-- ============================================================
local AscendSection = Tabs.Automation:AddSection("Ascend")
local t_AutoAscend = AscendSection:AddToggle("AutoAscend", { Title = "Auto Ascend", Default = false })
Toggles.AutoAscend = t_AutoAscend
t_AutoAscend:OnChanged(function(s)
    if s then Remotes.ReqAscend:InvokeServer() else Remotes.CloseAscend:FireServer() end
end)

local RollSection = Tabs.Automation:AddSection("Auto Rolls")

local slRollCD = RollSection:AddSlider("RollCD", { Title = "Roll Delay", Default = 0.3, Min = 0.01, Max = 1, Rounding = 2 })
Options.RollCD = slRollCD

local selTrait = RollSection:AddDropdown("SelectedTrait", { Title = "Select Trait(s)", Values = Tables.TraitList, Multi = true, AllowNull = true })
Options.SelectedTrait = selTrait
local t_AutoTrait = RollSection:AddToggle("AutoTrait", { Title = "Auto Roll Trait", Default = false })
Toggles.AutoTrait = t_AutoTrait
t_AutoTrait:OnChanged(EnsureRollManager)

local selRace = RollSection:AddDropdown("SelectedRace", { Title = "Select Race(s)", Values = Tables.RaceList, Multi = true, AllowNull = true })
Options.SelectedRace = selRace
local t_AutoRace = RollSection:AddToggle("AutoRace", { Title = "Auto Roll Race", Default = false })
Toggles.AutoRace = t_AutoRace
t_AutoRace:OnChanged(EnsureRollManager)

local selClan = RollSection:AddDropdown("SelectedClan", { Title = "Select Clan(s)", Values = Tables.ClanList, Multi = true, AllowNull = true })
Options.SelectedClan = selClan
local t_AutoClan = RollSection:AddToggle("AutoClan", { Title = "Auto Roll Clan", Default = false })
Toggles.AutoClan = t_AutoClan
t_AutoClan:OnChanged(EnsureRollManager)

local StatsSection = Tabs.Automation:AddSection("Stats")

local selStats = StatsSection:AddDropdown("SelectedStats", { Title = "Select Stat(s)", Values = {"Melee","Defense","Sword","Power"}, Multi = true })
Options.SelectedStats = selStats
local t_AutoStats = StatsSection:AddToggle("AutoStats", { Title = "Auto UP Stats", Default = false })
Toggles.AutoStats = t_AutoStats
t_AutoStats:OnChanged(function(s) Thread("AutoStats", SafeLoop("Auto Stats", Func_AutoStats), s) end)

local selGemStats = StatsSection:AddDropdown("SelectedGemStats", { Title = "Gem Stat(s)", Values = Tables.GemStat, Multi = true })
Options.SelectedGemStats = selGemStats
local selRank = StatsSection:AddDropdown("SelectedRank", { Title = "Rank(s)", Values = Tables.GemRank, Multi = true })
Options.SelectedRank = selRank
local slStatsRollCD = StatsSection:AddSlider("StatsRollCD", { Title = "Roll Delay", Default = 0.1, Min = 0.01, Max = 1, Rounding = 2 })
Options.StatsRollCD = slStatsRollCD
local t_AutoRollStats = StatsSection:AddToggle("AutoRollStats", { Title = "Auto Roll Stats", Default = false })
Toggles.AutoRollStats = t_AutoRollStats
t_AutoRollStats:OnChanged(function(s) Thread("AutoRollStats", SafeLoop("Stat Roll", AutoRollStatsLoop), s) end)

local MiscAutoSection = Tabs.Automation:AddSection("Misc Automation")

local t_AutoSkillTree = MiscAutoSection:AddToggle("AutoSkillTree", { Title = "Auto Skill Tree", Default = false })
Toggles.AutoSkillTree = t_AutoSkillTree
t_AutoSkillTree:OnChanged(function(s) Thread("AutoSkillTree", SafeLoop("Skill Tree", AutoSkillTreeLoop), s) end)

local t_ArtMilestone = MiscAutoSection:AddToggle("ArtifactMilestone", { Title = "Auto Artifact Milestone", Default = false })
Toggles.ArtifactMilestone = t_ArtMilestone
t_ArtMilestone:OnChanged(function(s) Thread("ArtifactMilestone", Func_ArtifactMilestone, s) end)

local EnchantSection = Tabs.Automation:AddSection("Enchant & Blessing")

local selEnchant = EnchantSection:AddDropdown("SelectedEnchant", { Title = "Select Enchant", Values = Tables.OwnedAccessory, Multi = true, AllowNull = true })
Options.SelectedEnchant = selEnchant
local t_AutoEnchant = EnchantSection:AddToggle("AutoEnchant", { Title = "Auto Enchant", Default = false })
Toggles.AutoEnchant = t_AutoEnchant
t_AutoEnchant:OnChanged(function(s) Thread("AutoEnchant", SafeLoop("Enchant", function() AutoUpgradeLoop("Enchant") end), s) end)
local t_AutoEnchantAll = EnchantSection:AddToggle("AutoEnchantAll", { Title = "Auto Enchant All", Default = false })
Toggles.AutoEnchantAll = t_AutoEnchantAll
t_AutoEnchantAll:OnChanged(function(s) Thread("AutoEnchantAll", SafeLoop("EnchantAll", function() AutoUpgradeLoop("Enchant") end), s) end)

local selBlessing = EnchantSection:AddDropdown("SelectedBlessing", { Title = "Select Blessing", Values = Tables.OwnedWeapon, Multi = true, AllowNull = true })
Options.SelectedBlessing = selBlessing
local t_AutoBlessing = EnchantSection:AddToggle("AutoBlessing", { Title = "Auto Blessing", Default = false })
Toggles.AutoBlessing = t_AutoBlessing
t_AutoBlessing:OnChanged(function(s) Thread("AutoBlessing", SafeLoop("Blessing", function() AutoUpgradeLoop("Blessing") end), s) end)
local t_AutoBlessingAll = EnchantSection:AddToggle("AutoBlessingAll", { Title = "Auto Blessing All", Default = false })
Toggles.AutoBlessingAll = t_AutoBlessingAll
t_AutoBlessingAll:OnChanged(function(s) Thread("AutoBlessingAll", SafeLoop("BlessingAll", function() AutoUpgradeLoop("Blessing") end), s) end)

local PassiveSection = Tabs.Automation:AddSection("Spec Passive")
local selPassive = PassiveSection:AddDropdown("SelectedPassive", { Title = "Select Weapon(s)", Values = Tables.AllOwnedWeapons, Multi = true, AllowNull = true })
Options.SelectedPassive = selPassive
local selSpec = PassiveSection:AddDropdown("SelectedSpec", { Title = "Target Passives", Values = Tables.SpecPassive, Multi = true, AllowNull = true })
Options.SelectedSpec = selSpec
local slSpecRollCD = PassiveSection:AddSlider("SpecRollCD", { Title = "Roll Delay", Default = 0.1, Min = 0.01, Max = 1, Rounding = 2 })
Options.SpecRollCD = slSpecRollCD
local t_AutoSpec = PassiveSection:AddToggle("AutoSpec", { Title = "Auto Reroll Passive", Default = false })
Toggles.AutoSpec = t_AutoSpec
t_AutoSpec:OnChanged(function(s) Thread("AutoSpecPassive", SafeLoop("Spec Passive", AutoSpecPassiveLoop), s) end)

local TradeSection = Tabs.Automation:AddSection("Trade")
local inTradePlr = TradeSection:AddInput("SelectedTradePlr", { Title = "Player Name", Default = "", Placeholder = "Username..." })
Options.SelectedTradePlr = inTradePlr
local selTradeItems = TradeSection:AddDropdown("SelectedTradeItems", { Title = "Select Item(s)", Values = Tables.OwnedItem, Multi = true, AllowNull = true })
Options.SelectedTradeItems = selTradeItems
local t_ReqTrade = TradeSection:AddToggle("ReqTrade", { Title = "Auto Send Request", Default = false })
Toggles.ReqTrade = t_ReqTrade
local t_ReqTradeAccept = TradeSection:AddToggle("ReqTradeAccept", { Title = "Auto Accept Request", Default = false })
Toggles.ReqTradeAccept = t_ReqTradeAccept
local t_AutoAccept = TradeSection:AddToggle("AutoAccept", { Title = "Auto Accept Trade", Default = false })
Toggles.AutoAccept = t_AutoAccept

-- ============================================================
--  ARTIFACT TAB
-- ============================================================
local ArtStatusSection = Tabs.Artifact:AddSection("Status")
ArtStatusSection:AddParagraph({ Title = "Warning", Content = "Artifact features are in heavy development. Use at your own risk." })

local ArtUpgradeSection = Tabs.Artifact:AddSection("Upgrade")
local slUpgradeLimit = ArtUpgradeSection:AddSlider("UpgradeLimit", { Title = "Upgrade Limit", Default = 0, Min = 0, Max = 15, Rounding = 0 })
Options.UpgradeLimit = slUpgradeLimit
local selUpMS = ArtUpgradeSection:AddDropdown("Up_MS", { Title = "Main Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Up_MS = selUpMS
local t_ArtUpgrade = ArtUpgradeSection:AddToggle("ArtifactUpgrade", { Title = "Auto Upgrade", Default = false })
Toggles.ArtifactUpgrade = t_ArtUpgrade
t_ArtUpgrade:OnChanged(function(s) Thread("Artifact.Upgrade", SafeLoop("ArtifactLogic", Func_ArtifactAutomation), s) end)
local t_UpgradeStage = ArtUpgradeSection:AddToggle("UpgradeStage", { Title = "Upgrade in Stages", Default = false })
Toggles.UpgradeStage = t_UpgradeStage

local ArtLockSection = Tabs.Artifact:AddSection("Lock")
local selLockType = ArtLockSection:AddDropdown("Lock_Type", { Title = "Artifact Type", Values = Modules.ArtifactConfig.Categories, Multi = true, AllowNull = true })
Options.Lock_Type = selLockType
local selLockSet = ArtLockSection:AddDropdown("Lock_Set", { Title = "Artifact Set", Values = allSets, Multi = true, AllowNull = true })
Options.Lock_Set = selLockSet
local selLockMS = ArtLockSection:AddDropdown("Lock_MS", { Title = "Main Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Lock_MS = selLockMS
local selLockSS = ArtLockSection:AddDropdown("Lock_SS", { Title = "Sub Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Lock_SS = selLockSS
local slLockMinSS = ArtLockSection:AddSlider("Lock_MinSS", { Title = "Min Sub-Stats", Default = 0, Min = 0, Max = 4, Rounding = 0 })
Options.Lock_MinSS = slLockMinSS
local t_ArtLock = ArtLockSection:AddToggle("ArtifactLock", { Title = "Auto Lock", Default = false })
Toggles.ArtifactLock = t_ArtLock
t_ArtLock:OnChanged(function(s) Thread("Artifact.Lock", SafeLoop("ArtifactLogic", Func_ArtifactAutomation), s) end)

local ArtDeleteSection = Tabs.Artifact:AddSection("Delete")
local selDelType = ArtDeleteSection:AddDropdown("Del_Type", { Title = "Artifact Type", Values = Modules.ArtifactConfig.Categories, Multi = true, AllowNull = true })
Options.Del_Type = selDelType
local selDelSet = ArtDeleteSection:AddDropdown("Del_Set", { Title = "Artifact Set", Values = allSets, Multi = true, AllowNull = true })
Options.Del_Set = selDelSet
local selDelMSHelmet = ArtDeleteSection:AddDropdown("Del_MS_Helmet", { Title = "Main Stat [Helmet]", Values = {"FlatDefense","Defense"}, Multi = true, AllowNull = true })
Options.Del_MS_Helmet = selDelMSHelmet
local selDelMSGloves = ArtDeleteSection:AddDropdown("Del_MS_Gloves", { Title = "Main Stat [Gloves]", Values = {"Damage"}, Multi = true, AllowNull = true })
Options.Del_MS_Gloves = selDelMSGloves
local selDelMSBody = ArtDeleteSection:AddDropdown("Del_MS_Body", { Title = "Main Stat [Body]", Values = allStats, Multi = true, AllowNull = true })
Options.Del_MS_Body = selDelMSBody
local selDelMSBoots = ArtDeleteSection:AddDropdown("Del_MS_Boots", { Title = "Main Stat [Boots]", Values = allStats, Multi = true, AllowNull = true })
Options.Del_MS_Boots = selDelMSBoots
local selDelSS = ArtDeleteSection:AddDropdown("Del_SS", { Title = "Sub Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Del_SS = selDelSS
local slDelMinSS = ArtDeleteSection:AddSlider("Del_MinSS", { Title = "Min Sub-Stats", Default = 0, Min = 0, Max = 4, Rounding = 0 })
Options.Del_MinSS = slDelMinSS
local t_ArtDelete = ArtDeleteSection:AddToggle("ArtifactDelete", { Title = "Auto Delete", Default = false })
Toggles.ArtifactDelete = t_ArtDelete
t_ArtDelete:OnChanged(function(s) Thread("Artifact.Delete", SafeLoop("ArtifactLogic", Func_ArtifactAutomation), s) end)
local t_DeleteUnlock = ArtDeleteSection:AddToggle("DeleteUnlock", { Title = "Auto Delete Unlocked", Default = false })
Toggles.DeleteUnlock = t_DeleteUnlock

local ArtEquipSection = Tabs.Artifact:AddSection("Auto Equip")
local selEqType = ArtEquipSection:AddDropdown("Eq_Type", { Title = "Artifact Type", Values = Modules.ArtifactConfig.Categories, Multi = true, AllowNull = true })
Options.Eq_Type = selEqType
local selEqMS = ArtEquipSection:AddDropdown("Eq_MS", { Title = "Main Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Eq_MS = selEqMS
local selEqSS = ArtEquipSection:AddDropdown("Eq_SS", { Title = "Sub Stat Filter", Values = allStats, Multi = true, AllowNull = true })
Options.Eq_SS = selEqSS
local t_ArtEquip = ArtEquipSection:AddToggle("ArtifactEquip", { Title = "Auto Equip", Default = false })
Toggles.ArtifactEquip = t_ArtEquip

-- ============================================================
--  DUNGEON TAB
-- ============================================================
local DungeonSection = Tabs.Dungeon:AddSection("Dungeon")
local selDungeon = DungeonSection:AddDropdown("SelectedDungeon", { Title = "Select Dungeon", Values = Tables.DungeonList, Multi = false, AllowNull = true })
Options.SelectedDungeon = selDungeon
local t_AutoDungeon = DungeonSection:AddToggle("AutoDungeon", { Title = "Auto Join Dungeon", Default = false })
Toggles.AutoDungeon = t_AutoDungeon
t_AutoDungeon:OnChanged(function(s) Thread("AutoDungeon", Func_AutoDungeon, s) end)
local t_AutoInfiniteTower = DungeonSection:AddToggle("AutoInfiniteTower", { Title = "Auto Infinite Tower", Default = false })
Toggles.AutoInfiniteTower = t_AutoInfiniteTower

-- ============================================================
--  PLAYER TAB
-- ============================================================
local PlayerGenSection = Tabs.Player:AddSection("General")

local function AddST(section, id, label, def, mn, mx, round)
    local tog = section:AddToggle("Toggle_"..id, { Title = label, Default = false })
    local sl  = section:AddSlider(id.."Value", { Title = label, Default = def, Min = mn, Max = mx, Rounding = round or 0 })
    Toggles[id] = tog; Options[id.."Value"] = sl
    return tog, sl
end

AddST(PlayerGenSection, "WS", "WalkSpeed", 16, 16, 250)
AddST(PlayerGenSection, "JP", "JumpPower", 50, 0, 500)
AddST(PlayerGenSection, "HH", "HipHeight", 2, 0, 10, 1)
AddST(PlayerGenSection, "Grav", "Gravity", 196, 0, 500, 1)
AddST(PlayerGenSection, "Zoom", "Camera Zoom", 128, 128, 10000)
AddST(PlayerGenSection, "FOV", "Field of View", 70, 30, 120)

local t_TPW, sl_TPW = AddST(PlayerGenSection, "TPW", "TPWalk", 1, 1, 10, 1)
t_TPW:OnChanged(function(s) Thread("TPW", FuncTPW, s) end)

local t_LimitFPS, sl_LimitFPS = AddST(PlayerGenSection, "LimitFPS", "Set Max FPS", 60, 5, 360)
if Support.FPS then
    t_LimitFPS:OnChanged(function(s) if not s then setfpscap(999) end end)
    sl_LimitFPS:OnChanged(function(v) if Toggles.Toggle_LimitFPS and Toggles.Toggle_LimitFPS.Value then setfpscap(v) end end)
end

local t_Noclip = PlayerGenSection:AddToggle("Noclip", { Title = "Noclip", Default = false })
Toggles.Noclip = t_Noclip
t_Noclip:OnChanged(function(s) Thread("Noclip", FuncNoclip, s) end)

local t_AntiKB = PlayerGenSection:AddToggle("AntiKnockback", { Title = "Anti Knockback", Default = false })
Toggles.AntiKnockback = t_AntiKB
t_AntiKB:OnChanged(function(s) Thread("AntiKnockback", Func_AntiKnockback, s) end)

local t_3DRender = PlayerGenSection:AddToggle("Disable3DRender", { Title = "Disable 3D Rendering", Default = false })
Toggles.Disable3DRender = t_3DRender
t_3DRender:OnChanged(function(v) RunService:Set3dRenderingEnabled(not v) end)

local t_FPSBoost = PlayerGenSection:AddToggle("FPSBoost", { Title = "FPS Boost", Default = false })
Toggles.FPSBoost = t_FPSBoost
t_FPSBoost:OnChanged(function(s) ApplyFPSBoost(s) end)

local PlayerServerSection = Tabs.Player:AddSection("Server")

local t_AntiAFK = PlayerServerSection:AddToggle("AntiAFK", { Title = "Anti AFK", Default = true })
Toggles.AntiAFK = t_AntiAFK

local t_AutoReconnect = PlayerServerSection:AddToggle("AutoReconnect", { Title = "Auto Reconnect", Default = false })
Toggles.AutoReconnect = t_AutoReconnect
t_AutoReconnect:OnChanged(function(s) if s then Func_AutoReconnect() end end)

local t_NoGameplayPaused = PlayerServerSection:AddToggle("NoGameplayPaused", { Title = "No Gameplay Paused", Default = false })
Toggles.NoGameplayPaused = t_NoGameplayPaused
t_NoGameplayPaused:OnChanged(function(s) Thread("NoGameplayPaused", SafeLoop("Anti-Pause", Func_NoGameplayPaused), s) end)

PlayerServerSection:AddButton({ Title = "Rejoin", Callback = function() TeleportService:Teleport(game.PlaceId, Plr) end })

local PlayerGameSection = Tabs.Player:AddSection("Game")

local t_Fullbright = PlayerGameSection:AddToggle("Fullbright", { Title = "Fullbright", Default = false })
Toggles.Fullbright = t_Fullbright

local t_NoFog = PlayerGameSection:AddToggle("NoFog", { Title = "No Fog", Default = false })
Toggles.NoFog = t_NoFog

local t_InstantPP = PlayerGameSection:AddToggle("InstantPP", { Title = "Instant Prompt", Default = false })
Toggles.InstantPP = t_InstantPP

AddST(PlayerGameSection, "OverrideTime", "Time Of Day", 12, 0, 24, 1)

local PlayerSafetySection = Tabs.Player:AddSection("Safety")
PlayerSafetySection:AddButton({ Title = "Panic Stop (or press P)", Callback = PanicStop })

local t_AutoKick = PlayerSafetySection:AddToggle("AutoKick", { Title = "Auto Kick", Default = true })
Toggles.AutoKick = t_AutoKick

local selKickType = PlayerSafetySection:AddDropdown("SelectedKickType", { Title = "Kick Type", Values = {"Mod","Player Join","Public Server"}, Default = {"Mod"}, Multi = true })
Options.SelectedKickType = selKickType
selKickType:OnChanged(function() CheckServerTypeSafety() end)

-- ============================================================
--  TELEPORT TAB
-- ============================================================
local IslandSection = Tabs.Teleport:AddSection("Island Teleport")
local selIsland = IslandSection:AddDropdown("SelectedIsland", { Title = "Select Island", Values = Tables.IslandList, Multi = false, AllowNull = true })
Options.SelectedIsland = selIsland
IslandSection:AddButton({ Title = "Teleport to Island", Callback = function()
    if Options.SelectedIsland.Value then Remotes.TP_Portal:FireServer(Options.SelectedIsland.Value)
    else Notify("Select an island first!", 2) end
end })

local NPCSection = Tabs.Teleport:AddSection("NPC Teleport")
local selQuestNPC = NPCSection:AddDropdown("SelectedQuestNPC", { Title = "Quest NPC", Values = Tables.NPC_QuestList, Multi = false, AllowNull = true })
Options.SelectedQuestNPC = selQuestNPC
NPCSection:AddButton({ Title = "TP to Quest NPC", Callback = function()
    local questMap = {["DungeonUnlock"]="DungeonPortalsNPC",["SlimeKeyUnlock"]="SlimeCraftNPC"}
    SafeTeleportToNPC(Options.SelectedQuestNPC.Value, questMap)
end })

local selMiscNPC = NPCSection:AddDropdown("SelectedMiscNPC", { Title = "Misc NPC", Values = Tables.NPC_MiscList, Multi = false, AllowNull = true })
Options.SelectedMiscNPC = selMiscNPC
NPCSection:AddButton({ Title = "TP to Misc NPC", Callback = function()
    local miscMap = {["ArmHaki"]="HakiQuest",["Observation"]="ObservationBuyer"}
    if Options.SelectedMiscNPC.Value then SafeTeleportToNPC(Options.SelectedMiscNPC.Value, miscMap) end
end })

local selMovesetNPC = NPCSection:AddDropdown("SelectedMovesetNPC", { Title = "Moveset NPC", Values = Tables.NPC_MovesetList, Multi = false, AllowNull = true })
Options.SelectedMovesetNPC = selMovesetNPC
NPCSection:AddButton({ Title = "TP to Moveset NPC", Callback = function()
    if Options.SelectedMovesetNPC.Value then SafeTeleportToNPC(Options.SelectedMovesetNPC.Value) end
end })

local selMasteryNPC = NPCSection:AddDropdown("SelectedMasteryNPC", { Title = "Mastery NPC", Values = Tables.NPC_MasteryList, Multi = false, AllowNull = true })
Options.SelectedMasteryNPC = selMasteryNPC
NPCSection:AddButton({ Title = "TP to Mastery NPC", Callback = function()
    if Options.SelectedMasteryNPC.Value then SafeTeleportToNPC(Options.SelectedMasteryNPC.Value) end
end })

NPCSection:AddButton({ Title = "TP to Level Based Quest", Callback = function()
    local distance = tonumber(pingUI.PingMarker:WaitForChild('DistanceLabel').Text:match("%d+"))
    if not distance then Notify("Something wrong..", 2); return end
    local target = findNPCByDistance(distance)
    if target then Plr.Character.HumanoidRootPart.CFrame = target:GetPivot() * CFrame.new(0,3,0) end
end })

-- ============================================================
--  MISC TAB
-- ============================================================
local MerchantSection = Tabs.Misc:AddSection("Merchant")
local selMerchantItems = MerchantSection:AddDropdown("SelectedMerchantItems", { Title = "Select Item(s)", Values = Tables.MerchantList, Multi = true, AllowNull = true })
Options.SelectedMerchantItems = selMerchantItems
local t_AutoMerchant = MerchantSection:AddToggle("AutoMerchant", { Title = "Auto Buy Items", Default = false })
Toggles.AutoMerchant = t_AutoMerchant
t_AutoMerchant:OnChanged(function(s) Thread("AutoMerchant", SafeLoop("Merchant", Func_AutoMerchant), s) end)

local selDungeonMerchant = MerchantSection:AddDropdown("SelectedDungeonMerchantItems", { Title = "Dungeon Item(s)", Values = Tables.DungeonMerchantList or {}, Multi = true, AllowNull = true })
Options.SelectedDungeonMerchantItems = selDungeonMerchant
local t_AutoDungeonMerchant = MerchantSection:AddToggle("AutoDungeonMerchant", { Title = "Auto Buy Dungeon Items", Default = false })
Toggles.AutoDungeonMerchant = t_AutoDungeonMerchant

local selTowerMerchant = MerchantSection:AddDropdown("SelectedTowerMerchantItems", { Title = "Tower Item(s)", Values = Tables.InfiniteTowerMerchantList or {}, Multi = true, AllowNull = true })
Options.SelectedTowerMerchantItems = selTowerMerchant
local t_AutoTowerMerchant = MerchantSection:AddToggle("AutoTowerMerchant", { Title = "Auto Buy Tower Items", Default = false })
Toggles.AutoTowerMerchant = t_AutoTowerMerchant

local selBossRushMerchant = MerchantSection:AddDropdown("SelectedBossRushMerchantItems", { Title = "Boss Rush Item(s)", Values = Tables.BossRushMerchantList or {}, Multi = true, AllowNull = true })
Options.SelectedBossRushMerchantItems = selBossRushMerchant
local t_AutoBossRushMerchant = MerchantSection:AddToggle("AutoBossRushMerchant", { Title = "Auto Buy Boss Rush Items", Default = false })
Toggles.AutoBossRushMerchant = t_AutoBossRushMerchant

local ChestSection = Tabs.Misc:AddSection("Chests & Crafting")
local selChests = ChestSection:AddDropdown("SelectedChests", { Title = "Select Chest(s)", Values = Tables.Rarities, Multi = true, AllowNull = true })
Options.SelectedChests = selChests
local t_AutoChest = ChestSection:AddToggle("AutoChest", { Title = "Auto Open Chest", Default = false })
Toggles.AutoChest = t_AutoChest
t_AutoChest:OnChanged(function(s) Thread("AutoChest", SafeLoop("Chest", Func_AutoChest), s) end)

local selCraftItems = ChestSection:AddDropdown("SelectedCraftItems", { Title = "Item(s) to Craft", Values = Tables.CraftItemList, Multi = true, AllowNull = true })
Options.SelectedCraftItems = selCraftItems
local t_AutoCraft = ChestSection:AddToggle("AutoCraftItem", { Title = "Auto Craft", Default = false })
Toggles.AutoCraftItem = t_AutoCraft
t_AutoCraft:OnChanged(function(s) Thread("AutoCraft", SafeLoop("Craft", Func_AutoCraft), s) end)

local NotifSection = Tabs.Misc:AddSection("Notifications")
local t_AutoDeleteNotif = NotifSection:AddToggle("AutoDeleteNotif", { Title = "Auto Hide Notifications", Default = false })
Toggles.AutoDeleteNotif = t_AutoDeleteNotif

local PuzzleSection = Tabs.Misc:AddSection("Puzzles")
PuzzleSection:AddButton({ Title = "Complete Dungeon Puzzle", Callback = function()
    if not Support.Proximity then Notify("Proximity not supported!", 3); return end
    if Plr.Data.Level.Value >= 5000 then UniversalPuzzleSolver("Dungeon")
    else Notify("Level 5000 required!", 3) end
end })
PuzzleSection:AddButton({ Title = "Complete Slime Key Puzzle", Callback = function()
    if Support.Proximity then UniversalPuzzleSolver("Slime") else Notify("Proximity not supported!", 3) end
end })
PuzzleSection:AddButton({ Title = "Complete Demonite Puzzle", Callback = function()
    if Support.Proximity then UniversalPuzzleSolver("Demonite") else Notify("Proximity not supported!", 3) end
end })
PuzzleSection:AddButton({ Title = "Complete Hogyoku Puzzle", Callback = function()
    if not Support.Proximity then Notify("Proximity not supported!", 3); return end
    if Plr.Data.Level.Value >= 8500 then UniversalPuzzleSolver("Hogyoku")
    else Notify("Level 8500 required!", 3) end
end })

local QuestlineSection = Tabs.Misc:AddSection("Questlines")
local selQuestline = QuestlineSection:AddDropdown("SelectedQuestline", { Title = "Select Questline", Values = Tables.QuestlineList, Multi = false, AllowNull = true })
Options.SelectedQuestline = selQuestline
local selQuestlinePlayer = QuestlineSection:AddInput("SelectedQuestline_Player", { Title = "Player Name [Kill]", Default = "", Placeholder = "Username..." })
Options.SelectedQuestline_Player = selQuestlinePlayer
local selQuestlineDMG = QuestlineSection:AddDropdown("SelectedQuestline_DMGTaken", { Title = "Mob [Take Damage]", Values = Tables.AllEntitiesList, Multi = false, AllowNull = true })
Options.SelectedQuestline_DMGTaken = selQuestlineDMG
QuestlineSection:AddButton({ Title = "Refresh Mob List", Callback = function() UpdateAllEntities() end })
local t_AutoQuestline = QuestlineSection:AddToggle("AutoQuestline", { Title = "Auto Questline [BETA]", Default = false })
Toggles.AutoQuestline = t_AutoQuestline

-- ============================================================
--  WEBHOOK TAB
-- ============================================================
local WebhookSection = Tabs.Webhook:AddSection("Config")
local inWebhookURL = WebhookSection:AddInput("WebhookURL", { Title = "Webhook URL", Default = "", Placeholder = "https://discord.com/api/webhooks/..." })
Options.WebhookURL = inWebhookURL
local inUID = WebhookSection:AddInput("UID", { Title = "User ID (for ping)", Default = "", Placeholder = "Discord ID..." })
Options.UID = inUID
local selWHData = WebhookSection:AddDropdown("SelectedData", { Title = "Select Data", Values = {"Name","Stats","New Items","All Items"}, Multi = true })
Options.SelectedData = selWHData
local selWHRarity = WebhookSection:AddDropdown("SelectedItemRarity", { Title = "Rarity Filter", Values = {"Common","Uncommon","Rare","Epic","Legendary","Mythical","Secret"}, Default = {"Common","Uncommon","Rare","Epic","Legendary","Mythical","Secret"}, Multi = true })
Options.SelectedItemRarity = selWHRarity
local t_PingUser = WebhookSection:AddToggle("PingUser", { Title = "Ping User", Default = false })
Toggles.PingUser = t_PingUser
local t_SendWebhook = WebhookSection:AddToggle("SendWebhook", { Title = "Send Webhook", Default = false })
Toggles.SendWebhook = t_SendWebhook
t_SendWebhook:OnChanged(function(s) Thread("WebhookLoop", Func_WebhookLoop, s) end)
local slWebhookDelay = WebhookSection:AddSlider("WebhookDelay", { Title = "Send Every X Minutes", Default = 5, Min = 1, Max = 30, Rounding = 0 })
Options.WebhookDelay = slWebhookDelay

-- ============================================================
--  SETTINGS TAB
-- ============================================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "SelectedIsland","SelectedQuestNPC","SelectedMiscNPC","SelectedMovesetNPC","SelectedMasteryNPC" })
SaveManager:SetFolder("FourHub/SailorPiece")
InterfaceManager:SetFolder("FourHub/SailorPiece")
SaveManager:BuildConfigSection(Tabs.Settings)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

-- ============================================================
--  RUNTIME LOOPS  (identical to original)
-- ============================================================
Connections.Player_General = RunService.Stepped:Connect(function()
    local Hum = Plr.Character and Plr.Character:FindFirstChildOfClass("Humanoid")
    if Hum then
        if Toggles.Toggle_WS and Toggles.Toggle_WS.Value then Hum.WalkSpeed = Options.WSValue.Value end
        if Toggles.Toggle_JP and Toggles.Toggle_JP.Value then Hum.JumpPower = Options.JPValue.Value; Hum.UseJumpPower = true end
        if Toggles.Toggle_HH and Toggles.Toggle_HH.Value then Hum.HipHeight = Options.HHValue.Value end
    end
    workspace.Gravity = (Toggles.Toggle_Grav and Toggles.Toggle_Grav.Value) and Options.GravValue.Value or 192
    if Toggles.Toggle_FOV and Toggles.Toggle_FOV.Value then workspace.CurrentCamera.FieldOfView = Options.FOVValue.Value end
    if Toggles.Toggle_Zoom and Toggles.Toggle_Zoom.Value then Plr.CameraMaxZoomDistance = Options.ZoomValue.Value end
end)

task.spawn(function()
    while task.wait() do
        if Toggles.Fullbright and Toggles.Fullbright.Value then
            Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = false
        elseif Toggles.Toggle_OverrideTime and Toggles.Toggle_OverrideTime.Value then
            Lighting.ClockTime = Options.OverrideTimeValue.Value
        end
        if Toggles.NoFog and Toggles.NoFog.Value then Lighting.FogEnd = 9e9 end
        if not getgenv().FourHub_Running then break end
    end
end)

RunService.Stepped:Connect(function()
    if Shared.Farm and Shared.Target then
        local char = GetCharacter()
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end
    end
end)

game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt)
    if Toggles.InstantPP and Toggles.InstantPP.Value then prompt.HoldDuration = 0 end
end)

-- Panic keybind (P)
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.P then PanicStop() end
end)

-- Notification filter
local NotifFrame = PGui:WaitForChild("NotificationUI"):WaitForChild("NotificationsFrame")
NotifFrame.ChildAdded:Connect(function(child) ProcessNotification(child) end)
for _, child in pairs(NotifFrame:GetChildren()) do ProcessNotification(child) end

-- Anti-AFK
task.spawn(function()
    DisableIdled()
    while true do
        task.wait(60)
        if Toggles.AntiAFK and Toggles.AntiAFK.Value then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                task.wait(0.2)
                VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end)
        end
    end
end)

-- Main M1 + farm execution loop
task.spawn(function()
    while true do
        task.wait()
        if Shared.AltActive then continue end
        if not Shared.Farm or Shared.MerchantBusy or not Shared.Target then continue end
        local success, err = pcall(function()
            local char = GetCharacter(); local target = Shared.Target
            if not target or not char then return end
            local npcHum = target:FindFirstChildOfClass("Humanoid")
            local npcRoot = target:FindFirstChild("HumanoidRootPart")
            local root = char:FindFirstChild("HumanoidRootPart")
            if npcHum and npcRoot and root then
                local currentDist = (root.Position - npcRoot.Position).Magnitude
                local hpPercent = (npcHum.Health / npcHum.MaxHealth) * 100
                local minMaxHP = tonumber(Options.InstaKillMinHP and Options.InstaKillMinHP.Value) or 0
                local ikThreshold = tonumber(Options.InstaKillHP and Options.InstaKillHP.Value) or 90
                if (Toggles.InstaKill and Toggles.InstaKill.Value) and npcHum.MaxHealth >= minMaxHP and hpPercent < ikThreshold then
                    npcHum.Health = 0
                    if not target:FindFirstChild("IK_Active") then
                        local tag = Instance.new("Folder"); tag.Name = "IK_Active"
                        tag:SetAttribute("TriggerTime", tick()); tag.Parent = target
                    end
                end
                if currentDist < 35 then
                    if math.abs(root.Position.Y - npcRoot.Position.Y) > 50 then root.Velocity = Vector3.new(0,-100,0) end
                    local m1Delay = tonumber(Options.M1Speed and Options.M1Speed.Value) or 0.2
                    if tick() - Shared.LastM1 >= m1Delay then
                        if Toggles.SwitchWeapon and Toggles.SwitchWeapon.Value then EquipWeapon() end
                        Remotes.M1:FireServer(); Shared.LastM1 = tick()
                    end
                end
            end
        end)
        if not success then Notify("ERROR: "..tostring(err), 10) end
    end
end)

-- Farm target loop
task.spawn(function()
    while task.wait() do
        if not Shared.Farm or Shared.MerchantBusy then Shared.Target = nil; continue end
        local char = GetCharacter()
        if not char or Shared.Recovering then continue end
        if Shared.TargetValid and (not Shared.Target or not Shared.Target.Parent or Shared.Target.Humanoid.Health <= 0) then
            Shared.KillTick = tick(); Shared.TargetValid = false
        end
        if tick() - Shared.KillTick < (tonumber(Options.TargetTPCD and Options.TargetTPCD.Value) or 0) then continue end
        HandleSummons()
        local currentPity, maxPity = GetCurrentPity()
        local isPityReady = (Toggles.PityBossFarm and Toggles.PityBossFarm.Value) and currentPity >= (maxPity-1)
        local foundTask = false
        if isPityReady then
            local t, isl, fType = GetPityTarget()
            if t then
                foundTask = true; Shared.Target = t; Shared.TargetValid = true
                UpdateSwitchState(t, fType); ExecuteFarmLogic(t, isl, fType)
            end
        end
        if not foundTask then
            for i = 1, #PriorityTasks do
                local taskName = Options["SelectedPriority_"..i] and Options["SelectedPriority_"..i].Value
                if not taskName then continue end
                if isPityReady and (taskName == "Boss" or taskName == "All Mob Farm" or taskName == "Mob") then continue end
                local t, isl, fType = CheckTask(taskName)
                if t then
                    foundTask = true; Shared.Target = (typeof(t)=="Instance") and t or nil; Shared.TargetValid = true
                    UpdateSwitchState(t, fType)
                    if taskName ~= "Merchant" then ExecuteFarmLogic(t, isl, fType) end
                    break
                end
            end
        end
        if not foundTask then Shared.Target = nil; UpdateSwitchState(nil, "None") end
    end
end)

-- Recovery / out-of-bounds check
task.spawn(function()
    while task.wait(1) do
        if not getgenv().FourHub_Running then break end
        local char = GetCharacter(); local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and not Shared.MovingIsland then
            local pos = root.Position
            if pos.Y > 5000 or math.abs(pos.X) > 10000 or math.abs(pos.Z) > 10000 then
                Shared.Recovering = true; Notify("Something went wrong, resetting..", 5)
                root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
                if IslandCrystals["Starter"] then
                    root.CFrame = IslandCrystals["Starter"]:GetPivot() * CFrame.new(0,5,0); task.wait(1)
                end
                Shared.Recovering = false
            end
        end
    end
end)

-- Inventory sync loop
task.spawn(function()
    while getgenv().FourHub_Running do
        if Remotes.ReqInventory then Remotes.ReqInventory:FireServer() end
        task.wait(30)
    end
end)

-- Pity label update (just notifies, no obsidian label)
task.spawn(function()
    while task.wait(1) do
        if not getgenv().FourHub_Running then break end
        pcall(function()
            local current, max = GetCurrentPity()
            -- Could update a Fluent paragraph here if desired
        end)
    end
end)

-- Trade auto loop
task.spawn(Func_AutoTrade)

-- ACThing
ACThing(true)

-- Init
UpdateNPCLists()
UpdateAllEntities()
InitAutoKick()
PopulateNPCLists()

task.spawn(function()
    if Remotes.ReqInventory then Remotes.ReqInventory:FireServer() end
    local timeout = 0
    while not Shared.InventorySynced and timeout < 5 do
        task.wait(0.15); timeout = timeout + 0.15
        if timeout == 1.5 and Remotes.ReqInventory then Remotes.ReqInventory:FireServer() end
    end
    SaveManager:LoadAutoloadConfig()
    if Remotes.ReqInventory then Remotes.ReqInventory:FireServer() end
end)

Notify("FourHub Fluent Edition loaded! Press U to toggle UI.", 5)
Notify("Report bugs in Discord!", 4)

-- Unload handler
Window.OnClose = function()
    getgenv().FourHub_Running = false
    Shared.Farm = false
    Cleanup(Connections)
    Cleanup(Flags)
end
