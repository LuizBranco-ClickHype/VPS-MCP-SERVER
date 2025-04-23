#!/bin/bash
# mcp-service.sh - Script unificado para gerenciamento de serviços MCP
# Autor: VPS MCP Server Team
# Versão: 2.0

# Detecta o sistema operacional
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
  else
    OS="unknown"
  fi
  echo $OS
}

# Configura cores para output
setup_colors() {
  if [[ "$(detect_os)" != "windows" ]]; then
    # Cores para sistemas Unix
    VERMELHO='\033[0;31m'
    VERDE='\033[0;32m'
    AMARELO='\033[0;33m'
    AZUL='\033[0;34m'
    SEM_COR='\033[0m'
  else
    # Para Windows, não usamos códigos de cores
    VERMELHO=''
    VERDE=''
    AMARELO=''
    AZUL=''
    SEM_COR=''
  fi
}

setup_colors

# Diretórios e arquivos
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE="$SCRIPT_DIR/mcp-model.json"

# Diretório de logs
if [[ "$(detect_os)" == "windows" ]]; then
  LOG_DIR="./logs"
else
  LOG_DIR="/var/log/vps-mcp"
fi

LOG_FILE="$LOG_DIR/mcp-communication.log"

# Processa argumentos para endpoints MCP
ENDPOINT=""
for arg in "$@"; do
  if [[ "$arg" == "--endpoint" ]]; then
    ENDPOINT_NEXT=true
  elif [[ "$ENDPOINT_NEXT" == true ]]; then
    ENDPOINT="$arg"
    ENDPOINT_NEXT=false
  fi
done

# Se for chamado como endpoint MCP, implementa a comunicação MCP SSE
if [[ -n "$ENDPOINT" ]]; then
  handle_mcp_endpoint "$ENDPOINT"
  exit 0
fi

# Verifica se as dependências estão instaladas
check_dependencies() {
  if ! command -v jq &> /dev/null; then
    echo -e "${VERMELHO}Erro: jq não está instalado.${SEM_COR}"
    if [[ "$(detect_os)" == "linux" ]]; then
      echo -e "Instale usando 'sudo apt-get install jq' ou equivalente."
    elif [[ "$(detect_os)" == "macos" ]]; then
      echo -e "Instale usando 'brew install jq'."
    else
      echo -e "Por favor, instale o jq de https://stedolan.github.io/jq/download/"
    fi
    exit 1
  fi
}

# Configura os diretórios necessários
setup_directories() {
  # Cria o diretório de logs se não existir
  if [ ! -d "$LOG_DIR" ]; then
    echo -e "${AZUL}Criando diretório de logs em $LOG_DIR...${SEM_COR}"
    mkdir -p "$LOG_DIR"
  fi
  
  # Cria o arquivo de log se não existir
  if [ ! -f "$LOG_FILE" ]; then
    echo -e "${AZUL}Criando arquivo de log em $LOG_FILE...${SEM_COR}"
    touch "$LOG_FILE"
    if [[ "$(detect_os)" != "windows" ]]; then
      chmod 644 "$LOG_FILE"
    fi
  fi
}

# Verifica se o arquivo de configuração existe
check_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${VERMELHO}Erro: Arquivo de configuração $CONFIG_FILE não encontrado.${SEM_COR}"
    echo -e "${AMARELO}Por favor, certifique-se de que o arquivo existe no diretório atual.${SEM_COR}"
    exit 1
  fi
}

# Função para implementar a comunicação SSE do MCP
handle_mcp_endpoint() {
  local endpoint=$1
  
  # Log de acesso ao MCP
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] MCP Request: $endpoint" >> "$LOG_FILE"
  
  # Simulação de resposta para diferentes endpoints
  case "$endpoint" in
    "/api/mcp")
      # Endpoint principal
      cat << EOF
{
  "tools": [
    {
      "name": "check_server_status",
      "description": "Verifica o status dos serviços no servidor",
      "parameters": {
        "type": "object",
        "properties": {
          "service": {
            "type": "string",
            "description": "Nome do serviço para verificar (opcional)"
          }
        },
        "required": []
      }
    },
    {
      "name": "restart_service",
      "description": "Reinicia um serviço específico",
      "parameters": {
        "type": "object",
        "properties": {
          "service": {
            "type": "string",
            "description": "Nome do serviço para reiniciar"
          }
        },
        "required": ["service"]
      }
    }
  ]
}
EOF
      ;;
    "/api/postgres")
      # Endpoint PostgreSQL
      cat << EOF
{
  "tools": [
    {
      "name": "query_database",
      "description": "Executa uma consulta SQL no PostgreSQL",
      "parameters": {
        "type": "object",
        "properties": {
          "query": {
            "type": "string",
            "description": "Consulta SQL a ser executada"
          },
          "database": {
            "type": "string",
            "description": "Nome do banco de dados (opcional)"
          }
        },
        "required": ["query"]
      }
    },
    {
      "name": "create_database",
      "description": "Cria um novo banco de dados PostgreSQL",
      "parameters": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "description": "Nome do banco de dados"
          },
          "owner": {
            "type": "string",
            "description": "Proprietário do banco de dados (opcional)"
          }
        },
        "required": ["name"]
      }
    }
  ]
}
EOF
      ;;
    "/api/storage")
      # Endpoint de armazenamento
      cat << EOF
{
  "tools": [
    {
      "name": "list_objects",
      "description": "Lista objetos em um bucket",
      "parameters": {
        "type": "object",
        "properties": {
          "bucket": {
            "type": "string",
            "description": "Nome do bucket"
          },
          "prefix": {
            "type": "string",
            "description": "Prefixo para filtrar objetos (opcional)"
          }
        },
        "required": ["bucket"]
      }
    },
    {
      "name": "upload_object",
      "description": "Faz upload de um objeto para um bucket",
      "parameters": {
        "type": "object",
        "properties": {
          "bucket": {
            "type": "string",
            "description": "Nome do bucket"
          },
          "key": {
            "type": "string",
            "description": "Chave/caminho do objeto"
          },
          "content_type": {
            "type": "string",
            "description": "Tipo de conteúdo do objeto"
          },
          "file_path": {
            "type": "string",
            "description": "Caminho do arquivo local para upload"
          }
        },
        "required": ["bucket", "key", "file_path"]
      }
    }
  ]
}
EOF
      ;;
    *)
      # Endpoint desconhecido
      echo "Endpoint MCP desconhecido: $endpoint" >> "$LOG_FILE"
      cat << EOF
{
  "error": "Endpoint não encontrado",
  "message": "O endpoint MCP solicitado não está disponível"
}
EOF
      ;;
  esac
}

# Lista todos os serviços MCP disponíveis
list_services() {
  echo -e "${AZUL}Serviços MCP disponíveis:${SEM_COR}"
  echo -e "${AMARELO}----------------------------------------------------------------${SEM_COR}"
  echo -e "${VERDE}NOME\t\tDESCRIÇÃO\t\t\tSTATUS${SEM_COR}"
  echo -e "${AMARELO}----------------------------------------------------------------${SEM_COR}"
  
  jq -r '.mcpServers | keys[]' "$CONFIG_FILE" | while read service; do
    description=$(jq -r ".mcpServers.$service.description" "$CONFIG_FILE")
    enabled=$(jq -r ".mcpServers.$service.enabled" "$CONFIG_FILE")
    
    if [ "$enabled" == "true" ]; then
      status="${VERDE}Ativo${SEM_COR}"
    else
      status="${VERMELHO}Inativo${SEM_COR}"
    fi
    
    echo -e "$service\t$description\t$status"
  done
  
  echo -e "${AMARELO}----------------------------------------------------------------${SEM_COR}"
}

# Testa a conexão com o serviço MCP específico
test_mcp_connection() {
  local service=$1
  
  if [ -z "$service" ]; then
    echo -e "${VERMELHO}Erro: É necessário especificar um serviço para testar.${SEM_COR}"
    echo -e "${AMARELO}Uso: $0 test-mcp <nome_do_serviço>${SEM_COR}"
    exit 1
  fi
  
  # Verifica se o serviço existe na configuração
  if ! jq -e ".mcpServers.$service" "$CONFIG_FILE" > /dev/null; then
    echo -e "${VERMELHO}Erro: Serviço '$service' não encontrado na configuração.${SEM_COR}"
    exit 1
  fi
  
  echo -e "${AZUL}Testando conexão com o serviço MCP '$service'...${SEM_COR}"
  
  # Obtém informações do serviço
  command=$(jq -r ".mcpServers.$service.command" "$CONFIG_FILE")
  args=$(jq -r ".mcpServers.$service.args | join(\" \")" "$CONFIG_FILE")
  timeout=$(jq -r ".mcpServers.$service.timeoutSeconds // \"10\"" "$CONFIG_FILE")
  
  # Substitui IP_DO_SERVIDOR pelo IP real (se necessário)
  args=$(echo "$args" | sed "s/IP_DO_SERVIDOR/127.0.0.1/g")
  
  # Executa o comando com timeout
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  if [[ "$(detect_os)" != "windows" ]]; then
    result=$(timeout $timeout $command $args 2>&1)
    status=$?
  else
    # No Windows não temos o comando timeout
    result=$($command $args 2>&1)
    status=$?
  fi
  
  if [ $status -eq 0 ]; then
    echo -e "${VERDE}Conexão bem-sucedida com o serviço '$service'.${SEM_COR}"
    echo "[$timestamp] SUCCESS: Conexão estabelecida com serviço $service" >> "$LOG_FILE"
  else
    echo -e "${VERMELHO}Falha na conexão com o serviço '$service'.${SEM_COR}"
    echo -e "${AMARELO}Detalhes do erro: $result${SEM_COR}"
    echo "[$timestamp] ERROR: Falha na conexão com serviço $service - $result" >> "$LOG_FILE"
  fi
}

# Exibe o status operacional de todos os serviços MCP
show_status() {
  echo -e "${AZUL}Status dos serviços MCP:${SEM_COR}"
  echo -e "${AMARELO}----------------------------------------------------------------${SEM_COR}"
  echo -e "${VERDE}SERVIÇO\t\tSTATUS\t\tÚLTIMA VERIFICAÇÃO${SEM_COR}"
  echo -e "${AMARELO}----------------------------------------------------------------${SEM_COR}"
  
  jq -r '.mcpServers | keys[]' "$CONFIG_FILE" | while read service; do
    # Verifica se o serviço está habilitado
    enabled=$(jq -r ".mcpServers.$service.enabled // \"true\"" "$CONFIG_FILE")
    
    if [ "$enabled" == "true" ]; then
      # Obtém informações do serviço
      command=$(jq -r ".mcpServers.$service.command" "$CONFIG_FILE")
      args=$(jq -r ".mcpServers.$service.args | join(\" \")" "$CONFIG_FILE")
      timeout=$(jq -r ".mcpServers.$service.timeoutSeconds // \"10\"" "$CONFIG_FILE")
      
      # Substitui IP_DO_SERVIDOR pelo IP real
      args=$(echo "$args" | sed "s/IP_DO_SERVIDOR/127.0.0.1/g")
      
      # Executa o comando para verificar o status
      timestamp=$(date +"%Y-%m-%d %H:%M:%S")
      
      if [[ "$(detect_os)" != "windows" ]]; then
        timeout $timeout $command $args &>/dev/null
        status=$?
      else
        # No Windows não temos o comando timeout
        $command $args &>/dev/null
        status=$?
      fi
      
      if [ $status -eq 0 ]; then
        status_text="${VERDE}Operacional${SEM_COR}"
      else
        status_text="${VERMELHO}Falha${SEM_COR}"
      fi
    else
      status_text="${AMARELO}Desativado${SEM_COR}"
      timestamp="-"
    fi
    
    echo -e "$service\t\t$status_text\t$timestamp"
  done
  
  echo -e "${AMARELO}----------------------------------------------------------------${SEM_COR}"
}

# Mostra as últimas linhas do arquivo de log
show_logs() {
  local lines=${1:-10}
  
  if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
    echo -e "${VERMELHO}Erro: O número de linhas deve ser um número inteiro.${SEM_COR}"
    echo -e "${AMARELO}Uso: $0 logs [linhas]${SEM_COR}"
    exit 1
  fi
  
  echo -e "${AZUL}Últimas $lines linhas do arquivo de log:${SEM_COR}"
  echo -e "${AMARELO}----------------------------------------------------------------${SEM_COR}"
  
  if [[ "$(detect_os)" != "windows" ]]; then
    tail -n "$lines" "$LOG_FILE"
  else
    # No Windows usamos findstr para simular o tail
    powershell -Command "Get-Content -Tail $lines $LOG_FILE"
  fi
  
  echo -e "${AMARELO}----------------------------------------------------------------${SEM_COR}"
}

# Exibe as instruções de uso
show_help() {
  echo -e "${AZUL}Script de Gerenciamento de Serviços MCP${SEM_COR}"
  echo -e "${AMARELO}----------------------------------------------------------------${SEM_COR}"
  echo -e "Uso: $0 [comando] [argumentos]"
  echo -e ""
  echo -e "Comandos disponíveis:"
  echo -e "  ${VERDE}list${SEM_COR}                 Lista todos os serviços MCP disponíveis"
  echo -e "  ${VERDE}status${SEM_COR}               Mostra o status operacional de todos os serviços"
  echo -e "  ${VERDE}test-mcp${SEM_COR} <serviço>   Testa a conexão com o serviço MCP específico"
  echo -e "  ${VERDE}logs${SEM_COR} [linhas]        Mostra as últimas linhas do arquivo de log (padrão: 10)"
  echo -e "  ${VERDE}help${SEM_COR}                 Mostra esta mensagem de ajuda"
  echo -e "  ${VERDE}--endpoint${SEM_COR} <path>    Executa como um servidor MCP para o endpoint especificado"
  echo -e ""
  echo -e "Exemplos:"
  echo -e "  $0 list                     # Lista todos os serviços MCP"
  echo -e "  $0 status                   # Mostra o status de todos os serviços"
  echo -e "  $0 test-mcp postgresql      # Testa conexão com o serviço PostgreSQL"
  echo -e "  $0 logs 20                  # Mostra as últimas 20 linhas do log"
  echo -e "  $0 --endpoint /api/mcp      # Executa como servidor MCP para o endpoint principal"
  echo -e "${AMARELO}----------------------------------------------------------------${SEM_COR}"
}

# Função principal
main() {
  # Verificações iniciais
  check_dependencies
  setup_directories
  check_config
  
  # Processa os comandos
  case "$1" in
    list|listar)
      list_services
      ;;
    status)
      show_status
      ;;
    test-mcp|testar)
      test_mcp_connection "$2"
      ;;
    logs)
      show_logs "$2"
      ;;
    help|ajuda)
      show_help
      ;;
    *)
      show_help
      ;;
  esac
}

# Executa a função principal
main "$@"