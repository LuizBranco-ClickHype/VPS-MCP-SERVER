# Guia de Contribuição para o VPS MCP SERVER

Obrigado pelo interesse em contribuir para o VPS MCP SERVER! Este documento fornece diretrizes e informações para ajudar no processo de contribuição.

## Índice

1. [Código de Conduta](#código-de-conduta)
2. [Como Contribuir](#como-contribuir)
   - [Reportando Bugs](#reportando-bugs)
   - [Sugerindo Melhorias](#sugerindo-melhorias)
   - [Enviando Pull Requests](#enviando-pull-requests)
3. [Estilo de Código](#estilo-de-código)
4. [Processo de Desenvolvimento](#processo-de-desenvolvimento)
5. [Estrutura do Projeto](#estrutura-do-projeto)
6. [Testes](#testes)
7. [Documentação](#documentação)
8. [Contato](#contato)

## Código de Conduta

Este projeto segue um Código de Conduta que todos os participantes devem aderir. Por favor, leia [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) antes de contribuir.

## Como Contribuir

### Reportando Bugs

Bugs são rastreados como issues no GitHub. Antes de criar um novo issue, verifique se já não existe um relatando o mesmo problema.

Para reportar um bug:

1. Use um título claro e descritivo
2. Descreva os passos para reproduzir o problema
3. Descreva o comportamento esperado
4. Descreva o comportamento observado
5. Inclua detalhes do ambiente (SO, versão do sistema, etc.)
6. Adicione capturas de tela se possível

### Sugerindo Melhorias

Melhorias são bem-vindas! Para sugerir uma melhoria:

1. Use um título claro e descritivo
2. Forneça uma descrição detalhada da sugestão
3. Explique por que essa melhoria seria útil
4. Inclua exemplos de como a funcionalidade seria usada

### Enviando Pull Requests

1. Fork o repositório
2. Crie um branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Faça suas alterações
4. Certifique-se de que os testes passam
5. Commit suas alterações (`git commit -m 'Add some AmazingFeature'`)
6. Push para o branch (`git push origin feature/AmazingFeature`)
7. Abra um Pull Request

## Estilo de Código

- Use indentação de 2 espaços para arquivos bash
- Use indentação de 2 espaços para JavaScript
- Mantenha linhas com no máximo 80 caracteres
- Use comentários significativos
- Siga as práticas de shellcheck para scripts bash
- Use nomes descritivos para variáveis e funções

## Processo de Desenvolvimento

1. Escolha uma issue para trabalhar ou crie uma nova
2. Discuta a abordagem na issue
3. Implemente a solução
4. Adicione testes conforme necessário
5. Atualize a documentação
6. Envie um Pull Request

## Estrutura do Projeto

```
/
├── app-server.sh          # Script para configuração do servidor de aplicação
├── db-server.sh           # Script para configuração do servidor de banco de dados
├── single-server.sh       # Script para configuração de servidor único
├── install.sh             # Script de instalação principal
├── mcp-service.sh         # Script do serviço MCP
├── postgres-mcp-setup.sh  # Configuração do MCP PostgreSQL
├── mcp-config.txt         # Modelo de configuração
├── gerenciar-mcp-config.sh # Gerenciamento de configurações
├── vps-mcp.sh             # Script de gerenciamento do servidor
├── mcp-model.json         # Modelo para configuração dos MCPs
├── mcp.json               # Configuração dos MCPs
├── README.md              # Documentação principal
├── LICENSE                # Licença do projeto
└── docs/                  # Documentação adicional
```

## Testes

Antes de enviar um Pull Request, teste suas alterações em diferentes ambientes:

- Ubuntu 20.04 ou posterior
- Debian 11 ou posterior
- Diferentes configurações de rede

## Documentação

- Mantenha a documentação atualizada
- Adicione comentários em código complexo
- Documente novas funcionalidades
- Atualize o README.md quando necessário

## Contato

Se você tiver dúvidas ou precisar de ajuda, pode entrar em contato através das issues do GitHub ou pelo email [contato@vps-mcp-server.com](mailto:contato@vps-mcp-server.com).