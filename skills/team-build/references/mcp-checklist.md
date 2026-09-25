# MCP server and agent tool endpoint checklist

Use this when a change adds an MCP server, an agent tool endpoint, or a new third-party MCP server. ai-agent-engineer builds to it, and the code-reviewer's security lens checks it. Each item comes from a real incident: an unauthenticated remote-code-execution chain in an HTTP MCP bridge, plus related defect reports. See the ruflo ADRs in NOTICE.md.

## Transport and exposure
1. **Auth on every non-stdio transport** (HTTP, SSE, WebSocket). Every route is covered by the same middleware, not just the main one.
2. **Bind to loopback by default.** Refuse to start on a public bind (`0.0.0.0`, `::`) without a configured token.
3. **No published database or backend ports** in compose files or deploy config (`ports:` for Mongo, Postgres, Redis or the bridge itself).
4. **A bad or unverifiable token gets a 401.** It is never downgraded to anonymous. If no token audience is configured, refuse bearer tokens entirely (confused deputy).
5. **Compare tokens in constant time** (`crypto.timingSafeEqual`, `hmac.compare_digest`).

## Tool dispatch
6. **The allow/deny check lives inside the one dispatch function** that every route and transport goes through. It uses an allowlist, not a per-route blocklist.
7. **Shell, exec and file-write tools are off by default,** and enabled only by explicit config.
8. **Spawned processes get an env allowlist,** never `{ ...process.env }`, which hands them every API key.
9. **Validate `inputSchema` at runtime** on every call. A declared schema alone is not validation.
10. **No credentials as tool arguments.** Arguments are model-generated, and they land in the model's context and in transcripts.
11. **File and path arguments are resolved and confined** to an allowed root. Reject path traversal and symlinks that point outside it.
12. **Escape regexes built from input,** and bound their input length (ReDoS).
13. **A rate limit and bounded caches** per client or token.

## Tool descriptions
14. **Each tool description matches what its handler does.** Read the handler, not just the description.
15. **For third-party MCP servers:** read every tool description for embedded instructions. They can be split across several tools, so read them together.
16. **After a security fix,** check persisted state (learning stores, caches, memory) for entries written before the fix, and purge them. Redeploying doesn't remove them.
