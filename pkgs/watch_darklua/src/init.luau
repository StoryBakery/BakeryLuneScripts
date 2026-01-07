--[[
	src 디렉터리를 감시해 Darklua 변환과 자산 복사, Rojo 프로젝트 리라이팅을 수행하는 모듈입니다.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

-- 기본 설정 (환경변수와 인자에서 재정의 가능)
local SRC_DIR = "src"
local OUT_DIR = "out"
local PROJECT_IN = "default.project.json"
local PROJECT_OUT = "place.project.json"
local DARKLUA_BIN = process.env.DARKLUA or "darklua"
local DARKLUA_CONFIG -- 예: ".darklua.json" 또는 ".darklua.json5"
local POLL = 0.25 -- 초
local PRUNE = true
local VERBOSE = false
local SERVE = false
local GEN_SOURCEMAP = true
local SOURCEMAP_OUT = "sourcemap.build.json"

-- 인자 파싱
do
	local i = 1
	while i <= #process.args do
		local a = process.args[i]
		if a == "--src" then
			i += 1
			SRC_DIR = process.args[i]
		elseif a == "--out" then
			i += 1
			OUT_DIR = process.args[i]
		elseif a == "--config" then
			i += 1
			DARKLUA_CONFIG = process.args[i]
		elseif a == "--poll" then
			i += 1
			POLL = tonumber(process.args[i]) or POLL
		elseif a == "--no-prune" then
			PRUNE = false
		elseif a == "--verbose" or a == "-v" then
			VERBOSE = true
		elseif a == "--serve" then
			SERVE = true
		elseif a == "--project" then
			i += 1
			PROJECT_IN = process.args[i]
		elseif a == "--project-out" then
			i += 1
			PROJECT_OUT = process.args[i]
		elseif a == "--sourcemap" then
			GEN_SOURCEMAP = true
		elseif a == "--sourcemap-out" then
			i += 1
			SOURCEMAP_OUT = process.args[i]
		end
		i += 1
	end
end

-- 유틸
local function endsWith(s, suffix)
	return #s >= #suffix and s:sub(-#suffix) == suffix
end

local function join(a, b)
	if a == "" then
		return b
	elseif endsWith(a, "/") then
		return a .. b
	else
		return a .. "/" .. b
	end
end

local function dirname(path)
	return (path:match("^(.*)/[^/]+$")) or ""
end

local function mkdirp(dir)
	if dir == "" or dir == "." then
		return
	end
	if not fs.isDir(dir) then
		local parent = dirname(dir)
		if parent ~= "" and not fs.isDir(parent) then
			mkdirp(parent)
		end
		local ok = pcall(function()
			fs.writeDir(dir)
		end)
		if not ok and not fs.isDir(dir) then
			-- 재시도 방어
			fs.writeDir(dir)
		end
	end
end

local function ensureParent(path)
	local d = dirname(path)
	if d ~= "" then
		mkdirp(d)
	end
end

local function isCodeFile(p)
	-- *.lua (서버/클라이언트 포함), *.luau
	return endsWith(p, ".lua") or endsWith(p, ".luau")
end

local ASSET_SUFFIXES = {
	[".csv"] = true,
	[".model.json"] = true,
	[".meta.json"] = true,
	[".rbxm"] = true,
	[".rbxmx"] = true,
}

local function isAssetFile(p)
	for suf in ASSET_SUFFIXES do
		if endsWith(p, suf) then
			return true
		end
	end
	return false
end

local IGNORE_DIRS = {
	[OUT_DIR] = true,
	[".git"] = true,
	[".rbxts"] = true,
	["Packages"] = true,
}

local function walkFiles(root, acc)
	for _, name in fs.readDir(root) do
		local p = join(root, name)
		if fs.isDir(p) then
			if not IGNORE_DIRS[name] then
				walkFiles(p, acc)
			end
		elseif fs.isFile(p) then
			-- src 이하만 처리
			table.insert(acc, p)
		end
	end
end

local function relFromSrc(abs)
	-- "src/..."을 "..."로 변환합니다.
	local prefix = SRC_DIR .. "/"
	if abs:sub(1, #prefix) == prefix then
		return abs:sub(#prefix + 1)
	end
	return abs
end

local function outPathFor(absSrc)
	return join(OUT_DIR, relFromSrc(absSrc))
end

local function copyFile(src, dst)
	ensureParent(dst)
	local ok = pcall(function()
		fs.copy(src, dst, { overwrite = true })
	end)
	if not ok then
		-- 플랫폼 호환을 위한 대체 복사 처리
		fs.writeFile(dst, fs.readFile(src))
	end
end

local function runDarklua(inPath, outPath)
	ensureParent(outPath)
	local params = { "process", inPath, outPath }
	if DARKLUA_CONFIG and #DARKLUA_CONFIG > 0 then
		table.insert(params, "--config")
		table.insert(params, DARKLUA_CONFIG)
	end
	local stdioKind = if VERBOSE
		then "inherit"
		else "default"
	local result = process.exec(DARKLUA_BIN, params, { stdio = { stdout = stdioKind, stderr = "default" } })
	if result.ok then
		return true
	else
		local msg = "(no details)"
		if result.stderr ~= nil and #result.stderr > 0 then
			msg = result.stderr
		elseif result.stdout ~= nil and #result.stdout > 0 then
			msg = result.stdout
		end
		print(`[Warning] darklua failed: {inPath}\n- {msg}`)
		-- 원본 그대로 복사
		copyFile(inPath, outPath)
		return false
	end
end

local function snapshot()
	local files = {}
	if not fs.isDir(SRC_DIR) then
		return {}
	end
	walkFiles(SRC_DIR, files)
	local map = {}
	for _, p in files do
		local md = fs.metadata(p)
		local size = 0
		if fs.isFile(p) then
			size = #fs.readFile(p)
		end
		map[p] = {
			mtime = md.modifiedAt.unixTimestampMillis,
			size = size,
		}
	end
	return map
end

local function buildOne(absSrc)
	local dst = outPathFor(absSrc)
	if isCodeFile(absSrc) then
		runDarklua(absSrc, dst)
	elseif isAssetFile(absSrc) then
		copyFile(absSrc, dst)
		if VERBOSE then
			print(`[Asset] -> {dst}`)
		end
	end
	-- Rojo에 필요 없는 파일은 무시합니다. (예: .md, 에디터 설정 등)
end

local function removeOutFor(absSrcRel)
	local dst = join(OUT_DIR, relFromSrc(absSrcRel))
	if fs.isFile(dst) then
		local ok, err = pcall(function()
			fs.removeFile(dst)
		end)
		if not ok and VERBOSE then
			print(`[Warning] Cleanup failed: {tostring(err)}`)
		end
	end
end

-- default.project.json의 $path를 SRC_DIR에서 OUT_DIR로 재매핑합니다.
local function rebasePathsInTree(node)
	if type(node) ~= "table" then
		return
	end
	for k, v in node do
		if k == "$path" and type(v) == "string" then
			if v == SRC_DIR then
				node[k] = OUT_DIR
			elseif v:sub(1, #SRC_DIR + 1) == (SRC_DIR .. "/") then
				node[k] = OUT_DIR .. "/" .. v:sub(#SRC_DIR + 2)
			end
		elseif type(v) == "table" then
			rebasePathsInTree(v)
		end
	end
end

local function writeBuildProject()
	if not fs.isFile(PROJECT_IN) then
		print(`[Info] "{PROJECT_IN}" not found. Skipping Rojo project rewrite.`)
		return
	end
	local src = fs.readFile(PROJECT_IN)
	local ok, data = pcall(function()
		return serde.decode("json", src)
	end)
	if not ok then
		print(`[Warning] Failed to parse "{PROJECT_IN}". Raw error: {tostring(data)}`)
		return
	end
	if type(data.tree) == "table" then
		rebasePathsInTree(data.tree)
	end
	mkdirp(dirname(PROJECT_OUT))
	fs.writeFile(PROJECT_OUT, serde.encode("json", data, true))
	print(`[Rojo] Generated {PROJECT_OUT}`)
end

local function startRojoServe()
	if not SERVE then
		return
	end
	if not fs.isFile(PROJECT_OUT) then
		writeBuildProject()
	end
	print(`[Rojo] Serve started: {PROJECT_OUT}`)
	-- 백그라운드로 실행하고 감시를 이어갑니다.
	process.create("rojo", { "serve", PROJECT_OUT })
end

local function startSourcemapWatch()
	if not GEN_SOURCEMAP then
		return
	end
	if not fs.isFile(PROJECT_OUT) then
		writeBuildProject()
	end
	print(`[Rojo] Sourcemap watch started: {PROJECT_OUT} -> {SOURCEMAP_OUT}`)
	-- 최신 Rojo는 sourcemap --watch를 지원합니다.
	process.create("rojo", {
		"sourcemap",
		PROJECT_OUT,
		"--watch",
		"--output",
		SOURCEMAP_OUT,
	})
end

-- 메인
local function fullRebuild()
	print(`[Build] Initial build started ({SRC_DIR} -> {OUT_DIR})...`)
	local cur = snapshot()
	for abs in cur do
		buildOne(abs)
	end
	print("[Build] Initial build completed.")
	return cur
end

local function watchLoop(prev)
	print("[Watch] Started watching for changes.")
	while true do
		task.wait(POLL)
		local now = snapshot()

		-- 생성/변경
		for abs, meta in now do
			local last = prev[abs]
			if not last or last.mtime ~= meta.mtime or last.size ~= meta.size then
				buildOne(abs)
			end
		end

		-- 삭제된 파일 정리
		if PRUNE then
			for abs in prev do
				if not now[abs] then
					removeOutFor(abs)
				end
			end
		end

		prev = now
	end
end

writeBuildProject()
startRojoServe()
startSourcemapWatch()
watchLoop(fullRebuild())
