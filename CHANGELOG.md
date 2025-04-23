# Changelog do VPS MCP SERVER

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [1.0.0] - 2023-04-23

### Adicionado
- Script de instalação principal com suporte a três modos: único, aplicação e banco de dados
- Configuração automática de servidores PostgreSQL e MySQL
- Suporte a pgvector para vetores em banco de dados PostgreSQL
- Integração com Nginx e configuração automática de certificados SSL
- Sistema de gerenciamento de tokens MCP
- API RESTful para comunicação entre servidores
- Documentação completa de instalação e uso
- Scripts de gerenciamento e monitoramento

### Implementações Específicas
- Sistema de verificação automática de ambiente
- Geração segura de tokens e senhas
- Configuração de firewall automática
- Integração com Context7 para acesso a documentação
- Sistema de backup automático de configurações

## [0.9.0] - 2023-04-15

### Adicionado
- Versão beta completa com todos os componentes principais
- Testes em ambientes Ubuntu 20.04, 22.04 e Debian 11
- Suporte a configurações personalizadas
- Implementação inicial de MCPs para PostgreSQL

### Corrigido
- Problemas de permissão em diretórios de configuração
- Erros na comunicação entre servidor de aplicação e banco de dados
- Validação de entradas de usuário durante instalação

## [0.8.0] - 2023-04-01

### Adicionado
- Primeira versão alfa para testes internos
- Implementação básica dos scripts de instalação
- Estrutura inicial do projeto
- Sistema de logging

### Conhecido
- Limitações na configuração automática de firewall
- Suporte limitado a diferentes distribuições Linux
- Falta de validação em algumas entradas de usuário