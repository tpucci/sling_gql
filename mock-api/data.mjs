// Deterministic in-memory dataset for the mock GraphQL API.
//
// Everything below is generated from a seeded PRNG (mulberry32) so that ids,
// names and stats are stable across server restarts. The only thing that is
// *not* stable is the split between past/future launches, which is derived
// from `Date.now()` at module-load time (by design: "upcoming" launches must
// always be in the future relative to "now").

const SEED = 0xc0ffee;

function mulberry32(seed) {
  let a = seed >>> 0;
  return function rng() {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const rng = mulberry32(SEED);

function randInt(min, max) {
  return Math.floor(rng() * (max - min + 1)) + min;
}

function randFloat(min, max, decimals = 1) {
  const v = rng() * (max - min) + min;
  const p = 10 ** decimals;
  return Math.round(v * p) / p;
}

function pick(arr) {
  return arr[Math.floor(rng() * arr.length)];
}

function pickN(arr, n) {
  const copy = [...arr];
  const out = [];
  for (let i = 0; i < n && copy.length > 0; i++) {
    const idx = Math.floor(rng() * copy.length);
    out.push(copy.splice(idx, 1)[0]);
  }
  return out;
}

function shuffle(arr) {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function randomDateBetween(start, end) {
  const t = start.getTime() + rng() * (end.getTime() - start.getTime());
  return new Date(t);
}

// ---------------------------------------------------------------------------
// Company
// ---------------------------------------------------------------------------

export const company = {
  id: "company-1",
  name: "Sling Space",
  founder: "Alex Corren",
  founded: 2007,
  employees: 14200,
  ceo: "Alex Corren",
  valuation: 148_500_000_000,
  summary:
    "Sling Space designs, manufactures and launches advanced rockets and " +
    "spacecraft, with the long term goal of enabling life on multiple " +
    "planets.",
  headquarters: {
    street: "1 Boca Chica Blvd",
    city: "Starbase",
    state: "TX",
    country: "USA",
  },
};

// ---------------------------------------------------------------------------
// Rockets — one per RocketFamily value
// ---------------------------------------------------------------------------

export const rockets = [
  {
    id: "rocket-falcon",
    name: "Falcon 9",
    family: "FALCON",
    description:
      "A reusable two-stage rocket designed and manufactured for the " +
      "reliable and safe transport of satellites and crew into orbit.",
    active: true,
    stages: 2,
    costPerLaunch: 62_000_000,
    successRatePct: 99,
    firstFlight: new Date("2010-06-04T18:45:00.000Z"),
    height: { meters: 70.0, feet: 229.6 },
    diameter: { meters: 3.7, feet: 12.1 },
    mass: { kg: 549_054, lb: 1_207_920 },
    engines: {
      count: 9,
      type: "Merlin",
      propellant: "LOX/RP-1",
      thrustSeaLevelKN: 7607.0,
      thrustVacuumKN: 8227.0,
    },
    wikipedia: "https://en.wikipedia.org/wiki/Falcon_9",
  },
  {
    id: "rocket-starship",
    name: "Starship",
    family: "STARSHIP",
    description:
      "A fully reusable super heavy-lift launch vehicle, the largest and " +
      "most powerful rocket ever flown, intended for missions to orbit, " +
      "the Moon and Mars.",
    active: true,
    stages: 2,
    costPerLaunch: 10_000_000,
    successRatePct: 62,
    firstFlight: new Date("2023-04-20T13:33:00.000Z"),
    height: { meters: 120.0, feet: 393.7 },
    diameter: { meters: 9.0, feet: 29.5 },
    mass: { kg: 5_000_000, lb: 11_023_000 },
    engines: {
      count: 33,
      type: "Raptor",
      propellant: "CH4/LOX",
      thrustSeaLevelKN: 74_000.0,
      thrustVacuumKN: 79_800.0,
    },
    wikipedia: "https://en.wikipedia.org/wiki/SpaceX_Starship",
  },
  {
    id: "rocket-atlas",
    name: "Atlas V",
    family: "ATLAS",
    description:
      "A consolidated expendable launch system with a strong record of " +
      "reliability for national security, science and commercial payloads.",
    active: true,
    stages: 2,
    costPerLaunch: 109_000_000,
    successRatePct: 100,
    firstFlight: new Date("2002-08-21T05:05:00.000Z"),
    height: { meters: 58.3, feet: 191.3 },
    diameter: { meters: 3.8, feet: 12.5 },
    mass: { kg: 334_500, lb: 737_500 },
    engines: {
      count: 1,
      type: "RD-180",
      propellant: "LOX/RP-1",
      thrustSeaLevelKN: 3827.0,
      thrustVacuumKN: 4152.0,
    },
    wikipedia: "https://en.wikipedia.org/wiki/Atlas_V",
  },
  {
    id: "rocket-ariane",
    name: "Ariane 6",
    family: "ARIANE",
    description:
      "Europe's next-generation modular heavy-lift launcher, succeeding " +
      "Ariane 5 for institutional and commercial missions.",
    active: false,
    stages: 2,
    costPerLaunch: 85_000_000,
    successRatePct: 92,
    firstFlight: new Date("2024-07-09T14:00:00.000Z"),
    height: { meters: 63.0, feet: 206.7 },
    diameter: { meters: 5.4, feet: 17.7 },
    mass: { kg: 860_000, lb: 1_895_800 },
    engines: {
      count: 1,
      type: "Vulcain 2.1",
      propellant: "LOX/LH2",
      thrustSeaLevelKN: 1390.0,
      thrustVacuumKN: 1670.0,
    },
    wikipedia: "https://en.wikipedia.org/wiki/Ariane_6",
  },
  {
    id: "rocket-vulcan",
    name: "Vulcan Centaur",
    family: "VULCAN",
    description:
      "A next-generation heavy-lift launcher combining new BE-4 engines " +
      "with a Centaur upper stage for national security and deep space " +
      "missions.",
    active: true,
    stages: 2,
    costPerLaunch: 110_000_000,
    successRatePct: 100,
    firstFlight: new Date("2024-01-08T07:18:00.000Z"),
    height: { meters: 61.6, feet: 202.1 },
    diameter: { meters: 5.4, feet: 17.7 },
    mass: { kg: 546_700, lb: 1_205_300 },
    engines: {
      count: 2,
      type: "BE-4",
      propellant: "CH4/LOX",
      thrustSeaLevelKN: 4900.0,
      thrustVacuumKN: 5320.0,
    },
    wikipedia: "https://en.wikipedia.org/wiki/Vulcan_Centaur",
  },
];

const rocketIds = rockets.map((r) => r.id);

// Weighted rocket picker: Falcon 9 flies the vast majority of missions.
function pickRocketIdFor(name) {
  if (/starship/i.test(name)) return "rocket-starship";
  const r = rng();
  if (r < 0.72) return "rocket-falcon";
  if (r < 0.8) return "rocket-starship";
  if (r < 0.87) return "rocket-atlas";
  if (r < 0.94) return "rocket-vulcan";
  return "rocket-ariane";
}

// ---------------------------------------------------------------------------
// Launchpads
// ---------------------------------------------------------------------------

export const launchpads = [
  {
    id: "pad-1",
    name: "SLC-40",
    fullName: "Space Launch Complex 40",
    locality: "Cape Canaveral",
    region: "Florida",
    latitude: 28.5623,
    longitude: -80.5774,
    status: "ACTIVE",
    launchAttempts: 210,
    launchSuccesses: 207,
  },
  {
    id: "pad-2",
    name: "LC-39A",
    fullName: "Launch Complex 39A",
    locality: "Kennedy Space Center",
    region: "Florida",
    latitude: 28.6084,
    longitude: -80.6043,
    status: "ACTIVE",
    launchAttempts: 175,
    launchSuccesses: 174,
  },
  {
    id: "pad-3",
    name: "SLC-4E",
    fullName: "Space Launch Complex 4 East",
    locality: "Vandenberg",
    region: "California",
    latitude: 34.6321,
    longitude: -120.6108,
    status: "ACTIVE",
    launchAttempts: 98,
    launchSuccesses: 96,
  },
  {
    id: "pad-4",
    name: "Starbase Orbital Pad A",
    fullName: "Starbase Orbital Launch Pad A",
    locality: "Boca Chica",
    region: "Texas",
    latitude: 25.9972,
    longitude: -97.1566,
    status: "ACTIVE",
    launchAttempts: 12,
    launchSuccesses: 7,
  },
];

const launchpadIds = launchpads.map((p) => p.id);

// ---------------------------------------------------------------------------
// Astronauts
// ---------------------------------------------------------------------------

const astronautNames = [
  ["Maya", "Sorensen"], ["Liam", "Okafor"], ["Elena", "Ivanova"],
  ["Hiro", "Tanaka"], ["Priya", "Nair"], ["Marcus", "Webb"],
  ["Chloe", "Dubois"], ["Ahmed", "Farouk"], ["Sofia", "Almeida"],
  ["Noah", "Bergström"], ["Aiko", "Yamamoto"], ["Daniel", "Cohen"],
  ["Grace", "Muthoni"], ["Lucas", "Ferreira"], ["Ingrid", "Solberg"],
  ["Wei", "Zhang"], ["Fatima", "Haidari"], ["Owen", "Mitchell"],
  ["Isabel", "Reyes"], ["Kenji", "Sato"], ["Anna", "Kowalski"],
  ["Diego", "Marquez"], ["Nadia", "Petrov"], ["Sam", "Whitfield"],
];

const nationalities = [
  "United States", "Canada", "Japan", "Germany", "France", "Italy",
  "United Kingdom", "Brazil", "India", "Nigeria", "Norway", "Poland",
  "Egypt", "Mexico", "Ukraine", "South Korea",
];

const agencies = ["NASA", "ESA", "JAXA", "CSA", "Sling Space"];

const bioTemplates = [
  "A former {job} who joined the astronaut corps after logging thousands " +
    "of hours in high-performance aircraft.",
  "Holds a doctorate in {field} and has spent over a decade researching " +
    "the effects of microgravity on the human body.",
  "Selected from a pool of thousands of applicants, {first} specializes " +
    "in robotics and spacecraft systems.",
  "Before joining the program, {first} served as a {job} and later became " +
    "a test pilot for experimental aircraft.",
  "{first} is an advocate for STEM education and has flown multiple " +
    "long-duration missions to low Earth orbit.",
];

const jobs = [
  "fighter pilot", "mechanical engineer", "physician", "geologist",
  "naval officer", "research scientist",
];
const fields = [
  "astrophysics", "aerospace engineering", "biochemistry",
  "planetary science", "materials science",
];

export const astronauts = astronautNames.map(([first, last], i) => {
  const bioTpl = pick(bioTemplates);
  return {
    id: `astro-${i + 1}`,
    name: `${first} ${last}`,
    nationality: pick(nationalities),
    agency: pick(agencies),
    bio: bioTpl
      .replaceAll("{first}", first)
      .replaceAll("{job}", pick(jobs))
      .replaceAll("{field}", pick(fields)),
    // `flights` is filled in after launches (and their crews) are built.
    flights: 0,
  };
});

const astronautIds = astronauts.map((a) => a.id);

// ---------------------------------------------------------------------------
// Launches
// ---------------------------------------------------------------------------

const missionTemplates = [];

// Starlink batches — the bulk of the manifest.
for (let i = 0; i < 107; i++) {
  const batch = Math.floor(i / 6) + 1;
  const sub = (i % 6) + 1;
  missionTemplates.push({ name: `Starlink Group ${batch}-${sub}`, kind: "starlink" });
}

// Cargo resupply missions.
for (let n = 18; n < 32; n++) {
  missionTemplates.push({ name: `CRS-${n}`, kind: "cargo" });
}

// Commercial crew rotations.
for (let n = 1; n <= 9; n++) {
  missionTemplates.push({ name: `Crew-${n}`, kind: "crew" });
}

// Rideshare missions.
for (let n = 1; n <= 14; n++) {
  missionTemplates.push({ name: `Transporter-${n}`, kind: "rideshare" });
}

// Private crewed missions.
missionTemplates.push({ name: "Polaris Dawn", kind: "crew" });
missionTemplates.push({ name: "Polaris Orbital", kind: "crew" });
missionTemplates.push({ name: "Inspiration4", kind: "crew" });

// Named science / commercial / national-security missions.
const namedMissions = [
  "Europa Clipper", "DART", "Psyche", "TESS", "Lucy", "IXPE",
  "Sentinel-6B", "PACE", "Peregrine Mission One", "ispace Mission 1",
  "Nova-C IM-1", "Nova-C IM-2", "GPS III SV05", "GPS III SV06",
  "GPS III SV07", "Galileo FOC FM25", "Galileo FOC FM26", "O3b mPOWER 1",
  "O3b mPOWER 2", "SES-22", "Intelsat 40e", "JCSAT-18", "Turksat 5B",
  "Amazonas Nexus", "Eutelsat HOTBIRD 13G", "USSF-52", "NROL-85",
  "NROL-87", "X-37B OTV-6", "Double Asteroid Redirection Test 2",
  "Axiom Mission 1", "Axiom Mission 2", "Axiom Mission 3", "Axiom Mission 4",
];
for (const name of namedMissions) {
  missionTemplates.push({ name, kind: "named" });
}

const shuffledTemplates = shuffle(missionTemplates);

const now = new Date();
const RANGE_START = new Date("2010-01-01T00:00:00.000Z");
const RANGE_END = new Date("2026-12-31T00:00:00.000Z");
const FUTURE_END = new Date(
  Math.max(now.getTime() + 1000, RANGE_END.getTime())
);

const FUTURE_COUNT = 15;
const futureIdxSet = new Set(pickN(
  shuffledTemplates.map((_, i) => i),
  Math.min(FUTURE_COUNT, shuffledTemplates.length)
));

const payloadTypes = ["Satellite", "Crew Dragon", "Cargo Dragon", "Rideshare", "Probe"];
const orbits = ["LEO", "GTO", "SSO", "ISS", "Heliocentric", "TLI"];
const customerPool = [
  "Sling Space", "NASA", "ESA", "U.S. Space Force", "Iridium", "SES",
  "Intelsat", "Planet Labs", "Various Rideshare Customers", "NOAA", "JAXA",
];

const detailTemplates = [
  "This mission delivered its payload to the target orbit and completed " +
    "a successful landing of the first stage.",
  "Part of an ongoing campaign to expand the constellation's coverage " +
    "over polar and mid-latitude regions.",
  "A rideshare mission carrying dozens of small satellites from " +
    "commercial and government customers.",
  "This flight marked a milestone reuse of a previously flown booster.",
  "Weather conditions at the launch site required a short scrub before a " +
    "successful liftoff on the backup date.",
];

function buildDetails() {
  return rng() < 0.7 ? pick(detailTemplates) : null;
}

function buildLinks(id) {
  return {
    article: rng() < 0.6 ? `https://example.com/articles/${id}` : null,
    video: rng() < 0.4 ? `https://example.com/videos/${id}` : null,
    wikipedia: rng() < 0.5 ? `https://en.wikipedia.org/wiki/${id}` : null,
    patch: `https://picsum.photos/seed/${id}/200`,
    flickrImages: Array.from({ length: randInt(0, 3) }, (_, i) =>
      `https://example.com/flickr/${id}/${i + 1}.jpg`
    ),
  };
}

function buildPayloads(id, kind) {
  const count = kind === "cargo" || kind === "crew" ? randInt(1, 2) : randInt(0, 4);
  return Array.from({ length: count }, (_, i) => {
    let type = pick(payloadTypes);
    if (kind === "crew") type = "Crew Dragon";
    else if (kind === "cargo") type = "Cargo Dragon";
    else if (kind === "starlink") type = "Satellite";
    return {
      id: `${id}-payload-${i + 1}`,
      name: `${type} Payload ${i + 1}`,
      type,
      massKg: rng() < 0.15 ? null : randFloat(60, 16000, 1),
      orbit: kind === "crew" || kind === "cargo" ? "ISS" : pick(orbits),
      customers: pickN(customerPool, randInt(1, 3)),
    };
  });
}

function isCrewedName(name) {
  return /Crew|Polaris|Inspiration/.test(name);
}

const rawLaunches = shuffledTemplates.map((tpl, i) => {
  const isFuture = futureIdxSet.has(i);
  const date = isFuture
    ? randomDateBetween(now, FUTURE_END)
    : randomDateBetween(RANGE_START, now);
  return { ...tpl, date, isFuture };
});

// Sort by date ascending so flight numbers are sequential in date order.
rawLaunches.sort((a, b) => a.date.getTime() - b.date.getTime());

export const launches = rawLaunches.map((raw, i) => {
  const id = `launch-${i + 1}`;
  const flightNumber = i + 1;
  let status;
  const upcoming = raw.isFuture;
  if (raw.isFuture) {
    status = rng() < 0.85 ? "SCHEDULED" : "SCRUBBED";
  } else {
    const r = rng();
    status = r < 0.88 ? "SUCCESS" : r < 0.95 ? "PARTIAL_FAILURE" : "FAILURE";
  }

  const crewed = isCrewedName(raw.name);
  const crewIds = crewed ? pickN(astronautIds, randInt(2, 4)) : [];

  return {
    id,
    flightNumber,
    name: raw.name,
    details: buildDetails(),
    date: raw.date,
    status,
    upcoming,
    rocketId: pickRocketIdFor(raw.name),
    launchpadId: pick(launchpadIds),
    payloads: buildPayloads(id, raw.kind),
    crewIds,
    links: buildLinks(id),
    favorite: false,
  };
});

// Back-fill astronaut `flights` counts now that crews are known.
for (const astronaut of astronauts) {
  astronaut.flights = launches.filter((l) => l.crewIds.includes(astronaut.id)).length;
}

// ---------------------------------------------------------------------------
// Mutation helpers
// ---------------------------------------------------------------------------

let nextFlightNumber = launches.length + 1;

export function findRocket(id) {
  return rockets.find((r) => r.id === id) ?? null;
}

export function findLaunchpad(id) {
  return launchpads.find((p) => p.id === id) ?? null;
}

export function findLaunch(id) {
  return launches.find((l) => l.id === id) ?? null;
}

export function findAstronaut(id) {
  return astronauts.find((a) => a.id === id) ?? null;
}

export function toggleFavorite(launchId) {
  const launch = findLaunch(launchId);
  if (!launch) return null;
  launch.favorite = !launch.favorite;
  return launch;
}

export function scheduleLaunch(input) {
  const id = `launch-${launches.length + 1}-${Date.now()}`;
  const payloadNames = input.payloadNames ?? [];
  const launch = {
    id,
    flightNumber: nextFlightNumber++,
    name: input.name,
    details: input.details ?? null,
    date: input.date,
    status: "SCHEDULED",
    upcoming: true,
    rocketId: input.rocketId,
    launchpadId: input.launchpadId,
    payloads: payloadNames.map((name, i) => ({
      id: `${id}-payload-${i + 1}`,
      name,
      type: "Satellite",
      massKg: null,
      orbit: "LEO",
      customers: ["Sling Space"],
    })),
    crewIds: [],
    links: buildLinks(id),
    favorite: false,
  };
  launches.push(launch);
  return launch;
}

export function updateLaunchStatus(id, status) {
  const launch = findLaunch(id);
  if (!launch) return null;
  launch.status = status;
  launch.upcoming =
    (status === "SCHEDULED" || status === "SCRUBBED") &&
    launch.date.getTime() > Date.now();
  return launch;
}
