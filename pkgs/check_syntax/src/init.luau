--> 프로젝트 전역의 Luau 스크립트를 순회하며 문법 오류를 검출하는 Lune 유틸리티입니다.
--[[
	CheckSyntax
	Luau 소스를 전부 컴파일 시뮬레이션해 문법 오류를 조기에 탐지합니다.
	CI 및 로컬 개발 환경에서 동일한 검증을 수행하기 위한 스크립트입니다.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

type FilePaths = { string }

local DEFAULT_ROOTS: { string } = {
	"src",
	".lune",
}

local LSP_IGNORE_GLOBS: { string } = {
	"roblox_packages/**",
}

local function join(a: string, b: string): string
	if a == "" or a == "." then
		return b
	end
	return a .. "/" .. b
end

local function isScriptFile(path: string): boolean
	return path:match("%.luau$") ~= nil or path:match("%.lua$") ~= nil
end

local EXCLUDES = {
	["src/Shared/InternalPackages/BufferBuilder/init.lua"] = true,
	["src/Shared/InternalPackages/BufferReader.lua"] = true,
	["src/Shared/InternalPackages/TableUtil.lua"] = true,

	-- 현 배치 경로
	["src/Shared/Modules/BufferBuilder/init.lua"] = true,
	["src/Shared/Modules/BufferReader.lua"] = true,
	["src/Shared/Modules/TableUtil.lua"] = true,
}

local function isExcluded(path: string): boolean
	return EXCLUDES[path] == true
end

local function addScriptFile(path: string, accumulator: FilePaths)
	if isScriptFile(path) and not isExcluded(path) then
		table.insert(accumulator, path)
	end
end

local function collectFromDirectory(dir: string, accumulator: FilePaths)
	local okReadDir, entries = pcall(fs.readDir, dir)
	if not okReadDir or entries == nil then
		return
	end

	for _, entry in ipairs(entries) do
		local path = join(dir, entry)
		if fs.isFile(path) then
			addScriptFile(path, accumulator)
		elseif fs.isDir(path) then
			collectFromDirectory(path, accumulator)
		end
	end
end

local function resolveRoots(): FilePaths
	local resolvedRoots: FilePaths = {}
	local candidates = (#process.args > 0) and process.args or DEFAULT_ROOTS
	local seen = {}

	for _, candidate in ipairs(candidates) do
		if not seen[candidate] then
			seen[candidate] = true

			local shouldInsertIntoResolvedRoot = fs.isDir(candidate)
				or (fs.isFile(candidate) and isScriptFile(candidate))

			if shouldInsertIntoResolvedRoot then
				table.insert(resolvedRoots, candidate)
			end
		end
	end

	return resolvedRoots
end

local function collectFiles(roots: FilePaths): FilePaths
	local collected: FilePaths = {}

	for _, root in ipairs(roots) do
		if fs.isDir(root) then
			collectFromDirectory(root, collected)
		elseif fs.isFile(root) then
			addScriptFile(root, collected)
		end
	end

	return collected
end

local function joinMany(base: string, segments: { string }): string
	local path = base

	for _, segment in ipairs(segments) do
		path = join(path, segment)
	end

	return path
end

local function expandHomePath(path: string): string
	if path:sub(1, 2) == "~/" then
		local home = process.env.HOME or process.env.USERPROFILE
		if home ~= nil and home ~= "" then
			return join(home, path:sub(3))
		end
	end

	return path
end

local function resolveLuauDefinitionsFile(): string?
	local envPath = process.env.LUAU_LSP_DEFINITIONS
	if envPath ~= nil and envPath ~= "" then
		local expanded = expandHomePath(envPath)
		if fs.isFile(expanded) then
			return expanded
		end

		print(`[luau-lsp] LUAU_LSP_DEFINITIONS 경로 "{expanded}" 를 찾을 수 없습니다.`)
	end

	local candidates: { string } = {}
	local home = process.env.HOME or process.env.USERPROFILE
	if home ~= nil and home ~= "" then
		table.insert(candidates, joinMany(home, { ".local", "share", "luau-lsp", "roblox.d.luau" }))
		table.insert(candidates, joinMany(home, { "Library", "Application Support", "luau-lsp", "roblox.d.luau" }))
		table.insert(candidates, joinMany(home, { ".config", "luau-lsp", "roblox.d.luau" }))
	end

	local localAppData = process.env.LOCALAPPDATA
	if localAppData ~= nil and localAppData ~= "" then
		table.insert(candidates, localAppData .. "\\luau-lsp\\roblox.d.luau")
	end

	local appData = process.env.APPDATA
	if appData ~= nil and appData ~= "" then
		table.insert(candidates, appData .. "\\luau-lsp\\roblox.d.luau")
	end

	for _, candidate in ipairs(candidates) do
		if candidate ~= nil and fs.isFile(candidate) then
			return candidate
		end
	end

	return nil
end

local function trimStackTrace(message: string): string
	local stackIndex = message:find("stack traceback:")

	if stackIndex then
		message = message:sub(1, stackIndex - 1)
	end

	return message:gsub("%s+$", "")
end

local function normalizeExecError(err: any): string
	if err == nil then
		return "알 수 없는 오류입니다."
	end

	if type(err) == "string" then
		return trimStackTrace(err)
	end

	return trimStackTrace(tostring(err))
end

local function runCommand(binary: string, args: { string }, description: string): boolean
	print(`{description}를 실행합니다...`)

	local okExec, resultOrErr = pcall(process.exec, binary, args, {
		capture = true,
		stdio = {
			stdout = "inherit",
			stderr = "inherit",
		},
	})

	if not okExec then
		local message = normalizeExecError(resultOrErr)
		print(`{description} 명령을 실행하지 못했습니다: {message}`)
		print("도구가 PATH 에 설치되어 있는지 확인하세요.")
		return false
	end

	local result = resultOrErr
	if not result.ok then
		local logOutput = result.stderr ~= "" and result.stderr or result.stdout

		print(`{description} 검사에서 문제가 발견되었습니다.`)
		if logOutput ~= nil and logOutput ~= "" then
			print(logOutput)
		end

		return false
	end

	return true
end

local function runLuauLanguageServer(targets: FilePaths): boolean
	local args: { string } = { "analyze" }
	if fs.isFile(".luaurc") then
		table.insert(args, "--base-luaurc")
		table.insert(args, ".luaurc")
	end
	local sourcemapPath = "sourcemap.json"

	if fs.isFile(sourcemapPath) then
		table.insert(args, "--sourcemap")
		table.insert(args, sourcemapPath)
	end

	local definitionsPath = resolveLuauDefinitionsFile()
	if definitionsPath ~= nil then
		table.insert(args, "--definitions")
		table.insert(args, definitionsPath)
	end

	for _, glob in ipairs(LSP_IGNORE_GLOBS) do
		table.insert(args, "--ignore")
		table.insert(args, glob)
	end

	for _, target in ipairs(targets) do
		table.insert(args, target)
	end

	return runCommand("luau-lsp", args, "Luau Language Server 분석")
end

local function runSeleneLint(targets: FilePaths): boolean
	local args: { string } = {}

	for _, target in ipairs(targets) do
		table.insert(args, target)
	end

	if #args == 0 then
		table.insert(args, ".")
	end

	return runCommand("selene", args, "Selene")
end

local function compileFiles(paths: FilePaths): (boolean, FilePaths)
	local failures: FilePaths = {}

	for _, path in ipairs(paths) do
		local okRead, src = pcall(fs.readFile, path)

		if not okRead or src == nil then
			table.insert(failures, `{path}: failed to read`)
		else
			-- BOM 제거 및 소스 정규화
			if src:sub(1, 3) == "\239\187\191" then
				src = src:sub(4)
			end
			local okCompile, err = pcall(function()
				luau.compile(src)
			end)

			if not okCompile then
				table.insert(failures, `{path}: {tostring(err)}`)
			end
		end
	end

	return #failures == 0, failures
end

local roots = resolveRoots()
local files = collectFiles(roots)
local success, failures = compileFiles(files)

if not success then
	for _, message in ipairs(failures) do
		print(message)
	end

	process.exit(1)
else
	print(`Luau 컴파일 검사를 통과했습니다. 총 {#files}개 파일.`)
end

if not runLuauLanguageServer(roots) then
	process.exit(1)
end

print("Luau Language Server 분석을 통과했습니다.")

if not runSeleneLint(roots) then
	process.exit(1)
end

print("Selene 검사를 통과했습니다.")
print("모든 Luau 관련 검사를 성공적으로 마쳤습니다.")
