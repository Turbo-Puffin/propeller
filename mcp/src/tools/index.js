import { z } from "zod";
import { PropellerApiError } from "../client.js";

// Tools are grouped per resource for readability. Each entry is the exact
// payload registerTool() takes plus a `handler` that receives (args, { client }).

const notYetSupported = (message) => ({
  not_supported: true,
  reason: message,
  status: "pending",
});

function paginationShape() {
  return {
    page: z.number().int().min(1).optional().describe("1-indexed page number (default 1)."),
    per_page: z
      .number()
      .int()
      .min(1)
      .max(100)
      .optional()
      .describe("Items per page (max 100, default 25)."),
  };
}

function unwrapData(payload) {
  if (payload && typeof payload === "object" && "data" in payload) return payload.data;
  return payload;
}

const tools = [
  // ─── Contacts ────────────────────────────────────────────────────────────
  {
    name: "propeller__create_contact",
    config: {
      title: "Create contact",
      description:
        "Create a new contact in the authenticated Propeller account. Returns the persisted contact, including its id.",
      inputSchema: {
        email: z.string().email().describe("Email address. Must be unique within the account."),
        first_name: z.string().optional().describe("Optional first name."),
        last_name: z.string().optional().describe("Optional last name."),
        status: z
          .enum(["subscribed", "unsubscribed", "bounced", "complained"])
          .optional()
          .describe("Initial subscription status (default subscribed)."),
        metadata: z
          .record(z.string(), z.any())
          .optional()
          .describe("Free-form JSON properties to attach to the contact."),
      },
    },
    async handler(args, { client }) {
      const payload = await client.post("/api/v1/contacts", { contact: args });
      return unwrapData(payload);
    },
  },
  {
    name: "propeller__update_contact",
    config: {
      title: "Update contact",
      description: "Update an existing contact's fields. Only provided fields are changed.",
      inputSchema: {
        contact_id: z.string().describe("ID of the contact to update."),
        email: z.string().email().optional(),
        first_name: z.string().optional(),
        last_name: z.string().optional(),
        status: z
          .enum(["subscribed", "unsubscribed", "bounced", "complained"])
          .optional(),
        metadata: z.record(z.string(), z.any()).optional(),
      },
    },
    async handler({ contact_id, ...attrs }, { client }) {
      const payload = await client.patch(`/api/v1/contacts/${encodeURIComponent(contact_id)}`, {
        contact: attrs,
      });
      return unwrapData(payload);
    },
  },
  {
    name: "propeller__list_contacts",
    config: {
      title: "List contacts",
      description:
        "List contacts in the account, newest first. Use page/per_page for pagination. The list_id filter is accepted but currently unused server-side and ignored.",
      inputSchema: {
        list_id: z
          .string()
          .optional()
          .describe(
            "Reserved for filtering by membership. Not yet supported server-side; provided for forward compatibility.",
          ),
        ...paginationShape(),
      },
    },
    async handler({ list_id: _listId, page, per_page }, { client }) {
      const payload = await client.get("/api/v1/contacts", { page, per_page });
      return { contacts: payload?.data ?? [], meta: payload?.meta ?? null };
    },
  },
  {
    name: "propeller__get_contact",
    config: {
      title: "Get contact",
      description: "Fetch a single contact by id.",
      inputSchema: {
        contact_id: z.string().describe("ID of the contact to fetch."),
      },
    },
    async handler({ contact_id }, { client }) {
      const payload = await client.get(`/api/v1/contacts/${encodeURIComponent(contact_id)}`);
      return unwrapData(payload);
    },
  },

  // ─── Lists ───────────────────────────────────────────────────────────────
  {
    name: "propeller__create_list",
    config: {
      title: "Create list",
      description: "Create a new contact list.",
      inputSchema: {
        name: z.string().min(1).describe("List name (required)."),
        description: z.string().optional().describe("Optional human-readable description."),
      },
    },
    async handler(args, { client }) {
      const payload = await client.post("/api/v1/lists", { list: args });
      return unwrapData(payload);
    },
  },
  {
    name: "propeller__list_lists",
    config: {
      title: "List lists",
      description: "List all contact lists in the account.",
      inputSchema: paginationShape(),
    },
    async handler({ page, per_page }, { client }) {
      const payload = await client.get("/api/v1/lists", { page, per_page });
      return { lists: payload?.data ?? [], meta: payload?.meta ?? null };
    },
  },
  {
    name: "propeller__add_contacts_to_list",
    config: {
      title: "Add contacts to list",
      description:
        "Add one or more contacts to a list. Each contact is added individually via the underlying REST API; results are reported per contact so partial successes are visible.",
      inputSchema: {
        list_id: z.string().describe("Target list id."),
        contact_ids: z
          .array(z.string().min(1))
          .min(1)
          .describe("One or more contact ids to add."),
      },
    },
    async handler({ list_id, contact_ids }, { client }) {
      const path = `/api/v1/lists/${encodeURIComponent(list_id)}/contacts`;
      const results = [];
      for (const contactId of contact_ids) {
        try {
          await client.post(path, { contact_id: contactId });
          results.push({ contact_id: contactId, ok: true });
        } catch (err) {
          if (err instanceof PropellerApiError) {
            results.push({
              contact_id: contactId,
              ok: false,
              error: { code: err.code, message: err.message, status: err.status },
            });
          } else {
            throw err;
          }
        }
      }
      const failed = results.filter((r) => !r.ok);
      return {
        list_id,
        added: results.length - failed.length,
        failed: failed.length,
        results,
      };
    },
  },

  // ─── Segments ────────────────────────────────────────────────────────────
  // No REST endpoint yet (see HON-350 scope). Surface a clear pending status so
  // agents discover the tool exists and can teach users it's coming, rather
  // than failing with a 404.
  {
    name: "propeller__create_segment",
    config: {
      title: "Create segment (pending)",
      description:
        "Create a dynamic segment within a list. The Propeller REST API does not yet expose segment endpoints; this tool returns a not-yet-supported response. It will start working without code changes once segment endpoints ship.",
      inputSchema: {
        list_id: z.string(),
        name: z.string(),
        rules: z
          .record(z.string(), z.any())
          .describe("Segment rules object. Schema will be defined when segment endpoints ship."),
      },
    },
    async handler() {
      return notYetSupported(
        "Segments are not yet supported by the Propeller REST API. This tool is reserved for forward compatibility.",
      );
    },
  },
  {
    name: "propeller__list_segments",
    config: {
      title: "List segments (pending)",
      description:
        "List segments within a list. Not yet supported by the Propeller REST API; returns a pending status.",
      inputSchema: {
        list_id: z.string(),
      },
    },
    async handler() {
      return notYetSupported(
        "Segments are not yet supported by the Propeller REST API.",
      );
    },
  },

  // ─── Campaigns ───────────────────────────────────────────────────────────
  {
    name: "propeller__create_campaign",
    config: {
      title: "Create campaign",
      description:
        "Create a draft campaign. If scheduled_at is provided, the campaign is scheduled in the same call. Sending pipeline lands in HON-352; until then a scheduled campaign sits in the queue without dispatching.",
      inputSchema: {
        list_id: z
          .string()
          .optional()
          .describe(
            "Audience list id. Reserved for the upcoming send pipeline (HON-352); not yet persisted server-side.",
          ),
        segment_id: z
          .string()
          .optional()
          .describe("Optional segment id. Not yet supported."),
        name: z.string().optional().describe("Internal campaign name (defaults to subject)."),
        subject: z.string().describe("Email subject line."),
        from_name: z.string().optional(),
        from_email: z.string().email().optional(),
        html_body: z.string().describe("HTML body. Maps to body_html in the REST API."),
        plain_body: z.string().describe("Plain-text body. Maps to body_text in the REST API."),
        scheduled_at: z
          .string()
          .datetime()
          .optional()
          .describe("ISO8601 timestamp. If supplied, schedules the campaign in the same call."),
      },
    },
    async handler(args, { client }) {
      const campaignBody = {
        name: args.name || args.subject,
        subject: args.subject,
        from_name: args.from_name,
        from_email: args.from_email,
        body_html: args.html_body,
        body_text: args.plain_body,
      };
      const created = unwrapData(await client.post("/api/v1/campaigns", { campaign: campaignBody }));

      if (args.scheduled_at) {
        const scheduled = unwrapData(
          await client.post(`/api/v1/campaigns/${encodeURIComponent(created.id)}/schedule`, {
            scheduled_at: args.scheduled_at,
          }),
        );
        return {
          campaign: scheduled,
          note: "Scheduled. Sending pipeline is not yet wired (HON-352); the campaign will not actually dispatch until that ships.",
        };
      }

      return { campaign: created };
    },
  },
  {
    name: "propeller__schedule_campaign",
    config: {
      title: "Schedule campaign",
      description:
        "Schedule a draft or paused campaign for a future send time. The send pipeline lands in HON-352; until then the campaign moves to the scheduled queue but no dispatch occurs.",
      inputSchema: {
        campaign_id: z.string(),
        scheduled_at: z.string().datetime().describe("ISO8601 timestamp."),
      },
    },
    async handler({ campaign_id, scheduled_at }, { client }) {
      const payload = await client.post(
        `/api/v1/campaigns/${encodeURIComponent(campaign_id)}/schedule`,
        { scheduled_at },
      );
      return {
        campaign: unwrapData(payload),
        note: "Sending pipeline not yet wired (HON-352); campaign will not actually dispatch until that ships.",
      };
    },
  },
  {
    name: "propeller__cancel_campaign",
    config: {
      title: "Cancel campaign",
      description: "Return a scheduled or paused campaign to draft status.",
      inputSchema: {
        campaign_id: z.string(),
      },
    },
    async handler({ campaign_id }, { client }) {
      const payload = await client.post(
        `/api/v1/campaigns/${encodeURIComponent(campaign_id)}/cancel`,
        {},
      );
      return unwrapData(payload);
    },
  },
  {
    name: "propeller__list_campaigns",
    config: {
      title: "List campaigns",
      description: "List campaigns, optionally filtered by status, newest first.",
      inputSchema: {
        status: z
          .enum(["draft", "scheduled", "sending", "sent", "paused", "cancelled"])
          .optional(),
        ...paginationShape(),
      },
    },
    async handler({ status, page, per_page }, { client }) {
      const payload = await client.get("/api/v1/campaigns", { status, page, per_page });
      return { campaigns: payload?.data ?? [], meta: payload?.meta ?? null };
    },
  },

  // ─── Send metrics ────────────────────────────────────────────────────────
  // The underlying REST API exposes individual send events but not the rolled-up
  // counts the ticket asks for. Until HON-352-354 ship the send pipeline, return
  // zeros with a clear pending status so agents can build flows that read the
  // same shape long-term.
  {
    name: "propeller__get_send_metrics",
    config: {
      title: "Get send metrics (pending)",
      description:
        "Aggregate send metrics (sent, opened, clicked, bounced, complained) for a campaign. Returns zeros until the send pipeline lands in HON-352-354.",
      inputSchema: {
        campaign_id: z.string(),
      },
    },
    async handler({ campaign_id }) {
      return {
        campaign_id,
        metrics: { sent: 0, opened: 0, clicked: 0, bounced: 0, complained: 0 },
        ...notYetSupported(
          "Aggregate metrics endpoint ships with the send pipeline (HON-352-354). Returning zeros so agent prompts work today.",
        ),
      };
    },
  },

  // ─── Templates ───────────────────────────────────────────────────────────
  {
    name: "propeller__create_template",
    config: {
      title: "Create template (pending)",
      description:
        "Create a reusable email template. Templates API not yet shipped; returns a pending status.",
      inputSchema: {
        name: z.string(),
        html: z.string(),
        plain: z.string(),
      },
    },
    async handler() {
      return notYetSupported(
        "Templates are not yet supported by the Propeller REST API.",
      );
    },
  },
  {
    name: "propeller__list_templates",
    config: {
      title: "List templates (pending)",
      description: "List reusable email templates. Not yet shipped; returns a pending status.",
      inputSchema: {},
    },
    async handler() {
      return notYetSupported(
        "Templates are not yet supported by the Propeller REST API.",
      );
    },
  },
];

export function getToolDefinitions() {
  return tools;
}
