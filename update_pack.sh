#!/bin/bash

# --- CONFIGURAÇÃO ---
DEST="/home/hiago/Documents/THE MODPACK MADNESS"
# AJUSTE O CAMINHO ABAIXO PARA A SUA INSTÂNCIA DO PRISM
SOURCE="/home/hiago/.local/share/PrismLauncher/instances/MODPACK MADNESS/.minecraft"

echo "🚀 Iniciando sincronização do modpack..."

# 1. Limpeza das pastas no destino (para deletar o que você removeu no jogo)
echo "🧹 Limpando pastas antigas..."
rm -rf "$DEST/overrides/config"
rm -rf "$DEST/overrides/resourcepacks"
rm -rf "$DEST/overrides/shaderpacks"
rm -rf "$DEST/overrides/mods"

# 2. Criando estrutura necessária
mkdir -p "$DEST/overrides/config"
mkdir -p "$DEST/overrides/resourcepacks"
mkdir -p "$DEST/overrides/shaderpacks"
mkdir -p "$DEST/overrides/mods"

# 3. Copiando arquivos da .minecraft para a pasta do GitHub
echo "📂 Copiando arquivos novos..."
cp -r "$SOURCE/config/"* "$DEST/overrides/config/"
cp -r "$SOURCE/resourcepacks/"* "$DEST/overrides/resourcepacks/"
cp -r "$SOURCE/shaderpacks/"* "$DEST/overrides/shaderpacks/"
cp -r "$SOURCE/mods/"* "$DEST/overrides/mods/"
cp "$SOURCE/icon.png" "$DEST/"

# 4. Rodando o Packwiz Refresh (Isso atualiza o index.toml)
cd "$DEST"
echo "⚙️ Atualizando manifesto do Packwiz..."
packwiz refresh

# 5. Git Push (Automação do envio)
echo "🌐 Enviando para o GitHub..."
git add .
read -p "Digite a mensagem do commit: " MESSAGE
if [ -z "$MESSAGE" ]; then
    MESSAGE="Update modpack $(date +'%Y-%m-%d %H:%M')"
fi
git commit -m "$MESSAGE"
git push origin main

echo "✅ Tudo pronto! Seus amigos já podem atualizar."
