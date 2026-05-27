# ==============================================================================
# CONFIGURAÇÕES E LINKS
# ==============================================================================
$ScriptRAW = "https://raw.githubusercontent.com/hi-bernardo/THE-MODPACK-MADNESS/refs/heads/main/install_madness.ps1"
$LinkMrpack = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1/Modpack-Madness.mrpack"
$LinkZip = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1/Modpack-Madness.zip"
$LinkPrism = "https://github.com/PrismLauncher/PrismLauncher/releases/download/11.0.2/PrismLauncher-Windows-MSVC-Setup-11.0.2.exe"
$LinkSK = "https://github.com/sklauncher/installer/releases/download/latest/SKlauncher_3.2.18_Setup.exe"
$LinkJava = "https://download.oracle.com/graalvm/21/latest/graalvm-jdk-21_windows-x64_bin.zip"

# Versão atual do modpack — utilizada pelo sistema de manifesto
$ModpackVersion = "1.0"

# ==============================================================================
# ENCAPSULAMENTO GLOBAL (TRY/CATCH)
# ==============================================================================
try {

    # ==============================================================================
    # TUNING DE REDE
    # ==============================================================================
    [System.Net.ServicePointManager]::DefaultConnectionLimit = 64
    [System.Net.ServicePointManager]::Expect100Continue = $false
    $tlsFlags = [System.Net.SecurityProtocolType]::Tls12
    try { $tlsFlags = $tlsFlags -bor [System.Net.SecurityProtocolType]::Tls13 } catch {}
    [System.Net.ServicePointManager]::SecurityProtocol = $tlsFlags

    # ==============================================================================
    # ENCODING FORCE
    # ==============================================================================
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    & chcp 65001 | Out-Null

    # ==============================================================================
    # ASSEMBLIES & CONSOLE GUARD
    # ==============================================================================
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.Windows.Forms

    if (-not ([System.Management.Automation.PSTypeName]'Win32').Type) {
        Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
        [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
        [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
        [DllImport("user32.dll")] public static extern bool FlashWindow(IntPtr hwnd, bool bInvert);
        [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
        [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT lpRect);
        [DllImport("user32.dll")] public static extern int  GetSystemMetrics(int nIndex);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
        [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
        
        public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    }
"@
    }

    # ==============================================================================
    # PREPARAÇÃO DE AMBIENTE
    # ==============================================================================
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host " Privilégios de Administrador necessários." -ForegroundColor Yellow
        Write-Host " Aguarde o UAC e clique em 'Sim'..." -ForegroundColor Cyan
        Start-Sleep -Seconds 1

        if ($PSCommandPath) {
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        }
        else {
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"Write-Host 'Baixando script...' -ForegroundColor Cyan; irm $ScriptRAW | iex`"" -Verb RunAs
        }
        exit
    }

    $hStdIn = [Win32]::GetStdHandle(-10)
    [uint32]$consoleMode = 0
    if ([Win32]::GetConsoleMode($hStdIn, [ref]$consoleMode)) {
        $consoleMode = $consoleMode -band (-bnot 0x0040)
        [Win32]::SetConsoleMode($hStdIn, $consoleMode) | Out-Null
    }

    $largura = 78
    $altura = 30
    try {
        $raw = $Host.UI.RawUI
        $minW = [math]::Min($largura, $raw.WindowSize.Width)
        $minH = [math]::Min($altura, $raw.WindowSize.Height)
        $raw.WindowSize = New-Object System.Management.Automation.Host.Size($minW, $minH)
        $raw.BufferSize = New-Object System.Management.Automation.Host.Size($largura, 9999)
        $raw.WindowSize = New-Object System.Management.Automation.Host.Size($largura, $altura)
    }
    catch {}

    $hwnd = (Get-Process -Id $PID).MainWindowHandle
    if ($hwnd -ne [IntPtr]::Zero) {
        $rect = New-Object Win32+RECT
        [Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
        $wndW = $rect.Right - $rect.Left
        $wndH = $rect.Bottom - $rect.Top
        $screenW = [Win32]::GetSystemMetrics(0)
        $screenH = [Win32]::GetSystemMetrics(1)
        $x = [math]::Max(0, [int](($screenW - $wndW) / 2))
        $y = [math]::Max(0, [int](($screenH - $wndH) / 2))
        [Win32]::MoveWindow($hwnd, $x, $y, $wndW, $wndH, $true) | Out-Null
    }

    try {
        if (!(Test-Path "HKCU:\Software\Microsoft\Clipboard")) {
            New-Item -Path "HKCU:\Software\Hardware\Clipboard" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableClipboardHistory" -Value 1 -ErrorAction SilentlyContinue
    }
    catch {}

    # ==============================================================================
    # FUNÇÕES DE INTERFACE E UX
    # ==============================================================================
    $Host.UI.RawUI.WindowTitle = "Instalador - THE MODPACK MADNESS"

    $script:SpinFrames = @('/', '|', '\', '-')
    $script:SpinIdx = 0

    function Write-Spinner ([string]$Mensagem) {
        $char = $script:SpinFrames[$script:SpinIdx % 4]
        Write-Host "`r [$char] $Mensagem" -NoNewline -ForegroundColor Cyan
        $script:SpinIdx++
    }

    function Show-Header {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host "        ____                                     _        _    ____       "    -ForegroundColor Green
        Write-Host "   ___ | __ ) _ __ __ _ _______   ___           | |      / \  | __ ) ___ "   -ForegroundColor Green
        Write-Host "  / _ \|  _ \| '__/ _` |_  / _ \ / _ \   _____  | |     / _ \ |  _ \/ __|"  -ForegroundColor Green
        Write-Host " | (_) | |_) | | | (_| |/ / (_) | (_) | |_____| | |___ / ___ \| |_) \__ \"  -ForegroundColor Green
        Write-Host "  \___/|____/|_|  \__,_/___\___/ \___/          |_____/_/   \_\____/|___/"   -ForegroundColor Green
        Write-Host ""
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host ""
    }
    function Get-FolderDialog ([string]$Mensagem) {
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = $Mensagem
        $dialog.ShowNewFolderButton = $true

        $form = New-Object System.Windows.Forms.Form
        $form.TopMost = $true
        $form.ShowInTaskbar = $false
        $form.WindowState = 'Minimized'
        $form.Show()
        $form.BringToFront()

        $result = $dialog.ShowDialog($form)
        $form.Dispose()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.SelectedPath
        }
        return $null
    }
    function Read-MenuOption ([array]$OpcoesValidas) {
        try { while ([System.Console]::KeyAvailable) { $null = [System.Console]::ReadKey($true) } } catch {}
        while ($true) {
            try {
                $tecla = [System.Console]::ReadKey($true).KeyChar.ToString().ToLower()
                if ($tecla -eq 'm') { $tecla = 'v' }
                if ($OpcoesValidas -contains $tecla) {
                    Write-Host $tecla -ForegroundColor Green
                    return $tecla
                }
            }
            catch {
                $inputStr = Read-Host
                $tecla = $inputStr.Trim().ToLower()
                if ($tecla -eq 'm') { $tecla = 'v' }
                if ($OpcoesValidas -contains $tecla) { return $tecla }
            }
        }
    }

    function Wait-SkipTimeout ([double]$Segundos) {
        try { while ([System.Console]::KeyAvailable) { $null = [System.Console]::ReadKey($true) } } catch {}
        $fim = (Get-Date).AddSeconds($Segundos)
        while ((Get-Date) -lt $fim) {
            $resta = [math]::Ceiling(($fim - (Get-Date)).TotalSeconds)
            Write-Host "`r Aguardando ${resta}s... (Espaço/Enter/Esc p/ pular) " -NoNewline -ForegroundColor DarkGray
            try {
                if ([System.Console]::KeyAvailable) {
                    $key = [System.Console]::ReadKey($true).Key
                    if ($key -in 'Enter', 'Escape', 'Spacebar') { break }
                }
            }
            catch {}
            Start-Sleep -Milliseconds 100
        }
        Write-Host "`r                                                              `r" -NoNewline
    }

    function Invoke-Attention {
        [System.Media.SystemSounds]::Exclamation.Play()
        $hwnd = (Get-Process -Id $PID).MainWindowHandle
        if ($hwnd -ne [IntPtr]::Zero) {
            [Win32]::ShowWindow($hwnd, 9)       | Out-Null
            [Win32]::SetForegroundWindow($hwnd) | Out-Null
            [Win32]::FlashWindow($hwnd, $true)  | Out-Null
        }
        try { (New-Object -ComObject wscript.shell).AppActivate($PID) | Out-Null } catch {}
    }

    function Set-MadnessClipboard ([string]$Texto) {
        try {
            [System.Windows.Forms.Clipboard]::SetText($Texto) | Out-Null
            return $true
        }
        catch {
            try { Set-Clipboard -Value $Texto -ErrorAction Stop; return $true } catch { return $false }
        }
    }

    function Show-FocusWarning ([string]$Mensagem) {
        Invoke-Attention
        Clear-Host
        Write-Host "`n`n`n   ========================================================================" -ForegroundColor Red
        Write-Host "                              AVISO IMPORTANTE!                            "  -ForegroundColor Yellow
        Write-Host "   ========================================================================" -ForegroundColor Red
        Write-Host "`n     $Mensagem`n"                                                            -ForegroundColor White
        Write-Host "   ========================================================================`n" -ForegroundColor Red
        Wait-SkipTimeout 3.5
    }

    # ==============================================================================
    # DOWNLOAD OTIMIZADO
    # ==============================================================================
    function Get-MadnessFile ([string]$Url, [string]$Destino, [string]$Mensagem, [string]$NomeProcesso, [int]$Tentativas = 3) {
        Write-Host "`n $Mensagem" -ForegroundColor Cyan

        $pastaDestino = Split-Path $Destino -Parent
        if ($pastaDestino -and -not (Test-Path $pastaDestino)) {
            New-Item -ItemType Directory -Path $pastaDestino -Force | Out-Null
        }

        $sucesso = $false

        for ($tentativa = 1; $tentativa -le $Tentativas; $tentativa++) {
            if ($tentativa -gt 1) {
                Write-Host "`n Retentando download ($tentativa/$Tentativas)..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }

            try {
                $req = [System.Net.HttpWebRequest]::Create($Url)
                $req.Method = "GET"
                $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
                $req.Timeout = 45000

                $resp = $req.GetResponse()
                $tamanho = $resp.ContentLength
                $streamIn = $resp.GetResponseStream()
            
                $streamOut = [System.IO.FileStream]::new($Destino, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 4MB, $false)

                $buffer = New-Object byte[] 4MB
                $baixado = [long]0
                $ultimaAtu = [DateTime]::Now

                while ($true) {
                    $lido = $streamIn.Read($buffer, 0, $buffer.Length)
                    if ($lido -eq 0) { break }
                    $streamOut.Write($buffer, 0, $lido)
                    $baixado += $lido

                    if (([DateTime]::Now - $ultimaAtu).TotalMilliseconds -ge 150) {
                        $mbBaixado = "{0:F1}" -f ($baixado / 1MB)
                        $mbTotal = if ($tamanho -gt 0) { "{0:F1} MB" -f ($tamanho / 1MB) } else { "? MB" }
                        Write-Spinner "Baixando $($NomeProcesso): $mbBaixado / $mbTotal..."
                        $ultimaAtu = [DateTime]::Now
                    }
                }

                $streamOut.Flush()
                $streamOut.Dispose()
                $streamIn.Dispose()
                $resp.Dispose()

                Write-Host "`r [OK] Download concluído: $NomeProcesso                          " -ForegroundColor Green
                if ((Get-Item $Destino).Length -lt 1024) { throw "Arquivo corrompido ou muito pequeno." }
                $sucesso = $true
                break
            }
            catch {
                if (Test-Path $Destino) { Remove-Item $Destino -Force -ErrorAction SilentlyContinue | Out-Null }
            }
        }

        if (-not $sucesso) {
            Write-Host "`n [ERRO] Não foi possível baixar o componente crítico: $NomeProcesso" -ForegroundColor Red
            Read-Host "Pressione ENTER para fechar..."
            exit 1
        }
    }

    function Clear-TempFiles {
        $lixos = @(
            "$env:TEMP\graalvm.zip",
            "$env:TEMP\PrismSetup.exe",
            "$env:TEMP\SKSetup.exe",
            "$env:TEMP\Modpack-Madness.zip",
            "$env:TEMP\Modpack-Madness.mrpack"
        )
        foreach ($lixo in $lixos) {
            if (Test-Path $lixo) {
                Remove-Item $lixo -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
            }
        }
        Get-ChildItem -Path $env:TEMP -Filter "MadnessExtract_*" -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # ==============================================================================
    # EXTRAÇÃO DE ALTO DESEMPENHO
    # ==============================================================================
    function Expand-MadnessArchive ([string]$ZipPath, [string]$DestinoPasta) {
        if (-not (Test-Path $DestinoPasta)) {
            New-Item -ItemType Directory -Path $DestinoPasta -Force | Out-Null
        }

        $zipStream = $null
        try {
            $zipStream = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        }
        catch {
            Write-Host "`n [ERRO CRÍTICO] O arquivo compactado está corrompido." -ForegroundColor Red
            Read-Host "Pressione ENTER para sair..."
            exit 1
        }

        $entradas = $zipStream.Entries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.FullName) -and -not $_.FullName.EndsWith("/") }
        $total = $entradas.Count
        $feitos = 0

        $contemPastaRaiz = $false
        if (($zipStream.Entries | Where-Object { $_.FullName.StartsWith("minecraft/") }).Count -gt 0) {
            $contemPastaRaiz = $true
        }
    
        $limiteAtualizacao = [math]::Max(1, [math]::Floor($total * 0.05))

        foreach ($entrada in $entradas) {
            $fullName = $entrada.FullName
        
            if ($contemPastaRaiz) {
                if ($fullName.StartsWith("minecraft/")) {
                    $fullName = $fullName.Substring(10)
                }
            }

            if ([string]::IsNullOrWhiteSpace($fullName)) { continue }

            $entryPath = $fullName.Replace("/", "\")
            $destinoFinalArquivo = Join-Path $DestinoPasta $entryPath
            $diretorioPai = Split-Path $destinoFinalArquivo -Parent

            if (-not (Test-Path $diretorioPai)) {
                New-Item -ItemType Directory -Path $diretorioPai -Force -ErrorAction SilentlyContinue | Out-Null
            }

            try {
                $streamIn = $entrada.Open()
                $streamOut = [System.IO.FileStream]::new($destinoFinalArquivo, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 81920, $false)
                $streamIn.CopyTo($streamOut, 81920)
                $streamOut.Dispose()
                $streamIn.Dispose()
                $feitos++
            }
            catch { }

            if ($feitos % $limiteAtualizacao -eq 0) {
                Write-Spinner "Extraindo e organizando modpack: $feitos de $total..."
            }
        }
        $zipStream.Dispose()
        Write-Host "`r [OK] Processamento e otimização concluídos! ($feitos arquivos)          " -ForegroundColor Green
    }

    # ==============================================================================
    # SEÇÃO DE LIMPEZA DE PASTAS MANIPULADAS (PRÉ-INSTALAÇÃO LIMPA)
    # ==============================================================================
    # Utilizada APENAS no fluxo de INSTALAÇÃO LIMPA ($AcaoModpack = "INSTALL").
    # Remove todas as pastas gerenciadas pelo modpack e reconstrói do zero.
    # NOTA: 'resourcepacks' foi removida desta lista — o mod Global Packs
    #       agora gerencia toda a infraestrutura visual internamente.
    function Clear-PreInstallation ([string]$DestinoPasta) {
        $pastasGerenciadas = @("mods", "shaderpacks", "config", "minecraft")
        foreach ($pasta in $pastasGerenciadas) {
            $caminho = Join-Path $DestinoPasta $pasta
            if (Test-Path $caminho) {
                Remove-Item -Path $caminho -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
        $optTxt = Join-Path $DestinoPasta "options.txt"
        if (Test-Path $optTxt) { Remove-Item -Path $optTxt -Force -ErrorAction SilentlyContinue | Out-Null }
    
        $cfgInvalido = Join-Path $DestinoPasta "instance.cfg"
        if (Test-Path $cfgInvalido) { Remove-Item -Path $cfgInvalido -Force -ErrorAction SilentlyContinue | Out-Null }
    }

    # ==============================================================================
    # LIMPEZA SELETIVA PARA ATUALIZAÇÃO (PURGE & SYNC)
    # ==============================================================================
    # Utilizada APENAS no fluxo de ATUALIZAÇÃO ($AcaoModpack = "UPDATE").
    # Remove cirurgicamente SOMENTE as pastas voláteis técnicas do modpack.
    # GARANTE preservação total de: saves, screenshots, options.txt, logs,
    # resourcepacks e quaisquer outros dados de personalização do usuário.
    function Clear-UpdatePurge ([string]$DestinoPasta) {
        $pastasVolateis = @("mods", "config", "shaderpacks")
        foreach ($pasta in $pastasVolateis) {
            $caminho = Join-Path $DestinoPasta $pasta
            if (Test-Path $caminho) {
                Write-Host "   -> Purgando: $pasta" -ForegroundColor DarkYellow
                Remove-Item -Path $caminho -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
        Write-Host " [OK] Purge seletivo concluído. Dados do usuário preservados." -ForegroundColor Green
    }

    function Clear-PrismPreInstallation {
        $instancesDir = "$env:APPDATA\PrismLauncher\instances"
        if (-not (Test-Path $instancesDir)) { return }

        $candidatas = Get-ChildItem -Path $instancesDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -imatch "madness|modpack" }

        if ($candidatas.Count -eq 0) { return }

        Write-Host " Removendo resíduos de instâncias antigas no Prism..." -ForegroundColor Yellow
        foreach ($c in $candidatas) {
            $alvo = $c.FullName
            try {
                Get-ChildItem -Path $alvo -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    if (-not $_.PSIsContainer) {
                        [System.IO.File]::Delete($_.FullName)
                    }
                }
                [System.IO.Directory]::Delete($alvo, $true)
            }
            catch {
                $tempRename = Join-Path $env:TEMP ("PrismTrash_" + (Get-Random))
                try {
                    Move-Item -Path $alvo -Destination $tempRename -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $tempRename -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                }
                catch { }
            }
        }
    }

    # ==============================================================================
    # CONTROLE DE VERSÃO LOCAL (SISTEMA DE MANIFESTO)
    # ==============================================================================
    # Arquivo '.madness_manifest.json' armazenado na raiz da pasta de dados do jogo.
    # Permite ao script detectar se o modpack já está instalado, qual versão
    # está presente e qual launcher foi utilizado na instalação anterior.
    function Get-MadnessManifest ([string]$BasePath) {
        $manifestPath = Join-Path $BasePath ".madness_manifest.json"
        if (Test-Path $manifestPath) {
            try {
                $json = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
                return $json
            }
            catch { return $null }
        }
        return $null
    }

    function Set-MadnessManifest ([string]$BasePath, [string]$Version, [string]$Launcher, [string]$Acao) {
        $manifestPath = Join-Path $BasePath ".madness_manifest.json"
        $agora = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

        # Se já existe um manifesto, preserva a data de instalação original
        $installedAt = $agora
        $existente = Get-MadnessManifest $BasePath
        if ($existente -and $existente.installed_at) {
            $installedAt = $existente.installed_at
        }

        $manifest = [ordered]@{
            version      = $Version
            launcher     = $Launcher
            installed_at = $installedAt
            updated_at   = $agora
            last_action  = $Acao
        }
        $json = $manifest | ConvertTo-Json -Depth 5
        Set-Content -Path $manifestPath -Value $json -Encoding UTF8 -NoNewline
    }

    function Show-ManifestStatus ([object]$Manifest) {
        if ($Manifest) {
            $ver = ($Manifest.version + "").PadRight(10)
            $lnc = ($Manifest.launcher + "").PadRight(15)
            $dt = ($Manifest.updated_at + "").PadRight(26)
            Write-Host ""
            Write-Host " ┌──────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
            Write-Host " │  MODPACK MADNESS DETECTADO NO SISTEMA                            │" -ForegroundColor Green
            Write-Host " │  Versão instalada: $ver                                    │" -ForegroundColor White
            Write-Host " │  Launcher: $lnc                                       │" -ForegroundColor White
            Write-Host " │  Última atualização: $dt                  │" -ForegroundColor DarkGray
            Write-Host " └──────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        }
        else {
            Write-Host ""
            Write-Host " [i] Nenhuma instalação anterior do Modpack Madness foi detectada." -ForegroundColor DarkGray
        }
    }

    # ==============================================================================
    # FUNÇÃO DE SINCRONIZAÇÃO E FOCO AVANÇADO (WIN32 API)
    # ==============================================================================
    function Set-PrismFocus {
        $proc = $null
        for ($i = 0; $i -lt 20; $i++) {
            $proc = Get-Process prism* -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
            if ($proc) { break }
            Start-Sleep 1
        }

        if (-not $proc) {
            return $false
        }

        $hwnd = $proc.MainWindowHandle
    
        $fgHwnd = [Win32]::GetForegroundWindow()
        $dummy = 0
        $fgThreadId = [Win32]::GetWindowThreadProcessId($fgHwnd, [ref]$dummy)
        $currentThreadId = [Win32]::GetCurrentThreadId()
    
        if ($fgThreadId -ne $currentThreadId) {
            [Win32]::AttachThreadInput($currentThreadId, $fgThreadId, $true) | Out-Null
        }
    
        if ([Win32]::IsIconic($hwnd)) {
            [Win32]::ShowWindowAsync($hwnd, 9) | Out-Null
        }
        else {
            [Win32]::ShowWindowAsync($hwnd, 5) | Out-Null
        }
    
        [Win32]::BringWindowToTop($hwnd) | Out-Null
        [Win32]::SetForegroundWindow($hwnd) | Out-Null
    
        if ($fgThreadId -ne $currentThreadId) {
            [Win32]::AttachThreadInput($currentThreadId, $fgThreadId, $false) | Out-Null
        }
    
        Start-Sleep -Seconds 1
        return $true
    }

    # ==============================================================================
    # INJEÇÃO E MERGE DE CONFIGURAÇÃO (SINCRO BLINDADA)
    # ==============================================================================
    function Update-InstanceCfg ([string]$JavaPath, [array]$instanciasAntigas) {
        if (-not $JavaPath) { return }
        # SOLUÇÃO DOS SEUS PROBLEMAS
        $InstancesDir = "$env:APPDATA\PrismLauncher\instances"
        $JavaPathPrism = $JavaPath.Replace('\', '/')
    
        $hwndConsole = (Get-Process -Id $PID).MainWindowHandle
        if ($hwndConsole -ne [IntPtr]::Zero) {
            [Win32]::ShowWindow($hwndConsole, 9) | Out-Null
            [Win32]::SetForegroundWindow($hwndConsole) | Out-Null
        }

        $mrpackPath = if ($ModoManual) { "$PastaDownloads\Modpack-Madness.mrpack" } else { "$env:TEMP\Modpack-Madness.mrpack" }

        Start-Process cmd.exe -ArgumentList "/c start `"`" `"$prismExeLocal`" `"$mrpackPath`"" -WindowStyle Hidden

        Write-Host "`n [Prism] A janela de importação do modpack foi aberta." -ForegroundColor Cyan
        Write-Host " -> Aplicando automação de confirmação na interface do Prism..." -ForegroundColor Yellow

        $jobCode = {
            $wsh = New-Object -ComObject WScript.Shell
            $timeout = 20
            $elapsed = 0
            while ($elapsed -lt $timeout) {
                $prismProcs = Get-Process prismlauncher -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne "" }
                if ($prismProcs) {
                    foreach ($p in $prismProcs) {
                        if ($wsh.AppActivate($p.Id)) {
                            Start-Sleep -Milliseconds 800
                            $wsh.SendKeys('{ENTER}')
                            Start-Sleep -Milliseconds 200
                            $wsh.SendKeys('{ENTER}')
                            return
                        }
                    }
                }
                Start-Sleep -Seconds 1
                $elapsed++
            }
        }
        Start-Job -ScriptBlock $jobCode | Out-Null

        $timeout = 300
        $elapsed = 0
        $cfgPath = $null

        while ($elapsed -lt $timeout) {
            $novas = Get-ChildItem -Path $InstancesDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notin $instanciasAntigas }

            if (-not $novas) {
                $novas = Get-ChildItem -Path $InstancesDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -imatch "madness|modpack" }
            }

            if ($novas) {
                $nova = $novas | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                $caminhoCfg = Join-Path $nova.FullName "instance.cfg"

                if (Test-Path $caminhoCfg) {
                    $cfgPath = $caminhoCfg
                    break
                }
            }
            Start-Sleep -Seconds 1
            $elapsed++
            $msgProgresso = "Procurando nova instância do jogo... (" + $elapsed + "s)"
            Write-Spinner $msgProgresso
        }

        if (-not $cfgPath) {
            Write-Host "`n [ERRO] Tempo esgotado. Nenhuma nova instância foi detectada." -ForegroundColor Red
            return
        }

        Write-Host "`n`n [!] Instância detectada! Encerrando o Prism para aplicar correções com segurança..." -ForegroundColor Yellow
        $prismProcesses = Get-Process -Name "prismlauncher" -ErrorAction SilentlyContinue
        if ($prismProcesses) {
            $prismProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }

        $arquivoLiberado = $false
        $tentativasLock = 0
        while (-not $arquivoLiberado -and $tentativasLock -lt 20) {
            try {
                $fileStream = [System.IO.File]::Open($cfgPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
                $fileStream.Close()
                $arquivoLiberado = $true
            }
            catch {
                $tentativasLock++
                Write-Spinner "Aguardando liberação completa do arquivo ($tentativasLock/20)..."
                Start-Sleep -Seconds 1
            }
        }

        if (-not $arquivoLiberado) {
            Write-Host "`n [ERRO] O arquivo instance.cfg continua travado por outro processo. Não foi possível editar." -ForegroundColor Red
            return
        }

        Write-Host "`n [OK] Arquivo liberado e pronto para edição. Aplicando configurações..." -ForegroundColor Cyan
        $conteudoAtual = Get-Content $cfgPath -Raw -Encoding UTF8

        $linhasOriginais = $conteudoAtual -split "`r?`n"
        $novasLinhas = [System.Collections.Generic.List[string]]::new()

        $OverridesMadness = [ordered]@{
            "OverrideJavaLocation"    = "true"
            "IgnoreJavaCompatibility" = "true"
            "AutomaticJava"           = "false"
            "JavaPath"                = $JavaPathPrism
        }
        $chavesInjetadas = @{}

        foreach ($linha in $linhasOriginais) {
            $linhaProcessada = $linha
            foreach ($chave in $OverridesMadness.Keys) {
                if ($linha -match "^$chave=") {
                    $linhaProcessada = "$chave=$($OverridesMadness[$chave])"
                    $chavesInjetadas[$chave] = $true
                }
            }
            $novasLinhas.Add($linhaProcessada) | Out-Null
        }

        $chavesFaltantes = $OverridesMadness.Keys | Where-Object { -not $chavesInjetadas[$_] }
        if ($chavesFaltantes) {
            $linhasComMerge = [System.Collections.Generic.List[string]]::new()
            foreach ($l in $novasLinhas) {
                $linhasComMerge.Add($l) | Out-Null
                if ($l.Trim() -eq "[General]") {
                    foreach ($cf in $chavesFaltantes) {
                        $linhasComMerge.Add("$cf=$($OverridesMadness[$cf])") | Out-Null
                    }
                }
            }
            $novasLinhas = $linhasComMerge
        }

        $cfgFinal = ($novasLinhas -join "`r`n").TrimEnd() + "`r`n"
        try {
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($cfgPath, $cfgFinal, $utf8NoBom)
            Write-Host " ========================================================" -ForegroundColor Green
            Write-Host "  SUCESSO: CONFIGURAÇÕES GRAVADAS COM SUCESSO!" -ForegroundColor Green
            Write-Host " ========================================================" -ForegroundColor Green
            Write-Host " -> As barras '/' e Overrides de Java foram consolidados." -ForegroundColor White
            Invoke-Attention
            Start-Sleep -Seconds 2
        }
        catch {
            Write-Host "`n [ERRO CRÍTICO] Falha ao gravar dados no arquivo: $($_.Exception.Message)" -ForegroundColor Red
            Start-Sleep -Seconds 5
        }

        if (-not $ModoManual -and (Test-Path $prismExeLocal)) {
            Write-Host " -> Reiniciando Prism Launcher com as novas configurações..." -ForegroundColor Cyan

            Stop-Process -Name "prismlauncher" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Process cmd.exe -ArgumentList "/c start `"`" `"$prismExeLocal`"" -WindowStyle Hidden
        }
    }

    # ==============================================================================
    # PROFILES SKLAUNCHER (SERIALIZAÇÃO JSON NATIVA SEGURA)
    # ==============================================================================
    function New-LauncherProfile ([string]$McDir, [string]$JavaPath) {
        $profilePath = Join-Path $McDir "launcher_profiles.json"
        $profileId = [guid]::NewGuid().ToString("N")
        $agora = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

        $jsonStructure = [ordered]@{
            profiles        = [ordered]@{
                "$profileId" = [ordered]@{
                    name          = "ModpackMadness"
                    lastVersionId = "fabric-loader-0.19.2-1.20.1"
                    type          = "custom"
                    icon          = "Grass"
                    created       = $agora
                    lastUsed      = $agora
                }
            }
            selectedProfile = $profileId
            settings        = [ordered]@{
                profileSorting = "byName"
            }
            version         = 6
        }

        if ($JavaPath) {
            $normalizedJavaPath = $JavaPath.Replace('/', '\')
            $jsonStructure.profiles."$profileId".Add("javaDir", $normalizedJavaPath)
        }

        $json = $jsonStructure | ConvertTo-Json -Depth 10
        Set-Content -Path $profilePath -Value $json -Encoding UTF8 -NoNewline
    }

    # ==============================================================================
    # DETECÇÃO DE SKLAUNCHER OTIMIZADA
    # ==============================================================================
    function Find-SKLauncher {
        $caminhosDiretos = @(
            "$env:LOCALAPPDATA\Programs\SKLauncher\SKLauncher.exe",
            "$env:LOCALAPPDATA\Programs\sklauncher\SKLauncher.exe",
            "$env:LOCALAPPDATA\Programs\sklauncher\sklauncher.exe",
            "$env:LOCALAPPDATA\SKLauncher\SKLauncher.exe",
            "$env:APPDATA\SKLauncher\SKLauncher.exe",
            "$env:ProgramFiles\SKLauncher\SKLauncher.exe",
            "${env:ProgramFiles(x86)}\SKLauncher\SKLauncher.exe",
            "$env:APPDATA\.minecraft\sklauncher\SKlauncher.exe",
            "$env:APPDATA\.minecraft\SKlauncher.exe"
        )

        foreach ($caminho in $caminhosDiretos) {
            if (Test-Path $caminho -PathType Leaf) {
                return $caminho
            }
        }

        $startMenuRoots = @(
            "$env:APPDATA\Microsoft\Windows\Start Menu",
            "$env:ProgramData\Microsoft\Windows\Start Menu"
        )

        foreach ($root in $startMenuRoots) {
            if (Test-Path $root) {
                $shortcuts = Get-ChildItem -Path $root -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue
                foreach ($lnk in $shortcuts) {
                
                    if ($lnk.Name -imatch "sklauncher" -and $lnk.Name -notmatch "(?i)uninstall|desinstalar|remove") {
                        try {
                            $wshShell = New-Object -ComObject WScript.Shell
                            $target = $wshShell.CreateShortcut($lnk.FullName).TargetPath
                        
                            if ((Test-Path $target -PathType Leaf) -and ($target -notmatch "(?i)javaw\.exe$|unins.*\.exe$|uninstall.*\.exe$")) {
                                return $target
                            }
                        }
                        catch {}
                    }
                }
            }
        }

        return $null
    }

    # ==============================================================================
    # EXECUÇÃO PRINCIPAL
    # ==============================================================================
    Clear-TempFiles

    # ──────────────────────────────────────────────────────────────────────────────
    # VERIFICAÇÃO DE ESPAÇO EM DISCO
    # ──────────────────────────────────────────────────────────────────────────────
    try { $DiscoC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop }
    catch { $DiscoC = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" }

    $EspacoLivreGB = [math]::Round($DiscoC.FreeSpace / 1GB, 2)
    if ($EspacoLivreGB -lt 3.0) {
        Show-FocusWarning "DISCO C: DETERMINADO COMO CHEIO! Libere espaço (Mínimo 3GB)."
        exit
    }

    # ──────────────────────────────────────────────────────────────────────────────
    # ETAPA 1/3: DETECÇÃO E INSTALAÇÃO DO RUNTIME JAVA
    # ──────────────────────────────────────────────────────────────────────────────
    Write-Host " Verificando runtime Java..." -ForegroundColor Cyan
    $javaJob = Start-Job -ScriptBlock {
        $graalDir = "$env:LOCALAPPDATA\GraalVM"
        if ([System.IO.Directory]::Exists($graalDir)) {
            $found = Get-ChildItem -Path $graalDir -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
            if ($found) { return $found }
        }
        return $null
    }

    while ($javaJob.State -eq "Running") {
        Write-Spinner "Localizando Java/GraalVM no sistema..."
        Start-Sleep -Milliseconds 100
    }

    $javawPath = Receive-Job -Job $javaJob
    Remove-Job -Job $javaJob

    if ($javawPath) {
        $javawPath = $javawPath.Replace('\', '/')

        Show-Header
        Write-Host " [ 1/3: VERIFICANDO AMBIENTE JAVA ]" -ForegroundColor Yellow
        Write-Host " GraalVM de alta performance localizado e ativo!" -ForegroundColor Green
        Write-Host " Local: $javawPath" -ForegroundColor White
        Write-Host ""
        Set-MadnessClipboard $javawPath | Out-Null
        Wait-SkipTimeout 1
    }
    else {
        Show-Header
        Write-Host " [ 1/3: CONFIGURAÇÃO DE RUNTIME JAVA ]" -ForegroundColor Yellow
        Write-Host "`n O Minecraft 1.20+ exige Java moderno e otimizado para rodar sem travamentos." -ForegroundColor White
        Write-Host " Instala o ambiente isolado GraalVM 21 automático para performance..." -ForegroundColor Cyan
    
        $javaDir = "$env:LOCALAPPDATA\GraalVM"
        $javaZip = "$env:TEMP\graalvm.zip"
        Get-MadnessFile $LinkJava $javaZip "Buscando pacotes binários do GraalVM 21 (~300MB)..." "JAVA 21"
    
        if (Test-Path $javaDir) { Remove-Item "$javaDir\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null }
        New-Item -ItemType Directory -Path $javaDir -Force | Out-Null
    
        Expand-MadnessArchive $javaZip $javaDir
        $pastaOriginal = Get-ChildItem -Path $javaDir -Directory | Select-Object -First 1
        if ($pastaOriginal) { Rename-Item -Path $pastaOriginal.FullName -NewName "jdk-21" -ErrorAction SilentlyContinue }
    
        $javawPath = Get-ChildItem -Path $javaDir -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    
        $javawPath = $javawPath.Replace('\', '/')
        Set-MadnessClipboard $javawPath | Out-Null
    }

    # ──────────────────────────────────────────────────────────────────────────────
    # ETAPA 2/3: ESCOLHA DO LAUNCHER
    # ──────────────────────────────────────────────────────────────────────────────
    while ($true) {
        Show-Header
        Write-Host " [ 2/3: ESCOLHA DO GERENCIADOR / LAUNCHER ]" -ForegroundColor Yellow
        Write-Host "`n Selecione a sua plataforma de execução de preferência:" -ForegroundColor White
        Write-Host " [ 0 ] URGENTE!!! Remover mod problemático!" -ForegroundColor Red
        Write-Host " [ 1 ] Prism Launcher (Contas Originais / Microsoft)" -ForegroundColor Green
        Write-Host " [ 2 ] SKLauncher     (Contas Offline / Alternativas)" -ForegroundColor Green
        Write-Host " [ V ] Voltar" -ForegroundColor Gray
        Write-Host "`n Opção: " -NoNewline -ForegroundColor Cyan

        $optLauncher = Read-MenuOption @('0', '1', '2', 'v')
        if ($optLauncher -eq 'v') { continue }

        if ($optLauncher -eq '0') {
            Show-Header
            Write-Host " [ REMOVENDO MOD PROBLEMÁTICO ]" -ForegroundColor Red
            Write-Host "`n Procurando [fabric]ctov-3.4.14.jar nos diretórios do modpack..." -ForegroundColor Cyan
            Write-Host ""

            $modName = "[fabric]ctov-3.4.14.jar"
            $encontrados = @()

            $prismInstances = "$env:APPDATA\PrismLauncher\instances"
            if (Test-Path $prismInstances) {
                $encontrados += Get-ChildItem -Path $prismInstances -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq $modName } |
                Select-Object -ExpandProperty FullName
            }

            $skModPath = "$env:APPDATA\.minecraft\mods\$modName"
            if (Test-Path -LiteralPath $skModPath) {
                $encontrados += $skModPath
            }

            if ($encontrados.Count -eq 0) {
                Write-Host " [OK] Mod não encontrado. Já foi removido ou não esta instalado." -ForegroundColor Green
            }
            else {
                $removidos = 0
                foreach ($arquivo in $encontrados) {
                    try {
                        Remove-Item -LiteralPath $arquivo -Force -ErrorAction Stop
                        $removidos++
                        Write-Host " [OK] Removido: $arquivo" -ForegroundColor Green
                    }
                    catch {
                        Write-Host " [ERRO] Não foi possível remover: $arquivo" -ForegroundColor Red
                    }
                }
                Write-Host ""
                Write-Host " $removidos arquivo(s) removido(s) com sucesso!" -ForegroundColor Green
            }

            Write-Host "`n Pressione qualquer tecla para fechar..." -ForegroundColor DarkGray
            $null = [System.Console]::ReadKey($true)
            exit
        }

        $LauncherType = if ($optLauncher -eq '1') { "PRISM" } else { "SKLAUNCHER" }
        break
    }

    # ──────────────────────────────────────────────────────────────────────────────
    # ETAPA 3/3: VERIFICAÇÃO DE DIRETÓRIOS E COMPONENTES
    # ──────────────────────────────────────────────────────────────────────────────
    Show-Header
    Write-Host " [ 3/3: VERIFICANDO DIRETÓRIOS E COMPONENTES DO $LauncherType ]" -ForegroundColor Yellow

    $launcherAchado = $false
    $ModoManual = $false
    $prismExeLocal = "$env:LOCALAPPDATA\Programs\PrismLauncher\prismlauncher.exe"
    $PastaDownloads = "$([Environment]::GetFolderPath('UserProfile'))\Downloads"
    $mcDir = "$env:APPDATA\.minecraft"
    $skExeValidado = $null

    if ($LauncherType -eq "PRISM") {
        if (Test-Path $prismExeLocal) { $launcherAchado = $true }
    }
    elseif ($LauncherType -eq "SKLAUNCHER") {
        $skExeValidado = Find-SKLauncher
        if ($skExeValidado) { $launcherAchado = $true }
    }

    if ($launcherAchado) {
        Write-Host "`n [OK] Executável do $LauncherType localizado!" -ForegroundColor Green
        Start-Sleep -Seconds 1
        $baixarLauncher = '2'
    }
    else {
        Write-Host "`n O gerenciador $LauncherType não foi encontrado." -ForegroundColor White
        Write-Host " [ 1 ] Realizar instalação limpa do zero." -ForegroundColor Green
        Write-Host " [ 2 ] Ignorar (Utilizo versão Portable ou local)." -ForegroundColor DarkGray
        Write-Host "`n Opção: " -NoNewline -ForegroundColor Cyan

        $baixarLauncher = Read-MenuOption @('1', '2')
        if ($baixarLauncher -eq '2') {
            $ModoManual = $true
            Write-Host "`n [!] Modo customizado ativo. Arquivos salvos na pasta Downloads." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }

    if ($baixarLauncher -eq '1') {
        $InstallDir = $null
        
        Write-Host "`n [ PREFERÊNCIA DE DIRETÓRIO ]" -ForegroundColor Yellow
        Write-Host " [ 1 ] Instalar no local padrão" -ForegroundColor Green
        Write-Host " [ 2 ] Escolher pasta personalizada" -ForegroundColor DarkGray
        Write-Host "`n Opção: " -NoNewline -ForegroundColor Cyan
        
        $optLocal = Read-MenuOption @('1', '2')
        
        if ($optLocal -eq '2') {
            Write-Host "`n -> Selecione a pasta na janela que acabou de abrir..." -ForegroundColor Yellow
            $InstallDir = Get-FolderDialog "Selecione onde deseja instalar o $LauncherType"
            if (-not $InstallDir) {
                Write-Host " Nenhuma pasta selecionada. Usando local padrão do sistema." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }

        if ($LauncherType -eq "PRISM") {
            $prismSetup = "$env:TEMP\PrismSetup.exe"
            Get-MadnessFile $LinkPrism $prismSetup "Baixando instalador oficial do Prism Launcher..." "PRISM SETUP"
            
            Write-Host " -> Instalando Prism Launcher silenciosamente..." -ForegroundColor Cyan
            
            $argsCmd = "/S"
            if ($InstallDir) { $argsCmd += " /D=$InstallDir" }
            else { $InstallDir = "$env:LOCALAPPDATA\Programs\PrismLauncher" }
            
            Start-Process -FilePath $prismSetup -ArgumentList $argsCmd -Wait -NoNewWindow
            
            $prismExeLocal = Join-Path $InstallDir "prismlauncher.exe"
        }
        else {
            $skSetup = "$env:TEMP\SKSetup.exe"
            Get-MadnessFile $LinkSK $skSetup "Baixando instalador oficial do SKLauncher..." "SK LAUNCHER SETUP"
            
            Write-Host " -> Instalando SKLauncher silenciosamente..." -ForegroundColor Cyan
            
            $argsCmd = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
            if ($InstallDir) { $argsCmd += " /DIR=`"$InstallDir`"" }
            else { $InstallDir = "$env:LOCALAPPDATA\Programs\SKLauncher" }

            Start-Process -FilePath $skSetup -ArgumentList $argsCmd -Wait -NoNewWindow
            
            $skExeValidado = Join-Path $InstallDir "SKLauncher.exe"
        }
    }

    # ==============================================================================
    # AJUSTE DE DIRETÓRIO PARA MODO MANUAL (SKLauncher)
    # ==============================================================================
    # Determina o $mcDir final ANTES do menu de ação para que a leitura do
    # manifesto aponte para o caminho correto independente do modo.
    if ($LauncherType -ne "PRISM" -and $ModoManual) {
        $mcDir = Join-Path $PastaDownloads "Modpack-Madness-Mods"
    }

    # ==============================================================================
    # MENU DINÂMICO: INSTALAR vs ATUALIZAR ($AcaoModpack)
    # ==============================================================================
    # Determina a base do manifesto conforme o launcher selecionado.
    # - Prism: manifesto fica na raiz de dados do PrismLauncher
    # - SKLauncher: manifesto fica dentro do diretório .minecraft (ou manual)
    $manifestBase = if ($LauncherType -eq "PRISM") {
        "$env:APPDATA\PrismLauncher"
    }
    else {
        $mcDir
    }

    $manifestAtual = Get-MadnessManifest $manifestBase

    Show-Header
    Write-Host " [ MODO DE OPERAÇÃO ]" -ForegroundColor Yellow
    Show-ManifestStatus $manifestAtual
    Write-Host ""
    Write-Host " [ 1 ] Instalação Limpa (Do Zero)" -ForegroundColor Green
    Write-Host "       Apaga tudo e reinstala completamente." -ForegroundColor DarkGray
    Write-Host " [ 2 ] Atualizar Modpack (Purge & Sync)" -ForegroundColor Cyan
    Write-Host "       Mantém saves, screenshots e options.txt." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " Opção: " -NoNewline -ForegroundColor Cyan

    $optAcao = Read-MenuOption @('1', '2')
    $AcaoModpack = if ($optAcao -eq '1') { "INSTALL" } else { "UPDATE" }

    # ==============================================================================
    # DEPLOY FINAL: APLICANDO MODPACK MADNESS
    # ==============================================================================
    Show-Header
    if ($AcaoModpack -eq "INSTALL") {
        Write-Host " [ DEPLOY: INSTALAÇÃO LIMPA DO MODPACK MADNESS ]" -ForegroundColor Yellow
    }
    else {
        Write-Host " [ DEPLOY: ATUALIZAÇÃO DO MODPACK MADNESS (PURGE & SYNC) ]" -ForegroundColor Yellow
    }

    # ──────────────────────────────────────────────────────────────────────────────
    # FLUXO PRISM LAUNCHER (.mrpack)
    # ──────────────────────────────────────────────────────────────────────────────
    # NOTA TÉCNICA: O importador nativo do Prism Launcher SEMPRE cria uma nova
    # instância ao processar um arquivo .mrpack. Não existe API ou flag para
    # "atualizar in-place" uma instância existente. Por isso, tanto no modo
    # INSTALL quanto UPDATE, o script baixa o .mrpack e aciona a automação
    # de GUI via SendKeys/WScript.Shell para injetar a nova instância.
    #
    # No modo UPDATE, o script identifica a instância anterior, importa a nova,
    # e migra automaticamente saves, screenshots e options.txt antes de limpar
    # a instância antiga.
    # ──────────────────────────────────────────────────────────────────────────────
    if ($LauncherType -eq "PRISM") {
        $instancesDir = "$env:APPDATA\PrismLauncher\instances"

        # Variável para armazenar referência da instância antiga (usada na migração)
        $instanciaAntigaPrism = $null

        if ($AcaoModpack -eq "INSTALL") {
            # INSTALAÇÃO LIMPA: remove todas as instâncias Madness anteriores
            Clear-PrismPreInstallation
        }
        else {
            # ATUALIZAÇÃO: preserva a instância mais recente para migrar dados do usuário
            if (Test-Path $instancesDir) {
                $instanciaAntigaPrism = Get-ChildItem -Path $instancesDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -imatch "madness|modpack" } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            }

            if ($instanciaAntigaPrism) {
                Write-Host " [i] Instância anterior detectada: $($instanciaAntigaPrism.Name)" -ForegroundColor DarkGray
                Write-Host " [i] Saves e screenshots serão migrados automaticamente." -ForegroundColor DarkGray
            }
        }

        # Snapshot das instâncias existentes (para detectar a nova após importação)
        $instanciasAntigas = @()
        if (Test-Path $instancesDir) {
            $instanciasAntigas = Get-ChildItem -Path $instancesDir -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        }

        # Download do pacote .mrpack
        $mrpackPath = "$env:TEMP\Modpack-Madness.mrpack"
        if ($ModoManual) { $mrpackPath = "$PastaDownloads\Modpack-Madness.mrpack" }
        Get-MadnessFile $LinkMrpack $mrpackPath "Baixando pacote estrutural do modpack (.mrpack)..." "PACK PRISM"

        # Importação via automação de GUI + patching de instance.cfg com Java
        Update-InstanceCfg $javawPath $instanciasAntigas

        # ── MIGRAÇÃO DE DADOS DO USUÁRIO (APENAS NO MODO ATUALIZAR) ──
        if ($AcaoModpack -eq "UPDATE" -and $instanciaAntigaPrism) {
            Write-Host "`n [Prism] Iniciando migração de dados do usuário..." -ForegroundColor Cyan

            # Localiza a instância recém-criada (não estava no snapshot anterior)
            $novaInstanciaPrism = $null
            if (Test-Path $instancesDir) {
                $novaInstanciaPrism = Get-ChildItem -Path $instancesDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notin $instanciasAntigas } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            }

            if ($novaInstanciaPrism) {
                $baseOrigem = Join-Path $instanciaAntigaPrism.FullName ".minecraft"
                $baseDestino = Join-Path $novaInstanciaPrism.FullName ".minecraft"

                # Migrar saves (mundos do usuário)
                $savesOrigem = Join-Path $baseOrigem "saves"
                if (Test-Path $savesOrigem) {
                    $savesDestino = Join-Path $baseDestino "saves"
                    if (-not (Test-Path $savesDestino)) { New-Item -ItemType Directory -Path $savesDestino -Force | Out-Null }
                    Copy-Item -Path "$savesOrigem\*" -Destination $savesDestino -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK] Mundos (saves) migrados com sucesso!" -ForegroundColor Green
                }

                # Migrar screenshots
                $screensOrigem = Join-Path $baseOrigem "screenshots"
                if (Test-Path $screensOrigem) {
                    $screensDestino = Join-Path $baseDestino "screenshots"
                    if (-not (Test-Path $screensDestino)) { New-Item -ItemType Directory -Path $screensDestino -Force | Out-Null }
                    Copy-Item -Path "$screensOrigem\*" -Destination $screensDestino -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK] Screenshots migrados com sucesso!" -ForegroundColor Green
                }

                # Migrar options.txt (mapeamento de teclas e configurações visuais)
                $optOrigem = Join-Path $baseOrigem "options.txt"
                if (Test-Path $optOrigem) {
                    $optDestino = Join-Path $baseDestino "options.txt"
                    Copy-Item -Path $optOrigem -Destination $optDestino -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK] Configurações de teclas (options.txt) migradas!" -ForegroundColor Green
                }

                Write-Host " [OK] Migração completa. Limpando instância anterior..." -ForegroundColor Cyan
            }
            else {
                Write-Host " [AVISO] Não foi possível localizar a nova instância para migração." -ForegroundColor Yellow
                Write-Host "         Os saves da instância anterior serão preservados." -ForegroundColor DarkGray
            }

            # Remove a instância antiga específica (não usa Clear-PrismPreInstallation
            # para evitar deletar a instância recém-criada que também contém "madness")
            if ($novaInstanciaPrism) {
                $alvoAntigo = $instanciaAntigaPrism.FullName
                try {
                    Remove-Item -Path $alvoAntigo -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                    Write-Host " [OK] Instância anterior removida: $($instanciaAntigaPrism.Name)" -ForegroundColor Green
                }
                catch {
                    Write-Host " [AVISO] Não foi possível remover a instância anterior automaticamente." -ForegroundColor Yellow
                }
            }
        }

        # Grava/atualiza manifesto na raiz do PrismLauncher
        Set-MadnessManifest "$env:APPDATA\PrismLauncher" $ModpackVersion "PRISM" $AcaoModpack
    }

    # ──────────────────────────────────────────────────────────────────────────────
    # FLUXO SKLAUNCHER / MODO MANUAL (.zip)
    # ──────────────────────────────────────────────────────────────────────────────
    if ($LauncherType -ne "PRISM") {
        $modpackZip = "$env:TEMP\Modpack-Madness.zip"
        Get-MadnessFile $LinkZip $modpackZip "Baixando arquivos de modificações e texturas (.zip)..." "ZIP DATA"

        if ($AcaoModpack -eq "INSTALL") {
            # ── INSTALAÇÃO LIMPA: apaga tudo e reconstrói do zero ──
            Write-Host " Limpeza completa dos diretórios de destino..." -ForegroundColor Cyan
            Clear-PreInstallation $mcDir

            Write-Host " Executando extração direta..." -ForegroundColor Cyan
            Expand-MadnessArchive $modpackZip $mcDir

            Write-Host " Gerando perfis do inicializador (launcher_profiles.json)..." -ForegroundColor Cyan
            New-LauncherProfile $mcDir $javawPath
        }
        else {
            # ── ATUALIZAÇÃO: purge cirúrgico + re-deploy ──
            # Faz backup do options.txt antes da extração, pois o .zip pode
            # conter um options.txt padrão que sobrescreveria as teclas do usuário.
            $optBackupContent = $null
            $optPath = Join-Path $mcDir "options.txt"
            if (Test-Path $optPath) {
                $optBackupContent = Get-Content $optPath -Raw -Encoding UTF8
                Write-Host " [i] Backup de options.txt realizado." -ForegroundColor DarkGray
            }

            Write-Host " Purge seletivo (preservando saves/screenshots/options)..." -ForegroundColor Cyan
            Clear-UpdatePurge $mcDir

            Write-Host " Executando extração dos novos dados..." -ForegroundColor Cyan
            Expand-MadnessArchive $modpackZip $mcDir

            # Restaura options.txt do backup (protege contra sobrescrita pelo .zip)
            if ($optBackupContent) {
                Set-Content -Path $optPath -Value $optBackupContent -Encoding UTF8 -NoNewline
                Write-Host " [OK] options.txt restaurado do backup (teclas preservadas)." -ForegroundColor Green
            }

            # NÃO regenera launcher_profiles.json — preserva perfil existente do usuário
        }

        # Limpeza de resíduos de extração (instance.cfg pode vir dentro do .zip)
        $cfgResiduo = Join-Path $mcDir "instance.cfg"
        if (Test-Path $cfgResiduo) { Remove-Item $cfgResiduo -Force -ErrorAction SilentlyContinue | Out-Null }

        # Grava/atualiza manifesto no diretório do jogo
        Set-MadnessManifest $mcDir $ModpackVersion "SKLAUNCHER" $AcaoModpack
    }

    # ==============================================================================
    # FINALIZAÇÃO SEGURA E INVOCAÇÃO DOS PROCESSOS
    # ==============================================================================
    Clear-Host
    Show-Header

    if ($AcaoModpack -eq "INSTALL") {
        Write-Host "==============================================================================" -ForegroundColor Green
        Write-Host "                    INSTALAÇÃO CONCLUÍDA COM SUCESSO!" -ForegroundColor Green
        Write-Host "==============================================================================`n" -ForegroundColor Green
    }
    else {
        Write-Host "==============================================================================" -ForegroundColor Green
        Write-Host "                   ATUALIZAÇÃO CONCLUÍDA COM SUCESSO!" -ForegroundColor Green
        Write-Host "==============================================================================`n" -ForegroundColor Green
        Write-Host " Seus mundos (saves), screenshots e teclas foram preservados." -ForegroundColor Cyan
        Write-Host ""
    }

    if ($javawPath) {
        $visualJavaPath = $javawPath.Replace('/', '\')
        Set-MadnessClipboard $visualJavaPath | Out-Null
        Write-Host " Caminho do Java 21 copiado para a Área de Transferência!" -ForegroundColor Cyan
        Write-Host " Use WIN + V se precisar colar manualmente nas configurações.`n" -ForegroundColor DarkGray
    }

    if ($LauncherType -ne "PRISM") {
        Write-Host " Modpack pronto para execução no SKLauncher." -ForegroundColor Green
        Write-Host " Buscando atalho de inicialização..." -ForegroundColor DarkGray

        $skToLaunch = $null
        
        $atalhosPadrao = @(
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\SKlauncher\SKlauncher.lnk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\SKlauncher\SKlauncher.lnk",
            "$([Environment]::GetFolderPath('Desktop'))\SKlauncher.lnk"
        )

        foreach ($atalho in $atalhosPadrao) {
            if (Test-Path $atalho) {
                $skToLaunch = $atalho
                break
            }
        }

        if (-not $skToLaunch) {
            $skToLaunch = Get-ChildItem -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -Filter "*SKlauncher*.lnk" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "(?i)uninstall|desinstalar" } |
            Select-Object -First 1 -ExpandProperty FullName
        }

        if (-not $skToLaunch -and $ModoManual) {
            $skToLaunch = Get-ChildItem -Path $PastaDownloads -Filter "*SKlauncher*.exe" -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        }

        if ($skToLaunch -and (Test-Path $skToLaunch)) {
            Write-Host " -> Inicializador validado!" -ForegroundColor Gray
            Write-Host " -> Abrindo o jogo..." -ForegroundColor Cyan
            
            Start-Process -FilePath $skToLaunch
        }
        else {
            Write-Host " [AVISO] Inicializador não localizado automaticamente. Abrindo pasta do Modpack." -ForegroundColor Yellow
            Start-Process explorer.exe $mcDir
        }
    }

    Clear-TempFiles

    Write-Host "`n Processo finalizado com sucesso." -ForegroundColor Green
    Wait-SkipTimeout 4
}
catch {
    Write-Host "`n`n [ERRO CRÍTICO INESPERADO]" -ForegroundColor Red
    Write-Host " Mensagem: $($_.Exception.Message)" -ForegroundColor White
    Write-Host " Linha: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Read-Host "Pressione ENTER para sair..."
    exit 1
}
exit    # ==============================================================================
# PROFILES SKLAUNCHER (SERIALIZAÇÃO JSON NATIVA SEGURA)
# ==============================================================================
function New-LauncherProfile ([string]$McDir, [string]$JavaPath) {
    $profilePath = Join-Path $McDir "launcher_profiles.json"
    $profileId = [guid]::NewGuid().ToString("N")
    $agora = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

    $jsonStructure = [ordered]@{
        profiles        = [ordered]@{
            "$profileId" = [ordered]@{
                name          = "ModpackMadness"
                lastVersionId = "fabric-loader-0.19.2-1.20.1"
                type          = "custom"
                icon          = "Grass"
                created       = $agora
                lastUsed      = $agora
            }
        }
        selectedProfile = $profileId
        settings        = [ordered]@{
            profileSorting = "byName"
        }
        version         = 6
    }

    if ($JavaPath) {
        $normalizedJavaPath = $JavaPath.Replace('/', '\')
        $jsonStructure.profiles."$profileId".Add("javaDir", $normalizedJavaPath)
    }

    $json = $jsonStructure | ConvertTo-Json -Depth 10
    Set-Content -Path $profilePath -Value $json -Encoding UTF8 -NoNewline
}

# ==============================================================================
# DETECÇÃO DE SKLAUNCHER OTIMIZADA
# ==============================================================================
function Find-SKLauncher {
    $caminhosDiretos = @(
        "$env:LOCALAPPDATA\Programs\SKLauncher\SKLauncher.exe",
        "$env:LOCALAPPDATA\Programs\sklauncher\SKLauncher.exe",
        "$env:LOCALAPPDATA\Programs\sklauncher\sklauncher.exe",
        "$env:LOCALAPPDATA\SKLauncher\SKLauncher.exe",
        "$env:APPDATA\SKLauncher\SKLauncher.exe",
        "$env:ProgramFiles\SKLauncher\SKLauncher.exe",
        "${env:ProgramFiles(x86)}\SKLauncher\SKLauncher.exe",
        "$env:APPDATA\.minecraft\sklauncher\SKlauncher.exe",
        "$env:APPDATA\.minecraft\SKlauncher.exe"
    )

    foreach ($caminho in $caminhosDiretos) {
        if (Test-Path $caminho -PathType Leaf) {
            return $caminho
        }
    }

    $startMenuRoots = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu",
        "$env:ProgramData\Microsoft\Windows\Start Menu"
    )

    foreach ($root in $startMenuRoots) {
        if (Test-Path $root) {
            $shortcuts = Get-ChildItem -Path $root -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue
            foreach ($lnk in $shortcuts) {
                
                if ($lnk.Name -imatch "sklauncher" -and $lnk.Name -notmatch "(?i)uninstall|desinstalar|remove") {
                    try {
                        $wshShell = New-Object -ComObject WScript.Shell
                        $target = $wshShell.CreateShortcut($lnk.FullName).TargetPath
                        
                        if ((Test-Path $target -PathType Leaf) -and ($target -notmatch "(?i)javaw\.exe$|unins.*\.exe$|uninstall.*\.exe$")) {
                            return $target
                        }
                    }
                    catch {}
                }
            }
        }
    }

    return $null
}

# ==============================================================================
# EXECUÇÃO PRINCIPAL
# ==============================================================================
Clear-TempFiles

# ==============================================================================
# MENU INICIAL - REMOÇÃO DE EMERGÊNCIA
# ==============================================================================
Show-Header
Write-Host " [ 0 ] URGENTE!!! Remover mod problemático!" -ForegroundColor Red
Write-Host " [ 1 ] Continuar instalação normal" -ForegroundColor Green
Write-Host "`n Opção: " -NoNewline -ForegroundColor Cyan

$optInicial = Read-MenuOption @('0', '1')

if ($optInicial -eq '0') {
    Show-Header
    Write-Host " [ REMOVENDO MOD PROBLEMÁTICO ]" -ForegroundColor Red
    Write-Host "`n Procurando [fabric]ctov-3.4.14.jar nos diretórios do modpack..." -ForegroundColor Cyan
    Write-Host ""

    $modName = "[fabric]ctov-3.4.14.jar"
    $encontrados = @()

    # Prism Launcher - busca em todas as instâncias
    $prismInstances = "$env:APPDATA\PrismLauncher\instances"
    if (Test-Path $prismInstances) {
        $encontrados += Get-ChildItem -Path $prismInstances -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $modName } |
        Select-Object -ExpandProperty FullName
    }

    # SK Launcher / .minecraft padrão
    $skModPath = "$env:APPDATA\.minecraft\mods\$modName"
    if (Test-Path -LiteralPath $skModPath) {
        $encontrados += $skModPath
    }

    if ($encontrados.Count -eq 0) {
        Write-Host " [OK] Mod nao encontrado. Ja foi removido ou nao esta instalado." -ForegroundColor Green
    }
    else {
        $removidos = 0
        foreach ($arquivo in $encontrados) {
            try {
                Remove-Item -LiteralPath $arquivo -Force -ErrorAction Stop
                $removidos++
                Write-Host " [OK] Removido: $arquivo" -ForegroundColor Green
            }
            catch {
                Write-Host " [ERRO] Nao foi possivel remover: $arquivo" -ForegroundColor Red
            }
        }
        Write-Host ""
        Write-Host " $removidos arquivo(s) removido(s) com sucesso!" -ForegroundColor Green
    }

    Write-Host "`n Pressione qualquer tecla para fechar..." -ForegroundColor DarkGray
    $null = [System.Console]::ReadKey($true)
    exit
}

try { $DiscoC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop }
catch { $DiscoC = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" }

$EspacoLivreGB = [math]::Round($DiscoC.FreeSpace / 1GB, 2)
if ($EspacoLivreGB -lt 3.0) {
    Show-FocusWarning "DISCO C: DETERMINADO COMO CHEIO! Libere espaço (Mínimo 3GB)."
    exit
}

Write-Host " Verificando runtime Java..." -ForegroundColor Cyan
$javaJob = Start-Job -ScriptBlock {
    $graalDir = "$env:LOCALAPPDATA\GraalVM"
    if ([System.IO.Directory]::Exists($graalDir)) {
        $found = Get-ChildItem -Path $graalDir -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        if ($found) { return $found }
    }
    return $null
}

while ($javaJob.State -eq "Running") {
    Write-Spinner "Localizando Java/GraalVM no sistema..."
    Start-Sleep -Milliseconds 120
}

$javawPath = Receive-Job -Job $javaJob
Remove-Job -Job $javaJob

if ($javawPath) {
    $javawPath = $javawPath.Replace('\', '/')

    Show-Header
    Write-Host " [ 1/3: VERIFICANDO AMBIENTE JAVA ]" -ForegroundColor Yellow
    Write-Host " GraalVM de alta performance localizado e ativo!" -ForegroundColor Green
    Write-Host " Local: $javawPath" -ForegroundColor White
    Write-Host ""
    Set-MadnessClipboard $javawPath | Out-Null
    Wait-SkipTimeout 3
}
else {
    Show-Header
    Write-Host " [ 1/3: CONFIGURAÇÃO DE RUNTIME JAVA ]" -ForegroundColor Yellow
    Write-Host "`n O Minecraft 1.20+ exige Java moderno e otimizado para rodar sem travamentos." -ForegroundColor White
    Write-Host " Instala o ambiente isolado GraalVM 21 automático para performance..." -ForegroundColor Cyan
    
    $javaDir = "$env:LOCALAPPDATA\GraalVM"
    $javaZip = "$env:TEMP\graalvm.zip"
    Get-MadnessFile $LinkJava $javaZip "Buscando pacotes binários do GraalVM 21 (~300MB)..." "JAVA 21"
    
    if (Test-Path $javaDir) { Remove-Item "$javaDir\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null }
    New-Item -ItemType Directory -Path $javaDir -Force | Out-Null
    
    Expand-MadnessArchive $javaZip $javaDir
    $pastaOriginal = Get-ChildItem -Path $javaDir -Directory | Select-Object -First 1
    if ($pastaOriginal) { Rename-Item -Path $pastaOriginal.FullName -NewName "jdk-21" -ErrorAction SilentlyContinue }
    
    $javawPath = Get-ChildItem -Path $javaDir -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    
    $javawPath = $javawPath.Replace('\', '/')
    Set-MadnessClipboard $javawPath | Out-Null
}

while ($true) {
    Show-Header
    Write-Host " [ 2/3: ESCOLHA DO GERENCIADOR / LAUNCHER ]" -ForegroundColor Yellow
    Write-Host "`n Selecione a sua plataforma de execução de preferência:" -ForegroundColor White
    Write-Host " [ 1 ] Prism Launcher (Contas Originais / Microsoft)" -ForegroundColor Green
    Write-Host " [ 2 ] SKLauncher     (Contas Offline / Alternativas)" -ForegroundColor Green
    Write-Host " [ V ] Voltar" -ForegroundColor Gray
    Write-Host "`n Opção: " -NoNewline -ForegroundColor Cyan

    $optLauncher = Read-MenuOption @('1', '2', 'v')
    if ($optLauncher -eq 'v') { continue }
    $LauncherType = if ($optLauncher -eq '1') { "PRISM" } else { "SKLAUNCHER" }
    break
}

Show-Header
Write-Host " [ 3/3: VERIFICANDO DIRETÓRIOS E COMPONENTES DO $LauncherType ]" -ForegroundColor Yellow

$launcherAchado = $false
$ModoManual = $false
$prismExeLocal = "$env:LOCALAPPDATA\Programs\PrismLauncher\prismlauncher.exe"
$PastaDownloads = "$([Environment]::GetFolderPath('UserProfile'))\Downloads"
$mcDir = "$env:APPDATA\.minecraft"
$skExeValidado = $null

if ($LauncherType -eq "PRISM") {
    if (Test-Path $prismExeLocal) { $launcherAchado = $true }
}
elseif ($LauncherType -eq "SKLAUNCHER") {
    $skExeValidado = Find-SKLauncher
    if ($skExeValidado) { $launcherAchado = $true }
}

if ($launcherAchado) {
    Write-Host "`n [OK] Executável do $LauncherType localizado!" -ForegroundColor Green
    Start-Sleep -Seconds 1
    $baixarLauncher = '2'
}
else {
    Write-Host "`n O gerenciador $LauncherType não foi encontrado." -ForegroundColor White
    Write-Host " [ 1 ] Realizar instalação limpa do zero." -ForegroundColor Green
    Write-Host " [ 2 ] Ignorar (Utilizo versão Portable ou local)." -ForegroundColor DarkGray
    Write-Host "`n Opção: " -NoNewline -ForegroundColor Cyan

    $baixarLauncher = Read-MenuOption @('1', '2')
    if ($baixarLauncher -eq '2') {
        $ModoManual = $true
        Write-Host "`n [!] Modo customizado ativo. Arquivos salvos na pasta Downloads." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

if ($baixarLauncher -eq '1') {
    $InstallDir = $null
        
    Write-Host "`n [ PREFERÊNCIA DE DIRETÓRIO ]" -ForegroundColor Yellow
    Write-Host " [ 1 ] Instalar no local padrão" -ForegroundColor Green
    Write-Host " [ 2 ] Escolher pasta personalizada" -ForegroundColor DarkGray
    Write-Host "`n Opção: " -NoNewline -ForegroundColor Cyan
        
    $optLocal = Read-MenuOption @('1', '2')
        
    if ($optLocal -eq '2') {
        Write-Host "`n -> Selecione a pasta na janela que acabou de abrir..." -ForegroundColor Yellow
        $InstallDir = Get-FolderDialog "Selecione onde deseja instalar o $LauncherType"
        if (-not $InstallDir) {
            Write-Host " Nenhuma pasta selecionada. Usando local padrão do sistema." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }

    if ($LauncherType -eq "PRISM") {
        $prismSetup = "$env:TEMP\PrismSetup.exe"
        Get-MadnessFile $LinkPrism $prismSetup "Baixando instalador oficial do Prism Launcher..." "PRISM SETUP"
            
        Write-Host " -> Instalando Prism Launcher silenciosamente..." -ForegroundColor Cyan
            
        $argsCmd = "/S"
        if ($InstallDir) { $argsCmd += " /D=$InstallDir" }
        else { $InstallDir = "$env:LOCALAPPDATA\Programs\PrismLauncher" }
            
        Start-Process -FilePath $prismSetup -ArgumentList $argsCmd -Wait -NoNewWindow
            
        $prismExeLocal = Join-Path $InstallDir "prismlauncher.exe"
    }
    else {
        $skSetup = "$env:TEMP\SKSetup.exe"
        Get-MadnessFile $LinkSK $skSetup "Baixando instalador oficial do SKLauncher..." "SK LAUNCHER SETUP"
            
        Write-Host " -> Instalando SKLauncher silenciosamente..." -ForegroundColor Cyan
            
        $argsCmd = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
        if ($InstallDir) { $argsCmd += " /DIR=`"$InstallDir`"" }
        else { $InstallDir = "$env:LOCALAPPDATA\Programs\SKLauncher" }

        Start-Process -FilePath $skSetup -ArgumentList $argsCmd -Wait -NoNewWindow
            
        $skExeValidado = Join-Path $InstallDir "SKLauncher.exe"
    }
}

Show-Header
Write-Host " [ DEPLOY FINAL: APLICANDO MODPACK MADNESS ]" -ForegroundColor Yellow

if ($LauncherType -eq "PRISM") {
    $instancesDir = "$env:APPDATA\PrismLauncher\instances"

    Clear-PrismPreInstallation

    $instanciasAntigas = @()
    if (Test-Path $instancesDir) {
        $instanciasAntigas = Get-ChildItem -Path $instancesDir -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    }

    $mrpackPath = "$env:TEMP\Modpack-Madness.mrpack"
    if ($ModoManual) { $mrpackPath = "$PastaDownloads\Modpack-Madness.mrpack" }
    Get-MadnessFile $LinkMrpack $mrpackPath "Baixando pacote estrutural do modpack (.mrpack)..." "PACK PRISM"
    
    Update-InstanceCfg $javawPath $instanciasAntigas
}

if ($LauncherType -ne "PRISM") {
    $modpackZip = "$env:TEMP\Modpack-Madness.zip"
    Get-MadnessFile $LinkZip $modpackZip "Baixando arquivos de modificações e texturas (.zip)..." "ZIP DATA"

    if ($ModoManual) { $mcDir = Join-Path $PastaDownloads "Modpack-Madness-Mods" }

    Write-Host " Modificando e limpando diretórios de destino..." -ForegroundColor Cyan
    Clear-PreInstallation $mcDir

    Write-Host " Executando extração direta..." -ForegroundColor Cyan
    Expand-MadnessArchive $modpackZip $mcDir

    Write-Host " Gerando perfis do inicializador (launcher_profiles.json)..." -ForegroundColor Cyan
    New-LauncherProfile $mcDir $javawPath

    $cfgResiduo = Join-Path $mcDir "instance.cfg"
    if (Test-Path $cfgResiduo) { Remove-Item $cfgResiduo -Force -ErrorAction SilentlyContinue | Out-Null }
}

# ==============================================================================
# FINALIZAÇÃO SEGURA E INVOCAÇÃO DOS PROCESSOS
# ==============================================================================
Clear-Host
Show-Header
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "                    PROCEDIMENTO CONCLUÍDO COM SUCESSO!" -ForegroundColor Green
Write-Host "==============================================================================`n" -ForegroundColor Green

if ($javawPath) {
    $visualJavaPath = $javawPath.Replace('/', '\')
    Set-MadnessClipboard $visualJavaPath | Out-Null
    Write-Host " Caminho do Java 21 copiado para a Área de Transferência!" -ForegroundColor Cyan
    Write-Host " Use WIN + V se precisar colar manualmente nas configurações.`n" -ForegroundColor DarkGray
}

if ($LauncherType -ne "PRISM") {
    Write-Host " Modpack pronto para execução no SKLauncher." -ForegroundColor Green
    Write-Host " Buscando atalho de inicialização..." -ForegroundColor DarkGray

    $skToLaunch = $null
        
    $atalhosPadrao = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\SKlauncher\SKlauncher.lnk",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\SKlauncher\SKlauncher.lnk",
        "$([Environment]::GetFolderPath('Desktop'))\SKlauncher.lnk"
    )

    foreach ($atalho in $atalhosPadrao) {
        if (Test-Path $atalho) {
            $skToLaunch = $atalho
            break
        }
    }

    if (-not $skToLaunch) {
        $skToLaunch = Get-ChildItem -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -Filter "*SKlauncher*.lnk" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "(?i)uninstall|desinstalar" } |
        Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $skToLaunch -and $ModoManual) {
        $skToLaunch = Get-ChildItem -Path $PastaDownloads -Filter "*SKlauncher*.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    }

    if ($skToLaunch -and (Test-Path $skToLaunch)) {
        Write-Host " -> Inicializador validado!" -ForegroundColor Gray
        Write-Host " -> Abrindo o jogo..." -ForegroundColor Cyan
            
        Start-Process -FilePath $skToLaunch
    }
    else {
        Write-Host " [AVISO] Inicializador não localizado automaticamente. Abrindo pasta do Modpack." -ForegroundColor Yellow
        Start-Process explorer.exe $mcDir
    }
}

Clear-TempFiles

Write-Host "`n Processo finalizado com sucesso." -ForegroundColor Green
Wait-SkipTimeout 4
}
catch {
    Write-Host "`n`n [ERRO CRÍTICO INESPERADO]" -ForegroundColor Red
    Write-Host " Mensagem: $($_.Exception.Message)" -ForegroundColor White
    Write-Host " Linha: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Read-Host "Pressione ENTER para sair..."
    exit 1
}
exit