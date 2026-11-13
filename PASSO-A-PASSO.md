# Como instalar e usar o clone do Financeiro HSN

Preparado em 13/11/2026 para Vanderson Santos e a equipe do Hotel Serra Negra.

**Atualização:** o repositório privado `Draugr1996/hsn-financeiro-v2` já foi criado. O banco e as oito funções também estão instalados. Para concluir o acesso, comece pelo passo 2.


O clone tem código próprio e banco separado. O sistema atual continua sendo a referência até terminar a conferência. As contas e os documentos antigos não foram copiados para o banco novo.

## 1. Confira o projeto criado no Supabase

Abra https://supabase.com/dashboard e selecione **HSN Financeiro V2**, na organização **financeiro-hsn**.

Referência do projeto: `qbowrzgpmkvlmmckvwaz`. Região: São Paulo. A criação foi cotada em US$ 0/mês, no plano Free. Isso não representa garantia de gratuidade para qualquer consumo ou alteração futura de plano.

A estrutura já está instalada: 40 tabelas públicas, tabelas privadas de controle, regras de acesso, dois buckets privados e oito Edge Functions. Não execute novamente o instalador inicial nesse projeto. Os arquivos de `supabase/migrations/` servem para reproduzir a instalação em OUTRO projeto vazio e versionar o banco.

Não use os SQLs antigos de zerar dados. Este clone já começou sem os lançamentos do sistema anterior.

## 2. Crie seu usuário de acesso

No projeto **HSN Financeiro V2**:

1. Acesse **Authentication → Users → Add user → Create new user**.
2. Preencha o e-mail de acesso e uma senha escolhida por você. Marque a confirmação do e-mail se a criação administrativa oferecer essa opção.
3. Copie o **User UID** do novo usuário. O UID antigo não serve no novo projeto.
4. Em **Authentication → Sign In / Providers**, desative o cadastro público de novos usuários para manter o modelo de acesso do sistema recebido.
5. Abra o **SQL Editor** deste projeto e execute o comando abaixo, trocando apenas o texto indicado pelo UUID copiado:

```sql
select hsn_private.initialize_clone('COLE_AQUI_O_NOVO_USER_UID'::uuid);
```

A inicialização cadastra o proprietário, as configurações padrão de contas e comissões, o tema e os três grupos de notificações. Reexecutar com o mesmo UID não duplica configurações. Ela não troca um proprietário existente por outro.

O aplicativo recebido usa um único usuário proprietário. Este clone preserva esse modelo; não foi implantado um sistema novo de permissões por funcionário. Os registros de auditoria identificam o usuário autenticado, não qual pessoa utilizou uma senha compartilhada.

## 3. Configure o aplicativo

1. Abra `configurar.html` pelo site do clone ou, no computador, pela pasta extraída. Não é necessário fazer login nessa página.
2. Mantenha o URL e a referência do projeto novo.
3. Copie a chave **publishable** em **Settings → API Keys** do Supabase novo. Não copie a chave secret ou service_role.
4. Preencha o mesmo e-mail e o UID do passo anterior.
5. Clique em **Baixar config.js**.
6. Substitua o arquivo `js/config.js` do clone pelo arquivo baixado.

A cópia preparada já contém o URL e a chave pública do banco novo; ainda faltam o e-mail e o UID. Se preferir editar o arquivo diretamente, altere somente esses dois campos. A página de configuração valida os campos, mas não grava nada no GitHub automaticamente.

Há proteção no código para bloquear a conexão com o banco antigo e rejeitar chaves secretas. A senha de acesso não deve entrar em `config.js`.

## 4. Salve em um repositório separado no GitHub

Nome sugerido: **hsn-financeiro-v2**. Use um repositório **privado** para guardar o código inicialmente.

1. No GitHub, clique em **+ → New repository**.
2. Escolha sua conta, preencha `hsn-financeiro-v2` e selecione **Private**.
3. Marque **Add a README file** e conclua a criação.
4. Abra **Add file → Upload files** e envie os arquivos e pastas de DENTRO da pasta do clone. `index.html`, `js`, `css`, `icons` e `supabase` devem ficar na raiz do repositório.
5. Não envie `node_modules`, arquivos `.env`, senhas, backups financeiros ou documentos de hóspedes.
6. Para enviar também os workflows em `.github`, use GitHub Desktop ou Git. Alguns exploradores ocultam essa pasta.

Se eu já tiver salvo o código em uma branch separada do repositório atual, você também pode selecioná-la no GitHub e usar **Code → Download ZIP**. Uma branch guarda uma versão isolada do código; não é um novo repositório e não troca o site atual automaticamente.

Com Git instalado, a partir da pasta extraída, use os comandos abaixo APÓS criar um repositório vazio (sem README). Substitua a URL pelo endereço mostrado pelo GitHub:

```bash
git init
git add .
git commit -m "Cria clone independente do Financeiro HSN"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/hsn-financeiro-v2.git
git push -u origin main
```

Não use comandos de sobrescrita forçada no repositório atual do hotel.

## 5. Publique o site do clone

**Guardar código no GitHub é diferente de colocar o aplicativo no ar.** O Supabase guarda o banco, o acesso, os arquivos privados e as funções; ele não publica automaticamente este frontend estático.

O pacote inclui publicação manual pelo GitHub Actions. O workflow publica somente os arquivos do aplicativo gerados em `dist/`. SQL, testes, funções de servidor, documentos de revisão e backups ficam fora do site.

Antes de publicar:

1. Termine a configuração de `js/config.js`.
2. No NOVO repositório, abra **Settings → Pages → Source → GitHub Actions**.
3. Abra **Actions → Publicar clone → Run workflow** e escolha a branch que contém o clone.
4. Aguarde a conclusão e use o endereço apresentado na publicação.
5. No Supabase novo, ajuste **Authentication → URL Configuration → Site URL** para o endereço do clone. Cadastre também o endereço nas URLs de retorno caso vá usar recuperação de senha por link.

O GitHub Pages no GitHub Free exige repositório público. Repositórios privados precisam de um plano compatível, como GitHub Pro ou Team. Mantenha o repositório privado se esse for o objetivo; nesse caso, use um plano compatível ou publique o frontend em uma hospedagem estática que aceite seu repositório privado. O workflow não muda a visibilidade do repositório.

Para conferir localmente antes da publicação, instale Node 24 e execute na pasta do clone:

```bash
npm ci
npm test
npm run check:config
npm run build
```

Sirva a pasta `dist` por um servidor HTTP local. Abrir o `index.html` diretamente como arquivo não reproduz o funcionamento do login e do PWA em HTTPS.

## 6. Configure o Zoho e as notificações

As oito funções foram recuperadas do servidor atual e instaladas no projeto novo. **Tokens OAuth e segredos do projeto antigo não foram copiados.** Cobranças e faturamentos só poderão sair após a configuração abaixo.

1. Em **Edge Functions → Secrets**, configure `HSN_APP_URL` com o endereço completo do site novo, incluindo a barra final.
2. Configure `ZOHO_CLIENT_ID` e `ZOHO_CLIENT_SECRET` usando as credenciais do aplicativo autorizado no Zoho. Preencha diretamente no Supabase; não envie esses valores ao GitHub.
3. No aplicativo OAuth do Zoho, cadastre este novo callback:

   `https://qbowrzgpmkvlmmckvwaz.supabase.co/functions/v1/zoho-oauth-callback`

4. Execute `node scripts/generate-integration-keys.cjs` em seu computador para criar chaves novas em `.env.integrations`. O script não consulta o sistema antigo nem envia nada.
5. Copie `ZOHO_TOKEN_ENCRYPTION_KEY` para os Secrets do Supabase novo. Preserve essa chave: ela será necessária para ler os tokens autorizados depois. Não substitua a chave após conectar o Zoho sem planejar uma nova autorização.
6. Abra **Conexão Zoho Mail** no clone e autorize a conta institucional. O remetente preservado é `faturamento@hotelserranegra.com.br`.
7. Somente após conferir conexão, remetente, destinatários e prévia, defina `HSN_ENABLE_EMAIL=true` nos Secrets para habilitar a integração. Faça o primeiro envio para um endereço controlado por você, usando documentos fictícios identificados como teste.

As notificações push são opcionais. Para ativá-las, configure também as novas chaves `HSN_VAPID_PUBLIC_KEY`, `HSN_VAPID_PRIVATE_KEY`, `HSN_VAPID_SUBJECT` e depois `HSN_ENABLE_PUSH=true`. Cada aparelho precisa se inscrever de novo no clone. As inscrições antigas não foram copiadas.

Agendamentos automáticos de push e backup NÃO foram ativados. O backup manual permanece disponível após o login. Se quiser agendamento, configure o Cron no projeto novo e confira o horário antes de habilitar; não copie chamadas do projeto anterior, que apontam para o endereço antigo. Consulte `docs/AGENDAMENTOS.md`.

As funções verificam sessão e proprietário no servidor. `verify_jwt=false` é intencional para compatibilidade com as chaves novas e com o callback OAuth; não transforma as rotinas financeiras em acesso anônimo.

## 7. Confira os fluxos antes de liberar para a equipe

Use registros fictícios no banco novo. Não envie cobranças de teste para clientes.

| Teste | Resultado esperado |
| --- | --- |
| Cadastrar conta a receber de R$ 1.000 e registrar R$ 300 | Total R$ 1.000, recebido R$ 300, saldo R$ 700 |
| Emitir/enviar uma cobrança | Valor recebido continua zero até confirmar pagamento |
| Reenviar cobrança já enviada | Mesmo título e mesma dívida; nova tentativa no histórico |
| Tentar reenviar R$ 1.000 após receber R$ 300 | Operação bloqueada para evitar cobrar o valor original |
| Importar o mesmo CSV duas vezes | Segunda importação informa duplicatas e não soma novamente |
| Importar extrato e apenas aceitar uma sugestão | Nenhuma baixa até a conferência e confirmação explícita |
| Conciliar um recebimento confirmado | Movimento vinculado a um único título; saldo atualizado |
| Estornar uma baixa com motivo | Baixa original preservada, estorno no histórico e saldo reaberto |
| Cancelar título sem baixa | Sai do saldo em aberto; registro e motivo continuam no histórico |
| Faturamento sem documento exigido | Pendência visível e confirmação de envio bloqueada |
| Confirmar envio do faturamento | Registra envio sem registrar recebimento |
| Sair e tentar acessar os dados | Login exigido; nenhuma tabela financeira liberada ao visitante |
| Abrir original e clone no mesmo navegador | Bancos, sessão de acesso, rascunhos e cache do clone separados |

Os testes automatizados verificam regras financeiras, banco PostgreSQL local, formulários e o esquema recuperado. Eles não substituem a conferência com seu login, arquivos bancários reais, Zoho e aparelhos da equipe. Consulte `docs/VALIDACAO-CLONE.json` e `docs/REVISAO-V10.md`.

Depois da conferência, comece a alimentar o clone e indique claramente à equipe qual endereço usar. Se quiser trazer cadastros ou saldos antigos no futuro, faça uma migração específica com conferência de totais; não importe o mesmo histórico por dois caminhos.

## Fontes técnicas

- Migração entre projetos: https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- Chaves novas e autenticação das funções: https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys
- Publicação pelo GitHub Actions: https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
- Disponibilidade do GitHub Pages por plano: https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site
