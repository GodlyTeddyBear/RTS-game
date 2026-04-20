Run the Selene linter on the specified path and summarize the results.

If no argument is given, lint the entire `src/` directory.

## Steps

1. Run the linter:
   - If $ARGUMENTS is provided: `selene $ARGUMENTS`
   - If no argument: `selene src/`
2. Parse the output and group findings by file.
3. Report a summary table showing file, line, severity, and message.
4. If there are errors (not warnings), highlight them clearly at the top.
5. If the linter passes cleanly, confirm that explicitly.

## Output format

```
ERRORS (must fix)
─────────────────
src/Path/To/File.lua:42  error   message here

WARNINGS (should fix)
──────────────────────
src/Path/To/File.lua:10  warning  message here

SUMMARY
───────
X errors, Y warnings across Z files
```

If no issues: `✓ Linter passed — no errors or warnings.`

## Notes

- Selene is configured via `selene.toml` at the project root
- Fix errors before committing — warnings are advisory
- If the `selene` binary is not found on PATH, try `~/.aftman/bin/selene` or `~/.rokit/bin/selene`
