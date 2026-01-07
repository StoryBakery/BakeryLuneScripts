--[[
	Moonwave 문서 빌드를 실행하고 실패 시 종료하는 모듈입니다.
]]

local process = require("@lune/process")

-- Moonwave 주석 금지 태그 검사
local function runCheckMoonwaveSyntax()
	local ok, err = pcall(require, "./.pesde/validate_moonwave/CheckMoonwaveSyntax")
	if ok then
		return
	end

	local workspacePath = "../check_moonwave_syntax/src/"
	local workspaceOk, workspaceErr = pcall(require, workspacePath)
	if workspaceOk then
		return
	end

	print("[Error] Failed to load the Moonwave forbidden-tag check script.")
	print(`.pesde/validate_moonwave failed: {tostring(err)}`)
	print(`Workspace path "{workspacePath}" failed: {tostring(workspaceErr)}`)
	process.exit(1)
end

runCheckMoonwaveSyntax()

local NPX_COMMAND = if process.os == "windows"
	then "npx.cmd"
	else "npx"

-- Moonwave 문서 빌드 실행
local fallback = process.exec(NPX_COMMAND, { "--yes", "moonwave@latest", "build" }, {
	stdio = { stdout = "inherit", stderr = "inherit" },
})
if not fallback.ok then
	print("Moonwave docs build failed.")
	local exitCode = if fallback.code ~= nil and fallback.code ~= 0
		then fallback.code
		else 1
	process.exit(exitCode)
end

print("Moonwave docs built successfully.")
