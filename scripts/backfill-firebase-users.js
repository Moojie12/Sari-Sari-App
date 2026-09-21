const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
// You need to download a service account key from Firebase Console:
// Project Settings -> Service Accounts -> Generate New Private Key
let serviceAccount;

try {
  // Try to load service account from common locations
  const possiblePaths = [
    './serviceAccountKey.json',
    '../serviceAccountKey.json',
    '../../serviceAccountKey.json',
    './firebase-service-account.json',
    '../firebase-service-account.json'
  ];

  for (const p of possiblePaths) {
    try {
      serviceAccount = require(p);
      console.log(`Loaded service account from: ${p}`);
      break;
    } catch (e) {
      // Continue trying
    }
  }

  if (!serviceAccount) {
    console.error('Error: Service account key not found. Please:');
    console.error('1. Go to Firebase Console -> Project Settings -> Service Accounts');
    console.error('2. Click "Generate New Private Key"');
    console.error('3. Save the JSON file as "serviceAccountKey.json" in the scripts/ directory');
    console.error('4. Run the script again');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://tindahan-ni-eca-app-default-rtdb.firebaseio.com"
  });

} catch (error) {
  console.error("Error initializing Firebase Admin SDK:", error);
  process.exit(1);
}

const auth = admin.auth();
const database = admin.database();

async function backfillAuthUsers() {
  try {
    console.log('Starting Firebase Auth users backfill to Realtime Database...');

    let nextPageToken;
    let totalUsers = 0;
    let processedUsers = 0;
    let createdCount = 0;
    let updatedCount = 0;
    let errorCount = 0;

    do {
      const listUsersResult = await auth.listUsers(1000, nextPageToken);
      nextPageToken = listUsersResult.pageToken;

      // Process users in batches
      const userPromises = listUsersResult.users.map(async (userRecord) => {
        totalUsers++;
        try {
          const uid = userRecord.uid;
          const email = userRecord.email || '';
          const displayName = userRecord.displayName || '';

          // Infer role from email (same logic as in auth_service.dart)
          let inferredRole = 'customer';
          const emailLower = email.toLowerCase();
          if (emailLower.includes('owner')) {
            inferredRole = 'owner';
          } else if (emailLower.includes('employee')) {
            inferredRole = 'employee';
          }

          // Prepare user data to write to Realtime Database
          const userData = {
            uid: uid,
            email: email,
            displayName: displayName,
            role: inferredRole,
            createdAt: userRecord.metadata.creationTime ?
              new Date(userRecord.metadata.creationTime).getTime() :
              Date.now()
          };

          // Write to Realtime Database at /users/{uid}
          const userRef = database.ref(`users/${uid}`);
          const snapshot = await userRef.get();

          if (snapshot.exists()) {
            // User already exists in DB, update it
            await userRef.update(userData);
            updatedCount++;
            console.log(`Updated user: ${email} (${uid})`);
          } else {
            // New user, create it
            await userRef.set(userData);
            createdCount++;
            console.log(`Created user: ${email} (${uid})`);
          }
        } catch (error) {
          errorCount++;
          console.error(`Error processing user ${userRecord.uid}:`, error);
        }
      });

      // Wait for all users in this batch to be processed
      await Promise.all(userPromises);
      processedUsers += listUsersResult.users.length;

    } while (nextPageToken); // Continue if there's another page

    console.log('\n=== Backfill Complete ===');
    console.log(`Total users in Firebase Auth: ${totalUsers}`);
    console.log(`Created in Realtime Database: ${createdCount}`);
    console.log(`Updated in Realtime Database: ${updatedCount}`);
    console.log(`Errors encountered: ${errorCount}`);
    console.log(`Processed: ${processedUsers}`);

  } catch (error) {
    console.error('Error during backfill process:', error);
    process.exit(1);
  }
}

// Run the backfill function
backfillAuthUsers().then(() => {
  console.log('\nBackfill process finished.');
  process.exit(0);
}).catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});