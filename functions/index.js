const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
const {Resend} = require("resend");
const bcrypt = require("bcryptjs");

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

/**
 * Reserves a normalized username for a Firebase user.
 * @param {string} username The requested username.
 * @param {string} uid The Firebase user UID.
 * @return {Promise<string>} The normalized username.
 */
async function reserveUsername(username, uid) {
  const normalizedUsername =
      username.trim().toLowerCase();

  if (!normalizedUsername) {
    throw new HttpsError(
        "invalid-argument",
        "Username is required.",
    );
  }

  const usernameRef = admin
      .firestore()
      .collection("usernames")
      .doc(normalizedUsername);

  await admin.firestore().runTransaction(
      async (transaction) => {
        const snapshot =
            await transaction.get(usernameRef);

        if (snapshot.exists) {
          const existingUid =
              snapshot.data().uid;

          if (existingUid !== uid) {
            throw new HttpsError(
                "already-exists",
                "That username is already taken.",
            );
          }
        }

        transaction.set(usernameRef, {
          uid,
          username: normalizedUsername,
        });
      },
  );

  return normalizedUsername;
}

exports.sendEmailOtp = onCall(
    {
      secrets: [RESEND_API_KEY],
    },
    async (request) => {
      const email =
          request.data && request.data.email ?
            request.data.email.trim().toLowerCase() :
            null;

      if (!email) {
        throw new HttpsError(
            "invalid-argument",
            "Email is required.",
        );
      }

      const code =
          crypto.randomInt(100000, 1000000).toString();

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

      const resend =
          new Resend(RESEND_API_KEY.value());

      const result = await resend.emails.send({
        from: "TrakOn <verify@gettrakon.com>",
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

            <p>
              If you didn't request this code,
              you can ignore this email.
            </p>
          </div>
        `,
      });

      if (result.error) {
        // Print the actual Resend error in Firebase Functions logs
        // so we can see exactly why the email was rejected.
        console.error("RESEND EMAIL ERROR:", result.error);

        throw new HttpsError(
            "internal",
            result.error.message || "Unable to send verification email.",
        );
      }

      return {
        success: true,
      };
    },
);

exports.verifyEmailOtp = onCall(
    async (request) => {
      const email =
          request.data && request.data.email ?
            request.data.email.trim().toLowerCase() :
            null;

      const code =
          request.data && request.data.code ?
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

      const enteredHash =
          hashCode(code);

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

exports.saveUserProfile = onCall(
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be signed in.",
        );
      }

      const uid = request.auth.uid;
      const data = request.data || {};

      const normalizedUsername =
          await reserveUsername(
              data.username || "",
              uid,
          );

      await admin
          .firestore()
          .collection("users")
          .doc(uid)
          .set({
            firstName: data.firstName || "",
            lastName: data.lastName || "",
            fullName: data.fullName || "",
            username: normalizedUsername,
            dateOfBirth: data.dateOfBirth || "",
            email: data.email || null,
            phoneNumber: data.phoneNumber || null,
            authMethod: data.authMethod || "",
            createdAt:
                admin.firestore.FieldValue.serverTimestamp(),
          });

      return {
        success: true,
      };
    },
);

exports.completePhoneSignup = onCall(
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Phone verification is required.",
        );
      }

      const data = request.data || {};

      const password = data.password;
      const firstName = data.firstName || "";
      const lastName = data.lastName || "";
      const username = data.username || "";
      const dateOfBirth = data.dateOfBirth || "";

      if (!password) {
        throw new HttpsError(
            "invalid-argument",
            "Password is required.",
        );
      }

      if (password.length < 7) {
        throw new HttpsError(
            "invalid-argument",
            "Password must be at least 7 characters.",
        );
      }

      // THIS WAS MISSING BEFORE
      const uid = request.auth.uid;

      const normalizedUsername =
          await reserveUsername(
              username,
              uid,
          );

      const userRecord =
          await admin.auth().getUser(uid);

      const phoneNumber =
          userRecord.phoneNumber;

      if (!phoneNumber) {
        throw new HttpsError(
            "failed-precondition",
            "A verified phone number is required.",
        );
      }

      const phoneAccountRef = admin
          .firestore()
          .collection("phoneAccounts")
          .doc(uid);

      const existingAccount =
          await phoneAccountRef.get();

      if (existingAccount.exists) {
        throw new HttpsError(
            "already-exists",
            "This phone account has already been registered.",
        );
      }

      const passwordHash =
          await bcrypt.hash(
              password,
              12,
          );

      const fullName =
          `${firstName} ${lastName}`.trim();

      await admin.auth().updateUser(
          uid,
          {
            displayName: fullName,
          },
      );

      await phoneAccountRef.set({
        uid,
        phoneNumber,
        passwordHash,
        createdAt:
            admin.firestore.FieldValue.serverTimestamp(),
      });

      await admin
          .firestore()
          .collection("users")
          .doc(uid)
          .set({
            firstName,
            lastName,
            fullName,
            username: normalizedUsername,
            dateOfBirth,
            phoneNumber,
            email: null,
            authMethod: "phone",
            createdAt:
                admin.firestore.FieldValue.serverTimestamp(),
          });

      return {
        success: true,
      };
    },
);

exports.loginWithPhonePassword = onCall(
    async (request) => {
      const data = request.data || {};

      const phoneNumber =
          data.phoneNumber;

      const password =
          data.password;

      if (!phoneNumber || !password) {
        throw new HttpsError(
            "invalid-argument",
            "Phone number and password are required.",
        );
      }

      const snapshot = await admin
          .firestore()
          .collection("phoneAccounts")
          .where(
              "phoneNumber",
              "==",
              phoneNumber,
          )
          .limit(1)
          .get();

      if (snapshot.empty) {
        throw new HttpsError(
            "unauthenticated",
            "Invalid phone number or password.",
        );
      }

      const accountDoc =
          snapshot.docs[0];

      const account =
          accountDoc.data();

      const passwordMatches =
          await bcrypt.compare(
              password,
              account.passwordHash,
          );

      if (!passwordMatches) {
        throw new HttpsError(
            "unauthenticated",
            "Invalid phone number or password.",
        );
      }

      const customToken =
          await admin.auth().createCustomToken(
              account.uid,
          );

      return {
        success: true,
        customToken,
      };
    },
);

exports.resolveUsername = onCall(
    async (request) => {
      const data = request.data || {};

      const username =
          data.username ?
            data.username.trim().toLowerCase() :
            null;

      if (!username) {
        throw new HttpsError(
            "invalid-argument",
            "Username is required.",
        );
      }

      // Use the username reservation instead of
      // searching every user document.
      const usernameDoc = await admin
          .firestore()
          .collection("usernames")
          .doc(username)
          .get();

      if (!usernameDoc.exists) {
        throw new HttpsError(
            "not-found",
            "No account was found.",
        );
      }

      const uid =
          usernameDoc.data().uid;

      const userDoc = await admin
          .firestore()
          .collection("users")
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw new HttpsError(
            "not-found",
            "No account was found.",
        );
      }

      const user =
          userDoc.data();

      return {
        authMethod: user.authMethod,
        email: user.email || null,
        phoneNumber:
            user.phoneNumber || null,
      };
    },
);

exports.sendUsernameReminder = onCall(
    {
      secrets: [RESEND_API_KEY],
    },
    async (request) => {
      const data = request.data || {};

      const email =
          data.email ?
            data.email.trim().toLowerCase() :
            null;

      if (!email) {
        throw new HttpsError(
            "invalid-argument",
            "Email is required.",
        );
      }

      let userRecord;

      try {
        userRecord =
            await admin.auth().getUserByEmail(email);
      } catch (error) {
        // Return a generic success response so we do not
        // reveal whether an email has an account.
        return {
          success: true,
        };
      }

      const userDoc = await admin
          .firestore()
          .collection("users")
          .doc(userRecord.uid)
          .get();

      if (!userDoc.exists) {
        return {
          success: true,
        };
      }

      const username =
          userDoc.data().username;

      if (!username) {
        return {
          success: true,
        };
      }

      const resend =
          new Resend(RESEND_API_KEY.value());

      const result = await resend.emails.send({
        from: "TrakOn <onboarding@resend.dev>",
        to: email,
        subject: "Your TrakOn username",
        html: `
          <div style="font-family: Arial, sans-serif;">
            <h2>Your TrakOn username</h2>

            <p>
              You requested a reminder of your username.
            </p>

            <div style="
              font-size: 24px;
              font-weight: bold;
              margin: 20px 0;
            ">
              ${username}
            </div>

            <p>
              If you didn't request this,
              you can ignore this email.
            </p>
          </div>
        `,
      });

      if (result.error) {
        throw new HttpsError(
            "internal",
            "Unable to send username reminder.",
        );
      }

      return {
        success: true,
      };
    },
);

// Permanently deletes the signed-in TrakOn user's
// backend profile data and Firebase Authentication account.
exports.deleteTrakOnAccount = onCall(
    async (request) => {
      // Only an authenticated user may delete an account.
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be signed in to delete your account.",
        );
      }

      const uid = request.auth.uid;

      const db = admin.firestore();

      const userRef = db
          .collection("users")
          .doc(uid);

      const phoneAccountRef = db
          .collection("phoneAccounts")
          .doc(uid);

      // Read the profile before deleting it because we may
      // need the username/email to clean up related records.
      const userSnapshot = await userRef.get();

      let username = null;
      let email = null;

      if (userSnapshot.exists) {
        const userData = userSnapshot.data();

        username = userData.username || null;
        email = userData.email || null;
      }

      const batch = db.batch();

      // Delete the main TrakOn profile.
      batch.delete(userRef);

      // Delete phone-login information if it exists.
      batch.delete(phoneAccountRef);

      // Remove the username reservation so the username
      // can be used again after the account is deleted.
      if (username) {
        const usernameRef = db
            .collection("usernames")
            .doc(username.toLowerCase());

        batch.delete(usernameRef);
      }

      // Remove any leftover email OTP for this account.
      if (email) {
        const emailOtpRef = db
            .collection("emailOtps")
            .doc(email.toLowerCase());

        batch.delete(emailOtpRef);
      }

      await batch.commit();

      // Delete the Firebase Authentication user last.
      await admin.auth().deleteUser(uid);

      return {
        success: true,
      };
    },
);
