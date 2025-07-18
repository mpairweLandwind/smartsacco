// FILEPATH: c:/Users/Lisa/smartsacco/webhook-server/index.js

const express = require('express');
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// CORS middleware
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

/**
 * Webhook endpoint to receive Mobile Money payment callbacks.
 * Saves callback data to Firestore collection 'momo_callbacks'.
 * Updates transaction status based on payment result.
 */
app.post('/momo-callback', async (req, res) => {
  try {
    const callbackData = req.body;
    const transactionId = callbackData.transactionId || callbackData.externalId;
    const status = callbackData.status || callbackData.resultCode;
    const referenceId = callbackData.referenceId || callbackData.requestId;

    console.log('Received MoMo callback:', {
      transactionId,
      status,
      referenceId,
      data: callbackData
    });

    if (!transactionId) {
      console.error('Missing transactionId in callback');
      return res.status(400).send('Missing transactionId');
    }

    // Save callback data
    await db.collection('momo_callbacks').doc(transactionId).set({
      ...callbackData,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false
    });

    // Process the callback based on status
    await processMoMoCallback(transactionId, status, callbackData);

    console.log('Callback processed successfully for transaction:', transactionId);
    res.status(200).send('Callback received and processed');
  } catch (error) {
    console.error('Error processing MoMo callback:', error);
    res.status(500).send('Internal Server Error');
  }
});

/**
 * Process Mobile Money callback and update transaction status
 */
async function processMoMoCallback(transactionId, status, callbackData) {
  try {
    // Find the transaction in Firestore
    const transactionsRef = db.collectionGroup('transactions');
    const query = transactionsRef.where('reference', '==', transactionId);
    const snapshot = await query.get();

    if (snapshot.empty) {
      console.log('No transaction found for ID:', transactionId);
      return;
    }

    const transactionDoc = snapshot.docs[0];
    const transactionData = transactionDoc.data();
    const userId = transactionDoc.ref.parent.parent.id;

    console.log('Found transaction:', {
      userId,
      transactionId: transactionDoc.id,
      currentStatus: transactionData.status,
      newStatus: status
    });

    // Determine new status based on MoMo callback
    let newStatus = 'failed';
    let errorMessage = 'Payment failed';

    switch (status) {
      case 'SUCCESSFUL':
      case 'SUCCESS':
        newStatus = 'completed';
        errorMessage = null;
        break;
      case 'PENDING':
      case 'INITIATED':
        newStatus = 'processing';
        errorMessage = 'Payment is being processed';
        break;
      case 'FAILED':
      case 'REJECTED':
      case 'CANCELLED':
        newStatus = 'failed';
        errorMessage = callbackData.message || 'Payment was rejected';
        break;
      case 'TIMEOUT':
        newStatus = 'failed';
        errorMessage = 'Payment timed out';
        break;
      default:
        newStatus = 'failed';
        errorMessage = `Unknown status: ${status}`;
    }

    // Update transaction status
    const updateData = {
      status: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      momoCallback: callbackData
    };

    if (errorMessage) {
      updateData.error = errorMessage;
    }

    if (newStatus === 'completed') {
      updateData.completedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    await transactionDoc.ref.update(updateData);

    // Update corresponding savings record
    const savingsQuery = db
      .collection('users')
      .doc(userId)
      .collection('savings')
      .where('transactionId', '==', transactionDoc.id);
    
    const savingsSnapshot = await savingsQuery.get();
    if (!savingsSnapshot.empty) {
      await savingsSnapshot.docs[0].ref.update({
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // Send notification to user
    await sendPaymentNotification(userId, transactionData, newStatus, errorMessage);

    // Mark callback as processed
    await db.collection('momo_callbacks').doc(transactionId).update({
      processed: true,
      processedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('Transaction status updated:', {
      transactionId,
      newStatus,
      userId
    });

  } catch (error) {
    console.error('Error processing MoMo callback:', error);
    throw error;
  }
}

/**
 * Send notification to user about payment status
 */
async function sendPaymentNotification(userId, transactionData, status, errorMessage) {
  try {
    const amount = transactionData.amount || 0;
    const type = transactionData.type || 'payment';
    const method = transactionData.method || 'Mobile Money';

    let title, message;

    switch (status) {
      case 'completed':
        title = 'Payment Successful';
        message = `Your ${type} of UGX ${amount.toFixed(2)} via ${method} has been completed successfully.`;
        break;
      case 'processing':
        title = 'Payment Processing';
        message = `Your ${type} of UGX ${amount.toFixed(2)} via ${method} is being processed.`;
        break;
      case 'failed':
        title = 'Payment Failed';
        message = `Your ${type} of UGX ${amount.toFixed(2)} via ${method} failed. ${errorMessage || ''}`;
        break;
      default:
        title = 'Payment Update';
        message = `Your ${type} of UGX ${amount.toFixed(2)} via ${method} status: ${status}`;
    }

    await db.collection('users').doc(userId).collection('notifications').add({
      title,
      message,
      type: status === 'completed' ? 0 : 3, // 0 = payment, 3 = general
      date: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
      data: {
        transactionId: transactionData.reference,
        amount,
        type,
        status
      }
    });

    console.log('Notification sent to user:', userId);
  } catch (error) {
    console.error('Error sending notification:', error);
  }
}

/**
 * Webhook endpoint for payment status queries
 */
app.get('/payment-status/:transactionId', async (req, res) => {
  try {
    const { transactionId } = req.params;

    // Check in transactions collection
    const transactionsRef = db.collectionGroup('transactions');
    const query = transactionsRef.where('reference', '==', transactionId);
    const snapshot = await query.get();

    if (snapshot.empty) {
      return res.status(404).json({
        success: false,
        message: 'Transaction not found'
      });
    }

    const transactionDoc = snapshot.docs[0];
    const transactionData = transactionDoc.data();

    res.json({
      success: true,
      transaction: {
        id: transactionDoc.id,
        status: transactionData.status,
        amount: transactionData.amount,
        type: transactionData.type,
        method: transactionData.method,
        date: transactionData.date,
        reference: transactionData.reference,
        error: transactionData.error
      }
    });

  } catch (error) {
    console.error('Error querying payment status:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

/**
 * Webhook endpoint for payment retry
 */
app.post('/retry-payment/:transactionId', async (req, res) => {
  try {
    const { transactionId } = req.params;
    const { phoneNumber } = req.body;

    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required'
      });
    }

    // Find the transaction
    const transactionsRef = db.collectionGroup('transactions');
    const query = transactionsRef.where('reference', '==', transactionId);
    const snapshot = await query.get();

    if (snapshot.empty) {
      return res.status(404).json({
        success: false,
        message: 'Transaction not found'
      });
    }

    const transactionDoc = snapshot.docs[0];
    const transactionData = transactionDoc.data();

    // Update transaction status to retry
    await transactionDoc.ref.update({
      status: 'retrying',
      retryCount: (transactionData.retryCount || 0) + 1,
      lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
      phoneNumber: phoneNumber
    });

    // Here you would typically call your MoMo API to retry the payment
    // For now, we'll just update the status
    console.log('Payment retry initiated for transaction:', transactionId);

    res.json({
      success: true,
      message: 'Payment retry initiated',
      transactionId
    });

  } catch (error) {
    console.error('Error retrying payment:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    service: 'Smart SACCO Webhook Server'
  });
});

/**
 * Get webhook statistics
 */
app.get('/stats', async (req, res) => {
  try {
    const callbacksSnapshot = await db.collection('momo_callbacks').get();
    const totalCallbacks = callbacksSnapshot.size;
    const processedCallbacks = callbacksSnapshot.docs.filter(doc => doc.data().processed).length;

    res.json({
      success: true,
      stats: {
        totalCallbacks,
        processedCallbacks,
        pendingCallbacks: totalCallbacks - processedCallbacks,
        uptime: process.uptime()
      }
    });

  } catch (error) {
    console.error('Error getting stats:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? error.message : undefined
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Endpoint not found'
  });
});

app.listen(PORT, () => {
  console.log(`Smart SACCO Webhook Server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`MoMo callback: http://localhost:${PORT}/momo-callback`);
});

module.exports = app;