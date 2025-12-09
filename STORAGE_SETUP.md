# Firebase Storage Setup Guide

This guide will help you set up Firebase Storage for profile picture uploads.

## Step 1: Enable Firebase Storage

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `vocaboost-fb`
3. Navigate to **Storage** in the left sidebar
4. Click **Get Started** if Storage is not enabled yet
5. Choose **Start in test mode** (we'll update rules next)
6. Select a location for your storage bucket (choose closest to your users)

## Step 2: Deploy Storage Rules

The storage rules are already configured in `storage.rules`. Deploy them using:

```bash
firebase deploy --only storage
```

Or deploy all rules at once:

```bash
firebase deploy --only firestore,storage
```

## Step 3: Verify Storage Rules

After deploying, verify the rules in Firebase Console:
1. Go to **Storage** > **Rules**
2. You should see rules that allow:
   - Anyone to read profile pictures
   - Users to upload/delete their own profile pictures

## Step 4: Test the Upload

1. Run your app
2. Go to Profile screen
3. Tap on the avatar
4. Select "Gallery" or "Camera"
5. Choose/select an image
6. The image should upload successfully

## Troubleshooting

### Error: "Permission denied" or "unauthorized"
- Make sure storage rules are deployed: `firebase deploy --only storage`
- Check that the user is logged in
- Verify the storage bucket name matches in `firebase_options.dart`

### Error: "Storage bucket not found"
- Make sure Firebase Storage is enabled in Firebase Console
- Check that `storageBucket` is set correctly in `firebase_options.dart`

### Error: "Failed to upload profile picture"
- Check your internet connection
- Verify Firebase Storage is enabled
- Check Firebase Console for any quota limits
- Review the error message in the app for specific details

## Storage Rules Explanation

The current rules allow:
- **Read**: Anyone can view profile pictures (for displaying in app)
- **Write**: Only the authenticated user can upload their own picture
- **Delete**: Only the authenticated user can delete their own picture

This ensures security while allowing profile pictures to be displayed throughout the app.



