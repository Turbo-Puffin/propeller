// Test helpers: build a fake fetch that records calls, plus an in-memory MCP
// client/server pair driven by the same plumbing as a real MCP connection.

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { PropellerClient } from "../src/client.js";
import { buildServer } from "../src/server.js";

export function makeFakeFetch(responses) {
  // `responses` is an array of objects describing each expected request:
  //   { status, body, headers? }
  // or a function (url, init) => response-like.
  const queue = Array.isArray(responses) ? [...responses] : null;
  const calls = [];

  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    let spec;
    if (typeof responses === "function") {
      spec = await responses(url, init);
    } else {
      if (!queue.length) {
        throw new Error(`Unexpected fetch call: ${init?.method || "GET"} ${url}`);
      }
      spec = queue.shift();
    }
    const status = spec.status ?? 200;
    const body = spec.body === undefined ? "" : typeof spec.body === "string" ? spec.body : JSON.stringify(spec.body);
    return {
      ok: status >= 200 && status < 300,
      status,
      headers: new Headers(spec.headers || {}),
      async text() {
        return body;
      },
    };
  };

  return { fetchImpl, calls };
}

export function makeTestClient(responses) {
  const { fetchImpl, calls } = makeFakeFetch(responses);
  const client = new PropellerClient({
    apiKey: "pk_test_abc",
    apiUrl: "https://propeller.test",
    fetchImpl,
    version: "test",
  });
  return { client, calls };
}

export async function connectInMemoryMcp(propellerClient) {
  const server = buildServer({ client: propellerClient });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();

  const mcpClient = new Client(
    { name: "propeller-mcp-tests", version: "0.0.0" },
    { capabilities: {} },
  );

  await Promise.all([
    server.connect(serverTransport),
    mcpClient.connect(clientTransport),
  ]);

  return { mcpClient, server };
}

export function parseToolResult(result) {
  // McpServer wraps handler output in a content array with the JSON as text.
  const text = result?.content?.[0]?.text;
  if (!text) return null;
  return JSON.parse(text);
}
