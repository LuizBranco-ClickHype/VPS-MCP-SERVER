#!/bin/bash
# db-server.sh - Configuração do servidor de banco de dados
# Parte do projeto VPS MCP SERVER
# Este script é chamado pelo install.sh no modo db

# Verifica se as variáveis necessárias estão definidas
if [ -z "$MCP_BASE_DIR" ] || [ -z "$MCP_LOG_DIR" ]; then
  echo "Erro: Este script deve ser chamado a partir do install.sh"
  exit 1
fi

# Função para configurar o servidor de banco de dados
setup_db_server() {
  local db_type="$1"
  local port="$2"
  local mcp_token="$3"
  local app_host="$4"
  
  echo "Configurando servidor de banco de dados..."
  echo "Tipo: $db_type"
  echo "Porta MCP: $port"
  echo "Host de aplicação: $app_host"
  
  # Criar diretório para configurações do banco de dados
  mkdir -p "$MCP_BASE_DIR/db"
  mkdir -p "$MCP_BASE_DIR/db/conf"
  mkdir -p "$MCP_BASE_DIR/db/data"
  
  # Configurar PostgreSQL
  if [[ "$db_type" == "postgres" || "$db_type" == "both" ]]; then
    echo "Configurando PostgreSQL..."
    
    # Instalar PostgreSQL
    apt-get update
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
    
    # Habilitar conexões externas
    if [ -n "$app_host" ]; then
      # Adicionar linha no pg_hba.conf para o servidor de aplicação
      PG_HBA_CONF=$(find /etc/postgresql -name pg_hba.conf)
      echo "host    all             mcp            $app_host/32           md5" >> "$PG_HBA_CONF"
      
      # Modificar postgresql.conf para ouvir em todas as interfaces
      PG_CONF=$(find /etc/postgresql -name postgresql.conf)
      sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
      
      # Reiniciar PostgreSQL
      systemctl restart postgresql
    fi
    
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
    apt-get update
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
    
    # Habilitar conexões externas se o host da aplicação for fornecido
    if [ -n "$app_host" ]; then
      mysql -e "CREATE USER IF NOT EXISTS 'mcp'@'$app_host' IDENTIFIED BY '$MYSQL_PASSWORD';"
      mysql -e "GRANT ALL PRIVILEGES ON mcp_database.* TO 'mcp'@'$app_host';"
      mysql -e "FLUSH PRIVILEGES;"
      
      # Configurar MySQL para aceitar conexões externas
      sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
      
      # Reiniciar MySQL
      systemctl restart mysql
    fi
  fi
  
  # Configurar serviço MCP para banco de dados
  cat > "$MCP_BASE_DIR/db/db_api.js" << EOF
const http = require('http');
const fs = require('fs');
const path = require('path');

const port = $port;
const token = '$mcp_token';

const server = http.createServer((req, res) => {
  if (req.headers['x-mcp-token'] !== token) {
    res.statusCode = 403;
    res.end('Unauthorized');
    return;
  }
  
  if (req.url === '/api/status') {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ status: 'online', server_type: 'db', db_types: ['$db_type'] }));
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
  console.log(\`MCP Database API running on port \${port}\`);
});
EOF
  
  # Configurar serviço systemd
  cat > /etc/systemd/system/mcp-db-api.service << EOF
[Unit]
Description=MCP Database API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$MCP_BASE_DIR/db
ExecStart=/usr/bin/node db_api.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  
  # Habilitar e iniciar o serviço
  systemctl daemon-reload
  systemctl enable mcp-db-api
  systemctl start mcp-db-api
  
  echo "Configuração do servidor de banco de dados concluída"
  echo "Credenciais salvas em $MCP_BASE_DIR/db/conf/"
}

# Este script não deve ser executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Este script deve ser chamado a partir do install.sh"
  exit 1
fi