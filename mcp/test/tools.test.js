// Per-tool unit tests: mock fetch, assert the right HTTP call shape goes out and
// the right structured payload comes back to the agent.

import { test } from "node:test";
import assert from "node:assert/strict";
import { getToolDefinitions } from "../src/tools/index.js";
import { makeTestClient } from "./_helpers.js";

function getTool(name) {
  const tool = getToolDefinitions().find((t) => t.name === name);
  if (!tool) throw new Error(`Tool not registered: ${name}`);
  return tool;
}

test("propeller__create_contact POSTs to /api/v1/contacts and returns the contact", async () => {
  const { client, calls } = makeTestClient([
    {
      status: 201,
      body: { data: { id: "c_1", email: "a@b.com", status: "subscribed" } },
    },
  ]);

  const tool = getTool("propeller__create_contact");
  const result = await tool.handler(
    { email: "a@b.com", first_name: "Ada", metadata: { source: "agent" } },
    { client },
  );

  assert.equal(calls.length, 1);
  assert.equal(calls[0].init.method, "POST");
  assert.equal(calls[0].url, "https://propeller.test/api/v1/contacts");
  assert.deepEqual(JSON.parse(calls[0].init.body), {
    contact: { email: "a@b.com", first_name: "Ada", metadata: { source: "agent" } },
  });
  assert.deepEqual(result, { id: "c_1", email: "a@b.com", status: "subscribed" });
});

test("propeller__update_contact PATCHes /api/v1/contacts/:id without the id in the body", async () => {
  const { client, calls } = makeTestClient([
    { status: 200, body: { data: { id: "c_1", email: "new@b.com" } } },
  ]);

  const tool = getTool("propeller__update_contact");
  await tool.handler({ contact_id: "c_1", email: "new@b.com" }, { client });

  assert.equal(calls[0].init.method, "PATCH");
  assert.equal(calls[0].url, "https://propeller.test/api/v1/contacts/c_1");
  assert.deepEqual(JSON.parse(calls[0].init.body), { contact: { email: "new@b.com" } });
});

test("propeller__list_contacts pages via querystring", async () => {
  const { client, calls } = makeTestClient([
    { status: 200, body: { data: [{ id: "c_1" }], meta: { page: 2, per_page: 10 } } },
  ]);

  const tool = getTool("propeller__list_contacts");
  const result = await tool.handler({ page: 2, per_page: 10 }, { client });

  assert.equal(calls[0].init.method, "GET");
  assert.equal(calls[0].url, "https://propeller.test/api/v1/contacts?page=2&per_page=10");
  assert.deepEqual(result, { contacts: [{ id: "c_1" }], meta: { page: 2, per_page: 10 } });
});

test("propeller__get_contact GETs /api/v1/contacts/:id", async () => {
  const { client, calls } = makeTestClient([
    { status: 200, body: { data: { id: "c_1", email: "a@b.com" } } },
  ]);

  const tool = getTool("propeller__get_contact");
  const result = await tool.handler({ contact_id: "c_1" }, { client });

  assert.equal(calls[0].url, "https://propeller.test/api/v1/contacts/c_1");
  assert.deepEqual(result, { id: "c_1", email: "a@b.com" });
});

test("propeller__create_list POSTs to /api/v1/lists", async () => {
  const { client, calls } = makeTestClient([
    { status: 201, body: { data: { id: "l_1", name: "Newsletter" } } },
  ]);

  const tool = getTool("propeller__create_list");
  await tool.handler({ name: "Newsletter", description: "Weekly" }, { client });

  assert.deepEqual(JSON.parse(calls[0].init.body), {
    list: { name: "Newsletter", description: "Weekly" },
  });
});

test("propeller__list_lists returns list array", async () => {
  const { client } = makeTestClient([
    { status: 200, body: { data: [{ id: "l_1" }, { id: "l_2" }], meta: { total: 2 } } },
  ]);

  const tool = getTool("propeller__list_lists");
  const result = await tool.handler({}, { client });
  assert.equal(result.lists.length, 2);
  assert.equal(result.meta.total, 2);
});

test("propeller__add_contacts_to_list adds each contact and reports per-contact result", async () => {
  const { client, calls } = makeTestClient([
    { status: 201, body: { data: { id: "l_1" } } },
    {
      status: 404,
      body: { error: { code: "not_found", message: "Resource not found" } },
    },
    { status: 201, body: { data: { id: "l_1" } } },
  ]);

  const tool = getTool("propeller__add_contacts_to_list");
  const result = await tool.handler(
    { list_id: "l_1", contact_ids: ["c_1", "c_missing", "c_3"] },
    { client },
  );

  assert.equal(calls.length, 3);
  for (const call of calls) {
    assert.equal(call.url, "https://propeller.test/api/v1/lists/l_1/contacts");
    assert.equal(call.init.method, "POST");
  }
  assert.equal(result.added, 2);
  assert.equal(result.failed, 1);
  assert.equal(result.results[1].ok, false);
  assert.equal(result.results[1].error.code, "not_found");
});

test("propeller__create_campaign maps html_body/plain_body to body_html/body_text", async () => {
  const { client, calls } = makeTestClient([
    {
      status: 201,
      body: { data: { id: "cmp_1", subject: "Hi", status: "draft" } },
    },
  ]);

  const tool = getTool("propeller__create_campaign");
  const result = await tool.handler(
    {
      subject: "Hi",
      html_body: "<p>Hi</p>",
      plain_body: "Hi",
      from_name: "Ada",
      from_email: "ada@example.com",
    },
    { client },
  );

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, "https://propeller.test/api/v1/campaigns");
  assert.deepEqual(JSON.parse(calls[0].init.body), {
    campaign: {
      name: "Hi",
      subject: "Hi",
      from_name: "Ada",
      from_email: "ada@example.com",
      body_html: "<p>Hi</p>",
      body_text: "Hi",
    },
  });
  assert.equal(result.campaign.id, "cmp_1");
});

test("propeller__create_campaign with scheduled_at chains schedule call and notes pending pipeline", async () => {
  const { client, calls } = makeTestClient([
    { status: 201, body: { data: { id: "cmp_1", status: "draft" } } },
    { status: 200, body: { data: { id: "cmp_1", status: "scheduled" } } },
  ]);

  const tool = getTool("propeller__create_campaign");
  const result = await tool.handler(
    {
      subject: "Hi",
      html_body: "<p>Hi</p>",
      plain_body: "Hi",
      scheduled_at: "2030-01-01T12:00:00Z",
    },
    { client },
  );

  assert.equal(calls.length, 2);
  assert.equal(calls[1].url, "https://propeller.test/api/v1/campaigns/cmp_1/schedule");
  assert.deepEqual(JSON.parse(calls[1].init.body), { scheduled_at: "2030-01-01T12:00:00Z" });
  assert.equal(result.campaign.status, "scheduled");
  assert.match(result.note, /HON-352/);
});

test("propeller__schedule_campaign hits schedule endpoint with note", async () => {
  const { client, calls } = makeTestClient([
    { status: 200, body: { data: { id: "cmp_1", status: "scheduled" } } },
  ]);

  const tool = getTool("propeller__schedule_campaign");
  const result = await tool.handler(
    { campaign_id: "cmp_1", scheduled_at: "2030-01-01T12:00:00Z" },
    { client },
  );

  assert.equal(calls[0].url, "https://propeller.test/api/v1/campaigns/cmp_1/schedule");
  assert.equal(result.campaign.status, "scheduled");
  assert.match(result.note, /HON-352/);
});

test("propeller__cancel_campaign hits cancel endpoint", async () => {
  const { client, calls } = makeTestClient([
    { status: 200, body: { data: { id: "cmp_1", status: "draft" } } },
  ]);

  const tool = getTool("propeller__cancel_campaign");
  await tool.handler({ campaign_id: "cmp_1" }, { client });
  assert.equal(calls[0].url, "https://propeller.test/api/v1/campaigns/cmp_1/cancel");
  assert.equal(calls[0].init.method, "POST");
});

test("propeller__list_campaigns passes status filter", async () => {
  const { client, calls } = makeTestClient([
    { status: 200, body: { data: [], meta: { total: 0 } } },
  ]);

  const tool = getTool("propeller__list_campaigns");
  await tool.handler({ status: "scheduled" }, { client });
  assert.equal(
    calls[0].url,
    "https://propeller.test/api/v1/campaigns?status=scheduled",
  );
});

test("propeller__get_send_metrics returns zeros without hitting API (pending pipeline)", async () => {
  const { client, calls } = makeTestClient([]);
  const tool = getTool("propeller__get_send_metrics");
  const result = await tool.handler({ campaign_id: "cmp_1" }, { client });
  assert.equal(calls.length, 0);
  assert.equal(result.campaign_id, "cmp_1");
  assert.deepEqual(result.metrics, {
    sent: 0,
    opened: 0,
    clicked: 0,
    bounced: 0,
    complained: 0,
  });
  assert.equal(result.not_supported, true);
});

test("pending tools return not_supported status without making API calls", async () => {
  const { client, calls } = makeTestClient([]);
  const pendingTools = [
    ["propeller__create_segment", { list_id: "l_1", name: "Whales", rules: {} }],
    ["propeller__list_segments", { list_id: "l_1" }],
    ["propeller__create_template", { name: "Welcome", html: "<p>", plain: "p" }],
    ["propeller__list_templates", {}],
  ];

  for (const [name, args] of pendingTools) {
    const tool = getTool(name);
    const result = await tool.handler(args, { client });
    assert.equal(result.not_supported, true, `${name} should report not_supported`);
    assert.ok(result.reason, `${name} should include a reason`);
  }
  assert.equal(calls.length, 0, "pending tools must not hit the API");
});
