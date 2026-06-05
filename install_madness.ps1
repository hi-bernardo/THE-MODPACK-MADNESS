# ==============================================================================
# CONFIGURACOES E LINKS
# ==============================================================================
$ScriptRAW = "https://raw.githubusercontent.com/hi-bernardo/THE-MODPACK-MADNESS/refs/heads/main/install_madness.ps1"
$LinkMrpackFallback = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1.0/Modpack-Madness.mrpack"
$LinkZipFallback = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1.0/Modpack-Madness.zip"
$LinkPrismFallback = "https://github.com/PrismLauncher/PrismLauncher/releases/download/11.0.2/PrismLauncher-Windows-MSVC-Setup-11.0.2.exe"
$LinkSKFallback = "https://github.com/sklauncher/installer/releases/download/latest/SKlauncher_3.2.18_Setup.exe"
$LinkJavaFallback = "https://download.oracle.com/graalvm/21/latest/graalvm-jdk-21_windows-x64_bin.zip"

try {
    $apiUrl = "https://api.github.com/repos/hi-bernardo/THE-MODPACK-MADNESS/releases/latest"
    $apiResp = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -TimeoutSec 5
    $RemoteVersion = $apiResp.tag_name
    $LinkMrpack = ($apiResp.assets | Where-Object { $_.name -like "*.mrpack" }).browser_download_url
    $LinkZip = ($apiResp.assets | Where-Object { $_.name -like "*.zip" }).browser_download_url
    if (-not $LinkMrpack -or -not $LinkZip) { throw "Assets not found" }
}
catch {
    $manifestPath = "$env:APPDATA\PrismLauncher\.madness_manifest.json"
    if (-not (Test-Path $manifestPath)) { $manifestPath = "$([Environment]::GetFolderPath('UserProfile'))\Downloads\Modpack-Madness-Mods\.madness_manifest.json" }
    if (-not (Test-Path $manifestPath)) { $manifestPath = "$env:APPDATA\.minecraft\instances\ModpackMadness\.madness_manifest.json" }

    $localFallbackVersion = $null
    if (Test-Path $manifestPath) {
        try { $localFallbackVersion = (Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json).version } catch {}
    }

    $LinkMrpack = if ($localFallbackVersion) { "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/$localFallbackVersion/Modpack-Madness.mrpack" } else { $LinkMrpackFallback }
    $LinkZip = if ($localFallbackVersion) { "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/$localFallbackVersion/Modpack-Madness.zip" } else { $LinkZipFallback }
    $RemoteVersion = $null
}

$LinkPrism = $LinkPrismFallback

$LinkSK = $LinkSKFallback

$LinkJava = $LinkJavaFallback

# ==============================================================================
# ENCAPSULAMENTO GLOBAL (TRY/CATCH)
# ==============================================================================
try {

    # ==============================================================================
    # 📦 BLOCO CORE (TUNING, UX, DOWNLOAD, JAVA)
    # ==============================================================================
    $ramFisicaGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $allocatedRam = if ($ramFisicaGB -le 8) { 4096 } else { 6144 }

    [System.Net.ServicePointManager]::DefaultConnectionLimit = 64
    [System.Net.ServicePointManager]::Expect100Continue = $false
    $tlsFlags = [System.Net.SecurityProtocolType]::Tls12
    try { $tlsFlags = $tlsFlags -bor [System.Net.SecurityProtocolType]::Tls13 } catch {}
    [System.Net.ServicePointManager]::SecurityProtocol = $tlsFlags

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    & chcp 65001 | Out-Null

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

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host " Privilegios de Administrador necessarios." -ForegroundColor Yellow
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
            New-Item -Path "HKCU:\Software\Microsoft\Clipboard" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableClipboardHistory" -Value 1 -ErrorAction SilentlyContinue
    }
    catch {}

    $Host.UI.RawUI.WindowTitle = "Instalador - THE MODPACK MADNESS"

    $script:SpinFrames = @('/', '|', '\', '-')
    $script:SpinIdx = 0

    function Write-Spinner ([string]$Mensagem) {
        $char = $script:SpinFrames[$script:SpinIdx % 4]
        Write-Host "`r [$char] $Mensagem" -NoNewline -ForegroundColor Cyan
        $script:SpinIdx++
    }
    # NAO ALTERA NADA AQUI NESSE BLOCO, DAQUI
    function Show-Header {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host "        ____                                     _        _    ____       "    -ForegroundColor Green
        Write-Host "   ___ | __ ) _ __ __ _ _______   ___           | |      / \  | __ ) ___ "   -ForegroundColor Green
        Write-Host "  / _ \|  _ \| '__/ _`  |_  / _ \ / _ \   _____  | |     / _ \ |  _ \/ __|"  -ForegroundColor Green
        Write-Host " | (_) | |_) | | | (_| |/ / (_) | (_) | |_____| | |___ / ___ \| |_) \__ \"  -ForegroundColor Green
        Write-Host "  \___/|____/|_|  \__,_/___\___/ \___/          |_____/_/   \_\____/|___/"   -ForegroundColor Green
        Write-Host ""
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host ""
    }
    # ATE AQUI TAMBEM NAO MEXA, ESTA CORRETO
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
            Write-Host "`r Aguardando ${resta}s... (Qualquer tecla p/ pular) " -NoNewline -ForegroundColor DarkGray
            try {
                if ([System.Console]::KeyAvailable) { $null = [System.Console]::ReadKey($true); break }
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
                $req.KeepAlive = $true
                $req.Proxy = $null

                $resp = $req.GetResponse()
                $tamanho = $resp.ContentLength
                $streamIn = $resp.GetResponseStream()
            
                $bufferSize = 81920
                $streamOut = [System.IO.FileStream]::new($Destino, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, $bufferSize, $false)

                $buffer = New-Object byte[] $bufferSize
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

                Write-Host "`r [OK] Download concluido: $NomeProcesso                          " -ForegroundColor Green
                if ((Get-Item $Destino).Length -lt 1024) { throw "Arquivo corrompido ou muito pequeno." }
                $sucesso = $true
                break
            }
            catch {
                if (Test-Path $Destino) { Remove-Item $Destino -Force -ErrorAction SilentlyContinue | Out-Null }
            }
        }

        if (-not $sucesso) {
            Write-Host "`n [ERRO] Nao foi possivel baixar o componente critico: $NomeProcesso" -ForegroundColor Red
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

    function Expand-MadnessArchive ([string]$ZipPath, [string]$DestinoPasta) {
        if (-not (Test-Path $DestinoPasta)) {
            New-Item -ItemType Directory -Path $DestinoPasta -Force | Out-Null
        }

        $zipStream = $null
        try {
            $zipStream = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        }
        catch {
            Write-Host "`n [ERRO CRITICO] O arquivo compactado esta corrompido." -ForegroundColor Red
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
        Write-Host "`r [OK] Processamento e otimizacao concluidos! ($feitos arquivos)          " -ForegroundColor Green
    }

    function Clear-PreInstallation ([string]$DestinoPasta) {
        $pastasGerenciadas = @("mods", "shaderpacks", "config", "minecraft")
        foreach ($pasta in $pastasGerenciadas) {
            $caminho = Join-Path $DestinoPasta $pasta
            if (Test-Path $caminho) {
                try {
                    [System.IO.Directory]::Delete($caminho, $true)
                    Write-Host " -> Pasta '$pasta' deletada com sucesso." -ForegroundColor Yellow
                }
                catch {
                    $fallback = $caminho + "_old_lixo_" + (Get-Random)
                    Rename-Item -Path $caminho -NewName $fallback -Force -ErrorAction SilentlyContinue | Out-Null
                    Write-Host " -> Pasta '$pasta' renomeada para evitar bloqueio." -ForegroundColor Yellow
                }
            }
        }
        $optTxt = Join-Path $DestinoPasta "options.txt"
        if (Test-Path $optTxt) { Remove-Item -Path $optTxt -Force -ErrorAction SilentlyContinue | Out-Null }
    
        $cfgInvalido = Join-Path $DestinoPasta "instance.cfg"
        if (Test-Path $cfgInvalido) { Remove-Item -Path $cfgInvalido -Force -ErrorAction SilentlyContinue | Out-Null }
    }

    function Clear-UpdateOnly ([string]$BasePath) {
        $foldersToRemove = @("config", "global_packs", "mods", "resourcepacks", "shaderpacks")
        $filesToRemove = @("icon.png", "servers.dat")

        Write-Spinner "Limpando diretorios gerenciados..."

        foreach ($folder in $foldersToRemove) {
            $fullPath = Join-Path $BasePath $folder
            if (Test-Path $fullPath) {
                Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        foreach ($file in $filesToRemove) {
            $fullPath = Join-Path $BasePath $file
            if (Test-Path $fullPath) {
                Remove-Item $fullPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    function Get-PrismGameDir ([string]$InstancePath) {
        $resolved = $null

        # Step 1: Check instance.cfg for GameDirPath key
        $cfgFile = Join-Path $InstancePath "instance.cfg"
        if (Test-Path $cfgFile) {
            foreach ($line in (Get-Content $cfgFile -Encoding UTF8)) {
                if ($line -match "^GameDirPath=(.+)$") {
                    $candidate = $Matches[1].Trim()
                    if ([System.IO.Path]::IsPathRooted($candidate) -and (Test-Path $candidate)) {
                        $resolved = $candidate
                        break
                    }
                }
            }
        }

        # Step 2: Check for "minecraft" (no dot) directory
        if (-not $resolved) {
            $candidate = Join-Path $InstancePath "minecraft"
            if (Test-Path $candidate) {
                $resolved = $candidate
            }
        }

        # Step 3: Fall back to ".minecraft" (with dot)
        if (-not $resolved) {
            $resolved = Join-Path $InstancePath ".minecraft"
        }

        Write-Host " -> Diretorio do jogo detectado: $resolved" -ForegroundColor DarkGray
        return $resolved
    }

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

    function Set-MadnessManifest ([string]$BasePath, [string]$Version, [string]$Launcher, [string]$Action = "INSTALL") {
        $manifestPath = Join-Path $BasePath ".madness_manifest.json"
        $agora = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

        $installedAt = $agora
        if ($Action -eq "UPDATE" -and (Test-Path $manifestPath)) {
            try {
                $existente = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($existente.installed_at) { $installedAt = $existente.installed_at }
            }
            catch {}
        }

        $manifest = [ordered]@{
            version      = $Version
            launcher     = $Launcher
            installed_at = $installedAt
            updated_at   = $agora
            last_action  = $Action
        }
        $json = $manifest | ConvertTo-Json -Depth 5
        Set-Content -Path $manifestPath -Value $json -Encoding UTF8 -NoNewline
    }

    function Show-ManifestStatus ([object]$Manifest) {
        if ($Manifest) {
            $ver = ($Manifest.version + "").PadRight(46)
            $lnc = ($Manifest.launcher + "").PadRight(54)

            $dtRaw = $Manifest.updated_at + ""
            try { $dtFormatted = [DateTime]::Parse($dtRaw).ToString("dd/MM/yyyy HH:mm") } catch { $dtFormatted = $dtRaw }
            $dt = $dtFormatted.PadRight(44)

            Write-Host ""
            Write-Host " +------------------------------------------------------------------+" -ForegroundColor Cyan
            Write-Host " |  MODPACK MADNESS DETECTADO NO SISTEMA                            |" -ForegroundColor Green
            Write-Host " |  Versao instalada: $ver|" -ForegroundColor White
            Write-Host " |  Launcher: $lnc|" -ForegroundColor White
            Write-Host " |  Ultima atualizacao: $dt|" -ForegroundColor DarkGray
            Write-Host " +------------------------------------------------------------------+" -ForegroundColor Cyan
        }
        else {
            Write-Host ""
            Write-Host " [i] Nenhuma instalacao anterior do Modpack Madness foi detectada." -ForegroundColor DarkGray
        }
    }

    # ==============================================================================
    # 📦 BLOCO PRISM LAUNCHER
    # ==============================================================================
    function Clear-PrismPreInstallation {
        $instancesDir = "$env:APPDATA\PrismLauncher\instances"
        if (-not (Test-Path $instancesDir)) { return }

        $candidatas = Get-ChildItem -Path $instancesDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -imatch "madness|modpack" }

        if ($candidatas.Count -eq 0) { return }

        Write-Spinner "Removendo instancias antigas no Prism..."
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

    function Update-InstanceCfg ([string]$JavaPath, [array]$instanciasAntigas, [string]$prismExeLocal, [bool]$ModoManual) {
        if (-not $JavaPath) { return }
        $InstancesDir = "$env:APPDATA\PrismLauncher\instances"
        $JavaPathPrism = $JavaPath.Replace('\', '/')
    
        $hwndConsole = (Get-Process -Id $PID).MainWindowHandle
        if ($hwndConsole -ne [IntPtr]::Zero) {
            [Win32]::ShowWindow($hwndConsole, 9) | Out-Null
            [Win32]::SetForegroundWindow($hwndConsole) | Out-Null
        }

        $PastaDownloads = "$([Environment]::GetFolderPath('UserProfile'))\Downloads"
        $mrpackPath = if ($ModoManual) { "$PastaDownloads\Modpack-Madness.mrpack" } else { "$env:TEMP\Modpack-Madness.mrpack" }

        # Lanca Prism via cmd /c start: processo desanexado do console pai (sem bleeding),
        # ShellExecute interno do cmd garante privilegio de foreground ao Prism
        Start-Process cmd.exe -ArgumentList "/c start `"`" `"$prismExeLocal`" `"$mrpackPath`"" -WindowStyle Hidden

        # Poll for Prism window handle -- smarter than fixed sleep
        $hwndPrism = [IntPtr]::Zero
        for ($wi = 0; $wi -lt 20; $wi++) {
            Start-Sleep -Milliseconds 500
            $wpProc = Get-Process -Name "prismlauncher" -ErrorAction SilentlyContinue |
                Sort-Object StartTime -Descending | Select-Object -First 1
            if ($wpProc -and $wpProc.MainWindowHandle -ne [IntPtr]::Zero) {
                $hwndPrism = $wpProc.MainWindowHandle
                break
            }
            Write-Spinner "Aguardando janela do Prism..."
        }

        # Bring Prism to front using AttachThreadInput to bypass focus-steal prevention
        if ($hwndPrism -ne [IntPtr]::Zero) {
            $foreHwnd   = [Win32]::GetForegroundWindow()
            $dummyPid   = [uint32]0
            $foreThread = [Win32]::GetWindowThreadProcessId($foreHwnd, [ref]$dummyPid)
            $prismThread = [Win32]::GetWindowThreadProcessId($hwndPrism, [ref]$dummyPid)
            $myThread   = [Win32]::GetCurrentThreadId()

            if ($foreThread -ne $prismThread) {
                [Win32]::AttachThreadInput($myThread, $foreThread,  $true)  | Out-Null
                [Win32]::AttachThreadInput($myThread, $prismThread, $true)  | Out-Null
            }
            [Win32]::ShowWindow($hwndPrism, 9)       | Out-Null
            [Win32]::SetForegroundWindow($hwndPrism) | Out-Null
            [Win32]::BringWindowToTop($hwndPrism)    | Out-Null
            if ($foreThread -ne $prismThread) {
                [Win32]::AttachThreadInput($myThread, $foreThread,  $false) | Out-Null
                [Win32]::AttachThreadInput($myThread, $prismThread, $false) | Out-Null
            }
        }
        if ($hwndPrism -ne [IntPtr]::Zero) { [Win32]::FlashWindow($hwndPrism, $true) | Out-Null }
        [System.Media.SystemSounds]::Exclamation.Play()

        Write-Host "`n [Prism] A janela de importacao do modpack foi aberta." -ForegroundColor Cyan
        Write-Host " -> Prossiga com a importacao na interface do Prism. Aguardando conclusao..." -ForegroundColor Yellow

        $timeout = 300
        $elapsed = 0
        $cfgPath = $null
        $attentionCount = 0

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
                    Start-Sleep -Seconds 2
                    $cfgPath = $caminhoCfg
                    break
                }
            }
            Start-Sleep -Seconds 1
            $elapsed++
            $msgProgresso = "Aguardando confirmacao manual da importacao... (" + $elapsed + "s)"
            Write-Spinner $msgProgresso
            if ($elapsed -gt 0 -and $elapsed % 20 -eq 0 -and $attentionCount -lt 2) {
                if ($hwndPrism -ne [IntPtr]::Zero) {
                    $fHwnd = [Win32]::GetForegroundWindow()
                    $dPid  = [uint32]0
                    $fThr  = [Win32]::GetWindowThreadProcessId($fHwnd, [ref]$dPid)
                    $pThr  = [Win32]::GetWindowThreadProcessId($hwndPrism, [ref]$dPid)
                    $mThr  = [Win32]::GetCurrentThreadId()
                    if ($fThr -ne $pThr) {
                        [Win32]::AttachThreadInput($mThr, $fThr, $true)  | Out-Null
                        [Win32]::AttachThreadInput($mThr, $pThr, $true)  | Out-Null
                    }
                    [Win32]::ShowWindow($hwndPrism, 9)       | Out-Null
                    [Win32]::SetForegroundWindow($hwndPrism) | Out-Null
                    [Win32]::BringWindowToTop($hwndPrism)    | Out-Null
                    if ($fThr -ne $pThr) {
                        [Win32]::AttachThreadInput($mThr, $fThr, $false) | Out-Null
                        [Win32]::AttachThreadInput($mThr, $pThr, $false) | Out-Null
                    }
                }
                if ($hwndPrism -ne [IntPtr]::Zero) { [Win32]::FlashWindow($hwndPrism, $true) | Out-Null }
                [System.Media.SystemSounds]::Exclamation.Play()
                $attentionCount++
            }
        }

        if (-not $cfgPath) {
            Write-Host "`n [ERRO] Tempo esgotado. Nenhuma nova instancia foi detectada." -ForegroundColor Red
            return
        }

        Write-Host "`n`n [!] Instancia detectada! Encerrando o Prism para aplicar correcoes com seguranca..." -ForegroundColor Yellow
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
                Write-Spinner "Aguardando liberacao completa do arquivo ($tentativasLock/20)..."
                Start-Sleep -Seconds 1
            }
        }

        if (-not $arquivoLiberado) {
            Write-Host "`n [ERRO] O arquivo instance.cfg continua travado por outro processo. Nao foi possivel editar." -ForegroundColor Red
            return
        }

        Write-Host "`n [OK] Arquivo liberado e pronto para edicao. Aplicando configuracoes..." -ForegroundColor Cyan
        $conteudoAtual = Get-Content $cfgPath -Raw -Encoding UTF8

        $linhasOriginais = $conteudoAtual -split "`r?`n"
        $novasLinhas = [System.Collections.Generic.List[string]]::new()

        $OverridesMadness = [ordered]@{
            "OverrideJavaLocation"    = "true"
            "IgnoreJavaCompatibility" = "true"
            "AutomaticJava"           = "false"
            "JavaPath"                = $JavaPathPrism
            "OverrideMemory"          = "true"
            "MinMemAlloc"             = "1024"
            "MaxMemAlloc"             = "$allocatedRam"
            "OverrideJavaArgs"        = "true"
            "JvmArgs"                 = "-XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:MaxGCPauseMillis=50 -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:G1HeapRegionSize=16M -XX:G1HeapWastePercent=5 -XX:InitiatingHeapOccupancyPercent=15 -XX:+UseStringDeduplication"
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
            Write-Host "  SUCESSO: CONFIGURACOES GRAVADAS COM SUCESSO!" -ForegroundColor Green
            Write-Host " ========================================================" -ForegroundColor Green
            Write-Host " -> As barras '/' e Overrides de Java foram consolidados." -ForegroundColor White
            Invoke-Attention
            Start-Sleep -Seconds 2
        }
        catch {
            Write-Host "`n [ERRO CRITICO] Falha ao gravar dados no arquivo: $($_.Exception.Message)" -ForegroundColor Red
            Start-Sleep -Seconds 5
        }

        if (-not $ModoManual -and (Test-Path $prismExeLocal)) {
            Write-Host " -> Reiniciando Prism Launcher com as novas configuracoes..." -ForegroundColor Cyan

            Stop-Process -Name "prismlauncher" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Process cmd.exe -ArgumentList "/c start `"`" `"$prismExeLocal`"" -WindowStyle Hidden
        }
    }

    # ==============================================================================
    # 📦 BLOCO SKLAUNCHER
    # ==============================================================================
    function New-LauncherProfile ([string]$McDir, [string]$JavaPath, [string]$GameDir) {
        $profilePath = Join-Path $McDir "launcher_profiles.json"
        $profileId = [guid]::NewGuid().ToString("N")
        $agora = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

        $versionId = "fabric-loader-0.19.2-1.20.1"
        $modpackJsonPath = Join-Path $GameDir "modpack.json"
        if (Test-Path $modpackJsonPath) {
            try {
                $modpackData = Get-Content $modpackJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($modpackData.dependencies."fabric-loader" -and $modpackData.dependencies.minecraft) {
                    $versionId = "fabric-loader-$($modpackData.dependencies."fabric-loader")-$($modpackData.dependencies.minecraft)"
                }
            }
            catch {}
        }

        $jsonStructure = [ordered]@{
            profiles        = [ordered]@{
                "$profileId" = [ordered]@{
                    name          = "ModpackMadness"
                    gameDir       = $GameDir.Replace('/', '\')
                    lastVersionId = $versionId
                    type          = "custom"
                    icon          = "Grass"
                    memoryMax     = $allocatedRam
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
            $jsonStructure.profiles."$profileId".Add("javaArgs", "-XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:MaxGCPauseMillis=50 -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:G1HeapRegionSize=16M -XX:G1HeapWastePercent=5 -XX:InitiatingHeapOccupancyPercent=15 -XX:+UseStringDeduplication")
        }

        $json = $jsonStructure | ConvertTo-Json -Depth 10
        Set-Content -Path $profilePath -Value $json -Encoding UTF8 -NoNewline
    }

    function Find-LauncherApp ([string]$AppName, [string]$ExeName) {
        Write-Host "`n Buscando $AppName no Registro do Windows..." -ForegroundColor Cyan
        $pathsToSearch = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        $foundPath = $null
        foreach ($path in $pathsToSearch) {
            $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match $AppName -or $_.DisplayName -match $ExeName }
            foreach ($app in $apps) {
                if ($app.InstallLocation -and (Test-Path $app.InstallLocation)) {
                    $cand = Join-Path $app.InstallLocation $ExeName
                    if (Test-Path $cand) { $foundPath = $cand; break }
                }
                if ($app.DisplayIcon) {
                    $iconPath = $app.DisplayIcon -replace '",.*$', '"' -replace '"', ''
                    if (Test-Path $iconPath) {
                        if ($iconPath.EndsWith($ExeName, [System.StringComparison]::InvariantCultureIgnoreCase)) {
                            $foundPath = $iconPath; break
                        }
                    }
                }
            }
            if ($foundPath) { break }
        }

        if (-not $foundPath) {
            $caminhosComuns = @(
                "$env:LOCALAPPDATA\Programs\$AppName\$ExeName",
                "$env:LOCALAPPDATA\$AppName\$ExeName",
                "$env:APPDATA\$AppName\$ExeName",
                "$env:ProgramFiles\$AppName\$ExeName",
                "${env:ProgramFiles(x86)}\$AppName\$ExeName"
            )
            if ($AppName -imatch "SKLauncher") {
                $caminhosComuns += "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\SKlauncher\SKlauncher.lnk"
                $caminhosComuns += "$env:APPDATA\sklauncher\SKlauncher.jar"
            }
            foreach ($c in $caminhosComuns) { if (Test-Path $c) { $foundPath = $c; break } }
        }

        if ($foundPath) { return $foundPath }

        return $null
    }

    # ==============================================================================
    # 🚀 EXECUCAO PRINCIPAL
    # ==============================================================================
    Clear-TempFiles

    # ──────────────────────────────────────────────────────────────────────────────
    # VERIFICACAO DE ESPACO EM DISCO
    # ──────────────────────────────────────────────────────────────────────────────
    try { $DiscoC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop }
    catch { $DiscoC = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" }

    $EspacoLivreGB = [math]::Round($DiscoC.FreeSpace / 1GB, 2)
    if ($EspacoLivreGB -lt 3.0) {
        Show-FocusWarning "DISCO C: DETERMINADO COMO CHEIO! Libere espaco (Minimo 3GB)."
        exit
    }

    # ──────────────────────────────────────────────────────────────────────────────
    # ETAPA 1: DETECCAO E INSTALACAO DO RUNTIME JAVA
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
        Write-Host " [ 1/3: CONFIGURACAO DE RUNTIME JAVA ]" -ForegroundColor Yellow
        Write-Host "`n O Minecraft 1.20+ exige Java moderno e otimizado para rodar sem travamentos." -ForegroundColor White
        Write-Host " Instala o ambiente isolado GraalVM 21 automatico para performance..." -ForegroundColor Cyan
    
        $javaDir = "$env:LOCALAPPDATA\GraalVM"
        $javaZip = "$env:TEMP\graalvm.zip"
        Get-MadnessFile $LinkJava $javaZip "Buscando pacotes binarios do GraalVM 21 (~300MB)..." "JAVA 21"
    
        if (Test-Path $javaDir) { Remove-Item "$javaDir\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null }
        New-Item -ItemType Directory -Path $javaDir -Force | Out-Null
    
        Expand-MadnessArchive $javaZip $javaDir
        $pastaOriginal = Get-ChildItem -Path $javaDir -Directory | Select-Object -First 1
        if ($pastaOriginal) { Rename-Item -Path $pastaOriginal.FullName -NewName "jdk-21" -ErrorAction SilentlyContinue }
    
        $javawPath = Get-ChildItem -Path $javaDir -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        if (-not $javawPath) {
            Write-Host "`n [ERRO CRITICO] Java 21 nao localizado apos extracao. Verifique o arquivo baixado." -ForegroundColor Red
            Read-Host "Pressione ENTER para fechar..."
            exit 1
        }
        $javawPath = $javawPath.Replace('\', '/')
        Set-MadnessClipboard $javawPath | Out-Null
    }

    # ──────────────────────────────────────────────────────────────────────────────
    # ETAPA 2: ESCOLHA DO LAUNCHER
    # ──────────────────────────────────────────────────────────────────────────────
    :Etapa2 while ($true) {
        Show-Header
        Write-Host " [ 2/3: ESCOLHA DO GERENCIADOR / LAUNCHER ]" -ForegroundColor Yellow
        Write-Host "`n Selecione a sua plataforma de execucao de preferencia:" -ForegroundColor White
        Write-Host " [ 1 ] Prism Launcher (Contas Originais / Microsoft)" -ForegroundColor Green
        Write-Host " [ 2 ] SKLauncher     (Contas Offline / Alternativas)" -ForegroundColor Green
        Write-Host " [ V ] Voltar" -ForegroundColor Gray
        Write-Host "`n Opcao: " -NoNewline -ForegroundColor Cyan

        $optLauncher = Read-MenuOption @('1', '2', 'v')
        if ($optLauncher -eq 'v') { continue }

        $LauncherType = if ($optLauncher -eq '1') { "PRISM" } else { "SKLAUNCHER" }

        # ──────────────────────────────────────────────────────────────────────────────
        # ETAPA 3: VERIFICACAO DE DIRETORIOS E COMPONENTES
        # ──────────────────────────────────────────────────────────────────────────────
        Show-Header
        Write-Host " [ 3/3: VERIFICANDO DIRETORIOS E COMPONENTES DO $LauncherType ]" -ForegroundColor Yellow

        $launcherAchado = $false
        $ModoManual = $false
        $prismExeLocal = $null
        $skExeValidado = $null
        $PastaDownloads = "$([Environment]::GetFolderPath('UserProfile'))\Downloads"
        $mcDir = "$env:APPDATA\.minecraft"

        if ($LauncherType -eq "PRISM") {
            $prismExeLocal = Find-LauncherApp "PrismLauncher" "prismlauncher.exe"
            if ($prismExeLocal) { $launcherAchado = $true }
        }
        elseif ($LauncherType -eq "SKLAUNCHER") {
            $skExeValidado = Find-LauncherApp "SKLauncher" "SKlauncher.exe"
            if ($skExeValidado) { $launcherAchado = $true }
        }

        if ($launcherAchado) {
            Write-Host "`n [OK] Executavel do $LauncherType localizado!" -ForegroundColor Green
            Start-Sleep -Seconds 1
            $baixarLauncher = '2'
        }
        else {
            Write-Host "`n O gerenciador $LauncherType nao foi encontrado ou nao selecionado." -ForegroundColor White
            Write-Host " [ 1 ] Realizar instalacao limpa do zero." -ForegroundColor Green
            Write-Host " [ 2 ] Ignorar (Utilizo versao Portable ou local)." -ForegroundColor DarkGray
            Write-Host "`n Opcao: " -NoNewline -ForegroundColor Cyan

            $baixarLauncher = Read-MenuOption @('1', '2')
            if ($baixarLauncher -eq '2') {
                $ModoManual = $true
                Write-Host "`n [!] Modo customizado ativo. Arquivos salvos na pasta Downloads." -ForegroundColor Yellow

                while ($true) {
                    Write-Host " Por favor, selecione o executavel do $LauncherType na janela que sera aberta." -ForegroundColor Cyan
                
                    $dialog = New-Object System.Windows.Forms.OpenFileDialog
                    $dialog.Filter = "Launchers (*.exe;*.lnk;*.jar)|*.exe;*.lnk;*.jar|Todos os Arquivos (*.*)|*.*"
                    $dialog.Title = "Selecione o inicializador do $LauncherType"
                    $dialog.FileName = ""
                
                    $form = New-Object System.Windows.Forms.Form
                    $form.TopMost = $true
                    $form.ShowInTaskbar = $false
                    $form.WindowState = 'Minimized'
                    $form.Show()
                    $form.BringToFront()

                    $result = $dialog.ShowDialog($form)
                    $form.Dispose()

                    if ($result -eq [System.Windows.Forms.DialogResult]::OK -and (Test-Path $dialog.FileName)) {
                        if ($LauncherType -eq "PRISM") {
                            $prismExeLocal = $dialog.FileName
                        }
                        else {
                            $skExeValidado = $dialog.FileName
                        }
                        break
                    }
                    else {
                        Write-Host " Nenhum executavel selecionado." -ForegroundColor Yellow
                        Write-Host " [ 1 ] Tentar selecionar novamente" -ForegroundColor Green
                        Write-Host " [ V ] Voltar para a escolha do Launcher" -ForegroundColor Gray
                        Write-Host "`n Opcao: " -NoNewline -ForegroundColor Cyan
                    
                        $optDialog = Read-MenuOption @('1', 'v')
                        if ($optDialog -eq 'v') {
                            continue Etapa2
                        }
                    }
                }
                Start-Sleep -Seconds 2
            }
        }

        if ($baixarLauncher -eq '1') {
            $InstallDir = $null
        
            Write-Host "`n [ PREFERENCIA DE DIRETORIO ]" -ForegroundColor Yellow
            Write-Host " [ 1 ] Instalar no local padrao" -ForegroundColor Green
            Write-Host " [ 2 ] Escolher pasta personalizada" -ForegroundColor DarkGray
            Write-Host "`n Opcao: " -NoNewline -ForegroundColor Cyan
        
            $optLocal = Read-MenuOption @('1', '2')
        
            if ($optLocal -eq '2') {
                Write-Host "`n -> Selecione a pasta na janela que acabou de abrir..." -ForegroundColor Yellow
                $InstallDir = Get-FolderDialog "Selecione onde deseja instalar o $LauncherType"
                if (-not $InstallDir) {
                    Write-Host " Nenhuma pasta selecionada. Usando local padrao do sistema." -ForegroundColor Yellow
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

        break
    } # Fim do while :Etapa2

    if ($LauncherType -ne "PRISM") {
        if ($ModoManual) {
            $isolatedDir = Join-Path $PastaDownloads "Modpack-Madness-Mods"
        }
        else {
            $isolatedDir = Join-Path $env:APPDATA ".minecraft\instances\ModpackMadness"
        }
    }

    $manifestBase = if ($LauncherType -eq "PRISM") { "$env:APPDATA\PrismLauncher" } else { $isolatedDir }
    $manifestAtual = Get-MadnessManifest $manifestBase

    $AcaoModpack = "INSTALL"
    if (-not $manifestAtual) {
        $AcaoModpack = "INSTALL"
        Show-Header
        Write-Host " [ MODO DE OPERACAO: INSTALACAO LIMPA ]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host " O instalador preparara o modpack do zero no seu pc." -ForegroundColor Green
        Wait-SkipTimeout 4
    }
    elseif ($RemoteVersion -eq $null -or $manifestAtual.version -ne $RemoteVersion) {
        Show-Header
        if (-not $RemoteVersion) {
            Write-Host " [AVISO] API offline - versao remota desconhecida. Prosseguindo com arquivos disponiveis." -ForegroundColor Yellow
            Write-Host " [ ATUALIZACAO / REINSTALACAO ]" -ForegroundColor Cyan
        }
        else {
            Write-Host " [ ATUALIZACAO DISPONIVEL ($RemoteVersion) ]" -ForegroundColor Cyan
        }
        Show-ManifestStatus $manifestAtual
        Write-Host ""
        Write-Host " [ 1 ] Atualizar (Preserva Saves e Options)" -ForegroundColor Green
        Write-Host " [ 2 ] Instalacao Limpa (Apaga Tudo)" -ForegroundColor DarkGray
        Write-Host "`n Opcao: " -NoNewline -ForegroundColor Cyan
        $optUpd = Read-MenuOption @('1', '2')
        $AcaoModpack = if ($optUpd -eq '1') { "UPDATE" } else { "INSTALL" }
    }
    else {
        Show-Header
        Write-Host " [ VOCE JA ESTA NA VERSAO MAIS RECENTE! ]" -ForegroundColor Green
        Show-ManifestStatus $manifestAtual
        Write-Host ""
        Write-Host " [ 1 ] Reparar/Reinstalar Modpack" -ForegroundColor Yellow
        Write-Host " [ 2 ] Cancelar e Sair" -ForegroundColor DarkGray
        Write-Host "`n Opcao: " -NoNewline -ForegroundColor Cyan
        $optRep = Read-MenuOption @('1', '2')
        if ($optRep -eq '2') { exit }
        $AcaoModpack = "INSTALL"
    }

    # ==============================================================================
    # DEPLOY FINAL: APLICANDO MODPACK MADNESS
    # ==============================================================================
    Show-Header
    if ($AcaoModpack -eq "UPDATE") {
        Write-Host " [ DEPLOY: ATUALIZACAO DO MODPACK MADNESS ]" -ForegroundColor Yellow
    }
    else {
        Write-Host " [ DEPLOY: INSTALACAO LIMPA DO MODPACK MADNESS ]" -ForegroundColor Yellow
    }

    if ($LauncherType -eq "PRISM") {
        $instancesDir = "$env:APPDATA\PrismLauncher\instances"

        if ($AcaoModpack -eq "INSTALL") {
            # --- INSTALL: comportamento identico ao original ---
            $instanciasAntigas = @()
            if (Test-Path $instancesDir) {
                $instanciasAntigas = Get-ChildItem -Path $instancesDir -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
            }
            Write-Spinner "Removendo instancias antigas..."
            Clear-PrismPreInstallation
            if (Test-Path $instancesDir) {
                $instanciasAntigas = Get-ChildItem -Path $instancesDir -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
            }
            $mrpackPath = "$env:TEMP\Modpack-Madness.mrpack"
            if ($ModoManual) { $mrpackPath = "$PastaDownloads\Modpack-Madness.mrpack" }
            Get-MadnessFile $LinkMrpack $mrpackPath "Baixando pacote estrutural do modpack (.mrpack)..." "PACK PRISM"
            Update-InstanceCfg $javawPath $instanciasAntigas $prismExeLocal $ModoManual
        }
        else {
            # --- UPDATE: in-place via .zip, sem criar nova instancia ---

            # 1. Localizar instancia existente
            $instanciaExistente = $null
            if (Test-Path $instancesDir) {
                $instanciaExistente = Get-ChildItem -Path $instancesDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -imatch "madness|modpack" } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
                if ($instanciaExistente) {
                    Write-Host " -> Instancia detectada: $($instanciaExistente.Name)" -ForegroundColor DarkGray
                }
            }

            if (-not $instanciaExistente) {
                Write-Host "`n [ERRO] Nenhuma instancia do modpack encontrada. Execute uma instalacao limpa." -ForegroundColor Red
                Read-Host "Pressione ENTER para fechar..."
                exit 1
            }

            $gameDir = Get-PrismGameDir $instanciaExistente.FullName
            $cfgPath = Join-Path $instanciaExistente.FullName "instance.cfg"

            # 2. Baixar .zip e extrair em pasta temporaria
            $modpackZip = "$env:TEMP\Modpack-Madness.zip"
            Get-MadnessFile $LinkZip $modpackZip "Baixando pacote de atualizacao (.zip)..." "ZIP UPDATE"

            $tempExtract = "$env:TEMP\MadnessExtract_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null
            Write-Spinner "Extraindo para staging temporario..."
            Expand-MadnessArchive $modpackZip $tempExtract

            # 3. Encerrar Prism
            $prismProcesses = Get-Process -Name "prismlauncher" -ErrorAction SilentlyContinue
            if ($prismProcesses) {
                Write-Spinner "Encerrando Prism Launcher..."
                $prismProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }

            # 4. Limpar pastas gerenciadas da instancia
            Clear-UpdateOnly $gameDir

            # 5. Mover conteudo do staging para a instancia
            Write-Spinner "Aplicando atualizacao na instancia..."
            Get-ChildItem -Path $tempExtract | ForEach-Object {
                $dest = Join-Path $gameDir $_.Name
                if (Test-Path $dest) { Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue }
                Move-Item -Path $_.FullName -Destination $gameDir -Force -ErrorAction SilentlyContinue
            }

            # 6. Remover staging temporario
            Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

            # 7. Aplicar configuracoes Java no instance.cfg
            if ($javawPath -and (Test-Path $cfgPath)) {
                $JavaPathPrism = $javawPath.Replace('\', '/')
                $OverridesMadness = [ordered]@{
                    "OverrideJavaLocation"    = "true"
                    "IgnoreJavaCompatibility" = "true"
                    "AutomaticJava"           = "false"
                    "JavaPath"                = $JavaPathPrism
                    "OverrideMemory"          = "true"
                    "MinMemAlloc"             = "1024"
                    "MaxMemAlloc"             = "$allocatedRam"
                    "OverrideJavaArgs"        = "true"
                    "JvmArgs"                 = "-XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:MaxGCPauseMillis=50 -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:G1HeapRegionSize=16M -XX:G1HeapWastePercent=5 -XX:InitiatingHeapOccupancyPercent=15 -XX:+UseStringDeduplication"
                }
                $conteudo = Get-Content $cfgPath -Raw -Encoding UTF8
                $linhas = $conteudo -split "`r?`n"
                $novasLinhas = [System.Collections.Generic.List[string]]::new()
                $chavesInjetadas = @{}
                foreach ($linha in $linhas) {
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
                    $merged = [System.Collections.Generic.List[string]]::new()
                    foreach ($l in $novasLinhas) {
                        $merged.Add($l) | Out-Null
                        if ($l.Trim() -eq "[General]") {
                            foreach ($cf in $chavesFaltantes) { $merged.Add("$cf=$($OverridesMadness[$cf])") | Out-Null }
                        }
                    }
                    $novasLinhas = $merged
                }
                $cfgFinal = ($novasLinhas -join "`r`n").TrimEnd() + "`r`n"
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($cfgPath, $cfgFinal, $utf8NoBom)
                Write-Host "`n [OK] Configuracoes Java aplicadas." -ForegroundColor Green
            }

            # 8. Reiniciar Prism
            if (-not $ModoManual -and $prismExeLocal -and (Test-Path $prismExeLocal)) {
                Write-Host " -> Reiniciando Prism Launcher..." -ForegroundColor Cyan
                Start-Sleep -Seconds 1
                Start-Process cmd.exe -ArgumentList "/c start `"`" `"$prismExeLocal`"" -WindowStyle Hidden
            }
        }

        Set-MadnessManifest "$env:APPDATA\PrismLauncher" $RemoteVersion "PRISM" $AcaoModpack
    }
    else {
        $modpackZip = "$env:TEMP\Modpack-Madness.zip"
        Get-MadnessFile $LinkZip $modpackZip "Baixando pacote de modificacoes (.zip)..." "ZIP DATA"


        if ($AcaoModpack -eq "UPDATE" -and (Test-Path $isolatedDir)) {
            # Extrair em staging temporario antes de alterar a instancia
            $tempExtract = "$env:TEMP\MadnessExtract_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null
            Write-Spinner "Extraindo para staging temporario..."
            Expand-MadnessArchive $modpackZip $tempExtract

            # Limpar pastas gerenciadas
            Clear-UpdateOnly $isolatedDir

            # Mover conteudo do staging para a instancia
            Write-Spinner "Aplicando atualizacao na instancia..."
            Get-ChildItem -Path $tempExtract | ForEach-Object {
                $dest = Join-Path $isolatedDir $_.Name
                if (Test-Path $dest) { Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue }
                Move-Item -Path $_.FullName -Destination $isolatedDir -Force -ErrorAction SilentlyContinue
            }

            # Remover staging temporario
            Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        }
        else {
            if (Test-Path $isolatedDir) {
                try { [System.IO.Directory]::Delete($isolatedDir, $true) }
                catch {
                    $fallback = $isolatedDir + "_old_lixo_" + (Get-Random)
                    Rename-Item -Path $isolatedDir -NewName $fallback -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }

        Write-Spinner "Extraindo arquivos..."
        Expand-MadnessArchive $modpackZip $isolatedDir

        Write-Spinner "Gerando perfil do inicializador..."
        New-LauncherProfile $mcDir $javawPath $isolatedDir

        $cfgResiduo = Join-Path $isolatedDir "instance.cfg"
        if (Test-Path $cfgResiduo) { Remove-Item $cfgResiduo -Force -ErrorAction SilentlyContinue | Out-Null }

        Set-MadnessManifest $isolatedDir $RemoteVersion "SKLAUNCHER" $AcaoModpack
    }

    # ==============================================================================
    # FINALIZACAO
    # ==============================================================================
    Clear-Host
    Show-Header
    Write-Host "==============================================================================" -ForegroundColor Green
    Write-Host "                    INSTALACAO CONCLUIDA COM SUCESSO!" -ForegroundColor Green
    Write-Host "==============================================================================`n" -ForegroundColor Green

    if ($javawPath) {
        $visualJavaPath = $javawPath.Replace('/', '\')
        Set-MadnessClipboard $visualJavaPath | Out-Null
        Write-Host " Caminho do Java 21 copiado para a Area de Transferencia!" -ForegroundColor Cyan
        Write-Host " Use WIN + V se precisar colar manualmente nas configuracoes.`n" -ForegroundColor DarkGray
    }

    if ($LauncherType -ne "PRISM") {
        Write-Host " Modpack pronto para execucao no SKLauncher." -ForegroundColor Green
        Write-Host " Buscando atalho de inicializacao..." -ForegroundColor DarkGray
        
        $skToLaunch = $skExeValidado
        if (-not $skToLaunch -or -not (Test-Path $skToLaunch)) {
            $skToLaunch = Find-LauncherApp "SKLauncher" "SKlauncher.exe"
        }

        if ($skToLaunch -and (Test-Path $skToLaunch)) {
            Write-Host " -> Inicializador validado!" -ForegroundColor Gray
            Write-Host " -> Abrindo o jogo..." -ForegroundColor Cyan
            # Start-Process delega naturalmente para o ShellExecute no Windows PowerShell,
            # abrindo corretamente tanto binarios (.exe) quanto (.lnk) e (.jar)
            Start-Process -FilePath $skToLaunch
        }
        else {
            Write-Host " [AVISO] Inicializador nao localizado automaticamente. Abrindo pasta do Modpack." -ForegroundColor Yellow
            Start-Process explorer.exe $isolatedDir
        }
    }

    Clear-TempFiles
    Write-Host "`n Processo finalizado com sucesso." -ForegroundColor Green
    Wait-SkipTimeout 4
}
catch {
    Write-Host "`n`n [ERRO CRITICO INESPERADO]" -ForegroundColor Red
    Write-Host " Mensagem: $($_.Exception.Message)" -ForegroundColor White
    Write-Host " Linha: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Read-Host "Pressione ENTER para sair..."
    exit 1
}
exit


