#!/bin/bash
# setup.sh - Script de configuração inicial para VPS MCP SERVER
# Parte do projeto VPS MCP SERVER
# Este script realiza a configuração inicial do ambiente

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
print_banner() {
    echo -e "${BLUE}"
    echo "██╗   ██╗██████╗ ███████╗    ███╗   ███╗ ██████╗██████╗     ███████╗███████╗████████╗██╗   ██╗██████╗ "
    echo "██║   ██║██╔══██╗██╔════╝    ████╗ ████║██╔════╝██╔══██╗    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗"
    echo "██║   ██║██████╔╝███████╗    ██╔████╔██║██║     ██████╔╝    ███████╗█████╗     ██║   ██║   ██║██████╔╝"
    echo "╚██╗ ██╔╝██╔═══╝ ╚════██║    ██║╚██╔╝██║██║     ██╔═══╝     ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ "
    echo " ╚████╔╝ ██║     ███████║    ██║ ╚═╝ ██║╚██████╗██║         ███████║███████╗   ██║   ╚██████╔╝██║     "
    echo "  ╚═══╝  ╚═╝     ╚══════╝    ╚═╝     ╚═╝ ╚═════╝╚═╝         ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     "
    echo -e "${NC}"
    echo -e "${GREEN}VPS MCP SERVER - Configuração Inicial${NC}"
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

# Configura o ambiente básico
setup_environment() {
    echo -e "${BLUE}Configurando ambiente básico...${NC}"
    
    # Atualizar pacotes
    apt-get update
    
    # Instalar dependências essenciais
    apt-get install -y \
        curl \
        wget \
        git \
        jq \
        nano \
        htop \
        ufw \
        fail2ban
    
    # Configurar timezone
    timedatectl set-timezone UTC
    
    # Configurar firewall básico
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Ativar firewall se não estiver ativo
    if ! ufw status | grep -q "Status: active"; then
        echo "y" | ufw enable
    fi
    
    # Configurar fail2ban
    if [ -f /etc/fail2ban/jail.conf ]; then
        cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
        systemctl enable fail2ban
        systemctl restart fail2ban
    fi
    
    echo -e "${GREEN}Ambiente básico configurado${NC}"
}

# Configura o Node.js
setup_nodejs() {
    echo -e "${BLUE}Configurando Node.js...${NC}"
    
    # Verificar se o Node.js já está instalado
    if command -v node &> /dev/null; then
        node_version=$(node -v)
        echo -e "${YELLOW}Node.js $node_version já está instalado${NC}"
    else
        # Instalar Node.js 18.x
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
        
        # Verificar instalação
        node_version=$(node -v)
        echo -e "${GREEN}Node.js $node_version instalado com sucesso${NC}"
    fi
    
    # Atualizar npm
    npm install -g npm@latest
    
    echo -e "${GREEN}Node.js configurado${NC}"
}

# Configura o diretório base
setup_base_dir() {
    echo -e "${BLUE}Configurando diretório base...${NC}"
    
    # Criar estrutura de diretórios
    mkdir -p /opt/mcp-server
    mkdir -p /opt/mcp-server/config
    mkdir -p /opt/mcp-server/scripts
    mkdir -p /opt/mcp-server/logs
    mkdir -p /opt/mcp-server/backups
    mkdir -p /opt/mcp-server/app
    
    # Configurar permissões
    chmod 755 /opt/mcp-server
    chmod 700 /opt/mcp-server/config
    
    echo -e "${GREEN}Diretório base configurado${NC}"
}

# Função principal
main() {
    print_banner
    check_root
    
    echo -e "${BLUE}Iniciando configuração inicial do VPS MCP SERVER...${NC}"
    
    # Configurar ambiente
    setup_environment
    
    # Configurar Node.js
    setup_nodejs
    
    # Configurar diretório base
    setup_base_dir
    
    echo -e "${GREEN}Configuração inicial concluída!${NC}"
    echo -e "${YELLOW}------------------------------------------------${NC}"
    echo -e "Para continuar a instalação, execute:"
    echo -e "${BLUE}curl -fsSL https://raw.githubusercontent.com/LuizBranco-ClickHype/VPS-MCP-SERVER/main/install.sh | bash${NC}"
}

# Executar função principal
main