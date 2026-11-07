# Planet SS-Tool - Tek dosyalik indirme + calistirma script'i
# ------------------------------------------------------------------
# GitHub'daki reponun icinde SADECE bu dosya (run.ps1) bulunur. Kaynak
# kod (src) reponuza HIC PUSH EDILMEZ. Bu script, en son GitHub
# Release'ine eklenmis derlenmis "SS-Tool.jar" dosyasini indirir ve
# dogrudan "java -jar" ile calistirir.
#
# HERKES kullanabilir - hicbir token/giris gerekmez (repo public).
#
# RELEASE'E YUKLENECEK DOSYA: `mvn clean package` sonrasi olusan
# target/SS-Tool.jar dosyasini GitHub'da yeni bir Release acip
# "SS-Tool.jar" adiyla asset olarak yukleyin.
#
# TEK SATIRLA KULLANIM:
#   irm https://raw.githubusercontent.com/kadirwastaken5/Planet-SS-Tool/main/run.ps1 | iex
# ------------------------------------------------------------------

$owner   = "kadirwastaken5"
$repo    = "Planet-SS-Tool"
$jarName = "SS-Tool.jar"

function Fail($message) {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Red
    Write-Host " HATA: $message" -ForegroundColor Red
    Write-Host "=======================================================" -ForegroundColor Red
    Write-Host ""
    Read-Host "Kapatmak icin Enter'a basin" | Out-Null
    exit 1
}

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " Planet SS-Tool - Indirici" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

# 1) Java kurulu mu kontrol et (jar icin sart - exe'nin aksine JRE gomulu degil)
Write-Host "[1/4] Java kontrol ediliyor..." -ForegroundColor Yellow
$javaCheck = Get-Command java -ErrorAction SilentlyContinue
if (-not $javaCheck) {
    Fail "Java bulunamadi. Once Java 17+ kurun: https://adoptium.net/temurin/releases/ (kurulumdan sonra bu komutu tekrar calistirin)."
}
Write-Host "      Java bulundu: $($javaCheck.Source)" -ForegroundColor DarkGray

# 2) En son release bilgisini cek (public repo - token gerekmez)
Write-Host ""
Write-Host "[2/4] En son release bilgisi cekiliyor..." -ForegroundColor Yellow

$apiUrl = "https://api.github.com/repos/$owner/$repo/releases/latest"
$headers = @{
    "User-Agent" = "ss-tool-installer"
    "Accept"     = "application/vnd.github+json"
}

try {
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
} catch {
    $statusCode = $null
    if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
    if ($statusCode -eq 404) {
        Fail "'$owner/$repo' icin henuz bir GitHub Release yok. GitHub'da 'Releases -> Draft a new release' ile bir release acip target/SS-Tool.jar dosyasini '$jarName' adiyla asset olarak ekleyin."
    }
    Fail "Release bilgisi alinamadi (HTTP $statusCode): $($_.Exception.Message)"
}

$asset = $release.assets | Where-Object { $_.name -eq $jarName }
if (-not $asset) {
    Fail "En son release'de '$jarName' bulunamadi. Release'e '$jarName' adiyla asset eklendiginden emin olun."
}

# 3) Jar'i indir
Write-Host ""
Write-Host "[3/4] Indiriliyor: $($asset.name) ($([math]::Round($asset.size / 1MB, 2)) MB)..." -ForegroundColor Yellow

$installDir = Join-Path $env:LOCALAPPDATA "SS-Tool"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}
$jarDest = Join-Path $installDir $jarName

try {
    Invoke-WebRequest -Uri $asset.browser_download_url -Headers @{ "User-Agent" = "ss-tool-installer" } -OutFile $jarDest -ErrorAction Stop
} catch {
    Fail "Jar indirilemedi: $($_.Exception.Message)"
}

if (-not (Test-Path $jarDest) -or (Get-Item $jarDest).Length -eq 0) {
    Fail "Indirilen dosya bos veya bulunamadi: $jarDest"
}

# 4) Calistir
Write-Host ""
Write-Host "[4/4] Calistiriliyor: $jarDest" -ForegroundColor Green
Write-Host ""

try {
    & java -jar "$jarDest"
} catch {
    Fail "Uygulama baslatilirken hata olustu: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "SS-Tool kapatildi." -ForegroundColor DarkGray
Read-Host "Cikmak icin Enter'a basin" | Out-Null
