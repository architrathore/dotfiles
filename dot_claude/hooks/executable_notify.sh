#!/bin/bash
#
# Claude Code Notification Hook
# Shows macOS system notifications with context about agent state
#

# Read hook input from stdin
INPUT=$(cat)

# Parse common fields using Python for reliable JSON handling
parse_json() {
    echo "$INPUT" | /usr/bin/python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('$1', '$2'))" 2>/dev/null
}

HOOK_EVENT=$(parse_json "hook_event_name" "")
TRANSCRIPT_PATH=$(parse_json "transcript_path" "")

# For Stop events, check if this is a recursive call to prevent loops
if [ "$HOOK_EVENT" = "Stop" ]; then
    STOP_HOOK_ACTIVE=$(parse_json "stop_hook_active" "False")
    if [ "$STOP_HOOK_ACTIVE" = "True" ]; then
        exit 0
    fi
fi

# Function to analyze transcript and extract useful info
analyze_transcript() {
    if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
        echo ""
        return
    fi

    /usr/bin/python3 << 'PYEOF' "$TRANSCRIPT_PATH" 2>/dev/null
import sys
import json

transcript_path = sys.argv[1] if len(sys.argv) > 1 else ""
if not transcript_path:
    sys.exit(0)

tool_counts = {}
last_tool = None
last_tool_input = None
files_edited = set()
files_read = set()
commands_run = []
total_tools = 0

try:
    with open(transcript_path, 'r') as f:
        for line in f:
            try:
                entry = json.loads(line.strip())

                if entry.get('type') == 'assistant':
                    message = entry.get('message', {})
                    content = message.get('content', [])

                    for block in content:
                        if block.get('type') == 'tool_use':
                            tool_name = block.get('name', 'unknown')
                            tool_input = block.get('input', {})

                            tool_counts[tool_name] = tool_counts.get(tool_name, 0) + 1
                            total_tools += 1
                            last_tool = tool_name
                            last_tool_input = tool_input

                            if tool_name == 'Edit':
                                fp = tool_input.get('file_path', '')
                                if fp:
                                    files_edited.add(fp.split('/')[-1])
                            elif tool_name == 'Write':
                                fp = tool_input.get('file_path', '')
                                if fp:
                                    files_edited.add(fp.split('/')[-1])
                            elif tool_name == 'Read':
                                fp = tool_input.get('file_path', '')
                                if fp:
                                    files_read.add(fp.split('/')[-1])
                            elif tool_name == 'Bash':
                                cmd = tool_input.get('command', '')
                                if cmd:
                                    commands_run.append(cmd[:50])

            except json.JSONDecodeError:
                continue
except:
    pass

summary_parts = []
if total_tools > 0:
    summary_parts.append(f"{total_tools} tool calls")

actions = []
if files_edited:
    edited_list = ', '.join(list(files_edited)[:3])
    if len(files_edited) > 3:
        edited_list += f" +{len(files_edited)-3} more"
    actions.append(f"edited {edited_list}")

if commands_run:
    actions.append(f"ran {len(commands_run)} commands")

if files_read and not files_edited:
    actions.append(f"read {len(files_read)} files")

last_action = ""
if last_tool:
    if last_tool == 'Edit':
        fp = last_tool_input.get('file_path', '') if last_tool_input else ''
        fname = fp.split('/')[-1] if fp else 'file'
        last_action = f"Last: edited {fname}"
    elif last_tool == 'Write':
        fp = last_tool_input.get('file_path', '') if last_tool_input else ''
        fname = fp.split('/')[-1] if fp else 'file'
        last_action = f"Last: created {fname}"
    elif last_tool == 'Bash':
        cmd = last_tool_input.get('command', '')[:30] if last_tool_input else ''
        last_action = f"Last: {cmd}..." if cmd else "Last: ran command"
    elif last_tool == 'Read':
        fp = last_tool_input.get('file_path', '') if last_tool_input else ''
        fname = fp.split('/')[-1] if fp else 'file'
        last_action = f"Last: read {fname}"
    elif last_tool == 'Task':
        last_action = "Last: spawned subagent"
    elif last_tool in ('Grep', 'Glob'):
        last_action = "Last: searched codebase"
    else:
        last_action = f"Last: {last_tool}"

output_parts = []
output_parts.append(' '.join(summary_parts) if summary_parts else "No tools used")
output_parts.append(', '.join(actions) if actions else "")
output_parts.append(last_action)

print('|'.join(output_parts))
PYEOF
}

# Determine notification content based on event
case "$HOOK_EVENT" in
    "Stop")
        TITLE="Claude Code - Done"
        SOUND="Glass"

        ANALYSIS=$(analyze_transcript)
        if [ -n "$ANALYSIS" ]; then
            SUMMARY=$(echo "$ANALYSIS" | cut -d'|' -f1)
            ACTIONS=$(echo "$ANALYSIS" | cut -d'|' -f2)
            LAST_ACTION=$(echo "$ANALYSIS" | cut -d'|' -f3)

            if [ -n "$ACTIONS" ]; then
                MESSAGE="$SUMMARY - $ACTIONS"
            elif [ -n "$SUMMARY" ]; then
                MESSAGE="$SUMMARY"
            else
                MESSAGE="Agent has finished"
            fi

            [ -n "$LAST_ACTION" ] && SUBTITLE="$LAST_ACTION"
        else
            MESSAGE="Agent has finished responding"
        fi
        ;;

    "Notification")
        NOTIF_TYPE=$(parse_json "notification_type" "")
        SOUND="Purr"

        case "$NOTIF_TYPE" in
            "permission_prompt")
                TITLE="Claude Code - Permission Needed"
                TOOL_NAME=$(echo "$INPUT" | /usr/bin/python3 -c "
import sys,json
data=json.load(sys.stdin)
tool = data.get('tool_name', '')
tool_input = data.get('tool_input', {})
if tool == 'Bash':
    cmd = tool_input.get('command', '')[:40]
    print(f'Bash: {cmd}...' if len(tool_input.get('command', '')) > 40 else f'Bash: {cmd}')
elif tool in ('Edit', 'Write'):
    fp = tool_input.get('file_path', '')
    fname = fp.split('/')[-1] if fp else 'file'
    print(f'{tool}: {fname}')
elif tool:
    print(tool)
else:
    print('Action requires approval')
" 2>/dev/null)
                MESSAGE="${TOOL_NAME:-Action requires approval}"
                ;;
            "idle_prompt")
                TITLE="Claude Code - Waiting"
                ANALYSIS=$(analyze_transcript)
                LAST_ACTION=$(echo "$ANALYSIS" | cut -d'|' -f3)
                if [ -n "$LAST_ACTION" ]; then
                    MESSAGE="Waiting for input. $LAST_ACTION"
                else
                    MESSAGE="Waiting for your input"
                fi
                ;;
            *)
                TITLE="Claude Code"
                MESSAGE="Notification: $NOTIF_TYPE"
                ;;
        esac
        ;;
    *)
        TITLE="Claude Code"
        MESSAGE="Event: $HOOK_EVENT"
        SOUND="Pop"
        ;;
esac

# Check if terminal is frontmost - skip notification if so
FRONTMOST=$(/usr/bin/osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)
TERMINALS="Terminal iTerm2 Ghostty Alacritty kitty WezTerm Warp"

for term in $TERMINALS; do
    [ "$FRONTMOST" = "$term" ] && exit 0
done

# Send notification via osascript
if [ -n "$SUBTITLE" ]; then
    /usr/bin/osascript << EOF
display notification "$MESSAGE" with title "$TITLE" subtitle "$SUBTITLE" sound name "$SOUND"
EOF
else
    /usr/bin/osascript << EOF
display notification "$MESSAGE" with title "$TITLE" sound name "$SOUND"
EOF
fi

exit 0
