import { describe, expect, it } from 'vitest';
import { demoData, demoMetrics } from './demoData';

describe('CareFlow demo workspace',()=>{
  it('keeps every visit linked to a known person and employee',()=>{
    const people=new Set(demoData.service_users?.map(r=>r.id));
    const employees=new Set(demoData.employees?.map(r=>r.id));
    for(const visit of demoData.visits??[]){
      expect(people.has(visit.service_user_id)).toBe(true);
      expect(employees.has(visit.employee_id)).toBe(true);
    }
  });
  it('matches dashboard totals to active demo records',()=>{
    expect(demoMetrics.service_users).toBe(demoData.service_users?.filter(r=>r.status==='active').length);
    expect(demoMetrics.employees).toBe(demoData.employees?.filter(r=>r.status==='active').length);
  });
  it('contains representative data for every main workflow',()=>{
    for(const table of ['care_plans','risk_assessments','visits','medications','mar_entries','incidents','safeguarding_records','timesheets','expenses','invoices'])
      expect(demoData[table]?.length,table).toBeGreaterThan(0);
  });
});
