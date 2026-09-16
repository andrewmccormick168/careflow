import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import type { Session } from '@supabase/supabase-js';
import type { Company, Membership } from '@careflow/shared-types';
import { isSupabaseConfigured, supabase } from './supabaseClient';
import { queryClient } from './queryClient';

type AuthValue = {
  loading: boolean; session: Session | null; demo: boolean; memberships: Membership[];
  activeCompany: Company | null; capabilities: Set<string>; displayName: string;
  enterDemo: () => void; signOut: () => Promise<void>; switchCompany: (id: string) => void;
  refreshMemberships: () => Promise<void>;
};

const demoCompany: Company = {
  id: '11111111-1111-4111-8111-111111111111', name: 'Rosewood Care Services',
  trading_name: 'Rosewood Care', contact_email: 'office@example.test', contact_phone: '0141 555 0148',
  address: '24 Rowan Street, Glasgow', logo_url: null, timezone: 'Europe/London', status: 'active',
  late_visit_threshold_minutes: 15, early_visit_threshold_minutes: 15
};

const allCapabilities = new Set([
  'employees.view','employees.manage','service_users.view','service_users.manage','assignments.manage',
  'care_plans.view','care_plans.manage','risks.view','risks.manage','visits.view','visits.schedule','visits.complete',
  'medication.view','medication.administer','medication.manage','incidents.view','incidents.create','incidents.manage',
  'safeguarding.view','safeguarding.create','safeguarding.manage','rota.view','rota.manage','timesheets.view',
  'timesheets.approve','payroll.view','payroll.manage','invoices.view','invoices.manage','documents.view',
  'documents.manage','reports.view','exports.create','audit.view','settings.manage'
]);

const AuthContext = createContext<AuthValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [loading, setLoading] = useState(isSupabaseConfigured);
  const [session, setSession] = useState<Session | null>(null);
  const [demo, setDemo] = useState(!isSupabaseConfigured);
  const [memberships, setMemberships] = useState<Membership[]>([]);
  const [activeCompanyId, setActiveCompanyId] = useState<string | null>(null);
  const [capabilities, setCapabilities] = useState<Set<string>>(new Set());

  async function loadMemberships(userId = session?.user.id) {
    if (!userId || demo) return;
    const { data, error } = await supabase.from('company_memberships').select(`id,company_id,user_id,status,role:roles(key,label),company:companies(*)`).eq('user_id', userId).eq('status','active');
    if (error) throw error;
    const next = (data ?? []) as unknown as Membership[];
    setMemberships(next);
    const requested = localStorage.getItem('careflow.activeCompany');
    setActiveCompanyId(next.some((m) => m.company_id === requested) ? requested : next[0]?.company_id ?? null);
  }

  async function loadCapabilities(companyId: string) {
    const membership = memberships.find((m) => m.company_id === companyId);
    if (!membership?.role) return setCapabilities(new Set());
    const { data } = await supabase.from('role_capabilities').select('capability:capabilities(key)').eq('role_id', await roleId(membership.role.key));
    const rows=(data ?? []) as unknown as {capability:{key:string}|null}[];
    setCapabilities(new Set(rows.map((row) => row.capability?.key).filter((key):key is string=>Boolean(key))));
  }

  async function roleId(key: string) {
    const { data } = await supabase.from('roles').select('id').eq('key', key).single();
    return data?.id ?? '';
  }

  useEffect(() => {
    if (!isSupabaseConfigured) return;
    supabase.auth.getSession().then(({ data }) => { setSession(data.session); setLoading(false); if (data.session) void loadMemberships(data.session.user.id); });
    const { data } = supabase.auth.onAuthStateChange((_event, next) => { setSession(next); setLoading(false); if (next) void loadMemberships(next.user.id); else setMemberships([]); });
    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => { if (activeCompanyId && !demo) void loadCapabilities(activeCompanyId); }, [activeCompanyId, memberships.length, demo]);

  const activeCompany = demo ? demoCompany : memberships.find((m) => m.company_id === activeCompanyId)?.company ?? null;
  const value = useMemo<AuthValue>(() => ({
    loading, session, demo, memberships, activeCompany, capabilities: demo ? allCapabilities : capabilities,
    displayName: demo ? 'Alex Morgan' : (session?.user.user_metadata.full_name as string | undefined) ?? session?.user.email?.split('@')[0] ?? 'CareFlow user',
    enterDemo: () => { setDemo(true); setLoading(false); },
    signOut: async () => { if (!demo) await supabase.auth.signOut(); setDemo(false); setSession(null); queryClient.clear(); },
    switchCompany: (id) => { queryClient.clear(); setActiveCompanyId(id); localStorage.setItem('careflow.activeCompany', id); },
    refreshMemberships: () => loadMemberships()
  }), [loading, session, demo, memberships, activeCompanyId, capabilities]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() { const value = useContext(AuthContext); if (!value) throw new Error('useAuth must be inside AuthProvider'); return value; }
