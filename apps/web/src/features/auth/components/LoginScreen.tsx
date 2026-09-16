import { useState } from "react";
import { Activity, ArrowRight, CheckCircle2 } from 'lucide-react';
import { isSupabaseConfigured, supabase } from '@/lib/supabaseClient';
import { useAuth } from '@/lib/authContext';

/** Invitation-only Supabase sign-in with an offline demo workspace. */
export function LoginScreen() {
  const { enterDemo } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error,setError]=useState(''); const [busy,setBusy]=useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);setError('');
    const {error}=await supabase.auth.signInWithPassword({email,password});
    if(error)setError(error.message);setBusy(false);
  }

  return (
    <div className="login-page"><aside><div className="login-brand"><span><Activity/></span><strong>CareFlow</strong></div><div className="login-copy"><p>CONNECTED CARE MANAGEMENT</p><h1>More time for care.<br/>Less time on admin.</h1><span>One secure place for care plans, visits, medication, compliance and your whole team.</span><ul><li><CheckCircle2/>Built for UK domiciliary care</li><li><CheckCircle2/>Secure, role-based access</li><li><CheckCircle2/>Complete evidence and audit trail</li></ul></div><small>CareFlow • Secure care operations</small></aside>
      <main><div className="login-card"><div className="mobile-login-brand"><Activity/><strong>CareFlow</strong></div><h2>Welcome back</h2>
        <p className="mt-1 text-sm text-muted">
          Sign in to manage your care service.
        </p>

        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <div>
            <label htmlFor="email" className="block text-sm font-medium text-ink">
              Email
            </label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="mt-1 block w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-ink focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-ink">
              Password
            </label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 block w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-ink focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
            />
          </div>

          <button
            type="submit"
            disabled={busy}
            className="login-submit"
          >
            {busy?'Signing in…':<>Sign in <ArrowRight/></>}
          </button>
        </form>
        {error&&<p className="form-error">{error}</p>}
        <button className="forgot" onClick={()=>email&&supabase.auth.resetPasswordForEmail(email)}>Forgot your password?</button>
        <div className="login-divider"><span>or preview the system</span></div><button className="demo-button" onClick={enterDemo}>Open interactive demo</button>
        {!isSupabaseConfigured&&<p className="setup-note">Supabase keys are not configured, so demo mode is available immediately.</p>}
        <footer>Access is invitation-only. Contact your administrator if you need an account.</footer>
      </div></main>
    </div>
  );
}
