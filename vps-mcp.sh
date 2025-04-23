#!/bin/bash
# vps-mcp.sh - Script de gerenciamento do VPS MCP SERVER
# Autor: VPS MCP Server Team
# Versão: 1.0

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretórios e arquivos
MCP_BASE_DIR="/opt/mcp-server"
MCP_CONFIG_DIR="/root/.mcp-server"
MCP_LOG_DIR="/var/log/mcp-server"

# Banner
print_banner() {
    echo -e "${BLUE}"
    echo "██╗   ██╗██████╗ ███████╗    ███╗   ███╗ ██████╗██████╗ "
    echo "██║   ██║██╔══██╗██╔════╝    ████╗ ████║██╔════╝██╔══██╗"
    echo "██║   ██║██████╔╝███████╗    ██╔████╔██║██║     ██████╔╝"
    echo "╚██╗ ██╔╝██╔═══╝ ╚════██║    ██║╚██╔╝██║██║     ██╔═══╝ "
    echo " ╚████╔╝ ██║     ███████║    ██║ ╚═╝ ██║╚██████╗██║     "
    echo "  ╚═══╝  ╚═╝     ╚══════╝    ╚═╝     ╚═╝ ╚═════╝╚═╝     "
    echo -e "${NC}"
    echo -e "${GREEN}VPS MCP SERVER - Gerenciamento${NC}"
    echo -e "${YELLOW}------------------------------------------------${NC}"
}

# Verifica se está rodando como root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}Este script precisa ser executado como root${NC}" 1>&2
        echo "Execute com sudo ou como usuário root"
        exit 1
    fi
}

# Exibe o status dos serviços
show_status() {
    echo -e "${BLUE}Status dos serviços MCP:${NC}"
    echo -e "${YELLOW}------------------------${NC}"
    
    # Verificar serviço principal
    if systemctl is-active --quiet mcp-server; then
        echo -e "${GREEN}● mcp-server${NC} está ativo"
    else
        echo -e "${RED}○ mcp-server${NC} está inativo"
    fi
    
    # Verificar serviço PostgreSQL MCP (se existir)
    if systemctl list-unit-files | grep -q postgres-mcp.service; then
        if systemctl is-active --quiet postgres-mcp; then
            echo -e "${GREEN}● postgres-mcp${NC} está ativo"
        else
            echo -e "${RED}○ postgres-mcp${NC} está inativo"
        fi
    fi
    
    # Verificar serviço de banco de dados
    if systemctl list-unit-files | grep -q mcp-db-api.service; then
        if systemctl is-active --quiet mcp-db-api; then
            echo -e "${GREEN}● mcp-db-api${NC} está ativo"
        else
            echo -e "${RED}○ mcp-db-api${NC} está inativo"
        fi
    fi
    
    # Verificar serviço de aplicação
    if systemctl list-unit-files | grep -q mcp-app.service; then
        if systemctl is-active --quiet mcp-app; then
            echo -e "${GREEN}● mcp-app${NC} está ativo"
        else
            echo -e "${RED}○ mcp-app${NC} está inativo"
        fi
    fi
    
    # Verificar serviços relacionados
    echo -e "\n${BLUE}Serviços relacionados:${NC}"
    echo -e "${YELLOW}------------------------${NC}"
    
    # Verificar PostgreSQL
    if command -v psql &> /dev/null; then
        if systemctl is-active --quiet postgresql; then
            echo -e "${GREEN}● PostgreSQL${NC} está ativo"
        else
            echo -e "${RED}○ PostgreSQL${NC} está inativo"
        fi
    fi
    
    # Verificar MySQL
    if command -v mysql &> /dev/null; then
        if systemctl is-active --quiet mysql; then
            echo -e "${GREEN}● MySQL${NC} está ativo"
        else
            echo -e "${RED}○ MySQL${NC} está inativo"
        fi
    fi
    
    # Verificar Nginx
    if command -v nginx &> /dev/null; then
        if systemctl is-active --quiet nginx; then
            echo -e "${GREEN}● Nginx${NC} está ativo"
        else
            echo -e "${RED}○ Nginx${NC} está inativo"
        fi
    fi
}

# Iniciar todos os serviços
start_services() {
    echo -e "${BLUE}Iniciando serviços MCP...${NC}"
    
    # Iniciar serviços relacionados primeiro
    if command -v psql &> /dev/null; then
        systemctl start postgresql
    fi
    
    if command -v mysql &> /dev/null; then
        systemctl start mysql
    fi
    
    if command -v nginx &> /dev/null; then
        systemctl start nginx
    fi
    
    # Iniciar serviços MCP
    if systemctl list-unit-files | grep -q mcp-server.service; then
        systemctl start mcp-server
    fi
    
    if systemctl list-unit-files | grep -q postgres-mcp.service; then
        systemctl start postgres-mcp
    fi
    
    if systemctl list-unit-files | grep -q mcp-db-api.service; then
        systemctl start mcp-db-api
    fi
    
    if systemctl list-unit-files | grep -q mcp-app.service; then
        systemctl start mcp-app
    fi
    
    echo -e "${GREEN}Serviços iniciados. Verificando status:${NC}"
    show_status
}

# Parar todos os serviços
stop_services() {
    echo -e "${BLUE}Parando serviços MCP...${NC}"
    
    # Parar serviços MCP
    if systemctl list-unit-files | grep -q mcp-app.service; then
        systemctl stop mcp-app
    fi
    
    if systemctl list-unit-files | grep -q mcp-db-api.service; then
        systemctl stop mcp-db-api
    fi
    
    if systemctl list-unit-files | grep -q postgres-mcp.service; then
        systemctl stop postgres-mcp
    fi
    
    if systemctl list-unit-files | grep -q mcp-server.service; then
        systemctl stop mcp-server
    fi
    
    echo -e "${YELLOW}Serviços MCP parados.${NC}"
    echo -e "${YELLOW}Os serviços relacionados (PostgreSQL, MySQL, Nginx) não foram parados.${NC}"
}

# Reiniciar todos os serviços
restart_services() {
    echo -e "${BLUE}Reiniciando serviços MCP...${NC}"
    
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
    
    echo -e "${GREEN}Serviços reiniciados. Verificando status:${NC}"
    show_status
}

# Exibir logs
show_logs() {
    local service="$1"
    local lines="${2:-50}"
    
    case "$service" in
        all)
            echo -e "${BLUE}Últimas $lines linhas de todos os logs:${NC}"
            journalctl -u mcp-server -u postgres-mcp -u mcp-db-api -u mcp-app -n "$lines"
            ;;
        mcp)
            echo -e "${BLUE}Últimas $lines linhas do log do mcp-server:${NC}"
            journalctl -u mcp-server -n "$lines"
            ;;
        postgres)
            echo -e "${BLUE}Últimas $lines linhas do log do postgres-mcp:${NC}"
            journalctl -u postgres-mcp -n "$lines"
            ;;
        db)
            echo -e "${BLUE}Últimas $lines linhas do log do mcp-db-api:${NC}"
            journalctl -u mcp-db-api -n "$lines"
            ;;
        app)
            echo -e "${BLUE}Últimas $lines linhas do log do mcp-app:${NC}"
            journalctl -u mcp-app -n "$lines"
            ;;
        *)
            echo -e "${RED}Serviço desconhecido: $service${NC}"
            echo "Serviços disponíveis: all, mcp, postgres, db, app"
            exit 1
            ;;
    esac
}

# Exibir ajuda
show_help() {
    echo "Uso: $0 [COMANDO]"
    echo
    echo "Comandos:"
    echo "  status        Mostrar status dos serviços MCP"
    echo "  start         Iniciar todos os serviços MCP"
    echo "  stop          Parar todos os serviços MCP"
    echo "  restart       Reiniciar todos os serviços MCP"
    echo "  logs [serviço] [linhas]"
    echo "                Mostrar logs de um serviço específico"
    echo "                Serviços disponíveis: all, mcp, postgres, db, app"
    echo "                Número de linhas padrão: 50"
    echo "  help          Mostrar esta ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 status"
    echo "  $0 start"
    echo "  $0 logs mcp 100"
    echo
}

# Função principal
main() {
    print_banner
    check_root
    
    # Processar comandos
    case "$1" in
        status)
            show_status
            ;;
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        logs)
            show_logs "${2:-all}" "${3:-50}"
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