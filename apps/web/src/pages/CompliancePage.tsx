import { useMemo, useState } from "react";
import { BookOpenCheck, BriefcaseMedical, ShieldCheck } from "lucide-react";
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

type Tab = "checks" | "training" | "services";

function CheckForm({
  employees,
  record,
  onClose,
}: {
  employees: Row[];
  record: Row | undefined;
  onClose: () => void;
}) {
  const create = useCreateRow("employee_compliance");
  const update = useUpdateRow("employee_compliance");
  const mutation = record ? update : create;
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const raw = Object.fromEntries(new FormData(event.currentTarget));
    const values = {
      ...raw,
      barred_list_checked: raw.barred_list_checked === "on",
      two_references_received: raw.two_references_received === "on",
      identity_verified: raw.identity_verified === "on",
      health_declaration_completed: raw.health_declaration_completed === "on",
      recruitment_complete: raw.recruitment_complete === "on",
    };
    await mutation.mutateAsync(record ? { id: record.id, ...values } : values);
    onClose();
  }
  return (
    <form className="form-grid" onSubmit={submit}>
      <Field label="Employee">
        <select
          name="employee_id"
          defaultValue={record?.employee_id ?? ""}
          disabled={Boolean(record)}
          required
        >
          <option value="" disabled>
            Select employee
          </option>
          {employees.map((employee) => (
            <option key={employee.id} value={employee.id}>
              {employee.full_name}
            </option>
          ))}
        </select>
      </Field>
      <Field label="Right to work">
        <select
          name="right_to_work_status"
          defaultValue={record?.right_to_work_status ?? "not_checked"}
        >
          <option value="not_checked">Not checked</option>
          <option value="verified">Verified</option>
          <option value="time_limited">Time limited</option>
          <option value="failed">Failed</option>
        </select>
      </Field>
      <Field label="Right-to-work check date">
        <input
          name="right_to_work_checked_at"
          type="date"
          defaultValue={record?.right_to_work_checked_at ?? ""}
        />
      </Field>
      <Field label="Right-to-work expiry">
        <input
          name="right_to_work_expiry"
          type="date"
          defaultValue={record?.right_to_work_expiry ?? ""}
        />
      </Field>
      <Field label="Disclosure scheme">
        <select
          name="disclosure_scheme"
          defaultValue={record?.disclosure_scheme ?? "pvg"}
        >
          <option value="pvg">PVG (Scotland)</option>
          <option value="dbs">DBS (England/Wales)</option>
          <option value="accessni">AccessNI</option>
        </select>
      </Field>
      <Field label="Certificate number">
        <input
          name="disclosure_number"
          defaultValue={record?.disclosure_number ?? ""}
        />
      </Field>
      <Field label="Review date">
        <input
          name="disclosure_review_date"
          type="date"
          defaultValue={record?.disclosure_review_date ?? ""}
        />
      </Field>
      <Field label="Registration body">
        <select
          name="registration_body"
          defaultValue={record?.registration_body ?? "sssc"}
        >
          <option value="sssc">SSSC</option>
          <option value="social_care_wales">Social Care Wales</option>
          <option value="niscc">NISCC</option>
          <option value="nmc">NMC</option>
          <option value="hcpc">HCPC</option>
          <option value="other">Other</option>
        </select>
      </Field>
      <Field label="Registration number">
        <input
          name="registration_number"
          defaultValue={record?.registration_number ?? ""}
        />
      </Field>
      <Field label="Registration expiry">
        <input
          name="registration_expiry"
          type="date"
          defaultValue={record?.registration_expiry ?? ""}
        />
      </Field>
      <Field label="Registration status">
        <select
          name="registration_status"
          defaultValue={record?.registration_status ?? "pending"}
        >
          <option value="not_required">Not required</option>
          <option value="pending">Pending</option>
          <option value="active">Active</option>
          <option value="expired">Expired</option>
          <option value="suspended">Suspended</option>
        </select>
      </Field>
      {[
        "barred_list_checked",
        "two_references_received",
        "identity_verified",
        "health_declaration_completed",
        "recruitment_complete",
      ].map((key) => (
        <label className="checkbox-field" key={key}>
          <input
            name={key}
            type="checkbox"
            defaultChecked={Boolean(record?.[key])}
          />
          <span>{key.replaceAll("_", " ")}</span>
        </label>
      ))}
      <Field label="Compliance notes">
        <textarea name="notes" defaultValue={record?.notes ?? ""} />
      </Field>
      {mutation.error && <p className="form-error">{mutation.error.message}</p>}
      <div className="form-actions">
        <button type="button" className="btn" onClick={onClose}>
          Cancel
        </button>
        <button className="btn primary" disabled={mutation.isPending}>
          {mutation.isPending ? "Saving…" : "Save checks"}
        </button>
      </div>
    </form>
  );
}

function TrainingForm({
  employees,
  courses,
  onClose,
}: {
  employees: Row[];
  courses: Row[];
  onClose: () => void;
}) {
  const create = useCreateRow("employee_training");
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await create.mutateAsync(
      Object.fromEntries(new FormData(event.currentTarget)),
    );
    onClose();
  }
  return (
    <form className="form-grid" onSubmit={submit}>
      <Field label="Employee">
        <select name="employee_id" defaultValue="" required>
          <option value="" disabled>
            Select employee
          </option>
          {employees.map((row) => (
            <option key={row.id} value={row.id}>
              {row.full_name}
            </option>
          ))}
        </select>
      </Field>
      <Field label="Course">
        <select name="course_id" defaultValue="" required>
          <option value="" disabled>
            Select course
          </option>
          {courses.map((row) => (
            <option key={row.id} value={row.id}>
              {row.name}
            </option>
          ))}
        </select>
      </Field>
      <Field label="Status">
        <select name="status" defaultValue="required">
          <option value="required">Required</option>
          <option value="booked">Booked</option>
          <option value="complete">Complete</option>
          <option value="expired">Expired</option>
          <option value="waived">Waived</option>
        </select>
      </Field>
      <Field label="Completed">
        <input name="completed_at" type="date" />
      </Field>
      <Field label="Expires">
        <input name="expires_at" type="date" />
      </Field>
      <Field label="Provider">
        <input name="provider" />
      </Field>
      <Field label="Certificate number">
        <input name="certificate_number" />
      </Field>
      <Field label="Notes">
        <textarea name="notes" />
      </Field>
      {create.error && <p className="form-error">{create.error.message}</p>}
      <div className="form-actions">
        <button type="button" className="btn" onClick={onClose}>
          Cancel
        </button>
        <button className="btn primary" disabled={create.isPending}>
          Save training
        </button>
      </div>
    </form>
  );
}

function ServiceForm({
  record,
  onClose,
}: {
  record: Row | undefined;
  onClose: () => void;
}) {
  const create = useCreateRow("service_types");
  const update = useUpdateRow("service_types");
  const mutation = record ? update : create;
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const raw = Object.fromEntries(new FormData(event.currentTarget));
    const tasks = String(raw.tasks || "")
      .split("\n")
      .map((value) => value.trim())
      .filter(Boolean)
      .map((label, index) => ({
        key: `task_${index + 1}`,
        label,
        required: true,
      }));
    delete raw.tasks;
    await mutation.mutateAsync({
      ...(record ? { id: record.id } : {}),
      ...raw,
      medication_support: raw.medication_support === "on",
      regulated_activity: raw.regulated_activity === "on",
      task_template: tasks,
    });
    onClose();
  }
  return (
    <form className="form-grid" onSubmit={submit}>
      <Field label="Service name">
        <input name="name" defaultValue={record?.name ?? ""} required />
      </Field>
      <Field label="Category">
        <input
          name="category"
          defaultValue={record?.category ?? "Personal care"}
          required
        />
      </Field>
      <Field label="Default duration (minutes)">
        <input
          name="default_duration_minutes"
          type="number"
          min="5"
          defaultValue={record?.default_duration_minutes ?? 30}
          required
        />
      </Field>
      <Field label="Travel allowance (minutes)">
        <input
          name="default_travel_minutes"
          type="number"
          min="0"
          defaultValue={record?.default_travel_minutes ?? 15}
          required
        />
      </Field>
      <Field label="Minimum staff">
        <input
          name="minimum_staff"
          type="number"
          min="1"
          max="4"
          defaultValue={record?.minimum_staff ?? 1}
          required
        />
      </Field>
      <Field label="Status">
        <select name="status" defaultValue={record?.status ?? "active"}>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </select>
      </Field>
      <Field label="Description">
        <textarea name="description" defaultValue={record?.description ?? ""} />
      </Field>
      <Field label="Required tasks (one per line)">
        <textarea
          name="tasks"
          defaultValue={(record?.task_template ?? [])
            .map((task: Row) => task.label)
            .join("\n")}
        />
      </Field>
      <label className="checkbox-field">
        <input
          name="medication_support"
          type="checkbox"
          defaultChecked={Boolean(record?.medication_support)}
        />
        <span>Includes medication support</span>
      </label>
      <label className="checkbox-field">
        <input
          name="regulated_activity"
          type="checkbox"
          defaultChecked={record?.regulated_activity ?? true}
        />
        <span>Regulated care activity</span>
      </label>
      {mutation.error && <p className="form-error">{mutation.error.message}</p>}
      <div className="form-actions">
        <button type="button" className="btn" onClick={onClose}>
          Cancel
        </button>
        <button className="btn primary">Save service</button>
      </div>
    </form>
  );
}

export function CompliancePage() {
  const [tab, setTab] = useState<Tab>("checks");
  const [modal, setModal] = useState<"check" | "training" | "service" | null>(
    null,
  );
  const [editing, setEditing] = useState<Row>();
  const employees = useRows("employees", "full_name", true);
  const checks = useRows("employee_compliance", "created_at", false);
  const courses = useRows("training_courses", "name", true);
  const training = useRows("employee_training", "expires_at", true);
  const services = useRows("service_types", "name", true);
  const loading = [employees, checks, courses, training, services].some(
    (query) => query.isLoading,
  );
  const error = [employees, checks, courses, training, services].find(
    (query) => query.error,
  )?.error;
  const activeEmployees = (employees.data ?? []).filter(
    (row) => row.status === "active",
  );
  const checkByEmployee = new Map(
    (checks.data ?? []).map((row) => [row.employee_id, row]),
  );
  const workforceRows = activeEmployees.map((employee) => ({
    employee,
    check: checkByEmployee.get(employee.id),
  }));
  const expiring = useMemo(
    () =>
      (training.data ?? []).filter(
        (row) =>
          row.expires_at &&
          new Date(row.expires_at).getTime() <= Date.now() + 90 * 86400000,
      ),
    [training.data],
  );
  if (loading) return <Loading />;
  if (error) return <DataError message={error.message} />;
  const action =
    tab === "checks"
      ? "Add workforce check"
      : tab === "training"
        ? "Assign training"
        : "Add service";
  return (
    <>
      <PageHeader
        title="Compliance & service catalogue"
        description="Safer recruitment, regulator registration, mandatory training and visit service standards in one operational register."
        action={action}
        onAction={() => {
          setEditing(undefined);
          setModal(
            tab === "checks"
              ? "check"
              : tab === "training"
                ? "training"
                : "service",
          );
        }}
      />
      <div className="tabs">
        <button
          className={tab === "checks" ? "active" : ""}
          onClick={() => setTab("checks")}
        >
          <ShieldCheck />
          Workforce checks
        </button>
        <button
          className={tab === "training" ? "active" : ""}
          onClick={() => setTab("training")}
        >
          <BookOpenCheck />
          Training matrix
        </button>
        <button
          className={tab === "services" ? "active" : ""}
          onClick={() => setTab("services")}
        >
          <BriefcaseMedical />
          Services & tasks
        </button>
      </div>
      {tab === "checks" &&
        (workforceRows.length ? (
          <div className="table-card">
            <table>
              <thead>
                <tr>
                  <th>Employee</th>
                  <th>Right to work</th>
                  <th>Disclosure</th>
                  <th>Registration</th>
                  <th>Recruitment</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {workforceRows.map(({ employee, check }) => (
                  <tr key={employee.id}>
                    <td>
                      <strong>{employee.full_name}</strong>
                      <small>{employee.job_title}</small>
                    </td>
                    <td>
                      <Status
                        value={check?.right_to_work_status ?? "not_checked"}
                      />
                    </td>
                    <td>
                      {check?.disclosure_scheme?.toUpperCase() ??
                        "Not recorded"}
                      <small>{check?.disclosure_review_date || ""}</small>
                    </td>
                    <td>
                      <Status
                        value={check?.registration_status ?? "not_recorded"}
                      />
                      <small>{check?.registration_number}</small>
                    </td>
                    <td>
                      <Status
                        value={
                          check?.recruitment_complete
                            ? "complete"
                            : "incomplete"
                        }
                      />
                    </td>
                    <td>
                      <button
                        className="btn small"
                        onClick={() => {
                          setEditing(check);
                          setModal("check");
                        }}
                      >
                        {check ? "Edit" : "Add checks"}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <Empty text="Add employees to begin safer-recruitment checks" />
        ))}
      {tab === "training" &&
        ((training.data ?? []).length ? (
          <>
            <p className="muted">
              {expiring.length} training record(s) expired or due within 90
              days.
            </p>
            <div className="table-card">
              <table>
                <thead>
                  <tr>
                    <th>Employee</th>
                    <th>Course</th>
                    <th>Completed</th>
                    <th>Expires</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {(training.data ?? []).map((row) => {
                    const expired =
                      row.expires_at && new Date(row.expires_at) < new Date();
                    return (
                      <tr key={row.id}>
                        <td>{row.employee?.full_name}</td>
                        <td>
                          <strong>{row.course?.name}</strong>
                          <small>{row.course?.category}</small>
                        </td>
                        <td>
                          {row.completed_at
                            ? new Date(row.completed_at).toLocaleDateString(
                                "en-GB",
                              )
                            : "—"}
                        </td>
                        <td>
                          {row.expires_at
                            ? new Date(row.expires_at).toLocaleDateString(
                                "en-GB",
                              )
                            : "No expiry"}
                        </td>
                        <td>
                          <Status value={expired ? "expired" : row.status} />
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </>
        ) : (
          <Empty text="No employee training records yet" />
        ))}
      {tab === "services" &&
        ((services.data ?? []).length ? (
          <div className="table-card">
            <table>
              <thead>
                <tr>
                  <th>Service</th>
                  <th>Duration</th>
                  <th>Travel</th>
                  <th>Staff</th>
                  <th>Tasks</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {(services.data ?? []).map((row) => (
                  <tr key={row.id}>
                    <td>
                      <strong>{row.name}</strong>
                      <small>{row.category}</small>
                    </td>
                    <td>{row.default_duration_minutes} min</td>
                    <td>{row.default_travel_minutes} min</td>
                    <td>{row.minimum_staff}</td>
                    <td>{row.task_template?.length ?? 0}</td>
                    <td>
                      <Status value={row.status} />
                    </td>
                    <td>
                      <button
                        className="btn small"
                        onClick={() => {
                          setEditing(row);
                          setModal("service");
                        }}
                      >
                        Edit
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <Empty text="No service types configured" />
        ))}
      {modal === "check" && (
        <Modal
          title={editing ? "Edit workforce checks" : "Add workforce checks"}
          onClose={() => setModal(null)}
        >
          <CheckForm
            employees={activeEmployees.filter(
              (employee) => editing || !checkByEmployee.has(employee.id),
            )}
            record={editing}
            onClose={() => setModal(null)}
          />
        </Modal>
      )}
      {modal === "training" && (
        <Modal title="Assign training" onClose={() => setModal(null)}>
          <TrainingForm
            employees={activeEmployees}
            courses={(courses.data ?? []).filter(
              (row) => row.status === "active",
            )}
            onClose={() => setModal(null)}
          />
        </Modal>
      )}
      {modal === "service" && (
        <Modal
          title={editing ? "Edit service" : "Add service"}
          onClose={() => setModal(null)}
        >
          <ServiceForm record={editing} onClose={() => setModal(null)} />
        </Modal>
      )}
    </>
  );
}
