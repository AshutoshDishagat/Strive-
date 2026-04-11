const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendSessionStartFCM = functions.firestore
    .document("remote_commands/{studentUid}")
    .onWrite(async (change, context) => {
        // If deleted, exit.
        if (!change.after.exists) return null;

        const data = change.after.data();

        // Only proceed if action is 'start' and it has NOT been handled
        if (data.action !== "start" || data.handled === true) return null;

        const studentUid = context.params.studentUid;

        // Get the student's FCM token from their user profile
        const userDoc = await admin.firestore().collection("users").doc(studentUid).get();

        if (!userDoc.exists) {
            console.log("User not found for uid:", studentUid);
            return null;
        }

        const userData = userDoc.data();
        const fcmToken = userData.student_fcm_token;

        if (!fcmToken) {
            console.log("No FCM token found for student:", studentUid);
            return null;
        }

        const duration = data.duration_minutes || 25;
        const durationText = duration === 0 ? "Unlimited" : `${duration} Minutes`;

        const payload = {
            token: fcmToken,
            notification: {
                title: "📚 Study Session Started!",
                body: `Your parent started a ${durationText} study session. Tap to begin.`,
            },
            data: {
                action: "start",
                duration_minutes: duration.toString(),
            },
            android: {
                priority: "high", // Required to wake app or show heads-up
            },
        };

        try {
            const response = await admin.messaging().send(payload);
            console.log("Successfully sent FCM message:", response);
        } catch (error) {
            console.error("Error sending FCM message:", error);
        }

        return null;
    });
