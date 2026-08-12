# ⚡ Zorva System Architecture & High-Level Design

## 1. Executive Overview

**Zorva** is a real-time competitive sports passport and multi-context rating platform. It enables players across cities to log match results, verify scores peer-to-peer, track dynamic Glicko/Elo ratings across multiple game contexts (**Official/Flagship** vs. **Community**), and maintain an official digital sports passport.

---

## 2. High-Level Architecture Diagram

```mermaid
graph TD
    subgraph Client Layer
        A[Flutter Web App]
        B[Flutter Mobile App - iOS/Android]
    end

    subgraph API & Logic Layer
        C[FastAPI Backend Server - Uvicorn]
        C1[/insights Endpoint/]
        C2[/subscriptions Endpoint/]
        C3[/rankings Endpoint/]
        C4[/matches Endpoint/]
        C --> C1
        C --> C2
        C --> C3
        C --> C4
    end

    subgraph Platform & Data Layer
        D[(Supabase PostgreSQL)]
        E[Supabase Auth Service - Email OTP]
    end

    A -->|HTTPS / REST API| C
    B -->|HTTPS / REST API| C
    A -->|Auth & Direct Queries| D
    B -->|Auth & Direct Queries| D
    A -->|OTP Request / Verify| E
    B -->|OTP Request / Verify| E
    C -->|Service Role / Admin SQL| D
```

---

## 3. Core Component Architecture

### A. Frontend Application (`apps/mobile_flutter`)
- **Framework**: Flutter (Dart) targeting Web, iOS, and Android.
- **Design System**: `ZorvaTheme` dark mode aesthetic with glassmorphism gradients and gold visual accents.
- **Key Modules**:
  - **Onboarding Flow**: Single-button entrance (`WelcomeScreen`), dynamic unified email OTP sign-in (`SignInScreen`), and first-time city selection (`CityOnboardingScreen`).
  - **Passport Dashboard (`HomeDashboardScreen`)**:
    - Interactive Header with Clickable User Profile Pill.
    - Verified & Pending Match Lists with sleek height scoping and visual type tags (🏆 **OFFICIAL ⚡** vs. 👥 **COMMUNITY 🎾**).
    - Quick Match Logging modal trigger.
  - **Leaderboards & Insights (`LeaderboardsScreen`)**: City & global rankings by rating context.
  - **Profile (`ProfileScreen`)**: Player statistics, city preferences, and sign-out control with back navigation.

---

### B. Backend REST API (`backend/app`)
- **Framework**: FastAPI (Python 3.11+) hosted via Uvicorn.
- **Key Routes**:
  - `/insights/{user_id}`: Single server-side roundtrip calculating win streaks, form guide, rivalries, and tier-specific context ratings.
  - `/subscriptions/{user_id}`: Tracks subscription tier (`founder_flagship`, `community_trial`) and verified match quotas.
  - `/rankings/{city}`: Evaluates city leaderboard order and percentile positioning.

---

### C. Backend Database & Auth Layer (Supabase)
- **Engine**: PostgreSQL with Row-Level Security (RLS).
- **Authentication**: Passwordless Email OTP with multi-OtpType fallback (`email`, `signup`, `magiclink`) for seamless auto-provisioning.

---

## 4. Database Entity-Relationship Diagram (ERD)

```mermaid
erDiagram
    PROFILES ||--o{ MATCHES : "creates / plays"
    PROFILES ||--o{ PLAYER_CONTEXT_RATINGS : "holds rating"
    PROFILES ||--o{ PREMIUM_SUBSCRIPTIONS : "owns plan"
    MATCHES ||--o{ MATCH_CONTEXT_LINKS : "linked to"
    RATING_CONTEXTS ||--o{ MATCH_CONTEXT_LINKS : "defines context"
    RATING_CONTEXTS ||--o{ PLAYER_CONTEXT_RATINGS : "scoped to"

    PROFILES {
        uuid id PK
        string full_name
        string username
        string email
        string city
        string sport
        datetime created_at
    }

    MATCHES {
        uuid id PK
        uuid creator_id FK
        uuid opponent_id FK
        int creator_score
        int opponent_score
        uuid winner_id FK
        string status
        datetime logged_at
    }

    RATING_CONTEXTS {
        uuid id PK
        string name
        string type
        string sport
    }

    MATCH_CONTEXT_LINKS {
        uuid id PK
        uuid match_id FK
        uuid context_id FK
        datetime created_at
    }

    PLAYER_CONTEXT_RATINGS {
        uuid id PK
        uuid user_id FK
        uuid context_id FK
        float rating
        float rd
        datetime updated_at
    }

    PREMIUM_SUBSCRIPTIONS {
        uuid id PK
        uuid user_id FK
        string plan_id
        string status
        int verified_matches_count
        datetime updated_at
    }
```

---

## 5. End-to-End Data Flows

### Match Logging & Peer Verification Flow

```mermaid
sequenceDiagram
    autonumber
    actor PlayerA as Player A (Creator)
    actor PlayerB as Player B (Opponent)
    participant Client as Flutter App
    participant DB as Supabase DB
    participant API as FastAPI Backend

    PlayerA->>Client: Log Match (Select Opponent B, Score: 11-8)
    Client->>DB: INSERT into `matches` (status: 'pending')
    Client->>DB: INSERT into `match_context_links` (context: 'flagship' / 'community')
    DB-->>Client: Match Created (Pending)

    PlayerB->>Client: Open Passport Dashboard
    Client->>DB: Fetch Pending Matches
    DB-->>Client: Show Incoming Match Confirmation Box

    PlayerB->>Client: Tap "CONFIRM & VERIFY"
    Client->>DB: UPDATE `matches` SET status = 'verified'
    Client->>API: Trigger Async Rating Update
    API->>DB: Update `player_context_ratings` (Glicko Calculation)
    API->>DB: Increment `verified_matches_count` in `premium_subscriptions`
    DB-->>Client: Real-time UI refresh (Verified Match + Updated Rating)
```

---

## 6. Key Design Highlights

1. **Multi-Context Rating Engine**: Separates official tournament/flagship matches from casual community matches so player competitive ratings remain authoritative.
2. **Unified Authentication Experience**: Auto-provisions new users seamlessly while routing existing players directly to their Passport without password complexity.
3. **Performant Layout Architecture**: Scoped 3-match height containers with smooth physics to avoid UI overlap with floating action controls across screen sizes.
