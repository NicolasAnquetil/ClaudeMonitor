# ClaudeMonitor

A live view, in a Pharo [Bloc](https://github.com/pharo-graphics/Bloc) window, of what Claude Code does in a workspace: every tool call (shell commands, file edits, Pharo MCP calls...) with why it was made, its full input, its result and its duration, plus the prompts you submit.

Claude Code [hooks](https://docs.claude.com/en/docs/claude-code/hooks) POST each event to a small HTTP server in the image (localhost, port 8091).

## Load

```smalltalk
Metacello new
	baseline: 'ClaudeMonitor';
	repository: 'github://NicolasAnquetil/ClaudeMonitor:main/src';
	load.
```

## Use

```smalltalk
CMMonitor start.   "receive hook events on 127.0.0.1:8091 and open the window"
CMMonitor open.    "open another window on the same activities"
CMMonitor stop.    "stop receiving events"
CMMonitor reset.   "stop and forget the activities"
```

The window lists the activities, newest on top: a status dot (orange running, green ok, red failed), the time, the tool, a summary and the duration. Click one to see its details:

- **Why**: the description Claude gives with a shell command.
- **Explanation**: the text Claude wrote just before the call, read from the session transcript (best effort: not every text reaches the transcript).
- **Input**: the full command, code or file content, then the other arguments.
- **Response** or **Error**: what the tool answered (cut after 20000 characters).

*Hide reads* hides the calls that only look at things (Read, Grep, Glob, Pharo searches...).

## Claude Code hooks

Put this in the workspace's `.claude/settings.json` (only sessions started in that workspace are monitored). The hooks run asynchronously and fail silently, so Claude Code is never slowed down or blocked when the image is not running.

```json
{
  "hooks": {
    "PreToolUse": [{ "matcher": "*", "hooks": [{ "type": "command", "async": true,
      "command": "curl -s -m 2 -X POST -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:8091/event >/dev/null 2>&1 || true" }] }],
    "PostToolUse": [{ "matcher": "*", "hooks": [{ "type": "command", "async": true,
      "command": "curl -s -m 2 -X POST -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:8091/event >/dev/null 2>&1 || true" }] }],
    "PostToolUseFailure": [{ "matcher": "*", "hooks": [{ "type": "command", "async": true,
      "command": "curl -s -m 2 -X POST -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:8091/event >/dev/null 2>&1 || true" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "async": true,
      "command": "curl -s -m 2 -X POST -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:8091/event >/dev/null 2>&1 || true" }] }]
  }
}
```

## Limits

- Only what happens while the image runs and `CMMonitor start` was done is shown; nothing is kept when the image is restarted without saving.
- Times are when the hook events reached the image (hooks are asynchronous, so a little late); durations are the ones Claude Code measured.
