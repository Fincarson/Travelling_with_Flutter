const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const geoapifyApiKey = defineSecret("GEOAPIFY_API_KEY");
const openAiApiKey = defineSecret("OPENAI_API_KEY");
const openAiModel = "gpt-5.5";

const travelAssistantInstructions = [
  "You are a concise travel planning assistant inside a mobile app.",
  "Help with itinerary order, budget tradeoffs, packing, food, transit,",
  "and practical destination advice. Keep replies friendly and short.",
].join(" ");

const tripPlanInstructions = [
  "Generate a practical travel itinerary for a mobile travel app.",
  "Use realistic attraction names, reasonable pacing, and approximate costs.",
  "Keep activities suitable for the destination, dates, budget, group, and tags.",
].join(" ");

const createTripInstructions = [
  "You are the Create Trip assistant inside a mobile travel app.",
  "Interpret the user message and update the trip draft.",
  "Ask for exactly one missing important field at a time.",
  "When useful, create a tappable widget with 2 to 4 options.",
  "Widget option values must be short user messages the app can send back.",
  "Required final fields: destination, startDate, endDate, budget, groupType.",
  "Dates must be ISO yyyy-MM-dd. groupType must be Solo, Friends, Family, or Tour.",
  "If the user names a currency, set currency to USD, TWD, IDR, JPY, or EUR.",
].join(" ");

const tripPlanFormat = {
  type: "json_schema",
  name: "generated_trip_plan",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    properties: {
      items: {
        type: "array",
        minItems: 3,
        maxItems: 12,
        items: {
          type: "object",
          additionalProperties: false,
          properties: {
            day: {type: "integer"},
            time: {type: "string"},
            activity: {type: "string"},
            type: {
              type: "string",
              enum: [
                "place",
                "food",
                "restaurant",
                "walk",
                "museum",
                "beach",
                "shopping",
                "train",
                "flight",
                "hotel",
                "cafe",
                "hiking",
                "temple",
              ],
            },
            cost: {type: "integer"},
          },
          required: ["day", "time", "activity", "type", "cost"],
        },
      },
      bookings: {
        type: "array",
        maxItems: 4,
        items: {
          type: "object",
          additionalProperties: false,
          properties: {
            title: {type: "string"},
            date: {type: "string"},
            time: {type: "string"},
            reference: {type: "string"},
            cost: {type: "integer"},
            type: {
              type: "string",
              enum: ["hotel", "flight", "train", "place"],
            },
          },
          required: ["title", "date", "time", "reference", "cost", "type"],
        },
      },
      checklist: {
        type: "array",
        maxItems: 5,
        items: {
          type: "object",
          additionalProperties: false,
          properties: {
            category: {type: "string"},
            items: {
              type: "array",
              minItems: 1,
              maxItems: 8,
              items: {type: "string"},
            },
          },
          required: ["category", "items"],
        },
      },
    },
    required: ["items", "bookings", "checklist"],
  },
};

const createTripReplyFormat = {
  type: "json_schema",
  name: "create_trip_reply",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    properties: {
      message: {type: "string"},
      draft: {
        type: "object",
        additionalProperties: false,
        properties: {
          destination: {type: ["string", "null"]},
          startDate: {type: ["string", "null"]},
          endDate: {type: ["string", "null"]},
          budget: {type: ["string", "null"]},
          currency: {type: ["string", "null"]},
          groupType: {type: ["string", "null"]},
          preferences: {
            type: "array",
            items: {type: "string"},
          },
        },
        required: [
          "destination",
          "startDate",
          "endDate",
          "budget",
          "currency",
          "groupType",
          "preferences",
        ],
      },
      widget: {
        type: ["object", "null"],
        additionalProperties: false,
        properties: {
          title: {type: "string"},
          options: {
            type: "array",
            minItems: 2,
            maxItems: 4,
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                label: {type: "string"},
                value: {type: "string"},
                description: {type: "string"},
              },
              required: ["label", "value", "description"],
            },
          },
        },
        required: ["title", "options"],
      },
    },
    required: ["message", "draft", "widget"],
  },
};

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
        model: openAiModel,
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

exports.generateTripPlan = onCall(
  {
    region: "us-central1",
    secrets: [openAiApiKey],
  },
  async (request) => {
    const data = request.data ?? {};
    const place = data.place ?? {};
    const destination = String(place.name ?? "").trim();
    const startDate = String(data.startDate ?? "").trim();
    const endDate = String(data.endDate ?? "").trim();
    const budget = Number.parseInt(data.budget, 10);

    if (!destination || !startDate || !endDate || !Number.isFinite(budget)) {
      throw new HttpsError("invalid-argument", "Trip details are required.");
    }

    const plan = await createStructuredResponse({
      instructions: tripPlanInstructions,
      input: {
        destination,
        formattedAddress: String(place.formatted ?? destination),
        startDate,
        endDate,
        budget,
        currency: String(data.currency ?? "USD"),
        groupType: String(data.groupType ?? "Solo"),
        preferences: Array.isArray(data.preferences) ? data.preferences : [],
        flight: {
          airline: String(data.airline ?? ""),
          confirmation: String(data.flightConfirmation ?? ""),
        },
      },
      format: tripPlanFormat,
      logContext: "OpenAI itinerary generation failed",
      publicMessage: "AI itinerary generation failed.",
    });

    return {plan};
  },
);

exports.createTripReply = onCall(
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

    const reply = await createStructuredResponse({
      instructions: createTripInstructions,
      input: {
        latestMessage: message,
        currentDraft: request.data?.currentDraft ?? {},
        recentHistory: Array.isArray(request.data?.history)
          ? request.data.history.slice(-8)
          : [],
        today: request.data?.today ?? null,
      },
      format: createTripReplyFormat,
      logContext: "OpenAI create trip chat failed",
      publicMessage: "AI create trip chat failed.",
    });

    return {reply};
  },
);

async function createStructuredResponse({
  instructions,
  input,
  format,
  logContext,
  publicMessage,
}) {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openAiApiKey.value()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: openAiModel,
      instructions,
      input: JSON.stringify(input),
      store: false,
      reasoning: {effort: "low"},
      text: {
        verbosity: "low",
        format,
      },
    }),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    logger.error(logContext, {
      status: response.status,
      detail: detail.slice(0, 500),
    });
    throw new HttpsError("unavailable", publicMessage);
  }

  const body = await response.json();
  return decodeJsonObject(outputText(body));
}

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

function decodeJsonObject(text) {
  const cleaned = String(text ?? "")
    .trim()
    .replace(/^```(?:json)?/m, "")
    .replace(/```$/m, "")
    .trim();
  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  if (start < 0 || end <= start) {
    throw new HttpsError("unavailable", "AI returned an invalid response.");
  }
  return JSON.parse(cleaned.slice(start, end + 1));
}
