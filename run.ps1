# SS Tool - PRIVATE GitHub reposundan indirip calistirma script'i
# ------------------------------------------------------------------
# Bu script, kaynak kodu (src) ICERMEYEN, sadece derlenmis .exe paketini
# (target\dist\SS-Tool klasorunun zip'i) bir GitHub Release'inden indirir
# ve calistirir. Repo PRIVATE oldugu icin (bkz. README) indirme islemi bir
# Personal Access Token (PAT) ile kimlik dogrulamasi gerektirir - boylece
# token'a sahip olmayan hic kimse (repo'yu goremeyen hic kimse) ne kaynak
# kodu ne de .exe'yi indirebilir.
#
# NOT: .exe paketi kendi icinde JRE barindirir - bu script'i calistiran
# makinede AYRICA JAVA KURULU OLMASI GEREKMEZ.
#
# RELEASE'E YUKLENECEK DOSYA: `build.bat` calistirdiktan sonra olusan
# target\dist\SS-Tool klasorunu zip'leyip (orn. "SS-Tool.zip" adiyla)
# GitHub Release'e asset olarak yukleyin.
#
# KULLANIM (kendi makinende, dosyayi kaydedip calistir):
#   powershell -ExecutionPolicy Bypass -File .\run.ps1
#
# Repo PRIVATE oldugu icin "irm <url> | iex" seklindeki tek satirlik
# uzaktan calistirma YONTEMI CALISMAZ (raw.githubusercontent.com private
# repolarda kimliksiz istekleri reddeder). Bu yuzden bu dosyayi lokal
# olarak indirip calistirmalisin - zaten amac da bu (src'yi baskasinin
# gormemesi).
# ------------------------------------------------------------------

$ErrorActionPreference = "Stop"

# --- Asagidaki degerleri kendi GitHub reponla degistir ---
$owner   = "KULLANICI_ADIN"
$repo    = "REPO_ADIN"
$zipName = "SS-Tool.zip"
$exeRelativePath = "SS-Tool\SS-Tool.exe"

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " SS-Tool - Private Release Indirici (.exe)" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# --- Personal Access Token (PAT) al ---
# Once ortam degiskeninden dene (kalici kullanim icin onerilir):
#   [Environment]::SetEnvironmentVariable("SSTOOL_GH_TOKEN", "ghp_xxx...", "User")
# Yoksa guvenli sekilde sor (ekranda gorunmez, kaydedilmez).
$token = $env:SSTOOL_GH_TOKEN
if (-not $token) {
    $secureToken = Read-Host "GitHub Personal Access Token (repo:read yetkili)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $token = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

if (-not $token) {
    Write-Host "HATA: Token girilmedi. Private repo icin token zorunlu." -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
    "User-Agent"    = "ss-tool-installer"
    "Accept"        = "application/vnd.github+json"
}

Write-Host ""
Write-Host "En son release bilgisi cekiliyor..." -ForegroundColor Cyan

try {
    $apiUrl  = "https://api.github.com/repos/$owner/$repo/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
} catch {
    Write-Host "HATA: Release bilgisi alinamadi. Token gecersiz/yetkisiz olabilir veya repo/owner adi yanlis." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor DarkRed
    exit 1
}

$asset = $release.assets | Where-Object { $_.name -eq $zipName }

if (-not $asset) {
    Write-Host "HATA: Release icinde '$zipName' bulunamadi." -ForegroundColor Red
    Write-Host "      (target\dist\SS-Tool klasorunu zip'leyip '$zipName' adiyla release'e ekleyin.)" -ForegroundColor Red
    exit 1
}

# ONEMLI: Private repolarda asset indirmek icin 'browser_download_url'
# YETMEZ; API'nin asset endpoint'i + 'application/octet-stream' Accept
# basligi ile, ayni Authorization token'i kullanilarak indirilmesi gerekir.
$assetApiUrl = $asset.url
$installDir  = Join-Path $env:LOCALAPPDATA "SS-Tool"
$zipDest     = Join-Path $env:TEMP $zipName

$downloadHeaders = @{
    "Authorization" = "Bearer $token"
    "User-Agent"    = "ss-tool-installer"
    "Accept"        = "application/octet-stream"
}

Write-Host "Indiriliyor: $($asset.name) ($([math]::Round($asset.size / 1MB, 2)) MB)" -ForegroundColor Cyan
Invoke-WebRequest -Uri $assetApiUrl -Headers $downloadHeaders -OutFile $zipDest

# Token'i bellekten temizle
$token = $null
$headers = $null
$downloadHeaders = $null
[System.GC]::Collect()

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
