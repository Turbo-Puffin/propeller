import { test } from "node:test";
import assert from "node:assert/strict";
import { PropellerClient, PropellerApiError } from "../src/client.js";
import { makeFakeFetch } from "./_helpers.js";

test("PropellerClient sends Bearer auth and JSON content type", async () => {
  const { fetchImpl, calls } = makeFakeFetch([
    { status: 200, body: { data: { id: "c_1" } } },
  ]);
  const client = new PropellerClient({
    apiKey: "pk_test",
    apiUrl: "https://propeller.test",
    fetchImpl,
  });

  await client.post("/api/v1/contacts", { contact: { email: "a@b.com" } });

  const call = calls[0];
  assert.equal(call.url, "https://propeller.test/api/v1/contacts");
  assert.equal(call.init.method, "POST");
  assert.equal(call.init.headers.Authorization, "Bearer pk_test");
  assert.equal(call.init.headers["Content-Type"], "application/json");
  assert.equal(call.init.headers.Accept, "application/json");
  assert.match(call.init.headers["User-Agent"], /^propeller-mcp\//);
  assert.deepEqual(JSON.parse(call.init.body), { contact: { email: "a@b.com" } });
});

test("PropellerClient appends query string and skips blank params", async () => {
  const { fetchImpl, calls } = makeFakeFetch([{ status: 200, body: { data: [] } }]);
  const client = new PropellerClient({
    apiKey: "pk_test",
    apiUrl: "https://propeller.test",
    fetchImpl,
  });

  await client.get("/api/v1/campaigns", { status: "scheduled", page: undefined, per_page: 10 });

  assert.equal(
    calls[0].url,
    "https://propeller.test/api/v1/campaigns?status=scheduled&per_page=10",
  );
});

test("PropellerClient strips trailing slash from apiUrl", () => {
  const client = new PropellerClient({
    apiKey: "pk_test",
    apiUrl: "https://propeller.test/",
    fetchImpl: () => {},
  });
  assert.equal(client.apiUrl, "https://propeller.test");
});

test("PropellerClient surfaces structured API errors", async () => {
  const { fetchImpl } = makeFakeFetch([
    {
      status: 422,
      body: {
        error: {
          code: "validation_failed",
          message: "Email has already been taken",
          fields: { email: ["has already been taken"] },
        },
      },
      headers: { "x-request-id": "req_42" },
    },
  ]);
  const client = new PropellerClient({
    apiKey: "pk_test",
    apiUrl: "https://propeller.test",
    fetchImpl,
  });

  await assert.rejects(
    () => client.post("/api/v1/contacts", { contact: { email: "dup@b.com" } }),
    (err) => {
      assert.ok(err instanceof PropellerApiError);
      assert.equal(err.status, 422);
      assert.equal(err.code, "validation_failed");
      assert.deepEqual(err.fields, { email: ["has already been taken"] });
      assert.equal(err.requestId, "req_42");
      return true;
    },
  );
});

test("PropellerClient wraps network errors as PropellerApiError", async () => {
  const client = new PropellerClient({
    apiKey: "pk_test",
    apiUrl: "https://propeller.test",
    fetchImpl: async () => {
      throw new Error("ECONNREFUSED");
    },
  });

  await assert.rejects(
    () => client.get("/api/v1/contacts"),
    (err) => {
      assert.ok(err instanceof PropellerApiError);
      assert.equal(err.code, "network_error");
      assert.match(err.message, /ECONNREFUSED/);
      return true;
    },
  );
});

test("PropellerClient handles 204 No Content cleanly", async () => {
  const { fetchImpl } = makeFakeFetch([
    { status: 204, body: "", headers: { "x-request-id": "req_99" } },
  ]);
  const client = new PropellerClient({
    apiKey: "pk_test",
    apiUrl: "https://propeller.test",
    fetchImpl,
  });

  const result = await client.delete("/api/v1/lists/list_1/contacts/c_1");
  assert.deepEqual(result, { ok: true, requestId: "req_99" });
});

test("PropellerClient requires an API key", () => {
  assert.throws(() => new PropellerClient({ fetchImpl: () => {} }), /PROPELLER_API_KEY/);
});
