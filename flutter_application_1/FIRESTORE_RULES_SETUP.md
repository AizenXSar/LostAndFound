# Firestore Security Rules Setup

## How to Deploy Firestore Rules

The `firestore.rules` file has been created with proper security rules for your app. To deploy these rules to Firebase:

### Option 1: Using Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `lostandfound-4e45a`
3. Click on **Firestore Database** in the left menu
4. Click on the **Rules** tab
5. Copy the contents of `firestore.rules` file
6. Paste it into the rules editor
7. Click **Publish**

### Option 2: Using Firebase CLI

If you have Firebase CLI installed:

```bash
firebase deploy --only firestore:rules
```

### Option 3: Using Firebase CLI with Project Selection

If you need to specify the project:

```bash
firebase use lostandfound-4e45a
firebase deploy --only firestore:rules
```

## What These Rules Do

### Notifications Collection
- ✅ Users can **read** their own notifications (where `toUserId == their userId`)
- ✅ Users can **update** their own notifications (mark as read)
- ✅ Users can **delete** their own notifications
- ✅ Authenticated users can **create** notifications (app can send notifications)

### FCM Tokens Collection
- ✅ Users can read/write their own FCM token

### Other Collections
- Users, Admins, Items, Chats, Messages, Calls, Transactions all have appropriate read/write permissions

## Important Notes

1. **After deploying rules**, the permission denied error should be resolved
2. Make sure you're logged in as an authenticated user when testing
3. The rules ensure users can only access their own data for security

## Testing

After deploying:
1. Log in to the app
2. Try accessing notifications - should work now
3. Check console logs for any remaining errors

