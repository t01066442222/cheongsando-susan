#!/usr/bin/env bash
# =====================================================================
#  청산도수산 정책자금 대시보드 — 일일 자동 최신화
#  Windows 작업 스케줄러가 매일 08:00 에 wsl.exe 로 이 스크립트를 실행.
#  흐름: (1) claude 헤드리스로 공고 데이터 웹조사·갱신  (2) dataUpdated→오늘
#        (3) 무결성 검증(실패 시 롤백)  (4) git push(배포)  (5) N드라이브 복사
#  안전장치: 검증 실패 시 백업 복원 + 배포 중단. claude 실패해도 날짜/배포는 진행.
# =====================================================================
set -uo pipefail

REPO="/home/t0106/cheongsando-susan"
LOG="$REPO/update.log"
TODAY="$(date +%Y-%m-%d)"
MODEL="${CS_UPDATE_MODEL:-sonnet}"   # 비용 절감 기본 sonnet. CS_UPDATE_MODEL=opus 로 변경 가능
export PATH="$HOME/.local/bin:$PATH" # claude CLI 경로 보장(cron 환경)
# node 경로 보장: 작업 스케줄러(wsl) 환경엔 nvm PATH가 없어 검증(node tools/validate.mjs)이 실패·롤백됨.
# nvm 로드 후, 그래도 없으면 설치된 최신 node bin 을 폴백으로 PATH 추가(버전 업그레이드에도 안전).
[ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1
command -v node >/dev/null 2>&1 || export PATH="$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1):$PATH"

cd "$REPO" || { echo "repo 없음"; exit 1; }
# 로그를 파일과 화면에 동시 기록
exec > >(tee -a "$LOG") 2>&1
echo ""
echo "===================== $(date '+%F %T')  일일 갱신 시작 (today=$TODAY, model=$MODEL) ====================="

cp index.html index.html.bak

# ---- (1) claude 헤드리스: 공고 데이터 웹조사 후 FUND_DATA 블록 갱신 ----
if [ "${CS_SKIP_CLAUDE:-0}" = "1" ]; then
  echo "[1/5] CS_SKIP_CLAUDE=1 — 웹조사 생략(점검 모드)"
elif command -v claude >/dev/null 2>&1; then
  echo "[1/5] claude 헤드리스 최신화 시작 (timeout 12분)..."
  PROMPT="$(cat tools/update-prompt.md)"
  timeout 720 claude -p "$PROMPT" \
      --model "$MODEL" \
      --permission-mode bypassPermissions \
      --allowedTools "Read Edit WebSearch WebFetch Bash" \
      --add-dir "$REPO" \
    && echo "[1/5] claude 최신화 종료" \
    || echo "[1/5] (warn) claude 비정상/타임아웃 — 날짜 갱신·배포는 계속 진행"
else
  echo "[1/5] (warn) claude CLI 미발견 — 데이터 웹조사 생략, 날짜만 갱신"
fi

# ---- (2) META.dataUpdated 를 오늘로 (결정적, 항상 수행) ----
python3 - "$TODAY" <<'PY'
import sys, re
t = sys.argv[1]
p = 'index.html'
s = open(p, encoding='utf-8').read()
s2, n = re.subn(r"dataUpdated:\s*'[0-9-]+'", "dataUpdated: '%s'" % t, s, count=1)
open(p, 'w', encoding='utf-8').write(s2)
print('[2/5] dataUpdated -> %s (치환 %d건)' % (t, n))
PY

# ---- (3) 무결성 검증 (실패 시 롤백 + 중단) ----
echo "[3/5] 무결성 검증..."
if ! node tools/validate.mjs index.html; then
  echo "[3/5] ✗ 검증 실패 → 백업 복원, 배포 중단"
  mv -f index.html.bak index.html
  echo "===================== $(date '+%F %T')  실패 종료(롤백) ====================="
  exit 2
fi
rm -f index.html.bak

# ---- (4) 변경 확인 후 git 커밋·푸시(배포) ----
if git diff --quiet && git diff --cached --quiet; then
  echo "[4/5] 변경사항 없음 — git 배포 생략 (페이지는 매 열람 시 오늘 날짜로 자동 갱신됨)"
else
  git add -A
  git -c user.name="CS Auto Updater" -c user.email="t01066442222@gmail.com" \
      commit -m "자동 최신화 ${TODAY} · 정책자금 공고/D-day 갱신" >/dev/null
  if git push origin HEAD; then
    echo "[4/5] ✓ git push 완료 → GitHub Pages / Netlify 배포 트리거"
  else
    echo "[4/5] (warn) git push 실패 — 'gh auth login' 또는 자격증명 확인 필요"
  fi
fi

# Netlify CLI 가 있으면 직접 배포 (git 연동이 아닐 경우 대비)
if command -v netlify >/dev/null 2>&1; then
  netlify deploy --prod --dir "$REPO" >/dev/null 2>&1 \
    && echo "      ↳ netlify CLI 배포 완료" \
    || echo "      ↳ (warn) netlify CLI 배포 실패/미연동"
fi

# ---- (5) N드라이브 복사 ----
echo "[5/5] N드라이브 복사..."
bash tools/copy_to_ndrive.sh || echo "[5/5] (warn) N드라이브 복사 실패"

echo "===================== $(date '+%F %T')  완료 ====================="
