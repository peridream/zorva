# Zorva Sports Passport: Subscription Tiers, 10-Match Trial & Insights Engine Guide

This document serves as the authoritative reference guide for the Zorva Sports Passport subscription architecture, the 10-match Community Free Trial system, and the Glicko-2 Player Insights & Analytics engine.

---

## 1. Business & Membership Tier Architecture

Zorva uses a **Product-Led Growth (PLG) Freemium Model** designed to maximize user engagement and drive high conversion to Flagship membership through loss aversion:

### Tier Overview:

| Feature | Founding Member (First 20 in City) | Regular Community Member (User #21+) | Flagship Member (Paid) |
| :--- | :--- | :--- | :--- |
| **City Founder Status** | ⚡ Granted Automatically | ❌ No | ❌ No |
| **Official City Leaderboard** | ✅ Full Access | 🔒 Locked (Upgrade required) | ✅ Full Access |
| **Community Rating Card** | ✅ Included | ✅ Included | ✅ Included |
| **Match Logging & Verification** | ✅ Unlimited | ✅ Unlimited | ✅ Unlimited |
| **Player Insights & Analytics** | ♾️ Unlimited Lifetime | ✨ 10-Match Free Trial (Locked at Match 11+) | ♾️ Unlimited Lifetime |

---

## 2. Database Schema & Migration (`premium_subscriptions`)

Subscription state is stored in the `premium_subscriptions` PostgreSQL table.

### Schema Definition:
```sql
CREATE TABLE premium_subscriptions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  plan_id               TEXT NOT NULL DEFAULT 'community_trial',
  status                TEXT NOT NULL CHECK (status IN ('active', 'expired')),
  trial_ends_at         TIMESTAMPTZ,
  current_period_end    TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Migration Script (`0005_add_plan_id_to_premium_subscriptions.sql`):
- Path: [0005_add_plan_id_to_premium_subscriptions.sql](file:///c:/zorva/supabase/migrations/0005_add_plan_id_to_premium_subscriptions.sql)
- Adds `plan_id` column with default `'community_trial'`.
- Enforces strict `status IN ('active', 'expired')` constraint.
- Enables RLS policy `Public allow all premium_subscriptions`.

---

## 3. Code Base Single Source of Truth (`SubscriptionConstants`)

All subscription plans, statuses, limits, and helper logic are centralized in a single file to eliminate magic strings and hallucinations.

- File Path: [subscription_constants.dart](file:///c:/zorva/apps/mobile_flutter/lib/core/constants/subscription_constants.dart)

```dart
class SubscriptionConstants {
  // Plan IDs
  static const String planFounderFlagship = 'founder_flagship';
  static const String planFlagship = 'flagship';
  static const String planCommunityTrial = 'community_trial';

  // Subscription Statuses (Strictly 'active' or 'expired')
  static const String statusActive = 'active';
  static const String statusExpired = 'expired';

  // Rules & Caps
  static const int trialMaxMatches = 10;
  static const int foundingMemberCapPerCity = 20;

  // Helper Methods
  static bool isFlagshipMember(String? planId, String? status) {
    if (status != statusActive) return false;
    return planId == planFounderFlagship || planId == planFlagship;
  }

  static bool isTrialActive(String? planId, String? status, int matchesPlayed) {
    if (status != statusActive) return false;
    if (planId != planCommunityTrial) return false;
    return matchesPlayed <= trialMaxMatches;
  }

  static bool isTrialExpired(String? planId, String? status, int matchesPlayed) {
    if (planId == planCommunityTrial && matchesPlayed > trialMaxMatches) {
      return true;
    }
    return status == statusExpired;
  }
}
```

---

## 4. End-to-End Operational Lifecycle

### Step 1: User Signup & Automatic Plan Assignment
- **Location**: [city_onboarding_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/onboarding/presentation/screens/city_onboarding_screen.dart#L286-L302)
- **Logic**:
  1. When a new user picks their city, the app queries `profiles` row count for that city (`playerRankNumber`).
  2. If `playerRankNumber <= 20` ➔ Inserts `plan_id: 'founder_flagship'`, `status: 'active'`.
  3. If `playerRankNumber > 20` ➔ Inserts `plan_id: 'community_trial'`, `status: 'active'`.

### Step 2: Match Ratification & Guarded Trial Expiration
- **Location**: [home_dashboard_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart#L612-L644)
- **Logic**:
  1. Whenever a match is ratified in `_quickApproveMatch()`, the system executes `_checkAndUpdateTrialExpiration(playerId)`.
  2. **Early Guard Check**: Reads `premium_subscriptions`. If player is NOT on `community_trial` or status is NOT `active`, returns immediately (**zero overhead for Flagship players**).
  3. **Trial Expiration**: If player is on `community_trial` AND total verified matches exceed 10 (`> SubscriptionConstants.trialMaxMatches`), updates `premium_subscriptions` status to **`'expired'`**.

### Step 3: Passport UI & Upgrade Sheet
- **Location**: [home_dashboard_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart#L1086-L1155)
- **Button States**:
  - **Flagship / Founders**: `PLAYER INSIGHTS & ANALYTICS ⚡` (Opens `InsightsScreen`).
  - **Active Trial (1-10 Matches)**: `✨ FLAGSHIP TRIAL (X / 10 LEFT)` (Opens `InsightsScreen` preview).
  - **Expired Trial (11+ Matches)**: `🔒 UNLOCK PLAYER INSIGHTS & ANALYTICS` (Opens Flagship Upgrade Bottom Sheet).

---

## 5. Player Insights & Glicko-2 Trajectory Graph Rules

- File Path: [insights_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/insights_screen.dart)

### Trajectory Graph Principles:
1. **Starting Baseline**: Reads true starting Glicko-2 rating before Match 1 from `p1_rating_before` / `p2_rating_before` in `match_context_links`.
2. **Context Filtering**: Queries `match_context_links` where `context_id = activeContextId`.
3. **Flagship Graph Prioritization**: For Flagship members, `insights_screen.dart` inspects `rating_contexts` and **always prioritizes their Official Flagship Rating Card**. Their graph plots **ONLY** official Flagship match ratings (`1200 ➔ 1307`) with zero Community match clutter.
4. **Community Trial Graph**: For Community trial players, plots their Community Glicko-2 progress trajectory preview during their 10-match trial.

---

## 6. How to Test & Verify SQL Reference

### Manually Granting Free Trial to a Test User:
```sql
INSERT INTO premium_subscriptions (user_id, plan_id, status)
VALUES ('<USER_UUID>', 'community_trial', 'active')
ON CONFLICT (user_id) DO UPDATE 
SET plan_id = 'community_trial', status = 'active';
```

### Manually Expiring a User's Trial:
```sql
UPDATE premium_subscriptions
SET status = 'expired'
WHERE user_id = '<USER_UUID>';
```

### Manually Promoting a User to Founder / Flagship:
```sql
INSERT INTO premium_subscriptions (user_id, plan_id, status)
VALUES ('<USER_UUID>', 'founder_flagship', 'active')
ON CONFLICT (user_id) DO UPDATE 
SET plan_id = 'founder_flagship', status = 'active';
```
