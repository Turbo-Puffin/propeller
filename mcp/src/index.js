#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { buildServer, buildClientFromEnv } from "./server.js";

async function main() {
  let client;
  try {
    client = buildClientFromEnv();
  } catch (err) {
    process.stderr.write(`[propeller-mcp] ${err.message}\n`);
    process.exit(1);
  }

  const server = buildServer({ client });
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  process.stderr.write(`[propeller-mcp] fatal: ${err?.stack || err}\n`);
  process.exit(1);
});
