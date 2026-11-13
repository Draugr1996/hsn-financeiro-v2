# Agendamentos opcionais do clone

O sistema de origem tem backup semanal às 07:00 UTC de domingo (04:00 em São Paulo) e verificação de notificações a cada cinco minutos. Esses agendamentos não foram ativados no clone. As configurações iniciais deixam o backup semanal e os envios push desativados.

Execute os trechos somente no **HSN Financeiro V2**, depois de criar o proprietário e conferir o funcionamento manual. O backup automático abaixo é uma cópia interna de dados; mantenha também exportações fora do banco e cópias dos arquivos privados. O JSON de backup não contém os bytes dos PDFs.

## Backup semanal

No SQL Editor, habilite a extensão e registre o agendamento:

```sql
create extension if not exists pg_cron;
select cron.schedule(
 'hsn-weekly-backup',
 '0 7 * * 0',
 'select hsn_private.weekly_backup();'
);
```

Depois, ative **backup semanal** nas configurações do aplicativo. Confira o status pelo módulo de backups e confirme que o servidor usa UTC:

```sql
select current_setting('cron.timezone',true) as cron_timezone;
select public.hsn_backup_schedule_status();
```

## Notificações push

Antes do agendamento, configure VAPID, `HSN_APP_URL` e `HSN_ENABLE_PUSH=true` nos Secrets das Edge Functions e inscreva um aparelho no clone.

Configure a MESMA chave nova `HSN_CRON_KEY` gerada para o clone tanto nos Secrets das funções quanto no Vault deste projeto, com o nome `hsn_push_cron_key`. Preencha o valor diretamente no painel Vault do Supabase. Não publique essa chave em SQL versionado.

Em seguida, no SQL Editor do clone:

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
select cron.schedule(
 'hsn-push-dispatch',
 '*/5 * * * *',
 'select hsn_private.request_push_run();'
);
```

Confira os agendamentos e a execução pelo painel Cron. A função lê o URL deste clone na configuração privada e a chave no Vault; não chama o projeto original.

Se precisar pausar um agendamento, use o painel Cron para desativá-lo. Não exclua o projeto nem seus dados para interromper notificações.
