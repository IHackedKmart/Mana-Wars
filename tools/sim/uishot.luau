--[[
	UI snapshots for the fake engine: lays out a PlayerGui the way Roblox would (UDim2 sizes and
	positions, anchor points, UIListLayout / UIGridLayout, UIPadding, AutomaticSize, clipping,
	ZIndex, DisplayOrder) and writes it as JSON. tools/ui/render.mjs turns the JSON into a PNG with
	headless Chromium, so screens can be looked at without opening Roblox Studio.

		local UIShot = require("./uishot")
		UIShot.save(playerGui, "build/ui/spellbook.json")

	It's an approximation (text is measured roughly, images and 3D viewports are drawn as plain
	boxes), but positions, sizes, colours and text match what the game sets.
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local UIShot = {}

local VIEW_W, VIEW_H = 1280, 720

local function props(inst): { [string]: any }
	return rawget(inst, "_props") or {}
end

local function prop(inst, name: string, default: any): any
	local v = props(inst)[name]
	if v == nil then
		return default
	end
	return v
end

local function className(inst): string
	return rawget(inst, "ClassName") or "?"
end

local function children(inst): { any }
	return rawget(inst, "_children") or {}
end

local GUI = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
	ViewportFrame = true,
	CanvasGroup = true,
}

local function isGui(inst): boolean
	return GUI[className(inst)] == true
end

local function isText(inst): boolean
	local c = className(inst)
	return c == "TextLabel" or c == "TextButton" or c == "TextBox"
end

local function childOfClass(inst, name: string): any
	for _, c in children(inst) do
		if className(c) == name then
			return c
		end
	end
	return nil
end

local function enumName(v: any): string
	if v == nil then
		return ""
	end
	return tostring(v.Name or v)
end

local function udim2(v: any): (number, number, number, number)
	if v == nil then
		return 0, 0, 0, 0
	end
	return v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset
end

local function udim(v: any, total: number): number
	if v == nil then
		return 0
	end
	return v.Scale * total + v.Offset
end

local function color(c: any): { number }?
	if c == nil then
		return nil
	end
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local function stripRich(text: string): string
	return (string.gsub(text, "<[^>]+>", ""))
end

-- Rough text height for AutomaticSize: glyphs average ~0.55em wide, lines ~1.2em tall.
local function textHeight(inst, width: number): number
	local text = tostring(prop(inst, "Text", ""))
	if prop(inst, "RichText", false) then
		text = stripRich(text)
	end
	local size = prop(inst, "TextSize", 14)
	if text == "" then
		return 0
	end
	local perLine = math.max(1, math.floor(width / (size * 0.6)))
	local lines = 0
	for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
		if prop(inst, "TextWrapped", false) then
			lines += math.max(1, math.ceil(utf8.len(line) or #line) / perLine)
		else
			lines += 1
		end
	end
	return math.ceil(lines) * size * 1.2
end

local function textWidth(inst): number
	local text = tostring(prop(inst, "Text", ""))
	if prop(inst, "RichText", false) then
		text = stripRich(text)
	end
	local size = prop(inst, "TextSize", 14)
	local longest = 0
	for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
		longest = math.max(longest, utf8.len(line) or #line)
	end
	return longest * size * 0.55
end

local function sortedGuiChildren(inst): { any }
	local list = {}
	for i, c in children(inst) do
		if isGui(c) and prop(c, "Visible", true) ~= false then
			table.insert(list, { inst = c, i = i })
		end
	end
	return list
end

type Node = {
	inst: any,
	x: number,
	y: number,
	w: number,
	h: number,
	kids: { Node },
}

local build: (inst: any, parentW: number, parentH: number, forced: { X: number, Y: number }?) -> Node

build = function(inst, parentW, parentH, forced)
	local sx, ox, sy, oy = udim2(prop(inst, "Size", nil))
	local w = if forced then forced.X else sx * parentW + ox
	local h = if forced then forced.Y else sy * parentH + oy
	local node: Node = { inst = inst, x = 0, y = 0, w = w, h = h, kids = {} }
	local pad = childOfClass(inst, "UIPadding")
	local pl = if pad then udim(prop(pad, "PaddingLeft", nil), w) else 0
	local pr = if pad then udim(prop(pad, "PaddingRight", nil), w) else 0
	local pt = if pad then udim(prop(pad, "PaddingTop", nil), h) else 0
	local pb = if pad then udim(prop(pad, "PaddingBottom", nil), h) else 0
	local cw, ch = math.max(0, w - pl - pr), math.max(0, h - pt - pb)
	local auto = enumName(prop(inst, "AutomaticSize", nil))
	local list = childOfClass(inst, "UIListLayout")
	local grid = childOfClass(inst, "UIGridLayout")
	local kids = sortedGuiChildren(inst)
	if list or grid then
		table.sort(kids, function(a, b)
			local la, lb = prop(a.inst, "LayoutOrder", 0), prop(b.inst, "LayoutOrder", 0)
			if la ~= lb then
				return la < lb
			end
			return a.i < b.i
		end)
	end
	local maxRight, maxBottom = 0, 0
	if list then
		local horizontal = enumName(prop(list, "FillDirection", nil)) == "Horizontal"
		local gap = udim(prop(list, "Padding", nil), if horizontal then cw else ch)
		local cursor = 0
		for _, k in kids do
			local n = build(k.inst, cw, ch, nil)
			if horizontal then
				n.x, n.y = pl + cursor, pt
				cursor += n.w + gap
			else
				n.x, n.y = pl, pt + cursor
				cursor += n.h + gap
			end
			table.insert(node.kids, n)
		end
		-- alignment
		local total = cursor - (if #kids > 0 then gap else 0)
		local hAlign = enumName(prop(list, "HorizontalAlignment", nil))
		local vAlign = enumName(prop(list, "VerticalAlignment", nil))
		for _, n in node.kids do
			if horizontal then
				if hAlign == "Center" then
					n.x += (cw - total) / 2
				elseif hAlign == "Right" then
					n.x += cw - total
				end
				if vAlign == "Center" then
					n.y += (ch - n.h) / 2
				elseif vAlign == "Bottom" then
					n.y += ch - n.h
				end
			else
				if hAlign == "Center" then
					n.x += (cw - n.w) / 2
				elseif hAlign == "Right" then
					n.x += cw - n.w
				end
				if vAlign == "Center" then
					n.y += (ch - total) / 2
				elseif vAlign == "Bottom" then
					n.y += ch - total
				end
			end
		end
	elseif grid then
		local cell = prop(grid, "CellSize", nil)
		local gapV = prop(grid, "CellPadding", nil)
		local cwid = if cell then cell.X.Scale * cw + cell.X.Offset else 100
		local chei = if cell then cell.Y.Scale * ch + cell.Y.Offset else 100
		local gx = if gapV then gapV.X.Scale * cw + gapV.X.Offset else 4
		local gy = if gapV then gapV.Y.Scale * ch + gapV.Y.Offset else 4
		local perRow = math.max(1, math.floor((cw + gx) / (cwid + gx)))
		for i, k in kids do
			local col = (i - 1) % perRow
			local row = (i - 1) // perRow
			local n = build(k.inst, cw, ch, { X = cwid, Y = chei })
			n.x, n.y = pl + col * (cwid + gx), pt + row * (chei + gy)
			table.insert(node.kids, n)
		end
	else
		for _, k in kids do
			local n = build(k.inst, cw, ch, nil)
			local px, pox, py, poy = udim2(prop(k.inst, "Position", nil))
			local anchor = prop(k.inst, "AnchorPoint", nil)
			local ax, ay = if anchor then anchor.X else 0, if anchor then anchor.Y else 0
			n.x = pl + px * cw + pox - ax * n.w
			n.y = pt + py * ch + poy - ay * n.h
			table.insert(node.kids, n)
		end
	end
	for _, n in node.kids do
		maxRight = math.max(maxRight, n.x + n.w)
		maxBottom = math.max(maxBottom, n.y + n.h)
	end
	-- AutomaticSize grows the box to fit its children (or its text)
	if auto == "Y" or auto == "XY" then
		local needed = maxBottom + pb
		if isText(inst) then
			needed = math.max(needed, textHeight(inst, w - pl - pr) + pt + pb)
		end
		node.h = math.max(node.h, needed)
	end
	if auto == "X" or auto == "XY" then
		local needed = maxRight + pr
		if isText(inst) then
			needed = math.max(needed, textWidth(inst) + pl + pr)
		end
		node.w = math.max(node.w, needed)
	end
	return node
end

-- Flattens a node into the JSON the renderer draws (positions relative to the parent).
local function export(n: Node): { [string]: any }
	local inst = n.inst
	local out: { [string]: any } = {
		name = prop(inst, "Name", className(inst)),
		class = className(inst),
		x = n.x,
		y = n.y,
		w = n.w,
		h = n.h,
		z = prop(inst, "ZIndex", 1),
		bg = color(prop(inst, "BackgroundColor3", nil)),
		bgT = prop(inst, "BackgroundTransparency", 0),
		clip = className(inst) == "ScrollingFrame" or prop(inst, "ClipsDescendants", false) == true,
	}
	if className(inst) == "ViewportFrame" then
		out.viewport = true
	end
	local corner = childOfClass(inst, "UICorner")
	if corner then
		local r = prop(corner, "CornerRadius", nil)
		out.radius = if r then r.Scale * math.min(n.w, n.h) + r.Offset else 8
	end
	for _, c in children(inst) do
		if className(c) == "UIStroke" and prop(c, "Enabled", true) ~= false then
			out.stroke = {
				color = color(prop(c, "Color", nil)) or { 0, 0, 0 },
				t = prop(c, "Thickness", 1),
				a = prop(c, "Transparency", 0),
				border = isText(inst) and enumName(prop(c, "ApplyStrokeMode", nil)) ~= "Border" and "text" or "border",
			}
		elseif className(c) == "UIGradient" then
			local seq = prop(c, "Color", nil)
			local kps = seq and seq.Keypoints
			if kps and #kps >= 2 then
				out.gradient = {
					from = color(kps[1].Value),
					to = color(kps[#kps].Value),
					rot = prop(c, "Rotation", 0),
				}
			end
		end
	end
	if isText(inst) then
		out.text = tostring(prop(inst, "Text", ""))
		out.rich = prop(inst, "RichText", false) == true
		out.color = color(prop(inst, "TextColor3", nil)) or { 0, 0, 0 }
		out.size = prop(inst, "TextSize", 14)
		out.scaled = prop(inst, "TextScaled", false) == true
		out.wrap = prop(inst, "TextWrapped", false) == true or out.scaled
		out.font = enumName(prop(inst, "Font", nil))
		out.xa = enumName(prop(inst, "TextXAlignment", nil))
		out.ya = enumName(prop(inst, "TextYAlignment", nil))
		out.tT = prop(inst, "TextTransparency", 0)
		out.strokeT = prop(inst, "TextStrokeTransparency", 1)
		out.placeholder = if className(inst) == "TextBox" then tostring(prop(inst, "PlaceholderText", "")) else nil
	end
	local kids = {}
	for _, k in n.kids do
		table.insert(kids, export(k))
	end
	-- siblings draw in ZIndex order
	table.sort(kids, function(a, b)
		return a.z < b.z
	end)
	out.kids = kids
	return out
end

-- Lays out every enabled ScreenGui under `playerGui` (lowest DisplayOrder first).
function UIShot.capture(playerGui): { any }
	local guis = {}
	for i, g in children(playerGui) do
		if className(g) == "ScreenGui" and prop(g, "Enabled", true) ~= false then
			table.insert(guis, { g = g, i = i })
		end
	end
	table.sort(guis, function(a, b)
		local da, db = prop(a.g, "DisplayOrder", 0), prop(b.g, "DisplayOrder", 0)
		if da ~= db then
			return da < db
		end
		return a.i < b.i
	end)
	local out = {}
	for _, entry in guis do
		local root: Node = { inst = entry.g, x = 0, y = 0, w = VIEW_W, h = VIEW_H, kids = {} }
		for _, k in sortedGuiChildren(entry.g) do
			local n = build(k.inst, VIEW_W, VIEW_H, nil)
			local px, pox, py, poy = udim2(prop(k.inst, "Position", nil))
			local anchor = prop(k.inst, "AnchorPoint", nil)
			n.x = px * VIEW_W + pox - (if anchor then anchor.X else 0) * n.w
			n.y = py * VIEW_H + poy - (if anchor then anchor.Y else 0) * n.h
			table.insert(root.kids, n)
		end
		local e = export(root)
		e.name = prop(entry.g, "Name", "ScreenGui")
		e.bg = nil
		table.insert(out, e)
	end
	return out
end

function UIShot.save(playerGui, path: string, title: string?)
	local data = { title = title or path, width = VIEW_W, height = VIEW_H, guis = UIShot.capture(playerGui) }
	local dir = string.match(path, "^(.*)/[^/]+$")
	if dir and not fs.isDir(dir) then
		fs.writeDir(dir)
	end
	fs.writeFile(path, serde.encode("json", data))
end

return UIShot
