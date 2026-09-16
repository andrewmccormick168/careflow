const today = new Date();
const day = (offset = 0) => { const d = new Date(today); d.setDate(d.getDate() + offset); return d.toISOString().slice(0,10); };
const at = (hour: number, offset = 0) => `${day(offset)}T${String(hour).padStart(2,'0')}:00:00.000Z`;

export const demoData: Record<string, Record<string, unknown>[]> = {
  operational_areas: [
    { id:'a1', name:'North Lanarkshire', code:'NL01', office_name:'Motherwell office', address:'Motherwell', contact_phone:'01698 555 100', status:'active' },
    { id:'a2', name:'Glasgow', code:'GL01', office_name:'Glasgow office', address:'Glasgow', contact_phone:'0141 555 1000', status:'active' },
  ],
  employees: [
    { id:'e1', area_id:'a2', area:{name:'Glasgow',code:'GL01'}, full_name:'Sarah Campbell', job_title:'Senior Care Assistant', contact_email:'sarah@example.test', contact_phone:'07700 900101', status:'active' },
    { id:'e2', area_id:'a2', area:{name:'Glasgow',code:'GL01'}, full_name:'John Reid', job_title:'Care Assistant', contact_email:'john@example.test', contact_phone:'07700 900102', status:'active' },
    { id:'e3', area_id:'a1', area:{name:'North Lanarkshire',code:'NL01'}, full_name:'Amina Khan', job_title:'Care Coordinator', contact_email:'amina@example.test', contact_phone:'07700 900103', status:'active' },
    { id:'e4', area_id:'a1', area:{name:'North Lanarkshire',code:'NL01'}, full_name:'David Fraser', job_title:'Care Assistant', contact_email:'david@example.test', contact_phone:'07700 900104', status:'active' },
  ],
  service_users: [
    { id:'s1', area_id:'a2', area:{name:'Glasgow',code:'GL01'}, funding_type:'local_authority', payer_name:'Glasgow City Council', full_name:'Margaret Wilson', preferred_name:'Maggie', address:'12 Orchard View, Glasgow', contact_phone:'0141 555 0101', important_alerts:'Penicillin allergy • High falls risk', status:'active' },
    { id:'s2', area_id:'a2', area:{name:'Glasgow',code:'GL01'}, funding_type:'private', full_name:'Robert McLean', preferred_name:'Bobby', address:'8 Station Road, Paisley', contact_phone:'0141 555 0102', important_alerts:'Diabetic • Texture-modified diet', status:'active' },
    { id:'s3', area_id:'a1', area:{name:'North Lanarkshire',code:'NL01'}, funding_type:'local_authority', payer_name:'North Lanarkshire Council', full_name:'Jean Douglas', preferred_name:'Jean', address:'31 Meadow Crescent, East Kilbride', contact_phone:'0141 555 0103', important_alerts:'DNACPR recorded', status:'active' },
    { id:'s4', area_id:'a1', area:{name:'North Lanarkshire',code:'NL01'}, funding_type:'private', full_name:'William Young', preferred_name:'Bill', address:'5 Rowan Gardens, Motherwell', contact_phone:'01698 555 104', important_alerts:null, status:'active' },
  ],
  visits: [
    { id:'v1', area_id:'a2', service_user_id:'s1', employee_id:'e1', service_user:{full_name:'Margaret Wilson'}, employee:{full_name:'Sarah Campbell'}, visit_type:'Morning care', starts_at:at(8), ends_at:at(9), actual_arrival_at:at(8), actual_departure_at:at(9), status:'completed', notes:'All tasks completed' },
    { id:'v2', area_id:'a2', service_user_id:'s2', employee_id:'e2', service_user:{full_name:'Robert McLean'}, employee:{full_name:'John Reid'}, visit_type:'Medication & breakfast', starts_at:at(9), ends_at:at(10), actual_arrival_at:at(9), status:'in_progress', notes:null },
    { id:'v3', area_id:'a1', service_user_id:'s3', employee_id:'e4', service_user:{full_name:'Jean Douglas'}, employee:{full_name:'David Fraser'}, visit_type:'Welfare visit', starts_at:at(11), ends_at:at(12), status:'scheduled', notes:null },
    { id:'v4', area_id:'a2', service_user_id:'s1', employee_id:'e2', service_user:{full_name:'Margaret Wilson'}, employee:{full_name:'John Reid'}, visit_type:'Tea visit', starts_at:at(16), ends_at:at(17), status:'scheduled', notes:null },
    { id:'v5', area_id:'a1', service_user_id:'s4', employee_id:'e1', service_user:{full_name:'William Young'}, employee:{full_name:'Sarah Campbell'}, visit_type:'Evening care', starts_at:at(18), ends_at:at(19), status:'scheduled', notes:null },
  ],
  care_plans: [
    { id:'cp1', service_user_id:'s1', service_user:{full_name:'Margaret Wilson'}, title:'Care and support plan', status:'active', version:3, effective_from:day(-30), review_due:day(21), summary:'Support with personal care, mobility and medication.' },
    { id:'cp2', service_user_id:'s2', service_user:{full_name:'Robert McLean'}, title:'Care and support plan', status:'active', version:2, effective_from:day(-62), review_due:day(7), summary:'Diabetes support, meal preparation and wellbeing.' },
    { id:'cp3', service_user_id:'s3', service_user:{full_name:'Jean Douglas'}, title:'Care and support plan', status:'draft', version:1, effective_from:null, review_due:null, summary:'Awaiting manager approval.' },
  ],
  risk_assessments: [
    { id:'r1', service_user_id:'s1', service_user:{full_name:'Margaret Wilson'}, category:'Falls', hazard:'Reduced mobility when transferring', likelihood:4, severity:4, controls:'Walking frame and one-person assistance', status:'controlled', review_due:day(14) },
    { id:'r2', service_user_id:'s2', service_user:{full_name:'Robert McLean'}, category:'Medication', hazard:'Hypoglycaemia', likelihood:3, severity:5, controls:'Monitor intake and follow diabetes plan', status:'open', review_due:day(5) },
  ],
  medications: [
    { id:'m1', service_user_id:'s1', service_user:{full_name:'Margaret Wilson'}, name:'Amlodipine', strength:'5 mg', form:'Tablet', route:'Oral', instructions:'One each morning', prn:false, status:'active' },
    { id:'m2', service_user_id:'s1', service_user:{full_name:'Margaret Wilson'}, name:'Paracetamol', strength:'500 mg', form:'Tablet', route:'Oral', instructions:'Two when required, maximum 8 daily', prn:true, status:'active' },
    { id:'m3', service_user_id:'s2', service_user:{full_name:'Robert McLean'}, name:'Metformin', strength:'500 mg', form:'Tablet', route:'Oral', instructions:'One with breakfast and evening meal', prn:false, status:'active' },
  ],
  mar_entries: [
    { id:'mar1', service_user_id:'s1', medication_id:'m1', service_user:{full_name:'Margaret Wilson'}, medication:{name:'Amlodipine'}, scheduled_for:at(8), outcome:'given', administered_at:at(8), dose_given:'5 mg' },
    { id:'mar2', service_user_id:'s2', medication_id:'m3', service_user:{full_name:'Robert McLean'}, medication:{name:'Metformin'}, scheduled_for:at(9), outcome:'refused', administered_at:at(9), reason:'Service user declined; manager informed' },
  ],
  incidents: [
    { id:'i1', service_user_id:'s1', service_user:{full_name:'Margaret Wilson'}, incident_type:'Near miss', severity:'medium', occurred_at:at(7,-1), description:'Unsteady transfer from chair; no injury.', immediate_action:'Mobility assessment requested.', status:'investigating' },
    { id:'i2', service_user_id:'s3', service_user:{full_name:'Jean Douglas'}, incident_type:'Medication error', severity:'high', occurred_at:at(18,-3), description:'Dose omitted during evening call.', immediate_action:'On-call manager and GP contacted.', status:'actions_pending' },
  ],
  safeguarding_records: [
    { id:'sg1', service_user_id:'s2', service_user:{full_name:'Robert McLean'}, concern_type:'Financial', risk_level:'medium', status:'referred', created_at:at(10,-5), local_authority_ref:'LA-2026-1042' },
  ],
  timesheets: [
    { id:'t1', employee_id:'e1', employee:{full_name:'Sarah Campbell'}, period_start:day(-7), period_end:day(-1), regular_minutes:2220, overtime_minutes:120, status:'submitted' },
    { id:'t2', employee_id:'e2', employee:{full_name:'John Reid'}, period_start:day(-7), period_end:day(-1), regular_minutes:2100, overtime_minutes:0, status:'approved' },
  ],
  expenses: [
    { id:'x1', employee_id:'e1', employee:{full_name:'Sarah Campbell'}, expense_date:day(-2), category:'Parking', description:'Hospital appointment', amount:6.5, status:'submitted' },
  ],
  invoices: [
    { id:'inv1', area_id:'a2', service_user_id:'s1', area:{name:'Glasgow',code:'GL01'}, invoice_number:'CF-2026-0048', service_user:{full_name:'Margaret Wilson',payer_name:'Glasgow City Council'}, issue_date:day(-7), due_date:day(7), subtotal:1240, tax:0, total:1240, status:'issued' },
    { id:'inv2', area_id:'a2', service_user_id:'s2', area:{name:'Glasgow',code:'GL01'}, invoice_number:'CF-2026-0047', service_user:{full_name:'Robert McLean'}, issue_date:day(-14), due_date:day(), subtotal:980, tax:0, total:980, status:'paid' },
  ],
  invoice_payments: [
    { id:'pay1', invoice_id:'inv2', amount:980, received_at:day(-2), method:'bank_transfer', reference:'DEMO-PAYMENT' },
  ],
  care_plan_sections: [],
  care_plan_reviews: [],
  audit_events: [
    { id:'a1', action:'update', entity_type:'care_plans', created_at:at(10), profile:{full_name:'Alex Morgan'} },
    { id:'a2', action:'insert', entity_type:'mar_entries', created_at:at(9), profile:{full_name:'Sarah Campbell'} },
  ],
  company_memberships: [
    { id:'u1', status:'active', profile:{full_name:'Alex Morgan',email:'alex@example.test'}, role:{label:'Company Administrator',key:'company_admin'} },
    { id:'u2', status:'active', profile:{full_name:'Amina Khan',email:'amina@example.test'}, role:{label:'Coordinator',key:'coordinator'} },
  ]
};

export const demoMetrics = { service_users:4, employees:4, visits_today:5, completed_today:1, open_incidents:2, medication_exceptions:1 };
