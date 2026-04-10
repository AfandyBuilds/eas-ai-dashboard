"""
Offline demo of the ChatLog — no API calls, no API key required.

Replays a scripted run of a CR ("Leaderboard CSV export") so you can see
exactly what the multi-agent conversation looks like before paying for a
real Claude run. Drives ChatLog directly with hand-crafted agent lines
that mimic the kind of output the real agents produce.

Usage:
    cd multi-agent-system
    python examples/demo_chat.py
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.chat_log import ChatLog  # noqa: E402

PAUSE = 0.35  # seconds between beats — lower to 0 for a dump, raise for drama


def beat(seconds: float = PAUSE) -> None:
    time.sleep(seconds)


def main() -> None:
    transcript = ROOT / "docs" / "cr" / "CR-DEMO-leaderboard-csv-export" / "chat_transcript.md"
    chat = ChatLog(transcript_path=transcript)

    chat.meta("Kick-off — CR: Leaderboard CSV export")
    chat.meta(
        "Intent: Practice SPOCs need to download their leaderboard as CSV every "
        "week to paste into their own status reports."
    )
    beat(0.6)

    # -------------------- Stage 1: Business --------------------
    chat.stage("DRAFT_BRD", "Mariam takes the ask and drafts a BRD")
    beat()
    chat.say(
        "business_agent",
        "Thanks team. I hear this one from SPOCs every Sunday — they screenshot "
        "the leaderboard into their weekly decks. Let me reopen the current BRD "
        "so I stay consistent with the scope we already signed off.",
    )
    chat.tool("business_agent", "read_file", {"path": "docs/BRD.md"})
    chat.tool_result("business_agent", "read_file", "…(~420 lines of BRD)…")
    beat()
    chat.say(
        "business_agent",
        "Okay, this fits under the Leaderboard & Gamification section. Drafting "
        "a new functional requirement block with acceptance criteria now.",
    )
    chat.tool(
        "business_agent",
        "write_file",
        {"path": "docs/cr/CR-DEMO-leaderboard-csv-export/BRD-draft.md", "content": "# CR …"},
    )
    chat.tool_result("business_agent", "write_file", "Wrote 3412 bytes to docs/cr/CR-DEMO-leaderboard-csv-export/BRD-draft.md")
    beat()
    chat.say(
        "business_agent",
        "Draft saved. KPIs: SPOCs produce weekly reports without manual retyping. "
        "Handing over to Sarah to turn this into a SOW.",
    )
    beat()
    chat.meta("Nadia is reviewing the BRD-draft.md …")
    beat(0.5)
    chat.verdict("supervisor_agent", "APPROVE", "Scope is tight, acceptance criteria are testable, fits the existing leaderboard feature.")
    beat(0.5)

    # -------------------- Stage 2: BA --------------------
    chat.stage("SOW", "Sarah sizes the work and writes the SOW")
    beat()
    chat.say(
        "ba_agent",
        "Picking up the draft BRD. One thing I want to nail down before I estimate: "
        "do we need this export scoped per-practice or should Admins be able to "
        "export all practices at once? Mariam, can you confirm?",
    )
    chat.tool("ba_agent", "read_file", {"path": "docs/cr/CR-DEMO-leaderboard-csv-export/BRD-draft.md"})
    chat.tool_result("ba_agent", "read_file", "…")
    beat()
    chat.say(
        "ba_agent",
        "Re-reading the BRD, the acceptance criteria implicitly cover both cases. "
        "I'll document that assumption in the SOW and flag it for the SA. "
        "Effort-wise I'm guessing 1.5 days — utility function + button + tests.",
    )
    chat.tool("ba_agent", "write_file", {"path": "docs/cr/CR-DEMO-leaderboard-csv-export/SOW.md", "content": "# SOW …"})
    chat.tool_result("ba_agent", "write_file", "Wrote 2180 bytes to docs/cr/CR-DEMO-leaderboard-csv-export/SOW.md")
    beat()
    chat.verdict("supervisor_agent", "APPROVE", "Effort and RACI are realistic; assumption is captured.")
    beat(0.5)

    # -------------------- Stage 3: SA --------------------
    chat.stage("HLD", "Karim challenges the ask and writes the HLD")
    beat()
    chat.say(
        "sa_agent",
        "Before I design anything — is there already a CSV export somewhere in "
        "the codebase I can reuse? Let me check.",
    )
    chat.tool("sa_agent", "grep_search", {"pattern": "export.*csv", "path": "js"})
    chat.tool_result("sa_agent", "grep_search", "js/db.js:612: // TODO CSV export for tasks")
    beat()
    chat.say(
        "sa_agent",
        "Nice — there's a TODO in db.js from when we added the tasks export. "
        "We should factor that into a shared util in js/utils.js so leaderboard "
        "and tasks both use the same code path. No SQL changes needed; this is "
        "pure client-side. LOW complexity. Writing the HLD now.",
    )
    chat.tool("sa_agent", "write_file", {"path": "docs/cr/CR-DEMO-leaderboard-csv-export/HLD.md", "content": "# HLD …"})
    chat.tool_result("sa_agent", "write_file", "Wrote 2956 bytes to docs/cr/CR-DEMO-leaderboard-csv-export/HLD.md")
    beat()
    chat.verdict("supervisor_agent", "APPROVE", "Good reuse, no data-model changes, matches CODE_ARCHITECTURE.md.")
    beat(0.5)

    # -------------------- Stage 4: Dev Lead --------------------
    chat.stage("DEV", "Ahmed implements the change")
    beat()
    chat.say(
        "dev_lead_agent",
        "HLD looks clean. I'll put the shared helper in js/utils.js as "
        "`exportToCSV(rows, filename)` and wire it into the leaderboard export "
        "button. Let me see the current utils module first.",
    )
    chat.tool("dev_lead_agent", "read_file", {"path": "js/utils.js"})
    chat.tool_result("dev_lead_agent", "read_file", "got it — ~318 lines")
    beat()
    chat.tool("dev_lead_agent", "edit_file", {
        "path": "js/utils.js",
        "old_text": "// ---- end of utils ----",
        "new_text": "function exportToCSV(rows, filename) { /* … */ }\n// ---- end of utils ----",
    })
    chat.tool_result("dev_lead_agent", "edit_file", "Edited js/utils.js — replaced 1 occurrence.")
    beat()
    chat.tool("dev_lead_agent", "edit_file", {
        "path": "index.html",
        "old_text": "<!-- leaderboard-actions -->",
        "new_text": "<!-- leaderboard-actions -->\n  <button id=\"export-leaderboard\">Export CSV</button>",
    })
    chat.tool_result("dev_lead_agent", "edit_file", "Edited index.html — replaced 1 occurrence.")
    beat()
    chat.tool("dev_lead_agent", "bash", {"command": "node -c js/utils.js && echo OK"})
    chat.tool_result("dev_lead_agent", "bash", "OK")
    beat()
    chat.say(
        "dev_lead_agent",
        "Syntax check passes. Writing up the patch summary with every file "
        "I touched and the reasoning so Layla can review it.",
    )
    chat.tool("dev_lead_agent", "write_file", {"path": "docs/cr/CR-DEMO-leaderboard-csv-export/PATCH.md", "content": "# PATCH …"})
    chat.tool_result("dev_lead_agent", "write_file", "Wrote 1744 bytes to docs/cr/CR-DEMO-leaderboard-csv-export/PATCH.md")
    beat()
    chat.verdict("supervisor_agent", "APPROVE", "Touched files match the HLD scope; no secrets exposed.")
    beat(0.5)

    # -------------------- Stage 5: Quality --------------------
    chat.stage("QA", "Layla reviews the patch")
    beat()
    chat.say(
        "quality_agent",
        "Looking at PATCH.md then reading the actual files Ahmed touched.",
    )
    chat.tool("quality_agent", "read_file", {"path": "docs/cr/CR-DEMO-leaderboard-csv-export/PATCH.md"})
    chat.tool_result("quality_agent", "read_file", "got it — ~42 lines")
    chat.tool("quality_agent", "read_file", {"path": "js/utils.js"})
    chat.tool_result("quality_agent", "read_file", "got it — ~340 lines")
    beat()
    chat.say(
        "quality_agent",
        "Overall the code is clean — but `exportToCSV` is building the file "
        "with string concatenation. If a practice name contains a comma or quote "
        "it will corrupt the CSV. Need proper escaping. Also the function lacks "
        "a JSDoc block, which is inconsistent with the rest of utils.js.\n\n"
        "Verdict: FAIL — two Medium findings, kicking back to Ahmed.",
    )
    beat()
    chat.verdict("supervisor_agent", "REJECT", "QA flagged a CSV-escaping bug — Dev Lead must re-open.")
    beat(0.5)

    # -------------------- Re-run Dev --------------------
    chat.meta("Dev Lead — retry #1")
    beat()
    chat.say(
        "dev_lead_agent",
        "Fair point Layla — fixing. I'll wrap every field in quotes and "
        "escape internal quotes. Adding the JSDoc block too.",
    )
    chat.tool("dev_lead_agent", "edit_file", {
        "path": "js/utils.js",
        "old_text": "function exportToCSV(rows, filename) { /* … */ }",
        "new_text": "/** Export rows to CSV with RFC-4180 escaping. */\nfunction exportToCSV(rows, filename) { /* … */ }",
    })
    chat.tool_result("dev_lead_agent", "edit_file", "Edited js/utils.js — replaced 1 occurrence.")
    beat()
    chat.verdict("supervisor_agent", "APPROVE", "Fixes address both findings.")
    beat(0.3)
    chat.meta("Layla re-runs QA …")
    beat(0.3)
    chat.say("quality_agent", "Both issues are resolved. Verdict: PASS.")
    chat.verdict("supervisor_agent", "APPROVE", "Moving to testing.")
    beat(0.5)

    # -------------------- Stage 6: Testing --------------------
    chat.stage("TEST", "Youssef writes and runs the test plan")
    beat()
    chat.say(
        "testing_agent",
        "I'll derive cases from the BRD acceptance criteria. Positive, negative, "
        "role-matrix, and an edge case for a practice name that contains a comma "
        "(which is exactly what Layla caught).",
    )
    chat.tool("testing_agent", "write_file", {"path": "docs/cr/CR-DEMO-leaderboard-csv-export/TestPlan.md", "content": "# TestPlan …"})
    chat.tool_result("testing_agent", "write_file", "Wrote 2810 bytes to docs/cr/CR-DEMO-leaderboard-csv-export/TestPlan.md")
    beat()
    chat.say(
        "testing_agent",
        "12 cases — all pass in manual execution. No defects to raise. "
        "Verdict: PASS.",
    )
    chat.verdict("supervisor_agent", "APPROVE", "Solid coverage; clearing for consolidation.")
    beat(0.5)

    # -------------------- Consolidation --------------------
    chat.stage("CONSOLIDATION", "Nadia updates the canonical docs")
    beat()
    chat.say(
        "supervisor_agent",
        "Appending the change log entry to docs/BRD.md, the frontend delta "
        "to docs/HLD.md, and a new milestone line to docs/IMPLEMENTATION_PLAN.md. "
        "Run log at docs/cr/CR-DEMO-leaderboard-csv-export/RUN-LOG.md. Nicely done, team — this is a "
        "clean CR from intent to merge in one pass plus one revision.",
    )
    beat()
    chat.meta("✓ Pipeline complete")

    saved = chat.save()
    if saved:
        print(f"\nTranscript saved to: {saved}")


if __name__ == "__main__":
    main()
