" 사용자 정의 명령어: 행 번호 켜기/끄기
command! Non set number
command! Noff set nonumber

" 구문 강조 활성화
syntax on

" 검색 관련 설정
set ignorecase      " 검색 시 대소문자 무시
set smartcase       " 대문자 포함 시 대소문자 구분
set hlsearch        " 검색 결과 강조
set incsearch       " 실시간 검색 결과 표시

" 화면 및 모드 표시
set laststatus=2    " 하단 상태바 항상 표시
set showmode        " 현재 모드(INSERT 등) 표시

" 탭 및 들여쓰기 설정 (4칸 기준)
set expandtab       " 탭을 공백으로 변환
set tabstop=4       " 탭의 크기
set softtabstop=4   " 편집 시 탭 이동 크기
set shiftwidth=4    " 자동 들여쓰기 크기
set autoindent      " 이전 줄에 맞춰 자동 들여쓰기

" 파일 형식 인식 및 플러그인
filetype indent on
filetype plugin on

" 백업 및 성능 관련
set nobackup        " 백업 파일 생성 안 함
set noswapfile      " 스왑 파일 생성 안 함
set endofline       " 파일 끝에 새 줄 유지

" 경고음 제거
set noerrorbells
set visualbell
set t_vb=

" 클립보드 및 마우스 설정
set clipboard=unnamedplus  " 시스템 클립보드와 동기화
set mouse=a                " 마우스 사용 가능 설정

" === 기존 설정 유지 ===
set clipboard=unnamedplus
set mouse=a

" === 클립보드 & 고속 작업 매핑 수정 ===

" 1. 기본 삭제(d, x) 시 시스템 클립보드 보호 (블랙홀 레지스터)
" 이렇게 하면 d로 지워도 이전에 복사한 게 안 날아갑니다.
nnoremap d "_d
vnoremap d "_d
nnoremap x "_x
vnoremap x "_x

" 2. gd: 문서 전체 삭제 (블랙홀 레지스터 사용으로 클립보드 보호)
" 사용자님 요청: gg "_ d G
nnoremap gd gg"_dG

" 3. gy: 문서 전체 복사 (시스템 클립보드 '+' 레지스터로 강제 전송)
" 사용자님 요청: gg y G (시스템 클립보드 연동 추가)
nnoremap gy gg"+yG

" 4. 선택 영역 복사(y) 시 시스템 클립보드로 명시적 전송
vnoremap y "+y

" 5. 붙여넣기(p)는 시스템 클립보드에서 가져오기
nnoremap p "+p
vnoremap p "+p