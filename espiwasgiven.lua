if not getfenv().LPH_NO_VIRTUALIZE then getfenv().LPH_NO_VIRTUALIZE = function(f) return f end; end

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

        Names = true,
        Distances = true,
        HealthText = true,
        HealthBar = true,
        HealthBarColor = Color3.fromRGB(0, 255, 0),

        Positions = {
            Name = "Top",
            Distance = "Bottom",
            HealthText = "Right",
            HealthBar = "Left"
        },

        Chams = false,
        ChamsFillColor = Color3.fromRGB(0, 255, 255),
        ChamsFillTransparency = 0.5,
        ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
        ChamsOutlineTransparency = 0,

        Optimizations = {
            RefreshRate = 30,
            DistanceCull = true,
            MaxTargets = 0,
            LowDetailDistance = 600
        }
    },
    Tracked = {}
}

local cam = workspace.CurrentCamera;
local rs = game:GetService("RunService");
local plrs = game:GetService("Players");
local lp = plrs.LocalPlayer;
local cons = {};

local v2 = Vector2.new;
local flr = math.floor;
local clamp = math.clamp;
local abs = math.abs;
local sqrt = math.sqrt;

local hoff = Vector3.new(0, 0.5, 0);
local fhoff = Vector3.new(0, 2.5, 0);
local loff = Vector3.new(0, 3, 0);

local skels = {
    R15 = {
        {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
        {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
        {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"}
    },
    R6 = {
        {"Head","Torso"},{"Torso","Right Arm"},{"Torso","Left Arm"},{"Torso","Right Leg"},{"Torso","Left Leg"}
    }
}

local function mkln(t, c, z)
    local l = Drawing.new("Line"); l.Thickness = t; l.Color = c; l.ZIndex = z; l.Visible = false; return l;
end
local function mktxt(s, f, c, cn, o)
    local t = Drawing.new("Text"); t.Size = s; t.Font = f; t.Color = c; t.Center = cn; t.Outline = o; t.Visible = false; return t;
end
local function mkcir(f, t, c, z)
    local cr = Drawing.new("Circle"); cr.Filled = f; cr.Thickness = t; cr.Color = c; cr.ZIndex = z; cr.Visible = false; return cr;
end
local function mksq(f, t, c, z)
    local sq = Drawing.new("Square"); sq.Filled = f; sq.Thickness = t; sq.Color = c; sq.ZIndex = z; sq.Visible = false; return sq;
end
local function setln(ln, ol, from, to, t, c, oc, v, ov)
    if ln then ln.From = from; ln.To = to; ln.Thickness = t; ln.Color = c; ln.Visible = v; end
    if ol then ol.From = from; ol.To = to; ol.Thickness = t + 2; ol.Color = oc; ol.Visible = ov; end
end

local function mkdraw()
    local d = {
        Corners = {}, CornerOutlines = {}, Box = {}, BoxOutlines = {}, Skeleton = {}, SkeletonOutlines = {},
        Tracer = mkln(1, Color3.new(), 2), TracerOutline = mkln(3, Color3.new(), 1),
        HeadDot = mkcir(true, 1, Color3.new(), 2), HeadDotOutline = mkcir(false, 3, Color3.new(), 1),
        HealthBG = mksq(true, 1, Color3.new(), 1), HealthFill = mksq(true, 1, Color3.new(), 2),
        Name = mktxt(14, 2, Color3.new(), true, true), Distance = mktxt(14, 2, Color3.new(), true, true), HealthT = mktxt(14, 2, Color3.new(), false, true),
        Highlight = Instance.new("Highlight"),
        root = nil, hum = nil
    }
    for i = 1, 8 do d.Corners[i] = mkln(1, Color3.new(), 2); d.CornerOutlines[i] = mkln(3, Color3.new(), 1); end
    for i = 1, 4 do d.Box[i] = mkln(1, Color3.new(), 2); d.BoxOutlines[i] = mkln(3, Color3.new(), 1); end
    for i = 1, 15 do d.Skeleton[i] = mkln(1, Color3.new(), 2); d.SkeletonOutlines[i] = mkln(3, Color3.new(), 1); end
    return d;
end

local function rmdraw(d)
    for _, l in next, {d.Corners, d.CornerOutlines, d.Box, d.BoxOutlines, d.Skeleton, d.SkeletonOutlines} do
        for _, ln in next, l do ln:Remove(); end
    end
    d.Tracer:Remove(); d.TracerOutline:Remove(); d.HeadDot:Remove(); d.HeadDotOutline:Remove(); d.HealthBG:Remove(); d.HealthFill:Remove(); d.Name:Remove(); d.Distance:Remove(); d.HealthT:Remove();
    if d.Highlight.Parent then d.Highlight:Destroy(); end
end

local function hide(d)
    for _, l in next, {d.Corners, d.CornerOutlines, d.Box, d.BoxOutlines, d.Skeleton, d.SkeletonOutlines} do
        for _, ln in next, l do ln.Visible = false; end
    end
    d.Tracer.Visible = false; d.TracerOutline.Visible = false; d.HeadDot.Visible = false; d.HeadDotOutline.Visible = false; d.HealthBG.Visible = false; d.HealthFill.Visible = false;
    d.Name.Visible = false; d.Distance.Visible = false; d.HealthT.Visible = false; d.Highlight.Enabled = false;
end

local lbl = { x = 0, w = 0, h = 0, y = 0, hpl = 0, hpr = 0, s = nil };
local stk = { Top = 2, Bottom = 2, Left = 0, Right = 0 };

local function poslbl(dr, str, side, col)
    if not str then dr.Visible = false; return; end
    local s = lbl.s;
    dr.Text = tostring(str); dr.Color = col or s.Color; dr.Size = s.TextSize; dr.Font = s.Font;
    local b, x, w, h, y = dr.TextBounds, lbl.x, lbl.w, lbl.h, lbl.y;
    if side == "Top" then
        dr.Center = true; dr.Position = v2(x + w / 2, y - stk.Top - b.Y); stk.Top = stk.Top + b.Y + 2;
    elseif side == "Bottom" then
        dr.Center = true; dr.Position = v2(x + w / 2, y + h + stk.Bottom); stk.Bottom = stk.Bottom + b.Y + 2;
    elseif side == "Left" then
        dr.Center = false; dr.Position = v2(x - b.X - 4 - lbl.hpl, y + stk.Left); stk.Left = stk.Left + b.Y + 2;
    elseif side == "Right" then
        dr.Center = false; dr.Position = v2(x + w + 4 + lbl.hpr, y + stk.Right); stk.Right = stk.Right + b.Y + 2;
    end
