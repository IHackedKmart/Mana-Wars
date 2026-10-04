--[[
	Glyph check (run from the repo root with Lune):

		lune run tools/sim/glyphs

	Roblox draws a square for any character its fonts don't have. That covers symbols like ✦ ☾ ✕ →,
	emoji that need U+FE0F to show as emoji (⚔ ⚖ ❤ without it), and emoji newer than its emoji font
	(🪙 🪼). This scans every source file and fails if any string uses one, so icons can't quietly
	turn into squares again.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local data = require("./emoji_data")

local function inRanges(ranges: { { number } }, cp: number): boolean
	local lo, hi = 1, #ranges
	while lo <= hi do
		local mid = (lo + hi) // 2
		local r = ranges[mid]
		if cp < r[1] then
			hi = mid - 1
		elseif cp > r[2] then
			lo = mid + 1
		else
			return true
		end
	end
	return false
end

local VS16, ZWJ, KEYCAP = 0xFE0F, 0x200D, 0x20E3

local problems: { string } = {}
local scanned = 0

local function check(path: string)
	scanned += 1
	local lineNo = 0
	for line in string.gmatch(fs.readFile(path) .. "\n", "(.-)\n") do
		lineNo += 1
		if string.match(line, "^%s*%-%-") then
			continue -- comments never reach the screen
		end
		local cps = {}
		for _, cp in utf8.codes(line) do
			table.insert(cps, cp)
		end
		for i, cp in cps do
			local bad: string? = nil
			if cp < 0x100 or cp == VS16 or cp == ZWJ or cp == KEYCAP then
				bad = nil
			elseif inRanges(data.needsVariation, cp) then
				if cps[i + 1] ~= VS16 then
					bad = "needs U+FE0F after it to draw as an emoji"
				end
			elseif cp >= 0x2000 and cp <= 0x206F then
				bad = nil -- dashes, quotes, bullets, ellipsis
			elseif not inRanges(data.emoji, cp) then
				bad = "isn't in Roblox's fonts or emoji (it draws as a square)"
			end
			if bad then
				table.insert(problems, string.format("%s:%d  %s (U+%04X) %s", path, lineNo, utf8.char(cp), cp, bad))
			end
		end
	end
end

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.match(name, "%.lua$") or string.match(name, "%.luau$") then
			check(path)
		end
	end
end

walk("src")

if #problems > 0 then
	for _, p in problems do
		print("FAIL  " .. p)
	end
	print(#problems .. " character(s) Roblox can't draw")
	process.exit(1)
end
print(string.format("glyph check passed (%d files)", scanned))
