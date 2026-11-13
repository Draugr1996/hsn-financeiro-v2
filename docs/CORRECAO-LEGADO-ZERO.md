# Correção HSN 10.0.1 — migração com valor zero

O erro 23514 ocorreu porque a migração tentou criar uma abertura financeira de 0,00 para um registro antigo marcado pago. A tabela de eventos aceita apenas valores positivos, corretamente.

A correção calcula o valor do legado uma única vez. Apenas valores maiores que zero geram abertura. Registros com valor zero/ausente/negativo permanecem na origem e no backup, sem inventar pagamento nem substituir um valor real zero por uma estimativa. Esses registros ganham um aviso `MIGRATION_REVIEW` no histórico, com os valores originais intactos. A repetição da migração não duplica eventos nem avisos.

## Como executar

1. Mantenha o backup do banco e dos documentos.
2. Abra uma nova consulta no SQL Editor do Supabase. Se a conexão estiver com transação abortada, execute `ROLLBACK;` separadamente.
3. Abra o arquivo atualizado `sql/HSN-10-integridade-financeira.sql` e execute TODO o conteúdo, do `BEGIN` ao resultado de conferência após o `COMMIT`.
4. Ao final, eventuais linhas de conferência são avisos sobre registros históricos preservados, não pagamentos gerados. Confira esses registros com os documentos do hotel depois da instalação.

Não remova a restrição `amount > 0`, não coloque 0,01 nas contas e não exclua os registros antigos.

## Verificação

O erro original foi reproduzido em PostgreSQL WASM com um registro pago de valor real 0,00 e estimativa 500,00. A execução antiga falhou com a mesma restrição; após ROLLBACK os registros permaneceram intactos. O SQL corrigido conclui sem usar os 500,00 como pagamento. Foram aprovados nove novos testes de regressão, além dos 46 testes anteriores: 55 no total. O banco real não foi acessado ou alterado nesta correção.
