# Zorva Sports Passport: Subscription Architecture, Dynamic Trials & Monetization Guide

This document serves as the authoritative reference guide for the Zorva Sports Passport subscription architecture, dynamic trial periods, and multi-phase monetization lifecycle.

---

## 1. Business & Membership Tier Architecture

Zorva uses a **Two-Phase Product-Led Growth (PLG) Model**:
1. **Growth Launch Era (Year 1 / Pre-Monetization)**: 100% Free full Flagship access for all players to maximize viral network effects, community group adoption, and rating data collection.
2. **Monetized Era (Post-Launch)**: Founding members remain free for life; new signups receive a 30-day Flagship trial, after which they can upgrade to Paid Flagship or continue on Free Community status.

---

## 2. Canonical Plan Matrix

| `plan_id` | Target Audience | Features & Permissions | Pricing & Term |
| :--- | :--- | :--- | :--- |
| **`founder_flagship`** | ⚡ First 20 registered players per city | **100% Full Flagship Access Lifetime** + Gold Founder Badge | **$0 / Free For Life** |
| **`flagship`** | 💎 Paid Subscribers | **100% Full Flagship Access** (Official City Leaderboards, Flagship Groups, Dual Ratings, Lifetime Insights) | Annual / Monthly Paid |
| **`community_trial`** | ✨ New Signups during Active Trial | **100% Full Flagship Access Preview** | • **365 Days** in Growth Era<br>• **30 Days** in Monetization Era |
| **`community`** | 🆓 Free Regular Players (Post-Trial) | Community Leaderboards, Community Groups, Community Ratings Only | Free Forever |

---

## 3. Database Schema & Tables

### 1. Global System Controls (`app_settings`)
```sql
CREATE TABLE public.app_settings (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL,
  description TEXT,
  updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```
**Core Configuration Keys:**
- `monetization_enabled`: `'false'` (Growth Mode) / `'true'` (Paywall Active).
- `trial_duration_days`: `'365'` (Growth Mode) / `'30'` (Monetization Mode).
- `founder_cap_per_city`: `'20'` (First 20 players in a city get permanent founder perks).

### 2. User Subscriptions (`subscriptions`)
```sql
CREATE TABLE public.subscriptions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  plan_id               TEXT NOT NULL CHECK (plan_id IN ('founder_flagship', 'flagship', 'community_trial', 'community')),
  status                TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired')),
  trial_ends_at         TIMESTAMPTZ,
  current_period_end    TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 4. Single Source of Truth (`SubscriptionConstants`)

- File: [subscription_constants.dart](file:///c:/zorva/apps/mobile_flutter/lib/core/constants/subscription_constants.dart)

```dart
class SubscriptionConstants {
  // Plan IDs
  static const String planFounderFlagship = 'founder_flagship';
  static const String planFlagship = 'flagship';
  static const String planCommunityTrial = 'community_trial';
  static const String planCommunity = 'community';

  // Founding Member Cap
  static const int foundingMemberCapPerCity = 20;

  // Single Flagship Access Check
  static bool hasFlagshipAccess({
    required String? planId,
    DateTime? trialEndsAt,
  }) {
    if (planId == planFounderFlagship || planId == planFlagship) {
      return true;
    }
    if (planId == planCommunityTrial) {
      if (trialEndsAt == null) return true;
      return DateTime.now().isBefore(trialEndsAt);
    }
    return false;
  }
}
```

---

## 5. End-to-End Operational Lifecycle

### Step 1: User Signup & Dynamic Trial Assignment
1. User completes onboarding and selects a city.
2. Backend queries `profiles` row count for that city (`playerRankNumber`).
3. If `playerRankNumber <= 20`:
   - Sets `is_founder: true`, `plan_id: 'founder_flagship'`, `trial_ends_at: null`.
4. If `playerRankNumber > 20`:
   - Reads `trial_duration_days` from `app_settings` (365 or 30).
   - Computes `trial_ends_at = NOW() + INTERVAL '{trial_duration_days} days'`.
   - Inserts `plan_id: 'community_trial'`, `is_founder: false`, `trial_ends_at: <calculated_date>`.

### Step 2: Access Evaluation (Frontend & Backend)
- **Flagship Privileges** are granted if `hasFlagshipAccess() == true`.
- When `DateTime.now() >= trial_ends_at` and the player has not subscribed, their effective plan resolves to **`community`** (Restricted free tier).

---

## 6. Flipping the Switch from Growth to Monetization

To activate monetization in production:
```sql
-- 1. Enable Paywall Mode
UPDATE app_settings 
SET value = 'true' 
WHERE key = 'monetization_enabled';

-- 2. Change trial duration for all subsequent new signups to 30 days
UPDATE app_settings 
SET value = '30' 
WHERE key = 'trial_duration_days';
```

Existing early signups maintain their 365-day trial until their individual `trial_ends_at` timestamps expire, providing an automatic, built-in grace period.
