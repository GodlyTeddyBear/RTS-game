# Debug Logging

Debug logging uses `Result.MentionSuccess` and `Result.MentionEvent` from the Result utility library. There is no `DebugLogger` — that pattern is legacy and should not be used.

---

## When to Log

Log at meaningful **milestones** — not on every line. Good candidates:

- After a significant state mutation completes (flag set, data saved, entity created)
- After a chapter or progression event fires
- After an external system is written to (ProfileStore, atoms)

Do **not** log:
- Inside tight loops
- Every intermediate calculation
- Things already covered by `warn()` error logging (see [backend/ERROR_HANDLING.md](../architecture/backend/ERROR_HANDLING.md))

---

## MentionSuccess

Use for successful operations that are worth tracing.

```lua
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

MentionSuccess("Unlock:EvaluateChapterAdvancement:Execute", "Player advanced to new chapter", {
    userId = userId,
    newChapter = nextChapter,
})
```

**Signature**: `MentionSuccess(label, message, data?)`
- `label` — `"Context:Service:Method"` format
- `message` — human-readable description
- `data` — optional table of contextual values

---

## MentionEvent

Use for event bus milestones — emitting or receiving significant game events.

```lua
local MentionEvent = Result.MentionEvent

MentionEvent("Unlock:ProcessAutoUnlocks", "ChapterAdvanced event received", {
    userId = userId,
    chapter = chapter,
})
```

---

## Debug vs Error Logging

| | Debug Logging | Error Logging |
|---|---|---|
| Tool | `MentionSuccess` / `MentionEvent` | `warn()` |
| When | Dev/testing — no-op if no logger registered | Always on |
| Purpose | Trace execution milestones | Signal failures |
| Location | Any meaningful milestone in any layer | Application layer only |