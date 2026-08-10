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
