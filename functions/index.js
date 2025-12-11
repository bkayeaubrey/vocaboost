const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const axios = require('axios');

// Initialize Firebase Admin
admin.initializeApp();

// Configure email transporter
// Note: You'll need to set up email credentials in Firebase Functions config
// For Gmail, you can use an App Password
const getEmailTransporter = () => {
  const emailConfig = functions.config().email || {};
  const emailUser = emailConfig.user;
  const emailPassword = emailConfig.password;
  const emailService = emailConfig.service || 'gmail';
  const adminEmail = emailConfig.admin || emailUser;

  if (!emailUser || !emailPassword) {
    console.warn('Email configuration not set. Feedback notifications will not be sent.');
    return null;
  }

  return nodemailer.createTransport({
    service: emailService,
    auth: {
      user: emailUser,
      pass: emailPassword,
    },
  });
};

/**
 * Cloud Function triggered when new feedback is created in Firestore
 * Sends an email notification to the admin
 */
exports.onFeedbackCreated = functions.firestore
    .document('feedback/{feedbackId}')
    .onCreate(async (snap, context) => {
      const feedbackData = snap.data();
      const feedbackId = context.params.feedbackId;

      console.log('New feedback received:', feedbackId);

      // Prepare email content
      const emailSubject = `[VocaBoost] New ${feedbackData.category} Feedback`;
      
      const emailBody = `
New feedback has been submitted to VocaBoost:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Feedback ID: ${feedbackId}
Category: ${feedbackData.category || 'general'}
Rating: ${feedbackData.rating ? '⭐'.repeat(feedbackData.rating) : 'Not provided'}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

User Information:
• Name: ${feedbackData.userName || 'Not provided'}
• Email: ${feedbackData.userEmail || 'Not provided'}
• User ID: ${feedbackData.userId || 'Anonymous'}

Feedback Message:
${feedbackData.message}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Submitted: ${feedbackData.timestamp && feedbackData.timestamp.toDate ? feedbackData.timestamp.toDate() : new Date().toISOString()}
App Version: ${feedbackData.appVersion || 'Unknown'}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

View in Firebase Console:
https://console.firebase.google.com/project/${process.env.GCLOUD_PROJECT}/firestore/data/~2Ffeedback~2F${feedbackId}
      `.trim();

      // Send email notification
      const transporter = getEmailTransporter();
      if (transporter) {
        try {
          const emailConfig = functions.config().email || {};
          const adminEmail = emailConfig.admin || emailConfig.user;
          
          await transporter.sendMail({
            from: `VocaBoost Feedback <${emailConfig.user}>`,
            to: adminEmail,
            subject: emailSubject,
            text: emailBody,
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #3B5FAE;">New Feedback Received</h2>
                <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                  <p><strong>Feedback ID:</strong> ${feedbackId}</p>
                  <p><strong>Category:</strong> ${feedbackData.category || 'general'}</p>
                  <p><strong>Rating:</strong> ${feedbackData.rating ? '⭐'.repeat(feedbackData.rating) : 'Not provided'}</p>
                </div>
                
                <h3 style="color: #2666B4;">User Information</h3>
                <ul>
                  <li><strong>Name:</strong> ${feedbackData.userName || 'Not provided'}</li>
                  <li><strong>Email:</strong> ${feedbackData.userEmail || 'Not provided'}</li>
                  <li><strong>User ID:</strong> ${feedbackData.userId || 'Anonymous'}</li>
                </ul>
                
                <h3 style="color: #2666B4;">Feedback Message</h3>
                <div style="background: #fff; padding: 15px; border-left: 4px solid #3B5FAE; margin: 15px 0;">
                  <p style="white-space: pre-wrap;">${feedbackData.message}</p>
                </div>
                
                <p style="color: #666; font-size: 12px; margin-top: 20px;">
                  Submitted: ${feedbackData.timestamp && feedbackData.timestamp.toDate ? feedbackData.timestamp.toDate() : new Date().toISOString()}<br>
                  App Version: ${feedbackData.appVersion || 'Unknown'}
                </p>
                
                <p style="margin-top: 30px;">
                  <a href="https://console.firebase.google.com/project/${process.env.GCLOUD_PROJECT}/firestore/data/~2Ffeedback~2F${feedbackId}" 
                     style="background: #3B5FAE; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
                    View in Firebase Console
                  </a>
                </p>
              </div>
            `,
          });

          console.log('Email notification sent successfully');
        } catch (error) {
          console.error('Error sending email notification:', error);
          // Don't throw - we still want the feedback to be saved even if email fails
        }
      } else {
        console.log('Email transporter not configured, skipping email notification');
      }

      // Optional: Send auto-reply to user if email is provided
      if (feedbackData.userEmail && transporter) {
        try {
          await transporter.sendMail({
            from: `VocaBoost <${emailConfig.user}>`,
            to: feedbackData.userEmail,
            subject: 'Thank you for your feedback!',
            text: `
Hello ${feedbackData.userName || 'there'},

Thank you for taking the time to provide feedback about VocaBoost!

We've received your ${feedbackData.category} feedback and will review it carefully. Your input helps us improve the app for everyone.

Best regards,
The VocaBoost Team
            `.trim(),
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #3B5FAE;">Thank you for your feedback!</h2>
                <p>Hello ${feedbackData.userName || 'there'},</p>
                <p>Thank you for taking the time to provide feedback about VocaBoost!</p>
                <p>We've received your <strong>${feedbackData.category}</strong> feedback and will review it carefully. Your input helps us improve the app for everyone.</p>
                <p style="margin-top: 30px;">Best regards,<br>The VocaBoost Team</p>
              </div>
            `,
          });
          console.log('Auto-reply sent to user');
        } catch (error) {
          console.error('Error sending auto-reply:', error);
          // Don't throw - auto-reply is optional
        }
      }

      return null;
    });

/**
 * HTTP Cloud Function to get feedback statistics (optional)
 * Can be used for admin dashboard
 */
exports.getFeedbackStats = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const feedbackSnapshot = await admin.firestore().collection('feedback').get();
    const feedbacks = feedbackSnapshot.docs.map((doc) => doc.data());

    const stats = {
      total: feedbacks.length,
      byCategory: {},
      byStatus: {},
      averageRating: 0,
      ratingsCount: 0,
    };

    let totalRating = 0;
    feedbacks.forEach((feedback) => {
      // Count by category
      const category = feedback.category || 'general';
      stats.byCategory[category] = (stats.byCategory[category] || 0) + 1;

      // Count by status
      const status = feedback.status || 'new';
      stats.byStatus[status] = (stats.byStatus[status] || 0) + 1;

      // Calculate average rating
      if (feedback.rating) {
        totalRating += feedback.rating;
        stats.ratingsCount++;
      }
    });

    stats.averageRating = stats.ratingsCount > 0 
      ? (totalRating / stats.ratingsCount).toFixed(1) 
      : 0;

    res.json(stats);
  } catch (error) {
    console.error('Error getting feedback stats:', error);
    res.status(500).json({error: 'Failed to get feedback statistics'});
  }
});

/**
 * OpenAI API Proxy for Word Vocabulary
 * Securely handles OpenAI API calls from the PWA
 */
exports.openaiProxy = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({error: 'Method not allowed'});
    return;
  }

  try {
    const { messages, model = 'gpt-3.5-turbo', temperature = 0.7 } = req.body;

    console.log('[openaiProxy] Request received:', {
      model,
      messageCount: messages?.length,
      temperature,
      firstMessageContent: messages?.[0]?.content?.substring(0, 100),
    });

    if (!messages || !Array.isArray(messages)) {
      console.error('[openaiProxy] Invalid request: messages is not an array');
      res.status(400).json({error: 'Invalid request: messages array required'});
      return;
    }

    const openaiConfig = functions.config().openai || {};
    const apiKey = openaiConfig.apikey;
    if (!apiKey) {
      console.error('[openaiProxy] OpenAI API key not configured');
      res.status(500).json({error: 'OpenAI API key not configured'});
      return;
    }

    console.log('[openaiProxy] Calling OpenAI API with model:', model);
    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model,
        messages,
        temperature,
      },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
      }
    );

    console.log('[openaiProxy] OpenAI response status:', response.status);
    const responseContent = response.data?.choices?.[0]?.message?.content?.substring(0, 200);
    console.log('[openaiProxy] Response content preview:', responseContent);

    res.json(response.data);
  } catch (error) {
    const errorData = error.response && error.response.data ? error.response.data : null;
    const errorMessage = errorData && errorData.error && errorData.error.message ? errorData.error.message : 'Failed to call OpenAI API';
    const errorStatus = error.response && error.response.status ? error.response.status : 500;
    
    console.error('[openaiProxy] Error status:', errorStatus);
    console.error('[openaiProxy] Error data:', errorData);
    console.error('[openaiProxy] Full error:', error.message);
    
    res.status(errorStatus).json({
      error: errorMessage,
      status: errorStatus,
    });
  }
});


