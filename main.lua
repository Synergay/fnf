-- // self-contained ui lib \\

local tween = game:GetService("TweenService");
local uis = game:GetService("UserInputService");
local http = game:GetService("HttpService");
local cs = game:GetService("CollectionService");
local plrs = game:GetService("Players");

local lib = {};
lib.__index = lib;

lib.flags = {};
lib.setters = {};
lib.conns = {};
lib.themed = { accent = {}, main = {}, stroke = {} };
lib.folder = "uilib";

lib.theme = {
	accent = Color3.fromRGB(226, 64, 144),
	main   = Color3.fromRGB(18, 18, 24),
	side   = Color3.fromRGB(14, 14, 19),
	panel  = Color3.fromRGB(24, 24, 32),
	hover  = Color3.fromRGB(34, 34, 44),
	text   = Color3.fromRGB(235, 235, 240),
	dim    = Color3.fromRGB(120, 120, 135),
	stroke = Color3.fromRGB(38, 38, 48),
};

-- // helpers \\

local function clamp01(x) return x < 0 and 0 or x > 1 and 1 or x end;

local function mk(c, p, par)
	local o = Instance.new(c);
	for k, v in p do o[k] = v end;
	if par then o.Parent = par end;
	return o;
end;

local function push(con) lib.conns[#lib.conns + 1] = con; return con end;

local function tw(o, t, props)
	tween:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play();
end;

local function theme(o, role, prop)
	lib.themed[role][#lib.themed[role] + 1] = { o = o, p = prop };
	pcall(cs.AddTag, cs, o, "ui_" .. role);
	o[prop] = lib.theme[role];
end;

local function getparent()
	if gethui then return gethui() end;
	local ok, cg = pcall(function() return game:GetService("CoreGui") end);
	if ok and cg then return cg end;
	return plrs.LocalPlayer:WaitForChild("PlayerGui");
end;

-- // drag binders \\

local function bindx(area, onmove)
	local d = false;
	area.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			d = true;
			onmove(clamp01((i.Position.X - area.AbsolutePosition.X) / area.AbsoluteSize.X));
		end;
	end);
	push(uis.InputChanged:Connect(function(i)
		if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			onmove(clamp01((i.Position.X - area.AbsolutePosition.X) / area.AbsoluteSize.X));
		end;
	end));
	push(uis.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d = false end;
	end));
end;

local function bindxy(area, onmove)
	local d = false;
	local function fire(p)
		onmove(
			clamp01((p.X - area.AbsolutePosition.X) / area.AbsoluteSize.X),
			clamp01((p.Y - area.AbsolutePosition.Y) / area.AbsoluteSize.Y)
		);
	end;
	area.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			d = true; fire(i.Position);
		end;
	end);
	push(uis.InputChanged:Connect(function(i)
		if d and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fire(i.Position) end;
	end));
	push(uis.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d = false end;
	end));
end;

-- // config serialization \\

local function ser(v)
	if typeof(v) == "Color3" then return { __c3 = true, r = v.R, g = v.G, b = v.B } end;
	return v;
end;

local function deser(v)
	if type(v) == "table" and v.__c3 then return Color3.new(v.r, v.g, v.b) end;
	return v;
end;

-- // theme setters \\

function lib:SetAccent(c)
	self.theme.accent = c;
	for _, e in self.themed.accent do if e.o and e.o.Parent then e.o[e.p] = c end end;
end;

function lib:SetMain(c)
	self.theme.main = c;
	for _, e in self.themed.main do if e.o and e.o.Parent then e.o[e.p] = c end end;
end;

-- // config api \\

function lib:_ensure()
	if not (makefolder and isfolder) then return false end;
	if not isfolder(self.folder) then makefolder(self.folder) end;
	return true;
end;

function lib:SaveConfig(name)
	if not writefile then return false, "no filesystem" end;
	self:_ensure();
	local t = {};
	for f, v in self.flags do t[f] = ser(v) end;
	writefile(self.folder .. "/" .. name .. ".json", http:JSONEncode(t));
	return true;
end;

function lib:LoadConfig(name)
	if not (readfile and isfile) then return false, "no filesystem" end;
	local p = self.folder .. "/" .. name .. ".json";
	if not isfile(p) then return false, "missing" end;
	local ok, t = pcall(function() return http:JSONDecode(readfile(p)) end);
	if not ok then return false, "corrupt" end;
	for f, v in t do
		v = deser(v);
		self.flags[f] = v;
		if self.setters[f] then pcall(self.setters[f], v) end;
	end;
	return true;
end;

function lib:DeleteConfig(name)
	if not (delfile and isfile) then return false end;
	local p = self.folder .. "/" .. name .. ".json";
	if isfile(p) then delfile(p); return true end;
	return false;
end;

function lib:RenameConfig(old, new)
	if not (readfile and isfile and writefile and delfile) then return false end;
	local op = self.folder .. "/" .. old .. ".json";
	if not isfile(op) then return false end;
	writefile(self.folder .. "/" .. new .. ".json", readfile(op));
	delfile(op);
	return true;
end;

function lib:ListConfigs()
	local r = {};
	if not (listfiles and isfolder) then return r end;
	if not isfolder(self.folder) then return r end;
	for _, p in listfiles(self.folder) do
		local n = p:match("([^/\\]+)%.json$");
		if n then r[#r + 1] = n end;
	end;
	return r;
end;

-- // cleanup \\

function lib:Unload()
	for _, c in self.conns do pcall(function() c:Disconnect() end) end;
	self.conns = {};
	for role in self.themed do
		for _, e in self.themed[role] do pcall(cs.RemoveTag, cs, e.o, "ui_" .. role) end;
	end;
	if self.gui then self.gui:Destroy() end;
end;

-- // tab component methods \\

local tab = {};
tab.__index = tab;

function tab:_flag(txt)
	self.lib._fc = (self.lib._fc or 0) + 1;
	return (txt:gsub("%s", "")) .. "_" .. self.lib._fc;
end;

function tab:_row(h)
	local f = mk("Frame", { Size = UDim2.new(1, 0, 0, h or 34), BackgroundColor3 = self.lib.theme.panel, BorderSizePixel = 0 }, self.page);
	theme(f, "main", "BackgroundColor3");
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, f);
	mk("UIStroke", { Color = self.lib.theme.stroke, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f);
	return f;
end;

function tab:Label(txt, col)
	local f = mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
		Text = txt, TextColor3 = col or self.lib.theme.dim, Font = Enum.Font.Gotham,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
	}, self.page);
	mk("UIPadding", { PaddingLeft = UDim.new(0, 4) }, f);
	return {
		Set = function(_, t) f.Text = t end,
		SetColor = function(_, c) f.TextColor3 = c end,
	};
end;

function tab:Button(txt, cb)
	cb = cb or function() end;
	local f = self:_row(34);
	local b = mk("TextButton", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = txt,
		TextColor3 = self.lib.theme.text, Font = Enum.Font.GothamMedium, TextSize = 13, AutoButtonColor = false,
	}, f);
	b.MouseEnter:Connect(function() tw(f, .15, { BackgroundColor3 = self.lib.theme.hover }) end);
	b.MouseLeave:Connect(function() tw(f, .15, { BackgroundColor3 = self.lib.theme.panel }) end);
	b.MouseButton1Click:Connect(function()
		tw(f, .07, { BackgroundColor3 = self.lib.theme.accent });
		task.delay(.1, function() tw(f, .15, { BackgroundColor3 = self.lib.theme.hover }) end);
		task.spawn(cb);
	end);
	return f;
end;

function tab:Toggle(txt, def, cb)
	cb = cb or function() end;
	local flag = self:_flag(txt);
	local state = def and true or false;
	local f = self:_row(34);
	mk("TextLabel", {
		Size = UDim2.new(1, -54, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
		Text = txt, TextColor3 = self.lib.theme.text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, f);
	local box = mk("Frame", {
		Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, -46, .5, -9),
		BackgroundColor3 = self.lib.theme.stroke, BorderSizePixel = 0,
	}, f);
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, box);
	local knob = mk("Frame", {
		Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 2, .5, -7),
		BackgroundColor3 = Color3.fromRGB(230, 230, 235), BorderSizePixel = 0,
	}, box);
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, knob);

	local function vis()
		if state then
			tw(box, .15, { BackgroundColor3 = self.lib.theme.accent });
			tw(knob, .15, { Position = UDim2.new(1, -16, .5, -7) });
		else
			tw(box, .15, { BackgroundColor3 = self.lib.theme.stroke });
			tw(knob, .15, { Position = UDim2.new(0, 2, .5, -7) });
		end;
	end;

	local obj = {};
	function obj:Set(v, silent)
		state = v and true or false;
		self_flag = state;
		lib.flags[flag] = state;
		vis();
		if not silent then task.spawn(cb, state) end;
	end;

	lib.flags[flag] = state;
	lib.setters[flag] = function(v) obj:Set(v) end;
	vis();

	mk("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, f).MouseButton1Click:Connect(function()
		obj:Set(not state);
	end);
	return obj;
end;

function tab:Slider(txt, min, max, def, cb)
	cb = cb or function() end;
	local flag = self:_flag(txt);
	local val = def or min;
	local f = self:_row(46);
	local lbl = mk("TextLabel", {
		Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 0, 4), BackgroundTransparency = 1,
		Text = txt, TextColor3 = self.lib.theme.text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, f);
	local vlbl = mk("TextLabel", {
		Size = UDim2.new(0, 60, 0, 20), Position = UDim2.new(1, -70, 0, 4), BackgroundTransparency = 1,
		Text = tostring(val), TextColor3 = self.lib.theme.dim, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
	}, f);
	local bar = mk("Frame", {
		Size = UDim2.new(1, -20, 0, 6), Position = UDim2.new(0, 10, 0, 30),
		BackgroundColor3 = self.lib.theme.stroke, BorderSizePixel = 0,
	}, f);
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, bar);
	local fill = mk("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = self.lib.theme.accent, BorderSizePixel = 0 }, bar);
	theme(fill, "accent", "BackgroundColor3");
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill);

	local obj = {};
	function obj:Set(v, silent)
		v = math.clamp(v, min, max);
		val = math.floor(v * 100 + .5) / 100;
		lib.flags[flag] = val;
		local a = (val - min) / (max - min);
		tw(fill, .06, { Size = UDim2.new(a, 0, 1, 0) });
		vlbl.Text = tostring(val);
		if not silent then task.spawn(cb, val) end;
	end;

	lib.flags[flag] = val;
	lib.setters[flag] = function(v) obj:Set(v) end;
	obj:Set(val, true);

	bindx(bar, function(a) obj:Set(min + (max - min) * a) end);
	return obj;
end;

function tab:Box(txt, cb)
	cb = cb or function() end;
	local f = self:_row(34);
	local b = mk("TextBox", {
		Size = UDim2.new(1, -20, 1, -10), Position = UDim2.new(0, 10, 0, 5), BackgroundColor3 = self.lib.theme.side,
		Text = "", PlaceholderText = txt, TextColor3 = self.lib.theme.text, PlaceholderColor3 = self.lib.theme.dim,
		Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, BorderSizePixel = 0,
	}, f);
	mk("UICorner", { CornerRadius = UDim.new(0, 5) }, b);
	mk("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b);
	b.FocusLost:Connect(function(enter) task.spawn(cb, b.Text, true) end);
	b:GetPropertyChangedSignal("Text"):Connect(function() task.spawn(cb, b.Text, false) end);
	return { Set = function(_, t) b.Text = t end, Get = function() return b.Text end };
end;

function tab:Dropdown(txt, opts, cb)
	cb = cb or function() end;
	local flag = self:_flag(txt);
	opts = opts or {};
	local open = false;
	local f = self:_row(34);
	f.ClipsDescendants = true;
	local head = mk("TextButton", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
	}, f);
	local lbl = mk("TextLabel", {
		Size = UDim2.new(1, -40, 0, 34), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
		Text = txt, TextColor3 = self.lib.theme.text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, head);
	local arrow = mk("TextLabel", {
		Size = UDim2.new(0, 24, 0, 34), Position = UDim2.new(1, -28, 0, 0), BackgroundTransparency = 1,
		Text = "v", TextColor3 = self.lib.theme.dim, Font = Enum.Font.GothamBold, TextSize = 12,
	}, head);
	local list = mk("Frame", { Size = UDim2.new(1, -8, 0, 0), Position = UDim2.new(0, 4, 0, 34), BackgroundTransparency = 1 }, f);
	local lay = mk("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list);

	local obj = { items = {} };

	local function resize()
		local n = #obj.items;
		list.Size = UDim2.new(1, -8, 0, n * 27);
		if open then f.Size = UDim2.new(1, 0, 0, 40 + n * 27) else f.Size = UDim2.new(1, 0, 0, 34) end;
	end;

	function obj:_render()
		for _, c in list:GetChildren() do if c:IsA("TextButton") then c:Destroy() end end;
		for _, name in self.items do
			local it = mk("TextButton", {
				Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = lib.theme.side, Text = name,
				TextColor3 = lib.theme.text, Font = Enum.Font.Gotham, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0,
			}, list);
			mk("UICorner", { CornerRadius = UDim.new(0, 4) }, it);
			it.MouseEnter:Connect(function() tw(it, .12, { BackgroundColor3 = lib.theme.hover }) end);
			it.MouseLeave:Connect(function() tw(it, .12, { BackgroundColor3 = lib.theme.side }) end);
			it.MouseButton1Click:Connect(function()
				lbl.Text = txt .. ": " .. name;
				lib.flags[flag] = name;
				open = false; arrow.Text = "v"; resize();
				task.spawn(cb, name);
			end);
		end;
		resize();
	end;

	function obj:Button(name) self.items[#self.items + 1] = name; self:_render() end;
	function obj:Remove(name)
		for i, v in self.items do if v == name then table.remove(self.items, i); break end end;
		self:_render();
	end;
	function obj:Set(name)
		lbl.Text = txt .. ": " .. name; lib.flags[flag] = name; task.spawn(cb, name);
	end;
	function obj:Clear() self.items = {}; self:_render() end;

	for _, v in opts do obj.items[#obj.items + 1] = v end;
	obj:_render();
	lib.flags[flag] = nil;
	lib.setters[flag] = function(v) if v then obj:Set(v) end end;

	head.MouseButton1Click:Connect(function()
		open = not open;
		arrow.Text = open and "^" or "v";
		resize();
	end);
	return obj;
end;

function tab:ColorPicker(txt, def, cb)
	cb = cb or function() end;
	local flag = self:_flag(txt);
	def = def or Color3.fromRGB(255, 255, 255);
	local h, s, v = def:ToHSV();
	local open = false;
	local f = self:_row(34);
	f.ClipsDescendants = true;
	mk("TextLabel", {
		Size = UDim2.new(1, -50, 0, 34), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
		Text = txt, TextColor3 = self.lib.theme.text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, f);
	local prev = mk("TextButton", {
		Size = UDim2.new(0, 28, 0, 16), Position = UDim2.new(1, -38, 0, 9), BackgroundColor3 = def, Text = "", BorderSizePixel = 0,
	}, f);
	mk("UICorner", { CornerRadius = UDim.new(0, 4) }, prev);
	mk("UIStroke", { Color = self.lib.theme.stroke, Thickness = 1 }, prev);

	local panel = mk("Frame", { Size = UDim2.new(1, -20, 0, 110), Position = UDim2.new(0, 10, 0, 40), BackgroundTransparency = 1 }, f);
	local box = mk("Frame", { Size = UDim2.new(1, -26, 0, 90), BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0 }, panel);
	mk("UICorner", { CornerRadius = UDim.new(0, 5) }, box);
	local sgrad = mk("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(h, 1, 1)) }, box);
	local vov = mk("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, box);
	mk("UICorner", { CornerRadius = UDim.new(0, 5) }, vov);
	mk("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
	}, vov);
	local dot = mk("Frame", { Size = UDim2.new(0, 8, 0, 8), AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, box);
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, dot);
	mk("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }, dot);

	local hue = mk("Frame", { Size = UDim2.new(0, 14, 0, 90), Position = UDim2.new(1, -14, 0, 0), BorderSizePixel = 0 }, panel);
	mk("UICorner", { CornerRadius = UDim.new(0, 4) }, hue);
	mk("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(.17, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(.33, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(.5, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(.67, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(.83, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
	}, hue);
	local hmark = mk("Frame", { Size = UDim2.new(1, 2, 0, 3), Position = UDim2.new(0, -1, h, 0), AnchorPoint = Vector2.new(0, .5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, hue);
	mk("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }, hmark);

	local obj = {};
	local function apply(fire)
		local col = Color3.fromHSV(h, s, v);
		box.BackgroundColor3 = Color3.fromHSV(h, 1, 1);
		sgrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(h, 1, 1));
		dot.Position = UDim2.new(s, 0, 1 - v, 0);
		hmark.Position = UDim2.new(0, -1, h, 0);
		prev.BackgroundColor3 = col;
		lib.flags[flag] = col;
		if fire then task.spawn(cb, col) end;
	end;

	function obj:Set(c) h, s, v = c:ToHSV(); apply(true) end;

	lib.flags[flag] = def;
	lib.setters[flag] = function(c) obj:Set(c) end;
	apply(false);

	bindxy(box, function(ax, ay) s = ax; v = 1 - ay; apply(true) end);
	bindx(hue, function(ax) h = ax; apply(true) end);

	prev.MouseButton1Click:Connect(function()
		open = not open;
		f.Size = open and UDim2.new(1, 0, 0, 158) or UDim2.new(1, 0, 0, 34);
	end);
	return obj;
end;

-- // window \\

function lib:Window(title)
	local old = getparent():FindFirstChild("uilib_gui");
	if old then old:Destroy() end;

	local gui = mk("ScreenGui", { Name = "uilib_gui", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, getparent());
	self.gui = gui;

	local main = mk("Frame", {
		Size = UDim2.new(0, 580, 0, 380), Position = UDim2.new(.5, -290, .5, -190),
		BackgroundColor3 = self.theme.main, BorderSizePixel = 0,
	}, gui);
	theme(main, "main", "BackgroundColor3");
	mk("UICorner", { CornerRadius = UDim.new(0, 8) }, main);
	mk("UIStroke", { Color = self.theme.stroke, Thickness = 1 }, main);

	local top = mk("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 }, main);
	local dotc = mk("Frame", { Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 14, .5, -4), BackgroundColor3 = self.theme.accent, BorderSizePixel = 0 }, top);
	theme(dotc, "accent", "BackgroundColor3");
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, dotc);
	mk("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 30, 0, 0), BackgroundTransparency = 1,
		Text = title or "uilib", TextColor3 = self.theme.text, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
	}, top);
	mk("Frame", { Size = UDim2.new(1, -20, 0, 1), Position = UDim2.new(0, 10, 1, 0), BackgroundColor3 = self.theme.stroke, BorderSizePixel = 0 }, top);

	-- drag
	local dragging, dpos, spos;
	top.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dpos = i.Position; spos = main.Position;
		end;
	end);
	push(uis.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dpos;
			main.Position = UDim2.new(spos.X.Scale, spos.X.Offset + d.X, spos.Y.Scale, spos.Y.Offset + d.Y);
		end;
	end));
	push(uis.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end;
	end));

	local side = mk("Frame", { Size = UDim2.new(0, 130, 1, -48), Position = UDim2.new(0, 8, 0, 42), BackgroundColor3 = self.theme.side, BorderSizePixel = 0 }, main);
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, side);
	local slay = mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, side);
	mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, side);

	local body = mk("Frame", { Size = UDim2.new(1, -154, 1, -48), Position = UDim2.new(0, 146, 0, 42), BackgroundTransparency = 1 }, main);

	local wnd = setmetatable({ lib = self, main = main, tabs = {}, active = nil }, lib);

	-- open anim
	main.Size = UDim2.new(0, 580, 0, 0);
	tw(main, .25, { Size = UDim2.new(0, 580, 0, 380) });

	function wnd:Tab(name)
		local btn = mk("TextButton", {
			Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = self.lib.theme.side, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		}, side);
		mk("UICorner", { CornerRadius = UDim.new(0, 5) }, btn);
		local ind = mk("Frame", { Size = UDim2.new(0, 3, 0, 0), Position = UDim2.new(0, 0, .5, 0), AnchorPoint = Vector2.new(0, .5), BackgroundColor3 = self.lib.theme.accent, BorderSizePixel = 0 }, btn);
		theme(ind, "accent", "BackgroundColor3");
		mk("UICorner", { CornerRadius = UDim.new(1, 0) }, ind);
		mk("TextLabel", {
			Size = UDim2.new(1, -14, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1,
			Text = name, TextColor3 = self.lib.theme.dim, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		}, btn);

		local page = mk("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
			ScrollBarThickness = 3, ScrollBarImageColor3 = self.lib.theme.accent, CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, body);
		mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page);
		mk("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingRight = UDim.new(0, 6) }, page);

		local t = setmetatable({ lib = self.lib, page = page, btn = btn, ind = ind }, tab);
		self.tabs[#self.tabs + 1] = t;

		local function activate()
			for _, o in self.tabs do
				o.page.Visible = false;
				tw(o.ind, .15, { Size = UDim2.new(0, 3, 0, 0) });
				tw(o.btn, .15, { BackgroundColor3 = self.lib.theme.side });
				o.btn.TextLabel.TextColor3 = self.lib.theme.dim;
			end;
			page.Visible = true;
			page.Position = UDim2.new(0, 8, 0, 0);
			tw(page, .2, { Position = UDim2.new() });
			tw(ind, .15, { Size = UDim2.new(0, 3, 0, 16) });
			tw(btn, .15, { BackgroundColor3 = self.lib.theme.hover });
			btn.TextLabel.TextColor3 = self.lib.theme.text;
			self.active = t;
		end;

		btn.MouseButton1Click:Connect(activate);
		if not self.active then activate() end;
		return t;
	end;

	-- proxy: direct component calls on window route to a default tab
	local function proxy(method)
		wnd[method] = function(self2, ...)
			if not self2._main then self2._main = self2:Tab("Main") end;
			return self2._main[method](self2._main, ...);
		end;
	end;
	for _, m in { "Button", "Toggle", "Slider", "ColorPicker", "Label", "Box", "Dropdown" } do proxy(m) end;

	-- built-in settings/config tab
	function wnd:Settings()
		local t = self:Tab("Settings");
		t:Label("<b>Theme</b>");
		t:ColorPicker("Accent color", self.lib.theme.accent, function(c) self.lib:SetAccent(c) end);
		t:ColorPicker("Main color", self.lib.theme.main, function(c) self.lib:SetMain(c) end);
		t:Label("<b>Configs</b>");
		local cfgname = "";
		t:Box("config name", function(txt) cfgname = txt end);
		local dd = t:Dropdown("Saved configs", self.lib:ListConfigs(), function(n) cfgname = n end);
		t:Button("Save", function() if cfgname ~= "" then self.lib:SaveConfig(cfgname); dd:Clear(); for _, n in self.lib:ListConfigs() do dd:Button(n) end end end);
		t:Button("Load", function() if cfgname ~= "" then self.lib:LoadConfig(cfgname) end end);
		t:Button("Delete", function() if cfgname ~= "" then self.lib:DeleteConfig(cfgname); dd:Clear(); for _, n in self.lib:ListConfigs() do dd:Button(n) end end end);
		return t;
	end;

	-- toggle visibility key (RightControl)
	push(uis.InputBegan:Connect(function(i, gp)
		if gp then return end;
		if i.KeyCode == (self.togglekey or Enum.KeyCode.RightControl) then main.Visible = not main.Visible end;
	end));

	return wnd;
end;

return lib;
