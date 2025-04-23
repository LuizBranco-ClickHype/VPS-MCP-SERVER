#!/bin/bash
# app-server.sh - Configuração do servidor de aplicação
# Parte do projeto VPS MCP SERVER
# Este script é chamado pelo install.sh no modo app

# Verifica se as variáveis necessárias estão definidas
if [ -z "$MCP_BASE_DIR" ] || [ -z "$MCP_LOG_DIR" ]; then
  echo "Erro: Este script deve ser chamado a partir do install.sh"
  exit 1
fi

# Função para configurar o servidor de aplicação
setup_app_server() {
  local domain="$1"
  local db_host="$2"
  local port="$3"
  local mcp_token="$4"
  local email="$5"
  
  echo "Configurando servidor de aplicação..."
  echo "Domínio: $domain"
  echo "Host do banco de dados: $db_host"
  echo "Porta: $port"
  
  # Criar diretório para a aplicação
  mkdir -p "$MCP_BASE_DIR/app"
  
  # Configurar Nginx
  apt-get install -y nginx certbot python3-certbot-nginx
  
  # Configurar arquivo de configuração Nginx para a aplicação
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
  
  # Configurar arquivo de conexão com o banco de dados
  if [ -n "$db_host" ]; then
    cat > "$MCP_BASE_DIR/config/database.conf" << EOF
DB_HOST=$db_host
DB_PORT=5432
DB_SSL=true
MCP_TOKEN=$mcp_token
EOF
    
    # Testar conexão com o banco de dados
    echo "Testando conexão com o banco de dados..."
    if nc -z -w5 "$db_host" 5432; then
      echo "Conexão com o banco de dados estabelecida com sucesso"
    else
      echo "Aviso: Não foi possível conectar ao banco de dados. Verifique se o servidor de banco de dados está configurado corretamente."
    fi
  else
    echo "Aviso: Host do banco de dados não configurado. Configure manualmente mais tarde."
  fi
  
  # Configurar aplicação Node.js
  cat > "$MCP_BASE_DIR/app/server.js" << EOF
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
    res.end(JSON.stringify({ status: 'online', server_type: 'app' }));
    return;
  }
  
  res.statusCode = 404;
  res.end('Not found');
});

server.listen(port, () => {
  console.log(\`MCP Application Server running on port \${port}\`);
});
EOF
  
  # Configurar serviço systemd
  cat > /etc/systemd/system/mcp-app.service << EOF
[Unit]
Description=MCP Application Server
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
  systemctl enable mcp-app
  systemctl start mcp-app
  
  echo "Configuração do servidor de aplicação concluída"
}

# Este script não deve ser executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Este script deve ser chamado a partir do install.sh"
  exit 1
fi