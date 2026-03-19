import re
import uuid


def markdown_to_adf(markdown: str) -> dict:
    """Convert a subset of Markdown to Atlassian Document Format (ADF)."""
    lines = markdown.splitlines()
    content = []
    i = 0

    while i < len(lines):
        line = lines[i]

        if not line.strip():
            i += 1
            continue

        # Headings
        heading_match = re.match(r'^(#{1,6})\s+(.*)', line)
        if heading_match:
            level = len(heading_match.group(1))
            content.append({
                "type": "heading",
                "attrs": {"level": level},
                "content": [{"type": "text", "text": heading_match.group(2).strip()}],
            })
            i += 1
            continue

        # Task list items — collect consecutive ones into a single taskList node
        if re.match(r'^-\s+\[[ x]\]', line):
            task_items = []
            while i < len(lines) and re.match(r'^-\s+\[[ x]\]', lines[i]):
                m = re.match(r'^-\s+\[( |x)\]\s+(.*)', lines[i])
                state = "DONE" if m.group(1) == "x" else "TODO"
                task_items.append({
                    "type": "taskItem",
                    "attrs": {"localId": str(uuid.uuid4()), "state": state},
                    "content": [{"type": "text", "text": m.group(2).strip()}],
                })
                i += 1
            content.append({
                "type": "taskList",
                "attrs": {"localId": str(uuid.uuid4())},
                "content": task_items,
            })
            continue

        # Bullet list items — collect consecutive ones into a single bulletList node
        if re.match(r'^-\s+', line):
            items = []
            while i < len(lines) and re.match(r'^-\s+', lines[i]) and not re.match(r'^-\s+\[', lines[i]):
                m = re.match(r'^-\s+(.*)', lines[i])
                items.append({
                    "type": "listItem",
                    "content": [{
                        "type": "paragraph",
                        "content": [{"type": "text", "text": m.group(1).strip()}],
                    }],
                })
                i += 1
            content.append({"type": "bulletList", "content": items})
            continue

        # Fallback: plain paragraph
        content.append({
            "type": "paragraph",
            "content": [{"type": "text", "text": line.strip()}],
        })
        i += 1

    return {"version": 1, "type": "doc", "content": content}
