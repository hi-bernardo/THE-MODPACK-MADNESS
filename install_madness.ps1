# ==============================================================================
# CONFIGURACOES E LINKS (Altere os links do ZIP e MRPACK aqui)
# ==============================================================================
# ATENCAO: Coloque aqui o link RAW do proprio script no seu GitHub para o UAC funcionar
$ScriptRAW = "https://raw.githubusercontent.com/hi-bernardo/THE-MODPACK-MADNESS/refs/heads/main/install_madness.ps1"

$LinkMrpack = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1.0/modpack.mrpack"
$LinkZip    = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1.0/modpack.zip"
$LinkPrism  = "https://github.com/PrismLauncher/PrismLauncher/releases/download/11.0.2/PrismLauncher-Windows-MSVC-Setup-11.0.2.exe"
$LinkSK     = "https://github.com/sklauncher/installer/releases/download/latest/SKlauncher_3.2.18_Setup.exe"
$LinkJava   = "https://download.oracle.com/graalvm/21/latest/graalvm-jdk-21_windows-x64_bin.zip"

# ==============================================================================
# AUTO-ELEVACAO PARA ADMINISTRADOR (UAC)
# ==============================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "🛠️  Privilegios de Administrador necessarios para instalar os Launchers." -ForegroundColor Yellow
    Write-Host "🛡️  Aguarde a tela do UAC do Windows e clique em 'Sim'..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    
    # Reexecuta o comando irm | iex com permissão de Admin
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm $ScriptRAW | iex`"" -Verb RunAs
    exit
}

# Configura o console para UTF-8 e cor
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Instalador - THE MODPACK MADNESS"

function Mostrar-Cabecalho {
    Clear-Host
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "       ___  ____                                  _      _    ___  _      " -ForegroundColor Green
    Write-Host "      / _ \| __ ) _ __ __ _ _______  ___         | |    / \  | _ )( )___  " -ForegroundColor Green
    Write-Host "     | | | |  _ \| '__/ _` |_  / _ \/ _ \  _____ | |   / _ \ | _ \|// __| " -ForegroundColor Green
    Write-Host "     | |_| | |_) | | | (_| |/ / (_) \ (_) |_____|| |___/ ___ \| _ \   \__ \" -ForegroundColor Green
    Write-Host "      \___/|____/|_|  \__,_/___\___/ \___/       |____/_/   \_\___/   |___/" -ForegroundColor Green
    Write-Host ""
    Write-Host "                        oBrazoo_ LAB`s" -ForegroundColor DarkCyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Bem-vindo(a) ao instalador automatico do THE MODPACK MADNESS!" -ForegroundColor White
    Write-Host " Este script vai baixar seu Launcher, o Java GraalVM e o Modpack." -ForegroundColor Gray
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ==============================================================================
# MENU 1: ESCOLHA DO LAUNCHER
# ==============================================================================
Mostrar-Cabecalho
Write-Host " [ 1 ] Jogar usando o PRISM LAUNCHER (Recomendado/Original)" -ForegroundColor Yellow
Write-Host " [ 2 ] Jogar usando o SKLAUNCHER (Pirata)" -ForegroundColor Yellow
Write-Host ""
Write-Host " Pressione 1 ou 2: " -NoNewline -ForegroundColor Cyan

$keyLauncher = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
$LauncherType = if ($keyLauncher -eq '1') { "PRISM" } else { "SKLAUNCHER" }

# ==============================================================================
# MENU 2: FLUXO DO JAVA (GRAALVM)
# ==============================================================================
Mostrar-Cabecalho
Write-Host " [ CONFIGURACAO DO JAVA (GRAALVM 21) ]" -ForegroundColor Yellow
Write-Host ""
Write-Host " O Minecraft 1.20+ exige o Java 21 para rodar com os mods." -ForegroundColor White
Write-Host " Quer que eu baixe e extraia o Java GraalVM pra voce?" -ForegroundColor White
Write-Host ""
Write-Host " [ S ] Sim, baixa pra mim!" -ForegroundColor Green
Write-Host " [ N ] Nao, eu ja tenho o Java 21 configurado no meu PC." -ForegroundColor Red
Write-Host ""
Write-Host " Pressione S ou N: " -NoNewline -ForegroundColor Cyan

$keyJava = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character

if ($keyJava -match '[sS]') {
    Write-Host "`n`n[1/2] Baixando o GraalVM 21... (Cerca de 180MB, aguarde...)" -ForegroundColor Cyan
    $javaZip = "$env:TEMP\graalvm.zip"
    Invoke-WebRequest -Uri $LinkJava -OutFile $javaZip

    Write-Host "[2/2] Extraindo o Java... (Isso pode demorar um minutinho)" -ForegroundColor Cyan
    $javaPath = "$env:LOCALAPPDATA\GraalVM"
    if (-not (Test-Path $javaPath)) { New-Item -ItemType Directory -Path $javaPath | Out-Null }
    Expand-Archive -Path $javaZip -DestinationPath $javaPath -Force
    Remove-Item $javaZip

    Write-Host "`n==============================================================================" -ForegroundColor Red
    Write-Host " AVISO IMPORTANTE SOBRE O JAVA! LEIA ANTES DE CONTINUAR:" -ForegroundColor Yellow
    Write-Host "==============================================================================" -ForegroundColor Red
    Write-Host " O Java foi extraido com sucesso. Quando voce for configurar o seu Launcher," -ForegroundColor White
    Write-Host " procure o Java (javaw.exe) EXATAMENTE neste caminho abaixo:`n" -ForegroundColor White
    Write-Host " $javaPath " -ForegroundColor Green
    Write-Host "`n Entre na pasta extraida, depois em 'bin', e selecione 'javaw.exe'." -ForegroundColor White
    Write-Host "==============================================================================" -ForegroundColor Red
    Write-Host " Pressione qualquer tecla para continuar..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ==============================================================================
# FLUXO DE INSTALACAO
# ==============================================================================
Mostrar-Cabecalho
Write-Host " [ OPCAO SELECIONADA: $LauncherType ]" -ForegroundColor Yellow
Write-Host ""
Write-Host " Voce ja tem o $LauncherType instalado no seu PC?" -ForegroundColor White
Write-Host " [ S ] Sim, ja tenho!" -ForegroundColor Green
Write-Host " [ N ] Nao, baixa pra mim." -ForegroundColor Red
Write-Host ""
Write-Host " Pressione S ou N: " -NoNewline -ForegroundColor Cyan

$keyInstalar = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character

if ($LauncherType -eq "PRISM") {
    if ($keyInstalar -match '[nN]') {
        Write-Host "`n`nBaixando o instalador do Prism Launcher..." -ForegroundColor Cyan
        $prismSetup = "$env:TEMP\PrismSetup.exe"
        Invoke-WebRequest -Uri $LinkPrism -OutFile $prismSetup
        Write-Host "Instalando o Prism... Siga as instrucoes na tela que vai abrir!" -ForegroundColor Yellow
        Start-Process -FilePath $prismSetup -Wait
        Remove-Item $prismSetup
    }

    Write-Host "`nBaixando o Modpack (.mrpack)..." -ForegroundColor Cyan
    $mrpackPath = "$env:USERPROFILE\Downloads\Madness.mrpack"
    Invoke-WebRequest -Uri $LinkMrpack -OutFile $mrpackPath

    Write-Host "`nTudo pronto! O modpack foi baixado." -ForegroundColor Green
    Write-Host "Vou abrir ele no Prism Launcher agora. Basta confirmar a importacao. Bom jogo!`n" -ForegroundColor White
    Start-Sleep -Seconds 3
    Start-Process -FilePath $mrpackPath

} elseif ($LauncherType -eq "SKLAUNCHER") {
    if ($keyInstalar -match '[nN]') {
        Write-Host "`n`nBaixando o instalador do SKLauncher..." -ForegroundColor Cyan
        $skSetup = "$env:TEMP\SKSetup.exe"
        Invoke-WebRequest -Uri $LinkSK -OutFile $skSetup
        Write-Host "Instalando o SKLauncher... Siga os passos na tela!" -ForegroundColor Yellow
        Start-Process -FilePath $skSetup -Wait
        Remove-Item $skSetup
    }

    Write-Host "`nBaixando os arquivos do Modpack (Mods, configs, shaders, etc)..." -ForegroundColor Cyan
    $modpackZip = "$env:TEMP\modpack.zip"
    Invoke-WebRequest -Uri $LinkZip -OutFile $modpackZip

    Write-Host "Extraindo arquivos direto para a pasta padrao do Minecraft..." -ForegroundColor Cyan
    $mcDir = "$env:APPDATA\.minecraft"
    Expand-Archive -Path $modpackZip -DestinationPath $mcDir -Force
    Remove-Item $modpackZip

    Write-Host "`n==============================================================================" -ForegroundColor Green
    Write-Host " TUDO PRONTO!" -ForegroundColor Green
    Write-Host "==============================================================================" -ForegroundColor Green
    Write-Host " Os mods foram instalados na pasta padrao do jogo." -ForegroundColor White
    Write-Host " Agora e so abrir o SKLauncher, apontar para o Java (se baixou agora)" -ForegroundColor White
    Write-Host " e jogar THE MODPACK MADNESS!`n" -ForegroundColor White
    Write-Host " Pressione qualquer tecla para sair..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}