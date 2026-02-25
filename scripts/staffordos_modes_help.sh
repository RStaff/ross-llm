#!/usr/bin/env bash
cat << 'MSG'
StaffordOS v1.2 – Runtime Modes

Core commands:
  ross          – raw Ross-LLM (router + profiles)
  ross-health   – quick health check
  ross-deep-health – health + metrics
  ross-metrics  – usage metrics

Behavioral overlays:
  ross-cbt      – CBT Debug Mode (S/T/E/B/R)
  ross-ooda     – OODA decision mode
  ross-freeze   – Freeze Override (body + micro-action)
  ross-lash     – Lash-Out Containment
  ross-parts    – Parts Router (CEO-Ross + safety)

Use these when:
  - Nervous system is fried → ross-freeze
  - You’re about to send heat → ross-lash
  - You’re spiraling → ross-cbt
  - Big choice → ross-ooda
  - Identity conflict / inner tug-of-war → ross-parts
MSG
