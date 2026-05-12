// Thin HTTP wrapper around Propeller's REST API.
// All tool handlers go through this so retries, headers, and error shaping live in one place.

const DEFAULT_API_URL = "https://propeller.rocks";
const USER_AGENT_FALLBACK = "propeller-mcp";

export class PropellerApiError extends Error {
  constructor(message, { status, code, fields, requestId } = {}) {
    super(message);
    this.name = "PropellerApiError";
    this.status = status ?? null;
    this.code = code ?? null;
    this.fields = fields ?? null;
    this.requestId = requestId ?? null;
  }
}

function trimTrailingSlash(value) {
  if (!value) return value;
  return value.replace(/\/+$/, "");
}

function buildQuery(params) {
  if (!params) return "";
  const usp = new URLSearchParams();
  for (const [key, raw] of Object.entries(params)) {
    if (raw === undefined || raw === null || raw === "") continue;
    usp.append(key, String(raw));
  }
  const out = usp.toString();
  return out ? `?${out}` : "";
}

export class PropellerClient {
  constructor({ apiKey, apiUrl, fetchImpl, userAgent, version } = {}) {
    if (!apiKey) {
      throw new Error("PROPELLER_API_KEY is required");
    }
    this.apiKey = apiKey;
    this.apiUrl = trimTrailingSlash(apiUrl || process.env.PROPELLER_API_URL || DEFAULT_API_URL);
    this.fetchImpl = fetchImpl || globalThis.fetch;
    if (typeof this.fetchImpl !== "function") {
      throw new Error("No fetch implementation available; pass fetchImpl or run on Node.js >= 18.");
    }
    this.userAgent = userAgent || `${USER_AGENT_FALLBACK}/${version || "0.0.0"}`;
  }

  async request(method, path, { query, body } = {}) {
    const url = `${this.apiUrl}${path}${buildQuery(query)}`;
    const headers = {
      Authorization: `Bearer ${this.apiKey}`,
      Accept: "application/json",
      "User-Agent": this.userAgent,
    };
    const init = { method, headers };
    if (body !== undefined) {
      headers["Content-Type"] = "application/json";
      init.body = JSON.stringify(body);
    }

    let response;
    try {
      response = await this.fetchImpl(url, init);
    } catch (err) {
      throw new PropellerApiError(`Network error contacting Propeller API: ${err.message}`, {
        code: "network_error",
      });
    }

    const requestId = response.headers.get?.("x-request-id") || null;

    if (response.status === 204) {
      return { ok: true, requestId };
    }

    const text = await response.text();
    let payload = null;
    if (text) {
      try {
        payload = JSON.parse(text);
      } catch {
        payload = { raw: text };
      }
    }

    if (!response.ok) {
      const errorBody = payload?.error || {};
      throw new PropellerApiError(
        errorBody.message || `Propeller API returned HTTP ${response.status}`,
        {
          status: response.status,
          code: errorBody.code || `http_${response.status}`,
          fields: errorBody.fields || null,
          requestId,
        },
      );
    }

    return payload ?? { ok: true, requestId };
  }

  get(path, query) {
    return this.request("GET", path, { query });
  }

  post(path, body) {
    return this.request("POST", path, { body });
  }

  patch(path, body) {
    return this.request("PATCH", path, { body });
  }

  delete(path) {
    return this.request("DELETE", path);
  }
}
