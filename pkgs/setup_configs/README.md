# setup_configs

워크스페이스 루트에 기본 설정 파일을 설치하고, 필요 시 옵션별 설정을 덮어쓰는 Lune 스크립트입니다.  
추가로 `libs/bakery-dev-handbook` Git 서브모듈을 보장하고, 원격과 달라지면 최신 상태로 맞춥니다.

## 기능

- `src/options/base`의 파일을 워크스페이스 루트에 복사합니다. (기존 파일은 덮어씀)
- `--option <name>` 지정 시 `src/options/<name>`를 추가로 덮어씁니다.
- Git 저장소라면 `libs/bakery-dev-handbook` 서브모듈을 추가/동기화/업데이트합니다.

## 사용 방법

### 이 레포에서 직접 실행

```sh
# 워크스페이스 루트에서 실행
lune run pkgs/setup_configs/src/init.luau
```

옵션 적용:

```sh
lune run pkgs/setup_configs/src/init.luau --option <name>
```

### pesde 의존성으로 사용

```toml
# 프로젝트의 pesde.toml 예시
[dependencies]
setup_configs = { repo = "story_bakery/setup_configs", rev = "main", target = "lune" }

[scripts]
setup_configs = ".pesde/setup_configs/src/init.luau"
```

```sh
pesde install
pesde run setup_configs
```

## 설치 대상 파일 (base)

- `.editorconfig`
- `.stylua.toml`
- `selene.toml`
- `AGENTS.md`
- `custom.yml`

## 옵션 구성

`src/options/<옵션명>` 폴더에 파일을 추가하면 `--option <옵션명>`으로 base 위에 덮어쓸 수 있습니다.

## 주의 사항

- 실행 위치가 대상 워크스페이스 루트여야 합니다. (복사 경로는 현재 작업 디렉터리 기준)
- Git이 없거나 Git 저장소가 아니면 서브모듈 처리를 건너뜁니다.
- `libs/bakery-dev-handbook` 경로에 일반 폴더가 있으면 서브모듈 추가가 실패합니다.
