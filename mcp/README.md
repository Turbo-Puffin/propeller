# propeller-mcp

A [Model Context Protocol](https://modelcontextprotocol.io) server that exposes Propeller's REST API as agent-callable tools. Agents (Claude Code, Cursor, Codex, etc.) add the server to their MCP config and drive Propeller in natural language, with no client code required.

This package is the signature differentiator for Propeller's agent-first thesis. It wraps the same `/api/v1` surface a human developer would call, with the same API-key Bearer auth.

## Install

```bash
npx -y propeller-mcp@latest
```

Or globally:

```bash
npm install -g propeller-mcp
propeller-mcp
```

## Configure in your agent

Add this to your MCP config file (Claude Desktop: `~/Library/Application Support/Claude/claude_desktop_config.json`; Claude Code: `~/.claude.json`; Cursor: `.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "propeller": {
      "command": "npx",
      "args": ["-y", "propeller-mcp@latest"],
      "env": {
        "PROPELLER_API_KEY": "pk_live_your_key_here",
        "PROPELLER_API_URL": "https://propeller.rocks"
      }
    }
  }
}
```

Create an API key from Propeller's web app at **Settings → API keys**. Keys are shown in plaintext exactly once; copy and store it.

### Environment variables

| Variable             | Required | Default                  | Notes                                                                 |
| -------------------- | -------- | ------------------------ | --------------------------------------------------------------------- |
| `PROPELLER_API_KEY`  | yes      | (none)                   | API key from Propeller. Scoped to a single account.                   |
| `PROPELLER_API_URL`  | no       | `https://propeller.rocks` | Override for self-hosted or staging environments.                     |

## Tools

All tools are namespaced with the `propeller__` prefix so they sort cleanly in agent UIs.

### Contacts

| Tool                              | Inputs                                                  | Returns                |
| --------------------------------- | ------------------------------------------------------- | ---------------------- |
| `propeller__create_contact`       | `email`, `first_name?`, `last_name?`, `status?`, `metadata?` | contact                |
| `propeller__update_contact`       | `contact_id`, fields                                    | contact                |
| `propeller__list_contacts`        | `page?`, `per_page?`                                    | `{ contacts, meta }`   |
| `propeller__get_contact`          | `contact_id`                                            | contact                |

### Lists

| Tool                               | Inputs                                | Returns               |
| ---------------------------------- | ------------------------------------- | --------------------- |
| `propeller__create_list`           | `name`, `description?`                | list                  |
| `propeller__list_lists`            | `page?`, `per_page?`                  | `{ lists, meta }`     |
| `propeller__add_contacts_to_list`  | `list_id`, `contact_ids[]`            | per-contact results   |

### Campaigns

| Tool                         | Inputs                                                                                           | Returns       |
| ---------------------------- | ------------------------------------------------------------------------------------------------ | ------------- |
| `propeller__create_campaign` | `subject`, `html_body`, `plain_body`, `from_name?`, `from_email?`, `list_id?`, `segment_id?`, `scheduled_at?` | campaign      |
| `propeller__schedule_campaign` | `campaign_id`, `scheduled_at`                                                                  | campaign      |
| `propeller__cancel_campaign` | `campaign_id`                                                                                    | campaign      |
| `propeller__list_campaigns`  | `status?`, `page?`, `per_page?`                                                                  | `{ campaigns, meta }` |

### Send metrics (pending)

| Tool                          | Inputs        | Returns                                            |
| ----------------------------- | ------------- | -------------------------------------------------- |
| `propeller__get_send_metrics` | `campaign_id` | zeros until the send pipeline ships (HON-352-354). |

### Segments and templates (pending)

These tools are registered with their full schemas so agents can discover them today. They return a `not_supported` payload until the underlying REST endpoints ship.

| Tool                             | Status                                |
| -------------------------------- | ------------------------------------- |
| `propeller__create_segment`      | pending (endpoint not yet shipped)    |
| `propeller__list_segments`       | pending (endpoint not yet shipped)    |
| `propeller__create_template`     | pending (endpoint not yet shipped)    |
| `propeller__list_templates`      | pending (endpoint not yet shipped)    |

When the endpoints ship, this package picks them up without any agent-side changes.

## Example session

Ask your agent:

> Add ada@example.com to the "Newsletter" list and create a draft campaign welcoming them.

The agent will call `propeller__list_lists`, `propeller__create_contact`, `propeller__add_contacts_to_list`, and `propeller__create_campaign` in sequence. No glue code needed.

## Error responses

Every tool returns a structured result. On failure (network, 4xx, 5xx) the result has `isError: true` and a JSON body like:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Email has already been taken",
    "status": 422,
    "fields": { "email": ["has already been taken"] },
    "request_id": "req_abc123"
  }
}
```

The transport stays open, so the agent can retry or take a different path.

## Development

```bash
cd mcp
npm install
npm test
```

Tests use Node's built-in test runner. The MCP server is exercised end-to-end through an in-memory transport so `tools/list` and `tools/call` behaviour are verified without spawning child processes.

To exercise against a live Propeller instance:

```bash
PROPELLER_API_KEY=pk_live_xxx PROPELLER_API_URL=https://propeller.rocks npm start
```

Then connect any MCP client to the resulting stdio transport.

## License

MIT.
