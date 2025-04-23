#!/bin/bash
# update-mcp.sh - Script para atualizar o VPS MCP SERVER
# Parte do projeto VPS MCP SERVER
# Este script atualiza os componentes do servidor MCP

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis
MCP_BASE_DIR="/opt/mcp-server"
REPO_URL="https://github.com/LuizBranco-ClickHype/VPS-MCP-SERVER"
BACKUP_DIR="$MCP_BASE_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")

# Verifica se está rodando como root
check_root() {
  if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Este script precisa ser executado como root${NC}" 1>&2
    echo "Execute com sudo ou como usuário root"
    exit 1
  fi
}

# Faz backup da instalação atual
backup_current_installation() {
  echo -e "${BLUE}Fazendo backup da instalação atual...${NC}"
  
  mkdir -p "$BACKUP_DIR"
  
  # Backup dos arquivos de configuração
  tar -czf "$BACKUP_DIR/mcp_backup_$TIMESTAMP.tar.gz" \
    --exclude="$MCP_BASE_DIR/backups" \
    --exclude="$MCP_BASE_DIR/logs" \
    "$MCP_BASE_DIR"
  
  echo -e "${GREEN}Backup criado em $BACKUP_DIR/mcp_backup_$TIMESTAMP.tar.gz${NC}"
}

# Atualiza scripts principais
update_scripts() {
  echo -e "${BLUE}Atualizando scripts principais...${NC}"
  
  # Diretório temporário para download
  TMP_DIR=$(mktemp -d)
  
  # Baixar últimos scripts
  curl -fsSL "$REPO_URL/raw/main/mcp-service.sh" -o "$TMP_DIR/mcp-service.sh"
  curl -fsSL "$REPO_URL/raw/main/vps-mcp.sh" -o "$TMP_DIR/vps-mcp.sh"
  curl -fsSL "$REPO_URL/raw/main/gerenciar-mcp-config.sh" -o "$TMP_DIR/gerenciar-mcp-config.sh"
  curl -fsSL "$REPO_URL/raw/main/postgres-mcp-setup.sh" -o "$TMP_DIR/postgres-mcp-setup.sh"
  
  # Verificar se os downloads foram bem-sucedidos
  if [ ! -f "$TMP_DIR/mcp-service.sh" ]; then
    echo -e "${RED}Falha ao baixar scripts. Verifique sua conexão com a internet.${NC}"
    rm -rf "$TMP_DIR"
    exit 1
  fi
  
  # Copiar para o diretório de instalação
  cp "$TMP_DIR/mcp-service.sh" "$MCP_BASE_DIR/mcp-service.sh"
  cp "$TMP_DIR/vps-mcp.sh" "$MCP_BASE_DIR/vps-mcp.sh"
  cp "$TMP_DIR/gerenciar-mcp-config.sh" "$MCP_BASE_DIR/scripts/gerenciar-mcp-config.sh"
  cp "$TMP_DIR/postgres-mcp-setup.sh" "$MCP_BASE_DIR/scripts/postgres-mcp-setup.sh"
  
  # Configurar permissões
  chmod +x "$MCP_BASE_DIR/mcp-service.sh"
  chmod +x "$MCP_BASE_DIR/vps-mcp.sh"
  chmod +x "$MCP_BASE_DIR/scripts/gerenciar-mcp-config.sh"
  chmod +x "$MCP_BASE_DIR/scripts/postgres-mcp-setup.sh"
  
  # Limpar diretório temporário
  rm -rf "$TMP_DIR"
  
  echo -e "${GREEN}Scripts atualizados com sucesso${NC}"
}

# Atualiza pacotes npm
update_npm_packages() {
  echo -e "${BLUE}Atualizando dependências npm...${NC}"
  
  # Verificar se npm está instalado
  if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm não está instalado${NC}"
    return 1
  fi
  
  cd "$MCP_BASE_DIR"
  
  # Backup do package.json atual
  cp package.json "package.json.bak.$TIMESTAMP"
  
  # Atualizar dependências
  npm update
  
  # Verificar atualizações específicas para MCPs
  echo -e "${BLUE}Verificando atualizações para MCPs...${NC}"
  
  # Context7 MCP
  if npm list | grep -q "@upstash/context7-mcp"; then
    echo -e "${YELLOW}Atualizando Context7 MCP...${NC}"
    npm install @upstash/context7-mcp@latest
  fi
  
  echo -e "${GREEN}Dependências npm atualizadas com sucesso${NC}"
}

# Reinicia serviços
restart_services() {
  echo -e "${BLUE}Reiniciando serviços...${NC}"
  
  # Reiniciar serviços MCP
  if systemctl list-unit-files | grep -q mcp-server.service; then
    systemctl restart mcp-server
  fi
  
  if systemctl list-unit-files | grep -q postgres-mcp.service; then
    systemctl restart postgres-mcp
  fi
  
  if systemctl list-unit-files | grep -q mcp-db-api.service; then
    systemctl restart mcp-db-api
  fi
  
  if systemctl list-unit-files | grep -q mcp-app.service; then
    systemctl restart mcp-app
  fi
  
  echo -e "${GREEN}Serviços reiniciados com sucesso${NC}"
}

# Função principal
main() {
  echo -e "${BLUE}VPS MCP SERVER - Atualização${NC}"
  echo -e "${YELLOW}------------------------------------------------${NC}"
  
  check_root
  
  # Perguntar antes de prosseguir
  read -p "Deseja continuar com a atualização? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Atualização cancelada pelo usuário${NC}"
    exit 0
  fi
  
  # Processo de atualização
  backup_current_installation
  update_scripts
  update_npm_packages
  restart_services
  
  echo -e "${GREEN}Atualização concluída com sucesso!${NC}"
  echo -e "${YELLOW}------------------------------------------------${NC}"
  echo -e "Para verificar o status dos serviços, execute:"
  echo -e "${BLUE}$MCP_BASE_DIR/vps-mcp.sh status${NC}"
}

# Executar função principal
main