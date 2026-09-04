# SS Tool - GitHub Release'inden indirip calistirma script'i
# ------------------------------------------------------------------
# Bu script, kaynak kodu (src) ICERMEYEN, sadece derlenmis .exe paketini
# (target\dist\SS-Tool klasorunun zip'i) GitHub Release'inden indirir ve
# calistirir.
#
# NOT: .exe paketi kendi icinde JRE barindirir - bu script'i calistiran
# makinede AYRICA JAVA KURULU OLMASI GEREKMEZ.
#
# RELEASE'E YUKLENECEK DOSYA: `build.bat` calistirdiktan sonra olusan
# target\dist\SS-Tool klasorunu zip'leyip "SS-Tool.zip" adiyla GitHub
# Release'e asset olarak yukleyin.
#
# Repo PUBLIC ise (https://github.com/kadirwastaken5/Planet-SS-Tool):
# hicbir token gerekmez, script dogrudan calisir - tek satirla:
#   irm https://raw.githubusercontent.com/kadirwastaken5/Planet-SS-Tool/main/run.ps1 | iex
#
# Repo ileride PRIVATE yapilirsa: script bunu otomatik fark edip bir
# Personal Access Token (PAT) ister (ekranda gorunmez) - o durumda
# "irm | iex" tek satiri calismaz, bu dosyayi lokal indirip
# "powershell -ExecutionPolicy Bypass -File .\run.ps1" ile calistirmak
# gerekir (private repolarda raw.githubusercontent.com kimliksiz
# istekleri reddeder).
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
$release = $null
$usingToken = $false

try {
    # Once TOKENSIZ dene - repo public ise bu yeterlidir.
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
} catch {
    # Basarisiz oldu (403/404) - repo private olabilir, token sor.
    Write-Host "[UYARI] Kimliksiz istek basarisiz oldu (repo private olabilir)." -ForegroundColor Yellow
    Write-Host "        Devam etmek icin bir GitHub Personal Access Token gerekiyor." -ForegroundColor Yellow

    $token = $env:SSTOOL_GH_TOKEN
    if (-not $token) {
        $secureToken = Read-Host "GitHub Personal Access Token (repo:read yetkili)" -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $token = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }

    if (-not $token) {
        Write-Host "HATA: Token girilmedi, devam edilemiyor." -ForegroundColor Red
        exit 1
    }

    $headers["Authorization"] = "Bearer $token"
    $usingToken = $true

    try {
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
    } catch {
        Write-Host "HATA: Release bilgisi alinamadi. Token gecersiz/yetkisiz olabilir veya repo/owner adi yanlis." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
        exit 1
    }
}

$asset = $release.assets | Where-Object { $_.name -eq $zipName }

if (-not $asset) {
    Write-Host "HATA: Release icinde '$zipName' bulunamadi." -ForegroundColor Red
    Write-Host "      (target\dist\SS-Tool klasorunu zip'leyip '$zipName' adiyla release'e ekleyin.)" -ForegroundColor Red
    exit 1
}

$installDir = Join-Path $env:LOCALAPPDATA "SS-Tool"
$zipDest    = Join-Path $env:TEMP $zipName

if ($usingToken) {
    # ONEMLI: Private repolarda asset indirmek icin 'browser_download_url'
    # YETMEZ; API'nin asset endpoint'i + 'application/octet-stream' Accept
    # basligi ile, ayni Authorization token'i kullanilarak indirilmesi gerekir.
    $downloadHeaders = @{
        "Authorization" = $headers["Authorization"]
        "User-Agent"    = "ss-tool-installer"
        "Accept"        = "application/octet-stream"
    }
    $downloadUrl = $asset.url
} else {
    # Public repo - dogrudan indirme linki tokensiz calisir.
    $downloadHeaders = @{ "User-Agent" = "ss-tool-installer" }
    $downloadUrl = $asset.browser_download_url
}

Write-Host "Indiriliyor: $($asset.name) ($([math]::Round($asset.size / 1MB, 2)) MB)" -ForegroundColor Cyan
Invoke-WebRequest -Uri $downloadUrl -Headers $downloadHeaders -OutFile $zipDest

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
