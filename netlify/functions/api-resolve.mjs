import { getStore } from "@netlify/blobs";

const STORE_NAME = "incidents";

async function getIncidentsStore() {
  return getStore(STORE_NAME);
}

export default async (req) => {
  if (req.method !== "PATCH") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const url = new URL(req.url);
  const id = url.searchParams.get("id");

  if (!id) {
    return new Response(JSON.stringify({ error: "incident id is required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const store = await getIncidentsStore();
  const key = `incident-${id}`;
  const data = await store.get(key);

  if (!data) {
    return new Response(JSON.stringify({ error: "incident not found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  let incident;
  try {
    incident = JSON.parse(data);
  } catch {
    return new Response(JSON.stringify({ error: "invalid incident data" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (incident.status !== "open") {
    return new Response(JSON.stringify({ error: "incident not found or already resolved" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  incident.status = "resolved";
  incident.resolved_at = new Date().toISOString();

  await store.set(key, JSON.stringify(incident));

  return new Response(JSON.stringify(incident), {
    headers: { "Content-Type": "application/json" },
  });
};
