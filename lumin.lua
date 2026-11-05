--!nocheck
--[[
    ╦  ╦ ╦╔╦╗╦╔╗╔   UI LIBRARY  v1.0.0
    ║  ║ ║║║║║║║║
    ╩═╝╚═╝╩ ╩╩╝╚╝

    local Lumin = loadstring(game:HttpGet("<raw url>"))()

    Lumin:KeySystem(cfg)                      -> success:boolean, key:string
    Lumin:CreateWindow(cfg)                   -> Window
    Lumin:Notify(cfg)
    Lumin:SaveConfig(name) / :LoadConfig(name) / :SetAccent(color)
    Lumin.SHA256(str)                         -> hex

    Window:AddPage(name, icon)                -> Page      (left sidebar)
    Page:AddTab(name, icon)                   -> Tab       (top bar, optional)
    Page:AddPanel(side) / Tab:AddPanel(side)  -> Panel     ("Left" | "Right")

    Panel:AddHeader / AddToggle / AddSlider / AddDropdown / AddColorPicker
          AddKeybind / AddTextBox / AddButton / AddLabel / AddDivider
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local TextService      = game:GetService("TextService")
local CoreGui          = game:GetService("CoreGui")
local Analytics        = game:GetService("RbxAnalyticsService")

local LP = Players.LocalPlayer

------------------------------------------------------------------------
-- Theme (sampled from the reference screenshots)
------------------------------------------------------------------------
local Theme = {
	Window    = Color3.fromRGB(22, 22, 26),
	Panel     = Color3.fromRGB(28, 28, 33),
	Element   = Color3.fromRGB(37, 37, 43),
	Row       = Color3.fromRGB(34, 34, 40),
	Hover     = Color3.fromRGB(44, 44, 52),
	Tile      = Color3.fromRGB(46, 46, 54),
	Track     = Color3.fromRGB(33, 33, 40),
	Switch    = Color3.fromRGB(37, 37, 50),
	Divider   = Color3.fromRGB(36, 36, 42),
	Accent    = Color3.fromRGB(170, 170, 255),
	AccentDim = Color3.fromRGB(104, 94, 170),
	OnAccent  = Color3.fromRGB(14, 14, 20),
	Text      = Color3.fromRGB(245, 245, 250),
	SubText   = Color3.fromRGB(122, 122, 138),
	Muted     = Color3.fromRGB(98, 98, 112),
	Good      = Color3.fromRGB(62, 224, 140),
	Warn      = Color3.fromRGB(255, 170, 40),
	Error     = Color3.fromRGB(232, 104, 128),
	Key = {
		Panel = Color3.fromRGB(30, 30, 34),
		Input = Color3.fromRGB(37, 38, 42),
		Icon  = Color3.fromRGB(212, 132, 192),
		Tile  = Color3.fromRGB(44, 40, 50),
	},
}

local Lumin = {
	Version = "1.0.0",
	Theme = Theme,
	Flags = {},
	Options = {},
	Windows = {},
	_hooks = {},
}

local FONT, FONT_REG, FONT_BOLD = Enum.Font.GothamMedium, Enum.Font.Gotham, Enum.Font.GothamBold
local LEFT, CENTER, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Center, Enum.TextXAlignment.Right
local HORIZ, VERT = Enum.FillDirection.Horizontal, Enum.FillDirection.Vertical
local V2 = Vector2.new

------------------------------------------------------------------------
-- Utilities
------------------------------------------------------------------------
local classDefaults = {
	Frame          = { BorderSizePixel = 0 },
	CanvasGroup    = { BorderSizePixel = 0, BackgroundTransparency = 1 },
	ScrollingFrame = { BorderSizePixel = 0, BackgroundTransparency = 1, ScrollBarThickness = 0 },
	TextLabel      = { BorderSizePixel = 0, BackgroundTransparency = 1, Font = FONT, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = LEFT },
	TextButton     = { BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false, Font = FONT, TextSize = 13, TextColor3 = Theme.Text, Text = "" },
	TextBox        = { BorderSizePixel = 0, BackgroundTransparency = 1, Font = FONT, TextSize = 13, TextColor3 = Theme.Text, ClearTextOnFocus = false, TextXAlignment = LEFT },
	ImageLabel     = { BorderSizePixel = 0, BackgroundTransparency = 1 },
}

local function create(class, props, children)
	local o = Instance.new(class)
	local d = classDefaults[class]
	if d then for k, v in pairs(d) do o[k] = v end end
	local parent
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then parent = v else o[k] = v end
		end
	end
	if children then for _, c in ipairs(children) do c.Parent = o end end
	o.Parent = parent
	return o
end

local function tw(o, p, t, style, dir)
	local tween = TweenService:Create(o, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), p)
	tween:Play()
	return tween
end

local function corner(o, r) return create("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end
local function stroke(o, c, t, tr) return create("UIStroke", { Color = c, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o }) end
local function pad(o, l, t, r, b)
	return create("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0), Parent = o })
end
local function list(o, gap, dir, extra)
	local l = create("UIListLayout", { Padding = UDim.new(0, gap or 0), FillDirection = dir or VERT, SortOrder = Enum.SortOrder.LayoutOrder, Parent = o })
	if extra then for k, v in pairs(extra) do l[k] = v end end
	return l
end

local FULL = UDim2.fromScale(1, 1)

local function bind(fn) table.insert(Lumin._hooks, fn); fn() end

local function markerColor(m)
	if typeof(m) == "Color3" then return m end
	m = tostring(m):lower()
	if m == "green" or m == "good" then return Theme.Good end
	if m == "orange" or m == "warn" then return Theme.Warn end
	if m == "red" or m == "error" then return Theme.Error end
	return Theme.Accent
end

local function mount(gui)
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
	local ok = pcall(function()
		if gethui then gui.Parent = gethui() else error("no gethui") end
	end)
	if ok and gui.Parent then return end
	ok = pcall(function() gui.Parent = CoreGui end)
	if ok and gui.Parent then return end
	gui.Parent = LP:WaitForChild("PlayerGui")
end

local function connect(win, signal, fn)
	local c = signal:Connect(fn)
	if win then table.insert(win.Connections, c) end
	return c
end

local function ripple(btn, color)
	btn.ClipsDescendants = true
	btn.InputBegan:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
		local rel = (V2(i.Position.X, i.Position.Y) - btn.AbsolutePosition) / btn.AbsoluteSize
		local c = create("Frame", {
			AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(rel.X, rel.Y), Size = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = color or Color3.new(1, 1, 1), BackgroundTransparency = .75, ZIndex = 5, Parent = btn,
		})
		corner(c, 999)
		create("UIAspectRatio", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width, Parent = c })
		tw(c, { Size = UDim2.new(2.6, 0, 0, 0), BackgroundTransparency = 1 }, .55)
		task.delay(.6, function() c:Destroy() end)
	end)
end

local function hoverable(btn, prop, normal, hover, win)
	btn.MouseEnter:Connect(function() tw(btn, { [prop] = hover }, .15) end)
	btn.MouseLeave:Connect(function() tw(btn, { [prop] = normal }, .15) end)
end

local function makeIcon(parent, icon, size, color)
	icon = tostring(icon or "")
	if icon ~= "" and (icon:find("rbxasset") or tonumber(icon)) then
		local id = tonumber(icon) and ("rbxassetid://" .. icon) or icon
		return create("ImageLabel", { Image = id, Size = UDim2.fromOffset(size, size), ImageColor3 = color, Parent = parent }), "ImageColor3"
	end
	return create("TextLabel", { Text = icon, TextSize = size, Size = UDim2.fromOffset(size + 4, size + 4), TextColor3 = color, TextXAlignment = CENTER, Parent = parent }), "TextColor3"
end

local function draggable(handle, target, win)
	local dragging, startInput, startPos
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startInput, startPos = true, i.Position, target.Position
			i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	connect(win, UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startInput
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

local function hasFS() return (writefile and readfile and isfile) and true or false end

------------------------------------------------------------------------
-- SHA-256 (so devs can ship hashed keys instead of plaintext)
------------------------------------------------------------------------
local K256 = {
	0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
	0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
	0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
	0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
	0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
	0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
	0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
	0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}

function Lumin.SHA256(msg)
	local band, bxor, bnot, rrot, rshift = bit32.band, bit32.bxor, bit32.bnot, bit32.rrotate, bit32.rshift
	local len = #msg
	msg = msg .. "\128" .. string.rep("\0", (55 - len) % 64) .. string.pack(">I8", len * 8)
	local H = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
	for chunk = 1, #msg, 64 do
		local w = {}
		for i = 0, 15 do w[i] = string.unpack(">I4", msg, chunk + i * 4) end
		for i = 16, 63 do
			local s0 = bxor(rrot(w[i - 15], 7), rrot(w[i - 15], 18), rshift(w[i - 15], 3))
			local s1 = bxor(rrot(w[i - 2], 17), rrot(w[i - 2], 19), rshift(w[i - 2], 10))
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % 2 ^ 32
		end
		local a, b, c, d, e, f, g, h = table.unpack(H)
		for i = 0, 63 do
			local S1 = bxor(rrot(e, 6), rrot(e, 11), rrot(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local t1 = (h + S1 + ch + K256[i + 1] + w[i]) % 2 ^ 32
			local S0 = bxor(rrot(a, 2), rrot(a, 13), rrot(a, 22))
			local maj = bxor(band(a, b), band(a, c), band(b, c))
			local t2 = (S0 + maj) % 2 ^ 32
			h, g, f, e, d, c, b, a = g, f, e, (d + t1) % 2 ^ 32, c, b, a, (t1 + t2) % 2 ^ 32
		end
		local v = { a, b, c, d, e, f, g, h }
		for i = 1, 8 do H[i] = (H[i] + v[i]) % 2 ^ 32 end
	end
	local out = {}
	for i = 1, 8 do out[i] = string.format("%08x", H[i]) end
	return table.concat(out)
end

------------------------------------------------------------------------
-- Notifications
------------------------------------------------------------------------
local notifGui
local function getHolder()
	if notifGui and notifGui.Parent then return notifGui.Holder end
	notifGui = create("ScreenGui", { Name = "LuminNotify", ResetOnSpawn = false, DisplayOrder = 10002, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	mount(notifGui)
	local holder = create("Frame", { Name = "Holder", AnchorPoint = V2(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(280, 500), BackgroundTransparency = 1, Parent = notifGui })
	list(holder, 8, VERT, { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right })
	return holder
end

function Lumin:Notify(cfg)
	cfg = cfg or {}
	local holder = getHolder()
	local content = cfg.Content or ""
	local th = content == "" and 0 or TextService:GetTextSize(content, 12, FONT_REG, V2(236, 1000)).Y
	local h = 16 + 18 + (th > 0 and th + 4 or 0) + 14
	local col = ({ Info = Theme.Accent, Success = Theme.Good, Warning = Theme.Warn, Error = Theme.Error })[cfg.Type or "Info"] or Theme.Accent

	local wrap = create("Frame", { Size = UDim2.fromOffset(280, h), BackgroundTransparency = 1, Parent = holder })
	local card = create("CanvasGroup", { Position = UDim2.fromOffset(300, 0), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = Theme.Panel, GroupTransparency = 1, Parent = wrap })
	corner(card, 12); stroke(card, Theme.Element, 1)
	local bar = create("Frame", { Position = UDim2.fromOffset(10, 12), Size = UDim2.new(0, 3, 1, -24), BackgroundColor3 = col, Parent = card }); corner(bar, 2)
	create("TextLabel", { Text = cfg.Title or "Lumin", Font = FONT_BOLD, Position = UDim2.fromOffset(24, 12), Size = UDim2.new(1, -36, 0, 18), Parent = card })
	if th > 0 then
		create("TextLabel", { Text = content, Font = FONT_REG, TextSize = 12, TextColor3 = Theme.SubText, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(24, 32), Size = UDim2.new(1, -36, 0, th), Parent = card })
	end
	local prog = create("Frame", { AnchorPoint = V2(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = col, BackgroundTransparency = .4, Parent = card })

	local dur = cfg.Duration or 4
	tw(card, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, .45, Enum.EasingStyle.Back)
	tw(prog, { Size = UDim2.new(0, 0, 0, 2) }, dur, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		tw(card, { Position = UDim2.fromOffset(300, 0), GroupTransparency = 1 }, .35)
		task.wait(.3)
		tw(wrap, { Size = UDim2.fromOffset(280, 0) }, .25)
		task.wait(.3)
		wrap:Destroy()
	end)
end

------------------------------------------------------------------------
-- Switch graphic (pill with bar + ring knob)
------------------------------------------------------------------------
local function buildSwitch(parent)
	local sw = create("Frame", { Name = "Switch", AnchorPoint = V2(1, .5), Position = UDim2.new(1, 0, .5, 0), Size = UDim2.fromOffset(46, 24), BackgroundColor3 = Theme.Switch, Parent = parent })
	corner(sw, 12)
	local bar = create("Frame", { AnchorPoint = V2(.5, .5), Size = UDim2.fromOffset(2, 10), Parent = sw }); corner(bar, 1)
	local knob = create("Frame", { AnchorPoint = V2(.5, .5), Size = UDim2.fromOffset(18, 18), Parent = sw }); corner(knob, 9)
	local dot = create("Frame", { AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(24, 24, 32), Parent = knob }); corner(dot, 4)
	local state = false
	local api = { Frame = sw }
	function api.Render(on, instant)
		state = on
		local col = on and Theme.Accent or Theme.AccentDim
		local kp = UDim2.new(0, on and 33 or 13, .5, 0)
		local bp = UDim2.new(0, on and 13 or 33, .5, 0)
		if instant then
			knob.Position, bar.Position, knob.BackgroundColor3, bar.BackgroundColor3 = kp, bp, col, col
		else
			tw(knob, { Position = kp, BackgroundColor3 = col }, .25, Enum.EasingStyle.Back)
			tw(bar, { Position = bp, BackgroundColor3 = col }, .25)
		end
	end
	bind(function() api.Render(state, true) end)
	return api
end

------------------------------------------------------------------------
-- Panel (column of controls)
------------------------------------------------------------------------
local Panel = {}
Panel.__index = Panel

local function lock(root, locked, instant)
	local b = root:FindFirstChild("Blocker")
	if b then b.Visible = locked end
	if instant then root.GroupTransparency = locked and .55 or 0
	else tw(root, { GroupTransparency = locked and .55 or 0 }, .25) end
end

function Panel:_row(height, title)
	self.Order += 1
	local root = create("CanvasGroup", { Name = "Row", Size = UDim2.new(1, 0, 0, height), LayoutOrder = self.Order, Parent = self.Frame })
	create("TextButton", { Name = "Blocker", Size = FULL, ZIndex = 50, Visible = false, Active = true, Parent = root })
	table.insert(self.Window.Rows, { Root = root, Title = tostring(title or ""):lower() })
	if self.Gate then
		table.insert(self.Gate.Items, root)
		if not self.Gate.State then lock(root, true, true) end
	end
	return root
end

local function titleRow(root, name, marker, rightPad, y)
	local row = create("Frame", { Name = "TitleRow", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y or 2), Size = UDim2.new(1, -(rightPad or 0), 0, 18), Parent = root })
	list(row, 6, HORIZ, { VerticalAlignment = Enum.VerticalAlignment.Center })
	local t = create("TextLabel", { Name = "Title", Text = name or "", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 1, Parent = row })
	if marker then
		create("TextLabel", { Text = "*", Font = FONT_BOLD, TextSize = 18, TextColor3 = markerColor(marker), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, Parent = row })
	end
	return t, row
end

local function descLabel(root, text, y, rightPad)
	return create("TextLabel", { Name = "Desc", Text = text, Font = FONT_REG, TextSize = 12, TextColor3 = Theme.SubText, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, -(rightPad or 0), 0, 16), Parent = root })
end

local function commit(obj, cfg, silent)
	if obj.Flag then Lumin.Flags[obj.Flag] = obj.Value end
	if not silent and cfg.Callback then task.spawn(cfg.Callback, obj.Value) end
end

local function register(obj, cfg)
	obj.Flag = cfg.Flag
	if cfg.Flag then Lumin.Flags[cfg.Flag] = obj.Value; Lumin.Options[cfg.Flag] = obj end
end

-- Section header (optionally with a master toggle that gates the controls below it)
function Panel:AddHeader(cfg)
	if type(cfg) == "string" then cfg = { Name = cfg } end
	local root = self:_row(40, cfg.Name)
	if self.Order > 1 then create("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Divider, Parent = root }) end
	local area = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 1, -8), Parent = root })
	local _, row = titleRow(area, cfg.Name, cfg.Marker, 60, 0)
	row.AnchorPoint = V2(0, .5); row.Position = UDim2.fromScale(0, .5)
	row.Size = UDim2.new(1, -60, 0, 20)
	local t = row:FindFirstChild("Title"); t.Font = FONT_BOLD; t.TextSize = 14

	local obj = { Type = "Toggle", Value = cfg.Default and true or false }
	self.Gate = nil
	if cfg.Toggle ~= nil or cfg.Default ~= nil or cfg.Flag then
		local sw = buildSwitch(area)
		sw.Render(obj.Value, true)
		local hit = create("TextButton", { Size = FULL, ZIndex = 3, Parent = area })
		local gate = (cfg.Gate ~= false) and { Items = {}, State = obj.Value } or nil
		self.Gate = gate
		function obj:Set(v, silent)
			self.Value = v and true or false
			sw.Render(self.Value)
			if gate then gate.State = self.Value; for _, r in ipairs(gate.Items) do lock(r, not self.Value) end end
			commit(self, cfg, silent)
		end
		function obj:Get() return self.Value end
		hit.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
		register(obj, cfg)
	end
	return obj
end

function Panel:AddToggle(cfg)
	local root = self:_row(cfg.Description and 42 or 30, cfg.Name)
	titleRow(root, cfg.Name, cfg.Marker, 60, cfg.Description and 2 or 6)
	if cfg.Description then descLabel(root, cfg.Description, 20, 60) end
	local sw = buildSwitch(root)
	local obj = { Type = "Toggle", Value = cfg.Default and true or false }
	sw.Render(obj.Value, true)
	local hit = create("TextButton", { Size = FULL, ZIndex = 3, Parent = root })
	function obj:Set(v, silent) self.Value = v and true or false; sw.Render(self.Value); commit(self, cfg, silent) end
	function obj:Get() return self.Value end
	hit.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
	register(obj, cfg)
	return obj
end

function Panel:AddSlider(cfg)
	local min, max, inc = cfg.Min or 0, cfg.Max or 100, cfg.Increment or 1
	local dec = 0
	local p = tostring(inc):find("%.")
	if p then dec = #tostring(inc) - p end
	local suffix = cfg.Suffix or ""
	local root = self:_row(cfg.Description and 54 or 38, cfg.Name)
	titleRow(root, cfg.Name, cfg.Marker, 90)
	local val = create("TextLabel", { AnchorPoint = V2(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(90, 18), TextXAlignment = RIGHT, Parent = root })
	if cfg.Description then descLabel(root, cfg.Description, 20, 90) end
	local track = create("Frame", { Position = UDim2.fromOffset(0, cfg.Description and 40 or 26), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Theme.Track, Parent = root })
	corner(track, 4)
	local fill = create("Frame", { Size = UDim2.new(0, 7, 1, 0), BackgroundColor3 = Theme.Accent, Parent = track }); corner(fill, 4)
	local knob = create("Frame", { AnchorPoint = V2(.5, .5), Position = UDim2.new(0, 7, .5, 0), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.fromRGB(10, 10, 12), ZIndex = 2, Parent = track })
	corner(knob, 7)
	local ks = stroke(knob, Theme.Text, 1.5)
	bind(function() fill.BackgroundColor3 = Theme.Accent end)

	local obj = { Type = "Slider", Value = min }
	function obj:Set(v, silent, instant)
		v = math.clamp(math.floor(v / inc + .5) * inc, min, max)
		self.Value = tonumber(string.format("%." .. dec .. "f", v))
		val.Text = string.format("%." .. dec .. "f", self.Value) .. suffix
		local rel = (max == min) and 0 or (self.Value - min) / (max - min)
		local off = (.5 - rel) * 14
		local fs, kp = UDim2.new(rel, off, 1, 0), UDim2.new(rel, off, .5, 0)
		if instant then fill.Size, knob.Position = fs, kp else tw(fill, { Size = fs }, .12); tw(knob, { Position = kp }, .12) end
		commit(self, cfg, silent)
	end
	function obj:Get() return self.Value end

	local dragging = false
	local function fromX(x)
		obj:Set(min + (max - min) * math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1))
	end
	local hit = create("TextButton", { Position = UDim2.fromOffset(0, (cfg.Description and 40 or 26) - 8), Size = UDim2.new(1, 0, 0, 24), ZIndex = 3, Parent = root })
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; tw(knob, { Size = UDim2.fromOffset(17, 17) }, .12); fromX(i.Position.X)
		end
	end)
	connect(self.Window, UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
	end)
	connect(self.Window, UserInputService.InputEnded, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false; tw(knob, { Size = UDim2.fromOffset(14, 14) }, .12)
		end
	end)
	obj:Set(cfg.Default or min, true, true)
	register(obj, cfg)
	return obj
end

function Panel:AddDropdown(cfg)
	local multi = cfg.Multi
	local options = cfg.Options or {}
	local top = cfg.Description and 40 or 24
	local boxH = 34
	local baseH = top + boxH + 2
	local root = self:_row(baseH, cfg.Name)
	titleRow(root, cfg.Name, cfg.Marker, 0)
	if cfg.Description then descLabel(root, cfg.Description, 20) end
	local box = create("TextButton", { Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 0, boxH), BackgroundTransparency = 0, BackgroundColor3 = Theme.Element, Parent = root })
	corner(box, 8)
	local txt = create("TextLabel", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -40, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = box })
	local arrow = create("TextLabel", { Text = "▾", TextSize = 16, TextColor3 = Theme.SubText, TextXAlignment = CENTER, AnchorPoint = V2(1, .5), Position = UDim2.new(1, -10, .5, 0), Size = UDim2.fromOffset(18, 18), Parent = box })
	hoverable(box, "BackgroundColor3", Theme.Element, Theme.Hover)

	local lf = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, top + boxH + 6), Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 0, BackgroundColor3 = Theme.Element,
		ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.AccentDim, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = root,
	})
	corner(lf, 8); list(lf, 0); pad(lf, 4, 4, 4, 4)

	local obj = { Type = "Dropdown", Value = multi and {} or nil, Open = false }
	local btns = {}
	local function selected(o) if multi then return table.find(obj.Value, o) ~= nil end return obj.Value == o end
	local function refreshVisual()
		for o, b in pairs(btns) do tw(b, { TextColor3 = selected(o) and Theme.Accent or Theme.SubText }, .15) end
		if multi then txt.Text = #obj.Value > 0 and table.concat(obj.Value, ", ") or (cfg.Placeholder or "None")
		else txt.Text = obj.Value ~= nil and tostring(obj.Value) or (cfg.Placeholder or "Select") end
	end
	local function openH() return baseH + 6 + math.min(#options, 5) * 28 + 8 end
	function obj:Toggle(state)
		self.Open = state
		tw(root, { Size = UDim2.new(1, 0, 0, state and openH() or baseH) }, .3)
		tw(lf, { Size = UDim2.new(1, 0, 0, state and (math.min(#options, 5) * 28 + 8) or 0) }, .3)
		tw(arrow, { Rotation = state and 180 or 0 }, .25)
	end
	local function build()
		for _, c in pairs(btns) do c:Destroy() end
		btns = {}
		for idx, o in ipairs(options) do
			local b = create("TextButton", { Text = tostring(o), TextXAlignment = LEFT, TextColor3 = Theme.SubText, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = idx, Parent = lf })
			pad(b, 8, 0, 0, 0)
			b.MouseEnter:Connect(function() if not selected(o) then tw(b, { TextColor3 = Theme.Text }, .12) end end)
			b.MouseLeave:Connect(function() if not selected(o) then tw(b, { TextColor3 = Theme.SubText }, .12) end end)
			b.MouseButton1Click:Connect(function()
				if multi then
					local i = table.find(obj.Value, o)
					if i then table.remove(obj.Value, i) else table.insert(obj.Value, o) end
					refreshVisual(); commit(obj, cfg)
				else
					obj:Set(o); obj:Toggle(false)
				end
			end)
			btns[o] = b
		end
		refreshVisual()
	end
	function obj:Set(v, silent)
		if multi then
			self.Value = {}
			for _, o in ipairs(type(v) == "table" and v or {}) do if table.find(options, o) then table.insert(self.Value, o) end end
		else self.Value = v end
		refreshVisual(); commit(self, cfg, silent)
	end
	function obj:Get() return self.Value end
	function obj:Refresh(newOptions) options = newOptions; build(); if self.Open then self:Toggle(true) end end
	box.MouseButton1Click:Connect(function() obj:Toggle(not obj.Open) end)
	build()
	if cfg.Default ~= nil then obj:Set(cfg.Default, true) end
	register(obj, cfg)
	return obj
end

function Panel:AddColorPicker(cfg)
	local color = cfg.Default or Color3.new(1, 1, 1)
	local h, s, v = color:ToHSV()
	local baseH, fullH = 38, 172
	local root = self:_row(baseH, cfg.Name)
	titleRow(root, cfg.Name, cfg.Marker, 60)
	local hex = create("TextBox", { Font = FONT_REG, TextSize = 12, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, -60, 0, 16), Parent = root })
	local swatch = create("TextButton", { AnchorPoint = V2(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(42, 22), BackgroundTransparency = 0, Parent = root })
	corner(swatch, 11)

	local sv = create("Frame", { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 100), BackgroundColor3 = Color3.fromHSV(h, 1, 1), ClipsDescendants = true, Parent = root })
	corner(sv, 8)
	local sat = create("Frame", { Size = FULL, BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv })
	create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = sat })
	local val = create("Frame", { Size = FULL, BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
	create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = val })
	local cur = create("Frame", { AnchorPoint = V2(.5, .5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 3, Parent = sv })
	corner(cur, 6); stroke(cur, Color3.new(1, 1, 1), 2)

	local hue = create("Frame", { Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Color3.new(1, 1, 1), Parent = root })
	corner(hue, 6)
	local seq = {}
	for i = 0, 6 do table.insert(seq, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1 == 0 and (i == 6 and .9999 or 0) or i / 6, 1, 1))) end
	create("UIGradient", { Color = ColorSequence.new(seq), Parent = hue })
	local hcur = create("Frame", { AnchorPoint = V2(.5, .5), Size = UDim2.fromOffset(6, 16), Position = UDim2.fromScale(0, .5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = hue })
	corner(hcur, 3); stroke(hcur, Color3.new(0, 0, 0), 1, .5)

	local obj = { Type = "Color", Value = color, Open = false }
	local function render(instant)
		obj.Value = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = obj.Value
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		cur.Position = UDim2.fromScale(s, 1 - v)
		hcur.Position = UDim2.fromScale(h, .5)
		if not hex:IsFocused() then hex.Text = "#" .. obj.Value:ToHex():upper() end
	end
	function obj:Set(c, silent)
		h, s, v = c:ToHSV(); render(); commit(self, cfg, silent)
	end
	function obj:Get() return self.Value end
	local mode
	local function upd(i)
		if mode == "sv" then
			s = math.clamp((i.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
			v = 1 - math.clamp((i.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		elseif mode == "hue" then
			h = math.clamp((i.Position.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, .999)
		else return end
		render(); commit(obj, cfg)
	end
	local function begin(m) return function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then mode = m; upd(i) end
	end end
	sv.InputBegan:Connect(begin("sv")); hue.InputBegan:Connect(begin("hue"))
	connect(self.Window, UserInputService.InputChanged, function(i)
		if mode and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i) end
	end)
	connect(self.Window, UserInputService.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then mode = nil end
	end)
	hex.FocusLost:Connect(function()
		local ok, c = pcall(Color3.fromHex, hex.Text)
		if ok and c then obj:Set(c) else render() end
	end)
	swatch.MouseButton1Click:Connect(function()
		obj.Open = not obj.Open
		tw(root, { Size = UDim2.new(1, 0, 0, obj.Open and fullH or baseH) }, .3)
	end)
	render(); register(obj, cfg)
	return obj
end

function Panel:AddKeybind(cfg)
	local root = self:_row(cfg.Description and 42 or 30, cfg.Name)
	titleRow(root, cfg.Name, cfg.Marker, 90, cfg.Description and 2 or 6)
	if cfg.Description then descLabel(root, cfg.Description, 20, 90) end
	local btn = create("TextButton", { AnchorPoint = V2(1, .5), Position = UDim2.new(1, 0, .5, 0), Size = UDim2.fromOffset(78, 24), BackgroundTransparency = 0, BackgroundColor3 = Theme.Element, TextSize = 12, TextColor3 = Theme.SubText, Parent = root })
	corner(btn, 7)
	hoverable(btn, "BackgroundColor3", Theme.Element, Theme.Hover)
	local obj = { Type = "Keybind", Value = cfg.Default }
	local listening = false
	local function show() btn.Text = obj.Value and obj.Value.Name or "None" end
	function obj:Set(k, silent) self.Value = k; show(); commit(self, cfg, silent) end
	function obj:Get() return self.Value end
	btn.MouseButton1Click:Connect(function()
		listening = true; btn.Text = "..."; tw(btn, { TextColor3 = Theme.Accent }, .15)
	end)
	connect(self.Window, UserInputService.InputBegan, function(i, gpe)
		if listening and i.UserInputType == Enum.UserInputType.Keyboard then
			listening = false; tw(btn, { TextColor3 = Theme.SubText }, .15)
			obj:Set(i.KeyCode ~= Enum.KeyCode.Escape and i.KeyCode or nil)
		elseif not gpe and not listening and obj.Value and i.KeyCode == obj.Value and cfg.OnPress then
			task.spawn(cfg.OnPress)
		end
	end)
	show(); register(obj, cfg)
	return obj
end

function Panel:AddTextBox(cfg)
	local top = cfg.Description and 40 or 24
	local root = self:_row(top + 36, cfg.Name)
	titleRow(root, cfg.Name, cfg.Marker, 0)
	if cfg.Description then descLabel(root, cfg.Description, 20) end
	local box = create("Frame", { Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 0, BackgroundColor3 = Theme.Element, Parent = root })
	corner(box, 8)
	local st = stroke(box, Theme.Accent, 1, 1)
	local tb = create("TextBox", { PlaceholderText = cfg.Placeholder or "", PlaceholderColor3 = Theme.Muted, Text = cfg.Default or "", Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), ClearTextOnFocus = false, Parent = box })
	tb.Focused:Connect(function() tw(st, { Transparency = .3 }, .2) end)
	local obj = { Type = "TextBox", Value = cfg.Default or "" }
	function obj:Set(t, silent) self.Value = t; tb.Text = t; commit(self, cfg, silent) end
	function obj:Get() return self.Value end
	tb.FocusLost:Connect(function(enter)
		tw(st, { Transparency = 1 }, .2)
		if cfg.Finished and not enter then return end
		obj.Value = tb.Text; commit(obj, cfg)
	end)
	register(obj, cfg)
	return obj
end

-- Style: "Primary" (accent, tall) | "Row" (icon tile + chevron) | "Plain" (default)
function Panel:AddButton(cfg)
	local style = cfg.Style or "Plain"
	local obj = {}
	local function fire() if cfg.Callback then task.spawn(cfg.Callback) end end
	if style == "Primary" then
		local root = self:_row(44, cfg.Name)
		local b = create("TextButton", { Size = FULL, BackgroundTransparency = 0, ClipsDescendants = true, Parent = root })
		corner(b, 12)
		local c = create("Frame", { BackgroundTransparency = 1, AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), AutomaticSize = Enum.AutomaticSize.XY, Parent = b })
		list(c, 8, HORIZ, { VerticalAlignment = Enum.VerticalAlignment.Center })
		local ring = create("Frame", { Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, LayoutOrder = 1, Parent = c })
		corner(ring, 10); stroke(ring, Theme.OnAccent, 2)
		create("TextLabel", { Text = cfg.Icon or "✓", TextColor3 = Theme.OnAccent, Font = FONT_BOLD, TextSize = 12, TextXAlignment = CENTER, Size = FULL, Parent = ring })
		local lbl = create("TextLabel", { Text = cfg.Name, Font = FONT_BOLD, TextColor3 = Theme.OnAccent, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 20), LayoutOrder = 2, Parent = c })
		bind(function() b.BackgroundColor3 = Theme.Accent end)
		b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = Theme.Accent:Lerp(Color3.new(1, 1, 1), .15) }, .15) end)
		b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = Theme.Accent }, .15) end)
		ripple(b, Color3.new(1, 1, 1))
		b.MouseButton1Click:Connect(fire)
		function obj:SetText(t) lbl.Text = t end
	elseif style == "Row" then
		local root = self:_row(40, cfg.Name)
		local b = create("TextButton", { Size = FULL, BackgroundTransparency = 0, BackgroundColor3 = Theme.Row, Parent = root })
		corner(b, 10)
		local tile = create("Frame", { Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Theme.Tile, Parent = b }); corner(tile, 8)
		local ic, prop = makeIcon(tile, cfg.Icon or "◇", 14, Theme.SubText)
		ic.AnchorPoint = V2(.5, .5); ic.Position = UDim2.fromScale(.5, .5)
		local lbl = create("TextLabel", { Text = cfg.Name, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -80, 1, 0), Parent = b })
		local chev = create("TextLabel", { Text = "›", TextSize = 22, TextColor3 = Theme.SubText, TextXAlignment = CENTER, AnchorPoint = V2(1, .5), Position = UDim2.new(1, -10, .5, -1), Size = UDim2.fromOffset(20, 24), Parent = b })
		b.MouseEnter:Connect(function() tw(b, { BackgroundColor3 = Theme.Hover }, .15); tw(lbl, { TextColor3 = Theme.Text }, .15); tw(chev, { Position = UDim2.new(1, -6, .5, -1) }, .2) end)
		b.MouseLeave:Connect(function() tw(b, { BackgroundColor3 = Theme.Row }, .15); tw(lbl, { TextColor3 = Theme.SubText }, .15); tw(chev, { Position = UDim2.new(1, -10, .5, -1) }, .2) end)
		ripple(b)
		b.MouseButton1Click:Connect(fire)
		function obj:SetText(t) lbl.Text = t end
	else
		local hasCap = cfg.Title or cfg.Description
		local capH = hasCap and (cfg.Title and 20 or 0) + (cfg.Description and 18 or 0) + 4 or 0
		local root = self:_row(capH + 32, cfg.Name)
		local y = 0
		if cfg.Title then create("TextLabel", { Text = cfg.Title, TextColor3 = Theme.SubText, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 0), Parent = root }); y = 20 end
		if cfg.Description then descLabel(root, cfg.Description, y, 0); y += 18 end
		local b = create("TextButton", { Text = cfg.Name, Position = UDim2.fromOffset(0, capH), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 0, BackgroundColor3 = Theme.Element, Parent = root })
		corner(b, 8)
		hoverable(b, "BackgroundColor3", Theme.Element, Theme.Hover)
		ripple(b)
		b.MouseButton1Click:Connect(fire)
		function obj:SetText(t) b.Text = t end
	end
	obj.Fire = fire
	return obj
end

function Panel:AddLabel(text, sub)
	local root = self:_row(sub and 38 or 22, text)
	local t = create("TextLabel", { Text = text, TextColor3 = Theme.SubText, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 2), Parent = root })
	local d = sub and descLabel(root, sub, 20, 0)
	return { Set = function(_, a, b) t.Text = a; if d and b then d.Text = b end end }
end

function Panel:AddDivider()
	local root = self:_row(9, "")
	create("Frame", { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Divider, Parent = root })
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local Window, Page, Tab = {}, {}, {}
Window.__index, Page.__index, Tab.__index = Window, Page, Tab

function Lumin:CreateWindow(cfg)
	cfg = cfg or {}
	local win = setmetatable({ Pages = {}, Rows = {}, Connections = {}, Visible = true, BaseScale = cfg.Scale or 1 }, Window)
	table.insert(Lumin.Windows, win)

	local gui = create("ScreenGui", { Name = cfg.Name or "Lumin", ResetOnSpawn = false, DisplayOrder = 10000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	mount(gui)
	win.Gui = gui

	local root = create("CanvasGroup", {
		Name = "Window", AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), Size = cfg.Size or UDim2.fromOffset(780, 480),
		BackgroundTransparency = 0, BackgroundColor3 = Theme.Window, GroupTransparency = 1, Parent = gui,
	})
	corner(root, 14)
	win.Root = root
	win.Scale = create("UIScale", { Scale = win.BaseScale * .92, Parent = root })

	-- Sidebar
	local side = create("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(0, 176, 1, -16), BackgroundColor3 = Theme.Panel, Parent = root })
	corner(side, 12)
	local head = create("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, Parent = side })
	local avatar = create("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Theme.Element, Parent = head })
	corner(avatar, 10)
	if cfg.Icon then
		local img = create("ImageLabel", { Image = tonumber(cfg.Icon) and ("rbxassetid://" .. cfg.Icon) or cfg.Icon, Size = FULL, Parent = avatar }); corner(img, 10)
	else
		local g = create("TextLabel", { Text = (cfg.Name or "L"):sub(1, 1), Font = FONT_BOLD, TextSize = 20, TextXAlignment = CENTER, Size = FULL, Parent = avatar })
		bind(function() g.TextColor3 = Theme.Accent end)
	end
	create("TextLabel", { Text = cfg.Name or "Lumin", Font = FONT_BOLD, TextSize = 14, Position = UDim2.fromOffset(62, 14), Size = UDim2.new(1, -70, 0, 18), Parent = head })
	create("TextLabel", { Text = cfg.Subtitle or "Active user", Font = FONT_REG, TextSize = 12, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(62, 32), Size = UDim2.new(1, -70, 0, 16), Parent = head })
	local nav = create("ScrollingFrame", { Position = UDim2.fromOffset(8, 72), Size = UDim2.new(1, -16, 1, -80), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = side })
	list(nav, 4)

	-- Top bar
	local top = create("Frame", { Position = UDim2.fromOffset(192, 8), Size = UDim2.new(1, -200, 0, 44), BackgroundColor3 = Theme.Panel, Parent = root })
	corner(top, 12)
	local searchBox = create("Frame", { Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(150, 30), BackgroundColor3 = Theme.Element, Parent = top })
	corner(searchBox, 9)
	local sStroke = stroke(searchBox, Theme.Accent, 1, 1)
	create("TextLabel", { Text = "⌕", TextSize = 18, TextColor3 = Theme.SubText, TextXAlignment = CENTER, Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(24, 30), Parent = searchBox })
	local search = create("TextBox", { PlaceholderText = "Search", PlaceholderColor3 = Theme.Muted, Text = "", Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -38, 1, 0), Parent = searchBox })
	search.Focused:Connect(function() tw(sStroke, { Transparency = .4 }, .2) end)
	search.FocusLost:Connect(function() tw(sStroke, { Transparency = 1 }, .2) end)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		local q = search.Text:lower()
		for _, r in ipairs(win.Rows) do r.Root.Visible = (q == "" or r.Title:find(q, 1, true) ~= nil) end
	end)
	local tabBar = create("ScrollingFrame", { Position = UDim2.fromOffset(168, 4), Size = UDim2.new(1, -176, 1, -8), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, Parent = top })
	list(tabBar, 4, HORIZ, { VerticalAlignment = Enum.VerticalAlignment.Center })

	local content = create("Frame", { Position = UDim2.fromOffset(192, 60), Size = UDim2.new(1, -200, 1, -68), BackgroundTransparency = 1, Parent = root })
	win.Content, win.NavList, win.TabBar = content, nav, tabBar

	draggable(top, root, win); draggable(head, root, win)

	-- Toggle keybind
	local key = cfg.Keybind or Enum.KeyCode.RightShift
	connect(win, UserInputService.InputBegan, function(i, gpe)
		if not gpe and i.KeyCode == key then win:SetVisible(not win.Visible) end
	end)

	-- Mobile toggle button
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		local mb = create("TextButton", { Text = (cfg.Name or "L"):sub(1, 1), Font = FONT_BOLD, TextSize = 18, Position = UDim2.new(0, 12, .5, 0), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 0, BackgroundColor3 = Theme.Panel, TextColor3 = Theme.Accent, Parent = gui })
		corner(mb, 22); stroke(mb, Theme.Element, 1)
		mb.MouseButton1Click:Connect(function() win:SetVisible(not win.Visible) end)
	end

	win:SetVisible(true)
	return win
end

function Window:SetVisible(v)
	self.Visible = v
	if v then
		self.Root.Visible = true
		tw(self.Root, { GroupTransparency = 0 }, .3)
		tw(self.Scale, { Scale = self.BaseScale }, .4, Enum.EasingStyle.Back)
	else
		tw(self.Root, { GroupTransparency = 1 }, .2)
		tw(self.Scale, { Scale = self.BaseScale * .94 }, .2)
		task.delay(.22, function() if not self.Visible then self.Root.Visible = false end end)
	end
end
function Window:Toggle() self:SetVisible(not self.Visible) end
function Window:SetScale(n) self.BaseScale = n; tw(self.Scale, { Scale = n }, .25) end
function Window:Destroy()
	for _, c in ipairs(self.Connections) do c:Disconnect() end
	self.Gui:Destroy()
end

function Window:SelectPage(page)
	if self.ActivePage == page then return end
	local old = self.ActivePage
	if old then
		old:_style(false)
		if old.ActiveTab then old.ActiveTab.Frame.Visible = false end
		for _, t in ipairs(old.Tabs) do if t.Button then t.Button.Visible = false end end
	end
	self.ActivePage = page
	page:_style(true)
	for _, t in ipairs(page.Tabs) do if t.Button then t.Button.Visible = true end end
	if page.ActiveTab then page.ActiveTab = nil; self:SelectTab(page.Tabs[page._last or 1]) end
end

function Window:SelectTab(tab)
	local page = tab.Page
	if page.ActiveTab == tab then return end
	if page.ActiveTab then
		page.ActiveTab.Frame.Visible = false
		page.ActiveTab:_style(false)
	end
	page.ActiveTab = tab
	page._last = table.find(page.Tabs, tab)
	tab:_style(true)
	if self.ActivePage == page then
		tab.Frame.Visible = true
		tab.Frame.GroupTransparency = 1
		tab.Frame.Position = UDim2.fromOffset(0, 12)
		tw(tab.Frame, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, .35)
	end
end

function Window:AddPage(name, icon)
	local pg = setmetatable({ Name = name, Tabs = {}, Window = self }, Page)
	local order = #self.Pages + 1
	local btn = create("TextButton", { Name = name, Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, BackgroundColor3 = Theme.Element, LayoutOrder = order, Parent = self.NavList })
	corner(btn, 10)
	local bar = create("Frame", { AnchorPoint = V2(0, .5), Position = UDim2.new(0, 0, .5, 0), Size = UDim2.fromOffset(3, 0), BackgroundTransparency = 1, Parent = btn })
	corner(bar, 2)
	bind(function() bar.BackgroundColor3 = Theme.Accent end)
	local ic, prop = makeIcon(btn, icon or "●", 16, Theme.Muted)
	ic.AnchorPoint = V2(0, .5); ic.Position = UDim2.new(0, 12, .5, 0)
	local lbl = create("TextLabel", { Text = name, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -44, 1, 0), Parent = btn })
	function pg:_style(active)
		tw(btn, { BackgroundTransparency = active and 0 or 1 }, .2)
		tw(lbl, { TextColor3 = active and Theme.Text or Theme.SubText }, .2)
		tw(ic, { [prop] = active and Theme.Text or Theme.Muted }, .2)
		tw(bar, { Size = UDim2.fromOffset(3, active and 20 or 0), BackgroundTransparency = active and 0 or 1 }, .25)
	end
	btn.MouseEnter:Connect(function() if self.ActivePage ~= pg then tw(lbl, { TextColor3 = Theme.Text }, .12) end end)
	btn.MouseLeave:Connect(function() if self.ActivePage ~= pg then tw(lbl, { TextColor3 = Theme.SubText }, .12) end end)
	btn.MouseButton1Click:Connect(function() self:SelectPage(pg) end)
	table.insert(self.Pages, pg)
	if order == 1 then self.ActivePage = pg; pg:_style(true) end
	return pg
end

function Page:AddTab(name, icon)
	local win = self.Window
	local tab = setmetatable({ Name = name, Page = self, _side = 0 }, Tab)
	local frame = create("CanvasGroup", { Name = name or "Default", Size = FULL, Visible = false, Parent = win.Content })
	tab.Frame = frame
	local function column(xs, xo)
		local sf = create("ScrollingFrame", {
			Position = UDim2.new(xs, xo, 0, 0), Size = UDim2.new(.5, -4, 1, 0), BackgroundTransparency = 0, BackgroundColor3 = Theme.Panel,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.AccentDim,
			Parent = frame,
		})
		corner(sf, 12); pad(sf, 12, 8, 12, 12); list(sf, 6)
		return setmetatable({ Frame = sf, Window = win, Order = 0 }, Panel)
	end
	tab.Left, tab.Right = column(0, 0), column(.5, 4)

	if name then
		local b = create("TextButton", { Name = name, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 32), BackgroundTransparency = 1, BackgroundColor3 = Theme.Element, Visible = win.ActivePage == self, LayoutOrder = #self.Tabs + 1, Parent = win.TabBar })
		corner(b, 9); pad(b, 12, 0, 12, 0)
		list(b, 8, HORIZ, { VerticalAlignment = Enum.VerticalAlignment.Center })
		local ic, prop
		if icon then ic, prop = makeIcon(b, icon, 15, Theme.Muted); ic.LayoutOrder = 1 end
		local lbl = create("TextLabel", { Text = name, TextColor3 = Theme.SubText, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, Parent = b })
		tab.Button = b
		function tab:_style(active)
			tw(b, { BackgroundTransparency = active and 0 or 1 }, .2)
			tw(lbl, { TextColor3 = active and Theme.Text or Theme.SubText }, .2)
			if ic then tw(ic, { [prop] = active and Theme.Text or Theme.Muted }, .2) end
		end
		b.MouseEnter:Connect(function() if self.ActiveTab ~= tab then tw(lbl, { TextColor3 = Theme.Text }, .12) end end)
		b.MouseLeave:Connect(function() if self.ActiveTab ~= tab then tw(lbl, { TextColor3 = Theme.SubText }, .12) end end)
		b.MouseButton1Click:Connect(function() win:SelectTab(tab) end)
	else
		function tab:_style() end
	end

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then win:SelectTab(tab) end
	return tab
end

function Tab:AddPanel(side)
	if side == nil then self._side += 1; side = (self._side % 2 == 1) and "Left" or "Right" end
	return side == "Right" and self.Right or self.Left
end

function Page:AddPanel(side)
	self.Default = self.Default or self:AddTab(nil)
	return self.Default:AddPanel(side)
end

------------------------------------------------------------------------
-- Theme / config
------------------------------------------------------------------------
function Lumin:SetAccent(color)
	Theme.Accent = color
	Theme.AccentDim = color:Lerp(Theme.Switch, .55)
	for _, fn in ipairs(self._hooks) do pcall(fn) end
end

local function cfgPath(name) return "Lumin/" .. (name or "default") .. ".json" end

function Lumin:SaveConfig(name)
	if not (writefile and makefolder) then return false, "filesystem unavailable" end
	local data = {}
	for flag, o in pairs(self.Options) do
		if o.Type == "Color" then data[flag] = "#" .. o.Value:ToHex()
		elseif o.Type == "Keybind" then data[flag] = o.Value and o.Value.Name or ""
		else data[flag] = o.Value end
	end
	pcall(function() if not (isfolder and isfolder("Lumin")) then makefolder("Lumin") end end)
	local ok, err = pcall(writefile, cfgPath(name), HttpService:JSONEncode(data))
	return ok, err
end

function Lumin:LoadConfig(name)
	if not hasFS() or not isfile(cfgPath(name)) then return false, "config not found" end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(cfgPath(name))) end)
	if not ok then return false, "corrupt config" end
	for flag, v in pairs(data) do
		local o = self.Options[flag]
		if o then
			pcall(function()
				if o.Type == "Color" then o:Set(Color3.fromHex(v))
				elseif o.Type == "Keybind" then o:Set(v ~= "" and Enum.KeyCode[v] or nil)
				else o:Set(v) end
			end)
		end
	end
	return true
end

------------------------------------------------------------------------
-- KEY SYSTEM
------------------------------------------------------------------------
--[[
    Lumin:KeySystem({
        Title        = "Lumin",
        Subtitle     = "License access",
        Icon         = nil,                       -- optional asset id for the logo
        Placeholder  = "Enter license key",

        -- pick ONE (or combine; first match wins, Validate takes priority):
        Validate     = function(key, hwid) return true/false, "optional message" end,
        Keys         = { "KEY-1", "KEY-2" },      -- plaintext (visible in the script!)
        HashedKeys   = { "<sha256 hex>", ... },   -- Lumin.SHA256(key)
        Url          = "https://api.site.com/check?key={key}&hwid={hwid}",
        ValidateResponse = function(body, status) return bool, msg end,

        CaseSensitive = true,
        SaveKey      = true,  FileName = "Lumin_Key.txt",
        MaxAttempts  = 5,     Cooldown = 30,
        GetKeyLink   = "https://...", GetKeyText = "Get a key",
        Closable     = true,  Wait = true,
        Callback     = function(key) end,          -- fires on success
        OnFail       = function(key, msg) end,
    })  --> success, key
]]
local function drawKey(parent, color, size, pos, anchor)
	local c = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Position = pos, AnchorPoint = anchor or V2(0, 0), Rotation = -32, Parent = parent })
	local r = math.floor(size * .42)
	local ring = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, math.floor((size - r) / 2)), Size = UDim2.fromOffset(r, r), Parent = c })
	corner(ring, 999)
	local rs = stroke(ring, color, 2)
	local shaftLen = size - r + 2
	local parts = {}
	parts[1] = create("Frame", { BackgroundColor3 = color, Position = UDim2.fromOffset(r - 2, math.floor(size / 2) - 1), Size = UDim2.fromOffset(shaftLen, 2), Parent = c })
	parts[2] = create("Frame", { BackgroundColor3 = color, Position = UDim2.fromOffset(size - 3, math.floor(size / 2)), Size = UDim2.fromOffset(2, math.floor(size * .22)), Parent = c })
	parts[3] = create("Frame", { BackgroundColor3 = color, Position = UDim2.fromOffset(size - 8, math.floor(size / 2)), Size = UDim2.fromOffset(2, math.floor(size * .16)), Parent = c })
	return c, function(col, t)
		tw(rs, { Color = col }, t or .25)
		for _, p in ipairs(parts) do tw(p, { BackgroundColor3 = col }, t or .25) end
	end
end

local function httpGet(url)
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if req then
		local ok, res = pcall(req, { Url = url, Method = "GET" })
		if ok and res then return res.Body, res.StatusCode end
	end
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok then return body, 200 end
	return nil, 0
end

local function getHWID()
	local ok, id = pcall(function() return Analytics:GetClientId() end)
	return ok and id or "unknown"
end

function Lumin:KeySystem(cfg)
	cfg = cfg or {}
	local K = Theme.Key
	local file = cfg.FileName or "Lumin_Key.txt"
	local saveKey = cfg.SaveKey ~= false and hasFS()
	local maxAttempts, cooldown = cfg.MaxAttempts or 5, cfg.Cooldown or 30
	local hwid = getHWID()

	local function check(key)
		key = tostring(key or ""):match("^%s*(.-)%s*$")
		if key == "" then return false, "Enter a license key" end
		if cfg.Validate then
			local ok, res, msg = pcall(cfg.Validate, key, hwid)
			if not ok then return false, "Validation error" end
			return res and true or false, msg
		end
		if cfg.HashedKeys then
			local h = Lumin.SHA256(cfg.CaseSensitive == false and key:lower() or key)
			for _, k in ipairs(cfg.HashedKeys) do if k:lower() == h then return true end end
		end
		if cfg.Keys then
			for _, k in ipairs(cfg.Keys) do
				if cfg.CaseSensitive == false then if k:lower() == key:lower() then return true end
				elseif k == key then return true end
			end
		end
		if cfg.Url then
			local url = cfg.Url:gsub("{key}", HttpService:UrlEncode(key)):gsub("{hwid}", HttpService:UrlEncode(hwid))
			local body, status = httpGet(url)
			if not body then return false, "Could not reach server" end
			if cfg.ValidateResponse then
				local ok, res, msg = pcall(cfg.ValidateResponse, body, status)
				return ok and res and true or false, msg
			end
			local okj, data = pcall(function() return HttpService:JSONDecode(body) end)
			if okj and type(data) == "table" then
				return (data.valid == true or data.success == true), data.message
			end
			return body:lower():match("^%s*(.-)%s*$") == "true"
		end
		return false, "Invalid license key"
	end

	-- Auto-login with saved key
	if saveKey and isfile(file) then
		local ok, saved = pcall(readfile, file)
		if ok and saved and saved ~= "" then
			local good = check(saved)
			if good then
				if cfg.Callback then task.spawn(cfg.Callback, saved) end
				return true, saved
			end
		end
	end

	-- UI
	local H = cfg.GetKeyLink and 318 or 276
	local gui = create("ScreenGui", { Name = "LuminKey", ResetOnSpawn = false, DisplayOrder = 10001, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	mount(gui)
	local dim = create("Frame", { Size = FULL, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = gui })
	if cfg.Dim ~= false then tw(dim, { BackgroundTransparency = .45 }, .4) end
	local card = create("CanvasGroup", { AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(400, H), BackgroundTransparency = 0, BackgroundColor3 = K.Panel, GroupTransparency = 1, Parent = gui })
	corner(card, 16)
	local scale = create("UIScale", { Scale = .92, Parent = card })
	tw(card, { GroupTransparency = 0 }, .35); tw(scale, { Scale = 1 }, .45, Enum.EasingStyle.Back)

	-- header
	local tile = create("Frame", { Position = UDim2.fromOffset(20, 20), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = K.Tile, Parent = card })
	corner(tile, 12)
	local setHeaderIcon
	if cfg.Icon then
		local im = create("ImageLabel", { Image = tonumber(cfg.Icon) and ("rbxassetid://" .. cfg.Icon) or cfg.Icon, Size = FULL, Parent = tile }); corner(im, 12)
	else
		local _, set = drawKey(tile, K.Icon, 26, UDim2.fromScale(.5, .5), V2(.5, .5))
		setHeaderIcon = set
	end
	create("TextLabel", { Text = cfg.Title or "Lumin", Font = FONT_BOLD, TextSize = 16, Position = UDim2.fromOffset(80, 24), Size = UDim2.new(1, -130, 0, 20), Parent = card })
	create("TextLabel", { Text = cfg.Subtitle or "License access", Font = FONT_REG, TextSize = 12, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(80, 44), Size = UDim2.new(1, -130, 0, 16), Parent = card })

	local finished, success, usedKey = false, false, nil
	local function close(ok)
		if finished then return end
		finished = true; success = ok
		tw(card, { GroupTransparency = 1 }, .3); tw(scale, { Scale = ok and 1.04 or .94 }, .3); tw(dim, { BackgroundTransparency = 1 }, .3)
		task.delay(.35, function() gui:Destroy() end)
	end
	if cfg.Closable ~= false then
		local x = create("TextButton", { Text = "✕", TextSize = 14, TextColor3 = Theme.Muted, TextXAlignment = CENTER, AnchorPoint = V2(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(28, 28), Parent = card })
		x.MouseEnter:Connect(function() tw(x, { TextColor3 = Theme.Text }, .15) end)
		x.MouseLeave:Connect(function() tw(x, { TextColor3 = Theme.Muted }, .15) end)
		x.MouseButton1Click:Connect(function() close(false) end)
	end

	-- input
	create("TextLabel", { Text = "License key", Font = FONT_BOLD, Position = UDim2.fromOffset(20, 88), Size = UDim2.new(1, -40, 0, 18), Parent = card })
	local inputBox = create("Frame", { Position = UDim2.fromOffset(20, 112), Size = UDim2.new(1, -40, 0, 46), BackgroundTransparency = 0, BackgroundColor3 = K.Input, Parent = card })
	corner(inputBox, 10)
	local inStroke = stroke(inputBox, Theme.Accent, 1, 1)
	local _, setInputIcon = drawKey(inputBox, Theme.Accent, 22, UDim2.fromOffset(16, 12))
	local input = create("TextBox", { PlaceholderText = cfg.Placeholder or "Enter license key", PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text, Text = "", TextSize = 14, Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -66, 1, 0), ClearTextOnFocus = false, Parent = inputBox })
	input.Focused:Connect(function() tw(inStroke, { Transparency = .35 }, .2) end)
	input.FocusLost:Connect(function(enter) tw(inStroke, { Transparency = 1 }, .2); if enter then task.defer(function() card:SetAttribute("go", (card:GetAttribute("go") or 0) + 1) end) end end)

	-- status + button
	create("Frame", { Position = UDim2.fromOffset(20, 166), Size = UDim2.new(1, -40, 0, 1), BackgroundColor3 = Color3.fromRGB(44, 44, 50), Parent = card })
	local _, setStatusIcon = drawKey(card, Theme.Muted, 14, UDim2.fromOffset(20, 176))
	local status = create("TextLabel", { Text = "Enter your license key to continue", Font = FONT_REG, TextSize = 12, TextColor3 = Theme.Muted, Position = UDim2.fromOffset(44, 174), Size = UDim2.new(1, -64, 0, 20), Parent = card })
	local btn = create("TextButton", { Position = UDim2.fromOffset(20, 202), Size = UDim2.new(1, -40, 0, 52), BackgroundTransparency = 0, BackgroundColor3 = Theme.Accent, Parent = card })
	corner(btn, 14); ripple(btn, Color3.new(1, 1, 1))
	local bc = create("Frame", { BackgroundTransparency = 1, AnchorPoint = V2(.5, .5), Position = UDim2.fromScale(.5, .5), AutomaticSize = Enum.AutomaticSize.XY, Parent = btn })
	list(bc, 10, HORIZ, { VerticalAlignment = Enum.VerticalAlignment.Center })
	local ring = create("Frame", { Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, LayoutOrder = 1, Parent = bc })
	corner(ring, 11); stroke(ring, Theme.OnAccent, 2)
	local ringIcon = create("TextLabel", { Text = "✓", Font = FONT_BOLD, TextSize = 13, TextColor3 = Theme.OnAccent, TextXAlignment = CENTER, Size = FULL, Parent = ring })
	local btnLabel = create("TextLabel", { Text = "Activate", Font = FONT_BOLD, TextColor3 = Theme.OnAccent, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 20), LayoutOrder = 2, Parent = bc })

	if cfg.GetKeyLink then
		local g = create("TextButton", { Text = cfg.GetKeyText or "Get a key", TextColor3 = Theme.SubText, Position = UDim2.fromOffset(20, 264), Size = UDim2.new(1, -40, 0, 34), BackgroundTransparency = 0, BackgroundColor3 = K.Input, Parent = card })
		corner(g, 10); hoverable(g, "BackgroundColor3", K.Input, Theme.Hover); ripple(g)
		g.MouseEnter:Connect(function() tw(g, { TextColor3 = Theme.Text }, .15) end)
		g.MouseLeave:Connect(function() tw(g, { TextColor3 = Theme.SubText }, .15) end)
		g.MouseButton1Click:Connect(function()
			local ok = pcall(function() setclipboard(cfg.GetKeyLink) end)
			status.Text = ok and "Link copied to clipboard" or cfg.GetKeyLink
		end)
	end

	-- state machine
	local state, busy, locked, token = "idle", false, false, 0
	local function setState(st, msg)
		state = st
		local col = (st == "error" or st == "locked") and K.Error or (st == "success") and Theme.Good or Theme.Accent
		tw(btn, { BackgroundColor3 = col }, .3)
		setInputIcon(col); setStatusIcon((st == "idle" or st == "checking") and Theme.Muted or col)
		if setHeaderIcon then setHeaderIcon(col) end
		tw(status, { TextColor3 = (st == "idle" or st == "checking") and Theme.Muted or col }, .25)
		if msg then status.Text = msg end
	end

	local function shake()
		task.spawn(function()
			for _, o in ipairs({ -10, 9, -6, 5, -2, 0 }) do
				tw(card, { Position = UDim2.new(.5, o, .5, 0) }, .045, Enum.EasingStyle.Sine)
				task.wait(.045)
			end
		end)
	end

	local function attempt()
		if busy or locked or finished then return end
		local key = input.Text
		busy = true; token += 1
		local my = token
		setState("checking", "Verifying key...")
		ringIcon.Text = "…"
		task.spawn(function()
			local n = 0
			while busy and token == my do
				btnLabel.Text = "Checking" .. string.rep(".", n % 4); n += 1; task.wait(.25)
			end
		end)
		task.spawn(function()
			local okc, valid, msg = pcall(check, key)
			if not okc then valid, msg = false, "Validation error" end
			busy = false
			ringIcon.Text = "✓"
			if valid then
				usedKey = key:match("^%s*(.-)%s*$")
				if saveKey then pcall(writefile, file, usedKey) end
				btnLabel.Text = "Access granted"
				setState("success", msg or "License verified")
				task.wait(.8)
				close(true)
			else
				btnLabel.Text = "Activate"
				setState("error", msg or "Invalid license key")
				shake()
				if cfg.OnFail then task.spawn(cfg.OnFail, key, msg) end
				cfg._attempts = (cfg._attempts or 0) + 1
				if cfg._attempts >= maxAttempts then
					locked = true
					for t = cooldown, 1, -1 do
						if finished then return end
						btnLabel.Text = "Locked (" .. t .. "s)"
						status.Text = "Too many attempts. Try again soon."
						task.wait(1)
					end
					cfg._attempts, locked = 0, false
					btnLabel.Text = "Activate"
					setState("idle", "Enter your license key to continue")
				end
			end
		end)
	end

	btn.MouseButton1Click:Connect(attempt)
	card:GetAttributeChangedSignal("go"):Connect(attempt)
	input:GetPropertyChangedSignal("Text"):Connect(function()
		if state == "error" and not locked then setState("idle", "Enter your license key to continue") end
	end)

	draggable(card, card, nil)

	if cfg.Wait == false then return { Success = false } end
	repeat task.wait(.05) until finished
	if success and cfg.Callback then task.spawn(cfg.Callback, usedKey) end
	return success, usedKey
end

return Lumin
