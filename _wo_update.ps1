# ============================================================
#  WO 업데이트 — GitHub 공개 저장소에서 최신 DLL을 받아 교체
#  더블클릭은 "WO업데이트.bat"
# ============================================================
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$BASE = 'https://raw.githubusercontent.com/MOONPILJAE/wsnp-dist/main'

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   WO 업데이트 (GitHub에서 최신 받기)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

function Get-Web($url) { (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30).Content }

# --- 1) 설치폴더 찾기 ---
$gstarRoot = $null
foreach ($x in @('GstarCAD2022','GstarCAD2023','GstarCAD2024','GstarCAD2025','GstarCAD2021')) {
    $p = "C:\Program Files\Gstarsoft\$x"
    if (Test-Path (Join-Path $p 'gcad.exe')) { $gstarRoot = $p; break }
}
if (-not $gstarRoot) {
    $h = Get-ChildItem "C:\Program Files\Gstarsoft" -Directory -ErrorAction SilentlyContinue |
         Where-Object { Test-Path (Join-Path $_.FullName 'gcad.exe') } | Select-Object -First 1
    if ($h) { $gstarRoot = $h.FullName }
}
if (-not $gstarRoot) { Write-Host "[오류] GstarCAD를 찾지 못했습니다." -ForegroundColor Red; Read-Host "`n엔터"; return }
$target = Join-Path $gstarRoot 'GCADwsnp'
if (-not (Test-Path (Join-Path $target 'GCADwsnp.dll'))) {
    Write-Host "[오류] WO가 아직 설치돼 있지 않습니다. 먼저 설치(설치하기.bat)부터 하세요." -ForegroundColor Red
    Read-Host "`n엔터"; return
}

# --- 2) 버전 비교 ---
try { $remoteVer = (Get-Web "$BASE/version.txt").Trim() }
catch { Write-Host "[오류] GitHub 연결 실패(인터넷 확인): $($_.Exception.Message)" -ForegroundColor Red; Read-Host "`n엔터"; return }
$localVerFile = Join-Path $target 'wo_version.txt'
$localVer = if (Test-Path $localVerFile) { (Get-Content $localVerFile -Raw).Trim() } else { '(없음)' }
Write-Host ""
Write-Host "현재 설치 버전 : $localVer" -ForegroundColor Gray
Write-Host "GitHub 최신   : $remoteVer" -ForegroundColor Gray
if ($remoteVer -eq $localVer) {
    Write-Host ""
    Write-Host "이미 최신입니다. 업데이트할 게 없어요." -ForegroundColor Green
    Read-Host "`n엔터를 누르면 닫힙니다"; return
}

# --- 3) GstarCAD 실행 중이면 중단 ---
if (Get-Process gcad -ErrorAction SilentlyContinue) {
    Write-Host "[중단] GstarCAD를 완전히 끄고 다시 실행하세요." -ForegroundColor Red
    Read-Host "`n엔터"; return
}

# --- 4) 받을 파일 목록 + 다운로드(임시) + 검증 ---
$files = (Get-Web "$BASE/files.txt") -split "`n" | ForEach-Object { $_.Trim() } |
         Where-Object { $_ -ne '' -and -not $_.StartsWith('#') }
$tmp = Join-Path $env:TEMP ('wo_upd_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Write-Host ""
foreach ($f in $files) {
    Write-Host "다운로드: $f ..." -NoNewline
    Invoke-WebRequest -Uri "$BASE/$f" -OutFile (Join-Path $tmp $f) -UseBasicParsing -TimeoutSec 180
    $sz = (Get-Item (Join-Path $tmp $f) -ErrorAction SilentlyContinue).Length
    if (-not $sz -or $sz -lt 1000) { Write-Host " 실패" -ForegroundColor Red; Write-Host "[오류] 다운로드 실패: $f" -ForegroundColor Red; Read-Host "`n엔터"; return }
    Write-Host (" OK ({0:N0}B)" -f $sz) -ForegroundColor Green
}

# --- 5) 백업 + 교체 ---
try {
    $bk = Join-Path $target ('_update_backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Force -Path $bk | Out-Null
    foreach ($f in $files) {
        $cur = Join-Path $target $f
        if (Test-Path $cur) { Copy-Item $cur (Join-Path $bk $f) -Force }
        Copy-Item (Join-Path $tmp $f) $cur -Force
    }
    Set-Content -Path $localVerFile -Value $remoteVer -Encoding ASCII -NoNewline
} catch {
    Write-Host ""
    Write-Host "[오류] 교체 실패: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "      이 파일(WO업데이트.bat)을 마우스 오른쪽 → '관리자 권한으로 실행' 해보세요." -ForegroundColor Yellow
    Read-Host "`n엔터"; return
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  업데이트 완료!  ($localVer  ->  $remoteVer)" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "GstarCAD를 다시 켜면 새 버전이 적용됩니다."
Write-Host "(이전 버전 백업: $bk)" -ForegroundColor Gray
Read-Host "`n엔터를 누르면 닫힙니다"
