import { createClient } from "@supabase/supabase-js";

/**
 * Client-side Supabase client. Uses ONLY the anon key — never the
 * service-role key, which must never reach the browser (see
 * docs/architecture.md §12 and docs/threat-model.md).
 *
 * All tenant access enforcement happens server-side via Postgres RLS
 * and SECURITY DEFINER functions, not here. This client is a
 * transport, not a security boundary.
 */
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

if (!supabaseUrl || !supabaseAnonKey) {
  console.warn(
    "VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY are not set. " +
      "Copy .env.example to .env.local and fill in your local Supabase project values."
  );
}

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

// A syntactically valid local placeholder keeps the demo build usable before
// deployment variables are supplied. No request is made in demo mode.
export const supabase = createClient(
  supabaseUrl ?? "http://127.0.0.1:54321",
  supabaseAnonKey ?? "careflow-demo-anon-key"
);
