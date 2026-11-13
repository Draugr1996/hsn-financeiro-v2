
import { createClient } from "npm:@supabase/supabase-js@2.119.0";

const encoder = new TextEncoder();

function base64(bytes: Uint8Array): string {
  let result = "";
  for (const byte of bytes) {
    result += String.fromCharCode(byte);
  }
  return btoa(result);
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    encoder.encode(value),
  );
  return base64(new Uint8Array(digest));
}

serveIsolated(async (request) => {
  const headers = {
    "Access-Control-Allow-Origin":
      new URL(Deno.env.get("HSN_APP_URL")||"http://localhost:8080/").origin,
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json",
  };

  if (request.method === "OPTIONS") {
    return new Response(null, { headers });
  }

  const respond = (body: object, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers,
    });

  if (request.method !== "POST") {
    return respond({ error: "Method not allowed" }, 405);
  }

  try {
    const authorization = request.headers.get("Authorization");

    if (!authorization?.startsWith("Bearer ")) {
      return respond({ error: "Login required" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey =
      hsnApiKey("SUPABASE_ANON_KEY") ??
      Deno.env.get("SB_PUBLISHABLE_KEY");
    const serviceKey = hsnApiKey("SUPABASE_SERVICE_ROLE_KEY")!;
    const zohoClientId = Deno.env.get("ZOHO_CLIENT_ID")!;

    if (!anonKey || !serviceKey || !zohoClientId) {
      throw new Error("Missing server configuration");
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const jwt = authorization.slice(7);

    const { data: userData, error: userError } =
      await authClient.auth.getUser(jwt);

    if (userError || !userData.user) {
      return respond({ error: "Invalid session" }, 401);
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const random = crypto.getRandomValues(new Uint8Array(32));
    const state = base64(random)
      .replaceAll("+", "-")
      .replaceAll("/", "_")
      .replaceAll("=", "");

    const stateHash = await sha256(state);

    const expiresAt = new Date(
      Date.now() + 10 * 60 * 1000,
    ).toISOString();

    const { error: insertError } = await admin
      .from("zoho_oauth_states")
      .insert({
        state_hash: stateHash,
        user_id: userData.user.id,
        expires_at: expiresAt,
      });

    if (insertError) throw insertError;

    const redirectUri =
      `${supabaseUrl}/functions/v1/zoho-oauth-callback`;

    const params = new URLSearchParams({
      client_id: zohoClientId,
      response_type: "code",
      redirect_uri: redirectUri,
      scope: "ZohoMail.accounts.READ,ZohoMail.messages.CREATE",
      access_type: "offline",
      prompt: "consent",
      state,
    });

    return respond({
      url: `https://accounts.zoho.com/oauth/v2/auth?${params}`,
    });
  } catch (error) {
    console.error("Zoho OAuth start error:", error);
    return respond({ error: "Unable to start Zoho authorization" }, 500);
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
  }
  return handler(request);
 });
}

function hsnApiKey(name:string):string|undefined{
 const mapping=name==='SUPABASE_SERVICE_ROLE_KEY'?'SUPABASE_SECRET_KEYS':'SUPABASE_PUBLISHABLE_KEYS';
 try{const keys=JSON.parse(Deno.env.get(mapping)||'{}');if(typeof keys.default==='string'&&keys.default)return keys.default;}catch{}
 return Deno.env.get(name);
}
