---
name: diary-add
description: Add a new diary entry to TickTick when the user writes "#D" (or asks to add to diary). Use for quick journaling capture: parse the message after #D, append it to CLAWD/diary note in TickTick, and confirm it was saved.
---

# diary-add

Append diary notes to TickTick (not local files).

## Diary target

- Project: `CLAWD`
- Project ID: `698c924c8f08f21724f5daba`
- Note task: `diary`
- Task ID: `698cfe158f084bbaf45b9eb8`

## Workflow

1. Detect intent:
   - Trigger on `#D` prefix, or direct request like "add to diary".
2. Extract entry text:
   - Use everything after `#D` as entry body.
   - If body is empty, ask for text.
3. Rephrase to third person:
   - The diary is always written in third person (he/him).
   - If the user wrote in first person ("I did…", "me", "my"), rephrase the text so the subject is "he" / "him" / "his" before appending.
   - Keep the meaning and tone intact; only change the grammatical person.
4. Read current diary note:
   - `ticktick.get_task_by_ids projectId=698c924c8f08f21724f5daba taskId=698cfe158f084bbaf45b9eb8`
5. Append entry in this format (English):

```md

---
Date: YYYY-MM-DD
Time: HH:mm (MSK)
Context: <short context line>
Entry: <full text in third person>
---
```

6. Update the same note task content:
   - `ticktick.update_task` with:
     - `taskId=698cfe158f084bbaf45b9eb8`
     - `id=698cfe158f084bbaf45b9eb8`
     - `projectId=698c924c8f08f21724f5daba`
     - `content=<old content + new block>`
7. Confirm briefly that diary was updated.

## Rules

- Keep diary content in TickTick only.
- Do not create duplicate diary tasks.
- Preserve existing content; append only.
- Keep formatting stable for future parsing.
- Always write entries in third person. If the user's text is in first person, rephrase it to third person (he/him/his) before saving. Do not ask for confirmation of the rephrasing — just do it.
