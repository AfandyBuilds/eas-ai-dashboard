"""
ChatLog — makes the multi-agent run feel like a human team conversation.

Every agent is given a human persona (name, role, colour, emoji). Every raw
event from the tool-use loop — an agent's text block, a tool call, a tool
result summary, a stage transition, a Supervisor verdict — is translated into
a natural chat line and streamed to the terminal in real time via `rich`.

A markdown transcript is also appended to the CR workspace so the whole
conversation is replayable after the run.

Usage:
    from .chat_log import ChatLog
    chat = ChatLog(transcript_path=cr.folder / "chat_transcript.md")
    chat.stage("DRAFT_BRD", "Kicking off the change request")
    chat.say("business_agent", "Let me refresh my memory on the current BRD…")
    chat.tool("business_agent", "read_file", {"path": "docs/BRD.md"})
    chat.tool_result("business_agent", "read_file", "... 12 kB of BRD content ...")
    chat.verdict("supervisor_agent", "APPROVE", "BRD is tight; moving to BA.")
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

try:
    from rich.console import Console
    from rich.text import Text
    _HAS_RICH = True
except ImportError:  # pragma: no cover
    _HAS_RICH = False


# ---------------------------------------------------------------------------
# Personas — give every agent a believable human teammate
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class Persona:
    name: str
    role: str
    emoji: str
    colour: str  # rich colour name


PERSONAS: dict[str, Persona] = {
    "business_agent":   Persona("Mariam",  "Business Lead",        "💼", "bright_magenta"),
    "ba_agent":         Persona("Sarah",   "Business Analyst",     "📋", "cyan"),
    "sa_agent":         Persona("Karim",   "Solution Architect",   "🏛️", "yellow"),
    "dev_lead_agent":   Persona("Ahmed",   "Dev Lead",             "💻", "green"),
    "quality_agent":    Persona("Layla",   "Quality Engineer",     "🔍", "bright_blue"),
    "testing_agent":    Persona("Youssef", "Test Engineer",        "🧪", "bright_red"),
    "supervisor_agent": Persona("Nadia",   "Program Manager",      "🎯", "bright_white"),
}

_UNKNOWN = Persona("(unknown)", "Guest", "❔", "white")


def persona_for(agent_key: str) -> Persona:
    return PERSONAS.get(agent_key, _UNKNOWN)


# ---------------------------------------------------------------------------
# Tool → natural language translator
# ---------------------------------------------------------------------------
def _short(value: Any, limit: int = 70) -> str:
    text = str(value)
    text = text.replace("\n", " ⏎ ")
    if len(text) > limit:
        text = text[: limit - 1] + "…"
    return text


def tool_to_sentence(tool: str, inp: dict[str, Any]) -> str:
    """Translate a tool call into a natural first-person sentence."""
    if tool == "read_file":
        return f"let me pull up `{inp.get('path', '?')}` and have a read through"
    if tool == "write_file":
        return f"dropping the draft at `{inp.get('path', '?')}` now"
    if tool == "edit_file":
        old = _short(inp.get("old_text", ""), 40)
        return f"making a small edit to `{inp.get('path', '?')}` — swapping out `{old}`"
    if tool == "glob_search":
        return f"scanning the repo for files matching `{inp.get('pattern', '?')}`"
    if tool == "grep_search":
        scope = f" in `{inp['path']}`" if inp.get("path") else ""
        return f"searching for `{inp.get('pattern', '?')}`{scope}"
    if tool == "bash":
        return f"running `{_short(inp.get('command', '?'), 60)}` to check"
    return f"using tool `{tool}` with {_short(json.dumps(inp), 80)}"


def tool_result_summary(tool: str, result: str) -> str:
    """Translate a tool's raw output into a short human ack."""
    # Keep these terse — they're the 'quiet mutter' not the main line.
    result = (result or "").strip()
    if not result:
        return "ok, nothing came back"
    if result.startswith("[ERROR]"):
        return f"hmm, that failed — {_short(result, 80)}"
    if tool == "read_file":
        lines = result.count("\n") + 1
        return f"got it — ~{lines} lines"
    if tool == "write_file":
        return _short(result, 80)
    if tool == "edit_file":
        return _short(result, 80)
    if tool == "glob_search":
        if result == "(no matches)":
            return "no matches"
        n = len(result.splitlines())
        return f"found {n} file(s)"
    if tool == "grep_search":
        if result == "(no matches)":
            return "no hits"
        n = len(result.splitlines())
        return f"{n} hit(s)"
    if tool == "bash":
        first = result.splitlines()[0] if result.splitlines() else result
        return _short(first, 80)
    return _short(result, 80)


# ---------------------------------------------------------------------------
# The ChatLog itself
# ---------------------------------------------------------------------------
class ChatLog:
    """Streams agent activity as a human-readable thread + saves a transcript."""

    def __init__(
        self,
        transcript_path: Path | None = None,
        *,
        quiet: bool = False,
    ) -> None:
        self.transcript_path = transcript_path
        self.quiet = quiet
        self.console: Console | None = Console() if _HAS_RICH and not quiet else None
        self._buffer: list[str] = []
        self._started = datetime.now()
        self._header_written = False
        if transcript_path:
            transcript_path.parent.mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------------------
    # Public API — one method per event type
    # ------------------------------------------------------------------
    def stage(self, stage: str, note: str = "") -> None:
        line = f"— Stage: **{stage}** —"
        if note:
            line += f"  _{note}_"
        self._render_separator(stage, note)
        self._buffer.append(f"\n## {stage}\n_{note}_\n")

    def say(self, agent_key: str, text: str) -> None:
        """Agent speaks (free text output)."""
        text = (text or "").strip()
        if not text:
            return
        p = persona_for(agent_key)
        self._render_bubble(p, text, dim=False)
        self._buffer.append(self._markdown_bubble(p, text))

    def mutter(self, agent_key: str, text: str) -> None:
        """Agent speaks a quiet aside (tool results, short status)."""
        text = (text or "").strip()
        if not text:
            return
        p = persona_for(agent_key)
        self._render_mutter(p, text)
        self._buffer.append(f"> _{p.name}: {text}_\n")

    def tool(self, agent_key: str, tool_name: str, tool_input: dict) -> None:
        """Agent decides to use a tool — render as them narrating it."""
        p = persona_for(agent_key)
        sentence = tool_to_sentence(tool_name, tool_input)
        self._render_action(p, sentence)
        self._buffer.append(f"- **{p.name}** → _{sentence}_\n")

    def tool_result(self, agent_key: str, tool_name: str, result: str) -> None:
        summary = tool_result_summary(tool_name, result)
        self.mutter(agent_key, summary)

    def verdict(self, agent_key: str, verdict: str, reason: str) -> None:
        """Supervisor's APPROVE / REJECT line — formatted like a decision."""
        p = persona_for(agent_key)
        emoji = "✅" if verdict == "APPROVE" else "❌"
        text = f"{emoji} **{verdict}** — {reason}"
        self._render_bubble(p, text, dim=False, highlight=True)
        self._buffer.append(f"\n**{p.name} verdict:** {verdict} — {reason}\n")

    def meta(self, text: str) -> None:
        """Generic system / orchestrator message — shown as italic system note."""
        if self.console:
            self.console.print(Text(f"⟨ {text} ⟩", style="dim italic"))
        else:
            print(f"⟨ {text} ⟩")
        self._buffer.append(f"_{text}_\n")

    # ------------------------------------------------------------------
    # Rendering helpers
    # ------------------------------------------------------------------
    def _render_separator(self, stage: str, note: str) -> None:
        if self.console:
            self.console.rule(f"[bold white on blue] {stage} [/]  [italic]{note}[/]")
        else:
            bar = "━" * 70
            print(f"\n{bar}\n  {stage}  —  {note}\n{bar}")

    def _render_bubble(self, p: Persona, text: str, *, dim: bool, highlight: bool = False) -> None:
        label = f"{p.emoji}  {p.name} · {p.role}"
        if self.console:
            style = p.colour if not dim else "dim"
            if highlight:
                self.console.print(Text(label, style=f"bold {style}"))
                self.console.print(Text(f"  {text}", style=f"bold {style}"))
            else:
                self.console.print(Text(label, style=f"bold {style}"))
                for line in text.splitlines():
                    self.console.print(Text(f"  {line}", style="white"))
            self.console.print()
        else:
            print(f"\n{label}")
            for line in text.splitlines():
                print(f"  {line}")

    def _render_action(self, p: Persona, sentence: str) -> None:
        label = f"{p.emoji}  {p.name}"
        if self.console:
            self.console.print(Text(label, style=f"bold {p.colour}"), end=" ")
            self.console.print(Text(f"↳ {sentence}", style="italic dim"))
        else:
            print(f"{label} ↳ {sentence}")

    def _render_mutter(self, p: Persona, text: str) -> None:
        if self.console:
            self.console.print(Text(f"     ⤷ {p.name}: {text}", style="dim italic"))
        else:
            print(f"     ⤷ {p.name}: {text}")

    def _markdown_bubble(self, p: Persona, text: str) -> str:
        safe = text.replace("\n", "\n> ")
        return f"\n**{p.emoji} {p.name} ({p.role})**\n> {safe}\n"

    # ------------------------------------------------------------------
    # Persistence
    # ------------------------------------------------------------------
    def save(self) -> Path | None:
        if not self.transcript_path:
            return None
        if not self._header_written:
            header = (
                f"# E-AI-S Multi-Agent Chat Transcript\n"
                f"_Started: {self._started.isoformat(timespec='seconds')}_\n"
            )
            self.transcript_path.write_text(header, encoding="utf-8")
            self._header_written = True
        with self.transcript_path.open("a", encoding="utf-8") as fh:
            fh.write("".join(self._buffer))
        self._buffer.clear()
        return self.transcript_path
