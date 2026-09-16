-- The authenticated browser client manages medication schedules through RLS.
-- The earlier browser-role grant migration exposed SELECT but omitted the
-- INSERT/UPDATE table privileges required by medication managers.

grant insert on table public.medication_schedules to authenticated;

grant update (
  dose,
  scheduled_time,
  days_of_week,
  notes
) on public.medication_schedules to authenticated;
