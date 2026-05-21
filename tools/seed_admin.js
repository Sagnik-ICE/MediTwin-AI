const admin = require('firebase-admin');
const fs = require('fs');
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

async function main() {
  const argv = yargs(hideBin(process.argv))
    .option('serviceAccount', { type: 'string', describe: 'Path to service account JSON (or set FIREBASE_SERVICE_ACCOUNT)' })
    .option('project', { type: 'string', describe: 'Firebase project id (or set FIREBASE_PROJECT)' })
    .option('uid', { type: 'string', describe: 'UID for the admin doc key (can be omitted if --email is provided)' })
    .option('email', { type: 'string', describe: 'Admin email (used to lookup uid if --uid not provided)' })
    .option('displayName', { type: 'string', describe: 'Display name' })
    .option('addedBy', { type: 'string', describe: 'Source who added this admin', default: 'script' })
    .help()
    .argv;

  const saPath = argv.serviceAccount || process.env.FIREBASE_SERVICE_ACCOUNT;
  const projectId = argv.project || process.env.FIREBASE_PROJECT;
  const uidArg = argv.uid || process.env.ADMIN_UID;
  const emailArg = argv.email || process.env.ADMIN_EMAIL;

  if (!saPath || !fs.existsSync(saPath)) {
    console.error('Service account file not found. Provide --serviceAccount or set FIREBASE_SERVICE_ACCOUNT.');
    process.exit(2);
  }

  const serviceAccount = require(saPath);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: argv.project,
  });

  const db = admin.firestore();

  let uid = uidArg;
  const email = emailArg ? emailArg.toLowerCase() : undefined;

  if (!uid && !email) {
    console.error('Either --uid (or ADMIN_UID) or --email (or ADMIN_EMAIL) must be provided.');
    process.exit(2);
  }

  try {
    if (!uid && email) {
      // Try to lookup user by email to obtain UID
      try {
        const user = await admin.auth().getUserByEmail(email);
        uid = user.uid;
        console.log('Found user UID for', email, '->', uid);
      } catch (err) {
        console.error('Failed to find user by email:', email, err.message || err);
        process.exit(2);
      }
    }

    const docRef = db.collection('app_admins').doc(uid);
    const data = {
      email: email || '',
      displayName: argv.displayName || process.env.ADMIN_DISPLAY_NAME || '',
      uid: uid,
      addedBy: argv.addedBy || process.env.ADDED_BY || 'script',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await docRef.set(data, { merge: true });
    console.log('Admin doc written at app_admins/' + uid);
    process.exit(0);
  } catch (e) {
    console.error('Failed to write admin doc:', e);
    process.exit(1);
  }
}

main().catch(e => { console.error(e); process.exit(1); });
