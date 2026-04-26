# ==============================================================================
# CONFIGURACOES E LINKS
# ==============================================================================
$ScriptRAW  = "https://raw.githubusercontent.com/hi-bernardo/THE-MODPACK-MADNESS/main/install_madness.ps1"
$LinkMrpack = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1.0/modpack.mrpack"
$LinkZip    = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1.0/modpack.zip"
$LinkPrism  = "https://github.com/PrismLauncher/PrismLauncher/releases/download/11.0.2/PrismLauncher-Windows-MSVC-Setup-11.0.2.exe"
$LinkSK     = "https://github.com/sklauncher/installer/releases/download/latest/SKlauncher_3.2.18_Setup.exe"
$LinkJava   = "https://download.oracle.com/graalvm/21/latest/graalvm-jdk-21_windows-x64_bin.zip"
$ServerIP   = "play.hiagobernardo.com"

# ==============================================================================
# AUTO-ELEVACAO PARA ADMINISTRADOR (UAC)
# ==============================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host " Privilegios de Administrador necessarios." -ForegroundColor Yellow
    Write-Host " Aguarde a tela do UAC e clique em 'Sim'..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2

    if ($PSCommandPath) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    } else {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm $ScriptRAW | iex`"" -Verb RunAs
    }
    exit
}

# ==============================================================================
# FUNCOES DE INTERFACE
# ==============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Instalador - THE MODPACK MADNESS"

function Mostrar-Cabecalho {
    Clear-Host
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "        ____                                     _        _    ____       " -ForegroundColor Green
    Write-Host "   ___ | __ ) _ __ __ _ _______   ___           | |      / \  | __ ) ___ " -ForegroundColor Green
    Write-Host "  / _ \|  _ \| '__/ _`` |_  / _ \ / _ \   _____  | |     / _ \ |  _ \/ __|" -ForegroundColor Green
    Write-Host " | (_) | |_) | | | (_| |/ / (_) | (_) | |_____| | |___ / ___ \| |_) \__ \" -ForegroundColor Green
    Write-Host "  \___/|____/|_|  \__,_/___\___/ \___/          |_____/_/   \_\____/|___/" -ForegroundColor Green
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Ler-Opcao {
    param ([array]$OpcoesValidas)
    while ($true) {
        $teclaInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $tecla = $teclaInfo.Character.ToString().ToLower()
        if ($tecla -eq 'm') { $tecla = 'v' }
        if ($OpcoesValidas -contains $tecla) { return $tecla }
        Write-Host "`n [!] Opcao invalida. Use apenas [ $($OpcoesValidas -join ', ') ]: " -NoNewline -ForegroundColor Red
    }
}

function Mostrar-Sucesso {
    Write-Host "`n==============================================================================" -ForegroundColor Green
    Write-Host "                    INSTALACAO CONCLUIDA COM SUCESSO!" -ForegroundColor Green
    Write-Host "==============================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Para entrar no servidor, use o IP:" -ForegroundColor White
    Write-Host "  $ServerIP" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Qualquer problema, chama no Discord!" -ForegroundColor Gray
    Write-Host "==============================================================================" -ForegroundColor Green
}

# ==============================================================================
# LOOP PRINCIPAL
# ==============================================================================
while ($true) {

    # ----------------------------------------------------------
    # PASSO 1: CONFIGURACAO DO JAVA
    # ----------------------------------------------------------
    Mostrar-Cabecalho
    Write-Host " [ PASSO 1 de 3: JAVA 21 (GraalVM) ]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " O Minecraft 1.20+ exige Java 21 para rodar com os mods." -ForegroundColor White
    Write-Host " Quer que eu baixe e configure o GraalVM Java 21 pra voce?" -ForegroundColor White
    Write-Host ""
    Write-Host " [ 1 ]  Sim, baixa vai pfvr." -ForegroundColor Green
    Write-Host " [ 2 ]  Nao, ja tenho o Java 21 instalado." -ForegroundColor DarkGray
    Write-Host " [ V ]  Voltar ao inicio" -ForegroundColor Gray
    Write-Host ""
    Write-Host " Opcao: " -NoNewline -ForegroundColor Cyan

    $optJava = Ler-Opcao -OpcoesValidas @('1','2','v')
    if ($optJava -eq 'v') { continue }

    if ($optJava -eq '1') {
        Write-Host "`n"
        Write-Host " [1/2] Baixando GraalVM 21..." -ForegroundColor Cyan
        $javaZip = "$env:TEMP\graalvm.zip"
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $LinkJava -OutFile $javaZip
        } catch {
            Write-Host "`n [ERRO] Falha ao baixar o Java: $_" -ForegroundColor Red
            Write-Host " Verifique sua conexao e tente novamente." -ForegroundColor Yellow
            Write-Host "`n Pressione ENTER para voltar..." -ForegroundColor Gray
            Read-Host
            continue
        }
        $ProgressPreference = 'Continue'

        Write-Host " [2/2] Extraindo Java em %LOCALAPPDATA%\GraalVM ..." -ForegroundColor Cyan
        $javaDir = "$env:LOCALAPPDATA\GraalVM"
        if (-not (Test-Path $javaDir)) { New-Item -ItemType Directory -Path $javaDir | Out-Null }
        Expand-Archive -Path $javaZip -DestinationPath $javaDir -Force
        Remove-Item $javaZip -ErrorAction SilentlyContinue

        $javawPath = Get-ChildItem -Path $javaDir -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

        Write-Host ""
        Write-Host " ==============================================================================" -ForegroundColor Magenta
        if ($javawPath) {
            Set-Clipboard -Value $javawPath
            Write-Host "  Java instalado e o caminho foi COPIADO (Ctrl+V no launcher)!" -ForegroundColor Green
            Write-Host "  Caminho: $javawPath" -ForegroundColor DarkGray
        } else {
            Write-Host "  Java extraido em: $javaDir" -ForegroundColor White
            Write-Host "  Procure o arquivo 'javaw.exe' dentro da pasta 'bin'." -ForegroundColor White
        }
        Write-Host " ==============================================================================" -ForegroundColor Magenta
        Write-Host ""
        Write-Host " Pressione ENTER para continuar..." -ForegroundColor Gray
        Read-Host
    }

    # ----------------------------------------------------------
    # PASSO 2: ESCOLHA DO LAUNCHER
    # ----------------------------------------------------------
    Mostrar-Cabecalho
    Write-Host " [ PASSO 2 de 3: LAUNCHER ]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " Qual launcher voce vai usar?" -ForegroundColor White
    Write-Host ""
    Write-Host " [ 1 ]  Prism Launcher  (conta Microsoft original)" -ForegroundColor Green
    Write-Host " [ 2 ]  SKLauncher      (conta pirata / sem conta)" -ForegroundColor Green
    Write-Host " [ V ]  Voltar" -ForegroundColor Gray
    Write-Host ""
    Write-Host " Opcao: " -NoNewline -ForegroundColor Cyan

    $optLauncher = Ler-Opcao -OpcoesValidas @('1','2','v')
    if ($optLauncher -eq 'v') { continue }

    $LauncherType = if ($optLauncher -eq '1') { "PRISM" } else { "SKLAUNCHER" }

    # ----------------------------------------------------------
    # PASSO 3: INSTALACAO DO LAUNCHER
    # ----------------------------------------------------------
    Mostrar-Cabecalho
    Write-Host " [ PASSO 3 de 3: INSTALANDO $LauncherType ]" -ForegroundColor Yellow
    Write-Host ""

    # Auto-deteccao
    $launcherAchado = $false
    if ($LauncherType -eq "PRISM" -and (Test-Path "$env:LOCALAPPDATA\Programs\PrismLauncher\prismlauncher.exe")) {
        $launcherAchado = $true
    } elseif ($LauncherType -eq "SKLAUNCHER") {
        if ((Test-Path "$env:LOCALAPPDATA\Programs\sklauncher\SKlauncher.exe") -or
            (Test-Path "$env:APPDATA\.minecraft\sklauncher*")) {
            $launcherAchado = $true
        }
    }

    if ($launcherAchado) {
        Write-Host " O $LauncherType ja esta instalado! Pulando download." -ForegroundColor Green
        $baixarLauncher = '1'
        Start-Sleep -Seconds 2
    } else {
        Write-Host " Voce ja tem o $LauncherType instalado (em outra pasta)?" -ForegroundColor White
        Write-Host ""
        Write-Host " [ 1 ]  Sim, ja tenho. (pular download)" -ForegroundColor Green
        Write-Host " [ 2 ]  Nao, baixa pra mim." -ForegroundColor DarkGray
        Write-Host " [ V ]  Voltar" -ForegroundColor Gray
        Write-Host ""
        Write-Host " Opcao: " -NoNewline -ForegroundColor Cyan

        $optInstalar = Ler-Opcao -OpcoesValidas @('1','2','v')
        if ($optInstalar -eq 'v') { continue }
        $baixarLauncher = $optInstalar
    }

    if ($baixarLauncher -eq '2') {
        if ($LauncherType -eq "PRISM") {
            Write-Host "`n Baixando Prism Launcher..." -ForegroundColor Cyan
            $prismSetup = "$env:TEMP\PrismSetup.exe"
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $LinkPrism -OutFile $prismSetup
            $ProgressPreference = 'Continue'
            Write-Host ""
            Write-Host " ATENCAO: Na ultima tela do instalador, DESMARQUE 'Abrir Prism Launcher'!" -ForegroundColor Magenta
            Write-Host " O script precisa continuar depois que o instalador fechar." -ForegroundColor White
            Write-Host ""
            Start-Process -FilePath $prismSetup -Wait
            Remove-Item $prismSetup -ErrorAction SilentlyContinue
        } else {
            Write-Host "`n Baixando SKLauncher..." -ForegroundColor Cyan
            $skSetup = "$env:TEMP\SKSetup.exe"
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $LinkSK -OutFile $skSetup
            $ProgressPreference = 'Continue'
            Write-Host ""
            Write-Host " ATENCAO: Se o SKLauncher abrir sozinho ao final, FECHE ELE para continuar!" -ForegroundColor Magenta
            Write-Host ""
            Start-Process -FilePath $skSetup -Wait
            Remove-Item $skSetup -ErrorAction SilentlyContinue
        }
    }

    # ----------------------------------------------------------
    # PASSO 4: DOWNLOAD E IMPORTACAO DO MODPACK
    # ----------------------------------------------------------
    Mostrar-Cabecalho
    Write-Host " [ INSTALANDO O MODPACK ]" -ForegroundColor Yellow
    Write-Host ""

    if ($LauncherType -eq "PRISM") {
        Write-Host " Baixando modpack (.mrpack)..." -ForegroundColor Cyan
        $mrpackPath = "$env:USERPROFILE\Downloads\Madness.mrpack"
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $LinkMrpack -OutFile $mrpackPath
        } catch {
            Write-Host "`n [ERRO] Falha ao baixar o modpack: $_" -ForegroundColor Red
            Write-Host " Verifique sua conexao e tente novamente." -ForegroundColor Yellow
            Write-Host "`n Pressione ENTER para voltar..." -ForegroundColor Gray
            Read-Host
            continue
        }
        $ProgressPreference = 'Continue'

        Write-Host " Abrindo no Prism Launcher... confirme a importacao na janela que abrir." -ForegroundColor White
        Start-Sleep -Seconds 2
        Start-Process -FilePath $mrpackPath

    } elseif ($LauncherType -eq "SKLAUNCHER") {
        Write-Host " Baixando modpack (.zip)..." -ForegroundColor Cyan
        $modpackZip = "$env:TEMP\modpack.zip"
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $LinkZip -OutFile $modpackZip
        } catch {
            Write-Host "`n [ERRO] Falha ao baixar o modpack: $_" -ForegroundColor Red
            Write-Host " Verifique sua conexao e tente novamente." -ForegroundColor Yellow
            Write-Host "`n Pressione ENTER para voltar..." -ForegroundColor Gray
            Read-Host
            continue
        }
        $ProgressPreference = 'Continue'

        Write-Host " Extraindo arquivos para %APPDATA%\.minecraft ..." -ForegroundColor Cyan
        $mcDir = "$env:APPDATA\.minecraft"

        # Garante que as pastas existam antes de extrair
        @("mods","config","resourcepacks","shaderpacks") | ForEach-Object {
            $p = Join-Path $mcDir $_
            if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
        }

        Expand-Archive -Path $modpackZip -DestinationPath $mcDir -Force
        Remove-Item $modpackZip -ErrorAction SilentlyContinue

        Write-Host ""
        Write-Host " Mods instalados em $mcDir" -ForegroundColor Green
        Write-Host " Agora abra o SKLauncher, selecione Fabric 1.20.1 e" -ForegroundColor White
        Write-Host " configure o caminho do Java (cole com Ctrl+V se baixou pelo script)." -ForegroundColor White
    }

    Mostrar-Sucesso

    Write-Host "`n Pressione ENTER para sair..." -ForegroundColor Gray
    Read-Host
    break
}
