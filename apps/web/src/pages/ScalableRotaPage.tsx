import { useMemo, useState } from "react";
import {
  AlertTriangle,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Route,
  Search,
  UsersRound,
} from "lucide-react";
import {
  DataError,
  Empty,
  Loading,
  Modal,
  PageHeader,
  Status,
} from "@/components/ui";
import { type Row, useRows } from "@/lib/data";
import {
  ScheduleVisit,
  Timeline,
  VisitDetails,
} from "@/pages/TimelineRotaPage";

const DAY_START = 5 * 60;
const SLOT_MINUTES = 30;
const SLOT_COUNT = 36;
const slots = Array.from(
  { length: SLOT_COUNT },
  (_, index) => DAY_START + index * SLOT_MINUTES,
);
const dateKey = (value: Date | string) =>
  new Date(value).toLocaleDateString("en-CA");
const time = (value: string) =>
  new Date(value).toLocaleTimeString("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
  });
const duration = (visit: Row) =>
  Math.round(
    (new Date(visit.ends_at).getTime() - new Date(visit.starts_at).getTime()) /
      60000,
  );
const allocations = (visit: Row) =>
  visit.assignments?.length
    ? [...visit.assignments].sort(
        (a: Row, b: Row) => a.assignment_slot - b.assignment_slot,
      )
    : visit.employee_id
      ? [
          {
            assignment_slot: 1,
            employee_id: visit.employee_id,
            employee: visit.employee,
          },
        ]
      : [];
const visitStatus = (visit: Row) =>
  visit.status === "scheduled" && new Date(visit.ends_at) < new Date()
    ? "overdue"
    : visit.status;
const slotLabel = (minutes: number) =>
  `${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`;
const isGap = (visit: Row) =>
  allocations(visit).length < Number(visit.required_carers ?? 1);

type GroupBy = "employees" | "service_users";
type StatusFilter =
  "all" | "scheduled" | "in_progress" | "completed" | "exceptions";

function ServiceUserTimeline({
  visits,
  people,
  onOpen,
}: {
  visits: Row[];
  people: Row[];
  onOpen: (id: string) => void;
}) {
  const rowsFor = (personId: string) =>
    visits.filter((visit) => visit.service_user_id === personId);
  const visiblePeople = people.filter(
    (person) => rowsFor(person.id).length > 0,
  );
  const place = (visit: Row) => {
    const start = new Date(visit.starts_at);
    const startMinute = start.getHours() * 60 + start.getMinutes();
    const column = Math.max(
      0,
      Math.min(
        SLOT_COUNT - 1,
        Math.floor((startMinute - DAY_START) / SLOT_MINUTES),
      ),
    );
    const span = Math.max(
      1,
      Math.min(SLOT_COUNT - column, Math.ceil(duration(visit) / SLOT_MINUTES)),
    );
    return { column, span };
  };
  const lanes = (rows: Row[]) => {
    const ends: number[] = [];
    return rows.map((visit) => {
      const start = new Date(visit.starts_at).getTime();
      let lane = ends.findIndex((end) => end <= start);
      if (lane < 0) lane = ends.length;
      ends[lane] = new Date(visit.ends_at).getTime();
      return { visit, lane };
    });
  };

  if (!visiblePeople.length)
    return (
      <section className="timeline-panel">
        <Empty text="No service-user visits match these filters" />
      </section>
    );

  return (
    <section className="timeline-panel service-user-timeline">
      <header>
        <div>
          <h2>Service-user schedule</h2>
          <p>
            One row per person, with every visit shown at its scheduled time.
          </p>
        </div>
        <span>
          {visiblePeople.length} people · {visits.length} visits
        </span>
      </header>
      <div className="timeline-scroll">
        <div className="timeline-grid">
          <div className="timeline-header">
            <div className="timeline-person">
              <strong>Service user</strong>
            </div>
            {slots.map((value, index) => (
              <div
                key={value}
                className={index % 2 ? "half-hour" : "hour"}
                style={{ gridColumn: index + 2 }}
              >
                <strong>{index % 2 ? "" : slotLabel(value)}</strong>
                <small>{index % 2 ? slotLabel(value) : ""}</small>
              </div>
            ))}
          </div>
          {visiblePeople.map((person) => {
            const rows = rowsFor(person.id);
            const layout = lanes(rows);
            const laneCount = Math.max(
              1,
              ...layout.map((item) => item.lane + 1),
            );
            return (
              <div
                key={person.id}
                className="timeline-row"
                style={{ gridTemplateRows: `repeat(${laneCount},72px)` }}
              >
                <div
                  className="timeline-person"
                  style={{ gridRow: `1 / span ${laneCount}` }}
                >
                  <span className="service-user-initial">
                    {person.full_name?.charAt(0)}
                  </span>
                  <div>
                    <strong>{person.full_name}</strong>
                    <small>
                      {rows.length} visit{rows.length === 1 ? "" : "s"} ·{" "}
                      {Math.round(
                        rows.reduce((sum, row) => sum + duration(row), 0) / 6,
                      ) / 10}
                      h care
                    </small>
                  </div>
                </div>
                {slots.map((_, index) => (
                  <div
                    key={index}
                    className={`timeline-cell ${index % 2 ? "half-hour" : "hour"}`}
                    style={{
                      gridColumn: index + 2,
                      gridRow: `1 / span ${laneCount}`,
                    }}
                  />
                ))}
                {layout.map(({ visit, lane }) => {
                  const position = place(visit);
                  const carers =
                    allocations(visit)
                      .map((row: Row) => row.employee?.full_name)
                      .filter(Boolean)
                      .join(" + ") || "Unassigned";
                  return (
                    <button
                      key={visit.id}
                      onClick={() => onOpen(visit.id)}
                      className={`timeline-visit ${visitStatus(visit)} ${isGap(visit) ? "understaffed" : ""}`}
                      style={{
                        gridColumn: `${position.column + 2} / span ${position.span}`,
                        gridRow: lane + 1,
                      }}
                    >
                      <span>
                        <strong>
                          {time(visit.starts_at)}–{time(visit.ends_at)}
                        </strong>
                        <small>{visit.visit_type}</small>
                        <em>{carers}</em>
                      </span>
                      <Status value={visitStatus(visit)} />
                    </button>
                  );
                })}
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}

export function ScalableRotaPage() {
  const visits = useRows("visits", "starts_at", true);
  const employees = useRows("employees", "full_name", true);
  const people = useRows("service_users", "full_name", true);
  const areas = useRows("operational_areas", "name", true);
  const [selectedDate, setSelectedDate] = useState(dateKey(new Date()));
  const [view, setView] = useState<"dispatch" | "week">("dispatch");
  const [groupBy, setGroupBy] = useState<GroupBy>("employees");
  const [area, setArea] = useState("all");
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [gapsOnly, setGapsOnly] = useState(false);
  const [createAt, setCreateAt] = useState<Date | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const activeEmployees =
    employees.data?.filter(
      (row) =>
        row.status === "active" && (area === "all" || row.area_id === area),
    ) ?? [];
  const activePeople =
    people.data?.filter(
      (row) =>
        row.status === "active" && (area === "all" || row.area_id === area),
    ) ?? [];
  const selected = visits.data?.find((row) => row.id === selectedId);
  const allDayVisits = useMemo(
    () =>
      (visits.data ?? [])
        .filter(
          (row) =>
            dateKey(row.starts_at) === selectedDate &&
            (area === "all" || row.area_id === area),
        )
        .sort(
          (a, b) =>
            new Date(a.starts_at).getTime() - new Date(b.starts_at).getTime(),
        ),
    [visits.data, selectedDate, area],
  );
  const normalisedQuery = query.trim().toLowerCase();
  const matchesSearch = (visit: Row) => {
    if (!normalisedQuery) return true;
    const carerNames = allocations(visit)
      .map((row: Row) => row.employee?.full_name)
      .join(" ");
    return `${visit.service_user?.full_name ?? ""} ${visit.visit_type ?? ""} ${carerNames}`
      .toLowerCase()
      .includes(normalisedQuery);
  };
  const matchesStatus = (visit: Row) => {
    const status = visitStatus(visit);
    if (statusFilter === "all") return true;
    if (statusFilter === "exceptions")
      return status === "overdue" || status === "missed" || isGap(visit);
    return status === statusFilter;
  };
  const filteredDayVisits = allDayVisits.filter(
    (visit) =>
      matchesSearch(visit) &&
      matchesStatus(visit) &&
      (!gapsOnly || isGap(visit)),
  );
  const relevantEmployeeIds = new Set(
    filteredDayVisits.flatMap((visit) =>
      allocations(visit).map((row: Row) => row.employee_id),
    ),
  );
  const visibleEmployees = normalisedQuery
    ? activeEmployees.filter(
        (employee) =>
          employee.full_name?.toLowerCase().includes(normalisedQuery) ||
          relevantEmployeeIds.has(employee.id),
      )
    : activeEmployees;
  const relevantPeopleIds = new Set(
    filteredDayVisits.map((visit) => visit.service_user_id),
  );
  const visiblePeople = activePeople.filter((person) =>
    relevantPeopleIds.has(person.id),
  );
  const gaps = allDayVisits.filter(isGap);
  const receivingCare = new Set(
    allDayVisits.map((visit) => visit.service_user_id),
  ).size;
  const scheduledEmployees = activeEmployees.filter((employee) =>
    allDayVisits.some((visit) =>
      allocations(visit).some((row: Row) => row.employee_id === employee.id),
    ),
  ).length;
  const date = new Date(`${selectedDate}T12:00:00`);
  const weekStart = new Date(date);
  weekStart.setDate(date.getDate() - ((date.getDay() + 6) % 7));
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekStart.getDate() + 7);
  const weekVisits = (visits.data ?? []).filter(
    (row) =>
      new Date(row.starts_at) >= weekStart &&
      new Date(row.starts_at) < weekEnd &&
      (area === "all" || row.area_id === area) &&
      matchesSearch(row) &&
      matchesStatus(row) &&
      (!gapsOnly || isGap(row)),
  );
  const moveDate = (amount: number) => {
    const next = new Date(`${selectedDate}T12:00:00`);
    next.setDate(next.getDate() + amount);
    setSelectedDate(dateKey(next));
  };
  const clearFilters = () => {
    setQuery("");
    setStatusFilter("all");
    setGapsOnly(false);
  };

  return (
    <>
      <PageHeader
        title="Rota dispatch"
        description="Operational scheduling by employee or service user, built for high-volume daily care."
        action="Schedule visit"
        onAction={() => setCreateAt(new Date(`${selectedDate}T08:00:00`))}
      />
      <div className="dispatch-controls">
        <div className="date-nav">
          <button
            aria-label="Previous"
            onClick={() => moveDate(view === "dispatch" ? -1 : -7)}
          >
            <ChevronLeft />
          </button>
          <input
            type="date"
            value={selectedDate}
            onChange={(event) => setSelectedDate(event.target.value)}
          />
          <button
            aria-label="Next"
            onClick={() => moveDate(view === "dispatch" ? 1 : 7)}
          >
            <ChevronRight />
          </button>
          <button
            className="btn small"
            onClick={() => setSelectedDate(dateKey(new Date()))}
          >
            Today
          </button>
          <strong>
            {date.toLocaleDateString("en-GB", {
              weekday: "long",
              day: "numeric",
              month: "long",
              year: "numeric",
            })}
          </strong>
        </div>
        <div className="view-toggle">
          <button
            className={view === "dispatch" ? "active" : ""}
            onClick={() => setView("dispatch")}
          >
            Daily dispatch
          </button>
          <button
            className={view === "week" ? "active" : ""}
            onClick={() => setView("week")}
          >
            Week board
          </button>
        </div>
      </div>
      <section className="dispatch-summary">
        <article>
          <Route />
          <div>
            <small>Total visits</small>
            <strong>{allDayVisits.length}</strong>
          </div>
        </article>
        <article className={gaps.length ? "warning" : ""}>
          <AlertTriangle />
          <div>
            <small>Staffing gaps</small>
            <strong>{gaps.length}</strong>
          </div>
        </article>
        <article>
          <UsersRound />
          <div>
            <small>Employees scheduled</small>
            <strong>{scheduledEmployees}</strong>
          </div>
        </article>
        <article>
          <CalendarDays />
          <div>
            <small>People receiving care</small>
            <strong>{receivingCare}</strong>
          </div>
        </article>
      </section>
      <section className="rota-filterbar">
        <div className="group-toggle" aria-label="Group rota">
          <span>Group by</span>
          <button
            className={groupBy === "employees" ? "active" : ""}
            onClick={() => setGroupBy("employees")}
          >
            Employees
          </button>
          <button
            className={groupBy === "service_users" ? "active" : ""}
            onClick={() => setGroupBy("service_users")}
          >
            Service users
          </button>
        </div>
        <select
          aria-label="Filter by operational area"
          value={area}
          onChange={(event) => setArea(event.target.value)}
        >
          <option value="all">All areas</option>
          {areas.data?.map((row) => (
            <option key={row.id} value={row.id}>
              {row.name}
            </option>
          ))}
        </select>
        <label className="rota-search">
          <Search />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search service user, employee or visit…"
          />
        </label>
        <select
          aria-label="Filter by visit status"
          value={statusFilter}
          onChange={(event) =>
            setStatusFilter(event.target.value as StatusFilter)
          }
        >
          <option value="all">All statuses</option>
          <option value="scheduled">Scheduled</option>
          <option value="in_progress">In progress</option>
          <option value="completed">Completed</option>
          <option value="exceptions">Exceptions</option>
        </select>
        <label className="gap-filter">
          <input
            type="checkbox"
            checked={gapsOnly}
            onChange={(event) => setGapsOnly(event.target.checked)}
          />{" "}
          Staffing gaps only
        </label>
        {(query || statusFilter !== "all" || gapsOnly) && (
          <button className="clear-filters" onClick={clearFilters}>
            Clear filters
          </button>
        )}
        <span className="filter-result">
          Showing{" "}
          {view === "dispatch" ? filteredDayVisits.length : weekVisits.length}{" "}
          visit
          {(view === "dispatch"
            ? filteredDayVisits.length
            : weekVisits.length) === 1
            ? ""
            : "s"}
        </span>
      </section>
      {areas.error && <div className="notice danger">Area filtering is temporarily unavailable, but the rota remains usable. {areas.error.message}. Apply all Supabase migrations to restore area filters.</div>}
      {visits.isLoading ||
      employees.isLoading ||
      people.isLoading ? (
        <Loading />
      ) : visits.error ? (
        <DataError message={visits.error.message} />
      ) : employees.error ? (
        <DataError message={employees.error.message} />
      ) : people.error ? (
        <DataError message={people.error.message} />
      ) : view === "dispatch" ? (
        groupBy === "employees" ? (
          <Timeline
            date={selectedDate}
            visits={filteredDayVisits}
            employees={visibleEmployees}
            onOpen={setSelectedId}
            onCreate={setCreateAt}
          />
        ) : (
          <ServiceUserTimeline
            visits={filteredDayVisits}
            people={visiblePeople}
            onOpen={setSelectedId}
          />
        )
      ) : (
        <div className="week-grid">
          {["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map(
            (day, index) => {
              const current = new Date(weekStart);
              current.setDate(weekStart.getDate() + index);
              const rows = weekVisits.filter(
                (row) => dateKey(row.starts_at) === dateKey(current),
              );
              return (
                <section key={day}>
                  <header>
                    {day}
                    <strong>{current.getDate()}</strong>
                  </header>
                  {rows.map((visit) => (
                    <article
                      key={visit.id}
                      className={`visit-block ${visitStatus(visit)}`}
                      onClick={() => setSelectedId(visit.id)}
                    >
                      <small>
                        {time(visit.starts_at)} · {duration(visit)} min
                      </small>
                      <strong>{visit.service_user?.full_name}</strong>
                      <span>{visit.visit_type}</span>
                      <em>
                        {allocations(visit)
                          .map((row: Row) => row.employee?.full_name)
                          .filter(Boolean)
                          .join(" + ") || "Unassigned"}
                      </em>
                    </article>
                  ))}
                </section>
              );
            },
          )}
        </div>
      )}
      {createAt && (
        <Modal title="Schedule visit" onClose={() => setCreateAt(null)}>
          <ScheduleVisit
            people={activePeople}
            employees={activeEmployees}
            initialStart={createAt}
            onClose={() => setCreateAt(null)}
          />
        </Modal>
      )}
      {selected && (
        <VisitDetails
          visit={selected}
          employees={activeEmployees}
          onClose={() => setSelectedId(null)}
        />
      )}
    </>
  );
}
