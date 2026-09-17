import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { demoData, demoMetrics } from "@/data/demoData";
import { useAuth } from "./authContext";
import { supabase } from "./supabaseClient";

// Supabase tables are deliberately queried through one tenant-keyed adapter;
// generated Database types can replace this dynamic row at project-link time.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Row = Record<string, any>;
const relationSelect: Record<string, string> = {
  operational_areas:
    "*,manager:employees!operational_areas_manager_id_company_id_fkey(full_name)",
  service_user_assignments: "*,employee:employees(full_name,job_title)",
  employees:
    "*,area:operational_areas!employees_area_id_company_id_fkey(name,code)",
  service_users: "*,area:operational_areas(name,code)",
  visits:
    "*,service_user:service_users(full_name,area_id),area:operational_areas(name,code),employee:employees(full_name),assignments:visit_assignments(id,assignment_slot,employee_id,employee:employees(full_name,job_title))",
  care_visit_requirements: "*,service_user:service_users(full_name)",
  visit_assignments: "*,employee:employees(full_name,job_title)",
  care_plans: "*,service_user:service_users(full_name)",
  risk_assessments: "*,service_user:service_users(full_name)",
  medications: "*,service_user:service_users(full_name)",
  mar_entries:
    "*,service_user:service_users(full_name),medication:medications(name)",
  medication_schedules:
    "*,medication:medications(name,strength,status,service_user_id,service_user:service_users(full_name))",
  incidents: "*,service_user:service_users(full_name)",
  safeguarding_records: "*,service_user:service_users(full_name)",
  timesheets:
    "*,employee:employees(full_name,area_id),area:operational_areas(name,code)",
  expenses: "*,employee:employees(full_name,area_id)",
  mileage_claims: "*,employee:employees(full_name,area_id)",
  invoices:
    "*,service_user:service_users(full_name,area_id,funding_type,payer_name),area:operational_areas(name,code)",
  invoice_items: "*",
  invoice_payments: "*",
  care_plan_reviews: "*",
  membership_area_access: "*",
  company_memberships:
    "*,profile:profiles!company_memberships_profile_fk(full_name,email),role:roles(label,key)",
  audit_events: "*",
  care_concerns: "*,service_user:service_users(full_name,area_id)",
  form_templates: "*",
  form_submissions:
    "*,service_user:service_users(full_name,area_id),template:form_templates(name,category,version)",
  employee_compliance: "*,employee:employees(full_name,job_title,area_id)",
  training_courses: "*",
  employee_training:
    "*,employee:employees(full_name,job_title),course:training_courses(name,category,mandatory)",
  service_types: "*",
  service_user_staff_preferences:
    "*,employee:employees(full_name),service_user:service_users(full_name)",
  complaints: "*,service_user:service_users(full_name)",
  data_rights_requests: "*,service_user:service_users(full_name)",
  data_breaches: "*",
};

export function useRows(
  table: string,
  order = "created_at",
  ascending = false,
) {
  const { activeCompany, demo } = useAuth();
  return useQuery({
    queryKey: ["company", activeCompany?.id, table],
    enabled: Boolean(activeCompany),
    queryFn: async () => {
      if (demo) return structuredClone(demoData[table] ?? []);
      let query = supabase
        .from(table)
        .select(relationSelect[table] ?? "*")
        .eq("company_id", activeCompany!.id);
      query = query.order(order, { ascending });
      const { data, error } = await query;
      if (error) throw error;
      return data as Row[];
    },
  });
}

export function useDashboardMetrics() {
  const { activeCompany, demo } = useAuth();
  return useQuery({
    queryKey: ["company", activeCompany?.id, "dashboard"],
    enabled: Boolean(activeCompany),
    queryFn: async () => {
      if (demo) return demoMetrics;
      const { data, error } = await supabase.rpc("get_dashboard_metrics", {
        target_company_id: activeCompany!.id,
      });
      if (error) throw error;
      return data;
    },
  });
}

export function useCreateRow(table: string) {
  const { activeCompany, demo } = useAuth();
  const client = useQueryClient();
  return useMutation({
    mutationFn: async (values: Row) => {
      const cleaned = Object.fromEntries(
        Object.entries(values).map(([key, value]) => [
          key,
          value === "" ? null : value,
        ]),
      );
      const row = { ...cleaned, company_id: activeCompany!.id };
      if (demo) {
        const created = {
          ...row,
          id: crypto.randomUUID(),
          created_at: new Date().toISOString(),
        };
        (demoData[table] ??= []).unshift(created);
        return created;
      }
      const { data, error } = await supabase
        .from(table)
        .insert(row)
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      void client.invalidateQueries({
        queryKey: ["company", activeCompany?.id, table],
      });
      void client.invalidateQueries({
        queryKey: ["company", activeCompany?.id, "dashboard"],
      });
    },
  });
}

export function useUpdateRow(table: string) {
  const { activeCompany, demo } = useAuth();
  const client = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...values }: Row) => {
      if (demo) {
        const i = (demoData[table] ?? []).findIndex((r) => r.id === id);
        if (i >= 0) demoData[table]![i] = { ...demoData[table]![i], ...values };
        return;
      }
      let query = supabase.from(table).update(values).eq("id", id);
      if (table !== "companies")
        query = query.eq("company_id", activeCompany!.id);
      const { error } = await query;
      if (error) throw error;
    },
    onSuccess: () => {
      void client.invalidateQueries({
        queryKey: ["company", activeCompany?.id, table],
      });
      void client.invalidateQueries({
        queryKey: ["company", activeCompany?.id, "dashboard"],
      });
    },
  });
}

export function useSetVisitAssignment() {
  const { activeCompany, demo } = useAuth();
  const client = useQueryClient();
  return useMutation({
    mutationFn: async ({
      visitId,
      slot,
      employeeId,
    }: {
      visitId: string;
      slot: number;
      employeeId: string | null;
    }) => {
      if (demo) {
        const rows = (demoData.visit_assignments ??= []);
        const index = rows.findIndex(
          (row) =>
            row.visit_id === visitId && Number(row.assignment_slot) === slot,
        );
        if (index >= 0) rows.splice(index, 1);
        if (employeeId)
          rows.push({
            id: crypto.randomUUID(),
            company_id: activeCompany!.id,
            visit_id: visitId,
            employee_id: employeeId,
            assignment_slot: slot,
          });
        return;
      }
      const { error } = await supabase.rpc("set_visit_assignment", {
        target_visit_id: visitId,
        target_slot: slot,
        target_employee_id: employeeId,
      });
      if (error) throw error;
    },
    onSuccess: () =>
      void client.invalidateQueries({
        queryKey: ["company", activeCompany?.id, "visits"],
      }),
  });
}

export function useGenerateServiceUserVisits() {
  const { activeCompany, demo } = useAuth();
  const client = useQueryClient();
  return useMutation({
    mutationFn: async ({
      serviceUserId,
      from,
      to,
    }: {
      serviceUserId: string;
      from: string;
      to: string;
    }) => {
      if (demo) return 0;
      const { data, error } = await supabase.rpc(
        "generate_service_user_visits",
        {
          target_service_user_id: serviceUserId,
          range_start: from,
          range_end: to,
        },
      );
      if (error) throw error;
      return Number(data ?? 0);
    },
    onSuccess: () => {
      void client.invalidateQueries({
        queryKey: ["company", activeCompany?.id, "visits"],
      });
      void client.invalidateQueries({
        queryKey: ["company", activeCompany?.id, "dashboard"],
      });
    },
  });
}

export function useCreateServiceUserVisitSchedule() {
  const { activeCompany, demo } = useAuth();
  const client = useQueryClient();
  return useMutation({
    mutationFn: async ({
      serviceUserId,
      weekdays,
      slots,
      from,
      to,
    }: {
      serviceUserId: string;
      weekdays: number[];
      slots: Row[];
      from: string;
      to: string;
    }) => {
      if (demo)
        return {
          requirements_created: weekdays.length * slots.length,
          visits_created: 0,
        };
      const { data, error } = await supabase.rpc(
        "create_service_user_visit_schedule",
        {
          target_service_user_id: serviceUserId,
          selected_weekdays: weekdays,
          visit_slots: slots,
          range_start: from,
          range_end: to,
        },
      );
      if (error) throw error;
      return data as { requirements_created: number; visits_created: number };
    },
    onSuccess: () => {
      void client.invalidateQueries({
        queryKey: ["company", activeCompany?.id, "care_visit_requirements"],
      });
      void client.invalidateQueries({
        queryKey: ["company", activeCompany?.id, "visits"],
      });
      void client.invalidateQueries({
        queryKey: ["company", activeCompany?.id, "dashboard"],
      });
    },
  });
}

export function useCreateInvitation() {
  const { activeCompany, demo } = useAuth();
  return useMutation({
    mutationFn: async ({ email, role }: { email: string; role: string }) => {
      if (demo) return "demo-invitation-code-not-deliverable".padEnd(64, "0");
      const { data, error } = await supabase.rpc("create_invitation", {
        target_company_id: activeCompany!.id,
        p_email: email,
        p_role_key: role,
      });
      if (error) throw error;
      const row = Array.isArray(data) ? data[0] : data;
      return (row as { raw_token: string } | null)?.raw_token ?? "";
    },
  });
}

export function useSaveOperationalArea() {
  const { activeCompany, demo } = useAuth();
  const client = useQueryClient();
  return useMutation({
    mutationFn: async (values: Row) => {
      const cleaned = Object.fromEntries(
        Object.entries(values).map(([key, value]) => [
          key,
          value === "" ? null : value,
        ]),
      );
      const baseCode =
        String(cleaned.code || cleaned.name || "AREA")
          .toUpperCase()
          .replace(/[^A-Z0-9]/g, "")
          .slice(0, 16) || "AREA";
      const uniqueCode = (rows: Row[]) => {
        const used = new Set(
          rows
            .filter((row) => row.id !== cleaned.id)
            .map((row) => String(row.code).toUpperCase()),
        );
        if (!used.has(baseCode)) return baseCode;
        let suffix = 2;
        while (
          used.has(`${baseCode.slice(0, 16 - String(suffix).length)}${suffix}`)
        )
          suffix += 1;
        return `${baseCode.slice(0, 16 - String(suffix).length)}${suffix}`;
      };
      if (demo) {
        const rows = (demoData.operational_areas ??= []);
        const existing = cleaned.id
          ? rows.find((row) => row.id === cleaned.id)
          : undefined;
        const saved = {
          ...existing,
          ...cleaned,
          id: existing?.id ?? crypto.randomUUID(),
          company_id: activeCompany!.id,
          code: uniqueCode(rows),
          updated_at: new Date().toISOString(),
        };
        if (existing) Object.assign(existing, saved);
        else rows.unshift(saved);
        demoData.operational_areas = rows;
        return saved;
      }
      const { data: existingRows, error: listError } = await supabase
        .from("operational_areas")
        .select("id,code")
        .eq("company_id", activeCompany!.id);
      if (listError) throw listError;
      const safeCode = uniqueCode((existingRows ?? []) as Row[]);
      const payload = {
        target_company_id: activeCompany!.id,
        target_area_id: cleaned.id ?? null,
        p_name: String(cleaned.name ?? ""),
        p_code: safeCode,
        p_office_name: cleaned.office_name ?? null,
        p_address: cleaned.address ?? null,
        p_contact_phone: cleaned.contact_phone ?? null,
        p_contact_email: cleaned.contact_email ?? null,
        p_manager_id: cleaned.manager_id ?? null,
        p_status: cleaned.status ?? "active",
      };
      const { data, error } = await supabase.rpc(
        "save_operational_area",
        payload,
      );
      if (!error) return data as Row;
      const isMissingFunction = ["PGRST202", "42883"].includes(
        error.code ?? "",
      );
      const isDuplicateCode =
        error.code === "23505" ||
        /operational_areas_company_id_code_key|area with code .* already exists|duplicate key/i.test(
          error.message,
        );
      if (!isMissingFunction && !isDuplicateCode) throw error;
      const row = {
        name: String(cleaned.name ?? "").trim(),
        code: safeCode,
        office_name: cleaned.office_name ?? null,
        address: cleaned.address ?? null,
        contact_phone: cleaned.contact_phone ?? null,
        contact_email: cleaned.contact_email ?? null,
        manager_id: cleaned.manager_id ?? null,
        status: cleaned.status ?? "active",
        company_id: activeCompany!.id,
      };
      if (cleaned.id) {
        const { data: fallback, error: fallbackError } = await supabase
          .from("operational_areas")
          .update(row)
          .eq("id", cleaned.id)
          .eq("company_id", activeCompany!.id)
          .select()
          .single();
        if (fallbackError) throw fallbackError;
        return fallback as Row;
      }
      // Older deployments may not have the save RPC yet, and another user can
      // claim a code between the list and insert calls. Retry with a compact
      // random suffix so area creation can never be blocked by that race.
      let candidate = row.code;
      for (let attempt = 0; attempt < 5; attempt += 1) {
        const { data: fallback, error: fallbackError } = await supabase
          .from("operational_areas")
          .insert({ ...row, code: candidate })
          .select()
          .single();
        if (!fallbackError) return fallback as Row;
        const duplicate =
          fallbackError.code === "23505" ||
          /operational_areas_company_id_code_key|duplicate key/i.test(
            fallbackError.message,
          );
        if (!duplicate) throw fallbackError;
        const suffix = crypto.randomUUID().slice(0, 4).toUpperCase();
        candidate = `${baseCode.slice(0, 11)}-${suffix}`;
      }
      throw new Error(
        "CareFlow could not allocate a unique area code after five attempts.",
      );
    },
    onSuccess: async () => {
      await client.invalidateQueries({
        queryKey: ["company", activeCompany?.id, "operational_areas"],
      });
      await Promise.all(
        ["employees", "service_users", "visits"].map((table) =>
          client.invalidateQueries({
            queryKey: ["company", activeCompany?.id, table],
          }),
        ),
      );
    },
  });
}
