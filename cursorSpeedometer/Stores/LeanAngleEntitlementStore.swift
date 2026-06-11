import Foundation

/// Gates the premium Lean Angle feature.
///
/// During testing this is forced unlocked so the full feature is usable without
/// the App Store in-app purchase. When the IAP is ready for launch, flip
/// `testingUnlockOverride` to `false` and back this store with StoreKit 2
/// (`Transaction.currentEntitlements`); the greyed-out gating in Settings and the
/// ride screen already react to `isUnlocked`.
@MainActor
final class LeanAngleEntitlementStore: ObservableObject {
    /// While true, the feature is unlocked for everyone (pre-launch testing).
    static let testingUnlockOverride = true

    @Published private(set) var isUnlocked: Bool

    init(isUnlocked: Bool = LeanAngleEntitlementStore.testingUnlockOverride) {
        self.isUnlocked = isUnlocked
    }

    /// Placeholder for the future StoreKit purchase flow.
    func purchase() {
        // TODO: Replace with StoreKit 2 purchase + Transaction verification at launch.
        isUnlocked = true
    }

    /// Placeholder for the future StoreKit restore flow.
    func restorePurchases() {
        // TODO: Replace with Transaction.currentEntitlements lookup at launch.
        isUnlocked = LeanAngleEntitlementStore.testingUnlockOverride
    }
}
