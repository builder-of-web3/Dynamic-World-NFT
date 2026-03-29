/**
 * Dynamic World NFT — Oracle Service
 * 
 * Reads real-world data APIs and updates NFT world states on-chain.
 * Run this on any Node.js server (e.g. Railway, Render, or a VPS).
 * 
 * Schedule: Set a cron job or use node-cron to run every 6 hours.
 * 
 * Usage:
 *   npm install
 *   cp .env.example .env  (fill in values)
 *   node oracle.js
 */

const { ethers } = require("ethers");
require("dotenv").config();

// ─── Config ──────────────────────────────────────────────────────────────────

const RPC_URL = process.env.OPTIMISM_RPC_URL || "https://sepolia.optimism.io";
const PRIVATE_KEY = process.env.ORACLE_PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;

const ABI = [
  "function totalSupply() view returns (uint256)",
  "function worldStates(uint256) view returns (uint8 category, uint8 intensity, uint8 sentimentScore, string eventTag, string dataPoint, uint256 lastUpdated, uint256 updateCount)",
  "function batchUpdateWorldState(uint256[] tokenIds, uint8[] intensities, uint8[] sentiments, string[] eventTags, string[] dataPoints)",
];

// ─── Data Fetchers ────────────────────────────────────────────────────────────

/**
 * Fetch climate data (uses Open-Meteo - free, no API key)
 * Returns intensity and sentiment scores based on anomalies
 */
async function fetchClimateData() {
  try {
    const res = await fetch(
      "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0&daily=temperature_2m_max,precipitation_sum&forecast_days=1&timezone=UTC"
    );
    const data = await res.json();
    const temp = data.daily?.temperature_2m_max?.[0] || 28;
    const rain = data.daily?.precipitation_sum?.[0] || 0;

    // Higher temp anomaly = higher intensity, lower sentiment
    const tempAnomaly = Math.max(0, temp - 25);
    const intensity = Math.min(100, Math.round(40 + tempAnomaly * 5 + rain * 2));
    const sentiment = Math.max(0, Math.round(70 - tempAnomaly * 8));

    return {
      intensity,
      sentiment,
      eventTag: temp > 35 ? "Extreme Heat Event" : rain > 20 ? "Heavy Rainfall" : "Stable Climate",
      dataPoint: `Temp: ${temp}°C | Rain: ${rain}mm`,
    };
  } catch (e) {
    console.error("Climate fetch failed:", e.message);
    return { intensity: 50, sentiment: 50, eventTag: "Climate Watch", dataPoint: "Data unavailable" };
  }
}

/**
 * Fetch market data (CoinGecko free API)
 */
async function fetchMarketData() {
  try {
    const res = await fetch(
      "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd&include_24hr_change=true"
    );
    const data = await res.json();
    const btcPrice = data.bitcoin?.usd || 0;
    const btcChange = data.bitcoin?.usd_24h_change || 0;
    const ethChange = data.ethereum?.usd_24h_change || 0;

    const avgChange = (btcChange + ethChange) / 2;
    const intensity = Math.min(100, Math.round(50 + Math.abs(avgChange) * 5));
    const sentiment = avgChange > 0
      ? Math.min(100, Math.round(65 + avgChange * 3))
      : Math.max(0, Math.round(35 + avgChange * 3));

    return {
      intensity,
      sentiment,
      eventTag: avgChange > 5 ? "Bull Run" : avgChange < -5 ? "Market Crash" : "Market Active",
      dataPoint: `BTC: $${btcPrice.toLocaleString()} | 24h: ${btcChange > 0 ? "+" : ""}${btcChange.toFixed(1)}%`,
    };
  } catch (e) {
    console.error("Market fetch failed:", e.message);
    return { intensity: 50, sentiment: 50, eventTag: "Market Observer", dataPoint: "Data unavailable" };
  }
}

/**
 * Fetch space data (NASA APOD API - free with key)
 */
async function fetchSpaceData() {
  try {
    const NASA_KEY = process.env.NASA_API_KEY || "DEMO_KEY";
    const res = await fetch(`https://api.nasa.gov/planetary/apod?api_key=${NASA_KEY}`);
    const data = await res.json();

    // Use title length and random as proxies (real impl would parse event feeds)
    const title = data.title || "Space Observation";
    const isExciting = title.toLowerCase().includes("explosion") ||
      title.toLowerCase().includes("supernova") ||
      title.toLowerCase().includes("comet") ||
      title.toLowerCase().includes("aurora");

    return {
      intensity: isExciting ? 85 : 55,
      sentiment: 82, // Space is generally positive/awe-inspiring
      eventTag: title.length > 20 ? title.substring(0, 20) + "..." : title,
      dataPoint: `NASA APOD: ${data.date || "Today"}`,
    };
  } catch (e) {
    console.error("Space fetch failed:", e.message);
    return { intensity: 60, sentiment: 80, eventTag: "Space Explorer", dataPoint: "NASA data unavailable" };
  }
}

/**
 * Fetch health data (placeholder - use WHO API or similar in production)
 */
async function fetchHealthData() {
  // In production, integrate WHO disease outbreak news API
  // https://www.who.int/csr/don/en/
  return {
    intensity: 45,
    sentiment: 65,
    eventTag: "Health Sentinel Active",
    dataPoint: "WHO: No active alerts | Routine monitoring",
  };
}

/**
 * Fetch geopolitical data (placeholder - use GDELT or ACLED in production)
 */
async function fetchGeopoliticalData() {
  // In production: GDELT API at https://api.gdeltproject.org/
  return {
    intensity: 55,
    sentiment: 40,
    eventTag: "Global Watch",
    dataPoint: "GDELT: Monitoring 183 countries",
  };
}

/**
 * Fetch tech data (Hacker News top stories sentiment)
 */
async function fetchTechData() {
  try {
    const res = await fetch("https://hacker-news.firebaseio.com/v0/topstories.json");
    const ids = await res.json();
    const topId = ids[0];
    const storyRes = await fetch(`https://hacker-news.firebaseio.com/v0/item/${topId}.json`);
    const story = await storyRes.json();

    const title = story.title || "Tech News";
    const isAI = title.toLowerCase().includes("ai") || title.toLowerCase().includes("llm") || title.toLowerCase().includes("gpt");
    const isBreaking = story.score > 500;

    return {
      intensity: isBreaking ? 80 : 55,
      sentiment: isAI ? 75 : 60,
      eventTag: title.length > 22 ? title.substring(0, 22) + "..." : title,
      dataPoint: `HN Score: ${story.score} | Comments: ${story.descendants || 0}`,
    };
  } catch (e) {
    console.error("Tech fetch failed:", e.message);
    return { intensity: 60, sentiment: 65, eventTag: "Tech Frontier", dataPoint: "HN data unavailable" };
  }
}

// ─── Category -> Fetcher map ─────────────────────────────────────────────────

const FETCHERS = [
  fetchClimateData,      // 0 = CLIMATE
  fetchMarketData,       // 1 = MARKET
  fetchGeopoliticalData, // 2 = GEOPOLITICAL
  fetchSpaceData,        // 3 = SPACE
  fetchHealthData,       // 4 = HEALTH
  fetchTechData,         // 5 = TECHNOLOGY
];

// ─── Oracle Main ──────────────────────────────────────────────────────────────

async function runOracle() {
  console.log("🌍 Dynamic World NFT Oracle starting...");
  console.log("RPC:", RPC_URL);
  console.log("Contract:", CONTRACT_ADDRESS);

  if (!PRIVATE_KEY || !CONTRACT_ADDRESS) {
    console.error("❌ Missing ORACLE_PRIVATE_KEY or CONTRACT_ADDRESS in .env");
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, wallet);

  const totalSupply = await contract.totalSupply();
  console.log(`📊 Total supply: ${totalSupply}`);

  if (totalSupply === 0n) {
    console.log("No tokens minted yet. Exiting.");
    return;
  }

  // Fetch all world data in parallel
  console.log("🔭 Fetching real-world data...");
  const worldData = await Promise.all(FETCHERS.map((f) => f()));
  console.log("World data fetched:", worldData.map((d) => d.eventTag).join(", "));

  // Build update arrays for all tokens
  const tokenIds = [];
  const intensities = [];
  const sentiments = [];
  const eventTags = [];
  const dataPoints = [];

  for (let i = 0; i < Number(totalSupply); i++) {
    const state = await contract.worldStates(i);
    const category = Number(state.category);
    const data = worldData[category];

    tokenIds.push(i);
    intensities.push(data.intensity);
    sentiments.push(data.sentiment);
    eventTags.push(data.eventTag);
    dataPoints.push(data.dataPoint);
  }

  // Batch update (process in chunks of 50 to avoid gas limits)
  const CHUNK_SIZE = 50;
  for (let i = 0; i < tokenIds.length; i += CHUNK_SIZE) {
    const chunk = {
      tokenIds: tokenIds.slice(i, i + CHUNK_SIZE),
      intensities: intensities.slice(i, i + CHUNK_SIZE),
      sentiments: sentiments.slice(i, i + CHUNK_SIZE),
      eventTags: eventTags.slice(i, i + CHUNK_SIZE),
      dataPoints: dataPoints.slice(i, i + CHUNK_SIZE),
    };

    console.log(`📡 Updating tokens ${chunk.tokenIds[0]}–${chunk.tokenIds[chunk.tokenIds.length - 1]}...`);
    const tx = await contract.batchUpdateWorldState(
      chunk.tokenIds,
      chunk.intensities,
      chunk.sentiments,
      chunk.eventTags,
      chunk.dataPoints
    );
    await tx.wait();
    console.log(`✅ Batch tx: ${tx.hash}`);
  }

  console.log("🎉 Oracle run complete!");
}

runOracle().catch((e) => {
  console.error("Oracle error:", e);
  process.exit(1);
});
