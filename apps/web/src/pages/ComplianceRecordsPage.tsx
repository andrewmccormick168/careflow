import { useMemo, useState } from "react";
import {
  AlertTriangle,
  ClipboardCheck,
  FileText,
  Search,
  ShieldAlert,
} from "lucide-react";
import {
  DataError,
  Empty,
  Field,
  Loading,
  Modal,
  PageHeader,
  Status,
} from "@/components/ui";
import { type Row, useCreateRow, useRows, useUpdateRow } from "@/lib/data";

type Tab = "concerns" | "forms" | "templates";
const today = () => new Date().toISOString().slice(0, 16);

function ConcernForm({
  people,
  record,
  onClose,
}: {
  people: Row[];
  record: Row | undefined;
  onClose: () => void;
}) {
  const create = useCreateRow("care_concerns");
  const update = useUpdateRow("care_concerns");
  const mutation = record ? update : create;
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const values = Object.fromEntries(new FormData(event.currentTarget));
    await mutation.mutateAsync(
      record
        ? {
            id: record.id,
            ...values,
            escalation_required: values.escalation_required === "on",
          }
        : {
            ...values,
            escalation_required: values.escalation_required === "on",
          },
    );
    onClose();
  }
  return (
    <form className="form-grid" onSubmit={submit}>
      <Field label="Person supported">
        <select
          name="service_user_id"
          defaultValue={record?.service_user_id ?? ""}
          disabled={Boolean(record)}
          required
        >
          <option value="" disabled>
            Select person
          </option>
          {people
            .filter((x) => x.status === "active")
            .map((x) => (
              <option key={x.id} value={x.id}>
                {x.full_name}
              </option>
            ))}
        </select>
      </Field>
      <Field label="Concern type">
        <select
          name="concern_type"
          defaultValue={record?.concern_type ?? "wellbeing"}
        >
          <option value="wellbeing">Wellbeing</option>
          <option value="care_delivery">Care delivery</option>
          <option value="medication">Medication</option>
          <option value="nutrition_hydration">Nutrition / hydration</option>
          <option value="skin_integrity">Skin integrity</option>
          <option value="behaviour">Behaviour</option>
          <option value="environment">Environment</option>
          <option value="complaint">Complaint</option>
          <option value="other">Other</option>
        </select>
      </Field>
      <Field label="Severity">
        <select name="severity" defaultValue={record?.severity ?? "medium"}>
          <option value="low">Low</option>
          <option value="medium">Medium</option>
          <option value="high">High</option>
          <option value="immediate">Immediate risk</option>
        </select>
      </Field>
      <Field label="Date and time">
        <input
          name="occurred_at"
          type="datetime-local"
          defaultValue={record?.occurred_at?.slice(0, 16) ?? today()}
          required
        />
      </Field>
      <Field label="What was observed or reported">
        <textarea
          name="details"
          defaultValue={record?.details ?? ""}
          required
        />
      </Field>
      <Field label="Immediate action taken">
        <textarea
          name="immediate_action"
          defaultValue={record?.immediate_action ?? ""}
        />
      </Field>
      <Field label="Escalated to">
        <input
          name="escalated_to"
          defaultValue={record?.escalated_to ?? ""}
          placeholder="Manager, GP, social worker…"
        />
      </Field>
      <Field label="Workflow status">
        <select name="status" defaultValue={record?.status ?? "open"}>
          <option value="open">Open</option>
          <option value="reviewing">Under review</option>
          <option value="action_required">Action required</option>
          <option value="closed">Closed</option>
        </select>
      </Field>
      <Field label="Outcome / management response">
        <textarea name="outcome" defaultValue={record?.outcome ?? ""} />
      </Field>
      <label className="checkbox-field">
        <input
          name="escalation_required"
          type="checkbox"
          defaultChecked={record?.escalation_required ?? false}
        />
        <span>Formal escalation is required</span>
      </label>
      {mutation.error && <p className="form-error">{mutation.error.message}</p>}
      <div className="form-actions">
        <button type="button" className="btn" onClick={onClose}>
          Cancel
        </button>
        <button className="btn primary" disabled={mutation.isPending}>
          {mutation.isPending ? "Saving…" : "Save concern"}
        </button>
      </div>
    </form>
  );
}

function TemplateForm({
  record,
  onClose,
}: {
  record: Row | undefined;
  onClose: () => void;
}) {
  const create = useCreateRow("form_templates");
  const update = useUpdateRow("form_templates");
  const mutation = record ? update : create;
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const raw = Object.fromEntries(new FormData(event.currentTarget));
    const labels = String(raw.field_labels || "")
      .split("\n")
      .map((x) => x.trim())
      .filter(Boolean);
    const fields = labels.map((label, index) => ({
      key: `field_${index + 1}`,
      label,
      type: "textarea",
      required: false,
    }));
    const values = { ...raw };
    delete values.field_labels;
    await mutation.mutateAsync(
      record ? { id: record.id, ...values, fields } : { ...values, fields },
    );
    onClose();
  }
  const labels = (record?.fields ?? [])
    .map((field: Row) => field.label)
    .join("\n");
  return (
    <form className="form-grid" onSubmit={submit}>
      <Field label="Form name">
        <input name="name" defaultValue={record?.name ?? ""} required />
      </Field>
      <Field label="Category">
        <select name="category" defaultValue={record?.category ?? "Assessment"}>
          <option>Assessment</option>
          <option>Consent</option>
          <option>Monitoring</option>
          <option>Review</option>
          <option>Body map</option>
          <option>Medication</option>
          <option>Quality</option>
          <option>Other</option>
        </select>
      </Field>
      <Field label="Version">
        <input
          name="version"
          type="number"
          min="1"
          defaultValue={record?.version ?? 1}
          required
        />
      </Field>
      <Field label="Review frequency (days)">
        <input
          name="review_frequency_days"
          type="number"
          min="1"
          defaultValue={record?.review_frequency_days ?? ""}
        />
      </Field>
      <Field label="Description">
        <textarea name="description" defaultValue={record?.description ?? ""} />
      </Field>
      <Field label="Instructions">
        <textarea
          name="instructions"
          defaultValue={record?.instructions ?? ""}
        />
      </Field>
      <Field label="Form questions (one per line)">
        <textarea
          name="field_labels"
          defaultValue={labels}
          placeholder={"Skin condition\nActions required\nPerson informed"}
          required
        />
      </Field>
      <Field label="Status">
        <select name="status" defaultValue={record?.status ?? "active"}>
          <option value="draft">Draft</option>
          <option value="active">Active</option>
          <option value="retired">Retired</option>
        </select>
      </Field>
      {mutation.error && <p className="form-error">{mutation.error.message}</p>}
      <div className="form-actions">
        <button type="button" className="btn" onClick={onClose}>
          Cancel
        </button>
        <button className="btn primary">Save template</button>
      </div>
    </form>
  );
}

function SubmissionForm({
  people,
  templates,
  onClose,
}: {
  people: Row[];
  templates: Row[];
  onClose: () => void;
}) {
  const create = useCreateRow("form_submissions");
  const [templateId, setTemplateId] = useState("");
  const template = templates.find((x) => x.id === templateId);
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const responses: Record<string, string> = Object.fromEntries(
      (template?.fields ?? []).map((field: Row) => [
        field.key,
        String(form.get(`response_${field.key}`) ?? ""),
      ]),
    );
    await create.mutateAsync({
      template_id: templateId,
      service_user_id: form.get("service_user_id"),
      title: form.get("title"),
      status: form.get("status"),
      responses,
      ...(form.get("status") === "completed"
        ? { completed_at: new Date().toISOString() }
        : {}),
    });
    onClose();
  }
  return (
    <form className="form-grid" onSubmit={submit}>
      <Field label="Form template">
        <select
          value={templateId}
          onChange={(e) => setTemplateId(e.target.value)}
          required
        >
          <option value="" disabled>
            Select template
          </option>
          {templates
            .filter((x) => x.status === "active")
            .map((x) => (
              <option key={x.id} value={x.id}>
                {x.name} · v{x.version}
              </option>
            ))}
        </select>
      </Field>
      <Field label="Person supported">
        <select name="service_user_id" defaultValue="" required>
          <option value="" disabled>
            Select person
          </option>
          {people
            .filter((x) => x.status === "active")
            .map((x) => (
              <option key={x.id} value={x.id}>
                {x.full_name}
              </option>
            ))}
        </select>
      </Field>
      <Field label="Record title">
        <input name="title" defaultValue={template?.name ?? ""} required />
      </Field>
      {(template?.fields ?? []).map((field: Row) => (
        <Field key={field.key} label={field.label}>
          <textarea
            name={`response_${field.key}`}
            required={Boolean(field.required)}
          />
        </Field>
      ))}
      <Field label="Status">
        <select name="status" defaultValue="completed">
          <option value="draft">Draft</option>
          <option value="completed">Completed</option>
          <option value="review_required">Review required</option>
        </select>
      </Field>
      {create.error && <p className="form-error">{create.error.message}</p>}
      <div className="form-actions">
        <button type="button" className="btn" onClick={onClose}>
          Cancel
        </button>
        <button
          className="btn primary"
          disabled={!templateId || create.isPending}
        >
          Save completed form
        </button>
      </div>
    </form>
  );
}

export function ComplianceRecordsPage() {
  const [tab, setTab] = useState<Tab>("concerns");
  const [search, setSearch] = useState("");
  const [editing, setEditing] = useState<Row | "new" | null>(null);
  const concerns = useRows("care_concerns", "occurred_at", false);
  const templates = useRows("form_templates", "name", true);
  const submissions = useRows("form_submissions", "created_at", false);
  const people = useRows("service_users", "full_name", true);
  const source =
    tab === "concerns" ? concerns : tab === "forms" ? submissions : templates;
  const rows = useMemo(
    () =>
      (source.data ?? []).filter((row) =>
        JSON.stringify(row).toLowerCase().includes(search.toLowerCase()),
      ),
    [source.data, search],
  );
  const action =
    tab === "concerns"
      ? "Raise concern"
      : tab === "forms"
        ? "Complete form"
        : "Create template";
  const close = () => setEditing(null);
  return (
    <>
      <PageHeader
        title="Forms & concerns"
        description="Controlled care forms, observations, concerns, escalation and review evidence."
        action={action}
        onAction={() => setEditing("new")}
      />
      <div className="care-toolbar">
        <div className="tabs">
          <button
            className={tab === "concerns" ? "active" : ""}
            onClick={() => {
              setTab("concerns");
              close();
            }}
          >
            <ShieldAlert />
            Concerns
          </button>
          <button
            className={tab === "forms" ? "active" : ""}
            onClick={() => {
              setTab("forms");
              close();
            }}
          >
            <ClipboardCheck />
            Completed forms
          </button>
          <button
            className={tab === "templates" ? "active" : ""}
            onClick={() => {
              setTab("templates");
              close();
            }}
          >
            <FileText />
            Templates
          </button>
        </div>
        <label className="rota-search">
          <Search />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search records…"
          />
        </label>
      </div>
      {source.isLoading || people.isLoading ? (
        <Loading />
      ) : source.error || people.error ? (
        <DataError message={(source.error || people.error)?.message} />
      ) : rows.length ? (
        <div className="table-card">
          <table>
            <thead>
              {tab === "concerns" ? (
                <tr>
                  <th>Person</th>
                  <th>Concern</th>
                  <th>Date</th>
                  <th>Escalation</th>
                  <th>Status</th>
                </tr>
              ) : tab === "forms" ? (
                <tr>
                  <th>Person</th>
                  <th>Form</th>
                  <th>Created</th>
                  <th>Status</th>
                </tr>
              ) : (
                <tr>
                  <th>Template</th>
                  <th>Category</th>
                  <th>Version</th>
                  <th>Review cycle</th>
                  <th>Status</th>
                </tr>
              )}
            </thead>
            <tbody>
              {rows.map((row) =>
                tab === "concerns" ? (
                  <tr
                    key={row.id}
                    className="clickable"
                    onClick={() => setEditing(row)}
                  >
                    <td>
                      <strong>{row.service_user?.full_name}</strong>
                    </td>
                    <td>
                      <strong>
                        {String(row.concern_type).replaceAll("_", " ")}
                      </strong>
                      <small>{row.details}</small>
                    </td>
                    <td>{new Date(row.occurred_at).toLocaleString("en-GB")}</td>
                    <td>
                      {row.escalation_required ? (
                        <span className="dispatch-alert">
                          <AlertTriangle />
                          Required
                        </span>
                      ) : (
                        "Routine"
                      )}
                    </td>
                    <td>
                      <Status value={row.status} />
                    </td>
                  </tr>
                ) : tab === "forms" ? (
                  <tr key={row.id}>
                    <td>
                      <strong>{row.service_user?.full_name}</strong>
                    </td>
                    <td>
                      <strong>{row.title}</strong>
                      <small>
                        {row.template?.name} · v{row.template?.version}
                      </small>
                    </td>
                    <td>{new Date(row.created_at).toLocaleString("en-GB")}</td>
                    <td>
                      <Status value={row.status} />
                    </td>
                  </tr>
                ) : (
                  <tr
                    key={row.id}
                    className="clickable"
                    onClick={() => setEditing(row)}
                  >
                    <td>
                      <strong>{row.name}</strong>
                      <small>{row.description}</small>
                    </td>
                    <td>{row.category}</td>
                    <td>{row.version}</td>
                    <td>
                      {row.review_frequency_days
                        ? `${row.review_frequency_days} days`
                        : "As required"}
                    </td>
                    <td>
                      <Status value={row.status} />
                    </td>
                  </tr>
                ),
              )}
            </tbody>
          </table>
        </div>
      ) : (
        <Empty text={`No ${tab.replace("_", " ")} recorded`} />
      )}{" "}
      {editing && (
        <Modal
          title={
            tab === "concerns"
              ? editing === "new"
                ? "Raise a concern"
                : "Review concern"
              : tab === "forms"
                ? "Complete a form"
                : editing === "new"
                  ? "Create form template"
                  : "Edit form template"
          }
          onClose={close}
          className="full-screen-modal"
        >
          {tab === "concerns" ? (
            <ConcernForm
              people={people.data ?? []}
              record={editing === "new" ? undefined : editing}
              onClose={close}
            />
          ) : tab === "forms" ? (
            <SubmissionForm
              people={people.data ?? []}
              templates={templates.data ?? []}
              onClose={close}
            />
          ) : (
            <TemplateForm
              record={editing === "new" ? undefined : editing}
              onClose={close}
            />
          )}
        </Modal>
      )}
    </>
  );
}
