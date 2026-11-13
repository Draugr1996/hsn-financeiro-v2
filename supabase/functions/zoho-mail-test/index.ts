
import { createClient } from "npm:@supabase/supabase-js@2.119.0";

const EMAIL_TESTE = "faturamento@hotelserranegra.com.br";

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, char => char.charCodeAt(0));
}

async function decryptToken(encrypted: string, keyBase64: string) {
  const [iv, data] = encrypted.split(".");
  if (!iv || !data) throw new Error("Invalid token");

  const key = await crypto.subtle.importKey(
    "raw",
    fromBase64(keyBase64),
    { name: "AES-GCM" },
    false,
    ["decrypt"]
  );

  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: fromBase64(iv) },
    key,
    fromBase64(data)
  );

  return new TextDecoder().decode(decrypted);
}

serveIsolated(async (request) => {
  const headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": new URL(Deno.env.get("HSN_APP_URL")||"http://localhost:8080/").origin,
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS"
  };

  const respond = (body: object, status = 200) =>
    new Response(JSON.stringify(body), { status, headers });

  if (request.method === "OPTIONS") {
    return new Response(null, { headers });
  }

  if (request.method !== "POST") {
    return respond({ error: "Method not allowed" }, 405);
  }

  try {
    const authHeader = request.headers.get("Authorization");

    if (!authHeader?.startsWith("Bearer ")) {
      return respond({ error: "Login required" }, 401);
    }

    const body = await request.json().catch(() => ({}));

    if (body.confirm !== "ENVIAR_TESTE") {
      return respond({
        error: "Explicit confirmation required"
      }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey =
      hsnApiKey("SUPABASE_ANON_KEY") ??
      Deno.env.get("SB_PUBLISHABLE_KEY");
    const serviceKey = hsnApiKey("SUPABASE_SERVICE_ROLE_KEY");
    const clientId = Deno.env.get("ZOHO_CLIENT_ID");
    const clientSecret = Deno.env.get("ZOHO_CLIENT_SECRET");
    const encryptionKey = Deno.env.get("ZOHO_TOKEN_ENCRYPTION_KEY");

    if (
      !supabaseUrl || !anonKey || !serviceKey ||
      !clientId || !clientSecret || !encryptionKey
    ) {
      throw new Error("Missing configuration");
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false
      }
    });

    const jwt = authHeader.slice(7);
    const { data: userData, error: userError } =
      await authClient.auth.getUser(jwt);

    if (userError || !userData.user) {
      return respond({ error: "Invalid session" }, 401);
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false
      }
    });

    const { data: stored, error: readError } = await admin
      .from("zoho_mail_tokens")
      .select("refresh_token, account_id")
      .eq("user_id", userData.user.id)
      .maybeSingle();

    if (readError || !stored?.account_id) {
      return respond({ error: "Zoho not connected" }, 404);
    }

    const refreshToken = await decryptToken(
      stored.refresh_token,
      encryptionKey
    );

    const tokenResponse = await fetch(
      "https://accounts.zoho.com/oauth/v2/token",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: new URLSearchParams({
          grant_type: "refresh_token",
          client_id: clientId,
          client_secret: clientSecret,
          refresh_token: refreshToken
        })
      }
    );

    const tokenData = await tokenResponse.json();

    if (!tokenResponse.ok || !tokenData.access_token) {
      return respond({
        error: "Zoho token refresh failed"
      }, 502);
    }

    const subject =
      "Hotel Serra Negra | TESTE DE ENVIO - NAO E COBRANCA";

    const content = [
      "TESTE DE ENVIO - NAO E COBRANCA",
      "",
      "Esta mensagem foi enviada para validar",
      "a integracao entre Financeiro HSN e Zoho Mail.",
      "",
      "Nenhum boleto ou cliente esta envolvido.",
      "",
      "Hotel Serra Negra"
    ].join("\n");

    const sendResponse = await fetch(
      `https://mail.zoho.com/api/accounts/${
        encodeURIComponent(String(stored.account_id))
      }/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Zoho-oauthtoken ${tokenData.access_token}`,
          "Content-Type": "application/json",
          Accept: "application/json"
        },
        body: JSON.stringify({
          fromAddress: EMAIL_TESTE,
          toAddress: EMAIL_TESTE,
          subject,
          content,
          mailFormat: "plaintext"
        })
      }
    );

    const sendData = await sendResponse.json().catch(() => null);

    if (!sendResponse.ok ||
        (sendData?.status?.code &&
         Number(sendData.status.code) !== 200)) {
      console.error("Zoho send failed:", {
        httpStatus: sendResponse.status,
        zohoCode: sendData?.status?.code
      });

      return respond({
        success: false,
        error: "Zoho mail send failed",
        zoho_status: sendResponse.status
      }, 502);
    }

    return respond({
      success: true,
      message: "Test email accepted by Zoho",
      recipient: EMAIL_TESTE
    });
  } catch (error) {
    console.error("Zoho mail test error:", error);
    return respond({
      error: "Mail test failed"
    }, 500);
  }
});


// Clone: valida sessão e proprietário no servidor antes de executar integrações.
function serveIsolated(handler: (request: Request) => Response | Promise<Response>){
 Deno.serve(async request=>{
  const origin=new URL(Deno.env.get('HSN_APP_URL')||'http://localhost:8080/').origin;
  const reply=(message:string,status:number)=>new Response(JSON.stringify({error:message}),{status,headers:{'Content-Type':'application/json','Access-Control-Allow-Origin':origin,'Vary':'Origin'}});
  if(request.method!=='OPTIONS'){
   const authorization=request.headers.get('Authorization')||'';
   if(!authorization.startsWith('Bearer '))return reply('Entre no aplicativo para continuar.',401);
   const admin=createClient(Deno.env.get('SUPABASE_URL')||'',hsnApiKey('SUPABASE_SERVICE_ROLE_KEY')||'',{auth:{persistSession:false,autoRefreshToken:false}});
   const {data,error}=await admin.auth.getUser(authorization.slice(7));
   if(error||!data.user)return reply('Sessão inválida.',401);
   const owner=await admin.rpc('hsn_push_owner');
   if(owner.error||!owner.data||owner.data!==data.user.id)return reply('Acesso restrito ao proprietário configurado.',403);
   if(Deno.env.get('HSN_ENABLE_EMAIL')!=='true')return reply('Integração desativada neste clone. Conclua a configuração e a homologação.',503);
  }
  return handler(request);
 });
}

function hsnApiKey(name:string):string|undefined{
 const mapping=name==='SUPABASE_SERVICE_ROLE_KEY'?'SUPABASE_SECRET_KEYS':'SUPABASE_PUBLISHABLE_KEYS';
 try{const keys=JSON.parse(Deno.env.get(mapping)||'{}');if(typeof keys.default==='string'&&keys.default)return keys.default;}catch{}
 return Deno.env.get(name);
}
