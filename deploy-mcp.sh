#!/bin/bash
# deploy-mcp.sh - Script para implantar um novo MCP
# Parte do projeto VPS MCP SERVER
# Este script facilita a implantação de novos MCPs no servidor

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variáveis
MCP_BASE_DIR="/opt/mcp-server"
MCP_CONFIG_FILE="$MCP_BASE_DIR/mcp.json"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")

# Verifica se está rodando como root
check_root() {
  if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Este script precisa ser executado como root${NC}" 1>&2
    echo "Execute com sudo ou como usuário root"
    exit 1
  fi
}

# Verifica pré-requisitos
check_prerequisites() {
  # Verificar se o MCP_BASE_DIR existe
  if [ ! -d "$MCP_BASE_DIR" ]; then
    echo -e "${RED}Diretório MCP não encontrado: $MCP_BASE_DIR${NC}"
    echo "Execute o script de instalação primeiro"
    exit 1
  fi
  
  # Verificar se o arquivo mcp.json existe
  if [ ! -f "$MCP_CONFIG_FILE" ]; then
    echo -e "${RED}Arquivo de configuração MCP não encontrado: $MCP_CONFIG_FILE${NC}"
    echo "Execute o script de instalação primeiro"
    exit 1
  fi
  
  # Verificar se jq está instalado
  if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}jq não está instalado. Instalando...${NC}"
    apt-get update && apt-get install -y jq
  fi
}

# Adiciona um novo MCP ao mcp.json
add_mcp() {
  local name="$1"
  local description="$2"
  local command="$3"
  local args="$4"
  
  # Verificar se já existe
  if jq -e ".mcpServers.\"$name\"" "$MCP_CONFIG_FILE" > /dev/null; then
    echo -e "${YELLOW}MCP \"$name\" já existe na configuração. Atualizando...${NC}"
    # Fazer backup do arquivo original
    cp "$MCP_CONFIG_FILE" "$MCP_CONFIG_FILE.bak.$TIMESTAMP"
  fi
  
  # Converter args de string para array JSON
  args_json=$(echo "$args" | jq -R 'split(" ")')
  
  # Atualizar mcp.json
  jq --arg name "$name" \
     --arg desc "$description" \
     --arg cmd "$command" \
     --argjson args "$args_json" \
     '.mcpServers[$name] = {"description": $desc, "command": $cmd, "args": $args}' \
     "$MCP_CONFIG_FILE" > "$MCP_CONFIG_FILE.tmp"
  
  # Verificar se o arquivo tmp foi criado corretamente
  if [ -s "$MCP_CONFIG_FILE.tmp" ]; then
    mv "$MCP_CONFIG_FILE.tmp" "$MCP_CONFIG_FILE"
    echo -e "${GREEN}MCP \"$name\" adicionado/atualizado com sucesso${NC}"
  else
    echo -e "${RED}Erro ao adicionar MCP. Arquivo temporário vazio.${NC}"
    exit 1
  fi
}

# Exibe os MCPs configurados
list_mcps() {
  echo -e "${BLUE}MCPs configurados:${NC}"
  echo -e "${YELLOW}------------------------${NC}"
  
  jq -r '.mcpServers | keys[] as $k | "\($k): \(.[$k].description)"' "$MCP_CONFIG_FILE"
}

# Exibe a ajuda
show_help() {
  echo "Uso: $0 [OPÇÕES]"
  echo
  echo "Script para implantar novos MCPs no servidor"
  echo
  echo "Opções:"
  echo "  --add NOME [OPÇÕES]    Adiciona ou atualiza um MCP"
  echo "    --desc DESCRIÇÃO     Descrição do MCP (obrigatório com --add)"
  echo "    --cmd COMANDO        Comando para executar o MCP (obrigatório com --add)"
  echo "    --args \"ARGUMENTOS\"  Argumentos para o comando (obrigatório com --add)"
  echo "  --list                 Lista os MCPs configurados"
  echo "  --help                 Exibe esta ajuda"
  echo
  echo "Exemplos:"
  echo "  $0 --add context7 --desc \"MCP para Context7\" --cmd \"npx\" --args \"-y @upstash/context7-mcp@latest\""
  echo "  $0 --list"
  echo
}

# Função principal
main() {
  check_root
  check_prerequisites
  
  if [ $# -eq 0 ]; then
    show_help
    exit 0
  fi
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --add)
        name="$2"
        shift 2
        
        description=""
        command=""
        args=""
        
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --desc)
              description="$2"
              shift 2
              ;;
            --cmd)
              command="$2"
              shift 2
              ;;
            --args)
              args="$2"
              shift 2
              ;;
            *)
              break
              ;;
          esac
        done
        
        if [ -z "$name" ] || [ -z "$description" ] || [ -z "$command" ] || [ -z "$args" ]; then
          echo -e "${RED}Erro: Parâmetros incompletos para --add${NC}"
          echo "Use: $0 --add NOME --desc DESCRIÇÃO --cmd COMANDO --args \"ARGUMENTOS\""
          exit 1
        fi
        
        add_mcp "$name" "$description" "$command" "$args"
        ;;
      --list)
        list_mcps
        shift
        ;;
      --help)
        show_help
        shift
        ;;
      *)
        echo -e "${RED}Opção desconhecida: $1${NC}"
        show_help
        exit 1
        ;;
    esac
  done
}

# Executar função principal
main "$@"