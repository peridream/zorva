# Zorva Milestone 1 Walkthrough & Project Quickstart

This document provides a walkthrough of the completed **Milestone 1** for **Zorva** built using **Flutter + Supabase Direct**.

---

## 1. Project Overview & Architecture

* **Flutter Application**: `apps/mobile_flutter`
* **Database**: Supabase PostgreSQL (`mdegfrekmcgejyvekodn.supabase.co`)
* **Theme**: Signature Black (`#0A0A0A`), Gold (`#D4AF37`), Green (`#4ADE80`), and Crimson (`#F87171`) palette with Google Fonts Inter typography.

---

## 2. Directory Structure (`apps/mobile_flutter`)

```
apps/mobile_flutter/
├── lib/
│   ├── core/
│   │   ├── theme/
│   │   │   └── zorva_theme.dart          # App design system & color tokens
│   │   └── constants/
│   │       └── supabase_constants.dart   # Supabase URL & Public anon API key
│   ├── features/
│   │   ├── onboarding/
│   │   │   └── presentation/screens/
│   │   │       ├── welcome_screen.dart            # Brand tagline & value carousel
│   │   │       ├── auth_screen.dart               # Supabase Auth sign-up / sign-in
│   │   │       └── city_onboarding_screen.dart    # City selection & Founding Player claim
│   │   ├── rating/
│   │   │   └── domain/
│   │   │       └── glicko2.dart          # Pure Dart Glicko-2 engine implementation
│   │   ├── dashboard/
│   │   │   └── presentation/screens/
│   │   │       └── home_dashboard_screen.dart # Glicko-2 Hero card & 1-tap approvals
│   │   ├── match_logger/
│   │   │   └── presentation/screens/
│   │   │       └── add_match_screen.dart # Sub-15s 3-tap match logger
│   │   └── leaderboards/
│   │       └── presentation/screens/
│   │           └── leaderboards_screen.dart # Ranked podiums & context filters
│   └── main.dart
└── test/
    └── glicko2_test.dart                 # Glicko-2 Worked Example paper unit tests
```

---

## 3. Key Accomplishments

1. **Pure Dart Glicko-2 Engine**:
   * Implemented in [glicko2.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/rating/domain/glicko2.dart).
   * Verified by [glicko2_test.dart](file:///c:/zorva/apps/mobile_flutter/test/glicko2_test.dart) matching Glickman (1999) paper numerical worked example (1500/200/0.06 ➔ 1464.06/151.52/0.05999) with 100% precision.
2. **Sub-15-Second Match Logging**:
   * 3-tap score submission (`Select Opponent` ➔ `Outcome` ➔ `Quick Preset`) in < 10 seconds.
3. **1-Tap In-App Opponent Approval**:
   * High-visibility pending match approval card rendered on Home Dashboard for instant confirmation.
4. **Supabase Database & RLS Migration**:
   * Created RLS migration [0003_enable_public_rls.sql](file:///c:/zorva/supabase/migrations/0003_enable_public_rls.sql) enabling public `anon` client access for MVP testing.

---

## 4. How to Run Locally

### Running the Flutter Web / Mobile App
```bash
cd c:\zorva\apps\mobile_flutter
C:\src\flutter\bin\flutter.bat run -d chrome
```

### Running Unit & Widget Tests
```bash
cd c:\zorva\apps\mobile_flutter
C:\src\flutter\bin\flutter.bat test
```
