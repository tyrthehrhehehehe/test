-- ============================================================
--  CattStar Sailor-Piece | WindUI Version
--  Merged from: CattStar script (WindUI) + FourHub script
--  UI Library: WindUI (Footagesus)
-- ============================================================

-- Prevent double-run
if getgenv().SailorPiece_Running then
    warn("Script already running!")
    return
end
getgenv().SailorPiece_Running = true

repeat task.wait() until game:IsLoaded()

-- ============================================================
--  SERVICES & LOCALS
-- ============================================================
do
    player              = game.Players.LocalPlayer
    playerName          = player.Name
    char                = player.Character
    playerDisplayName   = player.DisplayName
    replicated          = game:GetService("ReplicatedStorage")
    TweenService        = game:GetService("TweenService")
    HttpService         = game:GetService("HttpService")
    TeleportService     = game:GetService("TeleportService")
    PlaceId             = game.PlaceId
    RunService          = game:GetService("RunService")
    Lighting            = game:GetService("Lighting")
    Terrain             = workspace:FindFirstChildOfClass("Terrain")
    vu                  = game:GetService("VirtualUser")
    vim1                = game:GetService("VirtualInputManager")
    Players             = game:GetService("Players")
    UIS                 = game:GetService("UserInputService")
    GuiService          = game:GetService("GuiService")
    PGui                = player:WaitForChild("PlayerGui")
end

-- ============================================================
--  MOB DATA
-- ============================================================
local mobs = {
    { isBoss=false, island="Starter",  title="Thief Hunter (Lv.0)",             amount=5, id="thief_hunt_1",            recommendedLevel=0,    questNPC="QuestNPC1",  npcType="Thief" },
    { isBoss=true,  island="Starter",  title="Thief Boss (Lv.100)",              amount=1, id="boss_hunt_1",             recommendedLevel=100,  questNPC="QuestNPC2",  npcType="ThiefBoss" },
    { isBoss=false, island="Jungle",   title="Monkey Hunter (Lv.250)",           amount=5, id="monkey_hunt_1",           recommendedLevel=250,  questNPC="QuestNPC3",  npcType="Monkey" },
    { isBoss=true,  island="Jungle",   title="Monkey Boss (Lv.500)",             amount=1, id="monkey_hunt_2",           recommendedLevel=500,  questNPC="QuestNPC4",  npcType="MonkeyBoss" },
    { isBoss=false, island="Desert",   title="Desert Bandit Hunter (Lv.750)",    amount=5, id="desert_hunt_1",           recommendedLevel=750,  questNPC="QuestNPC5",  npcType="DesertBandit" },
    { isBoss=true,  island="Desert",   title="Desert Bandit Boss (Lv.1000)",     amount=1, id="desert_hunt_2",           recommendedLevel=1000, questNPC="QuestNPC6",  npcType="DesertBoss" },
    { isBoss=false, island="Snow",     title="Frost Rogue Hunter (Lv.1500)",     amount=5, id="snow_hunt_1",             recommendedLevel=1500, questNPC="QuestNPC7",  npcType="FrostRogue" },
    { isBoss=true,  island="Snow",     title="Winter Warden Boss (Lv.2000)",     amount=1, id="snow_hunt_2",             recommendedLevel=2000, questNPC="QuestNPC8",  npcType="SnowBoss" },
    { isBoss=false, island="Shibuya",  title="Sorcerer Hunter (Lv.3000)",        amount=5, id="jjk_hunt_1",              recommendedLevel=3000, questNPC="QuestNPC9",  npcType="Sorcerer" },
    { isBoss=true,  island="Shibuya",  title="Panda Sorcerer Boss (Lv.4000)",    amount=1, id="jjk_hunt_2",              recommendedLevel=4000, questNPC="QuestNPC10", npcType="PandaMiniBoss" },
    { isBoss=false, island="Hollow",   title="Hollow Hunter (Lv.5000)",          amount=5, id="hollow_hunt_1",           recommendedLevel=5000, questNPC="QuestNPC11", npcType="Hollow" },
    { isBoss=false, island="Shinjuku", title="Strong Sorcerer Hunter (Lv.6000)", amount=5, id="strong_sorcerer_hunt_1",  recommendedLevel=6000, questNPC="QuestNPC12", npcType="StrongSorcerer" },
    { isBoss=false, island="Shinjuku", title="Curse Hunter (Lv.7000)",           amount=5, id="curse_hunt_1",            recommendedLevel=7000, questNPC="QuestNPC13", npcType="Curse" },
    { isBoss=false, island="Slime",    title="Slime Warrior Hunter (Lv.8000)",   amount=5, id="slime_warrior_hunt_1",    recommendedLevel=8000, questNPC="QuestNPC14", npcType="SlimeWarrior" },
    { isBoss=false, island="Academy",  title="Academy Challenge (Lv.9000)",      amount=5, id="academy_teacher_hunt_1",  recommendedLevel=9000, questNPC="QuestNPC15", npcType="AcademyTeacher" },
}

TeleportLocations = {
    { Name="Starter",  Display="Starter",  Portal="Starter" },
    { Name="Jungle",   Display="Jungle",   Portal="Jungle" },
    { Name="Desert",   Display="Desert",   Portal="Desert" },
    { Name="Snow",     Display="Snow",     Portal="Snow" },
    { Name="Sailor",   Display="Sailor",   Portal="Sailor" },
    { Name="Shibuya",  Display="Shibuya",  Portal="Shibuya" },
    { Name="Hollow",   Display="Hollow",   Portal="HollowIsland" },
    { Name="Boss",     Display="Boss",     Portal="Boss" },
    { Name="Dungeon",  Display="Dungeon",  Portal="Dungeon" },
    { Name="Shinjuku", Display="Shinjuku", Portal="Shinjuku" },
    { Name="Slime",    Display="Slime",    Portal="Slime" },
    { Name="Academy",  Display="Academy",  Portal="Academy" },
    { Name="Valentine",Display="Valentine",Portal="Valentine" },
    { Name="HuecoMundo",Display="HuecoMundo",Portal="HuecoMundo" },
    { Name="Judgement",Display="Judgement",Portal="Judgement" },
    { Name="Tower",    Display="Tower",    Portal="TowerIsland" },
}

-- ============================================================
--  SUPPORT DETECTION
-- ============================================================
local Support = {
    Webhook    = (typeof(request)            == "function" or typeof(http_request) == "function"),
    Clipboard  = (typeof(setclipboard)       == "function"),
    FileIO     = (typeof(writefile)          == "function" and typeof(isfile) == "function"),
    Proximity  = (typeof(fireproximityprompt)== "function"),
    FPS        = (typeof(setfpscap)          == "function"),
    Connections= (typeof(getconnections)     == "function" or typeof(get_signal_cons) == "function"),
}

-- ============================================================
--  REMOTES (mapped from FourHub)
-- ============================================================
local function GetRemote(parent, pathStr)
    local cur = parent
    for _, name in ipairs(pathStr:split(".")) do
        if not cur then return nil end
        cur = cur:FindFirstChild(name)
    end
    return cur
end

local Remotes = {
    M1              = GetRemote(replicated, "CombatSystem.Remotes.RequestHit"),
    UseSkill        = GetRemote(replicated, "AbilitySystem.Remotes.RequestAbility"),
    UseFruit        = GetRemote(replicated, "RemoteEvents.FruitPowerRemote"),
    QuestAccept     = GetRemote(replicated, "RemoteEvents.QuestAccept"),
    QuestAbandon    = GetRemote(replicated, "RemoteEvents.QuestAbandon"),
    UseItem         = GetRemote(replicated, "Remotes.UseItem"),
    TP_Portal       = GetRemote(replicated, "Remotes.TeleportToPortal"),
    AddStat         = GetRemote(replicated, "RemoteEvents.AllocateStat"),
    SummonBoss      = GetRemote(replicated, "Remotes.RequestSummonBoss"),
    EquipWeapon     = GetRemote(replicated, "Remotes.EquipWeapon"),
    SlimeCraft      = GetRemote(replicated, "Remotes.RequestSlimeCraft"),
    GrailCraft      = GetRemote(replicated, "Remotes.RequestGrailCraft"),
    ArmHaki         = GetRemote(replicated, "RemoteEvents.HakiRemote"),
    ObserHaki       = GetRemote(replicated, "RemoteEvents.ObservationHakiRemote"),
    ConquerorHaki   = GetRemote(replicated, "Remotes.ConquerorHakiRemote"),
    OpenDungeon     = GetRemote(replicated, "Remotes.RequestDungeonPortal"),
    SettingsToggle  = GetRemote(replicated, "RemoteEvents.SettingsToggle"),
    SkillTreeUpgrade= GetRemote(replicated, "RemoteEvents.SkillTreeUpgrade"),
    Enchant         = GetRemote(replicated, "Remotes.EnchantAccessory"),
    Blessing        = GetRemote(replicated, "Remotes.BlessWeapon"),
    UpInventory     = GetRemote(replicated, "Remotes.UpdateInventory"),
    ReqInventory    = GetRemote(replicated, "Remotes.RequestInventory"),
    HakiStateUpdate = GetRemote(replicated, "RemoteEvents.HakiStateUpdate"),
    MerchantBuy     = GetRemote(replicated, "Remotes.MerchantRemotes.PurchaseMerchantItem"),
    OpenMerchantR   = GetRemote(replicated, "Remotes.MerchantRemotes.OpenMerchantUI"),
    StockUpdate     = GetRemote(replicated, "Remotes.MerchantRemotes.MerchantStockUpdate"),
    PurchaseProduct = GetRemote(replicated, "Remotes.ShopRemotes.PurchaseProduct"),
    JJKSummonBoss   = GetRemote(replicated, "Remotes.RequestSpawnStrongestBoss"),
    RimuruBoss      = GetRemote(replicated, "RemoteEvents.RequestSpawnRimuru"),
    AnosBoss        = GetRemote(replicated, "Remotes.RequestSpawnAnosBoss"),
    TrueAizenBoss   = GetRemote(replicated, "RemoteEvents.RequestSpawnTrueAizen"),
    AtomicBoss      = GetRemote(replicated, "RemoteEvents.RequestSpawnAtomic"),
    NotifyItemDrop  = GetRemote(replicated, "Remotes.NotifyItemDrop"),
    BossUIUpdate    = GetRemote(replicated, "Remotes.BossUIUpdate"),
    Ascend          = GetRemote(replicated, "RemoteEvents.RequestAscend"),
    ReqAscend       = GetRemote(replicated, "RemoteEvents.GetAscendData"),
    CloseAscend     = GetRemote(replicated, "RemoteEvents.CloseAscendUI"),
    SpecPassiveReroll=GetRemote(replicated, "RemoteEvents.SpecPassiveReroll"),
    SpecPassiveSkip = GetRemote(replicated, "RemoteEvents.SpecPassiveUpdateAutoSkip"),
    SpecPassiveUpdate=GetRemote(replicated, "RemoteEvents.SpecPassiveDataUpdate"),
    SkillTreeUpdate = GetRemote(replicated, "RemoteEvents.SkillTreeUpdate"),
    UpStatReroll    = GetRemote(replicated, "RemoteEvents.StatRerollUpdate"),
    UpPlayerStats   = GetRemote(replicated, "RemoteEvents.UpdatePlayerStats"),
    UpAscend        = GetRemote(replicated, "RemoteEvents.AscendDataUpdate"),
    RerollSingleStat= GetRemote(replicated, "Remotes.RerollSingleStat"),
    Roll_Trait      = GetRemote(replicated, "RemoteEvents.TraitReroll"),
    TraitAutoSkip   = GetRemote(replicated, "RemoteEvents.TraitUpdateAutoSkip"),
    TraitConfirm    = GetRemote(replicated, "RemoteEvents.TraitConfirm"),
    TitleSync       = GetRemote(replicated, "RemoteEvents.TitleDataSync"),
    EquipTitle      = GetRemote(replicated, "RemoteEvents.TitleEquip"),
    TitleUnequip    = GetRemote(replicated, "RemoteEvents.TitleUnequip"),
    EquipRune       = GetRemote(replicated, "Remotes.EquipRune"),
    LoadoutLoad     = GetRemote(replicated, "RemoteEvents.LoadoutLoad"),
    ArtifactSync    = GetRemote(replicated, "RemoteEvents.ArtifactDataSync"),
    ArtifactClaim   = GetRemote(replicated, "RemoteEvents.ArtifactMilestoneClaimReward"),
    MassDelete      = GetRemote(replicated, "RemoteEvents.ArtifactMassDeleteByUUIDs"),
    MassUpgrade     = GetRemote(replicated, "RemoteEvents.ArtifactMassUpgrade"),
    ArtifactLock    = GetRemote(replicated, "RemoteEvents.ArtifactLock"),
    ArtifactUnequip = GetRemote(replicated, "RemoteEvents.ArtifactUnequip"),
    ArtifactEquip   = GetRemote(replicated, "RemoteEvents.ArtifactEquip"),
    UseCode         = GetRemote(replicated, "RemoteEvents.CodeRedeem"),
    TradeRespond    = GetRemote(replicated, "Remotes.TradeRemotes.RespondToRequest"),
    TradeSend       = GetRemote(replicated, "Remotes.TradeRemotes.SendTradeRequest"),
    TradeAddItem    = GetRemote(replicated, "Remotes.TradeRemotes.AddItemToTrade"),
    TradeReady      = GetRemote(replicated, "Remotes.TradeRemotes.SetReady"),
    TradeConfirm    = GetRemote(replicated, "Remotes.TradeRemotes.ConfirmTrade"),
    TradeUpdated    = GetRemote(replicated, "Remotes.TradeRemotes.TradeUpdated"),
    SettingsSync    = GetRemote(replicated, "RemoteEvents.SettingsSync"),
    DungeonWaveVote = GetRemote(replicated, "Remotes.DungeonWaveVote"),
}

-- ============================================================
--  SHARED STATE
-- ============================================================
local Shared = {
    Farm            = true,
    Recovering      = false,
    MovingIsland    = false,
    Island          = "",
    Target          = nil,
    KillTick        = 0,
    TargetValid     = false,
    QuestNPC        = "",
    MobIdx          = 1,
    AllMobIdx       = 1,
    WeapRotationIdx = 1,
    ComboIdx        = 1,
    ParsedCombo     = {},
    ActiveWeap      = "",
    ArmHaki         = false,
    BossTIMap       = {},
    InventorySynced = false,
    Stats           = {},
    Settings        = {},
    GemStats        = {},
    SkillTree       = { Nodes={}, Points=0 },
    Passives        = {},
    SpecStatsSlider = {},
    ArtifactSession = { Inventory={}, Dust=0 },
    UpBlacklist     = {},
    MerchantBusy    = false,
    LocalMerchantTime=0,
    LastTimerTick   = tick(),
    MerchantExecute = false,
    FirstMerchantSync=false,
    CurrentStock    = {},
    LastM1          = 0,
    LastWRSwitch    = 0,
    LastSwitch      = { Title="", Rune="" },
    LastBuildSwitch = 0,
    LastDungeon     = 0,
    AltDamage       = {},
    AltActive       = false,
    TradeState      = {},
    GlobalPrio      = "FARM",
    UnlockedTitles  = {},
    Cached          = { Inv={}, Accessories={}, RawWeapCache={ Sword={}, Melee={} } },
}

-- Global toggles (for TP/movement functions)
_G.FarmLevel        = false
_G.AutoAttack       = false
_G.FarmSelectedMob  = false
_G.SelectedMobType  = nil
_G.AutoHaki         = false
_G.AutoStatsDefense = false
_G.AutoStatsPower   = false
_G.AutoStatsFruit   = false
_G.AutoEquipTool    = false
_G.SelectedAutoEquipTool = nil
_G.AutoSkill1       = false
_G.AutoSkill2       = false
_G.SailorNoclip     = false
_G.SailorESP        = false
_G.SailorAutoFarm   = false
_G.SelectedChestRarity = "Common Chest"
_G.SelectedChestNumber = 2
_G.SelectedTeleportLocation = TeleportLocations[1]
_G.UnlockDungeon    = false

-- Thread management
local Flags = {}
local function Thread(featurePath, featureFunc, isEnabled, ...)
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
            currentTable[flagKey] = task.spawn(featureFunc, ...)
        end
    else
        if activeThread and typeof(activeThread) == "thread" then
            task.cancel(activeThread)
            currentTable[flagKey] = nil
        end
    end
end

-- ============================================================
--  WINDUI LOAD
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ============================================================
--  HELPER FUNCTIONS
-- ============================================================

local function GetCharacter()
    local c = player.Character
    return (c and c:FindFirstChild("HumanoidRootPart") and c:FindFirstChildOfClass("Humanoid")) and c or nil
end

local function Abbreviate(n)
    local abbrev = {{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}
    for _, v in ipairs(abbrev) do
        if n >= v[1] then return string.format("%.1f%s", n/v[1], v[2]) end
    end
    return tostring(n)
end

local function CommaFormat(n)
    local s = tostring(n)
    return s:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,","")
end

function GetBestMob(currentLevel)
    local bestMob, highestValidLevel = nil, -1
    for _, mob in ipairs(mobs) do
        if mob.recommendedLevel <= currentLevel and mob.recommendedLevel > highestValidLevel then
            highestValidLevel = mob.recommendedLevel
            bestMob = mob
        end
    end
    return bestMob
end

TeleportToMobIsland = function(mob)
    if not mob or not mob.island then return end
    pcall(function()
        replicated.Remotes.TeleportToPortal:FireServer(mob.island)
    end)
    WindUI:Notify({
        Title   = "Teleporting",
        Content = "Going to "..mob.island.." for "..mob.npcType,
        Duration= 2,
        Icon    = "map-pin",
    })
end

GetConnectionEnemies = function(v)
    local d = {
        positions  = {},
        searchName = string.lower(v),
        playerHrp  = player.Character and player.Character:FindFirstChild("HumanoidRootPart"),
    }
    for _, npc in pairs(workspace.NPCs:GetChildren()) do
        local d2 = {
            hrp  = npc:FindFirstChild("HumanoidRootPart"),
            hum  = npc:FindFirstChild("Humanoid"),
            name = string.lower(npc.Name),
        }
        local nameMatch = d2.name == d.searchName or string.match(d2.name, "^"..d.searchName.."%d+$")
        if d2.hrp and d2.hum and d2.hum.Health > 0 and nameMatch then
            table.insert(d.positions, d2.hrp.CFrame)
        end
    end
    if d.playerHrp then
        table.sort(d.positions, function(a,b)
            return (a.Position - d.playerHrp.Position).Magnitude < (b.Position - d.playerHrp.Position).Magnitude
        end)
    end
    return d.positions
end

GetNearestMob = function()
    local data = {
        nearest   = nil,
        lastDist  = math.huge,
        folder    = workspace:FindFirstChild("NPCs"),
        playerHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart"),
    }
    if not data.folder or not data.playerHrp then return nil end
    for _, v in pairs(data.folder:GetChildren()) do
        local hrp = v:FindFirstChild("HumanoidRootPart")
        local hum = v:FindFirstChild("Humanoid")
        if hrp and hum and hum.Health > 0 then
            local dist = (data.playerHrp.Position - hrp.Position).Magnitude
            if dist < data.lastDist then
                data.lastDist = dist
                data.nearest  = hrp
            end
        end
    end
    return data.nearest
end

GetBackpackItems = function()
    local items = {}
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        table.insert(items, tool.Name)
    end
    return items
end

-- Tween movement (with BodyVelocity, respects _G.FarmLevel)
TP = function(targetCFrame)
    local data = {
        hrp   = player.Character and player.Character:FindFirstChild("HumanoidRootPart"),
        hum   = player.Character and player.Character:FindFirstChild("Humanoid"),
        speed = 250,
        offset= targetCFrame * CFrame.new(0, 15, 0),
    }
    if not data.hrp or not data.hum then return end
    data.dist  = (data.hrp.Position - data.offset.Position).Magnitude
    data.tween = TweenService:Create(data.hrp,
        TweenInfo.new(data.dist / data.speed, Enum.EasingStyle.Linear),
        {CFrame = data.offset})
    local bv = data.hrp:FindFirstChild("FloatBV") or Instance.new("BodyVelocity")
    bv.Name       = "FloatBV"
    bv.MaxForce   = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity   = Vector3.new(0,0,0)
    bv.Parent     = data.hrp
    task.spawn(function()
        while bv and bv.Parent do
            if not _G.FarmLevel or data.hum.Health <= 0 or _G.UnlockDungeon then
                bv:Destroy(); break
            end
            task.wait()
        end
    end)
    data.tween:Play()
    while data.tween.PlaybackState == Enum.PlaybackState.Playing do
        if not _G.FarmLevel then data.tween:Cancel(); break end
        task.wait()
    end
end

-- Simple tween (no _G guard)
Tween2 = function(targetCFrame)
    local data = {
        hrp   = player.Character and player.Character:FindFirstChild("HumanoidRootPart"),
        speed = 150,
    }
    if not data.hrp then return end
    data.dist  = (data.hrp.Position - targetCFrame.Position).Magnitude
    data.tween = TweenService:Create(data.hrp,
        TweenInfo.new(data.dist / data.speed, Enum.EasingStyle.Linear),
        {CFrame = targetCFrame})
    data.bv           = Instance.new("BodyVelocity")
    data.bv.MaxForce  = Vector3.new(math.huge, math.huge, math.huge)
    data.bv.Velocity  = Vector3.zero
    data.bv.Parent    = data.hrp
    data.tween:Play()
    data.tween.Completed:Wait()
    data.bv:Destroy()
end

-- HybridMove (tween + teleport combo)
local function HybridMove(targetCF)
    local character = GetCharacter()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local distance  = (root.Position - targetCF.Position).Magnitude
    local tweenSpeed= 180
    if distance > 50 then
        local tweenTarget = targetCF * CFrame.new(0,0,150)
        local tweenDist   = (root.Position - tweenTarget.Position).Magnitude
        local tween = TweenService:Create(root,
            TweenInfo.new(tweenDist/tweenSpeed, Enum.EasingStyle.Linear),
            {CFrame = tweenTarget})
        tween:Play(); tween.Completed:Wait()
        task.wait(0.1)
    end
    root.CFrame = targetCF
    root.AssemblyLinearVelocity = Vector3.new(0,0.01,0)
    task.wait(0.2)
end

-- ServerHop
ServerHop = function()
    local Api = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(Api))
    end)
    if success and result and result.data then
        local possibleServers = {}
        for _, server in pairs(result.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                table.insert(possibleServers, server.id)
            end
        end
        if #possibleServers > 0 then
            TeleportService:TeleportToPlaceInstance(PlaceId, possibleServers[math.random(1,#possibleServers)], player)
        end
    end
end

-- FarmBestMob (original from script 1)
local lastTeleport = 0
FarmBestMob = function()
    local ch  = player.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    local d = { level = player.Data and player.Data.Level and player.Data.Level.Value or 0 }
    d.mob = GetBestMob(d.level)
    if not d.mob then return end
    local mobCFrames = GetConnectionEnemies(d.mob.npcType)
    if #mobCFrames > 0 then
        local targetCFrame = mobCFrames[1]
        local distance = (hrp.Position - targetCFrame.Position).Magnitude
        if distance > 1000 then
            if tick() - lastTeleport > 5 then
                TeleportToMobIsland(d.mob)
                lastTeleport = tick()
                task.wait(2)
            end
            return
        end
        if distance > 10 then
            TP(targetCFrame * CFrame.new(50,0,50))
        end
        if _G.FarmLevel then
            pcall(function()
                replicated.CombatSystem.Remotes.RequestHit:FireServer(targetCFrame.Position)
            end)
        end
    else
        if tick() - lastTeleport > 3 then
            TeleportToMobIsland(d.mob)
            lastTeleport = tick()
            task.wait(2)
        end
    end
end

-- Get nearest aura target
local function GetNearestAuraTarget(range)
    range = range or 200
    local nearest, lastDist = nil, range
    local ch   = player.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local mobFolder = workspace:FindFirstChild("NPCs")
    if not mobFolder then return nil end
    for _, v in ipairs(mobFolder:GetChildren()) do
        if v:IsA("Model") then
            local dist = (root.Position - v:GetPivot().Position).Magnitude
            if dist <= lastDist then
                local hum = v:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    nearest  = v
                    lastDist = dist
                end
            end
        end
    end
    return nearest
end

-- CheckObsHaki
local function CheckObsHaki()
    local DodgeUI = PGui:FindFirstChild("DodgeCounterUI")
    if DodgeUI and DodgeUI:FindFirstChild("MainFrame") then
        return DodgeUI.MainFrame.Visible
    end
    return false
end

-- CheckArmHaki
local function CheckArmHaki()
    if Shared.ArmHaki then return true end
    local ch = GetCharacter()
    if ch then
        local leftArm  = ch:FindFirstChild("Left Arm")  or ch:FindFirstChild("LeftUpperArm")
        local rightArm = ch:FindFirstChild("Right Arm") or ch:FindFirstChild("RightUpperArm")
        if (leftArm and leftArm:FindFirstChild("Lightning Strike")) or
           (rightArm and rightArm:FindFirstChild("Lightning Strike")) then
            Shared.ArmHaki = true; return true
        end
    end
    return false
end

-- IsBusy (ForceField check)
local function IsBusy()
    return player.Character and player.Character:FindFirstChildOfClass("ForceField") ~= nil
end

-- EquipWeapon helper
local Tables = {
    ManualWeaponClass = { ["Invisible"]="Power", ["Bomb"]="Power", ["Quake"]="Power" },
    Weapon = {"Melee","Sword","Power"},
    OwnedWeapon = {}, AllOwnedWeapons = {}, OwnedAccessory = {},
    OwnedItem = {}, RuneList = {"None"},
    MobList = {}, MobToIsland = {},
    BossList = {}, AllBossList = {}, SummonList = {}, OtherSummonList = {"StrongestHistory","StrongestToday","Rimuru","Anos","TrueAizen","Atomic","AbyssalEmpress"},
    DiffList = {"Normal","Medium","Hard","Extreme"},
    MiniBossList = {"ThiefBoss","MonkeyBoss","DesertBoss","SnowBoss","PandaMiniBoss"},
    Rarities = {"Common","Rare","Epic","Legendary","Mythical","Secret","Aura Crate","Cosmetic Crate"},
    CraftItemList = {"SlimeKey","DivineGrail"},
    DungeonList = {"CidDungeon","RuneDungeon","DoubleDungeon","BossRush","InfiniteTower"},
    TraitList={}, RaceList={}, ClanList={}, SpecPassive={}, GemStat={}, GemRank={},
    QuestlineList={}, TitleList={}, UnlockedTitle={},
    AllEntitiesList={},
}

local SummonMap = {}

local function GetSafeModule(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    if obj and obj:IsA("ModuleScript") then
        local ok, res = pcall(require, obj)
        if ok then return res end
    end
    return nil
end

local Modules = {
    BossConfig    = GetSafeModule(replicated:FindFirstChild("Modules"), "BossConfig") or {Bosses={}},
    TimedConfig   = GetSafeModule(replicated:FindFirstChild("Modules"), "TimedBossConfig"),
    SummonConfig  = GetSafeModule(replicated:FindFirstChild("Modules"), "SummonableBossConfig"),
    Merchant      = GetSafeModule(replicated:FindFirstChild("Modules"), "MerchantConfig") or {ITEMS={}},
    WeaponClass   = GetSafeModule(replicated:FindFirstChild("Modules"), "WeaponClassification") or {Tools={}},
    Stats         = GetSafeModule(replicated:FindFirstChild("Modules"), "StatRerollConfig") or {StatKeys={},RankOrder={}},
    Quests        = GetSafeModule(replicated:FindFirstChild("Modules"), "QuestConfig") or {RepeatableQuests={},Questlines={}},
    ArtifactConfig= GetSafeModule(replicated:FindFirstChild("Modules"), "ArtifactConfig"),
    Title         = GetSafeModule(replicated:FindFirstChild("Modules"), "TitlesConfig") or {Titles={},GetSortedTitleIds=function() return {} end},
    Trait         = GetSafeModule(replicated:FindFirstChild("Modules"), "TraitConfig") or {Traits={}},
    Race          = GetSafeModule(replicated:FindFirstChild("Modules"), "RaceConfig") or {Races={}},
    Clan          = GetSafeModule(replicated:FindFirstChild("Modules"), "ClanConfig") or {Clans={}},
    SpecPassive   = GetSafeModule(replicated:FindFirstChild("Modules"), "SpecPassiveConfig"),
    SkillTree     = GetSafeModule(replicated:FindFirstChild("Modules"), "SkillTreeConfig"),
    Codes         = GetSafeModule(replicated, "CodesConfig") or {Codes={}},
    ItemRarity    = GetSafeModule(replicated:FindFirstChild("Modules"), "ItemRarityConfig"),
    Fruits        = GetSafeModule(replicated:FindFirstChild("FruitPowerSystem"), "FruitPowerConfig") or {Powers={}},
    DungeonMerchant=GetSafeModule(replicated:FindFirstChild("Modules"), "DungeonMerchantConfig"),
    InfiniteTowerMerchant=GetSafeModule(replicated:FindFirstChild("Modules"), "InfiniteTowerMerchantConfig"),
    BossRushMerchant=GetSafeModule(replicated:FindFirstChild("Modules"), "BossRushMerchantConfig"),
}

Tables.GemStat  = (Modules.Stats and Modules.Stats.StatKeys) or {}
Tables.GemRank  = (Modules.Stats and Modules.Stats.RankOrder) or {}

local RarityWeight = {Secret=1,Mythical=2,Legendary=3,Epic=4,Rare=5,Uncommon=6,Common=7}

-- Populate boss/summon lists
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
    for _, data in pairs(Modules.SummonConfig.Bosses) do
        table.insert(Tables.SummonList, data.displayName)
        SummonMap[data.displayName] = data.bossId
    end
    table.sort(Tables.SummonList)
end

for bossName, _ in pairs(Modules.BossConfig.Bosses or {}) do
    table.insert(Tables.AllBossList, bossName:gsub("Boss$",""))
end
table.sort(Tables.AllBossList)

for name,_ in pairs(Modules.Trait.Traits or {}) do table.insert(Tables.TraitList, name) end
table.sort(Tables.TraitList, function(a,b)
    local ra = (Modules.Trait.Traits[a] or {}).Rarity
    local rb = (Modules.Trait.Traits[b] or {}).Rarity
    if ra ~= rb then return (RarityWeight[ra] or 99) < (RarityWeight[rb] or 99) end
    return a < b
end)

for name,_ in pairs(Modules.Race.Races or {}) do table.insert(Tables.RaceList, name) end
table.sort(Tables.RaceList)

for name,_ in pairs(Modules.Clan.Clans or {}) do table.insert(Tables.ClanList, name) end
table.sort(Tables.ClanList)

if Modules.SpecPassive and Modules.SpecPassive.Passives then
    for name,_ in pairs(Modules.SpecPassive.Passives) do table.insert(Tables.SpecPassive, name) end
    table.sort(Tables.SpecPassive)
end

for k,_ in pairs(Modules.Quests.Questlines or {}) do table.insert(Tables.QuestlineList, k) end
table.sort(Tables.QuestlineList)

Tables.MerchantList = {}
for name,_ in pairs(Modules.Merchant.ITEMS or {}) do table.insert(Tables.MerchantList, name) end

Tables.DungeonMerchantList = {}
if Modules.DungeonMerchant and Modules.DungeonMerchant.ITEMS then
    for name,_ in pairs(Modules.DungeonMerchant.ITEMS) do table.insert(Tables.DungeonMerchantList, name) end
    table.sort(Tables.DungeonMerchantList)
end

Tables.InfiniteTowerMerchantList = {}
if Modules.InfiniteTowerMerchant and Modules.InfiniteTowerMerchant.ITEMS then
    for name,_ in pairs(Modules.InfiniteTowerMerchant.ITEMS) do table.insert(Tables.InfiniteTowerMerchantList, name) end
    table.sort(Tables.InfiniteTowerMerchantList)
end

Tables.BossRushMerchantList = {}
if Modules.BossRushMerchant and Modules.BossRushMerchant.ITEMS then
    for name,_ in pairs(Modules.BossRushMerchant.ITEMS) do table.insert(Tables.BossRushMerchantList, name) end
    table.sort(Tables.BossRushMerchantList)
end

if Modules.Title and Modules.Title.GetSortedTitleIds then
    Tables.TitleList = Modules.Title:GetSortedTitleIds()
end

-- Island crystals for nearest-island detection
local PATH = {
    Mobs        = workspace:WaitForChild("NPCs"),
    InteractNPCs= workspace:WaitForChild("ServiceNPCs"),
}

local IslandCrystals = {
    ["Starter"]       = workspace:FindFirstChild("StarterIsland")       and workspace.StarterIsland:FindFirstChild("SpawnPointCrystal_Starter"),
    ["Jungle"]        = workspace:FindFirstChild("JungleIsland")        and workspace.JungleIsland:FindFirstChild("SpawnPointCrystal_Jungle"),
    ["Desert"]        = workspace:FindFirstChild("DesertIsland")        and workspace.DesertIsland:FindFirstChild("SpawnPointCrystal_Desert"),
    ["Snow"]          = workspace:FindFirstChild("SnowIsland")          and workspace.SnowIsland:FindFirstChild("SpawnPointCrystal_Snow"),
    ["Sailor"]        = workspace:FindFirstChild("SailorIsland")        and workspace.SailorIsland:FindFirstChild("SpawnPointCrystal_Sailor"),
    ["Shibuya"]       = workspace:FindFirstChild("ShibuyaStation")      and workspace.ShibuyaStation:FindFirstChild("SpawnPointCrystal_Shibuya"),
    ["HuecoMundo"]    = workspace:FindFirstChild("HuecoMundo")          and workspace.HuecoMundo:FindFirstChild("SpawnPointCrystal_HuecoMundo"),
    ["Boss"]          = workspace:FindFirstChild("BossIsland")          and workspace.BossIsland:FindFirstChild("SpawnPointCrystal_Boss"),
    ["Dungeon"]       = workspace:FindFirstChild("Main Temple")         and workspace["Main Temple"]:FindFirstChild("SpawnPointCrystal_Dungeon"),
    ["Shinjuku"]      = workspace:FindFirstChild("ShinjukuIsland")      and workspace.ShinjukuIsland:FindFirstChild("SpawnPointCrystal_Shinjuku"),
    ["Slime"]         = workspace:FindFirstChild("SlimeIsland")         and workspace.SlimeIsland:FindFirstChild("SpawnPointCrystal_Slime"),
    ["Academy"]       = workspace:FindFirstChild("AcademyIsland")       and workspace.AcademyIsland:FindFirstChild("SpawnPointCrystal_Academy"),
    ["Judgement"]     = workspace:FindFirstChild("JudgementIsland")     and workspace.JudgementIsland:FindFirstChild("SpawnPointCrystal_Judgement"),
    ["TowerIsland"]   = workspace:FindFirstChild("TowerIsland")         and workspace.TowerIsland:FindFirstChild("SpawnPointCrystal_Tower"),
}

local function GetNearestIsland(targetPos, npcName)
    if npcName and Shared.BossTIMap[npcName] then return Shared.BossTIMap[npcName] end
    local nearestName, minDist = "Starter", math.huge
    for islandName, crystal in pairs(IslandCrystals) do
        if crystal then
            local dist = (targetPos - crystal:GetPivot().Position).Magnitude
            if dist < minDist then minDist = dist; nearestName = islandName end
        end
    end
    return nearestName
end

local function UpdateNPCLists()
    local current = {}
    for _, name in pairs(Tables.MobList) do current[name] = true end
    for _, v in pairs(PATH.Mobs:GetChildren()) do
        local cleanName = v.Name:gsub("%d+$","")
        local isSpecial = table.find(Tables.MiniBossList, cleanName)
        if (isSpecial or not cleanName:find("Boss")) and not current[cleanName] then
            table.insert(Tables.MobList, cleanName)
            current[cleanName] = true
            local npcPos = v:GetPivot().Position
            local closest, minShot = "Unknown", math.huge
            for islandName, crystal in pairs(IslandCrystals) do
                if crystal then
                    local dist = (npcPos - crystal:GetPivot().Position).Magnitude
                    if dist < minShot then minShot = dist; closest = islandName end
                end
            end
            Tables.MobToIsland[cleanName] = closest
        end
    end
end

local function GetToolTypeFromModule(toolName)
    local function Clean(s) return s:gsub("%s+",""):lower() end
    local ct = Clean(toolName)
    for n, t in pairs(Tables.ManualWeaponClass) do if Clean(n)==ct then return t end end
    if Modules.WeaponClass and Modules.WeaponClass.Tools then
        for n, t in pairs(Modules.WeaponClass.Tools) do if Clean(n)==ct then return t end end
    end
    if toolName:lower():find("fruit") then return "Power" end
    return "Melee"
end

local function GetWeaponsByType(enabledTypes)
    local available = {}
    local ch = GetCharacter()
    local containers = {player.Backpack}
    if ch then table.insert(containers, ch) end
    for _, container in ipairs(containers) do
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local toolType = GetToolTypeFromModule(tool.Name)
                if enabledTypes and enabledTypes[toolType] then
                    if not table.find(available, tool.Name) then
                        table.insert(available, tool.Name)
                    end
                end
            end
        end
    end
    return available
end

-- Mob cluster finder
local function IsValidTarget(npc)
    if not npc or not npc.Parent then return false end
    local hum = npc:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function GetBestMobCluster(mobDict)
    local allMobs = {}
    if type(mobDict) ~= "table" then return nil end
    for _, npc in pairs(PATH.Mobs:GetChildren()) do
        if npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid") then
            local cleanName = npc.Name:gsub("%d+$","")
            if mobDict[cleanName] and IsValidTarget(npc) then
                table.insert(allMobs, npc)
            end
        end
    end
    if #allMobs == 0 then return nil end
    local bestMob, maxNearby = allMobs[1], 0
    for _, mobA in ipairs(allMobs) do
        local nearby = 0
        local posA = mobA:GetPivot().Position
        for _, mobB in ipairs(allMobs) do
            if (posA - mobB:GetPivot().Position).Magnitude <= 35 then nearby=nearby+1 end
        end
        if nearby > maxNearby then maxNearby=nearby; bestMob=mobA end
    end
    return bestMob, maxNearby
end

local function IsStrictBossMatch(npcName, targetDisplayName)
    local n = npcName:lower():gsub("%s+","")
    local t = targetDisplayName:lower():gsub("%s+","")
    if n:find("true") and not t:find("true") then return false end
    if t:find("strongest") then
        local era = t:find("history") and "history" or "today"
        return n:find("strongest") and n:find(era)
    end
    return n:find(t)
end

local function FireBossRemote(bossName, diff)
    local lowerName = bossName:lower():gsub("%s+","")
    local function GetInternalSummonId(name)
        local cleanTarget = name:lower():gsub("%s+","")
        for displayName, internalId in pairs(SummonMap) do
            if displayName:lower():gsub("%s+","") == cleanTarget then return internalId end
        end
        return name:gsub("%s+","").."Boss"
    end
    pcall(function()
        if lowerName:find("rimuru") then
            Remotes.RimuruBoss:FireServer(diff)
        elseif lowerName:find("anos") then
            Remotes.AnosBoss:FireServer("Anos", diff)
        elseif lowerName:find("trueaizen") then
            if Remotes.TrueAizenBoss then Remotes.TrueAizenBoss:FireServer(diff) end
        elseif lowerName:find("strongest") then
            local arg = lowerName:find("history") and "StrongestHistory" or "StrongestToday"
            Remotes.JJKSummonBoss:FireServer(arg, diff)
        elseif lowerName:find("atomic") then
            Remotes.AtomicBoss:FireServer(diff)
        else
            Remotes.SummonBoss:FireServer(GetInternalSummonId(bossName), diff)
        end
    end)
end

-- Quest helpers
local function GetBestQuestNPC()
    local QuestModule = Modules.Quests
    local playerLevel = player.Data and player.Data.Level and player.Data.Level.Value or 0
    local bestNPC, highestLevel = "QuestNPC1", -1
    for npcId, questData in pairs(QuestModule.RepeatableQuests or {}) do
        local reqLevel = questData.recommendedLevel or 0
        if playerLevel >= reqLevel and reqLevel > highestLevel then
            highestLevel = reqLevel; bestNPC = npcId
        end
    end
    return bestNPC
end

local function EnsureQuestSettings()
    pcall(function()
        local settings = PGui.SettingsUI.MainFrame.Frame.Content.SettingsTabFrame
        local tog1 = settings:FindFirstChild("Toggle_EnableQuestRepeat",true)
        if tog1 and tog1.SettingsHolder.Off.Visible then
            Remotes.SettingsToggle:FireServer("EnableQuestRepeat", true); task.wait(0.3)
        end
        local tog2 = settings:FindFirstChild("Toggle_AutoQuestRepeat",true)
        if tog2 and tog2.SettingsHolder.Off.Visible then
            Remotes.SettingsToggle:FireServer("AutoQuestRepeat", true)
        end
    end)
end

-- Puzzle solver
local function UniversalPuzzleSolver(puzzleType)
    local moduleMap = {
        ["Dungeon"]  = replicated.Modules:FindFirstChild("DungeonConfig"),
        ["Slime"]    = replicated.Modules:FindFirstChild("SlimePuzzleConfig"),
        ["Demonite"] = replicated.Modules:FindFirstChild("DemoniteCoreQuestConfig"),
        ["Hogyoku"]  = replicated.Modules:FindFirstChild("HogyokuQuestConfig"),
    }
    local hogyokuIslands = {"Snow","Shibuya","HuecoMundo","Shinjuku","Slime","Judgement"}
    local targetModule = moduleMap[puzzleType]
    if not targetModule then return end
    local data = require(targetModule)
    local settings = data.PuzzleSettings or data.PieceSettings
    local piecesToCollect = data.Pieces or (settings and settings.IslandOrder)
    local pieceModelName  = (settings and settings.PieceModelName) or "DungeonPuzzlePiece"
    WindUI:Notify({ Title="Puzzle", Content="Starting "..puzzleType.." puzzle...", Duration=3, Icon="puzzle" })
    for i, islandOrPiece in ipairs(piecesToCollect) do
        local piece, tpTarget = nil, nil
        if puzzleType == "Demonite" then tpTarget = "Academy"
        elseif puzzleType == "Hogyoku" then tpTarget = hogyokuIslands[i]
        else
            tpTarget = islandOrPiece:gsub("Island",""):gsub("Station","")
            if islandOrPiece == "HuecoMundo" then tpTarget = "HuecoMundo" end
        end
        if tpTarget then Remotes.TP_Portal:FireServer(tpTarget); task.wait(2.5) end
        if puzzleType == "Demonite" or puzzleType == "Hogyoku" then
            piece = workspace:FindFirstChild(islandOrPiece, true)
        else
            local islandFolder = workspace:FindFirstChild(islandOrPiece)
            piece = islandFolder and islandFolder:FindFirstChild(pieceModelName, true) or workspace:FindFirstChild(pieceModelName, true)
        end
        if piece then
            HybridMove(piece:GetPivot() * CFrame.new(0,3,0))
            task.wait(0.5)
            local prompt = piece:FindFirstChildOfClass("ProximityPrompt")
                or piece:FindFirstChild("PuzzlePrompt",true)
                or piece:FindFirstChild("ProximityPrompt",true)
            if prompt and Support.Proximity then
                fireproximityprompt(prompt)
                WindUI:Notify({ Title="Puzzle", Content=string.format("Piece %d/%d collected", i, #piecesToCollect), Duration=2, Icon="check" })
                task.wait(1.5)
            end
        end
    end
    WindUI:Notify({ Title="Puzzle Complete", Content=puzzleType.." done!", Duration=3, Icon="party-popper" })
end

-- Anti AFK
local function DisableIdled()
    pcall(function()
        local cons = getconnections or get_signal_cons
        if cons then
            for _, v in pairs(cons(player.Idled)) do
                if v.Disable then v:Disable() elseif v.Disconnect then v:Disconnect() end
            end
        end
    end)
end

-- SafeTeleportToNPC
local function SafeTeleportToNPC(targetName, customMap)
    local character = GetCharacter()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local actualName = (customMap and customMap[targetName]) or targetName
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
    end
end

-- FPS Boost
local function ApplyFPSBoost()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
        Lighting.ShadowSoftness = 0
        if Terrain then
            Terrain.WaterWaveSize = 0; Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0; Terrain.WaterTransparency = 0
        end
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("PostProcessEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") then
                v.Enabled = false
            end
        end
        task.spawn(function()
            for _, v in pairs(workspace:GetDescendants()) do
                pcall(function()
                    if v:IsA("BasePart") then
                        v.Material = Enum.Material.SmoothPlastic; v.Reflectance = 0; v.CastShadow = false
                    elseif v:IsA("Decal") or v:IsA("Texture") then
                        v.Transparency = 1
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                        v.Enabled = false
                    end
                end)
            end
        end)
    end)
end

-- Pity helper
local function GetCurrentPity()
    local ok, pityLabel = pcall(function()
        return PGui.BossUI.MainFrame.BossHPBar.Pity
    end)
    if ok and pityLabel then
        local current, max = pityLabel.Text:match("Pity: (%d+)/(%d+)")
        return tonumber(current) or 0, tonumber(max) or 25
    end
    return 0, 25
end

-- Auto upgrade loop (enchant/blessing)
local function AutoUpgradeLoop(mode)
    local sourceTable = (mode=="Enchant") and Tables.OwnedAccessory or Tables.OwnedWeapon
    local remote      = (mode=="Enchant") and Remotes.Enchant or Remotes.Blessing
    while _G["Auto"..mode] do
        local workDone = false
        for _, itemName in ipairs(sourceTable) do
            if not Shared.UpBlacklist[itemName] then
                workDone = true
                pcall(function() remote:FireServer(itemName) end)
                task.wait(1.5); break
            end
        end
        if not workDone then _G["Auto"..mode] = false; break end
        task.wait(0.1)
    end
end

-- ============================================================
--  REMOTE LISTENERS
-- ============================================================
if Remotes.UpInventory then
    Remotes.UpInventory.OnClientEvent:Connect(function(category, data)
        Shared.InventorySynced = true
        if category == "Items" then
            Shared.Cached.Inv = data or {}
            table.clear(Tables.OwnedItem)
            for _, item in pairs(data) do
                if not table.find(Tables.OwnedItem, item.name) then
                    table.insert(Tables.OwnedItem, item.name)
                end
            end
            table.sort(Tables.OwnedItem)
        elseif category == "Accessories" then
            table.clear(Shared.Cached.Accessories)
            table.clear(Tables.OwnedAccessory)
            local processed = {}
            for _, item in ipairs(data) do
                Shared.Cached.Accessories[item.name] = item.quantity
                if (item.enchantLevel or 0) < 10 and not processed[item.name] then
                    table.insert(Tables.OwnedAccessory, item.name)
                    processed[item.name] = true
                end
            end
            table.sort(Tables.OwnedAccessory)
        elseif category == "Sword" or category == "Melee" then
            Shared.Cached.RawWeapCache[category] = data or {}
            table.clear(Tables.OwnedWeapon)
            local processed = {}
            for _, cat in pairs({"Sword","Melee"}) do
                for _, item in ipairs(Shared.Cached.RawWeapCache[cat]) do
                    if (item.blessingLevel or 0) < 10 and not processed[item.name] then
                        table.insert(Tables.OwnedWeapon, item.name)
                        processed[item.name] = true
                    end
                end
            end
            table.sort(Tables.OwnedWeapon)
            table.clear(Tables.AllOwnedWeapons)
            local allProcessed = {}
            for _, cat in pairs({"Sword","Melee"}) do
                for _, item in ipairs(Shared.Cached.RawWeapCache[cat]) do
                    if not allProcessed[item.name] then
                        table.insert(Tables.AllOwnedWeapons, item.name)
                        allProcessed[item.name] = true
                    end
                end
            end
            table.sort(Tables.AllOwnedWeapons)
        end
    end)
end

if Remotes.HakiStateUpdate then
    Remotes.HakiStateUpdate.OnClientEvent:Connect(function(arg1, arg2)
        if arg1 == false then Shared.ArmHaki = false; return end
        if arg1 == player then Shared.ArmHaki = arg2 end
    end)
end

if Remotes.TitleSync then
    Remotes.TitleSync.OnClientEvent:Connect(function(data)
        if data and data.unlocked then Tables.UnlockedTitle = data.unlocked end
    end)
end

if Remotes.ArtifactSync then
    Remotes.ArtifactSync.OnClientEvent:Connect(function(data)
        Shared.ArtifactSession.Inventory = data.Inventory
        Shared.ArtifactSession.Dust = data.Dust
    end)
end

if Remotes.SpecPassiveUpdate then
    Remotes.SpecPassiveUpdate.OnClientEvent:Connect(function(data)
        if type(Shared.Passives) ~= "table" then Shared.Passives = {} end
        if data and data.Passives then
            for wName, info in pairs(data.Passives) do
                Shared.Passives[wName] = (type(info)=="table") and info or {Name=tostring(info),RolledBuffs={}}
            end
        end
    end)
end

if Remotes.UpStatReroll then
    Remotes.UpStatReroll.OnClientEvent:Connect(function(data)
        if data and data.Stats then Shared.GemStats = data.Stats end
    end)
end

if Remotes.UpPlayerStats then
    Remotes.UpPlayerStats.OnClientEvent:Connect(function(data)
        if data and data.Stats then Shared.Stats = data.Stats end
    end)
end

if Remotes.SkillTreeUpdate then
    Remotes.SkillTreeUpdate.OnClientEvent:Connect(function(data)
        if data then
            Shared.SkillTree.Nodes       = data.Nodes or {}
            Shared.SkillTree.SkillPoints = data.SkillPoints or 0
        end
    end)
end

if Remotes.TradeUpdated then
    Remotes.TradeUpdated.OnClientEvent:Connect(function(data) Shared.TradeState = data end)
end

if Remotes.StockUpdate then
    Remotes.StockUpdate.OnClientEvent:Connect(function(itemName, stockLeft)
        Shared.CurrentStock[itemName] = tonumber(stockLeft)
    end)
end

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

PATH.Mobs.ChildRemoved:Connect(function(child)
    if child:IsA("Model") and child.Name:lower():find("boss") then
        table.clear(Shared.AltDamage); Shared.AltActive = false
    end
end)

-- ============================================================
--  BACKGROUND LOOPS (non-UI)
-- ============================================================

-- Auto Haki
task.spawn(function()
    while true do
        task.wait(0.5)
        if _G.ObserHaki and not CheckObsHaki() then
            pcall(function() Remotes.ObserHaki:FireServer("Toggle") end)
        end
        if _G.ArmHakiAuto and not CheckArmHaki() then
            pcall(function() Remotes.ArmHaki:FireServer("Toggle") end)
            task.wait(0.5)
        end
        if _G.ConquerorHakiAuto then
            pcall(function() Remotes.ConquerorHaki:FireServer("Activate") end)
        end
    end
end)

-- Auto Attack (nearest mob)
task.spawn(function()
    while task.wait(0.1) do
        if _G.AutoAttack then
            pcall(function()
                local target = GetNearestMob()
                if target then
                    replicated.CombatSystem.Remotes.RequestHit:FireServer(target.Position)
                end
            end)
        end
    end
end)

-- Auto Haki quest (Thief kills)
task.spawn(function()
    while task.wait(0.1) do
        if _G.AutoHaki then
            local cframes = GetConnectionEnemies("Thief")
            for _, cf in ipairs(cframes) do
                pcall(function()
                    replicated.CombatSystem.Remotes.RequestHit:FireServer(cf.Position)
                end)
            end
        end
    end
end)

-- Farm Best Mob loop
task.spawn(function()
    while task.wait(0.1) do
        if _G.FarmLevel then FarmBestMob() end
    end
end)

-- Farm Selected Mob loop
task.spawn(function()
    while task.wait(0.1) do
        if _G.FarmSelectedMob and _G.SelectedMobType then
            local mobCFrames = GetConnectionEnemies(_G.SelectedMobType)
            for _, cf in ipairs(mobCFrames) do
                pcall(function()
                    replicated.CombatSystem.Remotes.RequestHit:FireServer(cf.Position)
                end)
            end
        end
    end
end)

-- Auto Stats loops
task.spawn(function()
    while task.wait(0.5) do
        if _G.AutoStatsDefense then
            pcall(function() replicated.RemoteEvents.AllocateStat:FireServer("Defense", 100) end)
        end
        if _G.AutoStatsPower then
            pcall(function() replicated.RemoteEvents.AllocateStat:FireServer("Power", 100) end)
        end
        if _G.AutoStatsFruit then
            pcall(function() replicated.RemoteEvents.AllocateStat:FireServer("Fruit", 100) end)
        end
    end
end)

-- Auto Skills (ability 1 & 2)
task.spawn(function()
    while task.wait(1) do
        if _G.AutoSkill1 then
            pcall(function() replicated.AbilitySystem.Remotes.RequestAbility:FireServer(1) end)
        end
        if _G.AutoSkill2 then
            pcall(function() replicated.AbilitySystem.Remotes.RequestAbility:FireServer(2) end)
        end
    end
end)

-- Anti AFK
task.spawn(function()
    DisableIdled()
    while true do
        task.wait(60)
        pcall(function()
            vu:CaptureController()
            vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            task.wait(0.2)
            vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end)
    end
end)

-- Kill Aura loop
task.spawn(function()
    while task.wait(0.12) do
        if _G.KillAura then
            local target = GetNearestAuraTarget(_G.KillAuraRange or 200)
            if target then
                pcall(function() Remotes.M1:FireServer(target:GetPivot().Position) end)
            end
        end
    end
end)

-- Player ESP loop
task.spawn(function()
    while task.wait(0.5) do
        if _G.SailorESP then
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    if not other.Character:FindFirstChild("SailorESP") then
                        local hl                = Instance.new("Highlight")
                        hl.Name                 = "SailorESP"
                        hl.FillColor            = Color3.fromRGB(255,50,50)
                        hl.FillTransparency     = 0.5
                        hl.OutlineColor         = Color3.fromRGB(255,255,255)
                        hl.DepthMode            = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Adornee              = other.Character
                        hl.Parent               = other.Character
                    end
                end
            end
        else
            for _, other in ipairs(Players:GetPlayers()) do
                if other.Character then
                    local hl = other.Character:FindFirstChild("SailorESP")
                    if hl then hl:Destroy() end
                end
            end
        end
    end
end)

-- Noclip loop
task.spawn(function()
    while RunService.Stepped:Wait() do
        if _G.SailorNoclip then
            local ch = player.Character
            if ch then
                for _, part in ipairs(ch:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end
    end
end)

-- CharacterAdded: auto equip tool
player.CharacterAdded:Connect(function(ch)
    if _G.AutoEquipTool and _G.SelectedAutoEquipTool then
        task.wait(0.1)
        local tool = player.Backpack:FindFirstChild(_G.SelectedAutoEquipTool)
        if tool then ch:WaitForChild("Humanoid"):EquipTool(tool) end
    end
end)

-- ============================================================
--  WINDUI WINDOW
-- ============================================================
Window = WindUI:CreateWindow({
    Title      = "CattStar Sailor-Piece",
    Icon       = "rbxassetid://84971028134779",
    Author     = "Xeno Supported | WindUI",
    Folder     = "CattStar_SailorPiece",
    Size       = UDim2.fromOffset(660, 600),
    MinSize    = Vector2.new(580, 480),
    MaxSize    = Vector2.new(950, 800),
    Transparent= false,
    Theme      = "Dark",
    Resizable  = true,
    SideBarWidth=195,
    ScrollBarEnabled=true,
    User = {
        Enabled  = true,
        Anonymous= false,
        Callback = function()
            WindUI:Notify({
                Title   = "Player Info",
                Content = "Username: "..playerName.."\nDisplay: "..playerDisplayName,
                Duration= 3,
                Icon    = "user",
            })
        end,
    },
})

Window:EditOpenButton({
    Title       = "CattStar Sailor Piece",
    Icon        = "monitor",
    CornerRadius= UDim.new(0,16),
    StrokeThickness=2,
    Color = ColorSequence.new(Color3.fromHex("FF0F7B"), Color3.fromHex("F89B29")),
    OnlyMobile  = false,
    Enabled     = true,
    Draggable   = true,
})

Window:SetToggleKey(Enum.KeyCode.RightShift)

-- ============================================================
--  TABS
-- ============================================================
local Tabs = {
    Player    = Window:Tab({ Title="Player",    Icon="user" }),
    Main      = Window:Tab({ Title="Main Farm", Icon="house" }),
    Boss      = Window:Tab({ Title="Boss Farm", Icon="skull" }),
    Dungeon   = Window:Tab({ Title="Dungeon",   Icon="flame" }),
    Automation= Window:Tab({ Title="Automation",Icon="repeat-2" }),
    Artifact  = Window:Tab({ Title="Artifact",  Icon="martini" }),
    World     = Window:Tab({ Title="World",     Icon="compass" }),
    Visuals   = Window:Tab({ Title="Visuals",   Icon="eye" }),
    Settings  = Window:Tab({ Title="Settings",  Icon="settings" }),
}

-- ============================================================
--  PLAYER TAB
-- ============================================================
local PlayerSection = Tabs.Player:Section({ Title="Character Modifiers", Box=true, Opened=true })

PlayerSection:Slider({
    Title="Walk Speed", Desc="Increase movement speed",
    Step=1, Value={Min=16, Max=250, Default=16},
    Callback=function(v)
        local ch = player.Character
        if ch and ch:FindFirstChild("Humanoid") then ch.Humanoid.WalkSpeed = v end
    end,
})

PlayerSection:Slider({
    Title="Jump Power", Desc="Increase jump height",
    Step=1, Value={Min=50, Max=500, Default=50},
    Callback=function(v)
        local ch = player.Character
        if ch and ch:FindFirstChild("Humanoid") then
            ch.Humanoid.UseJumpPower = true
            ch.Humanoid.JumpPower   = v
        end
    end,
})

PlayerSection:Slider({
    Title="Gravity", Desc="Change world gravity",
    Step=1, Value={Min=0, Max=500, Default=196},
    Callback=function(v) workspace.Gravity = v end,
})

PlayerSection:Slider({
    Title="Hip Height", Desc="Adjust hip height",
    Step=1, Value={Min=0, Max=10, Default=2},
    Callback=function(v)
        local ch = player.Character
        if ch and ch:FindFirstChild("Humanoid") then ch.Humanoid.HipHeight = v end
    end,
})

PlayerSection:Toggle({
    Title="Noclip", Desc="Walk through walls", Icon="door-open",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.SailorNoclip = state end,
})

PlayerSection:Toggle({
    Title="Anti AFK", Desc="Prevent idle kick", Icon="clock",
    Type="Checkbox", Value=true,
    Callback=function(state) _G.AntiAFK = state end,
})

PlayerSection:Toggle({
    Title="Kill Aura", Desc="Attack nearby mobs automatically", Icon="crosshair",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.KillAura = state end,
})

PlayerSection:Slider({
    Title="Kill Aura Range", Desc="Range for kill aura",
    Step=5, Value={Min=10, Max=200, Default=100},
    Callback=function(v) _G.KillAuraRange = v end,
})

-- Auto Stats Section
local StatsSection = Tabs.Player:Section({ Title="Auto Stats", Box=true, Opened=true })

StatsSection:Toggle({
    Title="Auto Stats Defense", Desc="Auto allocate to Defense", Icon="shield",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.AutoStatsDefense = state end,
})

StatsSection:Toggle({
    Title="Auto Stats Power", Desc="Auto allocate to Power", Icon="zap",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.AutoStatsPower = state end,
})

StatsSection:Toggle({
    Title="Auto Stats Fruit", Desc="Auto allocate to Fruit", Icon="apple",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.AutoStatsFruit = state end,
})

do
    local statOptions = {"Melee","Defense","Sword","Power"}
    StatsSection:Dropdown({
        Title="Auto Allocate Stats", Desc="Select stats to auto-allocate",
        Values=statOptions, Value=statOptions[1], Multi=true,
        Callback=function(selected)
            _G.AutoAllocateStats = selected
        end,
    })
    StatsSection:Toggle({
        Title="Auto Allocate (Advanced)", Desc="Distributes stat points evenly", Icon="bar-chart",
        Type="Checkbox", Value=false,
        Callback=function(state)
            _G.AutoAllocateAdvanced = state
            if state then
                task.spawn(function()
                    while _G.AutoAllocateAdvanced do
                        local pointsPath = player:FindFirstChild("Data") and player.Data:FindFirstChild("StatPoints")
                        if pointsPath and pointsPath.Value > 0 then
                            local selected = _G.AutoAllocateStats or {}
                            local active = {}
                            for statName, enabled in pairs(selected) do
                                if enabled then table.insert(active, statName) end
                            end
                            if #active > 0 then
                                local pts = math.floor(pointsPath.Value / #active)
                                if pts > 0 then
                                    for _, stat in ipairs(active) do
                                        pcall(function() Remotes.AddStat:FireServer(stat, pts) end)
                                    end
                                end
                            end
                        end
                        task.wait(1)
                    end
                end)
            end
        end,
    })
end

-- Auto Equip Section
local EquipSection = Tabs.Player:Section({ Title="Auto Equip Tool", Box=true, Opened=true })

local toolDropdown = EquipSection:Dropdown({
    Title="Select Tool", Desc="Choose tool to auto equip",
    Values=GetBackpackItems(), Value=GetBackpackItems()[1] or "None",
    Multi=false,
    Callback=function(selected) _G.SelectedAutoEquipTool = selected end,
})

EquipSection:Button({
    Title="Refresh Tool List", Desc="Reload from backpack",
    Callback=function()
        local items = GetBackpackItems()
        toolDropdown:SetValues(items)
        WindUI:Notify({ Title="Refreshed", Content="Tool list updated", Duration=2, Icon="refresh-cw" })
    end,
})

EquipSection:Toggle({
    Title="Auto Equip on Respawn", Desc="Equips selected tool on respawn", Icon="sword",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.AutoEquipTool = state end,
})

-- Auto Use Abilities Section
local FruitSection = Tabs.Player:Section({ Title="Auto Use Abilities", Box=true, Opened=true })

FruitSection:Toggle({
    Title="Auto Use Skill 1", Desc="Auto use first ability", Icon="sparkles",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.AutoSkill1 = state end,
})

FruitSection:Toggle({
    Title="Auto Use Skill 2", Desc="Auto use second ability", Icon="flame",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.AutoSkill2 = state end,
})

-- Haki Section
local HakiSection = Tabs.Player:Section({ Title="Haki", Box=true, Opened=true })

HakiSection:Toggle({
    Title="Auto Armament Haki", Desc="Keeps Armament Haki active", Icon="shield",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.ArmHakiAuto = state end,
})

HakiSection:Toggle({
    Title="Auto Observation Haki", Desc="Keeps Observation Haki active", Icon="eye",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.ObserHaki = state end,
})

HakiSection:Toggle({
    Title="Auto Conqueror Haki", Desc="Keeps Conqueror Haki active", Icon="crown",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.ConquerorHakiAuto = state end,
})

-- ============================================================
--  MAIN FARM TAB
-- ============================================================
local ChestSection = Tabs.Main:Section({ Title="Chest Farm", Box=true, Opened=true })

local chestRarities = {"Common Chest","Rare Chest","Epic Chest","Legendary Chest","Mythic Chest"}

ChestSection:Dropdown({
    Title="Select Rarity", Values=chestRarities, Value=chestRarities[1], Multi=false,
    Callback=function(s) _G.SelectedChestRarity = s end,
})

ChestSection:Slider({
    Title="No. of Chests", Desc="How many chests to open",
    Step=1, Value={Min=1, Max=100, Default=2},
    Callback=function(v) _G.SelectedChestNumber = v end,
})

ChestSection:Button({
    Title="Open Chest", Desc="",
    Callback=function()
        local ok = pcall(function()
            replicated.Remotes.UseItem:FireServer("Use", _G.SelectedChestRarity, _G.SelectedChestNumber, false)
        end)
        if not ok then
            WindUI:Notify({ Title="Error", Content="Failed to open chest!", Duration=3, Icon="alert-triangle" })
        end
    end,
})

-- Auto Open Chest Toggle
ChestSection:Toggle({
    Title="Auto Open Chests", Desc="Continuously open selected chests", Icon="box",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoOpenChest = state
        if state then
            task.spawn(function()
                while _G.AutoOpenChest do
                    pcall(function()
                        replicated.Remotes.UseItem:FireServer("Use", _G.SelectedChestRarity, 10000, false)
                    end)
                    task.wait(2)
                end
            end)
        end
    end,
})

-- Haki Unlock Section
local HakiUnlockSection = Tabs.Main:Section({ Title="Auto Unlock Haki", Box=true, Opened=true })

HakiUnlockSection:Toggle({
    Title="Unlock Haki", Desc="Takes quest and kills 100 Bandits", Icon="sword",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoHaki = state
        if state then
            pcall(function() replicated.RemoteEvents.QuestAbandon:FireServer("repeatable") end)
            pcall(function() replicated.RemoteEvents.QuestAccept:FireServer("HakiQuestNPC") end)
            pcall(function() replicated.Remotes.TeleportToPortal:FireServer("Starter") end)
        end
    end,
})

-- Farm Mobs Section
local FarmingLevel = Tabs.Main:Section({ Title="Farm Mobs", Box=true, Opened=true })

FarmingLevel:Toggle({
    Title="Kill Nearest Mobs", Desc="Inf-M1 on nearest mobs", Icon="sword",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.AutoAttack = state end,
})

FarmingLevel:Toggle({
    Title="Auto Farm Level", Desc="Automatically farms best mob for your level", Icon="swords",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.FarmLevel = state
        if state then
            local level = player.Data and player.Data.Level and player.Data.Level.Value or 0
            local mob   = GetBestMob(level)
            if mob then
                TeleportToMobIsland(mob)
                task.wait(2)
                pcall(function() replicated.RemoteEvents.QuestAccept:FireServer(mob.questNPC) end)
            end
        end
    end,
})

do
    local MobNames = {}
    for _, mob in ipairs(mobs) do table.insert(MobNames, mob.npcType) end

    FarmingLevel:Dropdown({
        Title="Select Mob", Desc="Choose which mob to farm",
        Values=MobNames, Value=MobNames[1], Multi=false,
        Callback=function(s) _G.SelectedMobType = s end,
    })
end

FarmingLevel:Toggle({
    Title="Auto Farm Selected Mob", Desc="Farms selected mob type", Icon="swords",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.FarmSelectedMob = state end,
})

-- Advanced Mob Farm
local AdvFarmSection = Tabs.Main:Section({ Title="Advanced Mob Farm", Box=true, Opened=false })

AdvFarmSection:Dropdown({
    Title="Select Mob(s)", Desc="Multi-select mobs",
    Values=Tables.MobList, Value=nil, Multi=true,
    Callback=function(s) _G.SelectedMobs = s end,
})

AdvFarmSection:Button({ Title="Refresh Mob List", Callback=function() UpdateNPCLists() end })

AdvFarmSection:Toggle({
    Title="Auto Farm Selected Mob(s)", Icon="target",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AdvFarmActive = state
        if state then
            task.spawn(function()
                while _G.AdvFarmActive do
                    local selected = _G.SelectedMobs or {}
                    for mobName, enabled in pairs(selected) do
                        if enabled then
                            local target, _ = GetBestMobCluster({[mobName]=true})
                            if target then
                                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                                if root then
                                    root.CFrame = target:GetPivot() * CFrame.new(0,0,10)
                                end
                                pcall(function() Remotes.M1:FireServer(target:GetPivot().Position) end)
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

AdvFarmSection:Toggle({
    Title="Auto Farm All Mobs", Desc="Rotates through all mobs", Icon="swords",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoFarmAllMobs = state
        if state then
            task.spawn(function()
                local idx = 1
                while _G.AutoFarmAllMobs do
                    if #Tables.MobList == 0 then task.wait(1); continue end
                    if idx > #Tables.MobList then idx = 1 end
                    local mobName = Tables.MobList[idx]
                    local target, _ = GetBestMobCluster({[mobName]=true})
                    if target then
                        local island = GetNearestIsland(target:GetPivot().Position, target.Name)
                        if island ~= Shared.Island then
                            Remotes.TP_Portal:FireServer(island)
                            Shared.Island = island
                            task.wait(2)
                        end
                        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        if root then root.CFrame = target:GetPivot() * CFrame.new(0,0,10) end
                        pcall(function() Remotes.M1:FireServer(target:GetPivot().Position) end)
                    else
                        idx = idx + 1
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

-- ============================================================
--  BOSS FARM TAB
-- ============================================================
local SlimeSection = Tabs.Boss:Section({ Title="Slime Pieces", Box=true, Opened=true })

SlimeSection:Toggle({
    Title="Auto Unlock All Slime Pieces", Desc="Visits all islands and collects pieces", Icon="puzzle",
    Type="Checkbox", Value=false,
    Callback=function(v)
        if not v then return end
        task.spawn(function()
            local islands = {
                {portal="Slime", npc=true},
                {portal="Desert",   piece="DesertIsland.SlimePuzzlePiece"},
                {portal="Snow",     piece="SnowIsland.SlimePuzzlePiece"},
                {portal="Starter",  piece="StarterIsland.SlimePuzzlePiece", offset=CFrame.new(0,2,0)},
                {portal="Jungle",   piece="JungleIsland.SlimePuzzlePiece"},
                {portal="Shibuya",  piece="ShibuyaStation.SlimePuzzlePiece"},
                {portal="HollowIsland", piece="HollowIsland.SlimePuzzlePiece"},
                {portal="Shinjuku", piece="ShinjukuIsland.SlimePuzzlePiece"},
            }
            replicated.Remotes.TeleportToPortal:FireServer("Slime")
            WindUI:Notify({ Title="Slime Pieces", Content="Going to SlimeNPC", Duration=2, Icon="map" })
            task.wait(1.5)
            Tween2(workspace.ServiceNPCs.SlimeCraftNPC.HumanoidRootPart.CFrame)
            task.wait(0.1)
            vim1:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.5)
            vim1:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            task.wait(1)
            for i = 2, #islands do
                local entry = islands[i]
                replicated.Remotes.TeleportToPortal:FireServer(entry.portal)
                WindUI:Notify({ Title="Slime Pieces", Content="Going to "..entry.portal, Duration=2, Icon="map" })
                task.wait(2.5)
                local parts = entry.piece:split(".")
                local obj = workspace
                for _, p in ipairs(parts) do obj = obj:FindFirstChild(p) or obj end
                if obj and obj ~= workspace then
                    local cf = obj.CFrame
                    if entry.offset then cf = cf * entry.offset end
                    Tween2(cf)
                    task.wait(0.5)
                    vim1:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.5)
                    vim1:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    task.wait(1)
                end
            end
            WindUI:Notify({ Title="Done!", Content="All slime pieces collected!", Duration=3, Icon="check" })
        end)
    end,
})

local slimePieces = {
    {label="#1 Desert",    portal="Desert",       path="DesertIsland.SlimePuzzlePiece"},
    {label="#2 Snow",      portal="Snow",         path="SnowIsland.SlimePuzzlePiece"},
    {label="#3 Starter",   portal="Starter",      path="StarterIsland.SlimePuzzlePiece"},
    {label="#4 Jungle",    portal="Jungle",       path="JungleIsland.SlimePuzzlePiece"},
    {label="#5 Shibuya",   portal="Shibuya",      path="ShibuyaStation.SlimePuzzlePiece"},
    {label="#6 Hollow",    portal="HollowIsland", path="HollowIsland.SlimePuzzlePiece"},
    {label="#7 Shinjuku",  portal="Shinjuku",     path="ShinjukuIsland.SlimePuzzlePiece"},
}

for _, sp in ipairs(slimePieces) do
    SlimeSection:Button({
        Title="Teleport to Slime "..sp.label, Desc="",
        Callback=function()
            replicated.Remotes.TeleportToPortal:FireServer(sp.portal)
            WindUI:Notify({ Title="Teleporting", Content=sp.label, Duration=2, Icon="map" })
            task.wait(3)
            local parts = sp.path:split(".")
            local obj = workspace
            for _, p in ipairs(parts) do obj = obj:FindFirstChild(p) or obj end
            if obj and obj ~= workspace then
                Tween2(obj.CFrame)
                task.wait(0.5)
                vim1:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.7)
                vim1:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end
        end,
    })
end

-- Boss Farm Section
local BossFarmSection = Tabs.Boss:Section({ Title="Auto Farm Bosses", Box=true, Opened=true })

BossFarmSection:Dropdown({
    Title="Select Boss(es)", Desc="Pick bosses to farm",
    Values=Tables.BossList, Value=nil, Multi=true,
    Callback=function(s) _G.SelectedBosses = s end,
})

BossFarmSection:Toggle({
    Title="Auto Farm Selected Boss", Icon="skull",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.BossFarmActive = state
        if state then
            task.spawn(function()
                while _G.BossFarmActive do
                    local selected = _G.SelectedBosses or {}
                    for bossName, enabled in pairs(selected) do
                        if enabled then
                            local found = false
                            for _, npc in pairs(PATH.Mobs:GetChildren()) do
                                if IsStrictBossMatch(npc.Name, bossName) and IsValidTarget(npc) then
                                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                                    if root then root.CFrame = npc:GetPivot() * CFrame.new(0,0,10) end
                                    pcall(function() Remotes.M1:FireServer(npc:GetPivot().Position) end)
                                    found = true; break
                                end
                            end
                            if not found then
                                FireBossRemote(bossName, _G.BossDiff or "Normal")
                                task.wait(1)
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

BossFarmSection:Dropdown({
    Title="Difficulty", Values=Tables.DiffList, Value="Normal", Multi=false,
    Callback=function(s) _G.BossDiff = s end,
})

BossFarmSection:Dropdown({
    Title="Select Summon Boss", Values=Tables.SummonList, Value=nil, Multi=false, AllowNull=true,
    Callback=function(s) _G.SelectedSummon = s end,
})

BossFarmSection:Button({
    Title="Spawn Selected Boss", Desc="",
    Callback=function()
        if _G.SelectedSummon then
            FireBossRemote(_G.SelectedSummon, _G.BossDiff or "Normal")
            WindUI:Notify({ Title="Spawning", Content="Spawning ".._G.SelectedSummon, Duration=2, Icon="bone" })
        end
    end,
})

BossFarmSection:Toggle({
    Title="Auto Farm Summon Boss", Icon="bone",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoSummonFarm = state
        if state then
            task.spawn(function()
                while _G.AutoSummonFarm do
                    if _G.SelectedSummon then
                        local found = false
                        local workspaceName = SummonMap[_G.SelectedSummon] or (_G.SelectedSummon.."Boss")
                        for _, npc in pairs(PATH.Mobs:GetChildren()) do
                            if npc.Name:lower():find(workspaceName:lower()) and IsValidTarget(npc) then
                                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                                if root then root.CFrame = npc:GetPivot() * CFrame.new(0,0,10) end
                                pcall(function() Remotes.M1:FireServer(npc:GetPivot().Position) end)
                                found = true; break
                            end
                        end
                        if not found then
                            FireBossRemote(_G.SelectedSummon, _G.BossDiff or "Normal")
                            task.wait(1)
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

-- Pity Boss Section
local PitySection = Tabs.Boss:Section({ Title="Pity Boss Farm", Box=true, Opened=false })

PitySection:Dropdown({
    Title="Build Pity Boss", Values=Tables.AllBossList, Value=nil, Multi=true, AllowNull=true,
    Callback=function(s) _G.PityBuildBoss = s end,
})

PitySection:Dropdown({
    Title="Use Pity Boss", Values=Tables.AllBossList, Value=nil, Multi=false, AllowNull=true,
    Callback=function(s) _G.PityUseBoss = s end,
})

PitySection:Dropdown({
    Title="Pity Difficulty", Values=Tables.DiffList, Value="Normal", Multi=false,
    Callback=function(s) _G.PityDiff = s end,
})

PitySection:Toggle({
    Title="Auto Farm Pity Boss", Icon="skull",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.PityFarmActive = state
        if state then
            task.spawn(function()
                while _G.PityFarmActive do
                    local current, max = GetCurrentPity()
                    local isUseTurn = (current >= (max - 1))
                    if isUseTurn and _G.PityUseBoss then
                        local found = false
                        for _, npc in pairs(PATH.Mobs:GetChildren()) do
                            if IsStrictBossMatch(npc.Name, _G.PityUseBoss) and IsValidTarget(npc) then
                                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                                if root then root.CFrame = npc:GetPivot() * CFrame.new(0,0,10) end
                                pcall(function() Remotes.M1:FireServer(npc:GetPivot().Position) end)
                                found = true; break
                            end
                        end
                        if not found then FireBossRemote(_G.PityUseBoss, _G.PityDiff or "Normal"); task.wait(1) end
                    elseif _G.PityBuildBoss then
                        for bossName, enabled in pairs(_G.PityBuildBoss) do
                            if enabled then
                                local found = false
                                for _, npc in pairs(PATH.Mobs:GetChildren()) do
                                    if IsStrictBossMatch(npc.Name, bossName) and IsValidTarget(npc) then
                                        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                                        if root then root.CFrame = npc:GetPivot() * CFrame.new(0,0,10) end
                                        pcall(function() Remotes.M1:FireServer(npc:GetPivot().Position) end)
                                        found = true; break
                                    end
                                end
                                if not found then FireBossRemote(bossName, "Normal"); task.wait(1) end
                                break
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

-- ============================================================
--  DUNGEON TAB
-- ============================================================
local DungeonSection = Tabs.Dungeon:Section({ Title="Dungeon Unlock", Box=true, Opened=true })

DungeonSection:Toggle({
    Title="Auto Unlock Dungeon", Desc="Collects all dungeon puzzle pieces", Icon="flame",
    Type="Checkbox", Value=false,
    Callback=function(v)
        if not v then return end
        task.spawn(function()
            _G.UnlockDungeon = true
            local dungeonPieces = {
                {portal="Starter",      piece="StarterIsland.DungeonPuzzlePiece"},
                {portal="Jungle",       piece="JungleIsland.DungeonPuzzlePiece"},
                {portal="Desert",       piece="DesertIsland.DungeonPuzzlePiece"},
                {portal="Snow",         piece="SnowIsland.DungeonPuzzlePiece"},
                {portal="Shibuya",      piece="ShibuyaStation.DungeonPuzzlePiece"},
                {portal="HollowIsland", piece="HollowIsland.DungeonPuzzlePiece"},
            }
            replicated.Remotes.TeleportToPortal:FireServer("Dungeon")
            WindUI:Notify({ Title="Dungeon Unlock", Content="Going to Dungeon NPC", Duration=2, Icon="map" })
            task.wait(1.5)
            Tween2(workspace.ServiceNPCs.DungeonPortalsNPC.HumanoidRootPart.CFrame)
            task.wait(0.1)
            vim1:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.5)
            vim1:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            task.wait(1)
            for _, entry in ipairs(dungeonPieces) do
                replicated.Remotes.TeleportToPortal:FireServer(entry.portal)
                WindUI:Notify({ Title="Dungeon Pieces", Content="Going to "..entry.portal, Duration=2, Icon="map" })
                task.wait(2.5)
                local parts = entry.piece:split(".")
                local obj = workspace
                for _, p in ipairs(parts) do obj = obj:FindFirstChild(p) or obj end
                if obj and obj ~= workspace then
                    Tween2(obj.CFrame)
                    task.wait(0.5)
                    vim1:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.5)
                    vim1:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    task.wait(1)
                end
            end
            WindUI:Notify({ Title="Dungeon Unlocked!", Content="All pieces collected!", Duration=3, Icon="check" })
            _G.UnlockDungeon = false
        end)
    end,
})

-- Dungeon Piece Buttons
local DungeonPieces = Tabs.Dungeon:Section({ Title="Dungeon Pieces", Box=true, Opened=true })

local dungeonPieceList = {
    {label="Starter",      portal="Starter",      path="StarterIsland.DungeonPuzzlePiece"},
    {label="Jungle",       portal="Jungle",       path="JungleIsland.DungeonPuzzlePiece"},
    {label="Desert",       portal="Desert",       path="DesertIsland.DungeonPuzzlePiece"},
    {label="Snow Island",  portal="Snow",         path="SnowIsland.DungeonPuzzlePiece"},
    {label="Shibuya",      portal="Shibuya",      path="ShibuyaStation.DungeonPuzzlePiece"},
    {label="Hollow Island",portal="HollowIsland", path="HollowIsland.DungeonPuzzlePiece"},
}

for _, dp in ipairs(dungeonPieceList) do
    DungeonPieces:Button({
        Title="Teleport: "..dp.label, Desc="",
        Callback=function()
            replicated.Remotes.TeleportToPortal:FireServer(dp.portal)
            WindUI:Notify({ Title="Teleporting", Content=dp.label, Duration=2, Icon="map" })
            task.wait(3)
            local parts = dp.path:split(".")
            local obj = workspace
            for _, p in ipairs(parts) do obj = obj:FindFirstChild(p) or obj end
            if obj and obj ~= workspace then
                Tween2(obj.CFrame)
                task.wait(0.5)
                vim1:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.5)
                vim1:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end
        end,
    })
end

-- Auto Dungeon Section
local AutoDungeonSection = Tabs.Dungeon:Section({ Title="Auto Dungeon", Box=true, Opened=false })

AutoDungeonSection:Dropdown({
    Title="Select Dungeon", Values=Tables.DungeonList, Value=nil, Multi=false, AllowNull=true,
    Callback=function(s) _G.SelectedDungeon = s end,
})

AutoDungeonSection:Toggle({
    Title="Auto Join Dungeon", Icon="door-open",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoDungeon = state
        if state then
            task.spawn(function()
                while _G.AutoDungeon do
                    task.wait(1)
                    if not _G.SelectedDungeon then continue end
                    pcall(function()
                        local leaveBtn = PGui.DungeonPortalJoinUI.LeaveButton
                        if leaveBtn and leaveBtn.Visible then return end
                        local targetIsland = "Dungeon"
                        if _G.SelectedDungeon == "BossRush" then targetIsland = "Sailor"
                        elseif _G.SelectedDungeon == "InfiniteTower" then targetIsland = "TowerIsland" end
                        if tick() - Shared.LastDungeon > 15 then
                            Remotes.OpenDungeon:FireServer(tostring(_G.SelectedDungeon))
                            Shared.LastDungeon = tick()
                            task.wait(1)
                        end
                        local portal = workspace:FindFirstChild("ActiveDungeonPortal")
                        if not portal then
                            if Shared.Island ~= targetIsland then
                                Remotes.TP_Portal:FireServer(targetIsland)
                                Shared.Island = targetIsland
                                task.wait(2.5)
                            end
                        else
                            local root = GetCharacter() and GetCharacter():FindFirstChild("HumanoidRootPart")
                            if root then
                                root.CFrame = portal.CFrame
                                task.wait(0.2)
                                local prompt = portal:FindFirstChild("JoinPrompt")
                                if prompt and Support.Proximity then
                                    fireproximityprompt(prompt); task.wait(1)
                                end
                            end
                        end
                    end)
                end
            end)
        end
    end,
})

-- Puzzle Buttons
local PuzzleSection = Tabs.Dungeon:Section({ Title="Puzzle Solvers", Box=true, Opened=false })

PuzzleSection:Button({
    Title="Complete Dungeon Puzzle", Desc="Requires Lv.5000+",
    Callback=function()
        local level = player.Data and player.Data.Level and player.Data.Level.Value or 0
        if level >= 5000 then
            task.spawn(function() UniversalPuzzleSolver("Dungeon") end)
        else
            WindUI:Notify({ Title="Error", Content="Level 5000 required! (You: "..level..")", Duration=3, Icon="alert-triangle" })
        end
    end,
})

PuzzleSection:Button({
    Title="Complete Slime Puzzle",
    Callback=function() task.spawn(function() UniversalPuzzleSolver("Slime") end) end,
})

PuzzleSection:Button({
    Title="Complete Demonite Puzzle",
    Callback=function() task.spawn(function() UniversalPuzzleSolver("Demonite") end) end,
})

PuzzleSection:Button({
    Title="Complete Hogyoku Puzzle", Desc="Requires Lv.8500+",
    Callback=function()
        local level = player.Data and player.Data.Level and player.Data.Level.Value or 0
        if level >= 8500 then
            task.spawn(function() UniversalPuzzleSolver("Hogyoku") end)
        else
            WindUI:Notify({ Title="Error", Content="Level 8500 required! (You: "..level..")", Duration=3, Icon="alert-triangle" })
        end
    end,
})

-- ============================================================
--  AUTOMATION TAB
-- ============================================================
local AutoCraftSection = Tabs.Automation:Section({ Title="Auto Craft", Box=true, Opened=true })

AutoCraftSection:Dropdown({
    Title="Select Item(s) to Craft", Values=Tables.CraftItemList, Value=nil, Multi=true,
    Callback=function(s) _G.SelectedCraftItems = s end,
})

AutoCraftSection:Toggle({
    Title="Auto Craft Item", Icon="hammer",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoCraftItem = state
        if state then
            task.spawn(function()
                while _G.AutoCraftItem do
                    for _, item in pairs(Shared.Cached.Inv) do
                        local selected = _G.SelectedCraftItems or {}
                        if selected["DivineGrail"] and item.name == "Broken Sword" and item.quantity >= 3 then
                            local amt = math.min(math.floor(item.quantity/3), 99)
                            pcall(function() Remotes.GrailCraft:InvokeServer("DivineGrail", amt) end)
                            task.wait(0.5)
                        end
                        if selected["SlimeKey"] and item.name == "Slime Shard" and item.quantity >= 2 then
                            local amt = math.min(math.floor(item.quantity/2), 99)
                            pcall(function() Remotes.SlimeCraft:InvokeServer("SlimeKey", amt) end)
                            task.wait(0.5)
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    end,
})

-- Auto Enchant / Blessing
local EnchantSection = Tabs.Automation:Section({ Title="Auto Enchant & Blessing", Box=true, Opened=true })

EnchantSection:Dropdown({
    Title="Select Accessory (Enchant)", Values=Tables.OwnedAccessory, Value=nil, Multi=true,
    Callback=function(s) _G.SelectedEnchant = s end,
})

EnchantSection:Toggle({
    Title="Auto Enchant", Icon="sparkles",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoEnchant = state
        if state then task.spawn(function() AutoUpgradeLoop("Enchant") end) end
    end,
})

EnchantSection:Dropdown({
    Title="Select Weapon (Blessing)", Values=Tables.OwnedWeapon, Value=nil, Multi=true,
    Callback=function(s) _G.SelectedBlessing = s end,
})

EnchantSection:Toggle({
    Title="Auto Blessing", Icon="star",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoBlessing = state
        if state then task.spawn(function() AutoUpgradeLoop("Blessing") end) end
    end,
})

-- Auto Roll Section
local RollSection = Tabs.Automation:Section({ Title="Auto Rolls", Box=true, Opened=true })

RollSection:Slider({
    Title="Roll Delay (s)", Step=0.01, Value={Min=0.01, Max=2, Default=0.3},
    Callback=function(v) _G.RollDelay = v end,
})

RollSection:Dropdown({
    Title="Target Trait(s)", Values=Tables.TraitList, Value=nil, Multi=true,
    Callback=function(s) _G.TargetTraits = s end,
})

RollSection:Toggle({
    Title="Auto Roll Trait", Icon="dice",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoRollTrait = state
        if state then
            task.spawn(function()
                while _G.AutoRollTrait do
                    pcall(function()
                        local traitUI = PGui:FindFirstChild("TraitRerollUI")
                        if traitUI then
                            local currentTrait = traitUI.MainFrame.Frame.Content.TraitPage.TraitGottenFrame.Holder.Trait.TraitGotten.Text
                            local selected = _G.TargetTraits or {}
                            if selected[currentTrait] then
                                WindUI:Notify({ Title="Success!", Content="Got trait: "..currentTrait, Duration=5, Icon="check" })
                                _G.AutoRollTrait = false; return
                            end
                            local confirmFrame = traitUI.MainFrame.Frame.Content:FindFirstChild("AreYouSureYouWantToRerollFrame")
                            if confirmFrame and confirmFrame.Visible then
                                Remotes.TraitConfirm:FireServer(true); task.wait(0.1)
                            end
                            Remotes.Roll_Trait:FireServer()
                        end
                    end)
                    task.wait(_G.RollDelay or 0.3)
                end
            end)
        end
    end,
})

RollSection:Dropdown({
    Title="Target Race(s)", Values=Tables.RaceList, Value=nil, Multi=true,
    Callback=function(s) _G.TargetRaces = s end,
})

RollSection:Toggle({
    Title="Auto Roll Race", Icon="users",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoRollRace = state
        if state then
            task.spawn(function()
                while _G.AutoRollRace do
                    local currentRace = player:GetAttribute("CurrentRace")
                    local selected = _G.TargetRaces or {}
                    if selected[currentRace] then
                        WindUI:Notify({ Title="Success!", Content="Got race: "..tostring(currentRace), Duration=5, Icon="check" })
                        _G.AutoRollRace = false; break
                    end
                    pcall(function() Remotes.UseItem:FireServer("Use", "Race Reroll", 1) end)
                    task.wait(_G.RollDelay or 0.3)
                end
            end)
        end
    end,
})

RollSection:Dropdown({
    Title="Target Clan(s)", Values=Tables.ClanList, Value=nil, Multi=true,
    Callback=function(s) _G.TargetClans = s end,
})

RollSection:Toggle({
    Title="Auto Roll Clan", Icon="flag",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoRollClan = state
        if state then
            task.spawn(function()
                while _G.AutoRollClan do
                    local currentClan = player:GetAttribute("CurrentClan")
                    local selected = _G.TargetClans or {}
                    if selected[currentClan] then
                        WindUI:Notify({ Title="Success!", Content="Got clan: "..tostring(currentClan), Duration=5, Icon="check" })
                        _G.AutoRollClan = false; break
                    end
                    pcall(function() Remotes.UseItem:FireServer("Use", "Clan Reroll", 1) end)
                    task.wait(_G.RollDelay or 0.3)
                end
            end)
        end
    end,
})

-- Ascend Section
local AscendSection = Tabs.Automation:Section({ Title="Auto Ascend", Box=true, Opened=false })

AscendSection:Toggle({
    Title="Auto Ascend", Icon="arrow-up",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoAscend = state
        if state then
            pcall(function()
                if Remotes.ReqAscend then Remotes.ReqAscend:InvokeServer() end
            end)
            if Remotes.UpAscend then
                Remotes.UpAscend.OnClientEvent:Connect(function(data)
                    if not _G.AutoAscend then return end
                    if data and data.allMet then
                        WindUI:Notify({ Title="Ascending!", Content="All requirements met!", Duration=3, Icon="arrow-up" })
                        pcall(function() Remotes.Ascend:FireServer() end)
                        task.wait(1)
                    end
                    if data and data.isMaxed then
                        WindUI:Notify({ Title="Max Ascension!", Content="Already at max!", Duration=3, Icon="star" })
                        _G.AutoAscend = false
                    end
                end)
            end
        end
    end,
})

-- Skill Tree Section
local SkillTreeSection = Tabs.Automation:Section({ Title="Skill Tree", Box=true, Opened=false })

SkillTreeSection:Toggle({
    Title="Auto Skill Tree", Icon="git-branch",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoSkillTree = state
        if state then
            task.spawn(function()
                while _G.AutoSkillTree do
                    task.wait(0.5)
                    if not Modules.SkillTree or not Modules.SkillTree.Branches then continue end
                    local points = Shared.SkillTree.SkillPoints or 0
                    if points <= 0 then continue end
                    for _, branch in pairs(Modules.SkillTree.Branches) do
                        for _, node in ipairs(branch.Nodes) do
                            if not Shared.SkillTree.Nodes[node.Id] then
                                if points >= node.Cost then
                                    pcall(function() Remotes.SkillTreeUpgrade:FireServer(node.Id) end)
                                    Shared.SkillTree.SkillPoints = points - node.Cost
                                    task.wait(0.3)
                                end
                                break
                            end
                        end
                    end
                end
            end)
        end
    end,
})

-- Artifact Milestone Section
local ArtifactMilestoneSection = Tabs.Automation:Section({ Title="Artifact Milestone", Box=true, Opened=false })

ArtifactMilestoneSection:Toggle({
    Title="Auto Claim Artifact Milestones", Icon="award",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoArtifactMilestone = state
        if state then
            task.spawn(function()
                local milestone = 1
                while _G.AutoArtifactMilestone do
                    pcall(function() Remotes.ArtifactClaim:FireServer(milestone) end)
                    milestone = milestone + 1
                    if milestone > 40 then milestone = 1 end
                    task.wait(1)
                end
            end)
        end
    end,
})

-- Merchant Section
local MerchantSection = Tabs.Automation:Section({ Title="Auto Merchant", Box=true, Opened=false })

MerchantSection:Dropdown({
    Title="Select Merchant Items", Values=Tables.MerchantList, Value=nil, Multi=true,
    Callback=function(s) _G.SelectedMerchantItems = s end,
})

MerchantSection:Toggle({
    Title="Auto Buy Merchant Items", Icon="shopping-cart",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoMerchant = state
        if state then
            task.spawn(function()
                while _G.AutoMerchant do
                    local selected = _G.SelectedMerchantItems or {}
                    for itemName, enabled in pairs(selected) do
                        if enabled then
                            pcall(function() Remotes.MerchantBuy:InvokeServer(itemName, 99) end)
                            task.wait(1.5)
                        end
                    end
                    task.wait(30)
                end
            end)
        end
    end,
})

-- Redeem Codes
local CodesSection = Tabs.Automation:Section({ Title="Codes", Box=true, Opened=false })

CodesSection:Button({
    Title="Redeem All Codes", Desc="Attempts to redeem all available codes",
    Callback=function()
        task.spawn(function()
            local allCodes = (Modules.Codes and Modules.Codes.Codes) or {}
            local playerLevel = player.Data and player.Data.Level and player.Data.Level.Value or 0
            for codeName, data in pairs(allCodes) do
                local levelReq = data.LevelReq or 0
                if playerLevel >= levelReq then
                    WindUI:Notify({ Title="Code", Content="Redeeming: "..codeName, Duration=2, Icon="gift" })
                    pcall(function() Remotes.UseCode:InvokeServer(codeName) end)
                    task.wait(2)
                end
            end
            WindUI:Notify({ Title="Done", Content="All codes attempted!", Duration=3, Icon="check" })
        end)
    end,
})

-- ============================================================
--  ARTIFACT TAB
-- ============================================================
local ArtifactSection = Tabs.Artifact:Section({ Title="Artifact Automation", Box=true, Opened=true })
local allSets, allStats2 = {}, {}
if Modules.ArtifactConfig then
    for setName,_ in pairs(Modules.ArtifactConfig.Sets or {}) do table.insert(allSets, setName) end
    for statKey,_ in pairs(Modules.ArtifactConfig.Stats or {}) do table.insert(allStats2, statKey) end
end

ArtifactSection:Slider({
    Title="Upgrade Limit", Step=1, Value={Min=0, Max=15, Default=0},
    Callback=function(v) _G.ArtifactUpgradeLimit = v end,
})

ArtifactSection:Toggle({
    Title="Auto Upgrade Artifacts", Icon="hammer",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.ArtifactAutoUpgrade = state end,
})

ArtifactSection:Toggle({
    Title="Auto Lock Artifacts", Icon="lock",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.ArtifactAutoLock = state end,
})

ArtifactSection:Toggle({
    Title="Auto Delete Unlocked", Icon="trash",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.ArtifactDeleteUnlocked = state end,
})

ArtifactSection:Toggle({
    Title="Auto Equip Best Artifacts", Icon="check-circle",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.ArtifactAutoEquip = state end,
})

ArtifactSection:Slider({
    Title="Min Sub-Stats to Lock", Step=1, Value={Min=0, Max=4, Default=2},
    Callback=function(v) _G.ArtifactMinSS = v end,
})

-- Artifact automation loop
task.spawn(function()
    while task.wait(5) do
        if not (_G.ArtifactAutoUpgrade or _G.ArtifactAutoLock or _G.ArtifactDeleteUnlocked or _G.ArtifactAutoEquip) then continue end
        if not Shared.ArtifactSession.Inventory or not next(Shared.ArtifactSession.Inventory) then
            if Remotes.ArtifactUnequip then pcall(function() Remotes.ArtifactUnequip:FireServer("") end) end
            continue
        end
        local lockQueue, deleteQueue, upgradeQueue = {}, {}, {}
        for uuid, data in pairs(Shared.ArtifactSession.Inventory) do
            if _G.ArtifactAutoUpgrade and data.Level < (_G.ArtifactUpgradeLimit or 0) then
                table.insert(upgradeQueue, {UUID=uuid, Levels=_G.ArtifactUpgradeLimit})
            end
            if not data.Locked then
                if _G.ArtifactAutoLock then
                    local ssCount = #(data.Substats or {})
                    if ssCount >= (_G.ArtifactMinSS or 2) then
                        table.insert(lockQueue, uuid)
                    end
                end
                if _G.ArtifactDeleteUnlocked then
                    table.insert(deleteQueue, uuid)
                end
            end
        end
        for _, uuid in ipairs(lockQueue) do
            pcall(function() Remotes.ArtifactLock:FireServer(uuid, true) end); task.wait(0.1)
        end
        if #deleteQueue > 0 then
            for i = 1, #deleteQueue, 50 do
                local chunk = {}
                for j = i, math.min(i+49, #deleteQueue) do table.insert(chunk, deleteQueue[j]) end
                pcall(function() Remotes.MassDelete:FireServer(chunk) end); task.wait(0.6)
            end
        end
        if #upgradeQueue > 0 then
            for i = 1, #upgradeQueue, 50 do
                local chunk = {}
                for j = i, math.min(i+49, #upgradeQueue) do table.insert(chunk, upgradeQueue[j]) end
                pcall(function() Remotes.MassUpgrade:FireServer(chunk) end); task.wait(0.6)
            end
        end
        if _G.ArtifactAutoEquip then
            local bestItems = {Helmet=nil,Gloves=nil,Body=nil,Boots=nil}
            local bestScores = {Helmet=-1,Gloves=-1,Body=-1,Boots=-1}
            for uuid, data in pairs(Shared.ArtifactSession.Inventory) do
                local score = (#(data.Substats or {}) * 10) + (data.Level or 0)
                if bestScores[data.Category] and score > bestScores[data.Category] then
                    bestScores[data.Category] = score
                    bestItems[data.Category] = {UUID=uuid, Equipped=data.Equipped}
                end
            end
            for _, item in pairs(bestItems) do
                if item and not item.Equipped then
                    pcall(function() Remotes.ArtifactEquip:FireServer(item.UUID) end)
                    task.wait(0.2)
                end
            end
        end
    end
end)

-- ============================================================
--  WORLD TAB
-- ============================================================
local TeleportSection = Tabs.World:Section({ Title="Teleport System", Box=true, Opened=true })

local LocationValues = {}
for _, loc in ipairs(TeleportLocations) do table.insert(LocationValues, loc.Display) end

TeleportSection:Dropdown({
    Title="Select Destination", Desc="Choose where to teleport",
    Values=LocationValues, Value=LocationValues[1], Multi=false,
    Callback=function(selected)
        for _, loc in ipairs(TeleportLocations) do
            if loc.Display == selected then _G.SelectedTeleportLocation = loc; break end
        end
    end,
})

TeleportSection:Button({
    Title="Teleport to Selected Location", Desc="",
    Callback=function()
        local loc = _G.SelectedTeleportLocation
        if not loc then
            WindUI:Notify({ Title="Error", Content="No location selected!", Duration=2, Icon="alert-triangle" })
            return
        end
        replicated.Remotes.TeleportToPortal:FireServer(loc.Portal)
        WindUI:Notify({ Title="Teleporting", Content="Going to "..loc.Name.."...", Duration=2, Icon="map-pin" })
    end,
})

TeleportSection:Divider()

-- NPC Teleport
local NPCTeleportSection = Tabs.World:Section({ Title="NPC Teleport", Box=true, Opened=false })

local allNPCNames = {}
for _, v in pairs(PATH.InteractNPCs:GetChildren()) do table.insert(allNPCNames, v.Name) end
table.sort(allNPCNames)

NPCTeleportSection:Dropdown({
    Title="Select NPC", Values=allNPCNames, Value=nil, Multi=false, AllowNull=true,
    Callback=function(s)
        if s then SafeTeleportToNPC(s) end
    end,
})

-- Shop Section
local ShopSection = Tabs.World:Section({ Title="Shop", Box=true, Opened=false })

ShopSection:Button({
    Title="Buy Katana Sword", Desc="Purchase Katana from shop",
    Callback=function()
        pcall(function() replicated.Remotes.ShopRemotes.PurchaseProduct:FireServer("clearGift") end)
        WindUI:Notify({ Title="Purchased", Content="Katana bought!", Duration=2, Icon="shopping-cart" })
    end,
})

-- World Auto Farm
local WorldFarmSection = Tabs.World:Section({ Title="World Auto Farm", Box=true, Opened=false })

WorldFarmSection:Toggle({
    Title="Auto Farm Nearby Mobs", Desc="Attacks mobs within range", Icon="swords",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.SailorAutoFarm = state
        if state then
            task.spawn(function()
                while _G.SailorAutoFarm do
                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        for _, mob in ipairs(workspace:GetDescendants()) do
                            if mob:IsA("Model") and (mob.Name:lower():find("mob") or mob.Name:lower():find("enemy") or mob.Name:lower():find("bandit")) then
                                local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Head")
                                if mobRoot and (mobRoot.Position - root.Position).Magnitude < 20 then
                                    root.CFrame = mobRoot.CFrame
                                    task.wait(0.05)
                                    pcall(function() replicated.CombatSystem.Remotes.RequestHit:FireServer() end)
                                    task.wait(0.2)
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

-- ============================================================
--  VISUALS TAB
-- ============================================================
local ESPSection = Tabs.Visuals:Section({ Title="ESP & Visuals", Box=true, Opened=true })

ESPSection:Toggle({
    Title="Player ESP", Desc="Highlight other players", Icon="users",
    Type="Checkbox", Value=false,
    Callback=function(state) _G.SailorESP = state end,
})

ESPSection:Toggle({
    Title="Fullbright", Desc="Remove shadows", Icon="sun",
    Type="Checkbox", Value=false,
    Callback=function(state)
        local lighting = game:GetService("Lighting")
        if state then
            lighting.Ambient = Color3.fromRGB(255,255,255)
            lighting.Brightness = 2
            lighting.GlobalShadows = false
            lighting.ClockTime = 12
        else
            lighting.Ambient = Color3.fromRGB(0,0,0)
            lighting.Brightness = 1
            lighting.GlobalShadows = true
        end
    end,
})

ESPSection:Toggle({
    Title="No Fog", Desc="Remove fog", Icon="wind",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.NoFog = state
        if state then Lighting.FogEnd = 9e9 end
    end,
})

ESPSection:Slider({
    Title="Time of Day", Step=0.5, Value={Min=0, Max=24, Default=12},
    Callback=function(v) _G.TimeOfDay = v; Lighting.ClockTime = v end,
})

-- Mob/Boss ESP
ESPSection:Toggle({
    Title="Mob ESP", Desc="Highlight mobs", Icon="target",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.MobESP = state
        task.spawn(function()
            while _G.MobESP do
                task.wait(0.5)
                for _, npc in pairs(PATH.Mobs:GetChildren()) do
                    if npc:IsA("Model") and not npc:FindFirstChild("MobESP") then
                        local hl            = Instance.new("Highlight")
                        hl.Name             = "MobESP"
                        hl.FillColor        = Color3.fromRGB(50,200,50)
                        hl.FillTransparency = 0.6
                        hl.OutlineColor     = Color3.fromRGB(0,255,0)
                        hl.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Adornee          = npc
                        hl.Parent           = npc
                    end
                end
            end
            for _, npc in pairs(PATH.Mobs:GetChildren()) do
                local hl = npc:FindFirstChild("MobESP")
                if hl then hl:Destroy() end
            end
        end)
    end,
})

-- ============================================================
--  SETTINGS TAB
-- ============================================================
local ServerSection = Tabs.Settings:Section({ Title="Server Features", Box=true, Opened=true })

ServerSection:Button({
    Title="Server Hop", Desc="Joins a different server instantly",
    Callback=function()
        WindUI:Notify({ Title="Server Hop", Content="Joining a Different Server..", Duration=2, Icon="server" })
        task.wait(1)
        ServerHop()
    end,
})

ServerSection:Button({
    Title="Copy Job ID", Desc="",
    Callback=function()
        if Support.Clipboard then setclipboard(game.JobId) end
        WindUI:Notify({ Title="Job ID", Content="Copied to clipboard", Duration=2, Icon="server" })
    end,
})

ServerSection:Input({
    Title="Enter Job ID", Desc="Paste server Job ID to join",
    Value="", Placeholder="Paste Job ID here...", Type="Input",
    Callback=function(input) _G.TargetJobId = input end,
})

ServerSection:Button({
    Title="Join Server", Desc="Teleports to entered Job ID",
    Callback=function()
        if _G.TargetJobId and _G.TargetJobId ~= "" then
            pcall(function() TeleportService:TeleportToPlaceInstance(PlaceId, _G.TargetJobId, player) end)
        else
            WindUI:Notify({ Title="Error", Content="Enter a Job ID first!", Duration=2, Icon="alert-triangle" })
        end
    end,
})

ServerSection:Divider()

ServerSection:Toggle({
    Title="Auto Rejoin on Disconnect", Desc="Auto reconnect when disconnected", Icon="refresh-cw",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoReconnect = state
        if state then
            GuiService.ErrorMessageChanged:Connect(function()
                if not _G.AutoReconnect then return end
                task.delay(3, function()
                    pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
                end)
            end)
        end
    end,
})

-- Performance Section
local PerfSection = Tabs.Settings:Section({ Title="Performance", Box=true, Opened=true })

PerfSection:Button({
    Title="Boost FPS", Desc="Lowers graphics and clears textures",
    Callback=function()
        ApplyFPSBoost()
        WindUI:Notify({ Title="FPS Boost", Content="Graphics optimised!", Duration=2, Icon="zap" })
    end,
})

if Support.FPS then
    PerfSection:Slider({
        Title="Max FPS Cap", Step=5, Value={Min=5, Max=360, Default=60},
        Callback=function(v) pcall(function() setfpscap(v) end) end,
    })
end

PerfSection:Toggle({
    Title="Disable 3D Rendering", Desc="Extreme FPS boost", Icon="eye-off",
    Type="Checkbox", Value=false,
    Callback=function(state) pcall(function() RunService:Set3dRenderingEnabled(not state) end) end,
})

-- Safety Section
local SafetySection = Tabs.Settings:Section({ Title="Safety", Box=true, Opened=false })

SafetySection:Toggle({
    Title="Anti Kick (Client)", Desc="Prevent client-side kicks", Icon="shield",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AntiKick = state
        if state then
            pcall(function()
                local mt = getrawmetatable and getrawmetatable(game)
                if mt then
                    local old = mt.__namecall
                    setreadonly(mt, false)
                    mt.__namecall = newcclosure(function(self, ...)
                        local method = getnamecallmethod()
                        if method == "Kick" then return end
                        return old(self, ...)
                    end)
                    setreadonly(mt, true)
                end
            end)
        end
    end,
})

-- Webhook Section
local WebhookSection = Tabs.Settings:Section({ Title="Webhook", Box=true, Opened=false })

WebhookSection:Input({
    Title="Discord Webhook URL", Desc="Your webhook URL",
    Value="", Placeholder="https://discord.com/api/webhooks/...", Type="Input",
    Callback=function(input) _G.WebhookURL = input end,
})

WebhookSection:Dropdown({
    Title="Select Rarities to Track",
    Values={"Common","Uncommon","Rare","Epic","Legendary","Mythical","Secret"},
    Value=nil, Multi=true,
    Callback=function(s) _G.WebhookRarities = s end,
})

WebhookSection:Slider({
    Title="Send Every (minutes)", Step=1, Value={Min=1, Max=60, Default=5},
    Callback=function(v) _G.WebhookDelay = v end,
})

WebhookSection:Toggle({
    Title="Auto Send Webhook", Desc="Sends stats periodically", Icon="send",
    Type="Checkbox", Value=false,
    Callback=function(state)
        _G.AutoWebhook = state
        if state then
            task.spawn(function()
                while _G.AutoWebhook do
                    if _G.WebhookURL and _G.WebhookURL:find("discord.com/api/webhooks/") then
                        local data = player.Data
                        local desc = "**Sailor Piece**\n"
                        if data then
                            desc = desc..string.format("**Level:** %s\n", CommaFormat(data.Level.Value))
                            desc = desc..string.format("**Money:** %s\n", Abbreviate(data.Money.Value))
                            desc = desc..string.format("**Gems:** %s\n", CommaFormat(data.Gems.Value))
                        end
                        local payload = {
                            embeds = {{ description=desc, color=tonumber("FF0F7B",16) }}
                        }
                        pcall(function()
                            if request then
                                request({ Url=_G.WebhookURL, Method="POST",
                                    Headers={["Content-Type"]="application/json"},
                                    Body=HttpService:JSONEncode(payload) })
                            end
                        end)
                    end
                    task.wait((_G.WebhookDelay or 5) * 60)
                end
            end)
        end
    end,
})

-- Window tag
Window:Tag({
    Title  = "v2.0",
    Icon   = "github",
    Color  = Color3.fromHex("#30ff6a"),
    Radius = 8,
})

-- ============================================================
--  STARTUP NOTIFICATION
-- ============================================================
task.spawn(function()
    task.wait(1)
    if Remotes.ReqInventory then
        pcall(function() Remotes.ReqInventory:FireServer() end)
    end
    UpdateNPCLists()
end)

WindUI:Notify({
    Title   = "Sailor Piece Loaded",
    Content = "CattStar Sailor-Piece v2.0 | RightShift to toggle UI",
    Duration= 4,
    Icon    = "rbxassetid://84971028134779",
})
