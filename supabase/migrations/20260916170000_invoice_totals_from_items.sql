-- Invoice totals must be derived from line items, never trusted from a client.

create or replace function public.recalculate_invoice_totals()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  target_invoice_id uuid;
  target_company_id uuid;
begin
  target_invoice_id := coalesce(new.invoice_id, old.invoice_id);
  target_company_id := coalesce(new.company_id, old.company_id);

  update public.invoices
  set subtotal = coalesce((
    select sum(item.line_total)
    from public.invoice_items item
    where item.invoice_id = target_invoice_id
      and item.company_id = target_company_id
  ), 0),
  updated_at = now()
  where id = target_invoice_id and company_id = target_company_id;

  return coalesce(new, old);
end;
$$;

revoke execute on function public.recalculate_invoice_totals()
from public, anon, authenticated;

create trigger invoice_items_recalculate_totals
after insert or update or delete on public.invoice_items
for each row execute function public.recalculate_invoice_totals();
