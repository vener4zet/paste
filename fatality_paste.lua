-- Anti-Aim + ESP для фреймворка Fatality (вкладки: ANTI-AIM, VISUAL, MISC)
-- Anti-Aim: основные режимы (None, Backward, At Target, Spin) + отдельный Jitter
-- ESP: боксы (Corner/Full), трейсеры, здоровье, имена, расстояние, чеймсы
-- В MISC: кнопки Infinite Yield, Stretch и Unload (полная выгрузка с улучшенным поиском GUI)
-- At Target игнорирует вертикальную составляющую

-- Загрузка Fatality
local Fatality = loadstring(game:HttpGet("https://raw.githubusercontent.com/4lpaca-pin/Fatality/refs/heads/main/src/source.luau"))();
local Notification = Fatality:CreateNotifier();

Fatality:Loader({
    Name = "FATALITY",
    Duration = 4
});

Notification:Notify({
    Title = "FATALITY",
    Content = "Hello, "..game.Players.LocalPlayer.DisplayName..' Welcome back!',
    Icon = "clipboard"
})

local Window = Fatality.new({
    Name = "FATALITY",
    Expire = "never",
});

-- Создаём вкладки
local AntiAimTab = Window:AddMenu({
    Name = "ANTIAIM",
    Icon = "crosshair"
})

local VisualTab = Window:AddMenu({
    Name = "VISUAL",
    Icon = "eye"
})

local Misc = Window:AddMenu({
    Name = "MISC",
    Icon = "settings"
})

-- ==================== Сервисы Roblox ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==================== Anti-Aim часть ====================
local antiAimEnabled = false
local currentMode = "none"      -- none, backward, attarget, spin
local jitterEnabled = false     -- отдельный джиттер
local spinSpeed = 360           -- град/сек
local jitterRange = 30          -- град
local antiAimConnection = nil

local function updateAntiAimMode(newMode)
    currentMode = newMode
end

local function getClosestPlayer()
    local character = LocalPlayer.Character
    if not character then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local closestDist = math.huge
    local closestPlayer = nil
    local myPos = root.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local targetChar = player.Character
            if targetChar then
                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    local dist = (myPos - targetRoot.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestPlayer = player
                    end
                end
            end
        end
    end

    return closestPlayer
end

local function antiAimLoop(dt)
    if not antiAimEnabled then return end

    local character = LocalPlayer.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local pos = root.Position
    local currentCF = root.CFrame
    local finalCF = currentCF

    -- Основной режим
    if currentMode == "backward" then
        local camera = Workspace.CurrentCamera
        if camera then
            local camLook = camera.CFrame.LookVector
            local dir = -camLook
            dir = Vector3.new(dir.X, 0, dir.Z).Unit
            local targetPos = pos + dir * 10
            finalCF = CFrame.lookAt(pos, targetPos)
        end
    elseif currentMode == "attarget" then
        local targetPlayer = getClosestPlayer()
        if targetPlayer then
            local targetChar = targetPlayer.Character
            if targetChar then
                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    -- Игнорируем вертикаль: цель на той же высоте, что и игрок
                    local targetPosFlat = Vector3.new(targetRoot.Position.X, pos.Y, targetRoot.Position.Z)
                    local lookAt = CFrame.lookAt(pos, targetPosFlat)
                    finalCF = lookAt * CFrame.Angles(0, math.pi, 0)
                end
            end
        end
    elseif currentMode == "spin" then
        local rotStep = math.rad(spinSpeed * dt)
        finalCF = currentCF * CFrame.Angles(0, rotStep, 0)
    end

    -- Джиттер (применяется поверх основного режима, если включён)
    if jitterEnabled then
        local randomYaw = (math.random() * 2 - 1) * math.rad(jitterRange)
        finalCF = finalCF * CFrame.Angles(0, randomYaw, 0)
    end

    root.CFrame = finalCF
end

local function setAntiAimState(state)
    antiAimEnabled = state
    if state and not antiAimConnection then
        antiAimConnection = RunService.RenderStepped:Connect(antiAimLoop)
    elseif not state and antiAimConnection then
        antiAimConnection:Disconnect()
        antiAimConnection = nil
    end
end

-- ==================== ESP часть ====================
local ESP = {
    Enabled = false,
    TeamCheck = false,
    ShowTeam = false,
    BoxESP = false,
    BoxStyle = "Corner", -- Corner, Full
    BoxThickness = 1,
    TracerESP = false,
    TracerOrigin = "Bottom", -- Bottom, Top, Mouse, Center
    TracerThickness = 1,
    HealthESP = false,
    HealthStyle = "Bar", -- Bar, Text, Both
    NameESP = false,
    NameMode = "DisplayName",
    ShowDistance = true,
    DistanceUnit = "studs",
    TextSize = 14, -- фиксированный
    MaxDistance = 1000,
    RainbowEnabled = false,
    RainbowSpeed = 1,
    RainbowBoxes = false,
    RainbowTracers = false,
    RainbowText = false,
    ChamsEnabled = false,
    ChamsFillColor = Color3.fromRGB(255, 0, 0),
    ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
    ChamsOccludedColor = Color3.fromRGB(150, 0, 0),
    ChamsTransparency = 0.5,
    ChamsOutlineTransparency = 0,
    ChamsOutlineThickness = 0.1,
    EnemyColor = Color3.fromRGB(255, 25, 25),
    AllyColor = Color3.fromRGB(25, 255, 25),
    HealthColor = Color3.fromRGB(0, 255, 0)
}

local Drawings = {
    ESP = {},
}
local Highlights = {}
local Colors = {Rainbow = Color3.new(1,0,0)} -- для радуги

local function createESP(player)
    if player == LocalPlayer then return end
    
    local box = {
        TopLeft = Drawing.new("Line"),
        TopRight = Drawing.new("Line"),
        BottomLeft = Drawing.new("Line"),
        BottomRight = Drawing.new("Line"),
        Left = Drawing.new("Line"),
        Right = Drawing.new("Line"),
        Top = Drawing.new("Line"),
        Bottom = Drawing.new("Line")
    }
    for _, line in pairs(box) do
        line.Visible = false
        line.Color = ESP.EnemyColor
        line.Thickness = ESP.BoxThickness
    end
    
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = ESP.EnemyColor
    tracer.Thickness = ESP.TracerThickness
    
    local healthBar = {
        Outline = Drawing.new("Square"),
        Fill = Drawing.new("Square"),
        Text = Drawing.new("Text")
    }
    healthBar.Outline.Visible = false
    healthBar.Outline.Color = Color3.new(1,1,1)
    healthBar.Outline.Filled = false
    healthBar.Outline.Thickness = 1
    healthBar.Fill.Visible = false
    healthBar.Fill.Filled = true
    healthBar.Text.Visible = false
    healthBar.Text.Center = true
    healthBar.Text.Size = ESP.TextSize
    healthBar.Text.Color = ESP.HealthColor
    healthBar.Text.Font = 2
    
    local info = {
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text")
    }
    for _, text in pairs(info) do
        text.Visible = false
        text.Center = true
        text.Size = ESP.TextSize
        text.Color = ESP.EnemyColor
        text.Font = 2
        text.Outline = true
    end
    
    local snapline = Drawing.new("Line")
    snapline.Visible = false
    snapline.Color = ESP.EnemyColor
    snapline.Thickness = 1
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = ESP.ChamsFillColor
    highlight.OutlineColor = ESP.ChamsOutlineColor
    highlight.FillTransparency = ESP.ChamsTransparency
    highlight.OutlineTransparency = ESP.ChamsOutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false
    Highlights[player] = highlight
    
    Drawings.ESP[player] = {
        Box = box,
        Tracer = tracer,
        HealthBar = healthBar,
        Info = info,
        Snapline = snapline
    }
end

local function removeESP(player)
    local esp = Drawings.ESP[player]
    if esp then
        for _, obj in pairs(esp.Box) do obj:Remove() end
        esp.Tracer:Remove()
        for _, obj in pairs(esp.HealthBar) do obj:Remove() end
        for _, obj in pairs(esp.Info) do obj:Remove() end
        esp.Snapline:Remove()
        Drawings.ESP[player] = nil
    end
    local highlight = Highlights[player]
    if highlight then
        highlight:Destroy()
        Highlights[player] = nil
    end
end

local function getPlayerColor(player)
    if ESP.RainbowEnabled then
        if ESP.RainbowBoxes and ESP.BoxESP then return Colors.Rainbow end
        if ESP.RainbowTracers and ESP.TracerESP then return Colors.Rainbow end
        if ESP.RainbowText and (ESP.NameESP or ESP.HealthESP) then return Colors.Rainbow end
    end
    if player.Team and player.Team == LocalPlayer.Team then
        return ESP.AllyColor
    else
        return ESP.EnemyColor
    end
end

local function getTracerOrigin()
    local o = ESP.TracerOrigin
    local vp = Camera.ViewportSize
    if o == "Bottom" then return Vector2.new(vp.X/2, vp.Y)
    elseif o == "Top" then return Vector2.new(vp.X/2, 0)
    elseif o == "Mouse" then return UserInputService:GetMouseLocation()
    else return Vector2.new(vp.X/2, vp.Y/2) end
end

local function updateESP(player)
    if not ESP.Enabled then return end
    
    local esp = Drawings.ESP[player]
    if not esp then return end
    
    local character = player.Character
    if not character then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        return
    end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        return
    end
    
    local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
    if not onScreen or distance > ESP.MaxDistance then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        return
    end
    
    if ESP.TeamCheck and player.Team == LocalPlayer.Team and not ESP.ShowTeam then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        return
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        esp.Tracer.Visible = false
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
        for _, obj in pairs(esp.Info) do obj.Visible = false end
        esp.Snapline.Visible = false
        return
    end
    
    local color = getPlayerColor(player)
    local size = character:GetExtentsSize()
    local cf = rootPart.CFrame
    
    local top, topOn = Camera:WorldToViewportPoint(cf * CFrame.new(0, size.Y/2, 0).Position)
    local bottom, bottomOn = Camera:WorldToViewportPoint(cf * CFrame.new(0, -size.Y/2, 0).Position)
    if not topOn or not bottomOn then
        for _, obj in pairs(esp.Box) do obj.Visible = false end
        return
    end
    
    local screenSize = bottom.Y - top.Y
    local boxWidth = screenSize * 0.65
    local boxPos = Vector2.new(top.X - boxWidth/2, top.Y)
    local boxSize = Vector2.new(boxWidth, screenSize)
    
    -- Hide all box parts initially
    for _, obj in pairs(esp.Box) do obj.Visible = false end
    
    if ESP.BoxESP then
        if ESP.BoxStyle == "Corner" then
            local corner = boxWidth * 0.2
            esp.Box.TopLeft.From = boxPos
            esp.Box.TopLeft.To = boxPos + Vector2.new(corner, 0)
            esp.Box.TopLeft.Visible = true
            
            esp.Box.TopRight.From = boxPos + Vector2.new(boxSize.X, 0)
            esp.Box.TopRight.To = boxPos + Vector2.new(boxSize.X - corner, 0)
            esp.Box.TopRight.Visible = true
            
            esp.Box.BottomLeft.From = boxPos + Vector2.new(0, boxSize.Y)
            esp.Box.BottomLeft.To = boxPos + Vector2.new(corner, boxSize.Y)
            esp.Box.BottomLeft.Visible = true
            
            esp.Box.BottomRight.From = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.BottomRight.To = boxPos + Vector2.new(boxSize.X - corner, boxSize.Y)
            esp.Box.BottomRight.Visible = true
            
            esp.Box.Left.From = boxPos
            esp.Box.Left.To = boxPos + Vector2.new(0, corner)
            esp.Box.Left.Visible = true
            
            esp.Box.Right.From = boxPos + Vector2.new(boxSize.X, 0)
            esp.Box.Right.To = boxPos + Vector2.new(boxSize.X, corner)
            esp.Box.Right.Visible = true
            
            esp.Box.Top.From = boxPos + Vector2.new(0, boxSize.Y)
            esp.Box.Top.To = boxPos + Vector2.new(0, boxSize.Y - corner)
            esp.Box.Top.Visible = true
            
            esp.Box.Bottom.From = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Bottom.To = boxPos + Vector2.new(boxSize.X, boxSize.Y - corner)
            esp.Box.Bottom.Visible = true
        elseif ESP.BoxStyle == "Full" then
            esp.Box.Left.From = boxPos
            esp.Box.Left.To = boxPos + Vector2.new(0, boxSize.Y)
            esp.Box.Left.Visible = true
            esp.Box.Right.From = boxPos + Vector2.new(boxSize.X, 0)
            esp.Box.Right.To = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Right.Visible = true
            esp.Box.Top.From = boxPos
            esp.Box.Top.To = boxPos + Vector2.new(boxSize.X, 0)
            esp.Box.Top.Visible = true
            esp.Box.Bottom.From = boxPos + Vector2.new(0, boxSize.Y)
            esp.Box.Bottom.To = boxPos + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Bottom.Visible = true
        end
        
        for _, obj in pairs(esp.Box) do
            if obj.Visible then
                obj.Color = color
                obj.Thickness = ESP.BoxThickness
            end
        end
    end
    
    if ESP.TracerESP then
        esp.Tracer.From = getTracerOrigin()
        esp.Tracer.To = Vector2.new(pos.X, pos.Y)
        esp.Tracer.Color = color
        esp.Tracer.Visible = true
    else
        esp.Tracer.Visible = false
    end
    
    if ESP.HealthESP then
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        local healthPercent = health / maxHealth
        local barHeight = screenSize * 0.8
        local barWidth = 4
        local barPos = Vector2.new(boxPos.X - barWidth - 2, boxPos.Y + (screenSize - barHeight)/2)
        
        esp.HealthBar.Outline.Size = Vector2.new(barWidth, barHeight)
        esp.HealthBar.Outline.Position = barPos
        esp.HealthBar.Outline.Visible = true
        
        esp.HealthBar.Fill.Size = Vector2.new(barWidth - 2, barHeight * healthPercent)
        esp.HealthBar.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + barHeight * (1-healthPercent))
        esp.HealthBar.Fill.Color = Color3.fromRGB(255 - 255*healthPercent, 255*healthPercent, 0)
        esp.HealthBar.Fill.Visible = true
        
        if ESP.HealthStyle == "Text" or ESP.HealthStyle == "Both" then
            esp.HealthBar.Text.Text = math.floor(health) .. "HP"
            esp.HealthBar.Text.Position = Vector2.new(barPos.X + barWidth + 2, barPos.Y + barHeight/2)
            esp.HealthBar.Text.Visible = true
        else
            esp.HealthBar.Text.Visible = false
        end
    else
        for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
    end
    
    if ESP.NameESP then
        esp.Info.Name.Text = player.DisplayName
        esp.Info.Name.Position = Vector2.new(boxPos.X + boxWidth/2, boxPos.Y - 20)
        esp.Info.Name.Color = color
        esp.Info.Name.Visible = true
    else
        esp.Info.Name.Visible = false
    end
    
    if ESP.ShowDistance then
        esp.Info.Distance.Text = tostring(math.floor(distance)) .. " " .. ESP.DistanceUnit
        esp.Info.Distance.Position = Vector2.new(boxPos.X + boxWidth/2, boxPos.Y + screenSize + 5)
        esp.Info.Distance.Color = color
        esp.Info.Distance.Visible = true
    else
        esp.Info.Distance.Visible = false
    end
    
    -- Chams
    local highlight = Highlights[player]
    if highlight then
        if ESP.ChamsEnabled then
            highlight.Parent = character
            highlight.FillColor = ESP.ChamsFillColor
            highlight.OutlineColor = ESP.ChamsOutlineColor
            highlight.FillTransparency = ESP.ChamsTransparency
            highlight.OutlineTransparency = ESP.ChamsOutlineTransparency
            highlight.Enabled = true
        else
            highlight.Enabled = false
        end
    end
end

local function espLoop()
    if not ESP.Enabled then
        for _, player in ipairs(Players:GetPlayers()) do
            local esp = Drawings.ESP[player]
            if esp then
                for _, obj in pairs(esp.Box) do obj.Visible = false end
                esp.Tracer.Visible = false
                for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
                for _, obj in pairs(esp.Info) do obj.Visible = false end
                esp.Snapline.Visible = false
            end
        end
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not Drawings.ESP[player] then
                createESP(player)
            end
            updateESP(player)
        end
    end
end

local espConnection = RunService.RenderStepped:Connect(espLoop)

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then createESP(player) end
end

-- ==================== UI для ANTI-AIM ====================
local aaSection = AntiAimTab:AddSection({
    Name = "ANTI-AIM",
    Position = 'left'
})

aaSection:AddDropdown({
    Name = "Main Mode",
    Values = {"None", "Backward", "At Target", "Spin"},
    Default = "None",
    Callback = function(value)
        local modeMap = {
            ["None"] = "none",
            ["Backward"] = "backward",
            ["At Target"] = "attarget",
            ["Spin"] = "spin"
        }
        local newMode = modeMap[value] or "none"
        updateAntiAimMode(newMode)
        if newMode == "none" then
            setAntiAimState(false)
        else
            setAntiAimState(true)
        end
    end
})

aaSection:AddSlider({
    Name = "Spin Speed (deg/s)",
    Default = 360,
    Min = 10,
    Max = 2000,
    Type = "deg/s",
    Callback = function(val) spinSpeed = val end
})

-- Отдельная секция для Jitter
local jitterSection = AntiAimTab:AddSection({
    Name = "JITTER",
    Position = 'left'
})

jitterSection:AddToggle({
    Name = "Enable Jitter",
    Default = false,
    Callback = function(val) jitterEnabled = val end
})

jitterSection:AddSlider({
    Name = "Jitter Range (deg)",
    Default = 30,
    Min = 1,
    Max = 90,
    Type = "deg",
    Callback = function(val) jitterRange = val end
})

-- ==================== UI для VISUAL ====================
local espSection = VisualTab:AddSection({
    Name = "MAIN",
    Position = 'left'
})

espSection:AddToggle({
    Name = "Enable ESP",
    Default = false,
    Callback = function(val) ESP.Enabled = val end
})

espSection:AddToggle({
    Name = "Team Check",
    Default = false,
    Callback = function(val) ESP.TeamCheck = val end
})

espSection:AddToggle({
    Name = "Show Team",
    Default = false,
    Callback = function(val) ESP.ShowTeam = val end
})

local boxSection = VisualTab:AddSection({
    Name = "BOX",
    Position = 'left'
})

boxSection:AddToggle({
    Name = "Box ESP",
    Default = false,
    Callback = function(val) ESP.BoxESP = val end
})

boxSection:AddDropdown({
    Name = "Box Style",
    Values = {"Corner", "Full"},
    Default = "Corner",
    Callback = function(val) ESP.BoxStyle = val end
})

boxSection:AddSlider({
    Name = "Box Thickness",
    Default = 1,
    Min = 1,
    Max = 5,
    Callback = function(val) ESP.BoxThickness = val end
})

local tracerSection = VisualTab:AddSection({
    Name = "TRACER",
    Position = 'center'
})

tracerSection:AddToggle({
    Name = "Tracer ESP",
    Default = false,
    Callback = function(val) ESP.TracerESP = val end
})

tracerSection:AddDropdown({
    Name = "Tracer Origin",
    Values = {"Bottom", "Top", "Mouse", "Center"},
    Default = "Bottom",
    Callback = function(val) ESP.TracerOrigin = val end
})

tracerSection:AddSlider({
    Name = "Tracer Thickness",
    Default = 1,
    Min = 1,
    Max = 3,
    Callback = function(val) ESP.TracerThickness = val end
})

local healthSection = VisualTab:AddSection({
    Name = "HEALTH",
    Position = 'center'
})

healthSection:AddToggle({
    Name = "Health Bar",
    Default = false,
    Callback = function(val) ESP.HealthESP = val end
})

healthSection:AddDropdown({
    Name = "Health Style",
    Values = {"Bar", "Text", "Both"},
    Default = "Bar",
    Callback = function(val) ESP.HealthStyle = val end
})

local nameSection = VisualTab:AddSection({
    Name = "INFO",
    Position = 'right'
})

nameSection:AddToggle({
    Name = "Name ESP",
    Default = false,
    Callback = function(val) ESP.NameESP = val end
})

nameSection:AddToggle({
    Name = "Show Distance",
    Default = true,
    Callback = function(val) ESP.ShowDistance = val end
})

nameSection:AddSlider({
    Name = "Max Distance",
    Default = 1000,
    Min = 100,
    Max = 5000,
    Callback = function(val) ESP.MaxDistance = val end
})

local chamsSection = VisualTab:AddSection({
    Name = "CHAMS",
    Position = 'right'
})

chamsSection:AddToggle({
    Name = "Enable Chams",
    Default = false,
    Callback = function(val) ESP.ChamsEnabled = val end
})

chamsSection:AddColorPicker({
    Name = "Fill Color",
    Default = ESP.ChamsFillColor,
    Callback = function(val) ESP.ChamsFillColor = val end
})

chamsSection:AddColorPicker({
    Name = "Outline Color",
    Default = ESP.ChamsOutlineColor,
    Callback = function(val) ESP.ChamsOutlineColor = val end
})

chamsSection:AddColorPicker({
    Name = "Occluded Color",
    Default = ESP.ChamsOccludedColor,
    Callback = function(val) ESP.ChamsOccludedColor = val end
})

chamsSection:AddSlider({
    Name = "Fill Transparency",
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(val) ESP.ChamsTransparency = val end
})

chamsSection:AddSlider({
    Name = "Outline Transparency",
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(val) ESP.ChamsOutlineTransparency = val end
})

local colorSection = VisualTab:AddSection({
    Name = "COLORS",
    Position = 'center'
})

colorSection:AddColorPicker({
    Name = "Enemy Color",
    Default = ESP.EnemyColor,
    Callback = function(val) ESP.EnemyColor = val end
})

colorSection:AddColorPicker({
    Name = "Ally Color",
    Default = ESP.AllyColor,
    Callback = function(val) ESP.AllyColor = val end
})

colorSection:AddColorPicker({
    Name = "Health Color",
    Default = ESP.HealthColor,
    Callback = function(val) ESP.HealthColor = val end
})

local rainbowSection = VisualTab:AddSection({
    Name = "RAINBOW",
    Position = 'right'
})

rainbowSection:AddToggle({
    Name = "Rainbow Mode",
    Default = false,
    Callback = function(val) ESP.RainbowEnabled = val end
})

rainbowSection:AddSlider({
    Name = "Rainbow Speed",
    Default = 1,
    Min = 0.1,
    Max = 5,
    Callback = function(val) ESP.RainbowSpeed = val end
})

rainbowSection:AddDropdown({
    Name = "Rainbow Parts",
    Values = {"All", "Box Only", "Tracers Only", "Text Only"},
    Default = "All",
    Callback = function(val)
        if val == "All" then
            ESP.RainbowBoxes = true
            ESP.RainbowTracers = true
            ESP.RainbowText = true
        elseif val == "Box Only" then
            ESP.RainbowBoxes = true
            ESP.RainbowTracers = false
            ESP.RainbowText = false
        elseif val == "Tracers Only" then
            ESP.RainbowBoxes = false
            ESP.RainbowTracers = true
            ESP.RainbowText = false
        elseif val == "Text Only" then
            ESP.RainbowBoxes = false
            ESP.RainbowTracers = false
            ESP.RainbowText = true
        end
    end
})

-- ==================== Кнопки в MISC (левая колонка) ====================
local miscSectionLeft = Misc:AddSection({
    Name = "UTILITIES",
    Position = 'left'
})

miscSectionLeft:AddButton({
    Name = "Load Infinite Yield",
    Description = "Загрузить админ-скрипт Infinite Yield",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
    end
})

miscSectionLeft:AddButton({
    Name = "Stretch",
    Description = "Активировать эффект растяжения (Resolution)",
    Callback = function()
        getgenv().Resolution = {
            [".gg/scripters"] = 0.65
        }
        local Camera = workspace.CurrentCamera
        if getgenv().gg_scripters == nil then
            game:GetService("RunService").RenderStepped:Connect(
                function()
                    Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, getgenv().Resolution[".gg/scripters"], 0, 0, 0, 1)
                end
            )
        end
        getgenv().gg_scripters = "Aori0001"
    end
})

-- ==================== Кнопка Unload (правая колонка) с улучшенным поиском GUI ====================
local miscSectionRight = Misc:AddSection({
    Name = "UNLOAD",
    Position = 'right'
})

miscSectionRight:AddButton({
    Name = "Unload(Double Click)",
    Description = "Полностью выгрузить скрипт и закрыть UI",
    Callback = function()
        -- 1. Останавливаем Anti-Aim
        setAntiAimState(false)
        if antiAimConnection then
            antiAimConnection:Disconnect()
            antiAimConnection = nil
        end

        -- 2. Останавливаем ESP
        if espConnection then
            espConnection:Disconnect()
            espConnection = nil
        end

        -- 3. Удаляем все Drawing объекты ESP
        for _, player in ipairs(Players:GetPlayers()) do
            local esp = Drawings.ESP[player]
            if esp then
                for _, obj in pairs(esp.Box) do pcall(function() obj:Remove() end) end
                pcall(function() esp.Tracer:Remove() end)
                for _, obj in pairs(esp.HealthBar) do pcall(function() obj:Remove() end) end
                for _, obj in pairs(esp.Info) do pcall(function() obj:Remove() end) end
                pcall(function() esp.Snapline:Remove() end)
            end
        end
        Drawings.ESP = {}

        -- 4. Удаляем Highlight
        for _, highlight in pairs(Highlights) do
            pcall(function() highlight:Destroy() end)
        end
        Highlights = {}

        -- 5. Улучшенный поиск и уничтожение GUI Fatality
        print("=== Поиск GUI Fatality для выгрузки ===")
        local containers = {CoreGui, LocalPlayer:FindFirstChildOfClass("PlayerGui")}
        local destroyed = false

        -- Функция для поиска по заголовку "FATALITY"
        local function findGuiByTitle()
            for _, container in ipairs(containers) do
                if container then
                    -- Ищем все TextLabel с текстом "FATALITY" (название окна)
                    local function search(inst)
                        if inst:IsA("TextLabel") and inst.Text == "FATALITY" then
                            -- Нашли заголовок, поднимаемся до ScreenGui
                            local gui = inst:FindFirstAncestorOfClass("ScreenGui")
                            if gui then
                                return gui
                            end
                        end
                        for _, child in ipairs(inst:GetChildren()) do
                            local res = search(child)
                            if res then return res end
                        end
                    end
                    local gui = search(container)
                    if gui then
                        return gui
                    end
                end
            end
            return nil
        end

        -- Сначала пробуем найти по нашей кнопке "Unload Script(Double Click)"
        local function findGuiByButton()
            for _, container in ipairs(containers) do
                if container then
                    local function search(inst)
                        if inst:IsA("TextButton") and inst.Text == "Unload Script" then
                            local gui = inst:FindFirstAncestorOfClass("ScreenGui")
                            if gui then
                                return gui
                            end
                        end
                        for _, child in ipairs(inst:GetChildren()) do
                            local res = search(child)
                            if res then return res end
                        end
                    end
                    local gui = search(container)
                    if gui then
                        return gui
                    end
                end
            end
            return nil
        end

        local targetGui = findGuiByButton() or findGuiByTitle()

        if targetGui then
            print("Найден GUI:", targetGui:GetFullName())
            pcall(function() targetGui:Destroy() end)
            destroyed = true
            print("GUI уничтожен.")
        else
            print("Не удалось найти GUI по кнопке или заголовку. Вывожу список всех ScreenGui:")
            for _, container in ipairs(containers) do
                if container then
                    print("Контейнер:", container:GetFullName())
                    for _, gui in ipairs(container:GetChildren()) do
                        if gui:IsA("ScreenGui") then
                            print("  GUI:", gui.Name)
                            -- Ищем текстовые кнопки
                            local function listButtons(inst, indent)
                                indent = indent or "    "
                                for _, child in ipairs(inst:GetChildren()) do
                                    if child:IsA("TextButton") then
                                        print(indent .. "Кнопка:", child.Text)
                                    end
                                    listButtons(child, indent .. "  ")
                                end
                            end
                            listButtons(gui)
                        end
                    end
                end
            end
            print("Вы можете вручную уничтожить GUI, используя имя из списка, например:")
            print("game:GetService('CoreGui'):FindFirstChild('ИМЯ_GUI'):Destroy()")
        end

        -- 6. Очищаем переменные
        Window = nil
        Fatality = nil
        AntiAimTab = nil
        VisualTab = nil
        Misc = nil

        print("Fatality: скрипт полностью выгружен.")
    end
})

-- ==================== Инициализация ====================
updateAntiAimMode("none")

Notification:Notify({
    Title = "Anti-Aim + ESP",
    Content = "Загружено. Настройки во вкладках.",
    Duration = 3,
    Icon = "info"
})

-- ==================== Rainbow timer ====================
task.spawn(function()
    local rainbowHue = 0
    while task.wait(0.05) do
        if ESP.RainbowEnabled then
            rainbowHue = (rainbowHue + 0.01 * ESP.RainbowSpeed) % 1
            Colors.Rainbow = Color3.fromHSV(rainbowHue, 1, 1)
        end
    end
end)
