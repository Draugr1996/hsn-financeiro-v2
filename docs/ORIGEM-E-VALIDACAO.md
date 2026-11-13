# Origem do clone e validação

Data: 13/11/2026. Fonte: código fornecido pelo usuário, revisão financeira 10.0.1 e leitura da estrutura do Supabase do hotel. Consultas ao projeto original foram somente de leitura. Não foi executado reset nem alteração do banco original nesta etapa.

O ZIP original foi preservado antes das alterações. Seu SHA-256 é `20d53c8c44a3b7d4ec4a9472ba1b9ae922991ab4b7de969989d40334d60e9e13`. Foi preservada também uma cópia da estrutura e do código das funções do servidor antes da adaptação do clone. Essa cópia não é um backup de todos os lançamentos nem dos arquivos do Storage.

## Recuperado do Supabase

- 40 tabelas públicas, 2 tabelas privadas existentes, colunas, padrões, restrições, índices, triggers, permissões e políticas.
- 26 rotinas públicas e 15 rotinas privadas.
- Metadados dos dois buckets privados, sem copiar os arquivos nem os registros de hóspedes.
- Código das oito Edge Functions existentes, sem ler ou exportar os valores dos Secrets ou os tokens OAuth.
- Frequência dos dois agendamentos existentes; não foram ativados no clone.

O clone adiciona uma tabela privada de configuração, inicialização parametrizada do proprietário e correções nas rotinas de envio. O instalador inicial exige projeto vazio e falha se já encontrar `public.payables`.

## Causa corrigida no servidor

A rotina de pré-reserva de cobranças admitia status `sent`, enquanto a reserva efetiva exigia `pending`. O encerramento registrava uma segunda linha de tentativa e mantinha a primeira em `processing`, além de manter a trava após sucesso. Isso confundia a leitura do histórico e impedia o reenvio.

No clone, cada tentativa registra início, término e resultado. O histórico de alteração fica no audit log. Sucesso e falha liberam a trava; resultado incerto (`review`) permanece bloqueado até conferência. Reenvio referencia o envio confirmado anterior e conserva o mesmo título. O servidor verifica baixas e cancelamento antes de permitir nova cobrança do valor original.

## Testes e limites

Foram usados testes de regras, PostgreSQL local/PGlite e formulários/DOM. Há testes específicos com a estrutura recuperada que verificam instalação vazia, inicialização idempotente, baixa parcial, reenvio, finalização de tentativas e isolamento por proprietário.

O projeto Supabase novo foi inspecionado após instalar as migrações: 40 tabelas públicas, nenhuma sem RLS, nenhuma conta a pagar ou a receber e nenhum proprietário ainda configurado. As oito funções foram publicadas ativas, mas e-mail e push dependem das flags de habilitação, ausentes por padrão.

A revisão de segurança do Supabase sinaliza funções `SECURITY DEFINER` intencionalmente acessíveis ao usuário autenticado (RPCs de baixas/estornos e backup). Elas verificam a identidade e a propriedade dos registros; os testes incluem tentativa de acesso de outro usuário. As rotinas internas de reserva/finalização de envios não são executáveis pelo cliente. Tabelas internas sem política RLS permanecem inacessíveis ao usuário comum por desenho. Remediações e referência: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable e https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy

Não foi feito envio real pelo Zoho, teste com senha do novo usuário, conferência visual em navegador nem inscrição push de um aparelho. A homologação operacional do guia precisa ser concluída antes de usar o clone com clientes.
