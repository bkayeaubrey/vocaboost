# Firebase Setup Guide for Feedback Feature

This guide will help you set up Firebase Firestore and Cloud Functions for the feedback feature.

## Prerequisites

1. Firebase project created
2. Firebase CLI installed: `npm install -g firebase-tools`
3. Node.js 18+ installed

## Step 1: Initialize Firebase in Your Project

If you haven't already:

```bash
firebase login
firebase init
```

Select:
- ✅ Firestore
- ✅ Functions
- ✅ Use existing project (select your project)

## Step 2: Set Up Firestore Security Rules

Add these rules to your Firestore security rules (in Firebase Console > Firestore > Rules):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Feedback collection
    match /feedback/{feedbackId} {
      // Allow authenticated users to create feedback
      allow create: if request.auth != null;
      
      // Users can read their own feedback
      allow read: if request.auth != null && 
                     (request.auth.uid == resource.data.userId || 
                      request.auth.uid == request.resource.data.userId);
      
      // Only admins can update/delete (via Firebase Console)
      allow update, delete: if false;
    }
    
    // Your existing rules for other collections...
  }
}
```

## Step 3: Install Function Dependencies

```bash
cd functions
npm install
```

## Step 4: Configure Email Settings

### For Gmail:

1. Enable 2-Factor Authentication on your Gmail account
2. Generate an App Password:
   - Go to: https://myaccount.google.com/apppasswords
   - Select "Mail" and "Other (Custom name)"
   - Enter "VocaBoost Functions"
   - Copy the generated 16-character password

3. Set Firebase Functions configuration:

```bash
firebase functions:config:set email.user="your-email@gmail.com"
firebase functions:config:set email.password="your-16-char-app-password"
firebase functions:config:set email.admin="admin-email@gmail.com"
firebase functions:config:set email.service="gmail"
```

### For Other Email Providers:

Modify the `getEmailTransporter()` function in `functions/index.js` to use your SMTP settings.

## Step 5: Deploy Cloud Functions

```bash
cd functions
firebase deploy --only functions
```

## Step 6: Test the Setup

1. Open your app and navigate to Settings
2. Tap "Send Feedback"
3. Fill out the feedback form and submit
4. Check:
   - Firestore Console: A new document should appear in the `feedback` collection
   - Your email inbox: You should receive a notification email

## Troubleshooting

### Functions not deploying?
- Check that you're in the `functions` directory
- Verify Node.js version: `node --version` (should be 18+)
- Check Firebase CLI is up to date: `firebase --version`

### Emails not sending?
- Verify email configuration: `firebase functions:config:get`
- Check function logs: `firebase functions:log`
- Ensure App Password is correct (for Gmail)
- Check spam folder

### Permission errors?
- Verify Firestore security rules are deployed
- Check that the user is authenticated when submitting feedback

## Viewing Feedback

You can view all feedback submissions in:
- **Firebase Console**: Firestore > `feedback` collection
- **Admin Dashboard**: Use the `getFeedbackStats` HTTP function endpoint

## Next Steps

- Set up Firestore indexes if needed for queries
- Configure email templates for better formatting
- Add feedback management dashboard (optional)
- Set up automated responses based on feedback category



