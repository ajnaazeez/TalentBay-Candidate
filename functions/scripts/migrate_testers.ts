import * as admin from "firebase-admin";

/**
 * Administrative script to safely migrate explicitly allowlisted owner/tester accounts
 * to the new zero-cost 7-day Firebase trial.
 * 
 * SAFEGUARDS:
 * 1. Only migrates UIDs explicitly listed in ALLOWLISTED_TESTER_UIDS or passed via CLI args.
 * 2. Preserves all profile data, applications, chats, assessment records, and Razorpay receipts.
 * 3. Never deletes documents or globally resets hasUsedTrial.
 * 4. Completely isolated from production app endpoints.
 */

// If running directly with ts-node or node:
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Specific allowlisted owner/tester UIDs for migration
const ALLOWLISTED_TESTER_UIDS: string[] = [
  // Add approved tester/owner UIDs here or pass via command line:
  // ts-node migrate_testers.ts <uid1> <uid2>
];

export async function migrateTesterAccounts(targetUids: string[] = ALLOWLISTED_TESTER_UIDS): Promise<void> {
  const uids = (process.argv.slice(2).length > 0 ? process.argv.slice(2) : targetUids).filter(
    (u) => typeof u === "string" && u.trim().length > 0
  );

  if (uids.length === 0) {
    console.log("No tester UIDs provided. Usage: ts-node migrate_testers.ts <uid1> <uid2>");
    return;
  }

  console.log(`Starting migration for ${uids.length} allowlisted tester account(s)...`);

  for (const uid of uids) {
    const candidateRef = db.collection("candidates").doc(uid);
    const userRef = db.collection("users").doc(uid);

    try {
      await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(candidateRef);
        if (!doc.exists) {
          console.warn(`[TesterMigration] Candidate document for ${uid} not found. Skipping.`);
          return;
        }

        const data = doc.data() || {};
        const now = admin.firestore.Timestamp.now();
        const sevenDaysMillis = 7 * 24 * 60 * 60 * 1000;
        const newExpiry = admin.firestore.Timestamp.fromMillis(now.toMillis() + sevenDaysMillis);

        // Archive previous legacy trial details safely on the candidate document
        const legacyTrialArchive = {
          planId: data.subscriptionPlanId || "7_days_trial",
          previousExpiryDate: data.subscriptionExpiryDate || null,
          razorpayPaymentId: data.razorpayPaymentId || null,
          razorpayOrderId: data.razorpayOrderId || null,
          migratedAt: now,
        };

        transaction.update(candidateRef, {
          trialStartDate: now,
          trialExpiryDate: newExpiry,
          hasUsedTrial: true,
          isPremium: true,
          subscriptionStatus: "trial",
          subscriptionPlanId: "free_trial_7d",
          legacyTrialArchive: legacyTrialArchive,
          isTestAccount: true,
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

        console.log(`[TesterMigration] Successfully migrated tester ${uid} to 7-day Firebase trial.`);
      });
    } catch (err) {
      console.error(`[TesterMigration] Error migrating tester ${uid}:`, err);
    }
  }

  console.log("Tester migration complete.");
}

// Execute if run directly from CLI
if (require.main === module) {
  migrateTesterAccounts()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("Migration fatal error:", err);
      process.exit(1);
    });
}
