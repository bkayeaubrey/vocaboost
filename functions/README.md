# VocaBoost Cloud Functions

This directory contains Firebase Cloud Functions for the VocaBoost app.

## Functions

### `onFeedbackCreated`
Triggered when new feedback is created in Firestore. Sends email notifications to the admin and optionally sends an auto-reply to the user.

### `getFeedbackStats`
HTTP endpoint to get feedback statistics (for admin dashboard).

## Setup

1. **Install dependencies:**
   ```bash
   cd functions
   npm install
   ```

2. **Configure email settings:**
   
   For Gmail, you'll need to:
   - Enable 2-factor authentication on your Gmail account
   - Generate an App Password: https://myaccount.google.com/apppasswords
   
   Then set the configuration:
   ```bash
   firebase functions:config:set email.user="your-email@gmail.com"
   firebase functions:config:set email.password="your-app-password"
   firebase functions:config:set email.admin="admin-email@gmail.com"
   firebase functions:config:set email.service="gmail"
   ```

   For other email providers, adjust the `service` and credentials accordingly.

3. **Deploy functions:**
   ```bash
   firebase deploy --only functions
   ```

## Testing Locally

1. **Start the emulator:**
   ```bash
   firebase emulators:start --only functions
   ```

2. **Test the function:**
   - Create a document in the `feedback` collection in Firestore
   - The function will trigger and send emails (if configured)

## Email Configuration

The functions use Nodemailer to send emails. Supported services include:
- Gmail
- Outlook
- Yahoo
- Custom SMTP servers

To use a custom SMTP server, modify the `getEmailTransporter()` function in `index.js`.

## Security Rules

Make sure your Firestore security rules allow authenticated users to write to the `feedback` collection:

```javascript
match /feedback/{feedbackId} {
  allow create: if request.auth != null;
  allow read: if request.auth != null && request.auth.uid == resource.data.userId;
  allow update, delete: if false; // Only admins can update/delete via console
}
```



