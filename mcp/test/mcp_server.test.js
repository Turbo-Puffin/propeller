// End-to-end MCP server tests: spin up an in-memory client/server pair,
// exercise tools/list + tools/call to confirm the wiring is correct.

import { test } from "node:test";
import assert from "node:assert/strict";
import { makeTestClient, connectInMemoryMcp, parseToolResult } from "./_helpers.js";

const EXPECTED_TOOLS = [
  "propeller__create_contact",
  "propeller__update_contact",
  "propeller__list_contacts",
  "propeller__get_contact",
  "propeller__create_list",
  "propeller__list_lists",
  "propeller__add_contacts_to_list",
  "propeller__create_segment",
  "propeller__list_segments",
  "propeller__create_campaign",
  "propeller__schedule_campaign",
  "propeller__cancel_campaign",
  "propeller__list_campaigns",
  "propeller__get_send_metrics",
  "propeller__create_template",
  "propeller__list_templates",
];

test("tools/list returns every documented tool with a JSON schema", async () => {
  const { client } = makeTestClient([]);
  const { mcpClient, server } = await connectInMemoryMcp(client);
  try {
    const { tools } = await mcpClient.listTools();
    const names = tools.map((t) => t.name).sort();
    assert.deepEqual(names, [...EXPECTED_TOOLS].sort());

    for (const tool of tools) {
      assert.ok(tool.description, `${tool.name} should have a description`);
      assert.ok(tool.inputSchema, `${tool.name} should have an inputSchema`);
      assert.equal(tool.inputSchema.type, "object");
    }
  } finally {
    await server.close();
  }
});

test("tools/call propeller__create_contact returns structured contact result", async () => {
  const { client, calls } = makeTestClient([
    {
      status: 201,
      body: { data: { id: "c_1", email: "ada@example.com", status: "subscribed" } },
    },
  ]);
  const { mcpClient, server } = await connectInMemoryMcp(client);
  try {
    const result = await mcpClient.callTool({
      name: "propeller__create_contact",
      arguments: { email: "ada@example.com" },
    });
    assert.equal(result.isError, undefined);
    const payload = parseToolResult(result);
    assert.deepEqual(payload, { id: "c_1", email: "ada@example.com", status: "subscribed" });
    assert.equal(calls[0].url, "https://propeller.test/api/v1/contacts");
  } finally {
    await server.close();
  }
});

test("tools/call surfaces 401 from the API as a structured MCP error, not a crash", async () => {
  const { client } = makeTestClient([
    {
      status: 401,
      body: { error: { code: "invalid_token", message: "Invalid API key" } },
    },
  ]);
  const { mcpClient, server } = await connectInMemoryMcp(client);
  try {
    const result = await mcpClient.callTool({
      name: "propeller__list_contacts",
      arguments: {},
    });
    assert.equal(result.isError, true);
    const payload = parseToolResult(result);
    assert.equal(payload.error.code, "invalid_token");
    assert.equal(payload.error.status, 401);
  } finally {
    await server.close();
  }
});

test("tools/call surfaces 404 from the API as a structured MCP error", async () => {
  const { client } = makeTestClient([
    {
      status: 404,
      body: { error: { code: "not_found", message: "Resource not found" } },
    },
  ]);
  const { mcpClient, server } = await connectInMemoryMcp(client);
  try {
    const result = await mcpClient.callTool({
      name: "propeller__get_contact",
      arguments: { contact_id: "missing" },
    });
    assert.equal(result.isError, true);
    const payload = parseToolResult(result);
    assert.equal(payload.error.code, "not_found");
    assert.equal(payload.error.status, 404);
  } finally {
    await server.close();
  }
});

test("tools/call surfaces 500 from the API without crashing the transport", async () => {
  const { client } = makeTestClient([
    { status: 500, body: "<html>upstream error</html>" },
  ]);
  const { mcpClient, server } = await connectInMemoryMcp(client);
  try {
    const result = await mcpClient.callTool({
      name: "propeller__list_lists",
      arguments: {},
    });
    assert.equal(result.isError, true);
    const payload = parseToolResult(result);
    assert.equal(payload.error.status, 500);
  } finally {
    await server.close();
  }
});

test("tools/call propeller__get_send_metrics returns zero metrics in pending pipeline", async () => {
  const { client, calls } = makeTestClient([]);
  const { mcpClient, server } = await connectInMemoryMcp(client);
  try {
    const result = await mcpClient.callTool({
      name: "propeller__get_send_metrics",
      arguments: { campaign_id: "cmp_1" },
    });
    assert.equal(result.isError, undefined);
    const payload = parseToolResult(result);
    assert.equal(payload.metrics.sent, 0);
    assert.equal(payload.not_supported, true);
    assert.equal(calls.length, 0, "should not call the API");
  } finally {
    await server.close();
  }
});
