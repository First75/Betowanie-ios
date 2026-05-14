const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const {onRequest} = require("firebase-functions/v2/https");
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

exports.syncMatches = onRequest(
    {
      region: "europe-west1",
      timeoutSeconds: 120,
      memory: "256MiB",
      cors: true,
      secrets: [FOOTBALL_DATA_API_TOKEN],
    },
    async (req, res) => {
      if (req.method !== "GET") {
        res.status(405).json({
          error: "Method not allowed. Use GET.",
        });
        return;
      }

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
        res.status(response.status).json({
          error: "football-data request failed",
          status: response.status,
          body: errorBody,
        });
        return;
      }

      const payload = await response.json();
      const matches = Array.isArray(payload.matches) ?
        payload.matches.map(mapMatch) :
        [];
      const result = {
        matches,
        matchesLastSyncedAt: Date.now(),
      };

      await admin.database().ref().update(result);

      logger.info("matches synced", {
        count: matches.length,
      });

      res.status(200).json(result);
    },
);

exports.sendTestNotificationToAllUsers = onRequest(
    {
      region: "europe-west1",
      cors: true,
      timeoutSeconds: 120,
      memory: "256MiB",
    },
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).json({
          error: "Method not allowed. Use POST.",
        });
        return;
      }

      const usersSnapshot = await admin.firestore().collection("users").get();
      const tokens = [];

      usersSnapshot.forEach((doc) => {
        const fcmToken = doc.get("fcmToken");
        if (typeof fcmToken === "string" && fcmToken.trim().length > 0) {
          tokens.push(fcmToken.trim());
        }
      });

      if (tokens.length === 0) {
        res.status(200).json({
          success: true,
          message: "No users with fcmToken found.",
          totalUsers: usersSnapshot.size,
          totalTokens: 0,
        });
        return;
      }

      const uniqueTokens = [...new Set(tokens)];
      const message = {
        notification: {
          title: "Test notification",
          body: "This is a test push notification from Firebase Functions.",
        },
        data: {
          type: "test",
          sentAt: new Date().toISOString(),
        },
        tokens: uniqueTokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);

      const invalidTokens = [];
      response.responses.forEach((result, index) => {
        if (!result.success) {
          const errorCode = result.error?.code ?? "unknown";
          logger.error("Failed to send notification", {
            token: uniqueTokens[index],
            errorCode,
            errorMessage: result.error?.message ?? null,
          });

          if (
            errorCode === "messaging/invalid-registration-token" ||
            errorCode === "messaging/registration-token-not-registered"
          ) {
            invalidTokens.push(uniqueTokens[index]);
          }
        }
      });

      res.status(200).json({
        success: true,
        message: "Test notification request completed.",
        totalUsers: usersSnapshot.size,
        totalTokens: uniqueTokens.length,
        successCount: response.successCount,
        failureCount: response.failureCount,
        invalidTokens,
      });
    },
);
