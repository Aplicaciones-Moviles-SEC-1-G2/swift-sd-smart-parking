/**
 * SD Smart Parking — Add extra vehicle records
 * Includes records with hitDailyCap: true on floor 2
 *
 * node add-records.js
 */

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

const db = admin.firestore();

function ts(hoursAgo) {
  return admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - hoursAgo * 3600 * 1000)
  );
}

// All new records — floor 2, int64-compatible numbers, exact field names
const NEW_RECORDS = [

  // ── AER-423: hit daily cap, still inside ─────────────────────────────────
  {
    plate: "AER423",
    type: "entry",
    timestamp: ts(3),
    floor: 2,
    spotNumber: 1,
    isRegistered: true,
    ownerEmail: "ana.lopez@uniandes.edu.co",
    ocrConfidence: 1.0,
    durationHours: null,
    hitDailyCap: true,
    photoURL: null,
  },

  // ── AER-423: previous trip earlier today (exit) ───────────────────────────
  {
    plate: "AER423",
    type: "exit",
    timestamp: ts(5.5),
    floor: 2,
    spotNumber: 1,
    isRegistered: true,
    ownerEmail: "ana.lopez@uniandes.edu.co",
    ocrConfidence: 1.0,
    durationHours: 6.0,
    hitDailyCap: false,
    photoURL: null,
  },
  {
    plate: "AER423",
    type: "entry",
    timestamp: ts(11.5),
    floor: 2,
    spotNumber: 4,
    isRegistered: true,
    ownerEmail: "ana.lopez@uniandes.edu.co",
    ocrConfidence: 1.0,
    durationHours: null,
    hitDailyCap: false,
    photoURL: null,
  },

  // ── BCG-321: hit daily cap, exited ───────────────────────────────────────
  {
    plate: "BCG321",
    type: "entry",
    timestamp: ts(9),
    floor: 2,
    spotNumber: 7,
    isRegistered: true,
    ownerEmail: "sebastian.torres@uniandes.edu.co",
    ocrConfidence: 0.96,
    durationHours: null,
    hitDailyCap: false,
    photoURL: null,
  },
  {
    plate: "BCG321",
    type: "exit",
    timestamp: ts(1.5),
    floor: 2,
    spotNumber: 7,
    isRegistered: true,
    ownerEmail: "sebastian.torres@uniandes.edu.co",
    ocrConfidence: 0.96,
    durationHours: 7.5,
    hitDailyCap: true,
    photoURL: null,
  },

  // ── KLM-555: hit daily cap, exited ───────────────────────────────────────
  {
    plate: "KLM555",
    type: "entry",
    timestamp: ts(10),
    floor: 2,
    spotNumber: 12,
    isRegistered: true,
    ownerEmail: "valentina.ruiz@uniandes.edu.co",
    ocrConfidence: 0.91,
    durationHours: null,
    hitDailyCap: false,
    photoURL: null,
  },
  {
    plate: "KLM555",
    type: "exit",
    timestamp: ts(2),
    floor: 2,
    spotNumber: 12,
    isRegistered: true,
    ownerEmail: "valentina.ruiz@uniandes.edu.co",
    ocrConfidence: 0.91,
    durationHours: 8.0,
    hitDailyCap: true,
    photoURL: null,
  },

  // ── PPQ-887: unregistered, hit daily cap ─────────────────────────────────
  {
    plate: "PPQ887",
    type: "entry",
    timestamp: ts(8),
    floor: 2,
    spotNumber: 3,
    isRegistered: false,
    ownerEmail: null,
    ocrConfidence: 0.88,
    durationHours: null,
    hitDailyCap: false,
    photoURL: null,
  },
  {
    plate: "PPQ887",
    type: "exit",
    timestamp: ts(0.5),
    floor: 2,
    spotNumber: 3,
    isRegistered: false,
    ownerEmail: null,
    ocrConfidence: 0.88,
    durationHours: 7.5,
    hitDailyCap: true,
    photoURL: null,
  },

  // ── RRS-001: unregistered, low confidence, still inside ──────────────────
  {
    plate: "RRS001",
    type: "entry",
    timestamp: ts(1),
    floor: 2,
    spotNumber: 17,
    isRegistered: false,
    ownerEmail: null,
    ocrConfidence: 0.62,
    durationHours: null,
    hitDailyCap: false,
    photoURL: null,
  },

  // ── GTC-456: normal trip on floor 2, no cap ──────────────────────────────
  {
    plate: "GTC456",
    type: "entry",
    timestamp: ts(4),
    floor: 2,
    spotNumber: 9,
    isRegistered: true,
    ownerEmail: "juan.perez@uniandes.edu.co",
    ocrConfidence: 0.94,
    durationHours: null,
    hitDailyCap: false,
    photoURL: null,
  },
  {
    plate: "GTC456",
    type: "exit",
    timestamp: ts(2.5),
    floor: 2,
    spotNumber: 9,
    isRegistered: true,
    ownerEmail: "juan.perez@uniandes.edu.co",
    ocrConfidence: 0.94,
    durationHours: 1.5,
    hitDailyCap: false,
    photoURL: null,
  },

  // ── XYZ-789: normal trip on floor 2, no cap ──────────────────────────────
  {
    plate: "XYZ789",
    type: "entry",
    timestamp: ts(6),
    floor: 2,
    spotNumber: 15,
    isRegistered: true,
    ownerEmail: "ana.lopez@uniandes.edu.co",
    ocrConfidence: 0.99,
    durationHours: null,
    hitDailyCap: false,
    photoURL: null,
  },
  {
    plate: "XYZ789",
    type: "exit",
    timestamp: ts(3.5),
    floor: 2,
    spotNumber: 15,
    isRegistered: true,
    ownerEmail: "ana.lopez@uniandes.edu.co",
    ocrConfidence: 0.99,
    durationHours: 2.5,
    hitDailyCap: false,
    photoURL: null,
  },
];

async function main() {
  console.log(`\n→ Adding ${NEW_RECORDS.length} vehicle records to floor 2...\n`);

  const batch = db.batch();
  for (const rec of NEW_RECORDS) {
    const ref = db.collection("vehicleRecords").doc();
    batch.set(ref, rec);
  }
  await batch.commit();

  const capped = NEW_RECORDS.filter((r) => r.hitDailyCap).length;
  console.log(`✓ ${NEW_RECORDS.length} records written (${capped} with hitDailyCap: true)`);

  const byPlate = {};
  for (const r of NEW_RECORDS) {
    byPlate[r.plate] = byPlate[r.plate] || [];
    byPlate[r.plate].push(`${r.type}${r.hitDailyCap ? " [CAP]" : ""}`);
  }
  console.log("\nSummary:");
  for (const [plate, events] of Object.entries(byPlate)) {
    console.log(`  ${plate}: ${events.join(" → ")}`);
  }

  console.log("");
  process.exit(0);
}

main().catch((err) => {
  console.error("Failed:", err);
  process.exit(1);
});
