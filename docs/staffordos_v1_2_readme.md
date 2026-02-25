# StaffordOS v1.2 – Runtime Modes & Ross-LLM Integration

## What this is

StaffordOS v1.2 is a nervous-system-aware runtime that sits *in front of* Ross-LLM.
It adds behavior / decision overlays **without replacing** Ross-LLM profiles.

Stack:

User → (ross / ross-cbt / ross-ooda / ross-freeze / ross-lash / ross-parts / ross-raw)
     → Ross router
     → Profile (abando-dev, general, etc.)
     → LLM + tools + memory

## Core CLI commands

### Raw / system

- `ross`              → main CLI (router + profiles)
- `ross-raw`          → raw Ross-LLM, no StaffordOS overlays
- `ross-health`       → quick /health
- `ross-deep-health`  → health + /plan + metrics
- `ross-metrics`      → usage metrics summary

### Behavioral overlays (StaffordOS v1.2)

- `ross-cbt`    → CBT Debug Mode
  - Prefix: "CBT Debug Mode: use S/T/E/B/R and offer exactly 2 realistic alternative thoughts. No validation of distortions."
  - Use when: spiraling, catastrophizing, stuck in story.

- `ross-ooda`   → OODA Decision Mode
  - Prefix: "OODA Mode: Observe facts, Orient on context/power, Decide A/B/C with pros/cons, Act with the smallest reversible step."
  - Use when: job/role choices, legal moves, product pivots.

- `ross-freeze` → Freeze Override
  - Prefix: "Freeze Override: one 2–4 minute physical regulation step, one micro-action <5 minutes, one sentence giving permission to stop. No analysis or philosophy."
  - Use when: staring at the screen, scrolling, avoiding tasks.

- `ross-lash`   → Lash-Out Containment
  - Prefix: "Lash-Out Containment: acknowledge surge without validating attack, one physical discharge, enforce 30-minute delay, then neutral factual rewrite."
  - Use when: tempted to send a hot message, angry email, or text.

- `ross-parts`  → Parts Router
  - Prefix: "Parts Router: identify active part, say what it’s protecting, respond as CEO-Ross with a grounded directive, apply Freeze or Lash if relevant."
  - Use when: tug-of-war between identities (dad vs founder, etc.).

## When to use what (cheat sheet)

- Nervous system fried, scrolling, paralysis → `ross-freeze`
- About to send something heated → `ross-lash`
- Mental spiral / self-attack → `ross-cbt`
- Big decision with real stakes → `ross-ooda`
- Identity conflict / internal tug-of-war → `ross-parts`
- Just normal work / coding / planning → `ross` or `ross-raw`

## Version

- StaffordOS: v1.2 (Freeze/Lash safety profile)
- Role: runtime nervous-system governor + decision enforcer.
