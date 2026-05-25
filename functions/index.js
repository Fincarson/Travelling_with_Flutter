const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const geoapifyApiKey = defineSecret("GEOAPIFY_API_KEY");
const openAiApiKey = defineSecret("OPENAI_API_KEY");

const travelAssistantInstructions = [
  "You are a concise travel planning assistant inside a mobile app.",
  "Help with itinerary order, budget tradeoffs, packing, food, transit,",
  "and practical destination advice. Keep replies friendly and short.",
].join(" ");

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

exports.chatWithAssistant = onCall(
  {
    region: "us-central1",
    secrets: [openAiApiKey],
  },
  async (request) => {
    const message = String(request.data?.message ?? "").trim();
    if (!message) {
      throw new HttpsError("invalid-argument", "Message is required.");
    }
    if (message.length > 1200) {
      throw new HttpsError("invalid-argument", "Message is too long.");
    }

    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openAiApiKey.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-5.5",
        instructions: travelAssistantInstructions,
        input: message,
        store: false,
        reasoning: {effort: "low"},
        text: {verbosity: "low"},
      }),
    });

    if (!response.ok) {
      logger.error("OpenAI chat failed", {
        status: response.status,
        messageLength: message.length,
      });
      throw new HttpsError("unavailable", "AI chat is unavailable.");
    }

    const body = await response.json();
    const reply = outputText(body).trim();
    if (!reply) {
      throw new HttpsError("unavailable", "AI chat returned an empty reply.");
    }

    return {reply};
  },
);

function outputText(responseBody) {
  if (typeof responseBody.output_text === "string") {
    return responseBody.output_text;
  }

  const output = Array.isArray(responseBody.output) ? responseBody.output : [];
  return output
    .flatMap((item) => Array.isArray(item.content) ? item.content : [])
    .map((content) => content.text)
    .filter((text) => typeof text === "string")
    .join("\n");
}
