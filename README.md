# 개요

Lune 기반 도구 스크립트들을 pesde 워크스페이스(`libs/*`)로 묶어 관리합니다. 루트에 동일한
이름의 스텁(.luau) 파일을 남겨 기존 호출 경로도 그대로 동작합니다.


## 사용 예시

```toml
# 프로젝트의 pesde.toml
[dependencies]
check_syntax = { repo = "story_bakery/check_syntax", rev = "main", target = "lune" }

[scripts]
check_syntax = ".pesde/check_syntax/CheckSyntax.luau"
```

`pesde install` 후 `pesde run check_syntax` 혹은 `lune run .pesde/check_syntax/CheckSyntax.luau`
처럼 실행할 수 있습니다.

## pesde 의존성 추가 가이드

### 워크스페이스에서 사용
- 루트 `pesde.toml`의 `workspace_members = ["libs/*"]` 구성이므로 루트에서 `pesde install`을 실행하면 워크스페이스 전체 패키지를 한 번에 처리할 수 있습니다.
- 워크스페이스 패키지끼리 의존할 때는 `workspace` 키를 사용합니다. `version`에는 `^`, `*`, `=`, `~` 또는 구체적 버전 요구사항을 넣을 수 있고, 퍼블리시 시 실제 버전으로 치환됩니다.

```toml
[dependencies]
check_moonwave_syntax = { workspace = "story_bakery/check_moonwave_syntax", version = "^", target = "lune" }
```

### StoryBakery 권장: Git 저장소로 추가
- StoryBakery 내부에서는 각 패키지 저장소를 직접 참조하는 Git 의존성을 권장합니다. `repo`와 `rev`를 지정하거나 `pesde add gh#<repo>#<rev>`로 추가할 수 있습니다.

```toml
[dependencies]
check_syntax = { repo = "story_bakery/check_syntax", rev = "main", target = "lune" }
# 태그나 특정 커밋으로도 지정 가능 (예: rev = "v0.1.0")
```

```sh
pesde add gh#story_bakery/check_syntax#main
```

### 버전으로 가져오기
- 버전 단위로 사용해야 한다면 레지스트리에 게시된 패키지를 `name`/`version`으로 의존성에 추가합니다. `[indices]`의 기본 값은 `https://github.com/pesde-pkg/index`입니다.

```toml
[indices]
default = "https://github.com/pesde-pkg/index"

[dependencies]
check_syntax = { name = "story_bakery/check_syntax", version = "^0.1.0", target = "lune" }
```

```sh
pesde add story_bakery/check_syntax
```
