import { getStore } from "@netlify/blobs";

const STORE_NAME = "incidents";
const COUNTER_KEY = "_counter";

async function getIncidentsStore() {
  return getStore(STORE_NAME);
}

async function getAllIncidents(store) {
  const { blobs } = await store.list();
  const incidents = [];
  for (const blob of blobs) {
    if (blob.key === COUNTER_KEY) continue;
    const data = await store.get(blob.key);
    if (data) {
      try {
        incidents.push(JSON.parse(data));
      } catch {
        // skip invalid entries
      }
    }
  }
  return incidents;
}

export default async (req) => {
  if (req.method !== "GET") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const store = await getIncidentsStore();
  const incidents = await getAllIncidents(store);

  const bySeverity = { P1: 0, P2: 0, P3: 0, P4: 0 };
  let openCount = 0;
  let resolvedCount = 0;

  for (const incident of incidents) {
    if (incident.status === "open") {
      openCount++;
      if (bySeverity[incident.severity] !== undefined) {
        bySeverity[incident.severity]++;
      }
    } else if (incident.status === "resolved") {
      resolvedCount++;
    }
  }

  return new Response(
    JSON.stringify({
      open: openCount,
      resolved: resolvedCount,
      severity: bySeverity,
    }),
    { headers: { "Content-Type": "application/json" } }
  );
};
