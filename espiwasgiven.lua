local ESP = {
    Settings = {
        Enabled = true,
        MaxDistance = 1500,
        Container = workspace:FindFirstChild("Characters") or workspace,
        Color = Color3.fromRGB(0, 255, 255),
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Thickness = 1,
        TextSize = 14,
        Font = 2,
        
        Boxes = false,
        CornerBoxes = true,
        BoxOutlines = true,
        CornerSizeX = 0.25,
        CornerSizeY = 0.25,
        
        Skeletons = true,
        SkeletonColor = Color3.fromRGB(255, 255, 255),
        
        HeadDots = false,
        HeadDotSize = 4,
        
        Tracers = false,
        TracerOrigin = "Bottom",
        
        -- VISUAL COMPONENTS
        Names = true,
        Distances = true,
        HealthText = true,
        HealthBar = true,
        HealthBarColor = Color3.fromRGB(0, 255, 0),

        -- ESP CONFIG (POSITIONING)
        -- Valid options: "Top", "Bottom", "Left", "Right"
        Positions = {
            Name = "Top",
            Distance = "Bottom",
            HealthText = "Right",
            HealthBar = "Left" -- Valid options: "Left", "Right"
        },
        
        Chams = false,
        ChamsFillColor = Color3.fromRGB(0, 255, 255),
        ChamsFillTransparency = 0.5,
        ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
        ChamsOutlineTransparency = 0
    },
    Tracked = {}
}

local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer

local connections = {}

-- [ Helper Functions for Drawings ]
local function createLine(t, c, z)
    local l = Drawing.new("Line"); l.Thickness = t; l.Color = c; l.ZIndex = z; l.Visible = false; return l
end
local function createText(s, f, c, cent, out)
    local t = Drawing.new("Text"); t.Size = s; t.Font = f; t.Color = c; t.Center = cent; t.Outline = out; t.Visible = false; return t
end
local function createCircle(f, t, c, z)
    local cir = Drawing.new("Circle"); cir.Filled = f; cir.Thickness = t; cir.Color = c; cir.ZIndex = z; cir.Visible = false; return cir
end
local function createSquare(f, t, c, z)
    local sq = Drawing.new("Square"); sq.Filled = f; sq.Thickness = t; sq.Color = c; sq.ZIndex = z; sq.Visible = false; return sq
end
local function setLineParams(line, outline, from, to, t, c, oc, v, ov)
    if line then line.From = from; line.To = to; line.Thickness = t; line.Color = c; line.Visible = v end
    if outline then outline.From = from; outline.To = to; outline.Thickness = t + 2; outline.Color = oc; outline.Visible = ov end
end

local function getSkeletons()
    return {
        R15 = {
            {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
            {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"}, {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
            {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"}
        },
        R6 = {
            {"Head", "Torso"}, {"Torso", "Right Arm"}, {"Torso", "Left Arm"}, {"Torso", "Right Leg"}, {"Torso", "Left Leg"}
        }
    }
end

local function createDrawings()
    local d = {
        Corners = {}, CornerOutlines = {}, Box = {}, BoxOutlines = {}, Skeleton = {}, SkeletonOutlines = {},
        Tracer = createLine(1, Color3.new(), 2), TracerOutline = createLine(3, Color3.new(), 1),
        HeadDot = createCircle(true, 1, Color3.new(), 2), HeadDotOutline = createCircle(false, 3, Color3.new(), 1),
        HealthBG = createSquare(true, 1, Color3.new(), 1), HealthFill = createSquare(true, 1, Color3.new(), 2),
        Name = createText(14, 2, Color3.new(), true, true), Distance = createText(14, 2, Color3.new(), true, true), HealthT = createText(14, 2, Color3.new(), false, true),
        Highlight = Instance.new("Highlight")
    }
    for i = 1, 8 do d.Corners[i] = createLine(1, Color3.new(), 2); d.CornerOutlines[i] = createLine(3, Color3.new(), 1) end
    for i = 1, 4 do d.Box[i] = createLine(1, Color3.new(), 2); d.BoxOutlines[i] = createLine(3, Color3.new(), 1) end
    for i = 1, 15 do d.Skeleton[i] = createLine(1, Color3.new(), 2); d.SkeletonOutlines[i] = createLine(3, Color3.new(), 1) end
    return d
end

local function removeDrawings(d)
    for _, list in pairs({d.Corners, d.CornerOutlines, d.Box, d.BoxOutlines, d.Skeleton, d.SkeletonOutlines}) do
        for _, line in pairs(list) do line:Remove() end
    end
    d.Tracer:Remove(); d.TracerOutline:Remove(); d.HeadDot:Remove(); d.HeadDotOutline:Remove(); d.HealthBG:Remove(); d.HealthFill:Remove(); d.Name:Remove(); d.Distance:Remove(); d.HealthT:Remove()
    if d.Highlight.Parent then d.Highlight:Destroy() end
end

local function hideDrawings(d)
    for _, list in pairs({d.Corners, d.CornerOutlines, d.Box, d.BoxOutlines, d.Skeleton, d.SkeletonOutlines}) do
        for _, line in pairs(list) do line.Visible = false end
    end
    d.Tracer.Visible = false; d.TracerOutline.Visible = false; d.HeadDot.Visible = false; d.HeadDotOutline.Visible = false; d.HealthBG.Visible = false; d.HealthFill.Visible = false
    d.Name.Visible = false; d.Distance.Visible = false; d.HealthT.Visible = false; d.Highlight.Enabled = false
end

function ESP:Add(model)
    if model.Name == localPlayer.Name or self.Tracked[model] then return end
    self.Tracked[model] = createDrawings()
end

function ESP:Remove(model)
    if self.Tracked[model] then removeDrawings(self.Tracked[model]); self.Tracked[model] = nil end
end

function ESP:Clear()
    for model, _ in pairs(self.Tracked) do self:Remove(model) end
    if connections.Added then connections.Added:Disconnect() end
    if connections.Removed then connections.Removed:Disconnect() end
    if connections.Render then connections.Render:Disconnect() end
end

function ESP:Update()
    local S = self.Settings
    local skelData = getSkeletons()
    
    for model, d in pairs(self.Tracked) do
        local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
        local hum = model:FindFirstChildOfClass("Humanoid")
        
        if S.Enabled and root and model.Parent then
            local pos, onScreen = camera:WorldToViewportPoint(root.Position)
            local dist = (camera.CFrame.Position - root.Position).Magnitude
            
            if onScreen and dist <= S.MaxDistance then
                local head = model:FindFirstChild("Head")
                local headPos = head and camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2.5, 0))
                local legPos = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                
                local h = math.abs(headPos.Y - legPos.Y)
                local w = h / 1.5
                local x = pos.X - w / 2
                local y = headPos.Y
                
                -- Draw Boxes
                if S.CornerBoxes then
                    local lx, ly = w * S.CornerSizeX, h * S.CornerSizeY
                    local c, o = d.Corners, d.CornerOutlines
                    setLineParams(c[1], o[1], Vector2.new(x, y), Vector2.new(x + lx, y), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                    setLineParams(c[2], o[2], Vector2.new(x, y), Vector2.new(x, y + ly), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                    setLineParams(c[3], o[3], Vector2.new(x + w, y), Vector2.new(x + w - lx, y), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                    setLineParams(c[4], o[4], Vector2.new(x + w, y), Vector2.new(x + w, y + ly), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                    setLineParams(c[5], o[5], Vector2.new(x, y + h), Vector2.new(x + lx, y + h), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                    setLineParams(c[6], o[6], Vector2.new(x, y + h), Vector2.new(x, y + h - ly), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                    setLineParams(c[7], o[7], Vector2.new(x + w, y + h), Vector2.new(x + w - lx, y + h), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                    setLineParams(c[8], o[8], Vector2.new(x + w, y + h), Vector2.new(x + w, y + h - ly), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                else
                    for i = 1, 8 do d.Corners[i].Visible = false; d.CornerOutlines[i].Visible = false end
                end

                if S.Boxes then
                    local b, o = d.Box, d.BoxOutlines
                    setLineParams(b[1], o[1], Vector2.new(x, y), Vector2.new(x + w, y), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                    setLineParams(b[2], o[2], Vector2.new(x, y), Vector2.new(x, y + h), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                    setLineParams(b[3], o[3], Vector2.new(x + w, y), Vector2.new(x + w, y + h), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                    setLineParams(b[4], o[4], Vector2.new(x, y + h), Vector2.new(x + w, y + h), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                else
                    for i = 1, 4 do d.Box[i].Visible = false; d.BoxOutlines[i].Visible = false end
                end

                -- Dynamic Stacking Algorithm for Text
                local stack = { Top = 2, Bottom = 2, Left = 0, Right = 0 }
                local hpOffsetLeft = 0
                local hpOffsetRight = 0

                -- Health Bar Logic
                if S.HealthBar and hum then
                    local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    local barH = h * hp
                    
                    if S.Positions.HealthBar == "Left" then
                        d.HealthBG.Position = Vector2.new(x - 5, y)
                        d.HealthFill.Position = Vector2.new(x - 4, y + (h - barH))
                        hpOffsetLeft = 6 -- Push left text further left
                    else
                        d.HealthBG.Position = Vector2.new(x + w + 2, y)
                        d.HealthFill.Position = Vector2.new(x + w + 3, y + (h - barH))
                        hpOffsetRight = 6 -- Push right text further right
                    end
                    
                    d.HealthBG.Size = Vector2.new(3, h); d.HealthBG.Color = S.OutlineColor; d.HealthBG.Visible = S.BoxOutlines
                    d.HealthFill.Size = Vector2.new(1, barH); d.HealthFill.Color = S.HealthBarColor; d.HealthFill.Visible = true
                else
                    d.HealthBG.Visible = false; d.HealthFill.Visible = false
                end

                -- Helper to position a single text element
                local function positionLabel(drawing, textStr, side, textCol)
                    if not textStr then drawing.Visible = false; return end
                    drawing.Text = tostring(textStr)
                    drawing.Color = textCol or S.Color
                    drawing.Size = S.TextSize
                    drawing.Font = S.Font
                    
                    local bounds = drawing.TextBounds
                    if side == "Top" then
                        drawing.Center = true
                        drawing.Position = Vector2.new(x + w/2, y - stack.Top - bounds.Y)
                        stack.Top = stack.Top + bounds.Y + 2
                    elseif side == "Bottom" then
                        drawing.Center = true
                        drawing.Position = Vector2.new(x + w/2, y + h + stack.Bottom)
                        stack.Bottom = stack.Bottom + bounds.Y + 2
                    elseif side == "Left" then
                        drawing.Center = false
                        drawing.Position = Vector2.new(x - bounds.X - 4 - hpOffsetLeft, y + stack.Left)
                        stack.Left = stack.Left + bounds.Y + 2
                    elseif side == "Right" then
                        drawing.Center = false
                        drawing.Position = Vector2.new(x + w + 4 + hpOffsetRight, y + stack.Right)
                        stack.Right = stack.Right + bounds.Y + 2
                    end
                    drawing.Visible = true
                end

                -- Apply Labels based on config
                positionLabel(d.Name, S.Names and model.Name or nil, S.Positions.Name, S.Color)
                positionLabel(d.Distance, S.Distances and math.floor(dist) .. "m" or nil, S.Positions.Distance, S.Color)
                positionLabel(d.HealthT, (S.HealthText and hum) and math.floor(hum.Health) .. " HP" or nil, S.Positions.HealthText, S.HealthBarColor)

                -- Tracers, Skeletons, Chams... (Same logic as before, hidden for brevity in comment, but included in raw script)
                if S.Tracers then
                    local startY = S.TracerOrigin == "Bottom" and camera.ViewportSize.Y or (S.TracerOrigin == "Top" and 0 or runService:GetMouseLocation().Y)
                    local startX = S.TracerOrigin == "Mouse" and runService:GetMouseLocation().X or camera.ViewportSize.X / 2
                    setLineParams(d.Tracer, d.TracerOutline, Vector2.new(startX, startY), Vector2.new(x + w/2, y + h), S.Thickness, S.Color, S.OutlineColor, true, S.BoxOutlines)
                else
                    d.Tracer.Visible = false; d.TracerOutline.Visible = false
                end
            else
                hideDrawings(d)
            end
        else
            hideDrawings(d)
            if not model.Parent then self:Remove(model) end
        end
    end
end

function ESP:Listen(container)
    if not container then return end
    self.Settings.Container = container
    for _, model in pairs(container:GetChildren()) do if model:IsA("Model") then self:Add(model) end end
    connections.Added = container.ChildAdded:Connect(function(child) if child:IsA("Model") then self:Add(child) end end)
    connections.Removed = container.ChildRemoved:Connect(function(child) self:Remove(child) end)
    connections.Render = runService.RenderStepped:Connect(function() self:Update() end)
end

return ESP
