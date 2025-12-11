# 개요

Lune 기반 도구 스크립트들을 pesde 워크스페이스(`libs/*`)로 묶어 관리합니다. 루트에 동일한
이름의 스텁(.luau) 파일을 남겨 기존 호출 경로도 그대로 동작합니다.

## 패키지 목록

- `story_bakery/check_syntax` → `.pesde/check_syntax/CheckSyntax.luau`
- `story_bakery/check_moonwave_syntax` → `.pesde/check_moonwave_syntax/CheckMoonwaveSyntax.luau`
- `story_bakery/build_docs` → `.pesde/build_docs/BuildDocs.luau`
- `story_bakery/watch_darklua` → `.pesde/watch_darklua/WatchDarklua.luau`

## 사용 예시

```toml
# 프로젝트의 pesde.toml
[dependencies]
check_syntax = { name = "story_bakery/check_syntax", version = "^0.1.0", target = "lune" }

[scripts]
check_syntax = ".pesde/check_syntax/CheckSyntax.luau"
```

`pesde install` 후 `pesde run check_syntax` 혹은 `lune run .pesde/check_syntax/CheckSyntax.luau`
처럼 실행할 수 있습니다.
