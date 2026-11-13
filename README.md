# Hotel Serra Negra · Financeiro V2

Clone independente do aplicativo recebido, com banco Supabase separado e melhorias de integridade financeira. Leia primeiro [PASSO-A-PASSO.md](PASSO-A-PASSO.md).

Inclui os módulos existentes de contas, fornecedores, recorrências, comissões, DDA, documentos, cobranças Sicoob, faturamento, comunicação, Zoho, notificações, histórico e backups. Incorpora contas a receber com hospedagem/documentos, pagamentos parciais, estornos, importação com prévia e idempotência, conciliação confirmada e painel que separa previsão e dinheiro recebido.

O esquema completo foi recuperado do banco real, incluindo o esquema privado e as oito funções do servidor que faltavam no ZIP. As duas migrações em `supabase/migrations` instalam um projeto novo vazio; a primeira já contém as regras financeiras da versão 10. Não execute também a migração antiga `sql/HSN-10-integridade-financeira.sql` nesse clone.

Melhorias específicas desta cópia:

- Conexão com o banco original bloqueada e configuração pública validada antes do login.
- Sessão, rascunhos, tema e cache separados do aplicativo anterior.
- Reenvio do mesmo título aceito pelo servidor, com proteção contra cobrança de títulos com baixas.
- Uma linha por tentativa de envio com início, término e auditoria; travas liberadas após sucesso/falha e mantidas em resultado incerto.
- Autorização do proprietário nas funções do servidor; e-mail e push desativados até configuração explícita.
- Publicação manual do frontend sem expor SQL, backups, testes ou código do servidor na pasta do site.

## Desenvolvimento

Node 24. `npm ci`; `npm test`; `npm run build`. O resultado publicável fica em `dist/`. A configuração real do novo usuário é necessária para `npm run check:config` e para a publicação.

As funções leem chaves e tokens apenas no servidor. Arquivos `.env` são ignorados pelo Git. Nunca publique dados bancários, documentos de hóspedes ou a chave `service_role`.

## Limites da entrega

Os lançamentos antigos, PDFs, tokens Zoho e inscrições push não foram migrados. Seu novo usuário e as integrações externas precisam ser configurados conforme o guia. Os testes locais não enviam e-mails. Não foi feita validação visual em navegador neste ambiente nem um envio real pelo Zoho.

Mantém o modelo de proprietário único do sistema recebido. Para usuários individuais por funcionário e trilha por pessoa, é necessário um trabalho específico de permissões.
