const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

initializeApp();

exports.pushOnNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const uid = data.userId || data.recipientId;
    if (!uid) return;

    const userSnap = await getFirestore().collection("users").doc(uid).get();
    const token = userSnap.get("fcmToken");
    if (!token) return;

    await getMessaging().send({
      token,
      notification: {
        title: data.title || "Sahyog",
        body: data.body || "",
      },
      data: {
        donationId: String(data.donationId || ""),
        status: String(data.status || ""),
      },
    });
  }
);
