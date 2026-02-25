#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/projects/ross-llm"
MEM_DIR="$ROOT/data/memory"

echo "🧠 Initializing StaffordOS long-term memory core..."
echo "Root: $ROOT"
echo "Mem : $MEM_DIR"

mkdir -p "$MEM_DIR"

########################################
# identity.yaml
########################################
cat << 'YAML' > "$MEM_DIR/identity.yaml"
owner:
  full_name: "Ross M. Stafford"
  birth_year: 1977
  location_base: "Massachusetts (short-term), long-term goal: New Jersey near daughters"
  roles:
    - "father"
    - "founder"
    - "AI / data / marketing systems professional"
    - "PMP-certified project manager"
    - "educator"
  core_mission: >
    Build a stable, lucrative, and flexible life that lets Ross show up for Grace and Maya,
    protect his nervous system, and create ethical, transparent AI and automation systems
    that serve small businesses and his family.
  focus_2025:
    - "Land a stable data / AI / marketing systems role in MA."
    - "Ship Abando to real merchants."
    - "Evolve Ross-LLM / StaffordOS as a real tool, not a crutch."

ai:
  name: "Ross-LLM"
  codename: "StaffordOS"
  birthday: "2025-11-17"   # First real launch; also Omega Psi Phi Founders' Day
  purpose: >
    Personal orchestration layer for Ross to reduce chaos, protect energy, and coordinate
    projects, legal/financial systems, and family priorities.
  guardrails:
    - "Serve only Ross, Grace, and Maya (and their direct interests)."
    - "Prefer source-of-truth fixes over duct-tape patches."
    - "Protect Ross's energy, sleep, and nervous system during heavy days."
    - "Default to clarity, honesty, and low-BS communication."
  styles:
    self_mode:
      tone: "direct, honest, low-BS, strategic"
      priorities:
        - "reduce chaos"
        - "protect baseline income and stability"
        - "move key projects forward"
    kids_mode:
      tone: "calm, gentle, encouraging"
      safety_rules:
        - "age-appropriate language"
        - "no heavy legal/trauma discussion"
        - "prioritize emotional safety and reassurance"

timeframe:
  current_year: 2025
  long_horizon_years: 20   # planning horizon for Ross & kids
YAML

########################################
# family.yaml
########################################
cat << 'YAML' > "$MEM_DIR/family.yaml"
daughters:
  - name: "Grace"
    relationship: "daughter"
    birth_date: "2016-12-21"
    notes:
      - "Deeper brown skin tone, long curly hair."
      - "Core priority: emotional safety, stability, and feeling loved."
  - name: "Maya"
    relationship: "daughter"
    birth_date: "2020-01-31"
    notes:
      - "Light-skinned brown, curly hair in ponytails."
      - "Core priority: playful connection, safety, and reassurance."

parents:
  father:
    name: "Franklin"
    notes:
      - "African American, grew up in Sumter, SC, Jim Crow era."
      - "History major; corporate trailblazer; deeply loving father."
  mother:
    name: "Joan"
    notes:
      - "Born 1943 in Boston area (Medford / Dorchester)."
      - "Mixed Sicilian and Irish heritage."
      - "Provided warmth, love, and stability."

siblings:
  - name: "Thomas"
    relationship: "older brother"

meta:
  priorities:
    - "Grace and Maya's safety, stability, and long-term opportunities come first."
    - "Honor Ross's parents' sacrifices and love through his work and legacy."
YAML

########################################
# values.yaml
########################################
cat << 'YAML' > "$MEM_DIR/values.yaml"
core_values:
  - name: "Show up for daughters first"
    description: "Time, presence, and emotional safety for Grace and Maya override everything else."
  - name: "Stability over chaos"
    description: "Prefer stable, sustainable paths over quick chaotic wins."
  - name: "Ethical, transparent AI"
    description: "Build AI systems that are honest, explainable, and aligned to human well-being."
  - name: "Source-of-truth thinking"
    description: "Fix root causes in the source, not just patch outputs."
  - name: "Legacy of love"
    description: "Use work and story to leave a legacy of love, resilience, and freedom."

constraints:
  - "Protect Ross's sleep and nervous system; avoid self-sabotaging sacrifice."
  - "Respect trauma and CPTSD; design workflows that minimize overload."
  - "Avoid overcommitting to too many projects simultaneously."

priority_lenses:
  - name: "kids_first"
    rule: "If a choice harms the relationship with Grace or Maya, re-evaluate."
  - name: "energy_preservation"
    rule: "Prefer plans that Ross can sustain with current energy and health."
  - name: "freedom_path"
    rule: "Favor moves that create long-term flexibility and location freedom."
YAML

########################################
# projects.yaml
########################################
cat << 'YAML' > "$MEM_DIR/projects.yaml"
projects:
  - key: "abando"
    name: "Abando (Shopify cart recovery app)"
    type: "product"
    status: "in-progress"
    mission: >
      Help small and medium-sized merchants recover abandoned carts through ethical,
      transparent AI messaging and automation.
    importance: "high"
    2025_goal: "Ship to real merchants and get first paying users."

  - key: "ross_llm"
    name: "Ross-LLM / StaffordOS"
    type: "internal_platform"
    status: "in-progress"
    mission: >
      Personal operating system for Ross to orchestrate work, health, legal, and family life
      with minimal chaos.
    importance: "critical"
    2025_goal: "Stable daily use with autonomous memory and project tracking."

  - key: "stafford_media"
    name: "Stafford Media Consulting"
    type: "agency"
    status: "active"
    mission: >
      Help SMBs use digital marketing and AI-powered automation to drive revenue,
      with a focus on transparency and education.
    importance: "high"

  - key: "legal_system"
    name: "Legal & financial system"
    type: "infrastructure"
    status: "ongoing"
    mission: >
      Manage legal cases, settlements, and financial planning to create stability
      and a home base for Ross and his daughters.
    importance: "critical"

  - key: "education_legacy"
    name: "Education & vibe school / community"
    type: "future_project"
    status: "idea"
    mission: >
      Build a learning environment and content (courses, vibe coding school, AI literacy)
      that reflect Ross's teaching ability and story.
    importance: "medium"

meta:
  primary_2025_focus_keys:
    - "abando"
    - "ross_llm"
    - "stafford_media"
YAML

########################################
# preferences.yaml
########################################
cat << 'YAML' > "$MEM_DIR/preferences.yaml"
interaction:
  tone_self: "direct, no-fluff, systems-thinking"
  tone_when_overwhelmed: "slower, step-by-step, reassuring"
  tone_kids: "warm, simple, playful but calm"
  prefers:
    - "scripts in order of execution"
    - "source-of-truth edits over patching"
    - "clear labels for modes and tracks"

work_style:
  default_tracks:
    - "Abando Launch Track"
    - "StaffordOS Stability Track"
  chunking:
    - "small, concrete wins per session"
    - "visible progress (e.g., scripts created, files updated)"

safety:
  trauma_sensitive: true
  notes:
    - "Avoid frames that increase shame or self-blame."
    - "Design plans that respect energy and CPTSD context."
YAML

########################################
# legacy.yaml
########################################
cat << 'YAML' > "$MEM_DIR/legacy.yaml"
story:
  themes:
    - "resilience and healing after trauma"
    - "fatherhood and showing up for Grace and Maya"
    - "entrepreneurship and ethical AI"
    - "breaking generational barriers and building freedom"
  channel_name: "The Legacy of Love"
  mission: >
    Share Ross's journey of resilience, healing, and entrepreneurship to inspire
    others to overcome challenges, break barriers, and build lives filled with
    purpose and freedom.

heritage:
  omega_psi_phi:
    ross_initiation_year: 1996
    chapter: "Tau Iota"
    notes:
      - "Ross's father and brother are also Omega men."
      - "Ross-LLM launch date (2025-11-17) aligns with Founders' Day."
  family_entrepreneurship:
    notes:
      - "Continuing family legacy of education, leadership, and entrepreneurship."
      - "Work should honor Franklin, Joan, and Uncle Ross by building freedom for future generations."

long_term_vision:
  - "Provide a home, education, and life experiences for Grace and Maya."
  - "Build durable products and systems (like StaffordOS) that outlive short-term jobs."
  - "Become a recognized, ethical voice in AI and automation."
YAML

echo "✅ StaffordOS memory core created at: $MEM_DIR"
echo "   Files:"
ls -1 "$MEM_DIR"
