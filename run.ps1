# SS Tool - GitHub Release'inden indirip calistirma script'i
# ------------------------------------------------------------------
# Bu script HERKES tarafindan, HICBIR TOKEN/GIRIS GEREKMEDEN kullanilabilir.
# Kaynak kodu (src) ICERMEZ - sadece derlenmis .exe paketini
# (target\dist\SS-Tool klasorunun zip'i) GitHub Release'inden indirir ve
# calistirir. Jar'in ICINDEKI kod (sinif/metot isimleri) zaten derleme
# sirasinda ProGuard ile anlamsiz kisa harflere donusturuluyor (bkz.
# pom.xml / proguard-rules.pro) - "kaynagin gizliligi" o katmanda saglanir,
# bu script tarafinda ekstra bir erisim engeli YOKTUR.
#
# NOT: .exe paketi kendi icinde JRE barindirir - bu script'i calistiran
# makinede AYRICA JAVA KURULU OLMASI GEREKMEZ.
#
# RELEASE'E YUKLENECEK DOSYA: `build.bat` calistirdiktan sonra olusan
# target\dist\SS-Tool klasorunu zip'leyip "SS-Tool.zip" adiyla GitHub
# Release'e asset olarak yukleyin.
#
# TEK SATIRLA KULLANIM:
#   irm https://raw.githubusercontent.com/kadirwastaken5/Planet-SS-Tool/main/run.ps1 | iex
# ------------------------------------------------------------------

$ErrorActionPreference = "Stop"

$owner   = "kadirwastaken5"
$repo    = "Planet-SS-Tool"
$zipName = "SS-Tool.zip"
$exeRelativePath = "SS-Tool\SS-Tool.exe"

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " Planet SS-Tool - Release Indirici (.exe)" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

$apiUrl = "https://api.github.com/repos/$owner/$repo/releases/latest"
$headers = @{
    "User-Agent" = "ss-tool-installer"
    "Accept"     = "application/vnd.github+json"
}

Write-Host "En son release bilgisi cekiliyor..." -ForegroundColor Cyan

try {
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
} catch {
    $statusCode = $null
    if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }

    if ($statusCode -eq 404) {
        Write-Host ""
        Write-Host "HATA: '$owner/$repo' icin henuz bir GitHub Release yayinlanmamis." -ForegroundColor Red
        Write-Host "      GitHub'da 'Releases -> Draft a new release' ile bir release" -ForegroundColor Red
        Write-Host "      acip, target\dist\SS-Tool klasorunu zip'leyerek '$zipName'" -ForegroundColor Red
        Write-Host "      adiyla asset olarak ekleyin, sonra bu script'i tekrar calistirin." -ForegroundColor Red
    } else {
        Write-Host ""
        Write-Host "HATA: Release bilgisi alinamadi (HTTP $statusCode)." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
    }
    exit 1
}

$asset = $release.assets | Where-Object { $_.name -eq $zipName }

if (-not $asset) {
    Write-Host "HATA: En son release'de '$zipName' bulunamadi." -ForegroundColor Red
    Write-Host "      (target\dist\SS-Tool klasorunu zip'leyip '$zipName' adiyla release'e ekleyin.)" -ForegroundColor Red
    exit 1
}

$installDir = Join-Path $env:LOCALAPPDATA "SS-Tool"
$zipDest    = Join-Path $env:TEMP $zipName

Write-Host "Indiriliyor: $($asset.name) ($([math]::Round($asset.size / 1MB, 2)) MB)" -ForegroundColor Cyan
Invoke-WebRequest -Uri $asset.browser_download_url -Headers @{ "User-Agent" = "ss-tool-installer" } -OutFile $zipDest

Write-Host "Cikartiliyor: $installDir" -ForegroundColor Cyan
if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue }
Expand-Archive -Path $zipDest -DestinationPath $installDir -Force
Remove-Item $zipDest -Force -ErrorAction SilentlyContinue

$exePath = Join-Path $installDir $exeRelativePath
if (-not (Test-Path $exePath)) {
    Write-Host "HATA: Cikartilan pakette '$exeRelativePath' bulunamadi." -ForegroundColor Red
    Write-Host "      Zip'in icerigini kontrol edin: $installDir" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Calistiriliyor: $exePath" -ForegroundColor Green
Start-Process -FilePath $exePath
