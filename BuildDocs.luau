--> Moonwave 문서화 빌드를 하며 오류 검사를 합니다.
--[[
	BuildDocs
	Moonwave 문서 빌드와 실패 시 종료 처리를 담당합니다.
	문서 생성이 실패하면 CI 흐름을 중단하도록 설계되었습니다.
]]

local process = require("@lune/process")

-- moonwave 주석 금지 태그 검사 (CheckForbiddenTags 재사용)
require("./CheckForbiddenTags")

local NPX_COMMAND = if process.os == "windows" then "npx.cmd" else "npx"

local fallback = process.exec(NPX_COMMAND, { "--yes", "moonwave@latest", "build"}, {
	stdio = { stdout = "inherit", stderr = "inherit" },
})
if not fallback.ok then
	print("Moonwave docs build failed.")
	process.exit(fallback.code ~= 0 and fallback.code or 1)
end

print(("Moonwave docs built successfully at %s"))
