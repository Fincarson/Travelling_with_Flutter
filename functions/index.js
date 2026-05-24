const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const geoapifyApiKey = defineSecret("GEOAPIFY_API_KEY");

exports.searchPlaces = onCall(
  {
    region: "us-central1",
    secrets: [geoapifyApiKey],
  },
  async (request) => {
    const query = String(request.data?.query ?? "").trim();
    if (query.length < 3) {
      return {results: []};
    }

    const url = new URL("https://api.geoapify.com/v1/geocode/autocomplete");
    url.searchParams.set("text", query);
    url.searchParams.set("format", "json");
    url.searchParams.set("type", "city");
    url.searchParams.set("limit", "6");
    url.searchParams.set("apiKey", geoapifyApiKey.value());

    const response = await fetch(url);
    if (!response.ok) {
      logger.error("Geoapify search failed", {
        status: response.status,
        query,
      });
      throw new HttpsError("unavailable", "Place search is unavailable.");
    }

    const body = await response.json();
    const results = Array.isArray(body.results) ? body.results : [];

    return {
      results: results.map((item) => {
        const city = item.city ?? item.county ?? item.state ?? item.name;
        const country = item.country;
        const formatted = item.formatted ?? city ?? "Unknown place";
        const name = city
          ? country
            ? `${city}, ${country}`
            : city
          : formatted;

        return {
          name,
          formatted,
          latitude: item.lat ?? 0,
          longitude: item.lon ?? 0,
          placeId: item.place_id ?? formatted,
          country: country ?? null,
        };
      }),
    };
  },
);
