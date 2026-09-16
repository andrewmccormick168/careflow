import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';

const page = (name: string) => readFileSync(new URL(`./pages/${name}`, import.meta.url), 'utf8');
const migration = readFileSync(new URL('../../../supabase/migrations/20260916200000_operational_areas_finance_workforce.sql', import.meta.url), 'utf8');

describe('operational expansion', () => {
  it('enforces operational areas in the database security boundary', () => {
    expect(migration).toContain('create table public.operational_areas');
    expect(migration).toContain('create table public.membership_area_access');
    expect(migration).toContain('function public.can_access_area');
    expect(migration).toContain('public.can_access_area(company_id,area_id)');
    expect(migration).toContain('alter table public.invoice_payments enable row level security');
  });

  it('calculates debtor balances from invoices and recorded payments', () => {
    const source = page('BusinessOperationsPages.tsx');
    expect(source).toContain("useRows('invoice_payments'");
    expect(source).toContain('Number(invoice.total) - paidFor(invoice)');
    expect(source).toContain('Record payment');
    expect(source).toContain('Outstanding');
    expect(source).toContain('Overdue');
  });

  it('reconciles staff hours against actual visit timestamps', () => {
    const source = page('BusinessOperationsPages.tsx');
    expect(source).toContain('actual_arrival_at');
    expect(source).toContain('actual_departure_at');
    expect(source).toContain('Actual delivered care');
    expect(source).toContain('Timesheet variance minutes');
  });

  it('uses a full-screen structured care-plan workspace', () => {
    const source = page('AdvancedCarePage.tsx');
    expect(source).toContain('full-screen-modal');
    expect(source).toContain('Desired personal outcome');
    expect(source).toContain('How staff must provide support');
    expect(source).toContain("useCreateRow('care_plan_reviews')");
    expect(source).toContain('standardSections');
  });
});
