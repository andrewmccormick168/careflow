import { LoginScreen } from "@/features/auth/components/LoginScreen";
import { useEffect, useState } from "react";
import { useAuth } from "@/lib/authContext";
import { AppShell, type PageKey } from "@/components/AppShell";
import { DashboardPage } from "@/pages/DashboardPage";
import { PeoplePage } from "@/pages/PeoplePage";
import { AdvancedCarePage } from "@/pages/AdvancedCarePage";
import { ScalableRotaPage } from "@/pages/ScalableRotaPage";
import { MedicationPage } from "@/pages/MedicationPage";
import { IncidentsPage } from "@/pages/IncidentsPage";
import { ReportsPage, SettingsPage } from "@/pages/OperationsPages";
import {
  ImprovedFinancePage,
  ImprovedWorkforcePage,
} from "@/pages/BusinessOperationsPages";
import { AcceptInvitationScreen } from "@/features/auth/components/AcceptInvitationScreen";
import { ComplianceRecordsPage } from "@/pages/ComplianceRecordsPage";

/** Authenticated, capability-driven application shell. Hash navigation keeps
 * static hosting simple while company changes clear all tenant-cached data. */
export function App() {
  const { loading, session, demo, activeCompany } = useAuth();
  const fromHash = () => {
    const value = location.hash.replace("#/", "") as PageKey;
    return [
      "dashboard",
      "people",
      "care",
      "records",
      "rota",
      "medication",
      "incidents",
      "workforce",
      "finance",
      "reports",
      "settings",
    ].includes(value)
      ? value
      : "dashboard";
  };
  const [page, setPage] = useState<PageKey>(fromHash);
  useEffect(() => {
    const handler = () => setPage(fromHash());
    addEventListener("hashchange", handler);
    return () => removeEventListener("hashchange", handler);
  }, []);
  const navigate = (next: PageKey) => {
    location.hash = `/${next}`;
    setPage(next);
  };
  if (loading)
    return (
      <div className="splash">
        <span>CF</span>
        <strong>CareFlow</strong>
        <p>Preparing your workspace…</p>
      </div>
    );
  if (!session && !demo) return <LoginScreen />;
  if (location.hash === "#/accept-invitation" && session)
    return <AcceptInvitationScreen />;
  if (!activeCompany)
    return (
      <div className="splash">
        <strong>No active organisation</strong>
        <p>Ask an administrator to invite you to a CareFlow organisation.</p>
      </div>
    );
  const pages: Record<PageKey, React.ReactNode> = {
    dashboard: <DashboardPage />,
    people: <PeoplePage />,
    care: <AdvancedCarePage />,
    records: <ComplianceRecordsPage />,
    rota: <ScalableRotaPage />,
    medication: <MedicationPage />,
    incidents: <IncidentsPage />,
    workforce: <ImprovedWorkforcePage />,
    finance: <ImprovedFinancePage />,
    reports: <ReportsPage />,
    settings: <SettingsPage />,
  };
  return (
    <AppShell page={page} onPage={navigate}>
      {pages[page]}
    </AppShell>
  );
}
