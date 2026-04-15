/**
 * SD Smart Parking — Firestore Seed Script
 *
 * Usage:
 *   1. npm install firebase-admin
 *   2. Download your service account key from:
 *      Firebase Console → Project Settings → Service accounts → Generate new private key
 *   3. Save it as serviceAccountKey.json next to this file
 *   4. node seed.js
 */

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const auth = admin.auth();
const db = admin.firestore();

// ---------------------------------------------------------------------------
// CONFIG
// ---------------------------------------------------------------------------

const PARKING_CONFIG = {
  parkingName: "SD Building Parking",
  numberOfFloors: 3,
  spotsPerFloor: 20,
  hourlyRate: 2000,
  ocrConfidenceThreshold: 0.75,
  openingHour: 6,
  closingHour: 22,
};

// Users to create in Firebase Auth + Firestore
// role: "manager" | "driver"
const USERS = [
  {
    name: "Carlos Gerente",
    email: "gerente@sdparking.com",
    password: "Gerente123!",
    role: "manager",
    cars: [],
  },
  {
    name: "Ana López",
    email: "ana.lopez@uniandes.edu.co",
    password: "Driver123!",
    role: "driver",
    cars: [
      { plate: "ABC-123", name: "Mazda CX-5" },
      { plate: "XYZ-789", name: "Toyota Corolla" },
    ],
  },
  {
    name: "Juan Pérez",
    email: "juan.perez@uniandes.edu.co",
    password: "Driver123!",
    role: "driver",
    cars: [
      { plate: "GTC-456", name: "Chevrolet Spark" },
    ],
  },
  {
    name: "María García",
    email: "maria.garcia@uniandes.edu.co",
    password: "Driver123!",
    role: "driver",
    cars: [
      { plate: "SDQ-001", name: "Renault Kwid" },
      { plate: "SDQ-002", name: "Nissan Kicks" },
    ],
  },
  {
    name: "Sebastián Torres",
    email: "sebastian.torres@uniandes.edu.co",
    password: "Driver123!",
    role: "driver",
    cars: [
      { plate: "BCG-321", name: "Hyundai Tucson" },
    ],
  },
  {
    name: "Valentina Ruiz",
    email: "valentina.ruiz@uniandes.edu.co",
    password: "Driver123!",
    role: "driver",
    cars: [
      { plate: "KLM-555", name: "Kia Picanto" },
    ],
  },
];

// Plates for vehicle records (mix of registered and unregistered)
const RECORD_PLATES = {
  registered: [
    { plate: "ABC-123", email: "ana.lopez@uniandes.edu.co" },
    { plate: "XYZ-789", email: "ana.lopez@uniandes.edu.co" },
    { plate: "GTC-456", email: "juan.perez@uniandes.edu.co" },
    { plate: "SDQ-001", email: "maria.garcia@uniandes.edu.co" },
    { plate: "BCG-321", email: "sebastian.torres@uniandes.edu.co" },
    { plate: "KLM-555", email: "valentina.ruiz@uniandes.edu.co" },
  ],
  unregistered: ["VIS-999", "RPK-777", "ZZZ-404", "MNO-876"],
};

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------

function hoursAgo(h) {
  return admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - h * 60 * 60 * 1000)
  );
}

function randomBetween(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomConfidence(min = 0.6, max = 1.0) {
  return Math.round((Math.random() * (max - min) + min) * 100) / 100;
}

// ---------------------------------------------------------------------------
// SEED FUNCTIONS
// ---------------------------------------------------------------------------

async function seedConfig() {
  console.log("→ Writing config/parking...");
  await db.collection("config").doc("parking").set(PARKING_CONFIG);
  console.log("  ✓ config/parking written");
}

async function seedUsers() {
  console.log("→ Creating Firebase Auth users + Firestore documents...");
  const results = [];

  for (const user of USERS) {
    let uid;
    try {
      // Try creating; if email already exists, fetch existing UID
      const record = await auth.createUser({
        email: user.email,
        password: user.password,
        displayName: user.name,
      });
      uid = record.uid;
      console.log(`  ✓ Auth user created: ${user.email} (${uid})`);
    } catch (err) {
      if (err.code === "auth/email-already-exists") {
        const existing = await auth.getUserByEmail(user.email);
        uid = existing.uid;
        console.log(`  ↩ Auth user already exists: ${user.email} (${uid})`);
      } else {
        throw err;
      }
    }

    const carsData = user.cars.map((c) => ({ plate: c.plate, name: c.name }));

    await db.collection("users").doc(uid).set({
      name: user.name,
      email: user.email,
      role: user.role,
      createdAt: admin.firestore.Timestamp.now(),
      cars: carsData,
    });
    console.log(`  ✓ Firestore user written: ${user.email}`);

    results.push({ uid, ...user });
  }

  return results;
}

async function seedParkingSpots() {
  console.log("→ Seeding parking spots...");
  const { numberOfFloors, spotsPerFloor } = PARKING_CONFIG;

  // Spots that will be occupied (to match vehicle records below)
  const occupiedSpots = new Set([
    "1-101", "1-103", "1-107",
    "2-201", "2-205",
    "3-302",
  ]);

  const batch = db.batch();
  let count = 0;

  for (let floor = 1; floor <= numberOfFloors; floor++) {
    for (let index = 1; index <= spotsPerFloor; index++) {
      const number = floor * 100 + index;
      const key = `${floor}-${number}`;
      const isAvailable = !occupiedSpots.has(key);

      const ref = db.collection("parkingSpots").doc(`spot-${number}`);
      batch.set(ref, {
        number,
        floor,
        isAvailable,
        currentPlate: "",
      });
      count++;
    }
  }

  await batch.commit();
  console.log(`  ✓ ${count} parking spots written`);
}

async function seedVehicleRecords() {
  console.log("→ Seeding vehicle records...");
  const records = [];

  // --- Completed trips (entry + exit pairs) ---
  const completedTrips = [
    // Registered vehicles
    { plate: "ABC-123", email: "ana.lopez@uniandes.edu.co", entryHoursAgo: 8, duration: 2.5, floor: 1, spot: 101, confidence: 0.98 },
    { plate: "GTC-456", email: "juan.perez@uniandes.edu.co", entryHoursAgo: 6, duration: 1.0, floor: 2, spot: 205, confidence: 0.92 },
    { plate: "SDQ-001", email: "maria.garcia@uniandes.edu.co", entryHoursAgo: 5, duration: 3.0, floor: 3, spot: 315, confidence: 0.87 },
    { plate: "BCG-321", email: "sebastian.torres@uniandes.edu.co", entryHoursAgo: 4, duration: 1.5, floor: 1, spot: 112, confidence: 0.95 },
    { plate: "XYZ-789", email: "ana.lopez@uniandes.edu.co", entryHoursAgo: 10, duration: 4.0, floor: 2, spot: 210, confidence: 0.99 },
    { plate: "KLM-555", email: "valentina.ruiz@uniandes.edu.co", entryHoursAgo: 3, duration: 0.75, floor: 1, spot: 108, confidence: 0.91 },
    // Unregistered vehicles
    { plate: "VIS-999", email: null, entryHoursAgo: 7, duration: 2.0, floor: 2, spot: 214, confidence: 0.83 },
    { plate: "RPK-777", email: null, entryHoursAgo: 9, duration: 1.5, floor: 3, spot: 308, confidence: 0.71 },
  ];

  for (const trip of completedTrips) {
    const entryTime = hoursAgo(trip.entryHoursAgo);
    const exitTime = hoursAgo(trip.entryHoursAgo - trip.duration);

    // Entry record
    records.push({
      plate: trip.plate,
      type: "entry",
      timestamp: entryTime,
      floor: trip.floor,
      spotNumber: trip.spot,
      photoURL: null,
      isRegistered: trip.email !== null,
      ownerEmail: trip.email,
      ocrConfidence: trip.confidence,
      durationHours: null,
      hitDailyCap: false,
    });

    // Exit record
    records.push({
      plate: trip.plate,
      type: "exit",
      timestamp: exitTime,
      floor: trip.floor,
      spotNumber: trip.spot,
      photoURL: null,
      isRegistered: trip.email !== null,
      ownerEmail: trip.email,
      ocrConfidence: trip.confidence,
      durationHours: trip.duration,
      hitDailyCap: false,
    });
  }

  // --- Currently parked (entry only, no exit) ---
  const currentlyParked = [
    { plate: "ABC-123", email: "ana.lopez@uniandes.edu.co", entryHoursAgo: 1.5, floor: 1, spot: 101, confidence: 0.97 },
    { plate: "SDQ-002", email: "maria.garcia@uniandes.edu.co", entryHoursAgo: 0.5, floor: 1, spot: 103, confidence: 0.88 },
    { plate: "GTC-456", email: "juan.perez@uniandes.edu.co", entryHoursAgo: 2.0, floor: 1, spot: 107, confidence: 0.94 },
    { plate: "BCG-321", email: "sebastian.torres@uniandes.edu.co", entryHoursAgo: 0.75, floor: 2, spot: 201, confidence: 0.96 },
    { plate: "ZZZ-404", email: null, entryHoursAgo: 1.0, floor: 2, spot: 205, confidence: 0.65 },   // low confidence → needsReview
    { plate: "MNO-876", email: null, entryHoursAgo: 3.0, floor: 3, spot: 302, confidence: 0.55 },   // low confidence → needsReview
  ];

  for (const p of currentlyParked) {
    records.push({
      plate: p.plate,
      type: "entry",
      timestamp: hoursAgo(p.entryHoursAgo),
      floor: p.floor,
      spotNumber: p.spot,
      photoURL: null,
      isRegistered: p.email !== null,
      ownerEmail: p.email,
      ocrConfidence: p.confidence,
      durationHours: null,
      hitDailyCap: false,
    });
  }

  // Write all records
  const batch = db.batch();
  for (const rec of records) {
    const ref = db.collection("vehicleRecords").doc();
    batch.set(ref, rec);
  }
  await batch.commit();
  console.log(`  ✓ ${records.length} vehicle records written`);
}

// ---------------------------------------------------------------------------
// MAIN
// ---------------------------------------------------------------------------

async function main() {
  console.log("\n=== SD Smart Parking — Firestore Seed ===\n");

  await seedConfig();
  await seedUsers();
  await seedParkingSpots();
  await seedVehicleRecords();

  console.log("\n=== Done! ===");
  console.log("\nTest accounts:");
  for (const u of USERS) {
    console.log(`  ${u.role === "manager" ? "🔑 Manager" : "🚗 Driver "} ${u.email}  /  ${u.password}`);
  }
  console.log("");

  process.exit(0);
}

main().catch((err) => {
  console.error("Seed failed:", err);
  process.exit(1);
});
