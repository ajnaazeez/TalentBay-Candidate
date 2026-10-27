import * as admin from "firebase-admin";

export interface EntitlementResult {
  hasAccess: boolean;
  reason: "valid_paid" | "active_trial" | "expired_trial" | "expired_paid" | "no_entitlement";
  subscriptionStatus: string;
  expiresAt: Date | null;
}

/**
 * Safely parses Date from a Firestore Timestamp or an ISO-8601 string.
 */
export function parseEntitlementDate(val: any): Date | null {
  if (!val) return null;
  if (val instanceof Date) return val;
  if (val.toDate && typeof val.toDate === "function") return val.toDate();
  if (typeof val === "string") {
    const d = new Date(val);
    return isNaN(d.getTime()) ? null : d;
  }
  return null;
}

/**
 * Authoritative server-side entitlement evaluation for candidate accounts.
 * Distinguishes between paid subscriptions and 7-day Firebase trials.
 * Never overwrites or shortens a valid paid subscription.
 */
export async function verifyCandidateEntitlement(
  uid: string,
  db: FirebaseFirestore.Firestore
): Promise<EntitlementResult> {
  const candidateRef = db.collection("candidates").doc(uid);
  const candidateDoc = await candidateRef.get();

  if (!candidateDoc.exists) {
    return {
      hasAccess: false,
      reason: "no_entitlement",
      subscriptionStatus: "none",
      expiresAt: null,
    };
  }

  const data = candidateDoc.data() || {};
  const now = new Date();

  const paidExpiry = parseEntitlementDate(data.subscriptionExpiryDate);
  const trialExpiry = parseEntitlementDate(data.trialExpiryDate);

  const planId = (data.subscriptionPlanId || "").toString();
  const isPaidPlan = planId.length > 0 && planId !== "7_days_trial" && planId !== "free_trial_7d";

  // 1. PRECEDENCE 1: Active Paid Subscription (Highest priority - never shortened)
  if (isPaidPlan && paidExpiry && paidExpiry > now && data.subscriptionStatus !== "cancelled") {
    return {
      hasAccess: true,
      reason: "valid_paid",
      subscriptionStatus: data.subscriptionStatus || "active",
      expiresAt: paidExpiry,
    };
  }

  // 2. PRECEDENCE 2: Active 7-Day Firebase Trial
  if (trialExpiry && trialExpiry > now) {
    return {
      hasAccess: true,
      reason: "active_trial",
      subscriptionStatus: "trial",
      expiresAt: trialExpiry,
    };
  }

  // 3. PRECEDENCE 3: Expired Trial
  if (!isPaidPlan && trialExpiry && trialExpiry <= now) {
    // Lazily synchronize Firestore so future reads reflect expired status
    if (data.isPremium === true || data.subscriptionStatus === "trial") {
      try {
        await candidateRef.update({
          isPremium: false,
          subscriptionStatus: "expired",
          lastUpdated: now.toISOString(),
        });
        const userRef = db.collection("users").doc(uid);
        await userRef.update({ isPremium: false }).catch(() => {});
      } catch (err) {
        console.warn(`[verifyCandidateEntitlement] Failed lazy update for expired trial ${uid}:`, err);
      }
    }
    return {
      hasAccess: false,
      reason: "expired_trial",
      subscriptionStatus: "expired",
      expiresAt: trialExpiry,
    };
  }

  // 4. PRECEDENCE 4: Expired Paid Subscription
  if (isPaidPlan && paidExpiry && paidExpiry <= now) {
    if (data.isPremium === true) {
      try {
        await candidateRef.update({
          isPremium: false,
          subscriptionStatus: "expired",
          lastUpdated: now.toISOString(),
        });
        const userRef = db.collection("users").doc(uid);
        await userRef.update({ isPremium: false }).catch(() => {});
      } catch (err) {
        console.warn(`[verifyCandidateEntitlement] Failed lazy update for expired subscription ${uid}:`, err);
      }
    }
    return {
      hasAccess: false,
      reason: "expired_paid",
      subscriptionStatus: "expired",
      expiresAt: paidExpiry,
    };
  }

  return {
    hasAccess: false,
    reason: "no_entitlement",
    subscriptionStatus: data.subscriptionStatus || "none",
    expiresAt: null,
  };
}

/**
 * Atomically grants an initial 7-day free trial to an eligible candidate.
 * Concurrency-safe and idempotent: duplicate invocations will NEVER restart or extend the trial.
 * Does NOT overwrite existing valid paid subscriptions.
 */
export async function grantInitialTrial(
  uid: string,
  db: FirebaseFirestore.Firestore
): Promise<{ granted: boolean; reason: string }> {
  const candidateRef = db.collection("candidates").doc(uid);
  const userRef = db.collection("users").doc(uid);

  return await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(candidateRef);
    if (!doc.exists) {
      return { granted: false, reason: "candidate_not_found" };
    }

    const data = doc.data() || {};

    // Invariant 1: If trial was already used, never grant another trial
    if (data.hasUsedTrial === true) {
      return { granted: false, reason: "already_used_trial" };
    }

    // Invariant 2: If trial start or expiry date exists, never overwrite or extend
    if (data.trialStartDate != null || data.trialExpiryDate != null) {
      return { granted: false, reason: "trial_already_initialized" };
    }

    // Invariant 3: Never overwrite an existing active paid subscription
    const planId = (data.subscriptionPlanId || "").toString();
    const isPaidPlan = planId.length > 0 && planId !== "7_days_trial" && planId !== "free_trial_7d";
    const paidExpiry = parseEntitlementDate(data.subscriptionExpiryDate);
    if (isPaidPlan && paidExpiry && paidExpiry > new Date()) {
      return { granted: false, reason: "active_paid_subscription_exists" };
    }

    // Server-side trusted timestamp calculation
    const now = admin.firestore.Timestamp.now();
    const sevenDaysMillis = 7 * 24 * 60 * 60 * 1000;
    const expiry = admin.firestore.Timestamp.fromMillis(now.toMillis() + sevenDaysMillis);

    transaction.update(candidateRef, {
      hasUsedTrial: true,
      trialStartDate: now,
      trialExpiryDate: expiry,
      isPremium: true,
      subscriptionStatus: "trial",
      subscriptionPlanId: "free_trial_7d",
      lastUpdated: now.toDate().toISOString(),
    });

    transaction.set(
      userRef,
      {
        isPremium: true,
        subscriptionPlanId: "free_trial_7d",
      },
      { merge: true }
    );

    return { granted: true, reason: "trial_granted" };
  });
}
