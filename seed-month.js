/**
 * SD Smart Parking — Last-month historical records
 * Generates realistic daily traffic for March 11 – April 9, 2026
 *
 * node seed-month.js
 */

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

const db = admin.firestore();

// ─── Known accounts (registered vehicles) ────────────────────────────────────
const REGISTERED = [
  { plate: "ABC123", email: "ana.lopez@uniandes.edu.co" },
  { plate: "XYZ789", email: "ana.lopez@uniandes.edu.co" },
  { plate: "GTC456", email: "juan.perez@uniandes.edu.co" },
  { plate: "SDQ001", email: "maria.garcia@uniandes.edu.co" },
  { plate: "SDQ002", email: "maria.garcia@uniandes.edu.co" },
  { plate: "BCG321", email: "sebastian.torres@uniandes.edu.co" },
  { plate: "KLM555", email: "valentina.ruiz@uniandes.edu.co" },
  { plate: "AER423", email: "ana.lopez@uniandes.edu.co" },
];

// Unregistered plates that show up occasionally
const UNREGISTERED = [
  "VIS999", "RPK777", "ZZZ404", "MNO876", "PPQ887",
  "TRQ112", "LLB993", "HJK234", "WQP541", "FGH678",
  "NNB321", "YYC845", "OOP132", "AAZ007", "CBV229",
];

const DAILY_CAP_HOURS = 8; // 8h × 2000 = 16 000 → hits daily cap

// ─── Helpers ─────────────────────────────────────────────────────────────────

function rand(min, max) {
  return Math.random() * (max - min) + min;
}
function randInt(min, max) {
  return Math.floor(rand(min, max + 1));
}
function pick(arr) {
  return arr[randInt(0, arr.length - 1)];
}
function round2(n) {
  return Math.round(n * 100) / 100;
}

/** Build a Firestore Timestamp for a given Date */
function ts(date) {
  return admin.firestore.Timestamp.fromDate(date);
}

/** Return a Date at hh:mm on a given day (local) */
function dateAt(day, hour, minuteFraction = 0) {
  const d = new Date(day);
  d.setHours(hour, Math.floor(minuteFraction * 60), 0, 0);
  return d;
}

/** true if Saturday or Sunday */
function isWeekend(date) {
  const d = date.getDay();
  return d === 0 || d === 6;
}

/**
 * Generate one spot number on a floor.
 * Spots: floor*100+1 … floor*100+20
 */
function spotOn(floor) {
  return floor * 100 + randInt(1, 20);
}

// ─── Trip builder ─────────────────────────────────────────────────────────────

/**
 * Build an entry+exit pair (or entry-only if still "parked").
 * Returns 1 or 2 record objects.
 */
function makeTrip({ plate, email, floor, entryDate, durationHours, confidence, dailyTotal }) {
  const isRegistered = email !== null;
  const spotNumber   = spotOn(floor);

  // Does this exit push cumulative time past the daily cap?
  const exitDailyTotal = dailyTotal + durationHours;
  const hitDailyCap    = exitDailyTotal >= DAILY_CAP_HOURS;

  const entryRec = {
    plate,
    type: "entry",
    timestamp: ts(entryDate),
    floor,
    spotNumber,
    isRegistered,
    ownerEmail: email,
    ocrConfidence: round2(confidence),
    durationHours: null,
    hitDailyCap: false,
    photoURL: null,
  };

  const exitDate = new Date(entryDate.getTime() + durationHours * 3600 * 1000);
  const exitRec  = {
    plate,
    type: "exit",
    timestamp: ts(exitDate),
    floor,
    spotNumber,
    isRegistered,
    ownerEmail: email,
    ocrConfidence: round2(confidence),
    durationHours: round2(durationHours),
    hitDailyCap,
    photoURL: null,
  };

  return [entryRec, exitRec];
}

// ─── Daily traffic generator ──────────────────────────────────────────────────

/**
 * Generate all trips for a single calendar day.
 * Weekdays: 15-25 cars; Weekends: 5-10 cars.
 */
function tripsForDay(day) {
  const weekend    = isWeekend(day);
  const carCount   = weekend ? randInt(5, 10) : randInt(15, 25);
  const records    = [];

  // Pool = registered + random unregistered selection
  const unreg = UNREGISTERED.filter(() => Math.random() < 0.4);
  const pool  = [
    ...REGISTERED.map(r => ({ plate: r.plate, email: r.email })),
    ...unreg.map(p => ({ plate: p, email: null })),
  ];

  // Shuffle pool and pick carCount vehicles
  const shuffled = pool.sort(() => Math.random() - 0.5).slice(0, carCount);

  // Spread entry times across operating hours (6:00 – 20:00)
  const usedSlots = new Set();
  for (const vehicle of shuffled) {
    // Pick a random entry hour (bias toward 7-9 and 12-14 on weekdays)
    let entryHour;
    if (!weekend && Math.random() < 0.35) {
      entryHour = randInt(7, 9);   // morning peak
    } else if (!weekend && Math.random() < 0.3) {
      entryHour = randInt(12, 14); // midday
    } else {
      entryHour = randInt(6, 20);
    }
    const entryMin  = rand(0, 1);           // fractional minutes
    const entryDate = dateAt(day, entryHour, entryMin);

    // Duration: 30 min – 9 h; occasionally a long stay that hits daily cap
    const hitCap = Math.random() < 0.08;    // ~8% of trips hit daily cap
    const duration = hitCap
      ? rand(DAILY_CAP_HOURS, DAILY_CAP_HOURS + 2)
      : rand(0.5, 6.5);

    // Don't run past closing hour (22:00)
    const closingDate = dateAt(day, 22);
    const exitDate    = new Date(entryDate.getTime() + duration * 3600 * 1000);
    if (exitDate > closingDate) continue;

    const floor = randInt(1, 3);
    const confidence = vehicle.email
      ? round2(rand(0.82, 1.0))   // registered → higher confidence
      : round2(rand(0.55, 0.95)); // unregistered → wider range

    const pair = makeTrip({
      plate:        vehicle.plate,
      email:        vehicle.email,
      floor,
      entryDate,
      durationHours: duration,
      confidence,
      dailyTotal:   hitCap ? DAILY_CAP_HOURS : 0,
    });
    records.push(...pair);
  }

  return records;
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  // March 11 → April 9, 2026 (30 days, not including today)
  const START = new Date("2026-03-11T00:00:00");
  const END   = new Date("2026-04-09T00:00:00");

  const allRecords = [];
  for (let d = new Date(START); d <= END; d.setDate(d.getDate() + 1)) {
    allRecords.push(...tripsForDay(new Date(d)));
  }

  console.log(`\n→ Generated ${allRecords.length} records across 30 days`);
  console.log(`  Capped trips: ${allRecords.filter(r => r.hitDailyCap).length}`);
  console.log(`  Low-confidence (needsReview): ${allRecords.filter(r => r.ocrConfidence < 0.75).length}`);
  console.log(`  Unregistered: ${allRecords.filter(r => !r.isRegistered).length}`);
  console.log("\n→ Writing to Firestore in batches...");

  // Firestore batch limit is 500 operations
  const BATCH_SIZE = 400;
  let written = 0;

  for (let i = 0; i < allRecords.length; i += BATCH_SIZE) {
    const chunk = allRecords.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const rec of chunk) {
      batch.set(db.collection("vehicleRecords").doc(), rec);
    }
    await batch.commit();
    written += chunk.length;
    console.log(`  ✓ ${written} / ${allRecords.length} written`);
  }

  console.log("\n=== Done! ===\n");
  process.exit(0);
}

main().catch(err => {
  console.error("Failed:", err);
  process.exit(1);
});
