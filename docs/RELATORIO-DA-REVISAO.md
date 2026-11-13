# Revisão do controle financeiro — Hotel Serra Negra

13/11/2026. Base: HSNFinanceiroDefinitivo-main (2)(1).zip.

## Preservação e escopo

Uma cópia binária do ZIP foi feita antes das alterações. SHA-256:
`20d53c8c44a3b7d4ec4a9472ba1b9ae922991ab4b7de969989d40334d60e9e13`.
A entrega inclui essa cópia fora da pasta do sistema.

A análise foi do código. Não havia exportação do banco nem documentos financeiros. Não foram acessados/alterados dados reais, enviadas cobranças ou realizadas operações bancárias. Inconsistências específicas de títulos antigos dependem da comparação com os documentos do hotel.

## Causas identificadas

| Código / causa | Efeito | Correção |
|---|---|---|
| `finance.js` / `bulkMarkPaid` substitui `actual_amount` pelo valor pago e sempre marca `paid` | Uma parcela pode reduzir o total original e quitar indevidamente a dívida | Livro de baixas e saldo cumulativo; quitação apenas no pagamento integral |
| Relatórios/previsão consideram somente `payment_status` | Cancelados entram no pendente e parcelas não são abatidas | Cálculo compartilhado de saldo; cancelamentos excluídos da obrigação pendente |
| Painel antigo usa competência/status para mostrar pago no mês | Mês da conta se confunde com data do dinheiro | Vencimento para obrigação; data efetiva para caixa |
| Sicoob identifica por nosso número + vencimento e descarta linhas inválidas | Alteração de vencimento pode criar outra dívida; erros não são visíveis | Prévia por linha, chave pelo nosso número e divergência bloqueada |
| Duplicidade depende da consulta anterior à inserção no navegador | Duas telas podem aprovar a mesma inclusão | Importação serializada no banco e repetição idempotente de operações |
| Arquivados não bloqueiam reimportação | Uma obrigação arquivada pode reaparecer como nova | Arquivados/cancelados continuam participando da verificação |
| Nome parecido de fornecedor é tratado como certeza | Pode confundir empresas distintas | Similaridade gera revisão; bloqueio usa identificação exata |
| Importador do hotel acessa `r.warnings` sem inicializar | Confirmação pode falhar durante a revisão | Inicialização corrigida |
| Leitura do extrato prioriza débito e ignora coluna de crédito | Recebimentos podem ficar fora da conferência | Leitura de ambos os sentidos e erros de valor/data explícitos |
| Sicoob permite “Marcar pago/Reabrir” sem livro financeiro | Correções sem data/referência/motivo consistentes | Registro de recebimento e estorno auditado |
| Faturamento atribui tipo de anexo pela posição na seleção | Boleto, NF e extrato podem ocupar campos trocados | Escolha explícita de tipo, sem repetição |
| HTML/README citam arquivos ausentes e logout chama `reset` ausente | Instalação incompleta e falha ao limpar dados privados | Referência CSS removida, cache atualizado e limpeza de sessão implementada |

## Regras implementadas

- Total original, valor baixado e saldo são separados. Cálculos em centavos no aplicativo e `numeric` no banco.
- Baixas exigem valor positivo, data efetiva até hoje, referência e motivo. Excesso gera divergência; não são inventados juros ou descontos.
- Solicitações têm identificadores de repetição segura. A mesma referência, data, valor e título também bloqueiam uma segunda baixa ativa.
- Estorno acrescenta evento vinculado à baixa original e reabre o saldo, sem apagar histórico nem executar transferência.
- O banco bloqueia registros durante a baixa; edições de títulos verificam a versão consultada para evitar sobreposição entre aparelhos.
- Cancelamento exige motivo e nenhum valor recebido ativo. Arquivar é organização visual e não extingue dívida.
- Contas a receber usam o próprio título `sicoob_collections`. Hóspede, reserva, período, NF e documentos são ligados a esse registro, sem outra dívida paralela.
- Cobrança emitida/enviada, faturamento enviado e dinheiro recebido são situações diferentes. Reenvio mantém o ID original.
- Títulos com recebimento parcial têm reenvio do valor original bloqueado no cliente. A função de envio externa não veio no ZIP para adaptação segura ao saldo remanescente.
- Extrato é identificado por conta + referência estável. Um movimento já conciliado não baixa outro título. Crédito baixa recebível; débito baixa conta a pagar. Data, sinal e valor precisam conferir.
- A equipe confirma a conciliação. Sem referência estável, liquidação ou data válida, o movimento não é elegível. Não há baixa automática por valor/data parecidos.
- Importações mostram resultados por linha e guardam os lotes. O status pago do CSV é informativo: a obrigação é importada e a baixa confirmada separadamente.
- Pagamentos antigos são preservados. Data ausente não é inventada: fica sinalizada e fora do caixa por período.
- Faturamento mostra hospedagem incompleta, documentos faltantes e envio pendente no check-out. Referência de documento é conferência administrativa; não equivale a upload nem entrega.
- Alterar empresa, hóspede, reserva, período, NF, valor ou documentos invalida a confirmação anterior de envio do faturamento, mantendo a alteração no histórico.
- Livro financeiro, estornos, lotes e alterações importantes são preservados. Há cópia dos registros antes da migração e exportação financeira completa em JSON.

## Fluxo da equipe

1. Confira a prévia e importe. Divergência exige correção da origem ou do título existente, sem recriar a dívida.
2. Vincule reserva, hóspede e período. Confira extrato/voucher e documentos emitidos.
3. Envie o faturamento no check-out e registre a confirmação. Resposta incerta do Zoho exige conferir Enviados antes de repetir.
4. Importe o banco, confira a identidade do lançamento e registre as parcelas efetivamente recebidas/pagas.
5. Trate documentos faltantes, atrasos e divergências pelo painel. Corrija erro de baixa com estorno e motivo.

## Validação e limites

Passaram 55 testes locais: 17 de regras, 20 de integração SQL, 9 de regressão da migração com legado zero/ausente e 9 de formulários/navegação. Os JSON nesta pasta detalham os testes executados. As regras SQL foram testadas em PostgreSQL WASM/PGlite com esquema reconstruído a partir dos campos usados pelo programa. Os formulários/navegação foram testados em JSDOM ligados a essas mesmas rotinas. Isso confirma os fluxos locais; o esquema, RLS, gatilhos e funções instalados no Supabase real ainda precisam ser homologados.

O ambiente bloqueou a inicialização do Chromium automatizado e a conexão do navegador compartilhado ao servidor local. Não houve validação visual renderizada, teste real de PWA, acesso ao banco do hotel ou entrega de e-mail. O teste de navegador permanece incluído para homologação.

O README anterior cita arquivos de backend ausentes. Foram mantidos os contratos de `zoho-send-mail` e `zoho-billing-mail`; a instalação dessas funções, tabelas e auxiliares precisa ser conferida. Envio confirmado não é pagamento.

A atualização não reconstrói um valor original já sobrescrito no passado. Compare NF, extrato da hospedagem e comprovantes para corrigir esses casos com justificativa no histórico. Juros, descontos, abatimentos, excesso de pagamento e uma transferência distribuída entre vários títulos exigem conferência; não há rateio automático nesta versão.

## Implantação

Siga o README. Teste primeiro em cópia do banco atual: recebível, parcela, estorno, importação repetida e envio para endereço controlado pelo hotel. O backup do código não substitui exportação do banco/Storage. Publique os arquivos estáticos em conjunto e mantenha a cópia original fora da pasta pública.
