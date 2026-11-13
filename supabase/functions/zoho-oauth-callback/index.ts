import { createClient } from "npm:@supabase/supabase-js@2.119.0";

const encoder = new TextEncoder();

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    encoder.encode(value),
  );
  return toBase64(new Uint8Array(digest));
}

async function encryptToken(
  token: string,
  keyBase64: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    fromBase64(keyBase64),
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );

  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    encoder.encode(token),
  );

  return `${toBase64(iv)}.${toBase64(new Uint8Array(encrypted))}`;
}

Deno.serve(async (request) => {
  const appUrl = Deno.env.get("HSN_APP_URL") || "http://localhost:8080/";

  const redirect = (status: string) =>
    Response.redirect(
      `${appUrl}?zoho=${encodeURIComponent(status)}`,
      302,
    );

  try {
    const url = new URL(request.url);
    const code = url.searchParams.get("code");
    const state = url.searchParams.get("state");
    const error = url.searchParams.get("error");

    if (error) return redirect("authorization_denied");
    if (!code || !state) return redirect("invalid_callback");

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = hsnApiKey("SUPABASE_SERVICE_ROLE_KEY")!;
    const clientId = Deno.env.get("ZOHO_CLIENT_ID")!;
    const clientSecret = Deno.env.get("ZOHO_CLIENT_SECRET")!;
    const encryptionKey = Deno.env.get("ZOHO_TOKEN_ENCRYPTION_KEY")!;

    if (
      !supabaseUrl ||
      !serviceRoleKey ||
      !clientId ||
      !clientSecret ||
      !encryptionKey
    ) {
      throw new Error("Missing server configuration");
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const stateHash = await sha256(state);

    const { data: pendingState, error: stateError } = await supabase
      .from("zoho_oauth_states")
      .select("user_id, expires_at, used_at")
      .eq("state_hash", stateHash)
      .maybeSingle();

    if (
      stateError ||
      !pendingState ||
      pendingState.used_at ||
      new Date(pendingState.expires_at).getTime() <= Date.now()
    ) {
      return redirect("invalid_state");
    }

    // Marca o estado como utilizado antes da troca do código.
    const { data: consumed, error: consumeError } = await supabase
      .from("zoho_oauth_states")
      .update({ used_at: new Date().toISOString() })
      .eq("state_hash", stateHash)
      .is("used_at", null)
      .gt("expires_at", new Date().toISOString())
      .select("user_id")
      .maybeSingle();

    if (consumeError || !consumed) {
      return redirect("state_already_used");
    }

    const tokenResponse = await fetch(
      "https://accounts.zoho.com/oauth/v2/token",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          grant_type: "authorization_code",
          client_id: clientId,
          client_secret: clientSecret,
          redirect_uri: `${supabaseUrl}/functions/v1/zoho-oauth-callback`,
          code,
        }),
      },
    );

    const tokens = await tokenResponse.json();

    if (!tokenResponse.ok || !tokens.refresh_token) {
      console.error("Zoho OAuth token exchange failed", {
        status: tokenResponse.status,
        error: tokens.error ?? "missing_refresh_token",
      });
      return redirect("token_error");
    }

    const encryptedRefreshToken = await encryptToken(
      tokens.refresh_token,
      encryptionKey,
    );

    const { error: saveError } = await supabase
      .from("zoho_mail_tokens")
      .upsert(
        {
          user_id: consumed.user_id,
          refresh_token: encryptedRefreshToken,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id" },
      );

    if (saveError) throw saveError;

    return redirect("connected");
  } catch (error) {
    console.error("Zoho callback error:", error);
    return redirect("connection_error");
  }
});
function hsnApiKey(name:string):string|undefined{
 const mapping=name==='SUPABASE_SERVICE_ROLE_KEY'?'SUPABASE_SECRET_KEYS':'SUPABASE_PUBLISHABLE_KEYS';
 try{const keys=JSON.parse(Deno.env.get(mapping)||'{}');if(typeof keys.default==='string'&&keys.default)return keys.default;}catch{}
 return Deno.env.get(name);
}
