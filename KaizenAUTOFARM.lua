--// Autofarm Hub - Fluent Version (Full Hub Structure)
--// + Auto Skills + Auto Attack + Auto Equip
--// + Teleport to TestChest when it appears in workspace.Effects
--// + Weapon dropdown includes "None"
--// + Enemy dropdown (FingerBearer, OgreCurse, Sukuna, Gojo, IroncladGnasher)
--// + REVERTED: Auto-Attack to original Click() M1 (remotes removed)
--// + ENHANCED: Strict equip-before-teleport (farm pauses until fully equipped)
--// + NEW: Wait for Backpack to finish loading before equipping
--// + REVERTED: Movement to original GetBehind (- LookVector on HumanoidRootPart)

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

--// Player
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local backpack = player:WaitForChild("Backpack")

------------------------------------------------------------
-- LOAD FLUENT
------------------------------------------------------------

local Fluent = loadstring(game:HttpGet(
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
))()

local SaveManager = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"
))()

local InterfaceManager = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"
))()

------------------------------------------------------------
-- WINDOW
------------------------------------------------------------

local Window = Fluent:CreateWindow({
    Title = "autofarm",
    SubTitle = "Farm Hub",
    TabWidth = 160,
    Size = UDim2.fromOffset(560, 500),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

------------------------------------------------------------
-- TABS
------------------------------------------------------------

local Tabs = {
    Main = Window:AddTab({ Title = "Autofarm", Icon = "play" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "sword" }),
    Loot = Window:AddTab({ Title = "Loot", Icon = "box" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

------------------------------------------------------------
-- SETTINGS TABLE
------------------------------------------------------------

local Settings = {
    -- Farm
    FarmEnabled = false,
    SelectedEnemy = "FingerBearer",
    DistanceBehind = 6,
    Smoothness = 0.18,
    FreezeY = true,

    -- Combat
    AutoAttack = false,
    AutoZ = false,
    AutoX = false,
    AutoC = false,
    AutoV = false,

    -- Weapon
    SelectedWeapon = "None",

    -- Loot
    AutoChestTeleport = true,
    ChestYOffset = 3
}

------------------------------------------------------------
-- AUTOFARM UI
------------------------------------------------------------

Tabs.Main:AddToggle("FarmToggle", {
    Title = "Enable Autofarm",
    Default = false
}):OnChanged(function(v)
    Settings.FarmEnabled = v
end)

local EnemyValues = { "FingerBearer", "OgreCurse", "Sukuna", "Gojo", "IroncladGnasher" }

local EnemyDropdown = Tabs.Main:AddDropdown("EnemyDropdown", {
    Title = "Enemy Target",
    Values = EnemyValues,
    Multi = false,
    Default = "FingerBearer"
})

EnemyDropdown:OnChanged(function(v)
    if v and v ~= "" then
        Settings.SelectedEnemy = v
    end
end)

Tabs.Main:AddSlider("DistanceSlider", {
    Title = "Distance Behind",
    Min = 3,
    Max = 15,
    Default = 6,
    Rounding = 1
}):OnChanged(function(v)
    Settings.DistanceBehind = v
end)

Tabs.Main:AddSlider("SmoothSlider", {
    Title = "Smoothness",
    Min = 0.05,
    Max = 0.5,
    Default = 0.18,
    Rounding = 2
}):OnChanged(function(v)
    Settings.Smoothness = v
end)

------------------------------------------------------------
-- COMBAT UI
------------------------------------------------------------

Tabs.Combat:AddToggle("AutoAttack", {
    Title = "Auto Attack (M1)",
    Default = false
}):OnChanged(function(v)
    Settings.AutoAttack = v
end)

Tabs.Combat:AddToggle("AutoZ", { Title = "Auto Skill Z", Default = false }):OnChanged(function(v) Settings.AutoZ = v end)
Tabs.Combat:AddToggle("AutoX", { Title = "Auto Skill X", Default = false }):OnChanged(function(v) Settings.AutoX = v end)
Tabs.Combat:AddToggle("AutoC", { Title = "Auto Skill C", Default = false }):OnChanged(function(v) Settings.AutoC = v end)
Tabs.Combat:AddToggle("AutoV", { Title = "Auto Skill V", Default = false }):OnChanged(function(v) Settings.AutoV = v end)

------------------------------------------------------------
-- LOOT UI (TestChest)
------------------------------------------------------------

Tabs.Loot:AddToggle("AutoChestTeleport", {
    Title = "Teleport to TestChest on spawn",
    Default = true
}):OnChanged(function(v)
    Settings.AutoChestTeleport = v
end)

Tabs.Loot:AddSlider("ChestYOffset", {
    Title = "Chest Teleport Y Offset",
    Min = 0,
    Max = 10,
    Default = 3,
    Rounding = 1
}):OnChanged(function(v)
    Settings.ChestYOffset = v
end)

------------------------------------------------------------
-- WEAPON SYSTEM (includes "None")
------------------------------------------------------------

local WeaponList = { "None" }

local WeaponDropdown = Tabs.Combat:AddDropdown("WeaponDropdown", {
    Title = "Select Weapon",
    Values = WeaponList,
    Multi = false,
    Default = "None"
})

WeaponDropdown:OnChanged(function(v)
    Settings.SelectedWeapon = v or "None"
end)

-- Inventory readiness gate
local Inventory = {
    lastChange = 0,
    ready = false
}

local function MarkInventoryChanged()
    Inventory.lastChange = os.clock()
    Inventory.ready = false
end

local function HookBackpackSignals()
    if backpack then
        backpack.ChildAdded:Connect(MarkInventoryChanged)
        backpack.ChildRemoved:Connect(MarkInventoryChanged)
    end
end

HookBackpackSignals()
MarkInventoryChanged()

-- Wait until backpack stops changing for quietPeriod seconds (or timeout)
local function WaitForBackpackStable(timeout, quietPeriod)
    timeout = timeout or 6
    quietPeriod = quietPeriod or 0.35

    local start = os.clock()
    while os.clock() - start < timeout do
        local sinceChange = os.clock() - (Inventory.lastChange or 0)
        if sinceChange >= quietPeriod then
            Inventory.ready = true
            return true
        end
        task.wait(0.05)
    end
    -- even if it times out, we proceed (but mark not-ready)
    return false
end

local function RefreshWeapons()
    WeaponList = { "None" }

    backpack = player:WaitForChild("Backpack")
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(WeaponList, tool.Name)
        end
    end

    WeaponDropdown:SetValues(WeaponList)

    -- If selected weapon no longer exists, fallback to None
    if Settings.SelectedWeapon and Settings.SelectedWeapon ~= "None" then
        local stillExists = false
        for _, name in ipairs(WeaponList) do
            if name == Settings.SelectedWeapon then
                stillExists = true
                break
            end
        end
        if not stillExists then
            Settings.SelectedWeapon = "None"
        end
    end
end

Tabs.Combat:AddButton({
    Title = "Refresh Weapons",
    Callback = function()
        MarkInventoryChanged()
        WaitForBackpackStable(6, 0.35)
        RefreshWeapons()
    end
})

-- Initial population
task.spawn(function()
    WaitForBackpackStable(6, 0.35)
    RefreshWeapons()
end)

------------------------------------------------------------
-- AUTO EQUIP (gated by backpack readiness)
------------------------------------------------------------

local EquipState = {
    equipped = false
}

local function IsEquipped()
    if Settings.SelectedWeapon == "None" then
        return true
    end
    if not character or not character.Parent then
        return false
    end
    return character:FindFirstChild(Settings.SelectedWeapon) ~= nil
end

local function EquipWeapon()
    if Settings.SelectedWeapon == nil or Settings.SelectedWeapon == "None" then
        EquipState.equipped = true
        return true
    end

    if not character or not character.Parent then
        EquipState.equipped = false
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        EquipState.equipped = false
        return false
    end

    -- Already equipped?
    if character:FindFirstChild(Settings.SelectedWeapon) then
        EquipState.equipped = true
        return true
    end

    -- Only attempt equip when inventory is ready/stable
    if not Inventory.ready then
        EquipState.equipped = false
        return false
    end

    backpack = player:FindFirstChild("Backpack") or backpack
    if not backpack then
        EquipState.equipped = false
        return false
    end

    local tool = backpack:FindFirstChild(Settings.SelectedWeapon)
    if tool then
        humanoid:EquipTool(tool)
        task.wait(0.05)
    end

    EquipState.equipped = IsEquipped()
    return EquipState.equipped
end

------------------------------------------------------------
-- TARGET SYSTEM (uses SelectedEnemy) - ORIGINAL
------------------------------------------------------------

local function IsValidTarget(enemy)
    if not enemy or not enemy.Parent then return false end
    if enemy:GetAttribute("EnemyName") ~= Settings.SelectedEnemy then return false end

    local ehrp = enemy:FindFirstChild("HumanoidRootPart")
    local hum = enemy:FindFirstChildOfClass("Humanoid")

    if not ehrp or not hum then return false end
    if hum.Health <= 0 then return false end

    return true
end

local function GetClosestTarget()
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return nil end

    local closest, shortest = nil, math.huge

    for _, enemy in pairs(enemies:GetChildren()) do
        if enemy:GetAttribute("EnemyName") == Settings.SelectedEnemy then
            local ehrp = enemy:FindFirstChild("HumanoidRootPart")
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            if ehrp and hum and hum.Health > 0 then
                local dist = (ehrp.Position - hrp.Position).Magnitude
                if dist < shortest then
                    shortest = dist
                    closest = enemy
                end
            end
        end
    end

    return closest
end

local function GetBehind(enemy)
    local ehrp = enemy:FindFirstChild("HumanoidRootPart")
    if not ehrp then return end

    local pos = ehrp.Position - (ehrp.CFrame.LookVector * Settings.DistanceBehind)

    if Settings.FreezeY then
        pos = Vector3.new(pos.X, hrp.Position.Y, pos.Z)
    end

    return CFrame.lookAt(pos, ehrp.Position)
end

------------------------------------------------------------
-- INPUT EMULATION
------------------------------------------------------------

local function HoldKey(key)
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    task.wait(1.5)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function Click()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

------------------------------------------------------------
-- TESTCHEST TELEPORT (workspace.Effects.TestChest)
------------------------------------------------------------

local chestDebounce = false
local chestName = "TestChest"

local function getObjectCFrame(obj)
    if obj:IsA("Model") then
        local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        if pp then return pp.CFrame end
        return nil
    elseif obj:IsA("BasePart") then
        return obj.CFrame
    end
    return nil
end

local function TeleportToChest(chestObj)
    if not Settings.AutoChestTeleport then return end
    if chestDebounce then return end
    if not hrp or not hrp.Parent then return end

    task.wait(0.05)

    local cf = getObjectCFrame(chestObj)
    if not cf then return end

    chestDebounce = true
    hrp.CFrame = cf + Vector3.new(0, Settings.ChestYOffset, 0)

    task.delay(0.4, function()
        chestDebounce = false
    end)
end

local function HookChestWatcher()
    local effects = workspace:FindFirstChild("Effects") or workspace:WaitForChild("Effects")

    for _, obj in ipairs(effects:GetChildren()) do
        if obj.Name == chestName then
            TeleportToChest(obj)
        end
    end

    effects.ChildAdded:Connect(function(obj)
        if obj.Name == chestName then
            TeleportToChest(obj)
        end
    end)
end

HookChestWatcher()

------------------------------------------------------------
-- LOOPS
------------------------------------------------------------

local currentTarget = nil
local lastEnemySelection = Settings.SelectedEnemy

RunService.RenderStepped:Connect(function()
    if not Settings.FarmEnabled then
        currentTarget = nil
        return
    end

    -- STRICT: If weapon selected, pause ALL farm movement until FULLY equipped
    if Settings.SelectedWeapon ~= "None" then
        if not IsEquipped() then
            EquipWeapon()  -- Attempt equip every frame until success
            return  -- NO teleport until equipped
        end
    end

    -- Enemy selection changed
    if Settings.SelectedEnemy ~= lastEnemySelection then
        lastEnemySelection = Settings.SelectedEnemy
        currentTarget = nil
    end

    if not currentTarget or not IsValidTarget(currentTarget) then
        currentTarget = GetClosestTarget()
    end

    if currentTarget then
        local cf = GetBehind(currentTarget)
        if cf then
            hrp.CFrame = hrp.CFrame:Lerp(cf, Settings.Smoothness)
        end
    end
end)

-- Equip manager loop:
-- 1) waits for backpack stability after changes
-- 2) refreshes dropdown list
-- 3) equips selected weapon
task.spawn(function()
    while true do
        task.wait(0.15)

        -- If inventory not ready, attempt to stabilize then refresh
        if not Inventory.ready then
            WaitForBackpackStable(6, 0.35)
            RefreshWeapons()
        end

        EquipWeapon()
    end
end)

-- Attack Loop (optional: only when equipped)
task.spawn(function()
    while true do
        task.wait(0.15)
        if Settings.AutoAttack then
            if Settings.SelectedWeapon == "None" or IsEquipped() then
                Click()
            end
        end
    end
end)

-- Skills Loop (optional: only when equipped)
task.spawn(function()
    while true do
        task.wait()
        local ok = (Settings.SelectedWeapon == "None") or IsEquipped()
        if not ok then
            -- don’t waste inputs if weapon/tool not equipped yet
            continue
        end

        if Settings.AutoZ then HoldKey(Enum.KeyCode.Z) end
        if Settings.AutoX then HoldKey(Enum.KeyCode.X) end
        if Settings.AutoC then HoldKey(Enum.KeyCode.C) end
        if Settings.AutoV then HoldKey(Enum.KeyCode.V) end
    end
end)

------------------------------------------------------------
-- RESPAWN FIX (WAIT BACKPACK LOAD -> REFRESH -> EQUIP -> RESUME)
------------------------------------------------------------

player.CharacterAdded:Connect(function(char)
    character = char
    hrp = char:WaitForChild("HumanoidRootPart")
    backpack = player:WaitForChild("Backpack")
    currentTarget = nil

    -- re-hook backpack signals (new instance timing can matter)
    HookBackpackSignals()
    MarkInventoryChanged()

    -- After respawn: wait for tools to replicate -> refresh -> equip
    task.spawn(function()
        WaitForBackpackStable(8, 0.45)
        RefreshWeapons()
        EquipWeapon()
    end)
end)

------------------------------------------------------------
-- SAVE SYSTEM
------------------------------------------------------------

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("autofarm")
SaveManager:SetFolder("autofarm/configs")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

------------------------------------------------------------
-- NOTIFY
------------------------------------------------------------

Fluent:Notify({
    Title = "autofarm",
    Content = "Loaded (Auto-Attack reverted to M1 + strict equip-before-teleport).",
    Duration = 6
})
