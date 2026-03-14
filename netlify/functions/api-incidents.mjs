import { getStore } from "@netlify/blobs";

const STORE_NAME = "incidents";
const COUNTER_KEY = "_counter";

async function getIncidentsStore() {
  return getStore(STORE_NAME);
}

async function getNextId(store) {
  const counterData = await store.get(COUNTER_KEY);
  const nextId = counterData ? parseInt(counterData, 10) + 1 : 1;
  await store.set(COUNTER_KEY, String(nextId));
  return nextId;
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
  // Sort by id descending
  incidents.sort((a, b) => b.id - a.id);
  return incidents;
}

export default async (req) => {
  const store = await getIncidentsStore();
  const url = new URL(req.url);

  if (req.method === "GET") {
    const status = url.searchParams.get("status") || "open";
    if (!["open", "resolved", "all"].includes(status)) {
      return new Response(JSON.stringify({ error: "status must be open, resolved, or all" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const incidents = await getAllIncidents(store);
    const filtered = status === "all" ? incidents : incidents.filter((i) => i.status === status);

    return new Response(JSON.stringify(filtered), {
      headers: { "Content-Type": "application/json" },
    });
  }

  if (req.method === "POST") {
    let payload;
    try {
      payload = await req.json();
    } catch {
      return new Response(JSON.stringify({ error: "Invalid JSON" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const service = (payload.service || "").trim();
    const title = (payload.title || "").trim();
    const severity = (payload.severity || "").trim().toUpperCase();
    const description = (payload.description || "").trim();

    if (!service || !title) {
      return new Response(JSON.stringify({ error: "service and title are required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const validSeverities = ["P1", "P2", "P3", "P4"];
    if (!validSeverities.includes(severity)) {
      return new Response(JSON.stringify({ error: "severity must be one of P1, P2, P3, P4" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const id = await getNextId(store);
    const incident = {
      id,
      service,
      title,
      severity,
      description,
      status: "open",
      created_at: new Date().toISOString(),
      resolved_at: null,
    };

    await store.set(`incident-${id}`, JSON.stringify(incident));

    return new Response(JSON.stringify(incident), {
      status: 201,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ error: "Method not allowed" }), {
    status: 405,
    headers: { "Content-Type": "application/json" },
  });
};
