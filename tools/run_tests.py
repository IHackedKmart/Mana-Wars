#!/usr/bin/env python3
"""Runs the pure-Luau unit tests in tests/ against src/shared with the stock `luau` CLI.

Roblox ModuleScripts use `require(script.Parent.Foo)`, which plain Luau does not understand,
so this script bundles every module in src/shared into one file with a tiny fake instance
tree that resolves `script.Parent.X` paths, then appends each test file and runs it.

Usage: python3 tools/run_tests.py [path/to/luau]
"""

import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, "src", "shared")
TESTS = os.path.join(ROOT, "tests")

PRELUDE = r'''
local __sources = {}
local __cache = {}
local __nodes = {}
local Node = {}
local function __node(path)
	local n = __nodes[path]
	if n then return n end
	n = setmetatable({ __path = path }, Node)
	__nodes[path] = n
	return n
end
Node.__index = function(self, key)
	local path = rawget(self, "__path")
	if key == "Parent" then
		local parent = string.match(path, "^(.*)/[^/]+$")
		return parent and __node(parent) or nil
	end
	if key == "Name" then
		return string.match(path, "([^/]+)$")
	end
	return __node(path .. "/" .. key)
end
local function __require(node)
	local path = rawget(node, "__path")
	if __cache[path] ~= nil then return __cache[path] end
	local fn = __sources[path]
	assert(fn, "no module at " .. tostring(path))
	local result = fn(node, __require)
	__cache[path] = result
	return result
end
local Shared = __node("Shared")

-- Minimal stand-in for Roblox's Random (Park-Miller LCG, deterministic per seed)
Random = {}
Random.__index = Random
function Random.new(seed)
	local s = math.floor(seed or 1) % 2147483647
	if s <= 0 then s = s + 2147483646 end
	return setmetatable({ state = s }, Random)
end
function Random:_next()
	self.state = (self.state * 16807) % 2147483647
	return (self.state - 1) / 2147483646
end
function Random:NextNumber(a, b)
	local r = self:_next()
	if a == nil then return r end
	return a + (b - a) * r
end
function Random:NextInteger(a, b)
	return math.min(b, a + math.floor((b - a + 1) * self:_next()))
end

local __passed, __failed = 0, 0
function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		__passed += 1
	else
		__failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end
function expect(cond, msg)
	if not cond then error(msg or "expectation failed", 2) end
end
function isFinite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
'''

EPILOGUE = r'''
print(string.format("%d passed, %d failed", __passed, __failed))
if __failed > 0 then error("tests failed") end
'''


def module_path(file_path):
    rel = os.path.relpath(file_path, SHARED)
    rel = re.sub(r"\.(luau|lua)$", "", rel).replace(os.sep, "/")
    if rel.endswith("/init") or rel == "init":
        rel = rel[: -len("/init")] if "/" in rel else ""
    return "Shared" + ("/" + rel if rel else "")


def bundle_shared():
    chunks = []
    for dirpath, _, files in os.walk(SHARED):
        for f in sorted(files):
            if not re.search(r"\.(luau|lua)$", f):
                continue
            full = os.path.join(dirpath, f)
            src = open(full, encoding="utf-8").read()
            # `export type` is only legal at module top level; we wrap modules in functions.
            src = re.sub(r"^(\s*)export\s+type\b", r"\1type", src, flags=re.M)
            src = src.replace("--!strict", "")
            chunks.append(
                '__sources["%s"] = function(script, require)\n%s\nend\n' % (module_path(full), src)
            )
    return "\n".join(chunks)


def main():
    luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
    shared = bundle_shared()
    test_files = sorted(f for f in os.listdir(TESTS) if f.endswith(".luau"))
    failures = 0
    for name in test_files:
        body = open(os.path.join(TESTS, name), encoding="utf-8").read()
        program = PRELUDE + shared + "\ndo\n" + body + "\nend\n" + EPILOGUE
        with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as tmp:
            tmp.write(program)
            tmp_path = tmp.name
        print("== " + name)
        result = subprocess.run([luau, tmp_path], capture_output=True, text=True)
        sys.stdout.write(result.stdout)
        if result.returncode != 0:
            sys.stdout.write(result.stderr)
            failures += 1
        os.unlink(tmp_path)
    if failures:
        print("%d test file(s) failed" % failures)
        sys.exit(1)
    print("all test files passed")


if __name__ == "__main__":
    main()
