
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
    dr.Visible = true;
end

function ESP:Add(model)
    if model.Name == lp.Name or self.Tracked[model] then return; end
    self.Tracked[model] = mkdraw();
end

function ESP:Remove(model)
    if self.Tracked[model] then rmdraw(self.Tracked[model]); self.Tracked[model] = nil; end
end

function ESP:Clear()
    for m in next, self.Tracked do self:Remove(m); end
    if cons.add then cons.add:Disconnect(); end
    if cons.rem then cons.rem:Disconnect(); end
    if cons.rndr then cons.rndr:Disconnect(); end
end

function ESP:Update()
    local s = self.Settings;
    if not s.Enabled then
        for _, d in next, self.Tracked do hide(d); end
        return;
    end

    local o = s.Optimizations;
    lbl.s = s;
    local cpos = cam.CFrame.Position;
    local vp = cam.ViewportSize;
    local md = s.MaxDistance;
    local mdsq = md * md;
    local ldsq = o.LowDetailDistance > 0 and o.LowDetailDistance * o.LowDetailDistance or math.huge;
    local mt = o.MaxTargets;
    local drawn = 0;

    for model, d in next, self.Tracked do
        local root = d.root;
        if not root or root.Parent ~= model then
            root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart;
            d.root = root;
        end

        if root and model.Parent then
            local rp = root.Position;
            local dx, dy, dz = cpos.X - rp.X, cpos.Y - rp.Y, cpos.Z - rp.Z;
            local dsq = dx * dx + dy * dy + dz * dz;

            if (o.DistanceCull and dsq > mdsq) or (mt > 0 and drawn >= mt) then
                hide(d);
            else
                local pos, vis = cam:WorldToViewportPoint(rp);
                local dist = sqrt(dsq);

                if vis and dist <= md then
                    drawn += 1;

                    local hum = d.hum;
                    if not hum or hum.Parent ~= model then
                        hum = model:FindFirstChildOfClass("Humanoid");
                        d.hum = hum;
                    end

                    local hd = model:FindFirstChild("Head");
                    local hp = hd and cam:WorldToViewportPoint(hd.Position + hoff) or cam:WorldToViewportPoint(rp + fhoff);
                    local lp2 = cam:WorldToViewportPoint(rp - loff);
                    local h = abs(hp.Y - lp2.Y);
                    local w = h / 1.5;
                    local x = pos.X - w / 2;
                    local y = hp.Y;

                    if s.CornerBoxes then
                        local lx, ly = w * s.CornerSizeX, h * s.CornerSizeY;
                        local c, ol = d.Corners, d.CornerOutlines;
                        setln(c[1], ol[1], v2(x, y), v2(x + lx, y), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                        setln(c[2], ol[2], v2(x, y), v2(x, y + ly), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                        setln(c[3], ol[3], v2(x + w, y), v2(x + w - lx, y), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                        setln(c[4], ol[4], v2(x + w, y), v2(x + w, y + ly), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                        setln(c[5], ol[5], v2(x, y + h), v2(x + lx, y + h), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                        setln(c[6], ol[6], v2(x, y + h), v2(x, y + h - ly), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                        setln(c[7], ol[7], v2(x + w, y + h), v2(x + w - lx, y + h), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                        setln(c[8], ol[8], v2(x + w, y + h), v2(x + w, y + h - ly), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                    else
                        for i = 1, 8 do d.Corners[i].Visible = false; d.CornerOutlines[i].Visible = false; end
                    end

                    if s.Boxes then
                        local b, ol = d.Box, d.BoxOutlines;
                        setln(b[1], ol[1], v2(x, y), v2(x + w, y), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                        setln(b[2], ol[2], v2(x, y), v2(x, y + h), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                        setln(b[3], ol[3], v2(x + w, y), v2(x + w, y + h), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                        setln(b[4], ol[4], v2(x, y + h), v2(x + w, y + h), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                    else
                        for i = 1, 4 do d.Box[i].Visible = false; d.BoxOutlines[i].Visible = false; end
                    end

                    stk.Top = 2; stk.Bottom = 2; stk.Left = 0; stk.Right = 0;
                    lbl.x = x; lbl.w = w; lbl.h = h; lbl.y = y; lbl.hpl = 0; lbl.hpr = 0;

                    if s.HealthBar and hum then
                        local f = clamp(hum.Health / hum.MaxHealth, 0, 1);
                        local bh = h * f;
                        if s.Positions.HealthBar == "Left" then
                            d.HealthBG.Position = v2(x - 5, y); d.HealthFill.Position = v2(x - 4, y + (h - bh)); lbl.hpl = 6;
                        else
                            d.HealthBG.Position = v2(x + w + 2, y); d.HealthFill.Position = v2(x + w + 3, y + (h - bh)); lbl.hpr = 6;
                        end
                        d.HealthBG.Size = v2(3, h); d.HealthBG.Color = s.OutlineColor; d.HealthBG.Visible = s.BoxOutlines;
                        d.HealthFill.Size = v2(1, bh); d.HealthFill.Color = s.HealthBarColor; d.HealthFill.Visible = true;
                    else
                        d.HealthBG.Visible = false; d.HealthFill.Visible = false;
                    end

                    poslbl(d.Name, s.Names and model.Name or nil, s.Positions.Name, s.Color);
                    poslbl(d.Distance, s.Distances and flr(dist) .. "m" or nil, s.Positions.Distance, s.Color);
                    poslbl(d.HealthT, (s.HealthText and hum) and flr(hum.Health) .. " HP" or nil, s.Positions.HealthText, s.HealthBarColor);

                    if s.Tracers then
                        local org = s.TracerOrigin;
                        local sy = org == "Bottom" and vp.Y or (org == "Top" and 0 or rs:GetMouseLocation().Y);
                        local sx = org == "Mouse" and rs:GetMouseLocation().X or vp.X / 2;
                        setln(d.Tracer, d.TracerOutline, v2(sx, sy), v2(x + w / 2, y + h), s.Thickness, s.Color, s.OutlineColor, true, s.BoxOutlines);
                    else
                        d.Tracer.Visible = false; d.TracerOutline.Visible = false;
                    end
                else
                    hide(d);
                end
            end
        else
            hide(d);
            if not model.Parent then self:Remove(model); end
        end
    end
end

function ESP:Listen(container)
    if not container then return; end
    self.Settings.Container = container;
    for _, m in next, container:GetChildren() do if m:IsA("Model") then self:Add(m); end end
    cons.add = container.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(c) if c:IsA("Model") then self:Add(c); end end));
    cons.rem = container.ChildRemoved:Connect(LPH_NO_VIRTUALIZE(function(c) self:Remove(c); end));

    local acc = 0;
    cons.rndr = rs.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function(dt)
        local r = self.Settings.Optimizations.RefreshRate;
        if r <= 0 or r >= 60 then
            self:Update();
        else
            acc += dt;
            local iv = 1 / r;
            if acc >= iv then acc = acc % iv; self:Update(); end
        end
    end));
end

return ESP;
