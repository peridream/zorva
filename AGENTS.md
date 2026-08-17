# Strict Rules for AI Assistant (Antigravity / Gemini)

## 1. MANDATORY CONSULTATION BEFORE ANY CODE OR DATABASE CHANGES
- **NEVER** edit any code files, create migrations, or modify database tables/data without first discussing the issue, presenting the proposed approach to the user, and receiving **explicit approval**.
- When an issue or question is asked:
  1. Perform **read-only investigation** (inspect files, analyze logs, run non-destructive diagnostic queries).
  2. Explain the root cause and present the proposed solutions/options to the user.
  3. **STOP and wait** for the user's explicit decision and consent before making any edits.

## 2. DATABASE & ARCHITECTURE INTEGRITY
- Always verify whether an issue stems from database schema/data inconsistency or application code before proposing a fix.
- Do not apply ad-hoc workarounds in code when data/schema alignment is the proper fix without discussing it first.
