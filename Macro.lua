-- [[ Slap Battles Macro - v9.0 Tactician Edition ]] --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local PathfindingService = game:GetService("PathfindingService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local FileName = "MacroGloveConfig_v9.json"

-- Limpieza previa de UI
if CoreGui:FindFirstChild("MacroUI") then
    CoreGui.MacroUI:Destroy()
end
if workspace:FindFirstChild("MacroTargetHighlight") then
    workspace.MacroTargetHighlight:Destroy()
end

-- [[ CONFIGURACIÓN DE PARÁMETROS ]] --
local Settings = {
    Enabled = false,
    BotType = "LowestHP", -- "Closest", "LowestHP"
    IgnoreRagdoll = false,
    SlapRadius = 10,
    Shiftlock = false,
    ShiftlockRadius = 20,
    Jumps = false,
    JumpChance = 10,
    IgnoreOneshots = false,
    DistanceRadius = 5,
    StrafeEnabled = false,
    StrafeRadius = 15,    
    UnequipFar = false,
    UnequipRadius = 30,
    AutoAbility = false,
    
    -- FUNCIONALIDADES TÁCTICAS V9
    AvoidTraps = true,
    BypassImmune = true,
    PriorityLowHP = true,
    AntiKnockbackGuard = true,
    AutoCollectOrbs = true,
    AutoCollectPlates = true,
    EdgeGuard = true,
    DodgeProjectiles = true,
    AntiCounter = true,
    TargetKillstreaks = true,
    AntiVoid = true,
    SmartShield = true,
    GhostLobbySafety = true,
    TrackInvisibles = true,
    TargetVisualizer = true,
    SmartServerHop = true,
    
    ServerHopMode = "Main",
    MinPlayers = 3,
    AutoHopTimerEnabled = false,
    AutoHopMinutes = 30,
    AntiAFK = true
}

-- [[ RASTREO DE DATOS Y ESTADÍSTICAS ]] --
local SessionStartSlaps = 0
local DeathsCount = 0
local StartTime = tick()
local LastPathCompute = 0

local TargetHighlight = Instance.new("Highlight")
TargetHighlight.Name = "MacroTargetHighlight"
TargetHighlight.FillColor = Color3.fromRGB(255, 50, 50)
TargetHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
TargetHighlight.FillTransparency = 0.5

local function GetSlaps()
    local stats = Player:FindFirstChild("leaderstats")
    local slaps = stats and stats:FindFirstChild("Slaps")
    return slaps and slaps.Value or 0
end
SessionStartSlaps = GetSlaps()

Player.CharacterAdded:Connect(function(char)
    DeathsCount = DeathsCount + 1
end)

-- [[ GUARDADO Y CARGA ]] --
local function SaveSettings()
    local success, encoded = pcall(function() return HttpService:JSONEncode(Settings) end)
    if success and writefile then 
        pcall(writefile, FileName, encoded) 
    end
end

local function LoadSettings()
    if isfile and readfile and isfile(FileName) then
        local success, decoded = pcall(function() return HttpService:JSONEncode(readfile(FileName)) end)
        if success and type(decoded) == "table" then
            for k, v in pairs(decoded) do 
                Settings[k] = v 
            end
        end
    end
end
LoadSettings()

local GameIDs = { Main = 6403373529, NoOneshots = 9015014224, KS = 11520107397 }
local OneShotGloves = {"OVERKILL", "God's Hand", "The Flex", "Error", "rob", "Shopkeeper", "Spectator", "buddies"}
local CounterGloves = {"Reverse", "COUNTER", "Pusher", "Shield"}
local ImmuneGloves = {"Diamond", "MEGAROCK", "Custom"}

-- [[ ANTI-AFK ]] --
if Settings.AntiAFK then
    local VirtualUser = game:GetService("VirtualUser")
    Player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

-- [[ RECONEXIÓN Y SERVER HOP ]] --
CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        TeleportService:Teleport(GameIDs[Settings.ServerHopMode] or GameIDs.Main, Player)
    end
end)

local function ServerHop()
    SaveSettings()
    local targetID = GameIDs[Settings.ServerHopMode] or GameIDs.Main
    TeleportService:Teleport(targetID, Player)
end

-- [[ VERIFICACIÓN DE SUELO ]] --
local function IsSafeGround(pos)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    if Player.Character then
        rayParams.FilterDescendantsInstances = {Player.Character}
    end
    local result = workspace:Raycast(pos, Vector3.new(0, -20, 0), rayParams)
    return result ~= nil
end

-- [[ MOVIMIENTO Y PATHFINDING ]] --
local function MoveToTargetSmooth(targetPos)
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root or not hum then return end

    if Settings.EdgeGuard and not IsSafeGround(targetPos) then
        local arenaCenter = Vector3.new(0, 0, 0)
        targetPos = root.Position + (arenaCenter - root.Position).Unit * 6
    end

    local dir = (targetPos - root.Position)
    if dir.Magnitude < 10 then
        hum:MoveTo(targetPos)
    else
        if tick() - LastPathCompute > 0.35 then
            LastPathCompute = tick()
            local path = PathfindingService:CreatePath({AgentRadius = 3, AgentCanJump = true})
            local success = pcall(function() path:ComputeAsync(root.Position, targetPos) end)

            if success and path.Status == Enum.PathStatus.Success then
                local waypoints = path:GetWaypoints()
                if waypoints[2] then
                    hum:MoveTo(waypoints[2].Position)
                    if waypoints[2].Action == Enum.PathWaypointAction.Jump then 
                        hum.Jump = true 
                    end
                end
            else
                hum:MoveTo(targetPos)
            end
        end
    end
end

local function TriggerAbility()
    local char = Player.Character
    if not char or not char:FindFirstChildOfClass("Tool") then return end
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- [[ RECOLECCIÓN DE OBJETOS ]] --
local function GetNearestCollectable()
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local closestObj = nil
    local shortestDist = 120

    local ArenaFolder = workspace:FindFirstChild("Arena") or workspace
    for _, obj in pairs(ArenaFolder:GetDescendants()) do
        local isValid = false
        if Settings.AutoCollectOrbs and (obj.Name == "Slapple" or obj.Name == "JetOrb" or obj.Name == "PhaseOrb") then
            isValid = true
        elseif Settings.AutoCollectPlates and (obj.Name == "Plate" or obj.Name == "FloatingPlate") then
            isValid = true
        end

        if isValid then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = (root.Position - part.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    closestObj = part.Position
                end
            end
        end
    end
    return closestObj
end

-- [[ EVITADOR DE TRAMPAS Y PROYECTILES ]] --
local function CheckIncomingProjectilesAndTraps()
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    for _, obj in pairs(workspace:GetChildren()) do
        local isProjectile = Settings.DodgeProjectiles and (obj.Name == "Track" or obj.Name == "Bus" or obj.Name == "Rocket" or obj.Name == "Boba")
        local isTrap = Settings.AvoidTraps and (obj.Name == "BearTrap" or obj.Name == "Saw" or obj.Name == "Acid")
        
        if isProjectile or isTrap then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = (root.Position - part.Position).Magnitude
                if dist < 20 then
                    local dodgeDir = (root.Position - part.Position).Unit * 15
                    MoveToTargetSmooth(root.Position + Vector3.new(dodgeDir.Z, 0, -dodgeDir.X))
                    return true
                end
            end
        end
    end
    return false
end

-- [[ SELECCIÓN AVANZADA DE OBJETIVOS ]] --
local function GetTarget()
    local pot = {}
    local char = Player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local c = p.Character
            local h = c:FindFirstChildOfClass("Humanoid")
            local tRoot = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart

            if not tRoot and Settings.TrackInvisibles then
                tRoot = c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
            end

            if tRoot and h and h.Health > 0 then
                local isBlocked = false

                -- Detección de Inmunidad (Diamond / Megarock)
                if Settings.BypassImmune and (c:FindFirstChild("rock") or c:FindFirstChild("Diamond")) then
                    isBlocked = true
                end

                -- Detección de Counters
                if not isBlocked and Settings.AntiCounter then
                    for _, cg in pairs(CounterGloves) do
                        if c:FindFirstChild(cg) and c:FindFirstChild("SelectionBox") then 
                            isBlocked = true
                            break
                        end
                    end
                end

                if not isBlocked then
                    if math.abs(myRoot.Position.Y - tRoot.Position.Y) < 16 then
                        table.insert(pot, {
                            player = p, 
                            character = c, 
                            root = tRoot, 
                            hp = h.Health,
                            isKS = c:FindFirstChild("Killstreak") ~= nil
                        })
                    end
                end
            end
        end
    end

    if #pot == 0 then 
        TargetHighlight.Parent = nil
        return nil 
    end

    local selected = nil
    if Settings.TargetKillstreaks then
        for _, entry in pairs(pot) do
            if entry.isKS then 
                selected = entry 
                break
            end
        end
    end

    if not selected then
        if Settings.BotType == "LowestHP" or Settings.PriorityLowHP then
            table.sort(pot, function(a, b) return a.hp < b.hp end)
        else
            table.sort(pot, function(a, b) 
                return (myRoot.Position - a.root.Position).Magnitude < (myRoot.Position - b.root.Position).Magnitude
            end)
        end
        selected = pot[1]
    end

    if selected and Settings.TargetVisualizer then
        TargetHighlight.Parent = selected.character
    else
        TargetHighlight.Parent = nil
    end

    return selected
end

-- [[ INTERFAZ GRÁFICA (GUI) ]] --
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MacroUI"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = Player:WaitForChild("PlayerGui") end

local StatFrame = Instance.new("Frame", ScreenGui)
StatFrame.Size = UDim2.new(0, 190, 0, 80)
StatFrame.Position = UDim2.new(0, 10, 0.35, 0)
StatFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
StatFrame.BackgroundTransparency = 0.2
Instance.new("UICorner", StatFrame)

local StatText = Instance.new("TextLabel", StatFrame)
StatText.Size = UDim2.new(1, -10, 1, -10)
StatText.Position = UDim2.new(0, 5, 0, 5)
StatText.BackgroundTransparency = 1
StatText.TextColor3 = Color3.new(1, 1, 1)
StatText.TextSize = 12
StatText.TextXAlignment = Enum.TextXAlignment.Left

task.spawn(function()
    while true do
        task.wait(1)
        local elapsed = math.max(1, tick() - StartTime)
        local gained = GetSlaps() - SessionStartSlaps
        local rate = math.floor((gained / elapsed) * 3600)
        StatText.Text = string.format("📊 SESIÓN MACRO v9.0\nSlaps Ganados: %d\nSlaps/Hora: %d\nMuertes: %d\nTiempo: %ds", gained, rate, DeathsCount, math.floor(elapsed))
    end
end)

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 500, 0, 340)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -170)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Instance.new("UICorner", MainFrame)

local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size = UDim2.new(0, 120, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Instance.new("UICorner", Sidebar)

local SideList = Instance.new("UIListLayout", Sidebar)
SideList.Padding = UDim.new(0, 2)

local Container = Instance.new("Frame", MainFrame)
Container.Size = UDim2.new(1, -140, 1, -50)
Container.Position = UDim2.new(0, 130, 0, 40)
Container.BackgroundTransparency = 1

local TabFrames = {}
local function CreateTab(name)
    local btn = Instance.new("TextButton", Sidebar)
    btn.Size = UDim2.new(1, 0, 0, 35)
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BorderSizePixel = 0
    
    local page = Instance.new("ScrollingFrame", Container)
    page.Size = UDim2.new(1, 0, 1, 0)
    page.Visible = false
    page.BackgroundTransparency = 1
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ScrollBarThickness = 2
    
    local list = Instance.new("UIListLayout", page)
    list.Padding = UDim.new(0, 8)
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
        page.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20) 
    end)
    
    btn.MouseButton1Click:Connect(function() 
        for _, v in pairs(TabFrames) do v.Visible = false end 
        page.Visible = true 
    end)
    TabFrames[name] = page
    return page
end

local function AddSlider(parent, text, min, max, default, callback)
    local actualDefault = Settings[text] or default
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, -10, 0, 45)
    f.BackgroundTransparency = 1
    
    local l = Instance.new("TextLabel", f)
    l.Text = text..": "..actualDefault
    l.Size = UDim2.new(1, 0, 0, 20)
    l.TextColor3 = Color3.new(1,1,1)
    l.BackgroundTransparency = 1
    l.TextXAlignment = Enum.TextXAlignment.Left
    
    local val = actualDefault
    local function update(nV) 
        val = math.clamp(nV, min, max)
        l.Text = text..": "..val
        callback(val)
        SaveSettings() 
    end
    
    local mi = Instance.new("TextButton", f); mi.Size = UDim2.new(0,35,0,25); mi.Position = UDim2.new(0,0,0,20); mi.Text = "-"; mi.BackgroundColor3 = Color3.fromRGB(60,60,60); mi.TextColor3 = Color3.new(1,1,1)
    local pl = Instance.new("TextButton", f); pl.Size = UDim2.new(0,35,0,25); pl.Position = UDim2.new(1,-35,0,20); pl.Text = "+"; pl.BackgroundColor3 = Color3.fromRGB(60,60,60); pl.TextColor3 = Color3.new(1,1,1)
    
    mi.MouseButton1Click:Connect(function() update(val - 1) end)
    pl.MouseButton1Click:Connect(function() update(val + 1) end)
end

local function AddToggle(parent, text, settingKey)
    local default = Settings[settingKey]
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, -10, 0, 30)
    f.BackgroundTransparency = 1
    
    local l = Instance.new("TextLabel", f)
    l.Text = text
    l.Size = UDim2.new(0.7, 0, 1, 0)
    l.TextColor3 = Color3.new(1,1,1)
    l.BackgroundTransparency = 1
    l.TextXAlignment = Enum.TextXAlignment.Left
    
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.new(0, 45, 0, 22)
    b.Position = UDim2.new(1, -50, 0.5, -11)
    b.Text = ""
    
    local function setVisual(val) 
        b.BackgroundColor3 = val and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(200, 50, 50) 
    end
    setVisual(default)
    Instance.new("UICorner", b)
    
    b.MouseButton1Click:Connect(function() 
        Settings[settingKey] = not Settings[settingKey]
        setVisual(Settings[settingKey])
        SaveSettings()
    end)
end

-- CREACIÓN DE PESTAÑAS
local MainTab = CreateTab("Main")
local CombatTab = CreateTab("Combat")
local FeaturesTab = CreateTab("Tactics/World")
local ServerTab = CreateTab("Server")

-- MAIN TAB
local StartBtn = Instance.new("TextButton", MainTab)
StartBtn.Size = UDim2.new(1,-10,0,50)
StartBtn.Text = Settings.Enabled and "STOP MACRO" or "START MACRO"
StartBtn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(180,0,50) or Color3.fromRGB(0,180,50)
StartBtn.TextColor3 = Color3.new(1,1,1)

StartBtn.MouseButton1Click:Connect(function()
    Settings.Enabled = not Settings.Enabled
    StartBtn.Text = Settings.Enabled and "STOP MACRO" or "START MACRO"
    StartBtn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(180,0,50) or Color3.fromRGB(0,180,50)
    SaveSettings()
end)

local ToggleHUD = Instance.new("TextButton", MainTab)
ToggleHUD.Size = UDim2.new(1,-10,0,35)
ToggleHUD.Text = "Toggle Stats HUD"
ToggleHUD.BackgroundColor3 = Color3.fromRGB(50,50,50)
ToggleHUD.TextColor3 = Color3.new(1,1,1)
ToggleHUD.MouseButton1Click:Connect(function()
    StatFrame.Visible = not StatFrame.Visible
end)

-- COMBAT TAB
AddSlider(CombatTab, "Slap Radius", 5, 20, 10, function(v) Settings.SlapRadius = v end)
AddToggle(CombatTab, "Shiftlock Mode", "Shiftlock")
AddSlider(CombatTab, "Shiftlock Radius", 5, 50, 20, function(v) Settings.ShiftlockRadius = v end)
AddToggle(CombatTab, "Strafe Around Player", "StrafeEnabled")
AddSlider(CombatTab, "Strafe Radius", 5, 30, 15, function(v) Settings.StrafeRadius = v end)
AddToggle(CombatTab, "Priority Low HP Targets", "PriorityLowHP")
AddToggle(CombatTab, "Bypass Immune (Diamond/Rock)", "BypassImmune")
AddToggle(CombatTab, "Auto Ability (E)", "AutoAbility")

-- FEATURES TAB
AddToggle(FeaturesTab, "Avoid Map Traps", "AvoidTraps")
AddToggle(FeaturesTab, "Auto Collect Orbs/Slapples", "AutoCollectOrbs")
AddToggle(FeaturesTab, "Auto Collect Plates", "AutoCollectPlates")
AddToggle(FeaturesTab, "Edge Anti-Fall Guard", "EdgeGuard")
AddToggle(FeaturesTab, "Dodge Projectiles", "DodgeProjectiles")
AddToggle(FeaturesTab, "Anti-Knockback Guard", "AntiKnockbackGuard")
AddToggle(FeaturesTab, "Anti-Counter Protection", "AntiCounter")
AddToggle(FeaturesTab, "Target Killstreaks", "TargetKillstreaks")
AddToggle(FeaturesTab, "Anti-Void Guard", "AntiVoid")
AddToggle(FeaturesTab, "Smart Shield / Dodge", "SmartShield")
AddToggle(FeaturesTab, "Lobby Ghost Safety", "GhostLobbySafety")
AddToggle(FeaturesTab, "Track Invisibles", "TrackInvisibles")
AddToggle(FeaturesTab, "Target Visualizer", "TargetVisualizer")

-- SERVER TAB
local HopNow = Instance.new("TextButton", ServerTab)
HopNow.Size = UDim2.new(1,-10,0,40)
HopNow.Text = "SERVER HOP NOW"
HopNow.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
HopNow.TextColor3 = Color3.new(1,1,1)
HopNow.MouseButton1Click:Connect(ServerHop)

AddToggle(ServerTab, "Smart Auto Server Hop", "SmartServerHop")
AddSlider(ServerTab, "Min Players Threshold", 1, 10, 3, function(v) Settings.MinPlayers = v end)

MINIMIZAR INTERFAZ
local Plus = Instance.new("TextButton", ScreenGui); Plus.Size = UDim2.new(0,45,0,45); Plus.Position = UDim2.new(0.05,0,0.05,0); Plus.Text = "+"; Plus.Visible = false; Plus.BackgroundColor3 = Color3.fromRGB(0,180,50); Instance.new("UICorner", Plus).CornerRadius = UDim.new(1,0)
local Minus = Instance.new("TextButton", MainFrame); Minus.Size = UDim2.new(0,30,0,30); Minus.Position = UDim2.new(1,-35,0,5); Minus.Text = "-"; Minus.BackgroundTransparency = 1; Minus.TextColor3 = Color3.new(1,1,1); Minus.TextSize = 25
Minus.MouseButton1Click:Connect(function() MainFrame.Visible = false; Plus.Visible = true end)
Plus.MouseButton1Click:Connect(function() MainFrame.Visible = true; Plus.Visible = false end)

-- [[ BUCLE PRINCIPAL DE COMBATE ]] --
RunService.Heartbeat:Connect(function()
    if not Settings.Enabled then return end
    
    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not hum or hum.Health <= 0 then return end

    -- 1. SMART SERVER HOP (SI HAY POCOS JUGADORES)
    if Settings.SmartServerHop and #Players:GetPlayers() < Settings.MinPlayers then
        ServerHop()
        return
    end

    -- 2. PROTECCIÓN DE LOBBY / SPAWN
    if Settings.GhostLobbySafety then
        local lobby = workspace:FindFirstChild("Lobby")
        if lobby and (root.Position - lobby.PrimaryPart.Position).Magnitude < 80 then
            task.wait(1.5)
        end
    end

    -- 3. SISTEMA ANTI-VOID
    if Settings.AntiVoid and root.Position.Y < -10 then
        hum.Jump = true
        TriggerAbility()
        return
    end

    -- 4. ESQUIVA DE PROYECTILES Y TRAMPAS
    if CheckIncomingProjectilesAndTraps() then
        return
    end

    -- 5. RECOLECCIÓN DE OBJETOS DEL MAPA
    local collectablePos = GetNearestCollectable()
    if collectablePos then
        MoveToTargetSmooth(collectablePos)
        return
    end

    -- 6. GESTIÓN DE EQUIPAMIENTO
    local toolInChar = char:FindFirstChildOfClass("Tool")
    local toolInBackpack = Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChildOfClass("Tool")

    if not toolInChar and toolInBackpack then 
        hum:EquipTool(toolInBackpack) 
    end

    -- 7. BÚSQUEDA Y LÓGICA DE COMBATE
    local targetData = GetTarget()
    if targetData and targetData.root then
        local tRoot = targetData.root
        local dist = (root.Position - tRoot.Position).Magnitude

        -- Smart Shield / Dodge
        if Settings.SmartShield and dist < 12 then
            local enemyChar = targetData.player.Character
            if enemyChar and enemyChar:FindFirstChildOfClass("Tool") then
                local toolName = enemyChar:FindFirstChildOfClass("Tool").Name
                if table.find(OneShotGloves, toolName) then
                    hum.Jump = true
                end
            end
        end

        -- Movimiento
        if Settings.StrafeEnabled and dist <= Settings.StrafeRadius then
            local speed = 4 
            local t = tick() * speed
            local offset = Vector3.new(math.cos(t) * Settings.DistanceRadius, 0, math.sin(t) * Settings.DistanceRadius)
            MoveToTargetSmooth(tRoot.Position + offset)
        else
            MoveToTargetSmooth(tRoot.Position)
        end

        -- Bofetada
        if dist <= Settings.SlapRadius and toolInChar then 
            toolInChar:Activate()
        end
    end
end)

MainTab.Visible = true
