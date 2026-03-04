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

