# Source Discovery Contract v1

Versioned, read-only JSON contract between Symaira Hub and importing tools for
pending-source discovery. Hub consumes discovery results from tool CLIs; tools
own their source-specific logic and expose metadata only — Hub never becomes a
second importer.

## Schema Version Handshake

Every discovery response carries a `schema_version` integer. Hub compares it
against its own `expectedSchemaVersion`:

| Condition | Behavior |
|---|---|
| `response.schema_version == expectedSchemaVersion` | Normal processing |
| `response.schema_version > expectedSchemaVersion` | Hub shows upgrade hint for itself |
| `response.schema_version < expectedSchemaVersion` | Hub shows upgrade hint for the tool |
| `schema_version` missing or non-integer | Treated as incompatible — actionable error, not a crash |

Hub must never crash on a mismatched schema version. The error path shows which
component needs upgrading and continues operating with other tools.

## Response Envelope

Tools expose discovery through a CLI subcommand or MCP tool that returns JSON
to stdout. Exit code 0 on success; non-zero with stderr message on failure.

```json
{
  "schema_version": 1,
  "sources": [
    {
      "source_id": "claude-code-sessions-v1",
      "tool": "symmemory",
      "kind": "session-data",
      "display_name": "Claude Code Sessions",
      "location": "~/Library/Application Support/Claude/claude_desktop_config.json",
      "capabilities": ["import"],
      "item_count": 42,
      "last_seen": "2026-07-31T14:00:00Z",
      "privacy_hint": "may_contain_personal_data"
    }
  ]
}
```

### Top-Level Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `schema_version` | integer | yes | Contract version (currently `1`) |
| `sources` | array | yes | Discovered source candidates, empty if none found |

### Source Object Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `source_id` | string | yes | Stable, unique identifier. Survives renames and path changes where possible. Tools choose the identity strategy (content hash, persistent UUID, canonical path). |
| `tool` | string | yes | Tool name (`symmemory`, `symskills`, etc.) |
| `kind` | string | yes | Source type (`session-data`, `skill-bundle`, `profile-context`, `document-repository`, etc.) |
| `display_name` | string | yes | Human-readable label for the Hub UI |
| `location` | string | yes | User-visible path, URL, or descriptor. May change when source moves. |
| `capabilities` | string[] | yes | What Hub can do with this source. Currently: `["import"]`. Future: `["preview", "sync", "export"]`. |
| `item_count` | integer | no | Approximate count of importable items for preview |
| `last_seen` | string | no | ISO 8601 timestamp of last scan |
| `privacy_hint` | string | no | Privacy classification: `"none"`, `"may_contain_personal_data"`, `"contains_credentials"`, `"sensitive"`. Hub uses this to adjust preview behavior. |

### Privacy and Security Rules

- Discovery payloads must never contain raw imported content, credentials, API
  keys, tokens, or file contents.
- `privacy_hint` is advisory metadata, not a security boundary.
- `location` may expose filesystem paths. Hub should display them only after
  the user has seen the source's display_name and tool origin.
- Tools must apply the same credential redaction to discovery output that they
  apply to their regular `--json` output.

## Hub-Side Contract

### Expected Response

Hub expects each tool's discovery command to produce the envelope above on
stdout and exit 0. On non-zero exit, Hub reads stderr for the error message
and treats the tool as unavailable for this scan cycle.

### Timeout

Hub applies a per-tool timeout (default 10 seconds). A tool that exceeds the
timeout is marked unavailable until the next scan cycle. Hub startup must
never block on discovery.

### Mock / Stub Adapter

During development, Hub can run against a mock adapter that returns a static
or configurable set of sources. The mock must implement the same contract
envelope and exit code semantics so the real adapter can be swapped in without
Hub-side changes.

### Idempotency

Hub compares `source_id` values across scans. A source with a known `source_id`
that was previously ignored must not be re-presented. A source whose `location`
changed but `source_id` is identical should update its displayed location
without creating a duplicate entry.

## Tool-Side Contract

### Adding a Discovery Adapter

1. Add a CLI subcommand or MCP tool that accepts no arguments and writes the
   discovery envelope to stdout.

   ```
   symmemory discover sources   # CLI
   mcp__symmemory__discover_sources   # MCP
   ```

2. The tool's `schema_version` must match the contract version it implements.

3. The tool must not require credentials or interactive input for discovery.
   If credentials are needed and unavailable, return an empty source list
   (exit 0) rather than an error — the source is simply not visible until
   credentials are configured.

4. Discovery must be read-only — no side effects, no state changes, no
   import operations.

5. Stable `source_id` strategy is tool-defined. Recommended approaches in
   priority order:

   a. Content-derived fingerprint (hash of canonical identifier)
   b. Persistent UUID stored alongside the source
   c. Normalized canonical path (acceptable for local-first tools)

   Path-based IDs without normalization must handle moved/renamed sources
   gracefully — the tool should detect that the old path is gone and the
   new path's content matches a known identity.

6. Deduplication: if two discovery mechanisms find the same logical source,
   the tool must deduplicate before returning results. Hub trusts the tool's
   deduplication and does not perform its own.

### Example: symmemory adapter

```bash
$ symmemory discover sources
{
  "schema_version": 1,
  "sources": [
    {
      "source_id": "claude-code-sessions-v1",
      "tool": "symmemory",
      "kind": "session-data",
      "display_name": "Claude Code Sessions",
      "location": "~/Library/Application Support/Claude/claude_desktop_config.json",
      "capabilities": ["import"],
      "item_count": 42,
      "last_seen": "2026-07-31T14:00:00Z",
      "privacy_hint": "may_contain_personal_data"
    }
  ]
}
```

### Example: symskills adapter

```bash
$ symskills discover sources
{
  "schema_version": 1,
  "sources": [
    {
      "source_id": "bundle:hermes-agent-tools:abc123",
      "tool": "symskills",
      "kind": "skill-bundle",
      "display_name": "hermes-agent-tools (unmanaged)",
      "location": "~/.config/opencode/skills/hermes-agent-tools/",
      "capabilities": ["import"],
      "item_count": 12,
      "last_seen": "2026-07-31T14:00:00Z",
      "privacy_hint": "none"
    }
  ]
}
```

## Version History

| Version | Date | Changes |
|---|---|---|
| 1 | 2026-07-31 | Initial contract: envelope, schema_version handshake, source fields, privacy rules, tool-side guide |
