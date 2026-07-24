

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local PathfindingService = game:GetService("PathfindingService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local FileName = "MacroGloveConfig.json"

-- [[ CONFIGURACIÓN OPTIMIZADA ]] --
local Settings = {
    -- Configuración General
    Enabled = false,
    BotType = "Closest",
    IgnoreRagdoll = false,
    
    -- Radios con micro-variaciones (mantienen eficiencia)
    SlapRadius = 10,
    SlapRadiusVariance = 0.05,  -- Solo 5% variación
    ShiftlockRadius = 20,
    ShiftlockRadiusVariance = 0.05,
    StrafeRadius = 15,
    StrafeRadiusVariance = 0.08,
    DistanceRadius = 5,
    DistanceRadiusVariance = 0.10,
    
    -- Comportamiento
    Shiftlock = false,
    Jumps = false,
    JumpChance = 10,
    IgnoreOneshots = false,
    StrafeEnabled = false,
    UnequipFar = false,
    UnequipRadius = 30,
    DangerMode = false,
    DangerType = "Backoff",
    DangerHP = 40,
    AutoAbility = false,
    AbilityMode = "Combat",
    
    -- Configuración UD
    HumanErrorChance = 0.10,      -- 10% de errores humanos
    MaxErrorAngle = 3,             -- Máximo 3 grados de error
    MinReactionTime = 120,         -- 120ms (muy rápido)
    MaxReactionTime = 180,         -- 180ms (aún rápido)
    ErrorReactionTime = 300,       -- 300ms cuando hay error
    ErrorChance = 0.05,            -- 5% de errores de reacción
    DistractionIdle = 0.15,        -- 15% distracción inactivo
    DistractionCombat = 0.02,      -- 2% distracción combate
    FatigueEnabled = true,
    FatigueThreshold = 90,
    RestTimeMin = 3,
    RestTimeMax = 8,
    
    -- Server Hop
    ServerHopMode = "Main",
    MinPlayers = 0,
    IgnoreLowPlayers = false,
    AutoHopTimerEnabled = false,
    AutoHopMinutes = 30,
    HopOnOneshotsEnabled = false,
    MaxOneshotsAllowed = 1,
    LastHopTick = tick(),
    AutoTournament = false
}

-- [[ DATA TRACKING ]] --
local LastSlapCount = 0
local LastReachedTime = tick()
local LastClickTick = 0
local Fatiga = {
    nivel = 0,
    ultimoDescanso = tick(),
    enDescanso = false
}

local function GetSlaps()
    local stats = Player:FindFirstChild("leaderstats")
    local slaps = stats and stats:FindFirstChild("Slaps")
    return slaps and slaps.Value or 0
end
LastSlapCount = GetSlaps()

-- [[ SAVE / LOAD LOGIC ]] --
local function SaveSettings()
    local success, encoded = pcall(function() return HttpService:JSONEncode(Settings) end)
    if success then writefile(FileName, encoded) end
end

local function LoadSettings()
    if isfile(FileName) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(FileName)) end)
        if success then
            for k, v in pairs(decoded) do
                Settings[k] = v
            end
        end
    end
end
LoadSettings()

local GameIDs = { Main = 6403373529, NoOneshots = 9015014224, KS = 11520107397 }
local OneShotGloves = {"OVERKILL", "God's Hand", "The Flex", "Error", "rob", "Shopkeeper", "Spectator", "buddies"}

-- [[ FUNCIONES DE RADIO DINÁMICO (Mantiene Eficiencia) ]] --
local function ObtenerRadioOptimizado(radioBase, tipo)
    local variaciones = {
        Slap = Settings.SlapRadiusVariance,
        Shiftlock = Settings.ShiftlockRadiusVariance,
        Strafe = Settings.StrafeRadiusVariance,
        Distance = Settings.DistanceRadiusVariance,
    }
    
    local variance = variaciones[tipo] or 0.08
    local variacion = math.random(-variance * 100, variance * 100) / 100
    local radioFinal = radioBase * (1 + variacion)
    
    -- Mantener cerca del óptimo
    return math.clamp(radioFinal, radioBase * (1 - variance * 1.5), radioBase * (1 + variance * 1.5))
end

-- [[ MOVIMIENTO CON ERRORES SUTILES ]] --
local function MovimientoEficienteConError(posObjetivo)
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root or not hum then return end
    
    -- 90% del tiempo: movimiento directo (eficiente)
    if math.random(1, 100) <= 90 then
        hum:MoveTo(posObjetivo)
        return
    end
    
    -- 10% del tiempo: pequeño error humano (sutil)
    local errorAngulo = math.rad(math.random(-Settings.MaxErrorAngle, Settings.MaxErrorAngle))
    local dir = (posObjetivo - root.Position).Unit
    
    local errorX = math.cos(errorAngulo) * dir.X - math.sin(errorAngulo) * dir.Z
    local errorZ = math.sin(errorAngulo) * dir.X + math.cos(errorAngulo) * dir.Z
    
    hum:MoveTo(root.Position + Vector3.new(errorX * 2, 0, errorZ * 2))
end

-- [[ REACCIÓN RÁPIDA CON ERRORES OCASIONALES ]] --
local function TiempoReaccion()
    local baseTime = math.random(Settings.MinReactionTime, Settings.MaxReactionTime)
    
    -- 5% de las veces, reacción más lenta (error humano)
    if math.random(1, 100) <= Settings.ErrorChance * 100 then
        baseTime = Settings.ErrorReactionTime
    end
    
    return baseTime / 1000
end

-- [[ FATIGA INTELIGENTE ]] --
local function VerificarFatiga()
    if not Settings.FatigueEnabled then return false end
    
    local target = GetTarget()
    local enPeligro = false
    
    -- Verificar si hay enemigos cerca
    if target then
        local char = Player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    local dist = (root.Position - tRoot.Position).Magnitude
                    if dist < 30 then
                        enPeligro = true
                    end
                end
            end
        end
    end
    
    -- No descansar si hay peligro cercano
    if enPeligro then
        Fatiga.nivel = math.max(0, Fatiga.nivel - 0.5)
        return false
    end
    
    -- Aumentar fatiga gradualmente
    Fatiga.nivel = math.min(100, Fatiga.nivel + 0.05)
    
    -- Descansar si muy cansado y seguro
    if Fatiga.nivel > Settings.FatigueThreshold then
        Fatiga.enDescanso = true
        Fatiga.ultimoDescanso = tick()
        Fatiga.nivel = 0
        
        -- Movimiento mínimo durante descanso
        local char = Player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local pos = char.HumanoidRootPart.Position
                hum:MoveTo(pos + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5)))
            end
        end
        
        return true
    end
    
    return false
end

-- [[ DISTRACCIÓN ESTRATÉGICA ]] --
local function DistraccionInteligente()
    local target = GetTarget()
    local char = Player.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    -- Probabilidad según situación
    local prob = target and Settings.DistractionCombat or Settings.DistractionIdle
    
    if math.random(1, 100) <= prob * 100 then
        -- Distracción sutil
        if target then
            -- En combate: solo micro-movimientos
            if math.random(1, 100) <= 30 then
                hum.Jump = true
            end
        else
            -- Inactivo: movimientos más notables
            local anguloAleatorio = math.random(0, 360)
            local direccion = Vector3.new(
                math.cos(math.rad(anguloAleatorio)),
                0,
                math.sin(math.rad(anguloAleatorio))
            )
            
            -- Mirar en dirección aleatoria (si existe animación)
            local head = char:FindFirstChild("Head")
            if head then
                head.CFrame = CFrame.lookAt(head.Position, head.Position + direccion * 10)
            end
            
            -- Saltos aleatorios
            if math.random(1, 3) == 1 then
                hum.Jump = true
            end
            
            -- Movimiento aleatorio
            if math.random(1, 2) == 1 then
                hum:MoveTo(char.HumanoidRootPart.Position + direccion * 5)
            end
        end
    end
end

-- [[ SERVER HOP ]] --
local function ServerHop()
    SaveSettings()
    local targetID = GameIDs[Settings.ServerHopMode] or GameIDs.Main
    TeleportService:Teleport(targetID, Player)
end

-- [[ HABILIDADES ]] --
local function TriggerAbility()
    local char = Player.Character
    if not char or not char:FindFirstChildOfClass("Tool") then return end
    
    -- Tiempo de reacción humano para habilidad
    local tiempo = TiempoReaccion()
    task.wait(tiempo)
    
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.05 + math.random(0, 3) / 100)  -- Micro-variación
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function MoverConRuta(posObjetivo)
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root or not hum then return end
    
    local path = PathfindingService:CreatePath({
        AgentRadius = 3,
        AgentCanJump = true,
        AgentHeight = 5
    })
    
    path:ComputeAsync(root.Position, posObjetivo)
    
    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        if waypoints[2] then
            hum:MoveTo(waypoints[2].Position)
            if waypoints[2].Action == Enum.PathWaypointAction.Jump then
                hum.Jump = true
            end
        end
    else
        MovimientoEficienteConError(posObjetivo)
    end
end

-- [[ OBTENER OBJETIVO ]] --
local function GetTarget()
    local pot = {}
    local char = Player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    
    local myPos = myRoot.Position
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local c = p.Character
            local h = c:FindFirstChildOfClass("Humanoid")
            local tRoot = c:FindFirstChild("HumanoidRootPart")
            
            if tRoot and h and h.Health > 0 then
                -- Verificar OneShots
                local isOneshots = false
                for _, g in pairs(OneShotGloves) do
                    if c:FindFirstChild(g) or p.Backpack:FindFirstChild(g) then
                        isOneshots = true
                        break
                    end
                end
                
                if not Settings.IgnoreOneshots or not isOneshots then
                    -- Verificar ragdoll
                    if not Settings.IgnoreRagdoll or not c:FindFirstChild("Ragdolled") or not c.Ragdolled.Value then
                        -- Verificar altura
                        if math.abs(myPos.Y - tRoot.Position.Y) < 12 then
                            -- Verificar suelo
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = {c, Player.Character}
                            local floorCheck = workspace:Raycast(tRoot.Position, Vector3.new(0, -15, 0), rayParams)
                            
                            if floorCheck then
                                local dist = (myPos - tRoot.Position).Magnitude
                                if dist < 100 then  -- Rango máximo
                                    table.insert(pot, {player = p, distance = dist})
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if #pot == 0 then return nil end
    
    -- Ordenar según modo
    table.sort(pot, function(a, b)
        if Settings.BotType == "Closest" then
            return a.distance < b.distance
        elseif Settings.BotType == "Furthest" then
            return a.distance > b.distance
        end
        return false
    end)
    
    if Settings.BotType == "Random" then
        return pot[math.random(1, #pot)].player
    end
    
    return pot[1].player
end

-- [[ TOURNAMENT ]] --
local function HandleTournamentGUI()
    if tick() - LastClickTick < 1 then return end
    
    for _, gui in pairs(PlayerGui:GetChildren()) do
        if gui.Name == "Component" then
            local container = gui:FindFirstChild("SlapTournament")
            if container and container.Visible then
                local targetButton = Settings.AutoTournament and 
                    container:FindFirstChild("AcceptButton") or 
                    container:FindFirstChild("DeclineButton")
                
                if targetButton and targetButton.Visible then
                    local absPos = targetButton.AbsolutePosition
                    local absSize = targetButton.AbsoluteSize
                    local inset = GuiService:GetGuiInset()
                    local centerX = absPos.X + (absSize.X / 2) + inset.X
                    local centerY = absPos.Y + (absSize.Y / 2) + inset.Y
                    
                    -- Simular clic humano
                    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
                    task.wait(0.03 + math.random(0, 3) / 100)
                    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
                    
                    LastClickTick = tick()
                end
            end
        end
    end
end

-- [[ INTERFAZ DE USUARIO ]] --
local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 480, 0, 360)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Instance.new("UICorner", MainFrame)

-- Barra de título
local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
local TitleText = Instance.new("TextLabel", TitleBar)
TitleText.Size = UDim2.new(1, -30, 1, 0)
TitleText.Position = UDim2.new(0, 10, 0, 0)
TitleText.Text = "Slap Battles Macro v2.0"
TitleText.TextColor3 = Color3.new(1, 1, 1)
TitleText.BackgroundTransparency = 1
TitleText.TextXAlignment = 0

-- Barra de estado
local StatusBar = Instance.new("TextLabel", MainFrame)
StatusBar.Size = UDim2.new(1, -10, 0, 25)
StatusBar.Position = UDim2.new(0, 5, 1, -35)
StatusBar.Text = "Estado: Inactivo"
StatusBar.TextColor3 = Color3.new(0.6, 0.8, 1)
StatusBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
StatusBar.BackgroundTransparency = 0.5
Instance.new("UICorner", StatusBar)

-- Sidebar
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size = UDim2.new(0, 110, 1, -30)
Sidebar.Position = UDim2.new(0, 0, 0, 30)
Sidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Instance.new("UICorner", Sidebar)
local SideList = Instance.new("UIListLayout", Sidebar)
SideList.Padding = UDim.new(0, 2)

local Container = Instance.new("Frame", MainFrame)
Container.Size = UDim2.new(1, -130, 1, -70)
Container.Position = UDim2.new(0, 120, 0, 40)
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
    list.Padding = UDim.new(0, 10)
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20)
    end)
    
    btn.MouseButton1Click:Connect(function()
        for _, v in pairs(TabFrames) do
            v.Visible = false
        end
        page.Visible = true
    end)
    
    TabFrames[name] = page
    return page
end

-- Funciones UI
local function AddSlider(parent, text, min, max, default, callback, settingKey)
    local actualDefault = Settings[settingKey] or default
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, -10, 0, 45)
    f.BackgroundTransparency = 1
    
    local l = Instance.new("TextLabel", f)
    l.Text = text..": "..actualDefault
    l.Size = UDim2.new(1, 0, 0, 20)
    l.TextColor3 = Color3.new(1,1,1)
    l.BackgroundTransparency = 1
    l.TextXAlignment = 0
    
    local val = actualDefault
    local function update(nV)
        val = math.clamp(nV, min, max)
        l.Text = text..": "..val
        Settings[settingKey] = val
        callback(val)
        SaveSettings()
    end
    
    local mi = Instance.new("TextButton", f)
    mi.Size = UDim2.new(0,35,0,25)
    mi.Position = UDim2.new(0,0,0,20)
    mi.Text = "-"
    mi.BackgroundColor3 = Color3.fromRGB(60,60,60)
    mi.TextColor3 = Color3.new(1,1,1)
    
    local pl = Instance.new("TextButton", f)
    pl.Size = UDim2.new(0,35,0,25)
    pl.Position = UDim2.new(1,-35,0,20)
    pl.Text = "+"
    pl.BackgroundColor3 = Color3.fromRGB(60,60,60)
    pl.TextColor3 = Color3.new(1,1,1)
    
    mi.MouseButton1Click:Connect(function() update(val - 1) end)
    pl.MouseButton1Click:Connect(function() update(val + 1) end)
end

local function AddToggle(parent, text, settingKey, callback)
    local default = Settings[settingKey]
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, -10, 0, 30)
    f.BackgroundTransparency = 1
    
    local l = Instance.new("TextLabel", f)
    l.Text = text
    l.Size = UDim2.new(0.7, 0, 1, 0)
    l.TextColor3 = Color3.new(1,1,1)
    l.BackgroundTransparency = 1
    l.TextXAlignment = 0
    
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
        callback(Settings[settingKey])
        SaveSettings()
    end)
end

-- [[ CREAR TABS ]] --
local MainTab = CreateTab("Main")
local BotTab = CreateTab("Bot")
local ServerTab = CreateTab("Server")
local UDTab = CreateTab("UD Config")

-- [[ TAB PRINCIPAL ]] --
local StartBtn = Instance.new("TextButton", MainTab)
StartBtn.Size = UDim2.new(1,-10,0,50)
StartBtn.Text = Settings.Enabled and "STOP MACRO" or "START MACRO"
StartBtn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(180,0,50) or Color3.fromRGB(0,180,50)
StartBtn.TextColor3 = Color3.new(1,1,1)
StartBtn.MouseButton1Click:Connect(function()
    Settings.Enabled = not Settings.Enabled
    StartBtn.Text = Settings.Enabled and "STOP MACRO" or "START MACRO"
    StartBtn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(180,0,50) or Color3.fromRGB(0,180,50)
    LastReachedTime = tick()
    SaveSettings()
end)

-- [[ 
local BotTypeBtn = Instance.new("TextButton", BotTab)
BotTypeBtn.Size = UDim2.new(1,-10,0,30)
BotTypeBtn.Text = "Bot Type: "..Settings.BotType
BotTypeBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
BotTypeBtn.TextColor3 = Color3.new(1,1,1)
BotTypeBtn.MouseButton1Click:Connect(function()
    local modes = {"Closest", "Random", "Furthest"}
    local idx = table.find(modes, Settings.BotType) or 1
    Settings.BotType = modes[idx % #modes + 1]
    BotTypeBtn.Text = "Bot Type: "..Settings.BotType
    SaveSettings()
end)

AddToggle(BotTab, "Auto Go In Tournaments", "AutoTournament", function(v) end)
AddToggle(BotTab, "Ignore Ragdoll", "IgnoreRagdoll", function(v) end)
AddSlider(BotTab, "Slap Radius", 5, 20, 10, function(v) end, "SlapRadius")
AddToggle(BotTab, "Shiftlock Mode", "Shiftlock", function(v) end)
AddSlider(BotTab, "Shiftlock Radius", 5, 50, 20, function(v) end, "ShiftlockRadius")
AddToggle(BotTab, "Strafe Around Player", "StrafeEnabled", function(v) end)
AddSlider(BotTab, "Strafe Radius", 5, 30, 15, function(v) end, "StrafeRadius")
AddToggle(BotTab, "Jumps", "Jumps", function(v) end)
AddSlider(BotTab, "Jump Chance (%)", 1, 100, 10, function(v) end, "JumpChance")
AddToggle(BotTab, "Ignore Oneshots", "IgnoreOneshots", function(v) end)
AddSlider(BotTab, "Distance Radius", 0, 30, 5, function(v) end, "DistanceRadius")
AddToggle(BotTab, "Unequip Glove Far", "UnequipFar", function(v) end)
AddSlider(BotTab, "Unequip Radius", 5, 50, 30, function(v) end, "UnequipRadius")
AddToggle(BotTab, "Danger Mode", "DangerMode", function(v) end)

local DangerTypeBtn = Instance.new("TextButton", BotTab)
DangerTypeBtn.Size = UDim2.new(1,-10,0,30)
DangerTypeBtn.Text = "Danger Type: "..Settings.DangerType
DangerTypeBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
DangerTypeBtn.TextColor3 = Color3.new(1,1,1)
DangerTypeBtn.MouseButton1Click:Connect(function()
    local types = {"Backoff", "Give up", "Ahh"}
    local idx = table.find(types, Settings.DangerType) or 1
    Settings.DangerType = types[idx % #types + 1]
    DangerTypeBtn.Text = "Danger Type: "..Settings.DangerType
    SaveSettings()
end)

AddSlider(BotTab, "Danger HP", 10, 90, 40, function(v) end, "DangerHP")
AddToggle(BotTab, "Auto Ability (E)", "AutoAbility", function(v) end)

local AbilityModeBtn = Instance.new("TextButton", BotTab)
AbilityModeBtn.Size = UDim2.new(1,-10,0,30)
AbilityModeBtn.Text = "Ability Mode: "..Settings.AbilityMode
AbilityModeBtn.BackgroundColor3 = Color3.fromRGB(50,50,80)
AbilityModeBtn.TextColor3 = Color3.new(1,1,1)
AbilityModeBtn.MouseButton1Click:Connect(function()
    local modes = {"Combat", "Defensive", "Instant", "Combo", "Camping"}
    local idx = table.find(modes, Settings.AbilityMode) or 1
    Settings.AbilityMode = modes[idx % #modes + 1]
    AbilityModeBtn.Text = "Ability Mode: "..Settings.AbilityMode
    SaveSettings()
end)

-- [[ TAB SERVER ]] --
local HopNow = Instance.new("TextButton", ServerTab)
HopNow.Size = UDim2.new(1,-10,0,40)
HopNow.Text = "SERVER HOP NOW"
HopNow.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
HopNow.TextColor3 = Color3.new(1,1,1)
HopNow.MouseButton1Click:Connect(ServerHop)

local HopModeBtn = Instance.new("TextButton", ServerTab)
HopModeBtn.Size = UDim2.new(1,-10,0,30)
HopModeBtn.Text = "Mode: "..Settings.ServerHopMode
HopModeBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
HopModeBtn.TextColor3 = Color3.new(1,1,1)
HopModeBtn.MouseButton1Click:Connect(function()
    local modes = {"Main", "NoOneshots", "KS"}
    local idx = table.find(modes, Settings.ServerHopMode) or 1
    Settings.ServerHopMode = modes[idx % #modes + 1]
    HopModeBtn.Text = "Mode: "..Settings.ServerHopMode
    SaveSettings()
end)

AddSlider(ServerTab, "Hop if Players <", 0, 14, 0, function(v) end, "MinPlayers")
AddToggle(ServerTab, "Ignore Low Players", "IgnoreLowPlayers", function(v) end)
AddToggle(ServerTab, "Hop on Timer", "AutoHopTimerEnabled", function(v) end)
AddSlider(ServerTab, "Timer (Minutes)", 10, 300, 30, function(v) end, "AutoHopMinutes")
AddToggle(ServerTab, "Hop on Oneshots", "HopOnOneshotsEnabled", function(v) end)
AddSlider(ServerTab, "Oneshot Limit", 1, 5, 1, function(v) end, "MaxOneshotsAllowed")

-- [[ TAB UD ]] --
AddSlider(UDTab, "Human Error Chance %", 0, 30, 10, function(v) Settings.HumanErrorChance = v/100 end, "HumanErrorChance")
AddSlider(UDTab, "Max Error Angle", 1, 10, 3, function(v) Settings.MaxErrorAngle = v end, "MaxErrorAngle")
AddSlider(UDTab, "Min Reaction (ms)", 50, 300, 120, function(v) Settings.MinReactionTime = v end, "MinReactionTime")
AddSlider(UDTab, "Max Reaction (ms)", 100, 500, 180, function(v) Settings.MaxReactionTime = v end, "MaxReactionTime")
AddSlider(UDTab, "Error Reaction (ms)", 200, 800, 300, function(v) Settings.ErrorReactionTime = v end, "ErrorReactionTime")
AddSlider(UDTab, "Error Chance %", 0, 20, 5, function(v) Settings.ErrorChance = v/100 end, "ErrorChance")
AddToggle(UDTab, "Fatigue System", "FatigueEnabled", function(v) end)

-- [[ MINIMIZAR ]] --
local Plus = Instance.new("TextButton", ScreenGui)
Plus.Size = UDim2.new(0,45,0,45)
Plus.Position = UDim2.new(0.05,0,0.05,0)
Plus.Text = "+"
Plus.Visible = false
Plus.BackgroundColor3 = Color3.fromRGB(0,180,50)
Instance.new("UICorner", Plus).CornerRadius = UDim.new(1,0)

local Minus = Instance.new("TextButton", MainFrame)
Minus.Size = UDim2.new(0,30,0,30)
Minus.Position = UDim2.new(1,-35,0,5)
Minus.Text = "-"
Minus.BackgroundTransparency = 1
Minus.TextColor3 = Color3.new(1,1,1)
Minus.TextSize = 25
Minus.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    Plus.Visible = true
end)
Plus.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    Plus.Visible = false
end)

-- [[ BUCLE PRINCIPAL ]] --
RunService.Heartbeat:Connect(function()
    HandleTournamentGUI()
    
    if not Settings.Enabled then
        LastReachedTime = tick()
        StatusBar.Text = "Estado: Inactivo"
        return
    end
    
    StatusBar.Text = "Estado: Activo"
    
    -- Verificar fatiga
    if VerificarFatiga() then
        StatusBar.Text = "Estado: Descansando"
        return
    end
    
    local char = Player.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root or not hum then return end
    
    -- Simular comportamiento humano
    SimularHumanoEficiente()
    DistraccionInteligente()
    
    -- Verificar herramientas
    local toolInChar = char:FindFirstChildOfClass("Tool")
    local toolInBackpack = Player.Backpack:FindFirstChildOfClass("Tool")
    
    -- Torneo abierto?
    local tourneyOpen = false
    for _, gui in pairs(PlayerGui:GetChildren()) do
        if gui.Name == "Component" then
            local container = gui:FindFirstChild("SlapTournament")
            if container and container.Visible then
                tourneyOpen = true
                break
            end
        end
    end
    
    if not toolInChar and not toolInBackpack then
        if tourneyOpen and Settings.AutoTournament then
            hum:Move(Vector3.new(0,0,0))
            return
        end
        
        local teleport = workspace:FindFirstChild("Lobby") and workspace.Lobby:FindFirstChild("Teleport1")
        if teleport then
            MoverConRuta(teleport.Position)
        end
        LastReachedTime = tick()
        return
    end
    
    -- Saltos
    if Settings.Jumps and math.random(1, 100) <= Settings.JumpChance then
        hum.Jump = true
    end
    
    -- Obtener objetivo
    local target = GetTarget()
    if target and target.Character then
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if tRoot then
            local dist = (root.Position - tRoot.Position).Magnitude
            
            -- Radios optimizados
            local slapRadius = ObtenerRadioOptimizado(Settings.SlapRadius, "Slap")
            local strafeRadius = ObtenerRadioOptimizado(Settings.StrafeRadius, "Strafe")
            local shiftlockRadius = ObtenerRadioOptimizado(Settings.ShiftlockRadius, "Shiftlock")
            local distanceRadius = ObtenerRadioOptimizado(Settings.DistanceRadius, "Distance")
            
            -- Actualizar tiempo de alcance
            if dist <= (slapRadius + 5) then
                LastReachedTime = tick()
            end
            
            -- Timeout (45 segundos sin progreso)
            if tick() - LastReachedTime > 45 then
                LastReachedTime = tick()
                hum.Health = 0
                return
            end
            
            -- Shiftlock
            if Settings.Shiftlock and dist <= shiftlockRadius then
                root.CFrame = CFrame.lookAt(
                    root.Position,
                    Vector3.new(tRoot.Position.X, root.Position.Y, tRoot.Position.Z)
                )
            end
            
            -- Equipar/Desequipar
            if Settings.UnequipFar then
                if dist > Settings.UnequipRadius then
                    hum:UnequipTools()
                elseif dist <= Settings.UnequipRadius and toolInBackpack then
                    hum:EquipTool(toolInBackpack)
                end
            elseif toolInBackpack then
                hum:EquipTool(toolInBackpack)
            end
            
            -- Movimiento
            if Settings.StrafeEnabled and dist <= strafeRadius then
                local speed = 4
                local time = tick() * speed
                local offset = Vector3.new(
                    math.cos(time) * distanceRadius,
                    0,
                    math.sin(time) * distanceRadius
                )
                MovimientoEficienteConError(tRoot.Position + offset)
            elseif dist > distanceRadius then
                MovimientoEficienteConError(tRoot.Position)
            end
            
            -- Ataque
            if dist <= slapRadius and toolInChar then
                local tiempo = TiempoReaccion()
                task.wait(tiempo)
                toolInChar:Activate()
            end
        end
    else
        LastReachedTime = tick()
    end
end)

-- [[ BUCLE DE HABILIDADES ]] --
task.spawn(function()
    while true do
        task.wait(0.1)
        if not Settings.Enabled or not Settings.AutoAbility then continue end
        
        local char = Player.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if not tool then continue end
        
        local target = GetTarget()
        local dist = 999
        if target and target.Character then
            local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
            if tRoot and char.HumanoidRootPart then
                dist = (char.HumanoidRootPart.Position - tRoot.Position).Magnitude
            end
        end
        
        local abilityUsed = false
        
        if Settings.AbilityMode == "Combat" then
            if dist <= 15 then
                TriggerAbility()
                abilityUsed = true
            end
        elseif Settings.AbilityMode == "Defensive" then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if (dist > 15 and dist < 30) or (hum and hum.Health < Settings.DangerHP) then
                TriggerAbility()
                abilityUsed = true
            end
        elseif Settings.AbilityMode == "Instant" then
            TriggerAbility()
            abilityUsed = true
        elseif Settings.AbilityMode == "Combo" then
            local currentSlaps = GetSlaps()
            if currentSlaps > LastSlapCount then
                task.wait(0.3 + math.random(0, 2) / 10)
                TriggerAbility()
                abilityUsed = true
                LastSlapCount = currentSlaps
            end
        elseif Settings.AbilityMode == "Camping" then
            if dist > 50 then
                TriggerAbility()
                abilityUsed = true
            end
        end
        
        if abilityUsed then
            -- Cooldown variable humano
            task.wait(math.random(5, 15) / 10)
        end
        
        LastSlapCount = GetSlaps()
    end
end)

-- [[ SERVER HOP AUTOMÁTICO ]] --
task.spawn(function()
    while true do
        task.wait(60)  -- Check cada minuto
        
        if not Settings.Enabled then continue end
        
        -- Hop por timer
        if Settings.AutoHopTimerEnabled then
            if tick() - Settings.LastHopTick > Settings.AutoHopMinutes * 60 then
                Settings.LastHopTick = tick()
                ServerHop()
                continue
            end
        end
        
        -- Hop por jugadores
        if Settings.MinPlayers > 0 then
            local count = #Players:GetPlayers()
            if count < Settings.MinPlayers and not Settings.IgnoreLowPlayers then
                ServerHop()
                continue
            end
        end
        
        -- Hop por oneshots
        if Settings.HopOnOneshotsEnabled then
            local oneshotCount = 0
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= Player and p.Character then
                    for _, g in pairs(OneShotGloves) do
                        if p.Character:FindFirstChild(g) then
                            oneshotCount = oneshotCount + 1
                            break
                        end
                    end
                end
            end
            if oneshotCount > Settings.MaxOneshotsAllowed then
                ServerHop()
            end
        end
    end
end)

-- Mostrar primera tab
TabFrames["Main"].Visible = true
print("Slap Battles Macro v2.0 - Optimizado UD")
print("Cargado exitosamente!")
