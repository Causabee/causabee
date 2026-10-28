// What a notification from the App Store means for a Pro account: Apple tells the server of
// renewals, refunds and ends itself — also while the app stays closed for weeks.
// developer.apple.com/documentation/appstoreservernotifications/notificationtype

/// The new end of Pro, or null when the notification does not move it.
export function newEnd(type: string, subtype: string | undefined, isPro: boolean,
                       tx: { expiresDate?: number; purchaseDate: number; revocationDate?: number },
                       renewal: { gracePeriodExpiresDate?: number } | undefined, now = Date.now()): number | null {
  // A plan of the same group renewed in Pro's place — Plus after a downgrade: Pro ended when it began.
  if (!isPro) return ["DID_RENEW", "SUBSCRIBED"].includes(type) ? tx.purchaseDate : null;
  switch (type) {
    case "SUBSCRIBED":
    case "DID_RENEW":
    case "OFFER_REDEEMED":
    case "RENEWAL_EXTENDED":
      return tx.expiresDate ?? null;
    case "DID_CHANGE_RENEWAL_PLAN":
      // An upgrade to Pro takes effect at once; a change away from it only at the renewal.
      return subtype === "UPGRADE" ? tx.expiresDate ?? null : null;
    case "DID_FAIL_TO_RENEW":
      // Apple keeps trying the card: Pro goes on through the grace period, and no longer.
      return subtype === "GRACE_PERIOD" ? renewal?.gracePeriodExpiresDate ?? null : tx.expiresDate ?? null;
    case "EXPIRED":
    case "GRACE_PERIOD_EXPIRED":
      return Math.min(tx.expiresDate ?? now, now);
    case "REFUND":
    case "REVOKE":
      return tx.revocationDate ?? now;
    default:
      return null;
  }
}

/// Whether the new end replaces the one on file: a renewal only ever lengthens Pro; an end, a
/// refund or a downgrade shortens it.
export function replaces(type: string, isPro: boolean): boolean {
  return !isPro || ["EXPIRED", "GRACE_PERIOD_EXPIRED", "REFUND", "REVOKE", "DID_FAIL_TO_RENEW"].includes(type);
}
