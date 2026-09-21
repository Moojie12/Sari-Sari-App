# Firebase Admin Scripts

## Backfill Firebase Auth Users to Realtime Database

This script synchronizes existing Firebase Authentication users with Firebase Realtime Database.

### Prerequisites

1. Node.js installed (v14+ recommended)
2. A Firebase service account key with appropriate permissions

### Setup

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate New Private Key" 
3. Save the downloaded JSON file as `serviceAccountKey.json` in this `scripts/` directory
4. Install dependencies:

```bash
npm install
```

### Usage

Run the backfill script:

```bash
npm run backfill
```

Or directly:

```bash
node backfill-firebase-users.js
```

### What the Script Does

- Lists all users from Firebase Authentication
- For each user, creates/updates a record in Realtime Database at `/users/[uid]`
- The stored data includes:
  - `uid`: Firebase UID
  - `email`: User's email address
  - `displayName`: User's display name (or empty string)
  - `role`: Inferred role based on email (owner/employee/customer)
  - `createdAt`: Timestamp when the user was created in Firebase Auth

### Notes

- The script will create new records for users not yet in the database
- The script will update existing records if they already exist
- Errors during processing are logged but don't stop the script
- Make sure your Firebase Realtime Database rules allow the service account to read/write
- The service account needs the Firebase Realtime Database Admin role or equivalent permissions

### Security

- Keep the `serviceAccountKey.json` file secure and never commit it to version control
- The service account has administrative privileges to your Firebase project
- Consider restricting the service account's permissions if possible