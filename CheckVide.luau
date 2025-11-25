--> Vide 패키지 의존성 상태를 점검하는 Lune 스크립트입니다.
--[[
	Vide 패키지 유효성 점검 스크립트.
	
	- 로컬 패키지 캐시 경로 존재 여부를 확인합니다.
	- (비로블록스 환경) lib.luau 파일 존재만 확인합니다.
	
	검사 실패 시 종료 코드 1로 종료합니다.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOT = "roblox_packages/.pesde/alicesaidhi+vide/0.4.1-testing.4/vide/src"

local function ensureFile(path: string)
	if not fs.isFile(path) then
		error(`Vide check failed: missing file: {path}`)
	end
end

local function main()
	if not fs.isDir(ROOT) then
		error(`Vide check failed: missing directory: {ROOT}`)
	end

	ensureFile("roblox_packages/vide.luau")
	ensureFile(ROOT .. "/init.luau")
	ensureFile(ROOT .. "/lib.luau")
	ensureFile(ROOT .. "/create.luau")
	ensureFile(ROOT .. "/apply.luau")

	print("Vide check passed: package files are present.")
end

local ok, err = pcall(main)
if not ok then
	print(tostring(err))
	process.exit(1)
end
