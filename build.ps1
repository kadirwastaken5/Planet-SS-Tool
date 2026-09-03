# PLANET SS-TOOL // UNIVERSAL BUILD SCRIPT
$ErrorActionPreference = 'Stop'

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   PLANET SS-TOOL // OTOMATIK DERLEME (BUILD)" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

# 1. Java / JDK Tespiti
Write-Host "[1/3] Java JDK kontrol ediliyor..." -ForegroundColor Yellow

$foundJdk = $null

# Kontrol edilecek olasi JDK yollari
$candidateJdkDirs = @(
    "C:\Program Files\Java\jdk-25",
    "C:\Program Files\Java\jdk-21",
    "C:\Program Files\Java\jdk-17",
    "C:\Program Files\Eclipse Adoptium\jdk-21*",
    "C:\Program Files\Eclipse Adoptium\jdk-17*",
    "C:\Program Files\Java\jdk*",
    "C:\Program Files\Eclipse Adoptium\jdk*",
    "C:\Program Files\BellSoft\*",
    "C:\Program Files\JetBrains\*\jbr",
    "$env:JAVA_HOME"
)

foreach ($pattern in $candidateJdkDirs) {
    if (-not $pattern) { continue }
    $resolved = Resolve-Path $pattern -ErrorAction SilentlyContinue
    foreach ($r in $resolved) {
        $p = $r.Path
        if (Test-Path "$p\bin\java.exe") {
            $foundJdk = $p
            break
        }
    }
    if ($foundJdk) { break }
}

if ($foundJdk) {
    $env:JAVA_HOME = $foundJdk
    Write-Host "  -> JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Green
} else {
    Write-Host "[HATA] Bilgisayarda Java JDK (17+) bulunamadi!" -ForegroundColor Red
    Write-Host "Lutfen Adoptium JDK 17 veya 21 kurun: https://adoptium.net" -ForegroundColor Red
    exit 1
}

# 2. Maven Tespiti veya Otomatik Yukleme
Write-Host "[2/3] Maven kontrol ediliyor..." -ForegroundColor Yellow
$mvnPath = $null

if (Get-Command mvn -ErrorAction SilentlyContinue) {
    $mvnPath = (Get-Command mvn).Source
} else {
    $searchPaths = @(
        "C:\Program Files\JetBrains\*\plugins\maven\lib\maven3\bin\mvn.cmd",
        "C:\Program Files\*\maven*\bin\mvn.cmd",
        "C:\ProgramData\chocolatey\bin\mvn.cmd",
        "$env:LOCALAPPDATA\Programs\*\bin\mvn.cmd",
        "$env:USERPROFILE\scoop\shims\mvn.cmd"
    )

    foreach ($pattern in $searchPaths) {
        $found = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $mvnPath = $found.FullName
            break
        }
    }
}

# Eger arkadasinda Maven veya IntelliJ hic yoksa, temp klasorune portable Maven indirip calistir
if (-not $mvnPath) {
    Write-Host "  -> Sistemde yuklu Maven bulunamadi, tasinabilir Maven hazirlaniyor..." -ForegroundColor DarkYellow
    $tempDir = Join-Path $env:TEMP "planet-maven-portable"
    $mvnExe = Join-Path $tempDir "apache-maven-3.9.6\bin\mvn.cmd"
    
    if (-not (Test-Path $mvnExe)) {
        Write-Host "  -> Maven indiriliyor (tek seferlik)..." -ForegroundColor Cyan
        $zipPath = Join-Path $env:TEMP "apache-maven-3.9.6-bin.zip"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://archive.apache.org/dist/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.zip" -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    }
    $mvnPath = $mvnExe
}

Write-Host "  -> Maven Yolu: $mvnPath" -ForegroundColor Green

# 3. Derlemeyi Baslat (Testleri Atlayarak Hizlica)
Write-Host ""
Write-Host "[3/3] Proje paketleniyor (mvn clean package -DskipTests)..." -ForegroundColor Cyan
Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($projectDir) { Set-Location $projectDir }

& $mvnPath clean package -DskipTests

if ($LASTEXITCODE -ne 0) {
    # Derleme basarisiz oldu. En olasi sebep: ProGuard obfuscation adimi
    # (bkz. pom.xml) bu makinede sorun cikarmis olabilir. Once ProGuard'i
    # atlayarak OTOMATIK TEKRAR DENE - boylece obfuscation calismasa bile
    # en azindan .exe uretilebilsin (obfuscate edilmemis olarak).
    Write-Host ""
    Write-Host "[UYARI] Ilk derleme basarisiz oldu. ProGuard (kod gizleme) adimi" -ForegroundColor Yellow
    Write-Host "        atlanarak tekrar deneniyor..." -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray

    & $mvnPath clean package -DskipTests "-Dproguard.skip=true"

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=======================================================" -ForegroundColor Yellow
        Write-Host " [OK] Paketleme ProGuard OLMADAN basarili oldu." -ForegroundColor Yellow
        Write-Host " (.exe uretilecek ama kod gizleme/obfuscation bu sefer" -ForegroundColor Yellow
        Write-Host "  calismadi - proguard hata mesajini yukarida gorebilirsin.)" -ForegroundColor Yellow
        Write-Host "=======================================================" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "[HATA] Derleme ProGuard olmadan da basarisiz oldu." -ForegroundColor Red
        Write-Host "       Bu artik ProGuard'dan bagimsiz gercek bir kod/bagimlilik hatasi." -ForegroundColor Red
        Write-Host "       Yukaridaki mvn ciktisini (ozellikle [ERROR] satirlarini) paylas." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host " [OK] PAKETLEME BASARILI (ara adim)" -ForegroundColor Green
    Write-Host " Simdi native .exe olusturulacak..." -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
}

# 4. .exe Paketleme (jpackage - JDK 14+ ile birlikte gelir, WiX gerektirmez)
Write-Host ""
Write-Host "[4/4] Native .exe paketi olusturuluyor (jpackage)..." -ForegroundColor Cyan
Write-Host "      Bu adim jlink ile ozel bir Java calisma zamani insa" -ForegroundColor DarkGray
Write-Host "      ediyor - 1-5 dakika surebilir, ozellikle Windows Defender" -ForegroundColor DarkGray
Write-Host "      gercek zamanli tarama yapiyorsa daha da yavas olabilir." -ForegroundColor DarkGray
Write-Host "      Konsolda asagida ilerleme satirlari akmaya baslayacak," -ForegroundColor DarkGray
Write-Host "      hicbir sey akmiyorsa (birkac dakika sonra bile) gercekten" -ForegroundColor DarkGray
Write-Host "      takilmis olabilir." -ForegroundColor DarkGray
Write-Host "-------------------------------------------------------" -ForegroundColor DarkGray

$jpackagePath = Join-Path $env:JAVA_HOME "bin\jpackage.exe"

if (-not (Test-Path $jpackagePath)) {
    Write-Host "[UYARI] jpackage.exe bulunamadi ($jpackagePath)." -ForegroundColor Yellow
    Write-Host "         .jar dosyasi hazir ama .exe paketi atlandi." -ForegroundColor Yellow
    Write-Host "         (JDK 14+ jpackage'i icerir; farkli bir JDK dizini deneyin.)" -ForegroundColor Yellow
    exit 0
}

$distDir = Join-Path $projectDir "target\dist"
if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

$jarDir = Join-Path $projectDir "target"

$iconPath = Join-Path $projectDir "app-icon.ico"

$jpackageArgs = @(
    "--type", "app-image",
    "--input", $jarDir,
    "--dest", $distDir,
    "--name", "SS-Tool",
    "--main-jar", "SS-Tool.jar",
    "--main-class", "com.sstool.Main",
    "--app-version", "1.2.0",
    "--vendor", "Planet",
    # ONEMLI: --add-modules VERMEZSEK jpackage/jlink, gerekli moduelleri
    # bulmak icin fat jar'in TAMAMINI jdeps ile tarar - ProGuard'dan gecmis
    # buyuk/obfuscate jar'larda bu tarama bazen SAATLERCE surebilir veya
    # hic bitmeyebilir (bilinen jlink sorunu). Modulleri burada SABIT
    # vererek bu yavas/riskli otomatik taramayi tamamen atlıyoruz.
    "--add-modules", "java.base,java.desktop,java.logging,java.xml,java.scripting,java.net.http",
    "--verbose"
)

if (Test-Path $iconPath) {
    $jpackageArgs += @("--icon", $iconPath)
} else {
    Write-Host "[UYARI] app-icon.ico bulunamadi, varsayilan Java ikonu kullanilacak." -ForegroundColor Yellow
}

$jpackageStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& $jpackagePath @jpackageArgs
$jpackageStopwatch.Stop()
Write-Host ""
Write-Host "(jpackage suresi: $($jpackageStopwatch.Elapsed.ToString('mm\:ss')))" -ForegroundColor DarkGray

if ($LASTEXITCODE -eq 0) {
    # .exe basariyla uretildi - artik ara .jar dosyasina gerek yok, sadece
    # .exe kalsin diye siliniyor.
    $intermediateJar = Join-Path $jarDir "SS-Tool.jar"
    if (Test-Path $intermediateJar) {
        Remove-Item $intermediateJar -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Green
    Write-Host " [OK] .EXE PAKETI HAZIR!" -ForegroundColor Green
    Write-Host " Cikti: target\dist\SS-Tool\SS-Tool.exe" -ForegroundColor Green
    Write-Host " (Bu klasoru oldugu gibi tasiyabilir/paylasabilirsiniz," -ForegroundColor Green
    Write-Host "  JRE zaten icine gomulu, ayrica Java kurmaya gerek yok." -ForegroundColor Green
    Write-Host "  Ara .jar dosyasi silindi, tek cikti .exe'dir.)" -ForegroundColor Green
    Write-Host "=======================================================" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "[UYARI] .exe paketleme basarisiz oldu, ama .jar dosyasi zaten kullanilabilir." -ForegroundColor Yellow
    Write-Host "        target\SS-Tool.jar dosyasini 'java -jar' ile calistirabilirsiniz." -ForegroundColor Yellow
    exit 0
}
