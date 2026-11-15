# ClaudeMonitor

A live view, in a Pharo window built with [Toplo](https://github.com/pharo-graphics/Toplo) (widgets on top of [Bloc](https://github.com/pharo-graphics/Bloc)), of what Claude Code does in a workspace: every tool call (shell commands, file edits, Pharo MCP calls...) with why it was made, its full input, its result and its duration, plus the prompts you submit.

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

This loads Bloc v3.0.0 and Toplo v0.11.0 (the Toplo version built on that Bloc).

The window shows a tree, newest on top: each Claude Code session, the prompts you submitted in it, and under each prompt what Claude did for it, in order:

- the tool calls,
- the messages Claude wrote and its thinking, read from the session transcript at each hook event (the transcript keeps the text of only part of the thinking: the rest is skipped),
- for a to-do list (`TodoWrite`) or a plan (`ExitPlanMode`), one row per step under the call, with its state (done, in progress, pending).
Each row has a status icon (running, ok, failed), the tool, a summary, then the start time and the duration in their own columns. The arrows fold and unfold sessions and prompts.

Keys: up and down move in the list; left folds a prompt or goes to its parent; right unfolds a prompt or goes to its first tool call.

Select a row to see its details on the right (the text can be selected and copied; drag the divider to resize the panes):

- **Why**: the description Claude gives with a shell command.
- **Explanation**: the text Claude wrote just before the call, read from the session transcript (best effort: not every text reaches the transcript).
- **Input**: the full command, code or file content, then the other arguments.
- **Response** or **Error**: what the tool answered (cut after 20000 characters).

*Hide reads* hides the calls that only look at things (Read, Grep, Glob, Pharo searches...); *Clear* hides what happened until now; *A-* and *A+* change the font size.
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
      "command": "curl -s -m 2 -X POST -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:8091/event >/dev/null 2>&1 || true" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "async": true,
      "command": "curl -s -m 2 -X POST -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:8091/event >/dev/null 2>&1 || true" }] }]
  }
}
```

## Limits

- Only what happens while the image runs and `CMMonitor start` was done is shown; nothing is kept when the image is restarted without saving.
- Times are when the hook events reached the image (hooks are asynchronous, so a little late); durations are the ones Claude Code measured.
