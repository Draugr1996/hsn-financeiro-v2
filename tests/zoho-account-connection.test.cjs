const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');
const { webcrypto } = require('node:crypto');

const owner = '11111111-1111-4111-8111-111111111111';
const sender = 'faturamento@hotelserranegra.com.br';
const source = fs.readFileSync('supabase/functions/zoho-send-mail/index.ts', 'utf8');
const code = stripTypeScriptTypes(source.replace(/^import .*?;\r?\n/, ''), { mode: 'strip' });

async function server({ user = owner, mailbox = sender } = {}) {
  // Only synthetic credentials and encrypted tokens are used in these tests.
  const keyBytes = new Uint8Array(32).fill(7), iv = new Uint8Array(12).fill(9);
  const key = await webcrypto.subtle.importKey('raw', keyBytes, 'AES-GCM', false, ['encrypt']);
  const encrypted = await webcrypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, new TextEncoder().encode('fixture-refresh'));
  const stored = { refresh_token: Buffer.from(iv).toString('base64') + '.' + Buffer.from(encrypted).toString('base64') };
  const env = {
    HSN_APP_URL: 'https://example.com/financeiro/', HSN_ENABLE_EMAIL: 'true',
    SUPABASE_URL: 'https://fixture.supabase.co', SUPABASE_ANON_KEY: 'fixture-public',
    SUPABASE_SERVICE_ROLE_KEY: 'fixture-admin', ZOHO_CLIENT_ID: 'fixture-client',
    ZOHO_CLIENT_SECRET: 'fixture-secret', ZOHO_TOKEN_ENCRYPTION_KEY: Buffer.from(keyBytes).toString('base64'),
  };
  const calls = { network: [], updates: [], tables: [] };
  const client = {
    auth: { getUser: async () => ({ data: { user: user ? { id: user } : null }, error: null }) },
    rpc: async name => {
      assert.equal(name, 'hsn_push_owner');
      return { data: owner, error: null };
    },
    from(table) {
      calls.tables.push(table);
      assert.equal(table, 'zoho_mail_tokens', 'Identifying an account must not touch billing or send jobs');
      return {
        select() { return { eq(column, value) {
          assert.equal(column, 'user_id'); assert.equal(value, owner);
          return { maybeSingle: async () => ({ data: stored, error: null }) };
        } }; },
        update(values) { return { eq: async (column, value) => {
          assert.equal(column, 'user_id'); assert.equal(value, owner);
          calls.updates.push(values); return { error: null };
        } }; },
      };
    },
  };
  let handler;
  vm.runInNewContext(code, {
    createClient: () => client,
    Deno: { env: { get: name => env[name] }, serve: callback => { handler = callback; } },
    crypto: webcrypto, TextEncoder, TextDecoder, Request, Response, Headers, URL, URLSearchParams,
    AbortSignal, File, atob, btoa, console,
    fetch: async (url, options = {}) => {
      calls.network.push({ url: String(url), method: options.method || 'GET' });
      if (url === 'https://accounts.zoho.com/oauth/v2/token') {
        assert.equal(options.method, 'POST');
        assert.equal(new URLSearchParams(options.body).get('grant_type'), 'refresh_token');
        return Response.json({ access_token: 'fixture-access' });
      }
      assert.equal(url, 'https://mail.zoho.com/api/accounts', 'No message creation endpoint may be called');
      assert.equal(options.method || 'GET', 'GET');
      return Response.json({ data: [{ accountId: 'fixture-mailbox', primaryEmailAddress: mailbox }] });
    },
  });
  const invoke = (body, authenticated = true) => handler(new Request('https://fixture.supabase.co/functions/v1/zoho-send-mail', {
    method: 'POST', headers: { Origin: 'https://example.com', 'Content-Type': 'application/json',
      ...(authenticated ? { Authorization: 'Bearer fixture-session' } : {}) }, body: JSON.stringify(body),
  }));
  return { invoke, calls };
}

test('Identificar conta grava somente o vínculo do remetente e não envia e-mail', async () => {
  const { invoke, calls } = await server();
  const response = await invoke({ action: 'identify_account' });
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.equal(result.success, true); assert.equal(result.account_configured, true); assert.equal(result.sender, sender);
  assert.equal(calls.updates.length, 1); assert.equal(calls.updates[0].account_id, 'fixture-mailbox');
  assert.deepEqual(calls.network.map(x => x.method), ['POST', 'GET']);
});

test('A identificação ignora parâmetros de envio e permanece sem efeitos sobre mensagens', async () => {
  const { invoke, calls } = await server();
  const response = await invoke({ action: 'identify_account', mode: 'test_send', confirm: 'ENVIAR_TESTE_HSN' });
  assert.equal(response.status, 200); assert.equal((await response.json()).account_configured, true);
  assert.equal(calls.network.length, 2); assert.equal(calls.updates.length, 1);
});

test('Conta sem o remetente esperado não é vinculada', async () => {
  const { invoke, calls } = await server({ mailbox: 'outra@example.com' });
  const response = await invoke({ action: 'identify_account' });
  assert.equal(response.status, 404); assert.equal(calls.updates.length, 0);
});

test('Identificação exige sessão e proprietário válidos antes de consultar o Zoho', async () => {
  const unauthenticated = await server();
  assert.equal((await unauthenticated.invoke({ action: 'identify_account' }, false)).status, 401);
  assert.equal(unauthenticated.calls.network.length, 0);
  const other = await server({ user: '22222222-2222-4222-8222-222222222222' });
  assert.equal((await other.invoke({ action: 'identify_account' })).status, 403);
  assert.equal(other.calls.network.length, 0);
});

test('Setup legado continua identificando a conta sem enviar mensagens', async () => {
  const { invoke } = await server();
  const response = await invoke({ mode: 'setup' });
  assert.equal(response.status, 200); assert.equal((await response.json()).account_configured, true);
});

test('Ações desconhecidas continuam rejeitadas sem chamadas ao Zoho', async () => {
  const { invoke, calls } = await server();
  assert.equal((await invoke({ action: 'unknown' })).status, 400);
  assert.equal(calls.network.length, 0); assert.equal(calls.updates.length, 0);
});
