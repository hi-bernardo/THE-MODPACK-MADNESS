#!/bin/bash
# ==============================================================================
# INSTALL MADNESS - LINUX EDITION
# ==============================================================================

# Cores para o terminal
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
WHITE='\033[1;37m'
GRAY='\033[1;30m'
NC='\033[0m' # No Color

# ==============================================================================
# CONFIGURACOES E LINKS
# ==============================================================================
LinkMrpack="https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1/Modpack-Madness.mrpack"
LinkZip="https://github.com/hi-bernardo/THE-MODPACK-MADNESS/releases/download/v1/Modpack-Madness.zip"
LinkJavaX64="https://download.oracle.com/graalvm/21/latest/graalvm-jdk-21_linux-x64_bin.tar.gz"
LinkJavaARM="https://download.oracle.com/graalvm/21/latest/graalvm-jdk-21_linux-aarch64_bin.tar.gz"
LinkSKLauncher="https://skmedix.pl/binaries/skl/3.2.18/SKlauncher-3.2.18.jar"

# Diretórios padrão do Linux
MC_DIR="$HOME/.minecraft"
GRAALVM_DIR="$HOME/.local/share/GraalVM"
TEMP_DIR="/tmp/madness_install"

# ==============================================================================
# SISTEMA DE LOG
# ==============================================================================
LogAtivado=true
LogPath="$PWD/install_madness_log.txt"

function Log-Msg() {
    if [ "$LogAtivado" = true ]; then
        local nivel="$1"
        local msg="$2"
        local ts=$(date "+%Y-%m-%d %H:%M:%S")
        echo "[$ts] [$nivel] $msg" >> "$LogPath"
    fi
}

function Log-Info() { Log-Msg "INFO " "$1"; }
function Log-Warn() { Log-Msg "WARN " "$1"; }
function Log-Erro() { Log-Msg "ERRO " "$1"; }
function Log-Step() { Log-Msg "STEP " "=== $1 ==="; }
function Log-Ok()   { Log-Msg "OK   " "$1"; }

if [ "$LogAtivado" = true ]; then
    echo "================================================================================" > "$LogPath"
    echo "  LOG - THE MODPACK MADNESS INSTALLER (LINUX)" >> "$LogPath"
    echo "  Data: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LogPath"
    echo "  Usuario: $USER | Distro: $(cat /etc/os-release | grep -E '^PRETTY_NAME=' | cut -d '=' -f 2 | tr -d '\"')" >> "$LogPath"
    echo "================================================================================" >> "$LogPath"
fi

Log-Step "INICIO DO INSTALADOR LINUX"

# ==============================================================================
# FUNCOES DE INTERFACE E UX
# ==============================================================================
function Mostrar-Cabecalho() {
    clear
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${GREEN}        ____                                     _        _    ____       ${NC}"
    echo -e "${GREEN}   ___ | __ ) _ __ __ _ _______   ___           | |      / \  | __ ) ___  ${NC}"
    echo -e "${GREEN}  / _ \|  _ \| '__/ _\` |_  / _ \ / _ \   _____  | |     / _ \ |  _ \/ __| ${NC}"
    echo -e "${GREEN} | (_) | |_) | | | (_| |/ / (_) | (_) | |_____| | |___ / ___ \| |_) \__ \ ${NC}"
    echo -e "${GREEN}  \___/|____/|_|  \__,_/___\___/ \___/          |_____/_/   \_\____/|___/ ${NC}"
    echo ""
    echo -e "${CYAN}==============================================================================${NC}"
    echo ""
}

function Chamar-Atencao() {
    # Tenta tocar um som no terminal e piscar se possível
    echo -ne '\007'
}

function Aguardar-Pulo() {
    local Segundos=$1
    for ((i=$Segundos; i>0; i--)); do
        echo -ne "\r${GRAY} Aguardando $i s... (Pressione Enter para pular) ${NC}"
        # Espera 1 segundo pela tecla Enter (-t 1)
        read -t 1 -s -n 1 key
        if [ $? -eq 0 ]; then
            break
        fi
    done
    echo -ne "\r                                                              \r"
}

function Mostrar-AvisoFoco() {
    Chamar-Atencao
    clear
    echo -e "\n\n\n   ${RED}========================================================================${NC}"
    echo -e "   ${YELLOW}                           AVISO IMPORTANTE!                            ${NC}"
    echo -e "   ${RED}========================================================================${NC}"
    echo -e "\n     ${WHITE}$1\n${NC}"
    echo -e "   ${RED}========================================================================\n${NC}"
    Aguardar-Pulo 5
}

# ==============================================================================
# VERIFICACAO DE DEPENDENCIAS E GERENCIADOR DE PACOTES
# ==============================================================================
PKG_MANAGER=""
INSTALL_CMD=""

function Detectar-PkgManager() {
    Log-Step "DETECCAO DE GERENCIADOR DE PACOTES"
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        INSTALL_CMD="sudo apt-get install -y"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        INSTALL_CMD="sudo dnf install -y"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        INSTALL_CMD="sudo pacman -S --noconfirm"
    else
        PKG_MANAGER="unknown"
        Log-Warn "Gerenciador de pacotes nao suportado nativamente."
    fi
    Log-Info "Gerenciador de pacotes detectado: $PKG_MANAGER"
}

function Verificar-Dependencias() {
    Log-Step "VERIFICANDO DEPENDENCIAS"
    local deps=("curl" "unzip" "tar" "jq")
    local faltantes=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            faltantes+=("$dep")
        fi
    done

    if [ ${#faltantes[@]} -ne 0 ]; then
        Mostrar-Cabecalho
        echo -e " ${YELLOW}[ATENCAO] Algumas ferramentas essenciais estao faltando no seu sistema.${NC}"
        echo -e " Ferramentas: ${WHITE}${faltantes[*]}${NC}"
        echo ""
        
        if [ "$PKG_MANAGER" != "unknown" ]; then
            echo -e " ${CYAN}Tentando instalar automaticamente usando '$PKG_MANAGER'...${NC}"
            echo -e " ${GRAY}Pode ser que o sistema peca a sua senha de usuario.${NC}"
            Log-Info "Instalando dependencias: ${faltantes[*]}"
            $INSTALL_CMD "${faltantes[@]}"
            
            # Verificar novamente
            for dep in "${faltantes[@]}"; do
                if ! command -v "$dep" >/dev/null 2>&1; then
                    echo -e " ${RED}[ERRO] Falha ao instalar '$dep'. Instale manualmente e tente de novo.${NC}"
                    Log-Erro "Falha ao instalar dependencia critica: $dep"
                    exit 1
                fi
            done
            Log-Ok "Dependencias instaladas com sucesso."
        else
            echo -e " ${RED}[ERRO] Nao foi possivel instalar automaticamente.${NC}"
            echo -e " Por favor, instale estas ferramentas manualmente: ${faltantes[*]}"
            Log-Erro "Dependencias faltando e gerenciador desconhecido."
            exit 1
        fi
    else
        Log-Ok "Todas dependencias criticas estao presentes."
    fi
}

Detectar-PkgManager
Verificar-Dependencias

mkdir -p "$TEMP_DIR"

# ==============================================================================
# PASSO 1: JAVA 21 (GRAALVM)
# ==============================================================================
Mostrar-Cabecalho
echo -e " ${YELLOW}[ 1/3: JAVA 21 GRAALVM ]${NC}"
echo -e " O Modpack necessita do Java 21 para rodar com a melhor performance.\n"
echo -e " ${GREEN}[ 1 ] Baixar e configurar automaticamente (Recomendado)${NC}"
echo -e " ${GRAY}[ 2 ] Ja tenho Java 21 instalado / Configurarei manualmente${NC}"
echo -ne "\n ${CYAN}Opcao: ${NC}"

read -n 1 optJava
echo ""

javawPath=""

if [ "$optJava" == "1" ]; then
    Log-Step "PASSO 1 - JAVA: Baixar automaticamente"
    
    # Detectar Arquitetura
    ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        Log-Info "Arquitetura detectada: ARM64"
        LinkJavaReal="$LinkJavaARM"
    else
        Log-Info "Arquitetura detectada: x86_64"
        LinkJavaReal="$LinkJavaX64"
    fi

    echo -e " ${CYAN}Baixando GraalVM 21...${NC}"
    curl -L -s -o "$TEMP_DIR/graalvm.tar.gz" "$LinkJavaReal"
    
    echo -e " ${CYAN}Extraindo GraalVM...${NC}"
    mkdir -p "$GRAALVM_DIR"
    tar -xzf "$TEMP_DIR/graalvm.tar.gz" -C "$GRAALVM_DIR"
    
    # Descobrir a subpasta (ex: graalvm-jdk-21.0.2+13.1)
    JavaSubDir=$(ls -1 "$GRAALVM_DIR" | grep -i graalvm | head -n 1)
    javawPath="$GRAALVM_DIR/$JavaSubDir/bin/java"
    
    if [ -f "$javawPath" ]; then
        echo -e " ${GREEN}[OK] Java configurado em: $javawPath${NC}"
        Log-Ok "Java extraido e detectado: $javawPath"
    else
        Log-Erro "Nao foi possivel encontrar o executavel Java apos extracao."
        javawPath=""
    fi
    Aguardar-Pulo 2
else
    Log-Info "Usuario optou por Java manual."
    # Tentar autodetectar o GraalVM previamente instalado pelo script
    if [ -d "$GRAALVM_DIR" ]; then
        JavaSubDir=$(ls -1 "$GRAALVM_DIR" 2>/dev/null | grep -i graalvm | head -n 1)
        if [ -n "$JavaSubDir" ] && [ -f "$GRAALVM_DIR/$JavaSubDir/bin/java" ]; then
            javawPath="$GRAALVM_DIR/$JavaSubDir/bin/java"
            echo -e " ${GRAY}[OK] Java detectado automaticamente: $javawPath${NC}"
            Log-Ok "Java detectado automaticamente na pasta local."
        fi
    fi
    Aguardar-Pulo 2
fi

# ==============================================================================
# PASSO 2: LAUNCHER
# ==============================================================================
Mostrar-Cabecalho
Chamar-Atencao
echo -e " ${YELLOW}[ 2/3: LAUNCHER ]${NC}"
echo -e "\n ${GREEN}[ 1 ] Prism Launcher (Conta Original)${NC}"
echo -e " ${GREEN}[ 2 ] SKLauncher     (Sem Conta / Pirata)${NC}"
echo -ne "\n ${CYAN}Opcao: ${NC}"

read -n 1 optLauncher
echo ""

LauncherType="PRISM"
if [ "$optLauncher" == "2" ]; then
    LauncherType="SKLAUNCHER"
fi
Log-Step "PASSO 2 - LAUNCHER: $LauncherType"

# ==============================================================================
# PASSO 3: INSTALACAO LAUNCHER
# ==============================================================================
Mostrar-Cabecalho
echo -e " ${YELLOW}[ 3/3: INSTALANDO $LauncherType ]${NC}"

baixarLauncher="1"
PRISM_CMD=""
PRISM_IS_FLATPAK=false

if [ "$LauncherType" == "PRISM" ]; then
    Log-Info "Verificando se o PrismLauncher ja esta instalado..."
    
    if command -v prismlauncher >/dev/null 2>&1; then
        echo -e "\n ${GREEN}Prism Launcher nativo detectado!${NC}"
        PRISM_CMD="prismlauncher"
        baixarLauncher="2"
    elif command -v flatpak >/dev/null 2>&1 && flatpak list | grep -q org.prismlauncher.PrismLauncher; then
        echo -e "\n ${GREEN}Prism Launcher (Flatpak) detectado!${NC}"
        PRISM_CMD="flatpak run org.prismlauncher.PrismLauncher"
        PRISM_IS_FLATPAK=true
        baixarLauncher="2"
    else
        Chamar-Atencao
        echo -e "\n ${WHITE}O Prism Launcher nao foi detectado. Como deseja prosseguir?${NC}\n"
        echo -e " ${GREEN}[ 1 ] Instalar Prism Launcher (Automatico)${NC}"
        echo -e " ${GRAY}[ 2 ] Usar versao ja instalada (Pularei a instalacao)${NC}"
        echo -ne "\n ${CYAN}Opcao: ${NC}"
        read -n 1 baixarLauncher
        echo ""
    fi

    if [ "$baixarLauncher" == "1" ]; then
        Log-Info "Tentando instalar PrismLauncher nativamente..."
        echo -e " ${CYAN}Instalando Prism Launcher...${NC}"
        
        # Tentar instalacao nativa primeiro
        if [ "$PKG_MANAGER" != "unknown" ]; then
            $INSTALL_CMD prismlauncher
        fi
        
        # Se nativo falhar, tentar Flatpak
        if ! command -v prismlauncher >/dev/null 2>&1; then
            Log-Warn "Instalacao nativa falhou ou nao disponivel. Tentando via Flatpak..."
            if command -v flatpak >/dev/null 2>&1; then
                flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
                flatpak install -y flathub org.prismlauncher.PrismLauncher
                PRISM_CMD="flatpak run org.prismlauncher.PrismLauncher"
                PRISM_IS_FLATPAK=true
                Log-Ok "Prism instalado via Flatpak."
            else
                echo -e " ${RED}[ERRO] Nao foi possivel instalar o Prism Launcher automaticamente.${NC}"
                echo -e " Instale manualmente a partir do site: https://prismlauncher.org/download/linux/"
                exit 1
            fi
        else
            PRISM_CMD="prismlauncher"
            Log-Ok "Prism instalado via $PKG_MANAGER nativo."
        fi
    fi

elif [ "$LauncherType" == "SKLAUNCHER" ]; then
    SK_JAR_DIR="$HOME/.minecraft"
    SK_JAR_PATH="$SK_JAR_DIR/SKlauncher.jar"
    
    mkdir -p "$SK_JAR_DIR"
    
    if [ -f "$SK_JAR_PATH" ]; then
        echo -e "\n ${GREEN}SKLauncher detectado! ($SK_JAR_PATH)${NC}"
        baixarLauncher="2"
    else
        Chamar-Atencao
        echo -e "\n ${WHITE}O SKLauncher nao foi detectado. Como deseja prosseguir?${NC}\n"
        echo -e " ${GREEN}[ 1 ] Baixar SKLauncher (Instalacao Limpa)${NC}"
        echo -e " ${GRAY}[ 2 ] Pular (Usarei um que ja tenho)${NC}"
        echo -ne "\n ${CYAN}Opcao: ${NC}"
        read -n 1 baixarLauncher
        echo ""
    fi

    if [ "$baixarLauncher" == "1" ]; then
        echo -e " ${CYAN}Baixando SKLauncher...${NC}"
        curl -L -s -o "$SK_JAR_PATH" "$LinkSKLauncher"
        Log-Ok "SKLauncher baixado para $SK_JAR_PATH"
        
        # Criar atalho Desktop para o Linux
        echo -e " ${CYAN}Criando atalho no menu de aplicativos...${NC}"
        DESKTOP_DIR="$HOME/.local/share/applications"
        mkdir -p "$DESKTOP_DIR"
        
        # Para rodar o SKLauncher, usa o java extraido (se houver) ou java do sistema
        EXEC_CMD="java -jar $SK_JAR_PATH"
        if [ -n "$javawPath" ]; then
            EXEC_CMD="$javawPath -jar $SK_JAR_PATH"
        fi
        
        cat <<EOF > "$DESKTOP_DIR/sklauncher.desktop"
[Desktop Entry]
Name=SKLauncher
Comment=Minecraft Launcher
Exec=$EXEC_CMD
Icon=minecraft
Terminal=false
Type=Application
Categories=Game;
EOF
        chmod +x "$DESKTOP_DIR/sklauncher.desktop"
        # Atualiza a base de dados de aplicativos do Linux (se o comando existir)
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database "$DESKTOP_DIR"
        fi
        Log-Ok "Atalho sklauncher.desktop criado em $DESKTOP_DIR"
    fi
fi

# ==============================================================================
# PASSO 4: MODPACK
# ==============================================================================
Mostrar-Cabecalho
echo -e " ${YELLOW}[ INSTALANDO O MODPACK ]${NC}"
Log-Step "PASSO 4 - INSTALACAO DO MODPACK ($LauncherType)"

if [ "$LauncherType" == "PRISM" ]; then
    MRPACK_PATH="$TEMP_DIR/Modpack-Madness.mrpack"
    echo -e " ${CYAN}Baixando modpack (.mrpack)...${NC}"
    curl -L -s -o "$MRPACK_PATH" "$LinkMrpack"
    Log-Ok "Modpack baixado em: $MRPACK_PATH"
    
    echo -e " ${CYAN}Abrindo modpack no Prism...${NC}"
    # O Prism Launcher sabe como abrir e importar arquivos .mrpack
    if [ "$PRISM_IS_FLATPAK" = true ]; then
        flatpak run org.prismlauncher.PrismLauncher "$MRPACK_PATH" &
    else
        $PRISM_CMD "$MRPACK_PATH" &
    fi
    Log-Info "Prism Launcher aberto com o .mrpack."
    
elif [ "$LauncherType" == "SKLAUNCHER" ]; then
    MODPACK_ZIP="$TEMP_DIR/Modpack-Madness.zip"
    echo -e " ${CYAN}Baixando mods (.zip)...${NC}"
    curl -L -s -o "$MODPACK_ZIP" "$LinkZip"
    Log-Ok "Modpack zip baixado em: $MODPACK_ZIP"
    
    echo -e " ${CYAN}Preparando pasta de destino...${NC}"
    # Limpeza pre-instalacao
    for pasta in "mods" "resourcepacks" "shaderpacks" "config"; do
        rm -rf "$MC_DIR/$pasta"
    done
    rm -f "$MC_DIR/options.txt"
    Log-Info "Limpeza pre-instalacao concluida."
    
    echo -e " ${CYAN}Extraindo arquivos...${NC}"
    # Descompacta o zip ignorando a primeira pasta raiz se existir (flatten se necessario)
    # A estrutura do ZIP gerado precisa ser mapeada corretamente. 
    # Usaremos unzip simples.
    mkdir -p "$MC_DIR"
    unzip -q -o "$MODPACK_ZIP" -d "$MC_DIR"
    
    # Corrige caso tenha extraido dentro de uma pasta unica
    if [ -d "$MC_DIR/Modpack-Madness" ]; then
        mv "$MC_DIR/Modpack-Madness/"* "$MC_DIR/"
        rm -rf "$MC_DIR/Modpack-Madness"
    fi
    Log-Ok "Extracao do ZIP concluida."
    
    # Gerar launcher_profiles.json
    PROFILE_PATH="$MC_DIR/launcher_profiles.json"
    PROFILE_ID=$(cat /proc/sys/kernel/random/uuid | sed 's/-//g')
    AGORA=$(date -Iseconds)
    
    JAVA_DIR_JSON=""
    if [ -n "$javawPath" ]; then
        JAVA_DIR_JSON=",\n      \"javaDir\": \"$javawPath\""
    fi
    
    cat <<EOF > "$PROFILE_PATH"
{
  "profiles": {
    "$PROFILE_ID": {
      "name": "ModpackMadness",
      "lastVersionId": "fabric-loader-0.19.2-1.20.1",
      "type": "custom",
      "icon": "Grass",
      "created": "$AGORA",
      "lastUsed": "$AGORA"$JAVA_DIR_JSON
    }
  },
  "selectedProfile": "$PROFILE_ID",
  "settings": {
    "profileSorting": "byName"
  },
  "version": 6
}
EOF
    Log-Ok "launcher_profiles.json gerado."
fi

# ==============================================================================
# TELA FINAL E INJECAO PRISM
# ==============================================================================
Mostrar-Cabecalho
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}                    INSTALACAO CONCLUIDA COM SUCESSO!${NC}"
echo -e "${GREEN}==============================================================================\n${NC}"

Log-Step "INSTALACAO CONCLUIDA"

if [ "$LauncherType" == "PRISM" ]; then
    echo -e " ${CYAN}O Prism abriu a janela de importacao de modpack.${NC}"
    echo -e " ${WHITE}Certifique-se que ela esta selecionada e clique em 'OK' para iniciar.${NC}"
    
    if [ -n "$javawPath" ]; then
        echo -e "\n ${CYAN}Aguardando o Prism criar a instancia...${NC}"
        
        # Localizar diretorio de instancias do Prism no Linux
        PRISM_INSTANCES_DIR=""
        if [ "$PRISM_IS_FLATPAK" = true ]; then
            PRISM_INSTANCES_DIR="$HOME/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances"
        else
            PRISM_INSTANCES_DIR="$HOME/.local/share/PrismLauncher/instances"
        fi
        
        # Polling para injetar instance.cfg
        timeout=300
        elapsed=0
        cfgPath=""
        
        while [ $elapsed -lt $timeout ]; do
            # Busca o arquivo instance.cfg mais recente no diretorio
            cfgCandidato=$(find "$PRISM_INSTANCES_DIR" -maxdepth 2 -name "instance.cfg" -type f -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -n 1 | cut -d ' ' -f 2-)
            
            if [ -n "$cfgCandidato" ]; then
                # Verifica se o arquivo recem criado tem o nome do modpack ou ja eh alvo
                if grep -q "name=" "$cfgCandidato"; then
                    cfgPath="$cfgCandidato"
                    break
                fi
            fi
            sleep 2
            elapsed=$((elapsed + 2))
            echo -ne "\r ${GRAY}Procurando instalacao... ($elapsed s) ${NC}"
        done
        echo ""
        
        if [ -n "$cfgPath" ]; then
            # Aguarda o Prism parar de escrever no arquivo
            lastSize=-1
            stableCount=0
            while [ $stableCount -lt 2 ]; do
                currSize=$(stat -c%s "$cfgPath" 2>/dev/null || echo 0)
                if [ "$currSize" -eq "$lastSize" ] && [ "$currSize" -gt 0 ]; then
                    stableCount=$((stableCount + 1))
                else
                    stableCount=0
                    lastSize=$currSize
                fi
                sleep 1
            done
            
            echo -e " ${CYAN}Injetando Java 21...${NC}"
            
            # Fecha o Prism para editar com seguranca
            pkill -f "prismlauncher" || pkill -f "PrismLauncher"
            
            # Remove linhas antigas de java e adiciona novas
            grep -v -E "^(JavaPath|OverrideJavaArgs|OverrideJavaLocation|JvmArgs|PreLaunchCommand)=" "$cfgPath" > "$cfgPath.tmp"
            
            # Insere as novas flags abaixo de [General]
            awk -v javaPath="$javawPath" '
            {print}
            /^\[General\]$/ {
                print "OverrideJavaLocation=true"
                print "JavaPath=" javaPath
                print "OverrideJavaArgs=true"
                print "JvmArgs=-XX:+UnlockExperimentalVMOptions -XX:+UseZGC -XX:+ZProactive -XX:ZCollectionInterval=5 -XX:ZUncommitDelay=5 -XX:ZFragmentationLimit=10 -XX:ZMaxTenuringThreshold=10 -XX:AllocatePrefetchStyle=1 -XX:-ZProactive -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+PerfDisableSharedMem -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1HeapRegionSize=8M -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1"
            }' "$cfgPath.tmp" > "$cfgPath"
            
            rm -f "$cfgPath.tmp"
            
            echo -e "\n ${GREEN}[OK] Java 21 configurado automaticamente na instancia!${NC}"
            
            echo -e "\n ${CYAN}Reabrindo o Prism Launcher...${NC}"
            if [ "$PRISM_IS_FLATPAK" = true ]; then
                flatpak run org.prismlauncher.PrismLauncher &
            else
                $PRISM_CMD &
            fi
        else
            echo -e "\n ${YELLOW}[ATENCAO] Java nao configurado automaticamente.${NC}"
            echo -e "           Apos importar o modpack, configure manualmente no Prism:"
            echo -e "           Instancia > Edit > Settings > Java > Java Executable"
            echo -e "           Aponte para: ${WHITE}$javawPath${NC}\n"
        fi
    else
        echo -e "\n ${YELLOW}[ATENCAO] Java nao configurado automaticamente.${NC}"
        echo -e "           Apos importar o modpack, configure manualmente no Prism:"
        echo -e "           ⋮ > Edit installation > More Options > Java Executable"
        echo -e "           Aponte para o Java 21 instalado no seu PC.\n"
    fi
else
    # SKLauncher
    if [ -n "$javawPath" ]; then
        echo -e " ${CYAN}Java detectado: $javawPath${NC}"
        echo -e " ${WHITE}Configure o caminho abaixo no SKLauncher:"
        echo -e " ⋮ > Editar > Java Executable\n"
        echo -e " ${GRAY}$javawPath\n${NC}"
    else
        echo -e "\n ${YELLOW}[ATENCAO] Java nao configurado automaticamente.${NC}"
        echo -e "           Configure manualmente no SKLauncher:"
        echo -e "           ⋮ > Editar > Java Executable"
        echo -e "           Aponte para o executavel do Java 21 instalado no seu PC.\n"
    fi
    echo -e "\n ${CYAN}[OK] launcher_profiles.json gerado em:${NC}"
    echo -e "      $MC_DIR/launcher_profiles.json\n"
    
    echo -e " ${CYAN}Abrindo SKLauncher...${NC}"
    if [ -f "$HOME/.local/share/applications/sklauncher.desktop" ]; then
        gtk-launch sklauncher.desktop 2>/dev/null || (cd "$MC_DIR" && java -jar "$SK_JAR_PATH" &)
    else
        (cd "$MC_DIR" && java -jar "$SK_JAR_PATH" &)
    fi
fi

# Limpar temporarios
rm -rf "$TEMP_DIR"
Log-Step "FIM DO INSTALADOR"
