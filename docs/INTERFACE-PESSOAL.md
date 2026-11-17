# Interface pessoal · 17/11/2026

O sistema foi reorganizado para uso individual. A cópia anterior permanece na branch `backup/antes-interface-pratica-20261113`, no commit `1274f90ee45a52ea37765e69fdcff192079f29e1`.

- Menu principal: Meu dia, A pagar, A receber, Faturamento e Banco e importações. Cadastros, consultas e recursos ocasionais ficam em Configurações.
- Meu dia mostra os quatro indicadores por período e uma lista de pendências de todos os períodos, respeitando a empresa selecionada. Créditos bancários ainda sem vínculo são identificados como total de todas as empresas.
- Atalhos para nova despesa, novo faturamento, seleção de título para recebimento e importação de arquivo.
- Ficha de faturamento com cobrança, hospedagem, documentos, saldo e histórico do título. Os campos de documentos registram referências conferidas; não são novos anexos.
- Filtros de período, empresa, situação e tipos são lembrados no aparelho com chave própria por projeto, usuário e tela. Não são armazenados valores financeiros ou documentos nesses filtros.
- Comandos secundários ficam em Mais opções / Mais filtros e ferramentas. O resumo diário continua acessível nos alertas, sem abrir automaticamente.
- Alterações de apresentação e navegação. As confirmações de baixa, estorno, importação e envio continuam nas rotinas existentes.

Validação: testes de regras financeiras, SQL, isolamento, recuperação de senha e integração DOM, incluindo menu, abertura da ficha sem salvar dívida e filtros independentes por tela. O teste automatizado com Chromium local encontrou uma restrição de socket do ambiente; a conferência visual é feita no navegador compartilhado.
