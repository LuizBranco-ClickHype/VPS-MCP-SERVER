#!/bin/bash
# gerenciar-mcp-config.sh - Gerenciamento de configurações MCP
# Parte do projeto VPS MCP SERVER
# Este script gerencia as configurações dos MCPs

# Diretório base
MCP_BASE_DIR="/opt/mcp-server"
CONFIG_FILE="$MCP_BASE_DIR/config/mcp-config.txt"
BACKUP_DIR="$MCP_BASE_DIR/backups"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verifica se está rodando como root
check_root() {
  if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Este script precisa ser executado como root${NC}" 1>&2
    echo "Execute com sudo ou como usuário root"
    exit 1
  fi
}

# Verifica se o arquivo de configuração existe
check_config_file() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Arquivo de configuração não encontrado: $CONFIG_FILE${NC}"
    echo "Criando arquivo de configuração padrão..."
    
    # Criar diretório se não existir
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Criar arquivo de configuração padrão
    cat > "$CONFIG_FILE" << EOF
# Arquivo de configuração do VPS MCP SERVER
# Gerado automaticamente em $(date)

# Configurações gerais
IP_SERVIDOR=0.0.0.0
DOMINIO=
MODO_INSTALACAO=single
MCP_PORT=3000

# Tokens para acesso aos MCPs
MCP_TOKEN=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 32)
CONTEXT7_TOKEN=
GITHUB_TOKEN=
POSTGRES_TOKEN=
STORAGE_TOKEN=

# Configurações de bancos de dados
DB_TYPE=postgres
DB_HOST=localhost
DB_PORT=5432
DB_USER=mcp
DB_PASSWORD=
DB_NAME=mcp_database

# Opções avançadas
DEBUG_MODE=false
LOG_LEVEL=info
BACKUP_INTERVAL=7
EOF
    
    # Configurar permissões
    chmod 600 "$CONFIG_FILE"
    
    echo -e "${GREEN}Arquivo de configuração padrão criado com sucesso.${NC}"
  fi
}

# Lê um valor do arquivo de configuração
get_config() {
  local key="$1"
  grep "^$key=" "$CONFIG_FILE" | cut -d '=' -f 2
}

# Atualiza um valor no arquivo de configuração
update_config() {
  local key="$1"
  local value="$2"
  
  # Verifica se a chave existe
  if grep -q "^$key=" "$CONFIG_FILE"; then
    # Substitui o valor
    sed -i "s|^$key=.*|$key=$value|" "$CONFIG_FILE"
    echo -e "${GREEN}Configuração '$key' atualizada para '$value'${NC}"
  else
    # Adiciona a chave
    echo "$key=$value" >> "$CONFIG_FILE"
    echo -e "${GREEN}Configuração '$key' adicionada com valor '$value'${NC}"
  fi
}

# Lista todas as configurações
list_configs() {
  echo -e "${BLUE}Configurações atuais:${NC}"
  echo -e "${YELLOW}------------------------${NC}"
  
  # Ler e mostrar cada linha sem comentários
  grep -v "^#" "$CONFIG_FILE" | grep -v "^$" | while read -r line; do
    key=$(echo "$line" | cut -d '=' -f 1)
    value=$(echo "$line" | cut -d '=' -f 2)
    
    # Oculta tokens por segurança
    if [[ "$key" == *"TOKEN"* || "$key" == *"PASSWORD"* ]]; then
      if [ -n "$value" ]; then
        value="[REDACTED]"
      else
        value="[NÃO CONFIGURADO]"
      fi
    fi
    
    echo -e "${BLUE}$key${NC} = $value"
  done
}

# Cria um backup do arquivo de configuração
backup_config() {
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  local backup_file="$BACKUP_DIR/mcp-config_$timestamp.bak"
  
  # Criar diretório de backup se não existir
  mkdir -p "$BACKUP_DIR"
  
  # Criar backup
  cp "$CONFIG_FILE" "$backup_file"
  
  # Compactar backup
  gzip "$backup_file"
  
  echo -e "${GREEN}Backup do arquivo de configuração criado em $backup_file.gz${NC}"
  
  # Limpar backups antigos (manter apenas os últimos 10)
  ls -t "$BACKUP_DIR"/mcp-config_*.bak.gz 2>/dev/null | tail -n +11 | xargs -r rm
}

# Restaura um backup do arquivo de configuração
restore_config() {
  local backup_file="$1"
  
  if [ -z "$backup_file" ]; then
    # Listar backups disponíveis
    echo -e "${BLUE}Backups disponíveis:${NC}"
    echo -e "${YELLOW}------------------------${NC}"
    
    ls -t "$BACKUP_DIR"/mcp-config_*.bak.gz 2>/dev/null | nl
    
    echo
    read -p "Digite o número do backup a ser restaurado (ou 0 para cancelar): " backup_number
    
    if [ "$backup_number" = "0" ]; then
      echo -e "${YELLOW}Restauração cancelada.${NC}"
      return
    fi
    
    backup_file=$(ls -t "$BACKUP_DIR"/mcp-config_*.bak.gz 2>/dev/null | sed -n "${backup_number}p")
    
    if [ -z "$backup_file" ]; then
      echo -e "${RED}Backup não encontrado.${NC}"
      return
    fi
  fi
  
  # Verificar se o arquivo existe
  if [ ! -f "$backup_file" ]; then
    echo -e "${RED}Arquivo de backup não encontrado: $backup_file${NC}"
    return
  fi
  
  # Backup do arquivo atual
  local current_backup="$BACKUP_DIR/mcp-config_pre_restore_$(date +"%Y%m%d_%H%M%S").bak"
  cp "$CONFIG_FILE" "$current_backup"
  
  # Restaurar backup
  if [[ "$backup_file" == *.gz ]]; then
    gunzip -c "$backup_file" > "$CONFIG_FILE"
  else
    cp "$backup_file" "$CONFIG_FILE"
  fi
  
  # Configurar permissões
  chmod 600 "$CONFIG_FILE"
  
  echo -e "${GREEN}Arquivo de configuração restaurado a partir de $backup_file${NC}"
  echo -e "${YELLOW}Um backup do arquivo anterior foi criado em $current_backup${NC}"
}

# Verifica validade dos tokens MCP
verify_tokens() {
  local tokens_updated=false
  
  echo -e "${BLUE}Verificando validade dos tokens...${NC}"
  
  # Verificar token MCP
  local mcp_token=$(get_config "MCP_TOKEN")
  if [ -z "$mcp_token" ] || [ ${#mcp_token} -lt 16 ]; then
    echo -e "${YELLOW}Token MCP não configurado ou inválido. Gerando novo token...${NC}"
    mcp_token=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 32)
    update_config "MCP_TOKEN" "$mcp_token"
    tokens_updated=true
  fi
  
  # Verificar outros tokens (se necessário, adicione lógica de validação específica)
  # ...
  
  if [ "$tokens_updated" = true ]; then
    echo -e "${GREEN}Tokens atualizados. Reinicie os serviços MCP para aplicar as alterações.${NC}"
    echo -e "${YELLOW}Execute: systemctl restart mcp-server${NC}"
  else
    echo -e "${GREEN}Todos os tokens são válidos.${NC}"
  fi
}

# Função de ajuda
show_help() {
  echo "Uso: $0 [COMANDO] [OPÇÕES]"
  echo
  echo "Comandos:"
  echo "  list                Lista todas as configurações"
  echo "  get CHAVE           Obtém o valor de uma configuração"
  echo "  update CHAVE VALOR  Atualiza ou adiciona uma configuração"
  echo "  backup              Cria um backup do arquivo de configuração"
  echo "  restore [ARQUIVO]   Restaura um backup do arquivo de configuração"
  echo "  verify              Verifica validade dos tokens MCP"
  echo "  help                Exibe esta ajuda"
  echo
  echo "Exemplos:"
  echo "  $0 list"
  echo "  $0 get MCP_PORT"
  echo "  $0 update MCP_PORT 4000"
  echo "  $0 backup"
  echo "  $0 restore"
  echo
}

# Função principal
main() {
  # Verificar se é root
  check_root
  
  # Verificar arquivo de configuração
  check_config_file
  
  # Processar comandos
  case "$1" in
    list)
      list_configs
      ;;
    get)
      if [ -z "$2" ]; then
        echo -e "${RED}Erro: Chave não especificada.${NC}"
        echo "Use: $0 get CHAVE"
        exit 1
      fi
      value=$(get_config "$2")
      echo -e "${BLUE}$2${NC} = $value"
      ;;
    update)
      if [ -z "$2" ] || [ -z "$3" ]; then
        echo -e "${RED}Erro: Chave ou valor não especificado.${NC}"
        echo "Use: $0 update CHAVE VALOR"
        exit 1
      fi
      update_config "$2" "$3"
      ;;
    backup)
      backup_config
      ;;
    restore)
      restore_config "$2"
      ;;
    verify)
      verify_tokens
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Comando desconhecido: $1${NC}"
      show_help
      exit 1
      ;;
  esac
}

# Executar função principal
main "$@"