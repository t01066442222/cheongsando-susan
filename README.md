# 청산도수산 정책자금 대시보드 — 매일 자동 최신화 시스템

대표: 김동률 (전남 완도 · 수산물 유통 · 1인기업) · 컨설팅: 카네기경영연구원

## 라이브 URL
- Netlify: https://cs-susan-73391.netlify.app/
- GitHub Pages(예비): https://t01066442222.github.io/cheongsando-susan/

## 동작 방식 (하이브리드)
1. **열람 시 자동(클라이언트)**: 페이지를 열 때마다 JavaScript가 `오늘 날짜`로
   D-day·긴급도·정렬·알림배너·체크리스트를 **실시간 재계산**한다. → 매일 자동으로 "오늘 버전".
2. **매일 08:00 자동(데이터)**: Windows 작업 스케줄러가 WSL `update.sh`를 실행 →
   `claude` 헤드리스가 웹에서 최신 공고를 조사해 `FUNDS` 데이터를 갱신 → 검증 후
   GitHub/Netlify 배포 + N드라이브 폴더에 저장.

## 파일 구조
```
cheongsando-susan/
├── index.html              # 대시보드 (FUND_DATA 블록 = 데이터, 나머지 = 템플릿)
├── update.sh               # 일일 갱신 오케스트레이터 (스케줄러가 실행)
├── update.log              # 실행 로그 (자동 생성)
├── README.md               # 본 문서
└── tools/
    ├── update-prompt.md    # claude 헤드리스에게 주는 갱신 지침
    ├── validate.mjs        # 배포 전 무결성 검증 (실패 시 자동 롤백)
    ├── copy_to_ndrive.sh   # N드라이브 폴더로 복사 (PowerShell 경유)
    ├── register_task.ps1   # 작업 스케줄러 등록 (매일 08:00)
    └── unregister_task.ps1 # 작업 스케줄러 해제
```

## 데이터 수정 방법 (수동)
`index.html` 의 `FUND_DATA_START` ~ `FUND_DATA_END` 사이 `const FUNDS = [...]` 만 고치면 된다.
각 항목: `status`('fixed'|'window'|'rolling'|'always'|'estimated'|'milestone'), `deadline`('YYYY-MM-DD'|null),
`hint`('now'|'soon'|'relaxed'). D-day·정렬은 자동 계산되므로 정확한 `deadline`/`status`만 넣으면 됨.

## 최초 1회 설정 (사용자)
GitHub 배포를 위해 인증이 필요하다(만료된 토큰 갱신):
```bash
gh auth login          # GitHub.com → HTTPS → 브라우저/디바이스 코드 인증
gh auth setup-git      # git 이 gh 자격증명을 쓰도록 설정 (cron 비대화식 작동)
```
이후 `git push` 와 매일 자동 배포가 모두 동작한다.

## 수동 실행 / 점검
```bash
bash /home/t0106/cheongsando-susan/update.sh                 # 전체(웹조사 포함)
CS_SKIP_CLAUDE=1 bash /home/t0106/cheongsando-susan/update.sh  # 웹조사 생략 점검
node tools/validate.mjs index.html                            # 무결성 검증만
CS_UPDATE_MODEL=opus bash update.sh                           # 갱신 모델 변경(기본 sonnet)
```

## 작업 스케줄러
- 이름: `청산도수산_정책자금_일일갱신` · 매일 08:00 · 로그인 시 실행(비밀번호 불필요)
- 다시 등록/변경: `powershell -ExecutionPolicy Bypass -File tools\register_task.ps1`
- 해제: `powershell -ExecutionPolicy Bypass -File tools\unregister_task.ps1`
