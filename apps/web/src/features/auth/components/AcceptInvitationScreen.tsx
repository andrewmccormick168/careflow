import { useState } from "react";
import { supabase } from '@/lib/supabaseClient';

/** Accepts a one-time invitation code through a POST body. */
export function AcceptInvitationScreen() {
  const [token, setToken] = useState("");
  const [message,setMessage]=useState(''); const [busy,setBusy]=useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);setMessage('');
    const {error}=await supabase.functions.invoke('accept-invitation',{body:{token:token.trim()}});
    setMessage(error?error.message:'Invitation accepted. Your workspace is ready.');setBusy(false);
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-6">
      <div className="w-full max-w-sm rounded-card border border-border bg-surface p-8 shadow-sm">
        <h1 className="text-xl font-semibold text-ink">Activate your account</h1>
        <p className="mt-1 text-sm text-muted">
          Enter the one-time code supplied by your administrator.
        </p>

        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <div>
            <label htmlFor="invitation-code" className="block text-sm font-medium text-ink">
              Invitation code
            </label>
            <input
              id="invitation-code"
              autoComplete="off"
              value={token}
              onChange={(e) => setToken(e.target.value)}
              className="mt-1 block w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-ink focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
            />
          </div>

          <button
            type="submit"
            disabled={token.trim().length!==64||busy}
            className="w-full rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-hover focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {busy?'Joining…':'Join organisation'}
          </button>
          {message&&<p className="text-sm text-muted">{message}</p>}
        </form>
      </div>
    </div>
  );
}
