#!/bin/bash
# install.sh - Script de instalação para VPS MCP SERVER
# Autor: VPS MCP Server Team
# Versão: 1.1

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
    echo -e "${YELLOW}Versão: 1.1${NC}"
    echo -e "${YELLOW}------------------------------------------------${NC}"
    echo
}

# Apresentação inicial e confirmação
welcome_message() {
    clear
    print_banner
    
    echo -e "${BLUE}Bem-vindo ao assistente de instalação do VPS MCP SERVER!${NC}"
    echo
    echo -e "Este script irá configurar seu servidor para funcionar como um provedor MCP"
    echo -e "compatível com a integração ao Cursor AI, permitindo a comunicação"
    echo -e "via plugins e funções personalizadas."
    echo
    echo -e "${YELLOW}O processo de instalação irá:${NC}"
    echo -e "  - Instalar dependências necessárias"
    echo -e "  - Configurar serviços MCP"
    echo -e "  - Configurar regras de firewall"
    echo -e "  - Configurar serviços systemd para inicialização automática"
    echo
    echo -e "${RED}ATENÇÃO:${NC} Recomendamos executar este script em um servidor limpo e dedicado"
    echo -e "para evitar conflitos com configurações existentes."
    echo
    
    read -p "Deseja continuar com a instalação? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Instalação cancelada pelo usuário.${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}Ótimo! Vamos prosseguir com a instalação.${NC}"
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
            read -p "Deseja continuar mesmo assim? (s/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
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

# Coleta informações do usuário para configuração
collect_user_info() {
    echo -e "${BLUE}Configuração do VPS MCP SERVER${NC}"
    echo -e "${YELLOW}------------------------------------------------${NC}"
    
    # Perguntar sobre o modo de instalação se não foi fornecido
    if [ -z "$MODE" ]; then
        echo -e "${YELLOW}Modos de instalação disponíveis:${NC}"
        echo -e "  single - Instala todos os componentes em um único servidor"
        echo -e "  app    - Instala apenas o servidor de aplicação"
        echo -e "  db     - Instala apenas o servidor de banco de dados"
        echo
        read -p "Escolha o modo de instalação [single]: " MODE_INPUT
        MODE=${MODE_INPUT:-single}
        
        if [[ "$MODE" != "single" && "$MODE" != "app" && "$MODE" != "db" ]]; then
            echo -e "${RED}Modo inválido: $MODE. Use single, app ou db.${NC}"
            exit 1
        fi
    fi
    
    # Pedir domínio e email para certificado SSL
    if [ -z "$DOMAIN" ]; then
        read -p "Informe o domínio para acesso ao servidor MCP (ex: mcp.seudominio.com): " DOMAIN
    fi
    
    if [ -z "$EMAIL" ]; then
        read -p "Informe um email para notificações e certificados SSL: " EMAIL
    fi
    
    # Validar domínio e email básicos
    if [ -z "$DOMAIN" ]; then
        echo -e "${YELLOW}Aviso: Nenhum domínio fornecido. O servidor será configurado apenas com IP.${NC}"
    fi
    
    if [ -z "$EMAIL" ]; then
        echo -e "${YELLOW}Aviso: Nenhum email fornecido. Não será possível receber notificações.${NC}"
    fi
    
    # Configurações adicionais com base no modo
    if [ "$MODE" == "single" ]; then
        # Definir tipo de banco para modo single
        if [ -z "$DB_TYPE" ]; then
            echo
            echo -e "${YELLOW}Tipos de banco de dados disponíveis:${NC}"
            echo -e "  postgres - PostgreSQL (recomendado, suporte a vetores)"
            echo -e "  mysql    - MySQL/MariaDB"
            echo
            read -p "Escolha o tipo de banco de dados [postgres]: " DB_TYPE_INPUT
            DB_TYPE=${DB_TYPE_INPUT:-postgres}
            
            if [[ "$DB_TYPE" != "postgres" && "$DB_TYPE" != "mysql" ]]; then
                echo -e "${RED}Tipo de banco de dados inválido: $DB_TYPE. Use postgres ou mysql.${NC}"
                exit 1
            fi
        fi
    fi
    
    # Porta do servidor
    if [ -z "$PORT" ] || [ "$PORT" == "3000" ]; then
        read -p "Informe a porta para o servidor MCP [3000]: " PORT_INPUT
        PORT=${PORT_INPUT:-3000}
        
        if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
            echo -e "${RED}Porta inválida: $PORT. Use um número entre 1024 e 65535.${NC}"
            exit 1
        fi
    fi
    
    # Confirmar configurações
    echo
    echo -e "${BLUE}Resumo da configuração:${NC}"
    echo -e "${YELLOW}------------------------------------------------${NC}"
    echo -e "Modo de instalação: ${GREEN}$MODE${NC}"
    
    if [ -n "$DOMAIN" ]; then
        echo -e "Domínio: ${GREEN}$DOMAIN${NC}"
    else
        echo -e "Domínio: ${YELLOW}Não configurado${NC}"
    fi
    
    if [ -n "$EMAIL" ]; then
        echo -e "Email: ${GREEN}$EMAIL${NC}"
    else
        echo -e "Email: ${YELLOW}Não configurado${NC}"
    fi
    
    if [ "$MODE" == "single" ]; then
        echo -e "Tipo de banco: ${GREEN}$DB_TYPE${NC}"
    fi
    
    echo -e "Porta: ${GREEN}$PORT${NC}"
    echo -e "${YELLOW}------------------------------------------------${NC}"
    
    read -p "Confirma estas configurações? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Configuração cancelada. Execute o script novamente para recomeçar.${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}Configuração confirmada! Iniciando instalação...${NC}"
    echo
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
MODE=""
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

# Configuração do Nginx e certificado SSL
setup_nginx_ssl() {
    if [ -z "$DOMAIN" ]; then
        echo -e "${YELLOW}Nenhum domínio fornecido, pulando configuração SSL...${NC}"
        return
    fi
    
    echo -e "${BLUE}Configurando Nginx e SSL para domínio $DOMAIN...${NC}"
    
    # Instalar Nginx e Certbot
    apt-get install -y nginx certbot python3-certbot-nginx
    
    # Criar configuração do Nginx
    cat > /etc/nginx/sites-available/mcp-server << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    # Ativar site
    ln -sf /etc/nginx/sites-available/mcp-server /etc/nginx/sites-enabled/
    systemctl restart nginx
    
    # Obter certificado SSL
    if [ -n "$EMAIL" ]; then
        certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
    else
        certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email
    fi
    
    # Permitir portas HTTP e HTTPS no firewall
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    echo -e "${GREEN}Configuração de Nginx e SSL concluída com sucesso!${NC}"
}

# Instalação e configuração das stacks MCP
setup_mcp_stacks() {
    echo -e "${BLUE}Configurando stacks MCP...${NC}"
    
    # Criar arquivo de configuração das stacks com base no domínio
    if [ -n "$DOMAIN" ]; then
        local BASE_URL="https://$DOMAIN"
    else
        local PUBLIC_IP=$(curl -s https://api.ipify.org)
        local BASE_URL="http://$PUBLIC_IP:$PORT"
    fi
    
    # Substituir URLs nas configurações
    sed -i "s|/api/mcp|$BASE_URL/api/mcp|g" "$MCP_BASE_DIR/mcp.json"
    sed -i "s|/api/postgres|$BASE_URL/api/postgres|g" "$MCP_BASE_DIR/mcp.json"
    sed -i "s|/api/storage|$BASE_URL/api/storage|g" "$MCP_BASE_DIR/mcp.json"
    
    echo -e "${GREEN}Stacks MCP configuradas com sucesso!${NC}"
}

# Função principal de instalação
main() {
    # Mostrar boas-vindas e obter confirmação
    welcome_message
    
    # Verificações iniciais
    check_root
    check_distro
    check_internet
    
    # Coletar informações do usuário se necessário
    collect_user_info
    
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
    
    # Configuração do Nginx e SSL se tiver um domínio
    if [ -n "$DOMAIN" ]; then
        setup_nginx_ssl
    fi
    
    # Configurar stacks MCP
    setup_mcp_stacks
    
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
    
    # Salvar informações de configuração
    cat > "$MCP_CONFIG_DIR/install.conf" << EOF
MODE=$MODE
DOMAIN=$DOMAIN
EMAIL=$EMAIL
DB_TYPE=$DB_TYPE
PORT=$PORT
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    # Mostrar informações finais
    echo
    echo -e "${GREEN}Instalação concluída com sucesso!${NC}"
    echo -e "${YELLOW}------------------------------------------------${NC}"
    echo -e "${BLUE}Informações do servidor:${NC}"
    echo -e "IP: $PUBLIC_IP"
    echo -e "Porta MCP: $PORT"
    
    if [ -n "$DOMAIN" ]; then
        echo -e "Domínio: $DOMAIN"
        echo -e "URL de acesso: https://$DOMAIN"
    else
        echo -e "URL de acesso: http://$PUBLIC_IP:$PORT"
    fi
    
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