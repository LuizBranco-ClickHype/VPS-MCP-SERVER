#!/bin/bash
# postgres-mcp-setup.sh - Configuração do MCP para PostgreSQL
# Parte do projeto VPS MCP SERVER
# Este script configura o acesso ao banco de dados PostgreSQL via MCP

# Diretório base
MCP_BASE_DIR="/opt/mcp-server"
CONFIG_FILE="$MCP_BASE_DIR/config/mcp-config.txt"
PG_MCP_DIR="$MCP_BASE_DIR/postgres-mcp"
LOG_FILE="$MCP_BASE_DIR/logs/postgres-mcp-setup.log"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  echo -e "[$timestamp] [$level] $message" >> "$LOG_FILE"
  
  case "$level" in
    INFO)
      echo -e "${BLUE}INFO:${NC} $message"
      ;;
    SUCCESS)
      echo -e "${GREEN}SUCCESS:${NC} $message"
      ;;
    WARNING)
      echo -e "${YELLOW}WARNING:${NC} $message"
      ;;
    ERROR)
      echo -e "${RED}ERROR:${NC} $message"
      ;;
    *)
      echo -e "$message"
      ;;
  esac
}

# Verifica se está rodando como root
check_root() {
  if [ "$(id -u)" != "0" ]; then
    log "ERROR" "Este script precisa ser executado como root"
    echo "Execute com sudo ou como usuário root"
    exit 1
  fi
}

# Verifica se o PostgreSQL está instalado
check_postgresql() {
  if ! command -v psql &> /dev/null; then
    log "ERROR" "PostgreSQL não está instalado"
    echo "Instale o PostgreSQL antes de executar este script"
    echo "Execute: apt-get install -y postgresql postgresql-contrib"
    exit 1
  fi
  
  log "INFO" "PostgreSQL encontrado: $(psql --version)"
}

# Verifica se o pgvector está disponível
check_pgvector() {
  if sudo -u postgres psql -c "SELECT * FROM pg_available_extensions WHERE name = 'vector'" | grep -q vector; then
    log "INFO" "Extensão pgvector disponível"
    return 0
  else
    log "WARNING" "Extensão pgvector não encontrada"
    return 1
  fi
}

# Cria banco de dados e usuário para o MCP
setup_database() {
  log "INFO" "Configurando banco de dados para o PostgreSQL MCP"
  
  # Gerar senha
  local pg_password=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 16)
  
  # Verificar se o usuário mcp existe
  if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='mcp'" | grep -q 1; then
    log "INFO" "Usuário 'mcp' já existe"
  else
    # Criar usuário
    sudo -u postgres psql -c "CREATE USER mcp WITH PASSWORD '$pg_password';"
    log "SUCCESS" "Usuário 'mcp' criado"
  fi
  
  # Verificar se o banco de dados mcp_vector existe
  if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw mcp_vector; then
    log "INFO" "Banco de dados 'mcp_vector' já existe"
  else
    # Criar banco de dados
    sudo -u postgres psql -c "CREATE DATABASE mcp_vector OWNER mcp;"
    log "SUCCESS" "Banco de dados 'mcp_vector' criado"
  fi
  
  # Conceder privilégios
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mcp_vector TO mcp;"
  
  # Ativar extensão pgvector
  if check_pgvector; then
    sudo -u postgres psql -d mcp_vector -c "CREATE EXTENSION IF NOT EXISTS vector;"
    log "SUCCESS" "Extensão pgvector ativada no banco de dados"
  fi
  
  # Salvar credenciais
  mkdir -p "$PG_MCP_DIR/config"
  
  cat > "$PG_MCP_DIR/config/pg_credentials.conf" << EOF
# Credenciais PostgreSQL para MCP
# Gerado em $(date)
PG_USER=mcp
PG_PASSWORD=$pg_password
PG_DATABASE=mcp_vector
PG_HOST=localhost
PG_PORT=5432
EOF
  
  chmod 600 "$PG_MCP_DIR/config/pg_credentials.conf"
  log "SUCCESS" "Credenciais salvas em $PG_MCP_DIR/config/pg_credentials.conf"
  
  # Atualizar token no arquivo de configuração global
  if [ -f "$CONFIG_FILE" ]; then
    local pg_token=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 32)
    sed -i "s/^POSTGRES_TOKEN=.*/POSTGRES_TOKEN=$pg_token/" "$CONFIG_FILE"
    log "SUCCESS" "Token PostgreSQL atualizado no arquivo de configuração global"
  fi
}

# Configura servidor MCP para PostgreSQL
setup_postgres_mcp() {
  log "INFO" "Configurando servidor MCP para PostgreSQL"
  
  # Criar diretórios
  mkdir -p "$PG_MCP_DIR"
  mkdir -p "$PG_MCP_DIR/scripts"
  
  # Obter token MCP global
  local mcp_token=""
  if [ -f "$CONFIG_FILE" ]; then
    mcp_token=$(grep "^MCP_TOKEN=" "$CONFIG_FILE" | cut -d '=' -f 2)
  fi
  
  if [ -z "$mcp_token" ]; then
    mcp_token=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 32)
    log "WARNING" "Token MCP não encontrado no arquivo de configuração. Gerando novo token."
  fi
  
  # Obter credenciais do banco de dados
  local pg_credentials="$PG_MCP_DIR/config/pg_credentials.conf"
  local pg_user="mcp"
  local pg_password=""
  local pg_database="mcp_vector"
  local pg_host="localhost"
  local pg_port="5432"
  
  if [ -f "$pg_credentials" ]; then
    pg_user=$(grep "^PG_USER=" "$pg_credentials" | cut -d '=' -f 2)
    pg_password=$(grep "^PG_PASSWORD=" "$pg_credentials" | cut -d '=' -f 2)
    pg_database=$(grep "^PG_DATABASE=" "$pg_credentials" | cut -d '=' -f 2)
    pg_host=$(grep "^PG_HOST=" "$pg_credentials" | cut -d '=' -f 2)
    pg_port=$(grep "^PG_PORT=" "$pg_credentials" | cut -d '=' -f 2)
  fi
  
  # Criar arquivo de serviço para o MCP PostgreSQL
  cat > "$PG_MCP_DIR/pg-mcp-service.js" << EOF
/**
 * Serviço MCP para PostgreSQL
 * Integra o PostgreSQL com suporte a pgvector ao MCP
 */

const http = require('http');
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

// Configurações
const PORT = process.env.PG_MCP_PORT || 3001;
const TOKEN = process.env.MCP_TOKEN || '$mcp_token';

// Conexão com o banco de dados
const dbConfig = {
  user: '$pg_user',
  password: '$pg_password',
  host: '$pg_host',
  database: '$pg_database',
  port: $pg_port,
};

// Criar servidor HTTP
const server = http.createServer(async (req, res) => {
  // Verificar token de autenticação
  const authToken = req.headers['x-mcp-token'];
  if (authToken !== TOKEN) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Unauthorized' }));
    return;
  }
  
  // Verificar método
  if (req.method !== 'POST') {
    res.writeHead(405, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Method not allowed' }));
    return;
  }
  
  // Ler corpo da requisição
  let body = '';
  req.on('data', chunk => {
    body += chunk.toString();
  });
  
  req.on('end', async () => {
    try {
      const data = JSON.parse(body);
      
      // Processar comandos
      switch (req.url) {
        case '/api/status':
          handleStatus(res);
          break;
          
        case '/api/query':
          await handleQuery(res, data);
          break;
          
        case '/api/vector':
          await handleVector(res, data);
          break;
          
        default:
          res.writeHead(404, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Endpoint not found' }));
      }
    } catch (error) {
      console.error('Error processing request:', error);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Internal server error', details: error.message }));
    }
  });
});

// Manipulador para status
function handleStatus(res) {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'online',
    service: 'postgres-mcp',
    version: '1.0.0',
    pgvector: true,
    timestamp: new Date().toISOString()
  }));
}

// Manipulador para consultas SQL
async function handleQuery(res, data) {
  if (!data.query) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Missing query parameter' }));
    return;
  }
  
  const client = new Client(dbConfig);
  
  try {
    await client.connect();
    const result = await client.query(data.query, data.params || []);
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      success: true,
      result: result.rows,
      rowCount: result.rowCount
    }));
  } catch (error) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      success: false,
      error: error.message
    }));
  } finally {
    await client.end();
  }
}

// Manipulador para operações com vetores
async function handleVector(res, data) {
  if (!data.operation) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Missing operation parameter' }));
    return;
  }
  
  const client = new Client(dbConfig);
  
  try {
    await client.connect();
    
    let result;
    switch (data.operation) {
      case 'store':
        if (!data.collection || !data.vector || !data.metadata) {
          throw new Error('Missing required parameters for store operation');
        }
        
        // Criar tabela se não existir
        await client.query(\`
          CREATE TABLE IF NOT EXISTS \${data.collection} (
            id SERIAL PRIMARY KEY,
            vector vector(1536),
            metadata JSONB,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        \`);
        
        // Inserir vetor
        result = await client.query(
          \`INSERT INTO \${data.collection} (vector, metadata) VALUES ($1, $2) RETURNING id\`,
          [data.vector, data.metadata]
        );
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: true,
          id: result.rows[0].id
        }));
        break;
        
      case 'search':
        if (!data.collection || !data.vector || !data.limit) {
          throw new Error('Missing required parameters for search operation');
        }
        
        // Buscar vetores similares
        result = await client.query(
          \`SELECT id, metadata, vector <-> $1 as distance FROM \${data.collection}
           ORDER BY distance LIMIT $2\`,
          [data.vector, data.limit]
        );
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: true,
          results: result.rows
        }));
        break;
        
      default:
        throw new Error(\`Unknown operation: \${data.operation}\`);
    }
  } catch (error) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      success: false,
      error: error.message
    }));
  } finally {
    await client.end();
  }
}

// Iniciar servidor
server.listen(PORT, () => {
  console.log(\`PostgreSQL MCP Server running on port \${PORT}\`);
});
EOF
  
  # Criar package.json
  cat > "$PG_MCP_DIR/package.json" << EOF
{
  "name": "postgres-mcp",
  "version": "1.0.0",
  "description": "MCP Server para PostgreSQL com suporte a pgvector",
  "main": "pg-mcp-service.js",
  "scripts": {
    "start": "node pg-mcp-service.js"
  },
  "dependencies": {
    "pg": "^8.11.0"
  }
}
EOF
  
  # Instalar dependências
  cd "$PG_MCP_DIR"
  npm install
  
  # Criar serviço systemd
  cat > /etc/systemd/system/postgres-mcp.service << EOF
[Unit]
Description=PostgreSQL MCP Service
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=$PG_MCP_DIR
Environment="MCP_TOKEN=$mcp_token"
Environment="PG_MCP_PORT=3001"
ExecStart=/usr/bin/node pg-mcp-service.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  
  # Recarregar systemd
  systemctl daemon-reload
  
  # Habilitar e iniciar serviço
  systemctl enable postgres-mcp
  systemctl start postgres-mcp
  
  # Verificar status
  if systemctl is-active --quiet postgres-mcp; then
    log "SUCCESS" "Serviço PostgreSQL MCP iniciado com sucesso"
  else
    log "ERROR" "Falha ao iniciar serviço PostgreSQL MCP"
    log "INFO" "Verifique o status com: systemctl status postgres-mcp"
  fi
  
  # Adicionar ao mcp.json
  local mcp_json="$MCP_BASE_DIR/mcp.json"
  if [ -f "$mcp_json" ]; then
    # Verificar se já existe entrada para PostgreSQL
    if grep -q '"postgresql"' "$mcp_json"; then
      log "INFO" "Entrada para PostgreSQL já existe no mcp.json"
    else
      # Adicionar entrada para PostgreSQL (usando temporário para manter formatação)
      local temp_file=$(mktemp)
      jq '.mcpServers += {"postgresql": {"description": "PostgreSQL com suporte a pgvector", "command": "node", "args": ["pg-mcp-service.js"]}}' "$mcp_json" > "$temp_file"
      mv "$temp_file" "$mcp_json"
      log "SUCCESS" "Configuração PostgreSQL adicionada ao mcp.json"
    fi
  else
    log "WARNING" "Arquivo mcp.json não encontrado"
  fi
}

# Função principal
main() {
  # Criar diretório de logs
  mkdir -p "$(dirname "$LOG_FILE")"
  
  log "INFO" "=== Iniciando configuração do MCP PostgreSQL ==="
  
  # Verificar se é root
  check_root
  
  # Verificar PostgreSQL
  check_postgresql
  
  # Verificar pgvector
  check_pgvector
  
  # Configurar banco de dados
  setup_database
  
  # Configurar MCP PostgreSQL
  setup_postgres_mcp
  
  log "SUCCESS" "=== Configuração do MCP PostgreSQL concluída ==="
  log "INFO" "Porta do serviço: 3001"
  log "INFO" "Para verificar o status: systemctl status postgres-mcp"
  log "INFO" "Para ver os logs: journalctl -u postgres-mcp"
}

# Executar função principal
main