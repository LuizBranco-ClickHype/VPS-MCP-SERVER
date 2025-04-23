#!/bin/bash
# install.sh - Script de instalação para VPS MCP SERVER
# Autor: VPS MCP Server Team
# Versão: 1.0

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
print_banner() {
    echo -e "${BLUE}"
    echo "██╗   ██╗██████╗ ███████╗    ███╗   ███╗ ██████╗██████╗     ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗ "
    echo "██║   ██║██╔══██╗██╔════╝    ████╗ ████║██╔════╝██╔══██╗    ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗"
    echo "██║   ██║██████╔╝███████╗    ██╔████╔██║██║     ██████╔╝    ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝"
    echo "╚██╗ ██╔╝██╔═══╝ ╚════██║    ██║╚██╔╝██║██║     ██╔═══╝     ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗"
    echo " ╚████╔╝ ██║     ███████║    ██║ ╚═╝ ██║╚██████╗██║         ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║"
    echo "  ╚═══╝  ╚═╝     ╚══════╝    ╚═╝     ╚═╝ ╚═════╝╚═╝         ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${GREEN}VPS MCP SERVER - Instalação${NC}"
    echo -e "${YELLOW}Sistema de automação para configuração de servidores MCP${NC}"
    echo -e "${YELLOW}Versão: 1.0${NC}"
    echo -e "${YELLOW}------------------------------------------------${NC}"
    echo
}

# Verifica se está rodando como root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}Este script precisa ser executado como root${NC}" 1>&2
        echo "Execute com sudo ou como usuário root"
        exit 1
    fi
}

# Verifica a distribuição Linux
check_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        
        if [[ "$OS" != *"Ubuntu"* ]] && [[ "$OS" != *"Debian"* ]]; then
            echo -e "${YELLOW}Atenção: Sistema operacional não oficialmente suportado: $OS $VER${NC}"
            echo -e "Este script foi testado apenas com Ubuntu 20.04+ e Debian 11+"
            read -p "Deseja continuar mesmo assim? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        echo -e "${RED}Não foi possível determinar o sistema operacional${NC}"
        exit 1
    fi
}

# Verifica conectividade com a internet
check_internet() {
    echo -e "${BLUE}Verificando conexão com a internet...${NC}"
    if ! ping -c 1 google.com &> /dev/null; then
        echo -e "${RED}Erro: Sem conexão com a internet${NC}"
        exit 1
    fi
    echo -e "${GREEN}Conexão com a internet verificada com sucesso${NC}"
}

# Mostra menu de ajuda
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo
    echo "Script para configuração automática de servidores MCP para integração com Cursor AI."
    echo
    echo "Opções:"
    echo "  --mode MODE            Modo de instalação: single, app, ou db (padrão: single)"
    echo "  --domain DOMAIN        Domínio para configuração SSL"
    echo "  --email EMAIL          Email para certificados Let's Encrypt"
    echo "  --db-type TYPE         Tipo de banco de dados: postgres ou mysql (padrão: postgres)"
    echo "  --db-host HOST         IP do servidor de banco de dados (para modo app)"
    echo "  --app-host HOST        IP do servidor de aplicação (para modo db)"
    echo "  --port PORT            Porta para o MCP Server (padrão: 3000)"
    echo "  --help                 Mostra esta ajuda"
    echo
    echo "Exemplos:"
    echo "  $0 --mode single --domain meudominio.com.br --email admin@meudominio.com.br"
    echo "  $0 --mode app --port 4000"
    echo "  $0 --mode db --db-type mysql --app-host 192.168.1.10"
    echo
}

# Variáveis padrão
MODE="single"
DOMAIN=""
EMAIL=""
DB_TYPE="postgres"
DB_HOST=""
APP_HOST=""
PORT="3000"

# Processa parâmetros da linha de comando
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            if [[ "$MODE" != "single" && "$MODE" != "app" && "$MODE" != "db" ]]; then
                echo "Modo inválido: $MODE. Use single, app ou db."
                exit 1
            fi
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --db-type)
            DB_TYPE="$2"
            if [[ "$DB_TYPE" != "postgres" && "$DB_TYPE" != "mysql" ]]; then
                echo "Tipo de banco de dados inválido: $DB_TYPE. Use postgres ou mysql."
                exit 1
            fi
            shift 2
            ;;
        --db-host)
            DB_HOST="$2"
            shift 2
            ;;
        --app-host)
            APP_HOST="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
                echo "Porta inválida: $PORT. Use um número entre 1024 e 65535."
                exit 1
            fi
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Diretórios
MCP_BASE_DIR="/opt/mcp-server"
MCP_CONFIG_DIR="/root/.mcp-server"
MCP_LOG_DIR="/var/log/mcp-server"

# Função principal de instalação
main() {
    print_banner
    
    # Verificações iniciais
    check_root
    check_distro
    check_internet
    
    echo -e "${BLUE}Iniciando instalação do VPS MCP SERVER no modo: $MODE${NC}"
    
    # Criar diretórios necessários
    echo -e "${BLUE}Criando diretórios...${NC}"
    mkdir -p "$MCP_BASE_DIR"
    mkdir -p "$MCP_CONFIG_DIR"
    mkdir -p "$MCP_LOG_DIR"
    mkdir -p "$MCP_BASE_DIR/logs"
    
    # Instalar dependências básicas
    echo -e "${BLUE}Instalando dependências...${NC}"
    apt-get update
    apt-get install -y \
        curl \
        git \
        jq \
        nodejs \
        npm
    
    # Clonar o repositório
    echo -e "${BLUE}Baixando arquivos do VPS MCP SERVER...${NC}"
    git clone https://github.com/LuizBranco-ClickHype/VPS-MCP-SERVER.git "$MCP_BASE_DIR/repo"
    
    # Copiar arquivos para o diretório de instalação
    cp "$MCP_BASE_DIR/repo/mcp-service.sh" "$MCP_BASE_DIR/"
    cp "$MCP_BASE_DIR/repo/mcp-model.json" "$MCP_BASE_DIR/"
    cp "$MCP_BASE_DIR/repo/mcp.json" "$MCP_BASE_DIR/"
    
    # Tornar executável
    chmod +x "$MCP_BASE_DIR/mcp-service.sh"
    
    # Substituir IP_DO_SERVIDOR no mcp-model.json
    PUBLIC_IP=$(curl -s https://api.ipify.org)
    sed -i "s/IP_DO_SERVIDOR/$PUBLIC_IP/g" "$MCP_BASE_DIR/mcp-model.json"
    
    # Instalar dependências NPM
    cd "$MCP_BASE_DIR"
    npm install @upstash/context7-mcp@latest
    
    # Configurar o firewall
    echo -e "${BLUE}Configurando firewall...${NC}"
    apt-get install -y ufw
    ufw allow ssh
    ufw allow "$PORT/tcp"
    ufw --force enable
    
    # Criar serviço systemd
    echo -e "${BLUE}Configurando serviço systemd...${NC}"
    cat > /etc/systemd/system/vps-mcp.service << EOF
[Unit]
Description=VPS MCP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$MCP_BASE_DIR
ExecStart=/bin/bash $MCP_BASE_DIR/mcp-service.sh --endpoint /api/mcp
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Habilitar e iniciar o serviço
    systemctl daemon-reload
    systemctl enable vps-mcp
    systemctl start vps-mcp
    
    # Verificar status do serviço
    echo -e "${BLUE}Verificando status do serviço...${NC}"
    systemctl status vps-mcp
    
    # Mostrar informações finais
    echo
    echo -e "${GREEN}Instalação concluída com sucesso!${NC}"
    echo -e "${YELLOW}------------------------------------------------${NC}"
    echo -e "${BLUE}Informações do servidor:${NC}"
    echo -e "IP: $PUBLIC_IP"
    echo -e "Porta MCP: $PORT"
    echo -e "Modo de instalação: $MODE"
    echo -e "${YELLOW}------------------------------------------------${NC}"
    echo -e "${BLUE}Para verificar o status do serviço:${NC}"
    echo -e "systemctl status vps-mcp"
    echo -e "${BLUE}Para ver os logs:${NC}"
    echo -e "journalctl -u vps-mcp"
    echo -e "${YELLOW}------------------------------------------------${NC}"
    echo -e "${GREEN}O VPS MCP SERVER está pronto para uso!${NC}"
}

# Executar função principal
main