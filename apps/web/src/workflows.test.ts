import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';

const page=(name:string)=>readFileSync(new URL(`./pages/${name}`,import.meta.url),'utf8');
const component=(name:string)=>readFileSync(new URL(`./components/${name}`,import.meta.url),'utf8');
const hasCall=(source:string,fn:string,value:string)=>new RegExp(`${fn}\\(["']${value}["']`).test(source);

describe('live workflow wiring',()=>{
  it('does not use browser alerts as placeholder actions',()=>{
    for(const name of ['PeoplePage.tsx','CarePage.tsx','AdvancedCarePage.tsx','BusinessOperationsPages.tsx','TimelineRotaPage.tsx','ScalableRotaPage.tsx','MedicationPage.tsx','IncidentsPage.tsx','OperationsPages.tsx']){
      expect(page(name),name).not.toContain('alert(');
    }
  });

  it('wires the person record and visit scheduler to mutations',()=>{
    expect(page('PeoplePage.tsx')).toContain('View care record');
    expect(page('PeoplePage.tsx')).toContain('care-record-modal');
    expect(hasCall(page('PeoplePage.tsx'),'useCreateRow','visits')).toBe(true);
    expect(page('TimelineRotaPage.tsx')).toContain('ScheduleVisit');
    expect(hasCall(page('TimelineRotaPage.tsx'),'useCreateRow','care_records')).toBe(true);
    expect(component('CareScheduleBuilder.tsx')).toContain('useCreateServiceUserVisitSchedule');
    expect(component('CareScheduleBuilder.tsx')).toContain('Create schedule and six-week rota');
    expect(page('TimelineRotaPage.tsx')).toContain('Dispatch schedule');
    expect(page('ScalableRotaPage.tsx')).toContain('ServiceUserTimeline');
    expect(page('ScalableRotaPage.tsx')).toContain('Group by');
    expect(page('ScalableRotaPage.tsx')).toContain('Search service user, employee or visit');
    expect(page('ScalableRotaPage.tsx')).toContain('Staffing gaps only');
    expect(page('TimelineRotaPage.tsx')).toContain('draggable');
    expect(page('TimelineRotaPage.tsx')).toContain('useSetVisitAssignment');
  });

  it('uses stored data for operational reports',()=>{
    const source=page('OperationsPages.tsx');
    for(const table of ['visits','care_plans','mar_entries','timesheets','incidents','audit_events']){
      expect(hasCall(source,'useRows',table)).toBe(true);
    }
    expect(source).toContain('downloadCsv');
    expect(source).toContain('Late start');
    expect(source).toContain('Missed / overdue');
    expect(source).toContain('Under-allocated');
    expect(source).toContain('Reporting definitions');
  });
});
