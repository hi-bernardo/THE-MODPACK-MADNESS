# ==============================================================================
# CONFIGURACOES E LINKS
# ==============================================================================
$ScriptRAW = "https://raw.githubusercontent.com/hi-bernardo/THE-MODPACK-MADNESS/refs/heads/main/install_madness.ps1"
$LinkMrpack = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1/Modpack-Madness.mrpack"
$LinkZip = "https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1/Modpack-Madness.zip"
$LinkPrism = "https://github.com/PrismLauncher/PrismLauncher/releases/download/11.0.2/PrismLauncher-Windows-MSVC-Setup-11.0.2.exe"
$LinkSK = "https://github.com/sklauncher/installer/releases/download/latest/SKlauncher_3.2.18_Setup.exe"
$LinkJava = "https://download.oracle.com/graalvm/21/latest/graalvm-jdk-21_windows-x64_bin.zip"

# ==============================================================================
# SISTEMA DE LOG (desative mudando para $false)
# ==============================================================================
$LogAtivado = $true
$LogPath = $null   # Sera definido apos verificar admin e caminho do script

function Log-Msg ([string]$Nivel, [string]$Mensagem) {
    if (-not $LogAtivado) { return }
    if (-not $LogPath) { return }
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $linha = "[$ts] [$Nivel] $Mensagem"
    Add-Content -Path $LogPath -Value $linha -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Log-Info  ([string]$m) { Log-Msg "INFO " $m }
function Log-Warn  ([string]$m) { Log-Msg "WARN " $m }
function Log-Erro  ([string]$m) { Log-Msg "ERRO " $m }
function Log-Step  ([string]$m) { Log-Msg "STEP " "=== $m ===" }
function Log-Ok    ([string]$m) { Log-Msg "OK   " $m }

# ==============================================================================
# TUNING DE REDE — aplica antes de qualquer download
# ==============================================================================
[System.Net.ServicePointManager]::DefaultConnectionLimit = 64
[System.Net.ServicePointManager]::Expect100Continue = $false
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# ==============================================================================
# ASSEMBLIES
# ==============================================================================
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
    }
    else {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm $ScriptRAW | iex`"" -Verb RunAs
    }
    exit
}

# Definir caminho do log (mesma pasta do script, ou TEMP se via iex)
if ($PSCommandPath) {
    $LogPath = Join-Path (Split-Path $PSCommandPath -Parent) "install_log.txt"
}
else {
    $LogPath = "$env:TEMP\install_madness_log.txt"
}

# Garantir que o arquivo de log existe
if ($LogAtivado) {
    $cabecalhoLog = @"
================================================================================
  LOG - THE MODPACK MADNESS INSTALLER
  Data  : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  Maquina: $env:COMPUTERNAME | Usuario: $env:USERNAME
  PowerShell: $($PSVersionTable.PSVersion)
================================================================================
"@
    Set-Content -Path $LogPath -Value $cabecalhoLog -Encoding UTF8 -ErrorAction SilentlyContinue
}

Log-Step "INICIO DO INSTALADOR"

# Anti-travamento de input
$hStdIn = [Win32]::GetStdHandle(-10)
[uint]$mode = 0
[Win32]::GetConsoleMode($hStdIn, [ref]$mode) | Out-Null
$mode = $mode -band (-bnot 0x0040)
[Win32]::SetConsoleMode($hStdIn, $mode) | Out-Null

# Redimensionar e centralizar — sem scrollbars
# Regra do Console Windows: BufferSize >= WindowSize sempre.
# Ordem correta: (1) encolher janela para o minimo, (2) setar Buffer = tamanho final, (3) setar Window = tamanho final.
$largura = 78
$altura = 30
$pshost = $Host.UI.RawUI

try {
    # Passo 1: encolher janela para garantir que nao excede o novo buffer
    $minW = [math]::Min($largura, $pshost.WindowSize.Width)
    $minH = [math]::Min($altura, $pshost.WindowSize.Height)
    $pshost.WindowSize = New-Object System.Management.Automation.Host.Size($minW, $minH)

    # Passo 2: definir buffer IGUAL ao tamanho final (sem scrollbars horizontal/vertical)
    $pshost.BufferSize = New-Object System.Management.Automation.Host.Size($largura, $altura)

    # Passo 3: expandir janela para o tamanho final
    $pshost.WindowSize = New-Object System.Management.Automation.Host.Size($largura, $altura)
}
catch {
    # Se falhar (ex: terminal embarcado do VS Code), ignora silenciosamente
}

$hwnd = (Get-Process -Id $PID).MainWindowHandle
if ($hwnd -ne [IntPtr]::Zero) {
    $rect = New-Object Win32+RECT
    [Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    $screenW = [Win32]::GetSystemMetrics(0)
    $screenH = [Win32]::GetSystemMetrics(1)
    $x = [math]::Max(0, ($screenW - $width) / 2)
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
    Log-Step "DOWNLOAD: $NomeProcesso"
    Log-Info "URL: $Url | Destino: $Destino"
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
        $webClient.DownloadFile($Url, $Destino)
        $webClient.Dispose()
        Log-Ok "Download concluido via WebClient: $NomeProcesso"
    }
    catch {
        Log-Warn "WebClient falhou: $($_.Exception.Message) — usando Invoke-WebRequest"
        Write-Host " [Aviso] Usando modo de fallback..." -ForegroundColor DarkGray
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $Destino -UseBasicParsing
        $ProgressPreference = 'Continue'
        Log-Ok "Download concluido via WebRequest: $NomeProcesso"
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
    Log-Step "LIMPEZA DE TEMPORARIOS"
    $lixos = @(
        "$env:TEMP\graalvm.zip",
        "$env:TEMP\PrismSetup.exe",
        "$env:TEMP\SKSetup.exe",
        "$env:TEMP\Modpack-Madness.zip",
        "$env:TEMP\Modpack-Madness.mrpack"
    )
    foreach ($lixo in $lixos) {
        if (Test-Path $lixo) {
            Remove-Item $lixo -Force -Recurse -ErrorAction SilentlyContinue
            Log-Info "Removido: $lixo"
        }
    }
    Get-ChildItem -Path $env:TEMP -Filter "MadnessExtract_*" | ForEach-Object {
        Log-Info "Removido temp: $($_.FullName)"
        Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# ==============================================================================
# EXTRACAO ROBUSTA — entrada-a-entrada, bypassa limite MAX_PATH do Windows
# Resolve: DirectoryNotFoundException em paths longos dentro do ZIP
# Resolve: ZIP com ou sem pasta raiz container
# ==============================================================================
function Extrair-ZipParaPasta ([string]$ZipPath, [string]$DestinoPasta) {
    Log-Step "EXTRACAO ZIP"
    Log-Info "Fonte : $ZipPath"
    Log-Info "Destino: $DestinoPasta"

    # Garantir que a pasta destino existe
    if (-not (Test-Path $DestinoPasta)) {
        New-Item -ItemType Directory -Path $DestinoPasta -Force | Out-Null
        Log-Info "Pasta destino criada: $DestinoPasta"
    }

    $zipStream = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)

    # Detectar se ha pasta raiz unica no ZIP (ex: "Modpack-Madness/mods/...")
    $todasEntradas = $zipStream.Entries
    $prefixoRaiz = ""

    $primeiroDir = ($todasEntradas | Where-Object { $_.FullName -like "*/*" } |
        ForEach-Object { ($_.FullName -split "/")[0] } | Select-Object -Unique)

    if ($primeiroDir.Count -eq 1) {
        # Verificar se TODAS as entradas estao dentro dessa pasta
        $tudoDentro = ($todasEntradas | Where-Object { -not $_.FullName.StartsWith($primeiroDir[0] + "/") }).Count -eq 0
        if ($tudoDentro) {
            $prefixoRaiz = $primeiroDir[0] + "/"
            Log-Warn "ZIP tem pasta raiz unica ('$($primeiroDir[0])'). Sera ignorada na extracao."
        }
    }

    if (-not $prefixoRaiz) {
        Log-Info "ZIP tem estrutura flat. Extraindo direto para destino."
    }

    # Buffer de 1 MB para copia de streams — muito mais rapido que o padrao de 81 KB
    $bufferSize = 1048576

    $erros = 0
    $extraidos = 0

    # Pre-criar todos os diretorios necessarios em batch (evita Test-Path por arquivo)
    $dirs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entrada in $todasEntradas) {
        $ep = $entrada.FullName
        if ($prefixoRaiz -and $ep.StartsWith($prefixoRaiz)) { $ep = $ep.Substring($prefixoRaiz.Length) }
        if ([string]::IsNullOrWhiteSpace($ep) -or $ep.EndsWith("/")) { continue }
        $ep = $ep.Replace("/", "\")
        $dir = Split-Path (Join-Path $DestinoPasta $ep) -Parent
        $dirs.Add($dir) | Out-Null
    }
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            try { New-Item -ItemType Directory -Path "\\?\$dir" -Force | Out-Null }
            catch { New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue | Out-Null }
        }
    }

    foreach ($entrada in $todasEntradas) {
        # Remover prefixo da pasta raiz se existir
        $entryPath = $entrada.FullName
        if ($prefixoRaiz -and $entryPath.StartsWith($prefixoRaiz)) {
            $entryPath = $entryPath.Substring($prefixoRaiz.Length)
        }

        # Entradas vazias (apenas pastas no ZIP) — pular
        if ([string]::IsNullOrWhiteSpace($entryPath) -or $entryPath.EndsWith("/")) {
            continue
        }

        # Montar path de destino — usar separador Windows
        $entryPath = $entryPath.Replace("/", "\")
        $destinoArq = Join-Path $DestinoPasta $entryPath
        $destinoArqL = "\\?\$destinoArq"   # versao long-path para operacoes IO

        # Verificar comprimento total do path (aviso no log, mas continua)
        if ($destinoArq.Length -gt 259) {
            Log-Warn "Path longo ($($destinoArq.Length) chars): $entryPath"
        }

        # Criar pasta pai se nao existir (seguranca, caso o batch acima tenha falhado)
        $pastaDestino = Split-Path $destinoArq -Parent
        if (-not (Test-Path $pastaDestino)) {
            try { New-Item -ItemType Directory -Path "\\?\$pastaDestino" -Force | Out-Null }
            catch { New-Item -ItemType Directory -Path $pastaDestino -Force -ErrorAction SilentlyContinue | Out-Null }
        }

        # Extrair com FileStream buffered (1 MB) + CopyTo com buffer explicito
        try {
            $streamEntrada = $entrada.Open()
            $streamSaida = [System.IO.FileStream]::new(
                $destinoArqL,
                [System.IO.FileMode]::Create,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None,
                $bufferSize,
                $false
            )
            $streamEntrada.CopyTo($streamSaida, $bufferSize)
            $streamSaida.Dispose()
            $streamEntrada.Dispose()
            $extraidos++
        }
        catch {
            # Fallback sem long-path prefix
            try {
                $streamEntrada = $entrada.Open()
                $streamSaida = [System.IO.FileStream]::new(
                    $destinoArq,
                    [System.IO.FileMode]::Create,
                    [System.IO.FileAccess]::Write,
                    [System.IO.FileShare]::None,
                    $bufferSize,
                    $false
                )
                $streamEntrada.CopyTo($streamSaida, $bufferSize)
                $streamSaida.Dispose()
                $streamEntrada.Dispose()
                $extraidos++
                Log-Warn "Extraido sem prefixo long-path: $entryPath"
            }
            catch {
                Log-Erro "Falha ao extrair '$entryPath': $($_.Exception.Message)"
                $erros++
            }
        }
    }

    $zipStream.Dispose()

    # Relatorio da extracao
    Log-Info "Extracao: $extraidos extraidos | $erros erros"

    if ($erros -gt 0) {
        Log-Warn "$erros arquivo(s) nao puderam ser extraidos (paths muito longos ou permissao)."
        Write-Host " [Aviso] $erros arquivo(s) com paths muito longos foram pulados." -ForegroundColor Yellow
        Write-Host " Isso pode afetar texturas de alguns resourcepacks." -ForegroundColor DarkGray
    }

    # Verificar pastas principais
    $pastasEsperadas = @("mods", "resourcepacks", "shaderpacks", "config")
    foreach ($pasta in $pastasEsperadas) {
        $alvo = Join-Path $DestinoPasta $pasta
        if (Test-Path $alvo) {
            $qtd = (Get-ChildItem $alvo -Recurse -File).Count
            Log-Ok "$pasta — $qtd arquivo(s)"
        }
        else {
            Log-Warn "$pasta — pasta NAO encontrada no destino"
        }
    }

    Log-Ok "Extracao concluida. Total: $extraidos arquivos."
}

# ==============================================================================
# LIMPEZA PRE-INSTALACAO — torna o processo deterministico entre runs
# ==============================================================================
function Limpar-PreInstalacao ([string]$DestinoPasta) {
    Log-Step "PRE-LIMPEZA DA PASTA DESTINO"
    Log-Info "Destino: $DestinoPasta"

    $pastasGerenciadas = @("mods", "resourcepacks", "shaderpacks", "config")

    foreach ($pasta in $pastasGerenciadas) {
        $caminho = Join-Path $DestinoPasta $pasta
        if (Test-Path $caminho) {
            Remove-Item -Path $caminho -Recurse -Force -ErrorAction SilentlyContinue
            Log-Info "Pasta limpa: $pasta"
        }
        else {
            Log-Info "Pasta nao existia (ok): $pasta"
        }
    }

    # options.txt tambem e gerenciado pelo modpack
    $optTxt = Join-Path $DestinoPasta "options.txt"
    if (Test-Path $optTxt) {
        Remove-Item -Path $optTxt -Force -ErrorAction SilentlyContinue
        Log-Info "options.txt removido para substituicao"
    }

    Log-Ok "Pre-limpeza concluida."
}

# ==============================================================================
# INJECAO NO instance.cfg DO PRISM — polling com verificacao de estabilidade
# Aguarda o arquivo existir E parar de ser escrito antes de editar
# ==============================================================================
function Injetar-InstanceCfg ([string]$JavaPath, [string]$InstancesDir) {
    Log-Step "INJECAO instance.cfg"

    if (-not $JavaPath) {
        Log-Warn "JavaPath nao fornecido. Pulando injecao do instance.cfg."
        return
    }

    # O Prism usa forward slashes no JavaPath, nao backslashes
    # Ex: C:/Users/Administrator/AppData/Local/GraalVM/jdk-21/bin/javaw.exe
    $JavaPathPrism = $JavaPath.Replace("\", "/")
    Log-Info "JavaPath para Prism (forward slashes): $JavaPathPrism"

    Write-Host "`n Aguardando o Prism criar a instancia..." -ForegroundColor Cyan
    Write-Host " (Importe o modpack no Prism e clique em OK para comecar o download)" -ForegroundColor DarkGray
    Log-Info "Iniciando polling por instance.cfg em: $InstancesDir"

    # FASE 1: aguardar o instance.cfg aparecer
    $timeout = 300
    $elapsed = 0
    $cfgPath = $null

    while ($elapsed -lt $timeout) {
        $candidatos = Get-ChildItem -Path $InstancesDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "instance.cfg") } |
        Sort-Object LastWriteTime -Descending

        if ($candidatos) {
            $cfgPath = Join-Path ($candidatos | Select-Object -First 1 -ExpandProperty FullName) "instance.cfg"
            Log-Ok "instance.cfg detectado: $cfgPath"
            
            # Aqui sim, trazemos a atencao de volta pro instalador
            Chamar-Atencao
            Write-Host "`n [!] Importacao detectada! O instalador vai assumir a partir daqui." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            
            # Capturar o caminho exato do executavel para poder reabrir depois (WMI e mais seguro)
            $cimProc = Get-CimInstance Win32_Process -Filter "Name = 'prismlauncher.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cimProc) {
                $script:PrismReabrirPath = $cimProc.ExecutablePath
                Log-Info "Caminho do Prism capturado via CIM: $($script:PrismReabrirPath)"
            }
            
            Write-Host " [!] Fechando o Prism Launcher automaticamente para aplicar configuracoes." -ForegroundColor Yellow
            Log-Info "Encerrando processo prismlauncher..."
            Get-Process -Name "prismlauncher" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            
            # Dar tempo para o sistema liberar o arquivo
            Start-Sleep -Seconds 1
            break
        }

        Start-Sleep -Seconds 3
        $elapsed += 3
        Write-Host "`r Aguardando Prism criar a instancia... ($elapsed s) " -NoNewline -ForegroundColor DarkGray
    }

    Write-Host ""

    if (-not $cfgPath) {
        Log-Erro "Timeout ($timeout s): nenhum instance.cfg encontrado."
        Write-Host " [AVISO] Configuracao automatica do Java nao foi possivel." -ForegroundColor Yellow
        Write-Host " Configure manualmente: Instancia > Edit > Settings > Java > Java executable" -ForegroundColor White
        Write-Host " Caminho: $JavaPath" -ForegroundColor DarkGray
        Copiar-ParaClipboard $JavaPath | Out-Null
        return
    }

    # FASE 2: ler e editar o instance.cfg linha a linha
    # NAO usar -replace para substituir valores — o PowerShell trata \ como escape
    # de regex na string de substituicao: "C:\Users" vira "C:sers" etc.
    # Processamento linha a linha e seguro e previsivel.
    $cfgContent = Get-Content $cfgPath -Raw -ErrorAction SilentlyContinue
    if (-not $cfgContent) { $cfgContent = "" }
    Log-Info "Conteudo original:`n$cfgContent"

    # Flags que precisamos garantir — chave => valor final desejado
    $flags = [ordered]@{
        "JavaPath"                = $JavaPathPrism
        "IgnoreJavaCompatibility" = "true"
        "OverrideJavaLocation"    = "true"
        "AutomaticJava"           = "false"
    }
    $flagsEncontradas = @{}

    $novasLinhas = foreach ($linha in ($cfgContent -split "`r?`n")) {
        $substituido = $false
        foreach ($chave in $flags.Keys) {
            if ($linha -match "^$chave=") {
                $flagsEncontradas[$chave] = $true
                "$chave=$($flags[$chave])"   # sem -replace, valor literal direto
                $substituido = $true
                Log-Info "Substituido: $chave=$($flags[$chave])"
                break
            }
        }
        if (-not $substituido) { $linha }
    }

    # Adicionar flags que nao existiam no arquivo original
    # Inseri-las na secao [General] logo apos a linha "[General]"
    $flagsFaltando = $flags.Keys | Where-Object { -not $flagsEncontradas[$_] }
    if ($flagsFaltando) {
        $linhasComInsert = [System.Collections.Generic.List[string]]::new()
        foreach ($linha in $novasLinhas) {
            $linhasComInsert.Add($linha)
            if ($linha.Trim() -eq "[General]") {
                foreach ($chave in $flagsFaltando) {
                    $linhasComInsert.Add("$chave=$($flags[$chave])")
                    Log-Warn "$chave nao existia — adicionado apos [General]."
                }
            }
        }
        $novasLinhas = $linhasComInsert
    }

    $cfgFinal = ($novasLinhas | Where-Object { $null -ne $_ }) -join "`n"
    Set-Content -Path $cfgPath -Value $cfgFinal.TrimEnd() -Encoding UTF8 -NoNewline
    Log-Ok "instance.cfg gravado."

    # Log do resultado para conferencia
    Log-Info "Conteudo final:`n$(Get-Content $cfgPath -Raw)"

    Write-Host "`n [OK] Java 21 configurado automaticamente na instancia!" -ForegroundColor Green
    Write-Host "      JavaPath  : $JavaPathPrism" -ForegroundColor DarkGray
    Write-Host "      Override  : true | AutomaticJava: false" -ForegroundColor DarkGray
}

# ==============================================================================
# GERAR launcher_profiles.json PARA SKLAUNCHER
# Formato compativel com o que o SKLauncher espera e gera
# ==============================================================================
function Gerar-LauncherProfiles ([string]$McDir, [string]$JavaPath) {
    Log-Step "GERANDO launcher_profiles.json"

    $profilePath = Join-Path $McDir "launcher_profiles.json"
    $profileId = [guid]::NewGuid().ToString("N")
    $agora = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

    # Escapar o JavaPath para JSON (barras invertidas)
    $javaDirJson = ""
    if ($JavaPath) {
        $javaDirJson = ",`n      `"javaDir`": `"$($JavaPath.Replace('\','\\'))`""
        Log-Info "javaDir incluido: $JavaPath"
    }
    else {
        Log-Warn "JavaPath nulo. javaDir nao incluido no perfil."
    }

    # Construir JSON manualmente — formato identico ao que o SKLauncher gera
    # Isso evita a indentacao estranha do ConvertTo-Json do PowerShell 5
    $json = @"
{
  "profiles": {
    "$profileId": {
      "name": "ModpackMadness",
      "lastVersionId": "fabric-loader-0.19.2-1.20.1",
      "type": "custom",
      "icon": "Grass",
      "created": "$agora",
      "lastUsed": "$agora"$javaDirJson
    }
  },
  "selectedProfile": "$profileId",
  "settings": {
    "profileSorting": "byName"
  },
  "version": 6
}
"@

    Set-Content -Path $profilePath -Value $json -Encoding UTF8 -NoNewline
    Log-Ok "launcher_profiles.json gerado em: $profilePath"
    Log-Info "Conteudo:`n$json"
}

# ==============================================================================
# INICIO
# ==============================================================================
Limpar-Temporarios

$DiscoC = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$EspacoLivreGB = [math]::Round($DiscoC.FreeSpace / 1GB, 2)
Log-Info "Espaco livre em C: $EspacoLivreGB GB"

if ($EspacoLivreGB -lt 3.0) {
    Log-Erro "Espaco insuficiente: $EspacoLivreGB GB (minimo 3 GB)"
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

    $optJava = Ler-Opcao @('1', '2')
    Log-Step "PASSO 1 - JAVA"
    Log-Info "Opcao escolhida: $optJava"

    if ($optJava -eq '1') {
        Write-Host "`n"
        $javaDir = "$env:LOCALAPPDATA\GraalVM"
        $javawPath = Get-ChildItem -Path $javaDir -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

        if ($javawPath) {
            Write-Host " [OK] Java 21 ja detectado!" -ForegroundColor Green
            Log-Ok "Java 21 ja instalado: $javawPath"
        }
        else {
            Log-Info "Java nao encontrado. Iniciando download."
            $javaZip = "$env:TEMP\graalvm.zip"
            Baixar-Arquivo $LinkJava $javaZip "Baixando GraalVM 21..." "JAVA 21"

            Write-Host " Extraindo..." -ForegroundColor Cyan
            Log-Step "EXTRACAO JAVA"
            if (Test-Path $javaDir) {
                Remove-Item "$javaDir\*" -Recurse -Force -ErrorAction SilentlyContinue
                Log-Info "Pasta GraalVM limpa antes da extracao."
            }
            New-Item -ItemType Directory -Path $javaDir -Force | Out-Null
            [System.IO.Compression.ZipFile]::ExtractToDirectory($javaZip, $javaDir)

            $pastaOriginal = Get-ChildItem -Path $javaDir -Directory | Select-Object -First 1
            if ($pastaOriginal) {
                Rename-Item -Path $pastaOriginal.FullName -NewName "jdk-21"
                Log-Info "Pasta renomeada de '$($pastaOriginal.Name)' para 'jdk-21'"
            }

            $javawPath = Get-ChildItem -Path $javaDir -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

            if ($javawPath) {
                Log-Ok "javaw.exe encontrado: $javawPath"
            }
            else {
                Log-Erro "javaw.exe NAO encontrado apos extracao. Verifique o zip do Java."
            }
        }
        Chamar-Atencao
        Aguardar-Pulo 2
    }
    else {
        # Tentar detectar Java instalado automaticamente mesmo sem baixar
        $javaDir = "$env:LOCALAPPDATA\GraalVM"
        $javawDetect = Get-ChildItem -Path $javaDir -Filter "javaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        if ($javawDetect) {
            $javawPath = $javawDetect
            Write-Host " [OK] Java detectado automaticamente: $javawPath" -ForegroundColor DarkGray
            Log-Ok "Java detectado via GraalVM (opcao 'Ja tenho'): $javawPath"
        }
        else {
            Log-Info "Java nao localizado automaticamente. Configuracao manual necessaria."
        }
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

    $optLauncher = Ler-Opcao @('1', '2', 'v')
    if ($optLauncher -eq 'v') { Log-Info "Usuario voltou do passo 2."; continue }
    $LauncherType = if ($optLauncher -eq '1') { "PRISM" } else { "SKLAUNCHER" }
    Log-Step "PASSO 2 - LAUNCHER: $LauncherType"

    # ----------------------------------------------------------
    # PASSO 3: INSTALACAO LAUNCHER
    # ----------------------------------------------------------
    Mostrar-Cabecalho
    Write-Host " [ 3/3: INSTALANDO $LauncherType ]" -ForegroundColor Yellow

    $launcherAchado = $false
    $ModoManual = $false
    $prismExeLocal = "$env:LOCALAPPDATA\Programs\PrismLauncher\prismlauncher.exe"
    $skExeLocal = "$env:LOCALAPPDATA\Programs\sklauncher\SKlauncher.exe"
    $PastaDownloads = "$([Environment]::GetFolderPath('UserProfile'))\Downloads"
    $mcDir = "$env:APPDATA\.minecraft"

    Log-Info "Verificando launcher existente..."
    Log-Info "prismExeLocal: $prismExeLocal (existe: $(Test-Path $prismExeLocal))"
    Log-Info "skExeLocal: $skExeLocal (existe: $(Test-Path $skExeLocal))"
    Log-Info "mcDir: $mcDir"

    if ($LauncherType -eq "PRISM" -and (Test-Path $prismExeLocal)) {
        $launcherAchado = $true
        Log-Ok "Prism encontrado em: $prismExeLocal"
    }
    elseif ($LauncherType -eq "SKLAUNCHER" -and (
            (Test-Path $skExeLocal) -or
            (Test-Path "$env:APPDATA\.minecraft\SKlauncher.exe") -or
            (Test-Path "$env:APPDATA\sklauncher")
        )) {
        $launcherAchado = $true
        Log-Ok "SKLauncher encontrado."
    }

    if ($launcherAchado) {
        Write-Host "`n $LauncherType detectado! Avancando..." -ForegroundColor Green
        Aguardar-Pulo 2
        $baixarLauncher = '2'   # '2' = usar existente (portable/instalado)
        Log-Info "Launcher ja instalado. Pulando download."
    }
    else {
        Chamar-Atencao
        Write-Host "`n O $LauncherType nao foi detectado. Como deseja prosseguir?`n" -ForegroundColor White
        Write-Host " [ 1 ] Instalar $LauncherType (instalacao limpa)." -ForegroundColor Green
        Write-Host " [ 2 ] Usar versao local (Portable/outra pasta)." -ForegroundColor DarkGray
        Write-Host " [ V ] Voltar" -ForegroundColor Gray
        Write-Host "`n Opcao: " -NoNewline -ForegroundColor Cyan

        $baixarLauncher = Ler-Opcao @('1', '2', 'v')
        if ($baixarLauncher -eq 'v') { Log-Info "Usuario voltou do passo 3."; continue }

        if ($baixarLauncher -eq '2') {
            $ModoManual = $true
            Log-Info "Modo manual ativado."
            Write-Host "`n Ok! Os arquivos do modpack serao salvos na sua pasta Downloads." -ForegroundColor Yellow
            Aguardar-Pulo 3
        }
    }

    if ($baixarLauncher -eq '1') {
        if ($LauncherType -eq "PRISM") {
            $prismSetup = "$env:TEMP\PrismSetup.exe"
            Baixar-Arquivo $LinkPrism $prismSetup "`nBaixando Prism Launcher..." "PRISM LAUNCHER"
            Mostrar-AvisoFoco "Na ultima tela, DESMARQUE a caixa 'Run Prism Launcher' e conclua!"
            Log-Step "INSTALANDO PRISM LAUNCHER"
            Start-Process -FilePath $prismSetup -Wait
            Log-Ok "Instalador do Prism concluido."
        }
        else {
            $skSetup = "$env:TEMP\SKSetup.exe"
            Baixar-Arquivo $LinkSK $skSetup "`nBaixando SKLauncher..." "SK LAUNCHER"
            Mostrar-AvisoFoco "Na ultima tela, DESMARQUE 'Launch SKlauncher' e finalize!"
            Log-Step "INSTALANDO SKLAUNCHER"
            Start-Process -FilePath $skSetup -Wait
            Log-Ok "Instalador do SKLauncher concluido."
        }
        Chamar-Atencao
    }

    # ----------------------------------------------------------
    # PASSO 4: MODPACK
    # ----------------------------------------------------------
    Mostrar-Cabecalho
    Write-Host " [ INSTALANDO O MODPACK ]" -ForegroundColor Yellow
    Log-Step "PASSO 4 - INSTALACAO DO MODPACK ($LauncherType)"

    if ($LauncherType -eq "PRISM") {
        $mrpackPath = if ($ModoManual) { "$PastaDownloads\Modpack-Madness.mrpack" } else { "$env:TEMP\Modpack-Madness.mrpack" }
        Baixar-Arquivo $LinkMrpack $mrpackPath "`nBaixando modpack (.mrpack)..." "MODPACK MADNESS"

        Log-Info "Abrindo .mrpack no Prism..."
        Write-Host " Abrindo modpack no Prism..." -ForegroundColor Cyan

        if ($ModoManual) {
            Start-Process cmd.exe -ArgumentList "/c start `"`" `"$mrpackPath`"" -WindowStyle Hidden
            Log-Info "Aberto via associacao de arquivo (modo manual)."
        }
        else {
            Start-Process cmd.exe -ArgumentList "/c start `"`" `"$prismExeLocal`" `"$mrpackPath`"" -WindowStyle Hidden
            Log-Info "Aberto via Prism exe: $prismExeLocal"
        }

    }
    elseif ($LauncherType -eq "SKLAUNCHER") {
        $modpackZip = "$env:TEMP\Modpack-Madness.zip"
        Baixar-Arquivo $LinkZip $modpackZip "`nBaixando mods (.zip)..." "MODS MADNESS"

        if ($ModoManual) {
            $mcDir = "$PastaDownloads\Modpack-Madness-Mods"
            Log-Info "Modo manual: destino alterado para $mcDir"
        }

        Write-Host " Preparando pasta de destino..." -ForegroundColor Cyan

        # FIX: limpeza pre-instalacao para determinismo entre runs
        Limpar-PreInstalacao $mcDir

        Write-Host " Extraindo arquivos..." -ForegroundColor Cyan

        # FIX: extracao robusta que resolve ZIP com/sem pasta raiz
        Extrair-ZipParaPasta $modpackZip $mcDir

        # Gerar launcher_profiles.json automaticamente
        Gerar-LauncherProfiles $mcDir $javawPath
    }

    # ----------------------------------------------------------
    # TELA FINAL
    # ----------------------------------------------------------
    Clear-Host
    Mostrar-Cabecalho
    
    # IMPORTANTE: NAO chamamos 'Chamar-Atencao' aqui incondicionalmente,
    # porque a janela do Prism acabou de ser aberta no passo anterior
    # e precisa ficar em foco para o usuario clicar em 'OK'.

    Write-Host "==============================================================================" -ForegroundColor Green
    Write-Host "                    INSTALACAO CONCLUIDA COM SUCESSO!" -ForegroundColor Green
    Write-Host "==============================================================================`n" -ForegroundColor Green

    Log-Step "INSTALACAO CONCLUIDA"

    if ($LauncherType -eq "PRISM") {
        Write-Host " O Prism abriu a janela de importacao de modpack." -ForegroundColor Cyan
        Write-Host " Certifique-se que ela esta selecionada e clique em 'OK' para iniciar." -ForegroundColor White

        if ($javawPath) {
            Log-Info "Iniciando injecao automatica do instance.cfg com polling."
            $instancesDir = "$env:APPDATA\PrismLauncher\instances"
            Injetar-InstanceCfg $javawPath $instancesDir
            
            Write-Host "`n Reabrindo o Prism Launcher..." -ForegroundColor Cyan
            $alvoPrism = $null
            if ($script:PrismReabrirPath -and (Test-Path $script:PrismReabrirPath)) { $alvoPrism = $script:PrismReabrirPath }
            elseif ($prismExeLocal -and (Test-Path $prismExeLocal)) { $alvoPrism = $prismExeLocal }
            
            if ($alvoPrism) {
                Start-Process $alvoPrism
                Log-Ok "Prism reaberto via: $alvoPrism"
            }
            else {
                Log-Warn "Nenhum executavel do Prism encontrado para reabrir."
            }

            # Ocultar janela do PowerShell — o Prism ja esta rodando de forma independente
            $hwndPS = (Get-Process -Id $PID).MainWindowHandle
            if ($hwndPS -ne [IntPtr]::Zero) { [Win32]::ShowWindow($hwndPS, 0) | Out-Null }
        }
        else {
            Log-Warn "javawPath nulo. Injecao do instance.cfg pulada."
            Chamar-Atencao
            Write-Host "`n [ATENCAO] Java nao configurado automaticamente." -ForegroundColor Yellow
            Write-Host "           Apos importar o modpack, configure manualmente no Prism:" -ForegroundColor White
            Write-Host "           ⋮ > Edit installation > More Options> Java Executable"-ForegroundColor DarkGray
            Write-Host "           Aponte para o javaw.exe do Java 21 instalado no seu PC.`n" -ForegroundColor DarkGray
            Start-Sleep -Seconds 5
        }
    }
    else {
        # SKLauncher
        if ($javawPath) {
            Write-Host " Java detectado: $javawPath" -ForegroundColor Cyan
            Write-Host " Configure o caminho abaixo no SKLauncher:" -ForegroundColor White
            Write-Host " ⋮ > Editar > Java Executable`n" -ForegroundColor White
            Write-Host " $javawPath`n" -ForegroundColor DarkGray
            Copiar-ParaClipboard $javawPath | Out-Null
            Write-Host " (Caminho copiado para a area de transferencia. Use WIN+V para colar.)" -ForegroundColor Gray
            Log-Ok "Caminho Java copiado para clipboard: $javawPath"
        }
        else {
            Chamar-Atencao
            Write-Host "`n [ATENCAO] Java nao configurado automaticamente." -ForegroundColor Yellow
            Write-Host "           Configure manualmente no SKLauncher:" -ForegroundColor White
            Write-Host "           Configuracoes > Java > Java Executable" -ForegroundColor DarkGray
            Write-Host "           Aponte para o javaw.exe do Java 21 instalado no seu PC.`n" -ForegroundColor DarkGray
            Log-Warn "javawPath nulo. Configuracao manual necessaria no SKLauncher."
        }

        Write-Host "`n[OK] launcher_profiles.json gerado em:" -ForegroundColor Cyan
        Write-Host "     $mcDir\launcher_profiles.json`n" -ForegroundColor DarkGray

        Aguardar-Pulo 3

        $skCaminhos = @(
            "$env:LOCALAPPDATA\Programs\sklauncher\SKlauncher.exe",
            "$env:APPDATA\.minecraft\SKlauncher.exe",
            "$([Environment]::GetFolderPath('Desktop'))\SKlauncher.lnk"
        )
        foreach ($c in $skCaminhos) {
            if (Test-Path $c) {
                Log-Info "Abrindo SKLauncher: $c"
                Start-Process $c
                break
            }
        }

        if ($ModoManual) {
            Write-Host " Abrindo a pasta de destino..." -ForegroundColor Gray
            Start-Process explorer.exe $mcDir
        }

        # Ocultar janela do PowerShell — o SKLauncher ja esta rodando de forma independente
        $hwndPS = (Get-Process -Id $PID).MainWindowHandle
        if ($hwndPS -ne [IntPtr]::Zero) { [Win32]::ShowWindow($hwndPS, 0) | Out-Null }
    }

    Log-Step "FIM DO INSTALADOR"
    Limpar-Temporarios

    if ($LogAtivado) {
        Write-Host "`n Log salvo em: $LogPath" -ForegroundColor DarkGray
    }

    Log-Ok "Instalador encerrado."
    exit
}