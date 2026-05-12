import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { PropellerClient, PropellerApiError } from "./client.js";
import { getToolDefinitions } from "./tools/index.js";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

function loadPackageVersion() {
  try {
    const pkg = JSON.parse(readFileSync(join(__dirname, "..", "package.json"), "utf8"));
    return pkg.version || "0.0.0";
  } catch {
    return "0.0.0";
  }
}

export function buildServer({ client } = {}) {
  if (!client) {
    throw new Error("buildServer requires a Propeller API client.");
  }

  const version = loadPackageVersion();
  const server = new McpServer({
    name: "propeller-mcp",
    version,
  });

  for (const tool of getToolDefinitions()) {
    server.registerTool(tool.name, tool.config, async (args) => {
      try {
        const result = await tool.handler(args ?? {}, { client });
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(result, null, 2),
            },
          ],
          structuredContent: result,
        };
      } catch (err) {
        return formatErrorResponse(err);
      }
    });
  }

  return server;
}

export function formatErrorResponse(err) {
  if (err instanceof PropellerApiError) {
    const payload = {
      error: {
        code: err.code || "api_error",
        message: err.message,
        status: err.status,
        fields: err.fields,
        request_id: err.requestId,
      },
    };
    return {
      isError: true,
      content: [{ type: "text", text: JSON.stringify(payload, null, 2) }],
      structuredContent: payload,
    };
  }

  const payload = {
    error: {
      code: "internal_error",
      message: err?.message || "Unknown error",
    },
  };
  return {
    isError: true,
    content: [{ type: "text", text: JSON.stringify(payload, null, 2) }],
    structuredContent: payload,
  };
}

export function buildClientFromEnv(env = process.env) {
  const apiKey = env.PROPELLER_API_KEY;
  if (!apiKey) {
    throw new Error(
      "PROPELLER_API_KEY is not set. Add it to your MCP server config, e.g. `env: { PROPELLER_API_KEY: \"pk_live_...\" }`.",
    );
  }
  return new PropellerClient({
    apiKey,
    apiUrl: env.PROPELLER_API_URL,
    version: loadPackageVersion(),
  });
}
