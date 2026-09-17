import { useEffect, useState } from "react";
import {
  Activity,
  Bell,
  BriefcaseBusiness,
  CalendarDays,
  ChevronDown,
  ClipboardList,
  FileBarChart,
  HeartPulse,
  House,
  LogOut,
  Menu,
  Pill,
  ReceiptPoundSterling,
  Settings,
  ShieldAlert,
  Users,
  X,
} from "lucide-react";
import { useAuth } from "@/lib/authContext";
import { Modal, Empty } from "@/components/ui";
import { useRows, useUpdateRow } from "@/lib/data";

export type PageKey =
  | "dashboard"
  | "people"
  | "care"
  | "records"
  | "rota"
  | "medication"
  | "incidents"
  | "workforce"
  | "compliance"
  | "finance"
  | "reports"
  | "settings";
const items: [PageKey, string, React.ReactNode, string?][] = [
  ["dashboard", "Overview", <House />],
  ["people", "People", <Users />, "visits.view"],
  ["care", "Care plans & risks", <HeartPulse />, "care_plans.view"],
  ["records", "Forms & concerns", <ClipboardList />, "care_plans.view"],
  ["rota", "Rota & visits", <CalendarDays />, "visits.view"],
  ["medication", "Medication", <Pill />, "medication.view"],
  ["incidents", "Incidents & safeguarding", <ShieldAlert />, "incidents.view"],
  ["workforce", "Workforce", <BriefcaseBusiness />, "timesheets.view"],
  ["compliance", "Compliance & services", <ClipboardList />, "employees.view"],
  ["finance", "Finance", <ReceiptPoundSterling />, "invoices.view"],
  ["reports", "Reports & audit", <FileBarChart />, "reports.view"],
  ["settings", "Settings", <Settings />, "settings.manage"],
];

export function AppShell({
  page,
  onPage,
  children,
}: {
  page: PageKey;
  onPage: (p: PageKey) => void;
  children: React.ReactNode;
}) {
  const {
    activeCompany,
    memberships,
    switchCompany,
    displayName,
    signOut,
    capabilities,
    demo,
  } = useAuth();
  const [open, setOpen] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const notifications = useRows("notifications", "created_at", false);
  const markRead = useUpdateRow("notifications");
  const unread = notifications.data?.filter((n) => !n.read_at).length ?? 0;
  useEffect(() => setOpen(false), [page]);
  return (
    <div className="app-shell">
      <aside className={open ? "sidebar open" : "sidebar"}>
        <div className="brand">
          <span>
            <Activity />
          </span>
          <div>
            <strong>CareFlow</strong>
            <small>Care management</small>
          </div>
          <button onClick={() => setOpen(false)} className="mobile-close">
            <X />
          </button>
        </div>
        <nav>
          <p>Workspace</p>
          {items
            .filter(([, , , cap]) => !cap || capabilities.has(cap))
            .map(([key, label, icon]) => (
              <button
                key={key}
                className={page === key ? "active" : ""}
                onClick={() => onPage(key)}
              >
                {icon}
                <span>{label}</span>
              </button>
            ))}
        </nav>
        <div className="sidebar-help">
          <ClipboardList />
          <strong>Need support?</strong>
          <p>
            Deployment and administrator guides are included in the repository.
          </p>
        </div>
      </aside>
      {open && (
        <button
          aria-label="Close menu"
          className="sidebar-scrim"
          onClick={() => setOpen(false)}
        />
      )}
      <div className="workspace">
        <header className="topbar">
          <button className="menu-btn" onClick={() => setOpen(true)}>
            <Menu />
          </button>
          <div className="company-select">
            <span className="company-mark">
              {activeCompany?.name.charAt(0)}
            </span>
            <label>
              <small>Organisation</small>
              {memberships.length > 1 && !demo ? (
                <select
                  value={activeCompany?.id}
                  onChange={(e) => switchCompany(e.target.value)}
                >
                  {memberships.map((m) => (
                    <option key={m.id} value={m.company_id}>
                      {m.company.name}
                    </option>
                  ))}
                </select>
              ) : (
                <strong>
                  {activeCompany?.trading_name || activeCompany?.name}
                </strong>
              )}
            </label>
            <ChevronDown size={15} />
          </div>
          <div className="top-actions">
            <button
              className="notification"
              title={`${unread} unread notifications`}
              onClick={() => setShowNotifications(true)}
            >
              <Bell />
              {unread > 0 && <span />}
            </button>
            <span className="avatar">
              {displayName
                .split(" ")
                .map((n) => n[0])
                .slice(0, 2)
                .join("")
                .toUpperCase()}
            </span>
            <div className="user">
              <strong>{displayName}</strong>
              <small>{demo ? "Administrator • Demo" : "CareFlow user"}</small>
            </div>
            <button
              className="logout"
              title="Sign out"
              onClick={() => void signOut()}
            >
              <LogOut />
            </button>
          </div>
        </header>
        {demo && (
          <div className="demo-banner">
            Demo workspace — changes remain in this browser session. Connect
            Supabase to use live data.
          </div>
        )}
        <main>{children}</main>
      </div>
      {showNotifications && (
        <Modal
          title="Notifications"
          onClose={() => setShowNotifications(false)}
        >
          <div className="record-detail">
            {notifications.data?.length ? (
              <div className="compact-list notification-list">
                {notifications.data.map((n) => (
                  <article key={n.id}>
                    <span
                      className={`attention-icon ${n.severity === "critical" ? "red" : n.severity === "warning" ? "amber" : "blue"}`}
                    >
                      <Bell />
                    </span>
                    <div>
                      <strong>{n.title}</strong>
                      <small>{n.body}</small>
                      <small>
                        {new Date(n.created_at).toLocaleString("en-GB")}
                      </small>
                    </div>
                    {!n.read_at && (
                      <button
                        className="btn small"
                        onClick={() =>
                          void markRead.mutate({
                            id: n.id,
                            read_at: new Date().toISOString(),
                          })
                        }
                      >
                        Mark read
                      </button>
                    )}
                  </article>
                ))}
              </div>
            ) : (
              <Empty text="No notifications" />
            )}
          </div>
        </Modal>
      )}
    </div>
  );
}
