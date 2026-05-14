const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {defineSecret} = require("firebase-functions/params");

const FOOTBALL_DATA_API_TOKEN = defineSecret("FOOTBALL_DATA_API_TOKEN");
const FOOTBALL_DATA_URL = "https://api.football-data.org/v4/matches";
const DATABASE_URL =
  "https://betowanie-ee389.europe-west1.firebasedatabase.app/";

admin.initializeApp({
  databaseURL: DATABASE_URL,
});

function mapMatch(match) {
  const fullTime = match.score?.fullTime ?? {};
  const regularTime = match.score?.regularTime ?? {};

  return {
    awayTeamIcon: match.awayTeam?.crest ?? null,
    awayTeamName: match.awayTeam?.name ?? null,
    fullTimeScore: {
      away: fullTime.away ?? null,
      home: fullTime.home ?? null,
      winner: match.score?.winner ?? null,
    },
    homeTeamIcon: match.homeTeam?.crest ?? null,
    homeTeamName: match.homeTeam?.name ?? null,
    id: match.id,
    regularTimeScore: {
      away: regularTime.away ?? null,
      home: regularTime.home ?? null,
      winner: match.score?.winner ?? null,
    },
    stage: match.stage ?? null,
    status: match.status ?? null,
    timestamp: match.utcDate ? new Date(match.utcDate).getTime() : null,
    winner: match.score?.winner ?? null,
  };
}

exports.syncMatches = onSchedule(
    {
      schedule: "every 12 hours",
      timeZone: "Europe/Warsaw",
      region: "europe-west1",
      timeoutSeconds: 120,
      memory: "256MiB",
      secrets: [FOOTBALL_DATA_API_TOKEN],
    },
    async () => {
      const apiToken = FOOTBALL_DATA_API_TOKEN.value();

      const response = await fetch(FOOTBALL_DATA_URL, {
        headers: {
          "X-Auth-Token": apiToken,
        },
      });

      if (!response.ok) {
        const errorBody = await response.text();
        logger.error("football-data request failed", {
          status: response.status,
          body: errorBody,
        });
        throw new Error(`football-data request failed: ${response.status}`);
      }

      const payload = await response.json();
      const matches = Array.isArray(payload.matches) ?
        payload.matches.map(mapMatch) :
        [];

      await admin.database().ref().update({
        matches,
        matchesLastSyncedAt: Date.now(),
      });

      logger.info("matches synced", {
        count: matches.length,
      });
    },
);
