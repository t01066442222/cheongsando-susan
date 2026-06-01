#!/usr/bin/env bash
# index.html 을 N드라이브 청산도수산 폴더에 복사.
# N: 가 /mnt/n 으로 마운트돼 있으면 직접 cp, 아니면 PowerShell + C:\Temp 경유.
set -uo pipefail
REPO="/home/t0106/cheongsando-susan"
SRC="$REPO/index.html"
NDIR='/mnt/n/개인/카네기경영(과업)/1업체/2광주,전남지역/완도군/(2026.03.13)청산도수산/claudecode(청산도수산)'

if [ -d "$NDIR" ]; then
  cp "$SRC" "$NDIR/청산도수산_정책자금_컨설팅.html"
  mkdir -p "$NDIR/netlify-deploy"
  cp "$SRC" "$NDIR/netlify-deploy/index.html"
  echo "[copy] /mnt/n 직접 복사 완료"
  exit 0
fi

# --- PowerShell 경유 (마운트 안 됨) ---
cp "$SRC" /mnt/c/Temp/cs_index.html
printf '\xef\xbb\xbf' > /mnt/c/Temp/cp_n.ps1
cat >> /mnt/c/Temp/cp_n.ps1 <<'PS'
chcp 65001 > $null
$dst = 'N:\개인\카네기경영(과업)\1업체\2광주,전남지역\완도군\(2026.03.13)청산도수산\claudecode(청산도수산)'
if (-not (Test-Path -LiteralPath $dst)) { Write-Output "ERR: 대상 폴더 없음"; exit 1 }
Copy-Item -LiteralPath 'C:\Temp\cs_index.html' -Destination (Join-Path $dst '청산도수산_정책자금_컨설팅.html') -Force
$nd = Join-Path $dst 'netlify-deploy'
if (-not (Test-Path -LiteralPath $nd)) { New-Item -ItemType Directory -LiteralPath $nd | Out-Null }
Copy-Item -LiteralPath 'C:\Temp\cs_index.html' -Destination (Join-Path $nd 'index.html') -Force
Write-Output "COPIED"
PS
OUT=$(powershell.exe -NoProfile -File "C:\\Temp\\cp_n.ps1" 2>&1)
echo "$OUT" | grep -q "COPIED" && { echo "[copy] PowerShell 경유 복사 완료"; exit 0; }
echo "[copy] 실패: $OUT"; exit 1
