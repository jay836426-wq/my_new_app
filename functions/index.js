const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
const {Resend} = require("resend");

admin.initializeApp();

setGlobalOptions({maxInstances: 10});

const RESEND_API_KEY = defineSecret("RESEND_API_KEY");

/**
 * Hashes a verification code using SHA-256.
 * @param {string} code The verification code.
 * @return {string} The hashed verification code.
 */
function hashCode(code) {
  return crypto
      .createHash("sha256")
      .update(code)
      .digest("hex");
}

exports.sendEmailOtp = onCall(
    {
      secrets: [RESEND_API_KEY],
    },
    async (request) => {
      const email = request.data && request.data.email ?
        request.data.email.trim().toLowerCase() :
        null;

      if (!email) {
        throw new HttpsError(
            "invalid-argument",
            "Email is required.",
        );
      }

      const code = crypto.randomInt(100000, 1000000).toString();
      const codeHash = hashCode(code);

      const expiresAt =
          admin.firestore.Timestamp.fromMillis(
              Date.now() + 10 * 60 * 1000,
          );

      await admin
          .firestore()
          .collection("emailOtps")
          .doc(email)
          .set({
            codeHash,
            expiresAt,
            createdAt:
              admin.firestore.FieldValue.serverTimestamp(),
            attempts: 0,
          });

      const resend = new Resend(RESEND_API_KEY.value());

      const result = await resend.emails.send({
        from: "TrakOn <onboarding@resend.dev>",
        to: email,
        subject: "Your TrakOn verification code",
        html: `
          <div style="font-family: Arial, sans-serif;">
            <h2>Verify your TrakOn account</h2>
            <p>Your verification code is:</p>
            <div style="
              font-size: 32px;
              font-weight: bold;
              letter-spacing: 8px;
              margin: 20px 0;
            ">
              ${code}
            </div>
            <p>This code expires in 10 minutes.</p>
            <p>If you didn't request this code, you can ignore this email.</p>
          </div>
        `,
      });

      if (result.error) {
        throw new HttpsError(
            "internal",
            "Unable to send verification email.",
        );
      }

      return {
        success: true,
      };
    },
);

exports.verifyEmailOtp = onCall(
    async (request) => {
      const email = request.data && request.data.email ?
    request.data.email.trim().toLowerCase() :
    null;
      const code = request.data && request.data.code ?
    request.data.code.trim() :
    null;

      if (!email || !code) {
        throw new HttpsError(
            "invalid-argument",
            "Email and code are required.",
        );
      }

      const ref = admin
          .firestore()
          .collection("emailOtps")
          .doc(email);

      const snapshot = await ref.get();

      if (!snapshot.exists) {
        throw new HttpsError(
            "not-found",
            "No verification code was found.",
        );
      }

      const data = snapshot.data();

      if (data.expiresAt.toMillis() < Date.now()) {
        await ref.delete();

        throw new HttpsError(
            "deadline-exceeded",
            "Verification code has expired.",
        );
      }

      if ((data.attempts || 0) >= 5) {
        await ref.delete();

        throw new HttpsError(
            "resource-exhausted",
            "Too many incorrect attempts.",
        );
      }

      const enteredHash = hashCode(code);

      if (enteredHash !== data.codeHash) {
        await ref.update({
          attempts:
              admin.firestore.FieldValue.increment(1),
        });

        throw new HttpsError(
            "permission-denied",
            "Incorrect verification code.",
        );
      }

      await ref.delete();

      return {
        success: true,
      };
    },
);
