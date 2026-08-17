class SubscriptionConstants {
  // Plan IDs
  static const String planFounderFlagship = 'founder_flagship';
  static const String planFlagship = 'flagship';
  static const String planCommunityTrial = 'community_trial';
  static const String planCommunity = 'community';

  // Subscription Statuses
  static const String statusActive = 'active';
  static const String statusExpired = 'expired';

  // Rules & Caps
  static const int trialMaxMatches = 10;
  static const int foundingMemberCapPerCity = 20;

  /// Single Unified Flagship Access Evaluator
  static bool hasFlagshipAccess({
    required String? planId,
    String? status,
    DateTime? trialEndsAt,
    bool isFounder = false,
  }) {
    if (isFounder || planId == planFounderFlagship) return true;
    if (planId == planFlagship && status == statusActive) return true;
    if (planId == planCommunityTrial) {
      if (trialEndsAt == null) return true;
      return DateTime.now().isBefore(trialEndsAt);
    }
    return false;
  }

  // Helper Methods (Backward Compatible)
  static bool isFlagshipMember(String? planId, String? status) {
    if (status != statusActive) return false;
    return planId == planFounderFlagship || planId == planFlagship;
  }

  static bool isTrialActive(String? planId, String? status, [DateTime? trialEndsAt]) {
    if (planId != planCommunityTrial) return false;
    if (trialEndsAt != null) {
      return DateTime.now().isBefore(trialEndsAt);
    }
    return status == statusActive;
  }

  static bool isTrialExpired(String? planId, String? status, [DateTime? trialEndsAt]) {
    if (planId == planCommunity) return true;
    if (planId == planCommunityTrial && trialEndsAt != null) {
      return DateTime.now().isAfter(trialEndsAt);
    }
    return status == statusExpired;
  }
}
