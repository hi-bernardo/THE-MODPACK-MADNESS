# ==============================================================================
# CONFIGURACOES E LINKS
# ==============================================================================
$ScriptRAW  = "https://raw.githubusercontent.com/hi-bernardo/THE-MODPACK-MADNESS/refs/heads/main/install_madness.ps1"
$LinkMrpack = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1/Modpack-Madness.mrpack"
$LinkZip    = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1/Modpack-Madness.zip"
$LinkPrism  = "https://github.com/PrismLauncher/PrismLauncher/releases/download/11.0.2/PrismLauncher-Windows-MSVC-Setup-11.0.2.exe"
$LinkSK     = "https://github.com/sklauncher/installer/releases/download/latest/SKlauncher_3.2.18_Setup.exe"
$LinkJava   = "https://download.oracle.com/graalvm/21/latest/graalvm-jdk-21_windows-x64_bin.zip"

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")] public static extern bool FlashWindow(IntPtr hwnd, bool bInvert);
        [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
        [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT lpRect);
        [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
        [DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
        [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
        public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    }
"@

# ==============================================================================
# PREPARACAO DE AMBIENTE (UAC, Janela e Anti-Travamento)
# ==============================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host " Privilegios de Administrador necessarios." -ForegroundColor Yellow
    Write-Host " Aguarde o UAC e clique em 'Sim'..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2

    if ($PSCommandPath) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    } else {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm $ScriptRAW | iex`"" -Verb RunAs
    }
    exit
}

$hStdIn = [Win32]::GetStdHandle(-10)
[uint]$mode = 0
[Win32]::GetConsoleMode($hStdIn, [ref]$mode) | Out-Null
$mode = $mode -band (-bnot 0x0040)
[Win32]::SetConsoleMode($hStdIn, $mode) | Out-Null

# Redimensionar e centralizar a janela do PowerShell
$largura = 78
$altura  = 30

$pshost  = $Host.UI.RawUI
$newSize = $pshost.WindowSize
$newSize.Width  = $largura
$newSize.Height = $altura

$pshost.BufferSize = New-Object System.Management.Automation.Host.Size($largura, $altura)
$pshost.WindowSize = $newSize

$hwnd = (Get-Process -Id $PID).MainWindowHandle
if ($hwnd -ne [IntPtr]::Zero) {
    $rect = New-Object Win32+RECT
    [Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    $width   = $rect.Right  - $rect.Left
    $height  = $rect.Bottom - $rect.Top
    $screenW = [Win32]::GetSystemMetrics(0)
    $screenH = [Win32]::GetSystemMetrics(1)
    $x = [math]::Max(0, ($screenW - $width)  / 2)
    $y = [math]::Max(0, ($screenH - $height) / 2)
    [Win32]::MoveWindow($hwnd, $x, $y, $width, $height, $true) | Out-Null
}

if (!(Test-Path "HKCU:\Software\Microsoft\Clipboard")) { New-Item -Path "HKCU:\Software\Microsoft\Clipboard" -Force | Out-Null }
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableClipboardHistory" -Value 1 -ErrorAction SilentlyContinue

# ==============================================================================
# FUNCOES DE INTERFACE E UX
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

function Ler-Opcao ([array]$OpcoesValidas) {
    while ($true) {
        $tecla = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character.ToString().ToLower()
        if ($tecla -eq 'm') { $tecla = 'v' }
        if ($OpcoesValidas -contains $tecla) { return $tecla }
    }
}

function Aguardar-Pulo ($Segundos) {
    $Host.UI.RawUI.FlushInputBuffer()
    $fim = (Get-Date).AddSeconds($Segundos)
    while ((Get-Date) -lt $fim) {
        $resta = [math]::Ceiling(($fim - (Get-Date)).TotalSeconds)
        Write-Host "`r Aguardando $resta s... (Espaco/Enter/Esc p/ pular) " -NoNewline -ForegroundColor DarkGray
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp").VirtualKeyCode
            if ($key -eq 13 -or $key -eq 27 -or $key -eq 32) { break }
        }
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`r                                                              `r" -NoNewline
}

function Chamar-Atencao {
    [System.Media.SystemSounds]::Exclamation.Play()
    $hwnd = (Get-Process -Id $PID).MainWindowHandle
    if ($hwnd -ne [IntPtr]::Zero) {
        [Win32]::ShowWindow($hwnd, 9)         | Out-Null
        [Win32]::SetForegroundWindow($hwnd)   | Out-Null
        [Win32]::FlashWindow($hwnd, $true)    | Out-Null
    }
    $wshell = New-Object -ComObject wscript.shell
    $wshell.AppActivate($PID) | Out-Null
}

function Baixar-Arquivo ($Url, $Destino, $Mensagem, $NomeProcesso) {
    Write-Host " $Mensagem" -ForegroundColor Cyan
    try {
        Import-Module BitsTransfer
        Start-BitsTransfer -Source $Url -Destination $Destino -DisplayName "Baixando: $NomeProcesso" -Description "Processando..." -Priority Foreground
    } catch {
        Write-Host " [Aviso] Usando modo basico (mais lento)..." -ForegroundColor DarkGray
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $Destino -UseBasicParsing
        $ProgressPreference = 'Continue'
    }
}

function Copiar-ParaClipboard ($Texto) {
    try { Set-Clipboard -Value $Texto -ErrorAction Stop; return $true }
    catch { return $false }
}

function Mostrar-AvisoFoco ($Mensagem) {
    Chamar-Atencao
    Clear-Host
    Write-Host "`n`n`n   ========================================================================" -ForegroundColor Red
    Write-Host "                              AVISO IMPORTANTE!                            " -ForegroundColor Yellow
    Write-Host "   ========================================================================" -ForegroundColor Red
    Write-Host "`n     $Mensagem`n" -ForegroundColor White
    Write-Host "   ========================================================================`n" -ForegroundColor Red
    Aguardar-Pulo 5
}

function Limpar-Temporarios {
    $lixos = @(
        "$env:TEMP\graalvm.zip",
        "$env:TEMP\PrismSetup.exe",
        "$env:TEMP\SKSetup.exe",
        "$env:TEMP\Modpack-Madness.zip",
        "$env:TEMP\Modpack-Madness.mrpack"
    )
    foreach ($lixo in $lixos) {
        if (Test-Path $lixo) { Remove-Item $lixo -Force -Recurse -ErrorAction SilentlyContinue }
    }
    Get-ChildItem -Path $env:TEMP -Filter "MadnessExtract_*" | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}

# ==============================================================================
# INICIO
# ==============================================================================
Limpar-Temporarios

$DiscoC = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$EspacoLivreGB = [math]::Round($DiscoC.FreeSpace / 1GB, 2)

if ($EspacoLivreGB -lt 3.0) {
    Mostrar-AvisoFoco "DISCO C: QUASE CHEIO! Apenas $EspacoLivreGB GB livres.`n     Libere pelo menos 3 GB para instalar os mods sem erros."
    exit
}

$javawPath = $null

while ($true) {

    # ----------------------------------------------------------
    # PASSO 1: JAVA
    # ----------------------------------------------------------
    Mostrar-Cabecalho
    Chamar-Atencao
    Write-Host " [ 1/3: JAVA 21 ]" -ForegroundColor Yellow
    Write-Host "`n O Minecraft 1.20+ exige Java 21.`n" -ForegroundColor White
    Write-Host " [ 1 ] Baixar e configurar." -ForegroundColor Green
    Write-Host " [ 2 ] Ja tenho." -ForegroundColor DarkGray
    Write-Host "`n Opcao: " -NoNewline -ForegroundColor Cyan

    $optJava = Ler-Opcao @('1','2')

    if ($optJava -eq '1') {
        Write-Host "`n"
        $javaDir   = "$env:LOCALAPPDATA\GraalVM"
        $javawPath = Get-ChildItem -Path $javaDir -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

        if ($javawPath) {
            Write-Host " [OK] Java 21 ja detectado!" -ForegroundColor Green
        } else {
            $javaZip = "$env:TEMP\graalvm.zip"
            Baixar-Arquivo $LinkJava $javaZip "Baixando GraalVM 21..." "JAVA 21"

            Write-Host " Extraindo..." -ForegroundColor Cyan
            if (Test-Path $javaDir) { Remove-Item "$javaDir\*" -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Path $javaDir -Force | Out-Null
            [System.IO.Compression.ZipFile]::ExtractToDirectory($javaZip, $javaDir)

            # Renomear pasta extraida para remover o "+" e evitar erro no jvm.cfg
            $pastaOriginal = Get-ChildItem -Path $javaDir -Directory | Select-Object -First 1
            if ($pastaOriginal) { Rename-Item -Path $pastaOriginal.FullName -NewName "jdk-21" }

            $javawPath = Get-ChildItem -Path $javaDir -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        }
        Chamar-Atencao
        Aguardar-Pulo 3
    }

    # ----------------------------------------------------------
    # PASSO 2: LAUNCHER
    # ----------------------------------------------------------
    Mostrar-Cabecalho
    Chamar-Atencao
    Write-Host " [ 2/3: LAUNCHER ]" -ForegroundColor Yellow
    Write-Host "`n [ 1 ] Prism Launcher (Conta Original)" -ForegroundColor Green
    Write-Host " [ 2 ] SKLauncher     (Sem Conta / Pirata)" -ForegroundColor Green
    Write-Host " [ V ] Voltar" -ForegroundColor Gray
    Write-Host "`n Opcao: " -NoNewline -ForegroundColor Cyan

    $optLauncher = Ler-Opcao @('1','2','v')
    if ($optLauncher -eq 'v') { continue }
    $LauncherType = if ($optLauncher -eq '1') { "PRISM" } else { "SKLAUNCHER" }

    # ----------------------------------------------------------
    # PASSO 3: INSTALACAO LAUNCHER
    # ----------------------------------------------------------
    Mostrar-Cabecalho
    Write-Host " [ 3/3: INSTALANDO $LauncherType ]" -ForegroundColor Yellow

    $launcherAchado  = $false
    $ModoManual      = $false
    $prismExeLocal   = "$env:LOCALAPPDATA\Programs\PrismLauncher\prismlauncher.exe"
    $skExeLocal      = "$env:LOCALAPPDATA\Programs\sklauncher\SKlauncher.exe"
    $PastaDownloads  = "$([Environment]::GetFolderPath('UserProfile'))\Downloads"
    $mcDir           = "$env:APPDATA\.minecraft"

    if ($LauncherType -eq "PRISM" -and (Test-Path $prismExeLocal)) {
        $launcherAchado = $true
    } elseif ($LauncherType -eq "SKLAUNCHER" -and (
        (Test-Path $skExeLocal) -or
        (Test-Path "$env:APPDATA\.minecraft\SKlauncher.exe") -or
        (Test-Path "$env:APPDATA\sklauncher")
    )) {
        $launcherAchado = $true
    }

    if ($launcherAchado) {
        Write-Host "`n $LauncherType detectado! Avancando..." -ForegroundColor Green
        Aguardar-Pulo 2
        $baixarLauncher = '1'
    } else {
        Chamar-Atencao
        Write-Host "`n Voce ja tem o $LauncherType em outra pasta (Versao Portable)?`n" -ForegroundColor White
        Write-Host " [ 1 ] Sim. (Vou gerenciar manualmente)" -ForegroundColor Green
        Write-Host " [ 2 ] Nao, instalar agora." -ForegroundColor DarkGray
        Write-Host " [ V ] Voltar" -ForegroundColor Gray
        Write-Host "`n Opcao: " -NoNewline -ForegroundColor Cyan

        $baixarLauncher = Ler-Opcao @('1','2','v')
        if ($baixarLauncher -eq 'v') { continue }

        if ($baixarLauncher -eq '1') {
            $ModoManual = $true
            Write-Host "`n Ok! Os arquivos do modpack serao salvos na sua pasta Downloads." -ForegroundColor Yellow
            Aguardar-Pulo 3
        }
    }

    if ($baixarLauncher -eq '2') {
        if ($LauncherType -eq "PRISM") {
            $prismSetup = "$env:TEMP\PrismSetup.exe"
            Baixar-Arquivo $LinkPrism $prismSetup "`nBaixando Prism Launcher..." "PRISM LAUNCHER"
            Mostrar-AvisoFoco "Na ultima tela, DESMARQUE a caixa 'Run Prism Launcher' e conclua!"
            Start-Process -FilePath $prismSetup -Wait
        } else {
            $skSetup = "$env:TEMP\SKSetup.exe"
            Baixar-Arquivo $LinkSK $skSetup "`nBaixando SKLauncher..." "SK LAUNCHER"
            Mostrar-AvisoFoco "Na ultima tela, DESMARQUE a caixa 'Executar SKlauncher' (se houver) e feche o instalador!"
            Start-Process -FilePath $skSetup -Wait
        }
        Chamar-Atencao
    }

    # ----------------------------------------------------------
    # PASSO 4: MODPACK
    # ----------------------------------------------------------
    Mostrar-Cabecalho
    Write-Host " [ INSTALANDO O MODPACK ]" -ForegroundColor Yellow

    if ($LauncherType -eq "PRISM") {
        $mrpackPath = if ($ModoManual) { "$PastaDownloads\Modpack-Madness.mrpack" } else { "$env:TEMP\Modpack-Madness.mrpack" }
        Baixar-Arquivo $LinkMrpack $mrpackPath "`nBaixando modpack (.mrpack)..." "MODPACK MADNESS"

        Write-Host " Abrindo modpack no Prism..." -ForegroundColor Cyan

        if ($ModoManual) {
            Start-Process cmd.exe -ArgumentList "/c start `"`" `"$mrpackPath`"" -WindowStyle Hidden
        } else {
            Start-Process cmd.exe -ArgumentList "/c start `"`" `"$prismExeLocal`" `"$mrpackPath`"" -WindowStyle Hidden
        }

    } elseif ($LauncherType -eq "SKLAUNCHER") {
        $modpackZip = "$env:TEMP\Modpack-Madness.zip"
        Baixar-Arquivo $LinkZip $modpackZip "`nBaixando mods (.zip)..." "MODS MADNESS"

        if ($ModoManual) {
            $mcDir = "$PastaDownloads\Modpack-Madness-Mods"
        }

        if (-not (Test-Path $mcDir)) { New-Item -ItemType Directory -Path $mcDir -Force | Out-Null }

        Write-Host " Extraindo arquivos..." -ForegroundColor Cyan
        $extractTemp = "$env:TEMP\MadnessExtract_$([guid]::NewGuid().Guid)"
        New-Item -ItemType Directory -Path $extractTemp -Force | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($modpackZip, $extractTemp)
        Copy-Item -Path "$extractTemp\*" -Destination $mcDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $extractTemp -Recurse -Force -ErrorAction SilentlyContinue
    }

    # ----------------------------------------------------------
    # TELA FINAL
    # ----------------------------------------------------------
    Clear-Host
    Mostrar-Cabecalho
    Chamar-Atencao

    Write-Host "==============================================================================" -ForegroundColor Green
    Write-Host "                    INSTALACAO CONCLUIDA COM SUCESSO!" -ForegroundColor Green
    Write-Host "==============================================================================`n" -ForegroundColor Green

    if ($LauncherType -eq "PRISM") {
        Write-Host " O Prism esta abrindo a janela de importacao." -ForegroundColor Cyan
        Write-Host " Clique em OK para confirmar e aguarde os mods baixarem.`n" -ForegroundColor White

        # Injetar JavaPath no instance.cfg apos o usuario confirmar a importacao
        if ($javawPath) {
            Write-Host " Depois de clicar OK no Prism, volte aqui e pressione ENTER." -ForegroundColor Yellow
            $Host.UI.RawUI.FlushInputBuffer()
            Read-Host

            $instancesDir = "$env:APPDATA\PrismLauncher\instances"
            $instancia = Get-ChildItem -Path $instancesDir -Directory -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

            if ($instancia) {
                $cfgPath = Join-Path $instancia.FullName "instance.cfg"
                if (Test-Path $cfgPath) {
                    $cfgContent = Get-Content $cfgPath -Raw
                    $cfgContent = $cfgContent -replace "JavaPath=.*",                "JavaPath=$javawPath"
                    $cfgContent = $cfgContent -replace "IgnoreJavaCompatibility=.*", "IgnoreJavaCompatibility=true"
                    Set-Content -Path $cfgPath -Value $cfgContent -Encoding UTF8
                    Write-Host "`n [OK] Java 21 configurado automaticamente na instancia!" -ForegroundColor Green
                }
            }

            Write-Host "`n Caminho do Java (copiado para a area de transferencia):" -ForegroundColor DarkGray
            Write-Host " $javawPath" -ForegroundColor DarkGray
            Copiar-ParaClipboard $javawPath | Out-Null
        } else {
            $Host.UI.RawUI.FlushInputBuffer()
            Read-Host "`n Pressione ENTER para fechar"
        }

    } else {
        # SKLauncher
        if ($javawPath) {
            Write-Host " Java 21 instalado. Configure o caminho abaixo no SKLauncher:" -ForegroundColor Cyan
            Write-Host " Configuracoes > Java > Java Executable`n" -ForegroundColor White
            Write-Host " $javawPath`n" -ForegroundColor DarkGray
            Copiar-ParaClipboard $javawPath | Out-Null
            Write-Host " (Caminho copiado para a area de transferencia. Use WIN+V para colar.)" -ForegroundColor Gray
        }

        $Host.UI.RawUI.FlushInputBuffer()
        Read-Host "`n Pressione ENTER para abrir o SKLauncher"

        $skCaminhos = @(
            "$env:LOCALAPPDATA\Programs\sklauncher\SKlauncher.exe",
            "$env:APPDATA\.minecraft\SKlauncher.exe",
            "$([Environment]::GetFolderPath('Desktop'))\SKlauncher.lnk"
        )
        foreach ($c in $skCaminhos) {
            if (Test-Path $c) { Start-Process $c; break }
        }

        if ($ModoManual) {
            Write-Host " Abrindo a pasta Downloads..." -ForegroundColor Gray
            Start-Process explorer.exe $PastaDownloads
        }
    }

    Limpar-Temporarios
    exit
}