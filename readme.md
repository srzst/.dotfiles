<!-- readme.md -->

# .dotfiles

개인 개발 환경 설정 파일 모음.

> version 2.0

---

## 구조

```
.dotfiles/
├── common/
│   ├── neovim/
│   ├── Vim/
│   ├── vscode/
│   ├── yazi/
│   └── zed/
├── linux/
│   └── ubuntu/
│       ├── Alias/
│       └── install/
├── mac/
│   ├── Alias/
│   └── install/
├── windows/
│   ├── Alias/
│   └── install/
├── .gitattributes
└── readme.md
```

---

## 설치

설치 명령어 확인:

- **Ubuntu / macOS**: `curl dl.srz.st/ui`
- **Windows (PowerShell)**: `irm dl.srz.st/wi`

OS별 상세 가이드:

- [Ubuntu](linux/ubuntu/README.md)
- [Windows](windows/README.md)
- [macOS](mac/README.md)

---

## 공통 설정

[common/](common/) — Neovim, Vim, VSCode, Yazi, Zed 설정 포함. 모든 OS에서 공유.

---

## 비고

- Secrets 관리: Infisical Cloud
- 프라이빗 설정: `.dotfolders` (별도 private repo)
