export type UUID = string;
export type ISODate = string;
export type ISODateTime = string;
export type CompanyStatus = 'active' | 'suspended';
export type MembershipStatus = 'active' | 'deactivated';
export type RecordStatus = 'draft' | 'active' | 'approved' | 'archived';
export type RoleKey = 'company_admin' | 'manager' | 'coordinator' | 'carer' | 'finance';

export interface Company {
  id: UUID; name: string; trading_name: string | null; contact_email: string | null;
  contact_phone: string | null; address: string | null; logo_url: string | null;
  timezone: string; status: CompanyStatus; late_visit_threshold_minutes: number;
  early_visit_threshold_minutes: number;
}
export interface Membership {
  id: UUID; company_id: UUID; user_id: UUID; status: MembershipStatus;
  role: { key: RoleKey; label: string } | null; company: Company;
}
export interface Profile { id: UUID; full_name: string | null; email: string | null; avatar_url: string | null; }
export interface Employee {
  id: UUID; company_id: UUID; user_id: UUID | null; full_name: string;
  job_title: string | null; contact_email: string | null; contact_phone: string | null;
  status: 'active' | 'leaver'; area_id: UUID | null;
}
export interface ServiceUser {
  id: UUID; company_id: UUID; full_name: string; preferred_name: string | null;
  address: string | null; contact_phone: string | null; important_alerts: string | null;
  status: 'active' | 'ended' | 'archived'; area_id: UUID | null;
  funding_type: 'private' | 'local_authority' | 'nhs' | 'mixed' | 'other';
  payer_name: string | null; payer_reference: string | null; payment_terms_days: number;
}
export interface OperationalArea {
  id: UUID; company_id: UUID; name: string; code: string; office_name: string | null;
  address: string | null; contact_phone: string | null; contact_email: string | null;
  manager_id: UUID | null; status: 'active' | 'inactive';
}
export interface Visit {
  id: UUID; company_id: UUID; service_user_id: UUID; employee_id: UUID | null;
  starts_at: ISODateTime; ends_at: ISODateTime;
  status: 'scheduled' | 'in_progress' | 'completed' | 'missed' | 'cancelled';
  visit_type: string; notes: string | null; required_carers: 1 | 2;
  care_visit_requirement_id: UUID | null;
  area_id: UUID | null;
}
export interface CareVisitRequirement {
  id: UUID; company_id: UUID; service_user_id: UUID; visit_type: string;
  weekday: 0 | 1 | 2 | 3 | 4 | 5 | 6; starts_at: string; duration_minutes: number;
  carers_required: 1 | 2; effective_from: ISODate; effective_to: ISODate | null;
  instructions: string | null; status: 'active' | 'paused' | 'ended';
}
export interface VisitAssignment {
  id: UUID; company_id: UUID; visit_id: UUID; employee_id: UUID;
  assignment_slot: 1 | 2; assigned_at: ISODateTime;
}
export interface InvoicePayment {
  id: UUID; company_id: UUID; invoice_id: UUID; amount: number; received_at: ISODate;
  method: 'bank_transfer' | 'direct_debit' | 'card' | 'cash' | 'cheque' | 'credit_note' | 'other';
  reference: string | null; notes: string | null;
}
export interface DashboardMetrics {
  service_users: number; employees: number; visits_today: number; completed_today: number;
  open_incidents: number; medication_exceptions: number;
}
export interface NavigationItem { key: string; label: string; capability?: string; }
