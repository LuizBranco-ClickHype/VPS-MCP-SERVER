#!/bin/bash
# single-server.sh - Configuração de servidor único (all-in-one)
# Parte do projeto VPS MCP SERVER
# Este script é chamado pelo install.sh no modo single

# Verifica se as variáveis necessárias estão definidas
if [ -z "$MCP_BASE_DIR" ] || [ -z "$MCP_LOG_DIR" ]; then
  echo "Erro: Este script deve ser chamado a partir do install.sh"
  exit 1
fi

# Função para configurar servidor único
setup_single_server() {
  local domain="$1"
  local db_type="$2"
  local port="$3"
  local mcp_token="$4"
  local email="$5"
  
  echo "Configurando servidor único..."
  echo "Domínio: $domain"
  echo "Tipo de banco de dados: $db_type"
  echo "Porta: $port"
  
  # Criar diretórios necessários
  mkdir -p "$MCP_BASE_DIR/app"
  mkdir -p "$MCP_BASE_DIR/db"
  mkdir -p "$MCP_BASE_DIR/db/conf"
  mkdir -p "$MCP_BASE_DIR/db/data"
  
  # Instalar dependências comuns
  apt-get update
  apt-get install -y \
    nginx \
    certbot \
    python3-certbot-nginx \
    nodejs \
    npm
  
  # Configurar PostgreSQL
  if [[ "$db_type" == "postgres" || "$db_type" == "both" ]]; then
    echo "Configurando PostgreSQL..."
    
    # Instalar PostgreSQL
    apt-get install -y postgresql postgresql-contrib postgresql-client
    
    # Gerar senha para usuário mcp
    DB_PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 16)
    
    # Salvar credenciais
    cat > "$MCP_BASE_DIR/db/conf/postgres_credentials.conf" << EOF
DB_USER=mcp
DB_PASSWORD=$DB_PASSWORD
DB_NAME=mcp_database
DB_PORT=5432
MCP_TOKEN=$mcp_token
EOF
    
    # Configurar permissões do arquivo de credenciais
    chmod 600 "$MCP_BASE_DIR/db/conf/postgres_credentials.conf"
    
    # Criar usuário e banco de dados
    sudo -u postgres psql -c "CREATE USER mcp WITH PASSWORD '$DB_PASSWORD';"
    sudo -u postgres psql -c "CREATE DATABASE mcp_database OWNER mcp;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mcp_database TO mcp;"
    
    # Configurar pgVector se disponível
    if apt-cache search postgresql-15-pgvector | grep -q pgvector; then
      echo "Instalando suporte a vetores (pgvector)..."
      apt-get install -y postgresql-15-pgvector
      
      # Habilitar extensão pgvector no banco de dados
      sudo -u postgres psql -d mcp_database -c "CREATE EXTENSION IF NOT EXISTS vector;"
    else
      echo "pgVector não disponível no repositório. Pulando instalação."
    fi
  fi
  
  # Configurar MySQL
  if [[ "$db_type" == "mysql" || "$db_type" == "both" ]]; then
    echo "Configurando MySQL..."
    
    # Instalar MySQL
    apt-get install -y mysql-server
    
    # Gerar senha para usuário mcp
    MYSQL_PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 16)
    
    # Salvar credenciais
    cat > "$MCP_BASE_DIR/db/conf/mysql_credentials.conf" << EOF
DB_USER=mcp
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=mcp_database
DB_PORT=3306
MCP_TOKEN=$mcp_token
EOF
    
    # Configurar permissões do arquivo de credenciais
    chmod 600 "$MCP_BASE_DIR/db/conf/mysql_credentials.conf"
    
    # Criar usuário e banco de dados
    mysql -e "CREATE DATABASE IF NOT EXISTS mcp_database;"
    mysql -e "CREATE USER IF NOT EXISTS 'mcp'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
    mysql -e "GRANT ALL PRIVILEGES ON mcp_database.* TO 'mcp'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
  fi
  
  # Configurar arquivo de configuração Nginx
  cat > /etc/nginx/sites-available/mcp-server << EOF
server {
    listen 80;
    server_name ${domain:-_};
    
    location / {
        proxy_pass http://localhost:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
  
  # Habilitar o site
  ln -sf /etc/nginx/sites-available/mcp-server /etc/nginx/sites-enabled/
  
  # Verificar configuração do Nginx
  nginx -t
  
  # Reiniciar Nginx
  systemctl restart nginx
  
  # Configurar certificado SSL se o domínio for fornecido
  if [ -n "$domain" ] && [ -n "$email" ]; then
    certbot --nginx -d "$domain" -m "$email" --agree-tos -n
    
    # Configurar renovação automática do certificado
    echo "0 3 * * * certbot renew --quiet" | crontab -
  fi
  
  # Configurar aplicação Node.js principal
  cat > "$MCP_BASE_DIR/app/server.js" << EOF
const http = require('http');
const fs = require('fs');
const path = require('path');

const port = $port;
const token = '$mcp_token';

const server = http.createServer((req, res) => {
  if (req.url === '/api/public/status') {
    // Endpoint público para verificar status
    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ status: 'online', mode: 'single' }));
    return;
  }
  
  // Todos os outros endpoints requerem token
  if (req.headers['x-mcp-token'] !== token) {
    res.statusCode = 403;
    res.end('Unauthorized');
    return;
  }
  
  if (req.url === '/api/status') {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ 
      status: 'online', 
      mode: 'single',
      db_type: '$db_type'
    }));
    return;
  }
  
  if (req.url === '/api/db/credentials') {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/json');
    const data = {};
    
    if (fs.existsSync('$MCP_BASE_DIR/db/conf/postgres_credentials.conf')) {
      const pgCreds = fs.readFileSync('$MCP_BASE_DIR/db/conf/postgres_credentials.conf', 'utf8');
      data.postgres = {};
      pgCreds.split('\\n').forEach(line => {
        const parts = line.split('=');
        if (parts.length === 2) {
          data.postgres[parts[0]] = parts[1];
        }
      });
    }
    
    if (fs.existsSync('$MCP_BASE_DIR/db/conf/mysql_credentials.conf')) {
      const mysqlCreds = fs.readFileSync('$MCP_BASE_DIR/db/conf/mysql_credentials.conf', 'utf8');
      data.mysql = {};
      mysqlCreds.split('\\n').forEach(line => {
        const parts = line.split('=');
        if (parts.length === 2) {
          data.mysql[parts[0]] = parts[1];
        }
      });
    }
    
    res.end(JSON.stringify(data));
    return;
  }
  
  res.statusCode = 404;
  res.end('Not found');
});

server.listen(port, () => {
  console.log(\`MCP Server running on port \${port}\`);
});
EOF
  
  # Configurar serviço systemd
  cat > /etc/systemd/system/mcp-server.service << EOF
[Unit]
Description=MCP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$MCP_BASE_DIR/app
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  
  # Habilitar e iniciar o serviço
  systemctl daemon-reload
  systemctl enable mcp-server
  systemctl start mcp-server
  
  echo "Configuração do servidor único concluída"
}

# Este script não deve ser executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Este script deve ser chamado a partir do install.sh"
  exit 1
fi