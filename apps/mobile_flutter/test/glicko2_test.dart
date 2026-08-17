import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/core/constants/subscription_constants.dart';

void main() {
  group('SubscriptionConstants Dynamic Access Tests', () {
    test('Founding Members always have Flagship Access', () {
      expect(
        SubscriptionConstants.hasFlagshipAccess(
          planId: SubscriptionConstants.planFounderFlagship,
          isFounder: true,
        ),
        isTrue,
      );
    });

    test('Paid Flagship Members have Flagship Access', () {
      expect(
        SubscriptionConstants.hasFlagshipAccess(
          planId: SubscriptionConstants.planFlagship,
          status: SubscriptionConstants.statusActive,
        ),
        isTrue,
      );
    });

    test('Community Trial with future trial_ends_at has Flagship Access', () {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      expect(
        SubscriptionConstants.hasFlagshipAccess(
          planId: SubscriptionConstants.planCommunityTrial,
          trialEndsAt: futureDate,
        ),
        isTrue,
      );
    });

    test('Community Trial with expired trial_ends_at is locked', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      expect(
        SubscriptionConstants.hasFlagshipAccess(
          planId: SubscriptionConstants.planCommunityTrial,
          trialEndsAt: pastDate,
        ),
        isFalse,
      );
    });

    test('Community Plan is restricted', () {
      expect(
        SubscriptionConstants.hasFlagshipAccess(
          planId: SubscriptionConstants.planCommunity,
        ),
        isFalse,
      );
    });
  });
}
