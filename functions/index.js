/* global process */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {TranslationServiceClient} = require("@google-cloud/translate").v3;
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {randomInt} = require("crypto");

admin.initializeApp();

const openAiChatModel = "gpt-5.4-mini";
const openAiItineraryModel = "gpt-5.5";
const openAiTimeoutMs = 30000;
const translationClient = new TranslationServiceClient();
const currencyRatesCacheLifetimeMs = 24 * 60 * 60 * 1000;
const currencyRatesDocument = admin
    .firestore()
    .collection("app_config")
    .doc("currencyRates");

function geoapifyApiKey() {
  return String(process.env.GEOAPIFY_API_KEY ?? "").trim();
}

function openAiApiKey() {
  return String(process.env.OPENAI_API_KEY ?? "").trim();
}

function safeTravelerCount(value) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) return 1;
  return Math.min(99, Math.max(1, parsed));
}

const travelAssistantInstructions = [
  "You are a concise travel planning assistant inside a mobile app.",
  "Help with itinerary order, budget tradeoffs, packing, food, transit,",
  "and practical destination advice. Keep replies friendly and short.",
  "Use appContext.localDate, appContext.localTime, and appContext.timeZoneOffset",
  "as the source of truth for today, tomorrow, and relative dates.",
  "Use appContext.location only for near-me or location-aware requests.",
].join(" ");

const tripPlanInstructions = [
  "Generate a practical travel itinerary for a mobile travel app.",
  "Use realistic attraction names, reasonable pacing, and approximate costs.",
  "Treat selected tags and custom preference tags as concrete itinerary requirements, not decorative labels.",
  "For each distinctive tag, include at least one matching schedule item, venue area, event search, food stop, accessibility choice, or practical constraint.",
  "For example, anime should trigger anime convention/event-calendar research when dates match, or anime districts, stores, themed cafes, arcades, museums, or pop-culture stops when no convention is current.",
  "Halal food should trigger halal restaurants or Muslim-friendly food areas. Wheelchair access should trigger accessible transit and step-free venues.",
  "Keep activities suitable for the destination, dates, budget, number of travelers, and tags.",
  "Use appContext.localDate and appContext.timeZoneOffset as today's context.",
  "Use startLocation as the trip origin when provided. If startLocation is missing, use appContext.location when available.",
  "If startLocation has an address, use that address as the origin reference; do not show raw coordinates in user-facing itinerary text.",
  "Use web search to identify the nearest practical station, bus stop, airport, ferry terminal, HSR/rail station, or transit hub from the origin address before recommending transport to the destination.",
  "Distribute activities across every date in the trip. Do not leave middle or later days empty.",
  "For trips of 3 or more days, include at least 2 useful schedule items per day and 3 on full sightseeing days.",
  "Day 1 must start with realistic transportation from the trip origin to the destination before destination activities.",
  "The final trip day must include realistic return transportation home after destination activities.",
  "Every day must include realistic place-to-place movement between separated stops, such as walk, metro, taxi, train, airport transfer, or buffer time before the next venue.",
  "Do not list attractions back-to-back as if travel time is zero. Leave realistic gaps for transit, walking, queues, family pacing, meals, check-in, check-out, airport security, and baggage.",
  "If exact public transport schedules or flight times are uncertain, say to confirm the exact operator/time instead of presenting the time as guaranteed.",
  "If flight details include departure or landing time/place, treat those as fixed user-provided constraints and build airport transfers and sightseeing around them.",
  "For international trips, do not end the itinerary at sightseeing. Add pack-up, airport or station transfer, departure, arrival, and return-home steps when the trip ends.",
  "For a one-day trip, do not add hotel stays or hotel bookings unless the user explicitly asks for lodging.",
  "When moving to a different city or district, or when returning home, include pack-up/preparation wording before the transport.",
  "Choose transport by distance: local transit/taxi for nearby trips, train/bus/high-speed rail for regional trips, and flights only for genuinely long-distance trips.",
  "Never suggest a plane for short regional travel such as Hsinchu to Taipei.",
  "Use current-known attraction names, transportation options, ticket prices, and local food costs.",
  "Use specific real place names or clearly named local areas. Do not use generic stop titles like \"signature landmark visit\", \"historic district walk\", \"scenic viewpoint stop\", or \"local scene stop\" unless the title also includes the actual venue or district name.",
  "When the destination name has multiple comma-separated parts, keep enough administrative context to avoid choosing a different city with the same name.",
  "For mappable sightseeing, food, shopping, museum, cafe, beach, hiking, and temple stops, include address, latitude, longitude, and imageUrl when known; use null only for non-place reminders, uncertain transport, or unknown coordinates.",
  "When live data may vary, mark times, prices, and operator details as approximate and tell the user to confirm before departure.",
  "Use ordinary local price ranges for meals. Do not price a normal Taipei local lunch at TWD 700 unless it is fine dining, a multi-person/shared meal, or explicitly expensive.",
].join(" ");

const createTripInstructions = [
  "You are the Create Trip assistant inside a mobile travel app.",
  "Interpret the user message and update the trip draft.",
  "Ask for exactly one missing important field at a time.",
  "When useful, create a tappable widget with 2 to 4 options.",
  "Widget option values must be short user messages the app can send back.",
  "When asking for dates, include a 'Pick exact dates' option with value '__pick_dates__'.",
  "Use appContext.localDate, appContext.localTime, and appContext.timeZoneOffset as the source of truth for today, tomorrow, next weekend, and relative dates.",
  "Use appContext.location only when the user says near me, nearby, my location, or asks for location-aware help.",
  "Required final fields: destination, startDate, endDate, budget, numOfTravelers.",
  "Dates must be ISO yyyy-MM-dd. numOfTravelers must be an integer from 1 to 99.",
  "If the user names a currency, set currency to its three-letter ISO 4217 code.",
].join(" ");

function aiLanguageName(profileLanguage, outputLanguage) {
  const explicit = String(outputLanguage ?? "").trim();
  if (explicit) return explicit;
  switch (String(profileLanguage ?? "en")) {
    case "id":
      return "Indonesian";
    case "zh":
    case "zh_Hant_TW":
    case "zh-TW":
      return "Traditional Chinese";
    case "ja":
      return "Japanese";
    case "ko":
      return "Korean";
    case "es":
      return "Spanish";
    case "fr":
      return "French";
    case "de":
      return "German";
    case "it":
      return "Italian";
    case "pt":
      return "Portuguese";
    case "th":
      return "Thai";
    case "vi":
      return "Vietnamese";
    case "ar":
      return "Arabic";
    default:
      return "English";
  }
}

function outputLanguageInstructions(profileLanguage, outputLanguage) {
  const language = aiLanguageName(profileLanguage, outputLanguage);
  return [
    `Write all user-facing text in ${language}.`,
    "Do not infer language from currency; currency only controls money values.",
  ].join(" ");
}

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
        maxItems: 24,
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
            address: {type: ["string", "null"]},
            latitude: {type: ["number", "null"]},
            longitude: {type: ["number", "null"]},
            imageUrl: {type: ["string", "null"]},
          },
          required: [
            "day",
            "time",
            "activity",
            "type",
            "cost",
            "address",
            "latitude",
            "longitude",
            "imageUrl",
          ],
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
          numOfTravelers: {type: ["integer", "null"]},
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
          "numOfTravelers",
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

const scheduleStopFormat = {
  type: "json_schema",
  name: "generated_schedule_stop",
  strict: true,
  schema: {
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
};

exports.translateUiStrings = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to translate the app interface.",
      );
    }

    const targetCode = String(request.data?.targetCode ?? "").trim();
    const targetLanguage = String(request.data?.targetLanguage ?? "")
      .trim()
      .replace(/[^\p{L}\p{M} ()-]/gu, "")
      .slice(0, 80);
    const strings = Array.isArray(request.data?.strings) ?
      request.data.strings :
      [];

    if (!/^[A-Za-z_]{2,16}$/.test(targetCode) || !targetLanguage) {
      throw new HttpsError(
        "invalid-argument",
        "Choose a supported target language.",
      );
    }
    if (
      strings.length < 1 ||
      strings.length > 40 ||
      strings.some((value) =>
        typeof value !== "string" ||
        value.length < 1 ||
        value.length > 500
      )
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Translation requests must contain 1 to 40 short strings.",
      );
    }

    if (targetCode === "en") {
      return {translations: strings};
    }

    const projectId =
      process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
    if (!projectId) {
      logger.error("translateUiStrings has no Firebase project ID");
      throw new HttpsError(
        "unavailable",
        "Could not translate the app interface right now.",
      );
    }

    try {
      const [response] = await translationClient.translateText({
        parent: `projects/${projectId}/locations/global`,
        contents: strings,
        mimeType: "text/plain",
        sourceLanguageCode: "en",
        targetLanguageCode: cloudTranslationCode(targetCode),
      });
      const translations = response.translations?.map((translation) =>
        String(translation.translatedText ?? ""),
      ) ?? [];
      if (
        translations.length !== strings.length ||
        translations.some((value) => !value)
      ) {
        throw new Error("The translation response was incomplete.");
      }
      return {translations};
    } catch (error) {
      logger.error("translateUiStrings failed", {
        targetCode,
        targetLanguage,
        error,
      });
      throw new HttpsError(
        "unavailable",
        "Could not translate the app interface right now.",
      );
    }
  },
);

function cloudTranslationCode(targetCode) {
  switch (targetCode) {
    case "zh_Hans":
      return "zh-CN";
    case "zh_Hant_TW":
      return "zh-TW";
    case "tl":
      return "fil";
    case "gsw":
      return "de";
    case "nb":
      return "no";
    default:
      return targetCode.replaceAll("_", "-");
  }
}

exports.getExchangeRates = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to load currency rates.",
      );
    }

    const cachedSnapshot = await currencyRatesDocument.get();
    const cached = cachedSnapshot.data();
    const cachedAt = cached?.fetchedAt?.toDate?.();
    if (
      cached &&
      cachedAt &&
      Date.now() - cachedAt.getTime() < currencyRatesCacheLifetimeMs
    ) {
      return currencyRatesResponse(cached, cachedAt);
    }

    try {
      const fresh = await fetchCurrencyRates();
      await currencyRatesDocument.set({
        ...fresh,
        fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        ...fresh,
        fetchedAt: new Date().toISOString(),
      };
    } catch (error) {
      if (cached && cachedAt) {
        logger.warn("Using stale currency rates after refresh failure", {
          message: error?.message,
        });
        return currencyRatesResponse(cached, cachedAt);
      }

      logger.error("Currency rate refresh failed", {
        message: error?.message,
      });
      throw new HttpsError(
        "unavailable",
        "Currency rates are temporarily unavailable.",
      );
    }
  },
);

function currencyRatesResponse(data, fetchedAt) {
  return {
    baseCurrency: data.baseCurrency ?? "USD",
    asOf: data.asOf ?? "",
    rates: data.rates ?? {USD: 1},
    currencies: data.currencies ?? [],
    fetchedAt: fetchedAt.toISOString(),
  };
}

async function fetchCurrencyRates() {
  const [ratesResponse, currenciesResponse] = await Promise.all([
    fetch("https://api.frankfurter.dev/v2/rates?base=USD"),
    fetch("https://api.frankfurter.dev/v2/currencies"),
  ]);
  if (!ratesResponse.ok || !currenciesResponse.ok) {
    throw new Error(
      `Frankfurter request failed: rates=${ratesResponse.status}, ` +
      `currencies=${currenciesResponse.status}`,
    );
  }

  const rateRows = await ratesResponse.json();
  const currencyRows = await currenciesResponse.json();
  if (!Array.isArray(rateRows) || !Array.isArray(currencyRows)) {
    throw new Error("Frankfurter returned an unexpected response.");
  }

  const rates = {USD: 1};
  let asOf = "";
  for (const row of rateRows) {
    const code = String(row?.quote ?? "").trim().toUpperCase();
    const rate = Number(row?.rate);
    if (!/^[A-Z]{3}$/.test(code) || !Number.isFinite(rate) || rate <= 0) {
      continue;
    }
    rates[code] = rate;
    const date = String(row?.date ?? "");
    if (date > asOf) asOf = date;
  }

  const excludedCodes = new Set(["XAG", "XAU", "XDR", "XPD", "XPT"]);
  const currencies = currencyRows
      .map((row) => ({
        code: String(row?.iso_code ?? "").trim().toUpperCase(),
        name: String(row?.name ?? "").trim(),
        symbol: String(row?.symbol ?? "").trim(),
        isoNumeric: String(row?.iso_numeric ?? "").trim(),
      }))
      .filter((item) =>
        /^[A-Z]{3}$/.test(item.code) &&
        item.isoNumeric &&
        rates[item.code] &&
        !excludedCodes.has(item.code),
      )
      .map(({code, name, symbol}) => ({
        code,
        name: name || code,
        symbol: symbol || code,
      }))
      .sort((a, b) => a.code.localeCompare(b.code));

  if (!currencies.some((item) => item.code === "USD")) {
    currencies.push({
      code: "USD",
      name: "United States Dollar",
      symbol: "$",
    });
    currencies.sort((a, b) => a.code.localeCompare(b.code));
  }

  return {
    baseCurrency: "USD",
    asOf,
    rates,
    currencies,
  };
}

exports.searchPlaces = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const query = String(request.data?.query ?? "").trim();
    if (query.length < 3) {
      return {results: []};
    }

    const apiKey = geoapifyApiKey();
    if (!apiKey) {
      logger.error("Geoapify search is not configured");
      throw new HttpsError(
        "failed-precondition",
        "Place search is not configured.",
      );
    }

    try {
      const [countryResults, cityResults] = await Promise.all([
        fetchGeoapifyAutocomplete({query, type: "country", apiKey}),
        fetchGeoapifyAutocomplete({query, type: "city", apiKey}),
      ]);

      return {
        results: rankGeoapifyResults(
          [...countryResults, ...cityResults],
          query,
        ).slice(0, 6),
      };
    } catch (error) {
      logger.error("Geoapify search request failed", {
        query,
        message: error?.message,
      });
      throw new HttpsError("unavailable", "Place search is unavailable.");
    }
  },
);

exports.reversePlace = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const latitude = Number(request.data?.latitude);
    const longitude = Number(request.data?.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      throw new HttpsError("invalid-argument", "Location is required.");
    }

    const apiKey = geoapifyApiKey();
    if (!apiKey) {
      logger.error("Geoapify reverse lookup is not configured");
      throw new HttpsError(
        "failed-precondition",
        "Current location lookup is not configured.",
      );
    }

    try {
      const result = await fetchGeoapifyReverse({
        latitude,
        longitude,
        apiKey,
      });
      return {result: result ? normalizeGeoapifyResult(result) : null};
    } catch (error) {
      logger.error("Geoapify reverse lookup failed", {
        latitude,
        longitude,
        message: error?.message,
      });
      throw new HttpsError(
        "unavailable",
        "Current location lookup is unavailable.",
      );
    }
  },
);

exports.searchNearbyPlaces = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const latitude = Number(request.data?.latitude);
    const longitude = Number(request.data?.longitude);
    const categories = Array.isArray(request.data?.categories) ?
      request.data.categories.map((item) => String(item).trim()).filter(Boolean) :
      [];
    const radiusMeters = Math.min(
      5000,
      Math.max(100, Number.parseInt(request.data?.radiusMeters ?? 1200, 10)),
    );
    const limit = Math.min(
      20,
      Math.max(1, Number.parseInt(request.data?.limit ?? 8, 10)),
    );

    if (
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      !categories.length
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Location and categories are required.",
      );
    }

    const apiKey = geoapifyApiKey();
    if (!apiKey) {
      logger.error("Geoapify nearby lookup is not configured");
      throw new HttpsError(
        "failed-precondition",
        "Nearby place lookup is not configured.",
      );
    }

    try {
      const results = await fetchGeoapifyPlaces({
        latitude,
        longitude,
        categories,
        radiusMeters,
        limit,
        apiKey,
      });
      return {results: results.map(normalizeGeoapifyResult)};
    } catch (error) {
      logger.error("Geoapify nearby lookup failed", {
        latitude,
        longitude,
        categories,
        message: error?.message,
      });
      throw new HttpsError("unavailable", "Nearby places are unavailable.");
    }
  },
);

exports.searchItineraryStop = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const query = String(request.data?.query ?? "").trim();
    const destination = String(request.data?.destination ?? "").trim();
    const latitude = Number(request.data?.latitude);
    const longitude = Number(request.data?.longitude);
    if (query.length < 3) {
      return {results: []};
    }

    const apiKey = geoapifyApiKey();
    if (!apiKey) {
      logger.error("Geoapify itinerary stop lookup is not configured");
      throw new HttpsError(
        "failed-precondition",
        "Itinerary stop lookup is not configured.",
      );
    }

    try {
      const results = await fetchGeoapifyStopSearch({
        query,
        destination,
        latitude,
        longitude,
        apiKey,
      });
      return {
        results: rankGeoapifyResults(results, query).slice(0, 4),
      };
    } catch (error) {
      logger.error("Geoapify itinerary stop lookup failed", {
        query,
        destination,
        message: error?.message,
      });
      throw new HttpsError("unavailable", "Itinerary stop lookup is unavailable.");
    }
  },
);

async function fetchGeoapifyAutocomplete({query, type, apiKey}) {
  const url = new URL("https://api.geoapify.com/v1/geocode/autocomplete");
  url.searchParams.set("text", query);
  url.searchParams.set("format", "json");
  url.searchParams.set("type", type);
  url.searchParams.set("limit", "6");
  url.searchParams.set("apiKey", apiKey);

  const response = await fetch(url);
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(
      `Geoapify ${type} search failed with ${response.status}: ` +
      detail.slice(0, 300),
    );
  }

  const body = await response.json();
  return Array.isArray(body.results) ? body.results : [];
}

async function fetchGeoapifyReverse({latitude, longitude, apiKey}) {
  const url = new URL("https://api.geoapify.com/v1/geocode/reverse");
  url.searchParams.set("lat", String(latitude));
  url.searchParams.set("lon", String(longitude));
  url.searchParams.set("format", "json");
  url.searchParams.set("apiKey", apiKey);

  const response = await fetch(url);
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(
      `Geoapify reverse lookup failed with ${response.status}: ` +
      detail.slice(0, 300),
    );
  }

  const body = await response.json();
  return Array.isArray(body.results) && body.results.length
    ? body.results[0]
    : null;
}

async function fetchGeoapifyStopSearch({
  query,
  destination,
  latitude,
  longitude,
  apiKey,
}) {
  const url = new URL("https://api.geoapify.com/v1/geocode/search");
  const text = destination ? `${query}, ${destination}` : query;
  url.searchParams.set("text", text);
  url.searchParams.set("format", "json");
  url.searchParams.set("limit", "4");
  if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
    url.searchParams.set("bias", `proximity:${longitude},${latitude}`);
  }
  url.searchParams.set("apiKey", apiKey);

  const response = await fetch(url);
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(
      `Geoapify stop search failed with ${response.status}: ` +
      detail.slice(0, 300),
    );
  }

  const body = await response.json();
  return Array.isArray(body.results) ? body.results : [];
}

async function fetchGeoapifyPlaces({
  latitude,
  longitude,
  categories,
  radiusMeters,
  limit,
  apiKey,
}) {
  const url = new URL("https://api.geoapify.com/v2/places");
  url.searchParams.set("categories", categories.join(","));
  url.searchParams.set(
    "filter",
    `circle:${longitude},${latitude},${radiusMeters}`,
  );
  url.searchParams.set("bias", `proximity:${longitude},${latitude}`);
  url.searchParams.set("limit", String(limit));
  url.searchParams.set("apiKey", apiKey);

  const response = await fetch(url);
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(
      `Geoapify nearby lookup failed with ${response.status}: ` +
      detail.slice(0, 300),
    );
  }

  const body = await response.json();
  return Array.isArray(body.features) ? body.features : [];
}

function normalizeGeoapifyResult(item) {
  const properties = item.properties ?? item;
  const geometry = item.geometry ?? {};
  const coordinates = Array.isArray(geometry.coordinates) ?
    geometry.coordinates :
    [];
  const resultType = properties.result_type ?? properties.type ?? null;
  const country = properties.country ?? null;
  const countryCode = String(properties.country_code ?? "")
      .trim()
      .toUpperCase() || null;
  const locality = properties.name ??
    properties.city ??
    properties.county ??
    properties.state ??
    (resultType === "country" ? country : null);
  const formatted = properties.formatted ?? locality ?? "Unknown place";
  const name = placeNameWithCountry(locality || formatted, country);

  return {
    name,
    formatted,
    latitude: properties.lat ?? coordinates[1] ?? 0,
    longitude: properties.lon ?? coordinates[0] ?? 0,
    placeId: properties.place_id ?? formatted,
    country,
    countryCode,
    resultType,
    distanceMeters: properties.distance ?? null,
    categories: Array.isArray(properties.categories) ?
      properties.categories :
      [],
  };
}

function placeNameWithCountry(value, country) {
  const name = String(value ?? "").trim();
  const countryName = String(country ?? "").trim();
  if (!countryName) return name;

  const parts = name
    .split(",")
    .map((part) => part.trim())
    .filter((part) => part);
  const lastPart = parts.length ? parts[parts.length - 1] : name;
  if (
    normalizedPlaceName(name) === normalizedPlaceName(countryName) ||
    normalizedPlaceName(lastPart) === normalizedPlaceName(countryName)
  ) {
    return name;
  }
  return `${name}, ${countryName}`;
}

function rankGeoapifyResults(results, query) {
  const seen = new Set();
  const normalizedQuery = normalizedPlaceName(query);
  return results
    .map(normalizeGeoapifyResult)
    .filter((place) => place.latitude !== 0 && place.longitude !== 0)
    .filter((place) => {
      const key = String(place.placeId || place.formatted);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((a, b) => {
      const scoreA = geoapifyRankScore(a, normalizedQuery);
      const scoreB = geoapifyRankScore(b, normalizedQuery);
      if (scoreA !== scoreB) return scoreA - scoreB;
      return a.name.length - b.name.length;
    });
}

function geoapifyRankScore(place, normalizedQuery) {
  const name = normalizedPlaceName(place.name);
  const country = normalizedPlaceName(place.country ?? "");
  const formatted = normalizedPlaceName(place.formatted);
  const isCountry = place.resultType === "country" ||
    Boolean(country && name === country);

  if (isCountry && (name === normalizedQuery || country === normalizedQuery)) {
    return 0;
  }
  if (name === normalizedQuery) return 1;
  if (formatted === normalizedQuery) return 2;
  if (isCountry) return 3;
  return 4;
}

function normalizedPlaceName(value) {
  return String(value ?? "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "");
}

function validateTripPlanRequest(data) {
  const place = data.place ?? {};
  const destination = String(place.name ?? "").trim();
  const startDate = String(data.startDate ?? "").trim();
  const endDate = String(data.endDate ?? "").trim();
  const budget = Number.parseInt(data.budget, 10);

  if (!destination || !startDate || !endDate || !Number.isFinite(budget)) {
    throw new HttpsError("invalid-argument", "Trip details are required.");
  }
}

async function generateTripPlanFromRequest(data, options = {}) {
  validateTripPlanRequest(data);
  const place = data.place ?? {};
  const destination = String(place.name ?? "").trim();
  const startDate = String(data.startDate ?? "").trim();
  const endDate = String(data.endDate ?? "").trim();
  const budget = Number.parseInt(data.budget, 10);
  const languageInstructions = outputLanguageInstructions(
    data.profileLanguage,
    data.outputLanguage,
  );

  const plan = await createStructuredResponse({
    instructions: `${tripPlanInstructions} ${languageInstructions}`,
    input: {
      destination,
      formattedAddress: String(place.formatted ?? destination),
      destinationLocation: {
        latitude: Number(place.latitude ?? 0),
        longitude: Number(place.longitude ?? 0),
      },
      startDate,
      endDate,
      budget,
      currency: String(data.currency ?? "USD"),
      profileLanguage: String(data.profileLanguage ?? "en"),
      outputLanguage: aiLanguageName(data.profileLanguage, data.outputLanguage),
      groupType: String(data.groupType ?? "Solo"),
      preferences: Array.isArray(data.preferences) ? data.preferences : [],
      flight: {
        airline: String(data.airline ?? ""),
        flightNumber: String(data.flightCode ?? ""),
        departureTime: String(data.flightDepartureTime ?? ""),
        departurePlace: String(data.flightDeparturePlace ?? ""),
        landingTime: String(data.flightLandingTime ?? ""),
        landingPlace: String(data.flightLandingPlace ?? ""),
      },
      startLocation: data.startLocation ?? null,
      appContext: data.appContext ?? null,
    },
    format: tripPlanFormat,
    logContext: "OpenAI itinerary generation failed",
    publicMessage: "AI itinerary generation failed.",
    timeoutMs: options.timeoutMs,
  });
  return enrichTripPlanPlaces(plan, {
    destination,
    latitude: Number(place.latitude ?? 0),
    longitude: Number(place.longitude ?? 0),
  });
}

function sanitizedTripPreviewRequest(data) {
  const place = data.place ?? {};
  return {
    place: {
      name: String(place.name ?? "").trim(),
      formatted: String(place.formatted ?? place.name ?? "").trim(),
      latitude: Number(place.latitude ?? 0),
      longitude: Number(place.longitude ?? 0),
      placeId: String(place.placeId ?? place.formatted ?? place.name ?? ""),
      country: place.country ? String(place.country) : null,
    },
    startDate: String(data.startDate ?? "").trim(),
    endDate: String(data.endDate ?? "").trim(),
    budget: Number.parseInt(data.budget, 10),
    groupType: String(data.groupType ?? "Solo"),
    preferences: Array.isArray(data.preferences) ?
      data.preferences.map((item) => String(item)).slice(0, 20) :
      [],
    currency: String(data.currency ?? "USD"),
    profileLanguage: String(data.profileLanguage ?? "en"),
    outputLanguage: String(data.outputLanguage ?? ""),
    airline: String(data.airline ?? ""),
    flightCode: String(data.flightCode ?? ""),
    flightDepartureTime: String(data.flightDepartureTime ?? ""),
    flightDeparturePlace: String(data.flightDeparturePlace ?? ""),
    flightLandingTime: String(data.flightLandingTime ?? ""),
    flightLandingPlace: String(data.flightLandingPlace ?? ""),
    startLocation: data.startLocation ?? null,
    appContext: data.appContext ?? null,
    fallbackImages: Array.isArray(data.fallbackImages) ?
      data.fallbackImages
        .map((item) => String(item))
        .filter((item) => item.startsWith("https://"))
        .slice(0, 8) :
      [],
  };
}

async function enrichTripPlanPlaces(plan, destinationContext) {
  const apiKey = geoapifyApiKey();
  if (!apiKey || !Array.isArray(plan.items)) return plan;

  const enrichedItems = [];
  for (const item of plan.items) {
    const enriched = {...item};
    if (shouldEnrichScheduleItem(item)) {
      try {
        const query = scheduleItemPlaceQuery(item);
        const results = await fetchGeoapifyStopSearch({
          query,
          destination: destinationContext.destination,
          latitude: destinationContext.latitude,
          longitude: destinationContext.longitude,
          apiKey,
        });
        const place = rankGeoapifyResults(results, query)[0];
        if (place && shouldAcceptEnrichedPlace(item, place, destinationContext)) {
          enriched.address = place.formatted;
          enriched.latitude = place.latitude;
          enriched.longitude = place.longitude;
        }
        const image = await firstPreviewImageForQueries([
          `${query} ${destinationContext.destination}`,
          query,
          destinationContext.destination,
        ]);
        if (image) enriched.imageUrl = image;
      } catch (error) {
        logger.warn("Schedule item enrichment failed", {
          activity: item.activity,
          message: error?.message,
        });
      }
    }
    enrichedItems.push(enriched);
  }
  return {...plan, items: enrichedItems};
}

function shouldEnrichScheduleItem(item) {
  const activity = String(item?.activity ?? "").trim().toLowerCase();
  if (activity.length < 3) return false;
  if (isGenericScheduleActivity(activity)) return false;
  if (activity.includes("weather check") || activity.includes("rain chance")) {
    return false;
  }
  if (
    activity.includes("rain expected") ||
    activity.includes("pack umbrella") ||
    activity.includes("raincoat") ||
    activity.includes("protect tickets") ||
    activity.includes("indoor backup") ||
    activity.startsWith("weather ") ||
    activity.startsWith("ai weather ") ||
    activity.startsWith("reminder:") ||
    activity.startsWith("note:") ||
    activity.startsWith("pack ") ||
    activity.startsWith("prepare ") ||
    activity.startsWith("bring ")
  ) {
    return false;
  }
  return true;
}

function isGenericScheduleActivity(activity) {
  return activity.includes("signature landmark") ||
    activity.includes("transit-friendly district route") ||
    activity.includes("scenic walk, riverside, or viewpoint") ||
    activity.includes("find the best local scene") ||
    activity.includes("nearby cafe or market stop") ||
    activity.includes("known landmark or historic area") ||
    activity.includes("local lunch area") ||
    activity.includes("dinner near the evening area") ||
    activity.includes("easy evening viewpoint") ||
    activity.includes("shopping street or neighborhood browse") ||
    activity.includes("food market or local specialty lunch") ||
    activity.includes("golden-hour park, bridge, or plaza");
}

function shouldAcceptEnrichedPlace(item, place, destinationContext) {
  const destinationLat = Number(destinationContext.latitude);
  const destinationLng = Number(destinationContext.longitude);
  const placeLat = Number(place.latitude);
  const placeLng = Number(place.longitude);
  if (
    !Number.isFinite(destinationLat) ||
    !Number.isFinite(destinationLng) ||
    !Number.isFinite(placeLat) ||
    !Number.isFinite(placeLng) ||
    destinationLat === 0 ||
    destinationLng === 0 ||
    placeLat === 0 ||
    placeLng === 0
  ) {
    return true;
  }
  const distance = distanceKm(destinationLat, destinationLng, placeLat, placeLng);
  if (distance <= 80) return true;
  return isLongDistanceScheduleItem(item);
}

function isLongDistanceScheduleItem(item) {
  const activity = String(item?.activity ?? "").toLowerCase();
  const type = String(item?.type ?? "").toLowerCase();
  return type === "flight" ||
    activity.includes("flight ") ||
    activity.includes("fly ") ||
    activity.includes("airport") ||
    activity.includes("intercity") ||
    activity.includes("long-haul") ||
    activity.includes("return home") ||
    activity.includes("go home");
}

function scheduleItemPlaceQuery(item) {
  return String(item?.activity ?? "")
    .replace(/\b(move|transfer|walk|visit|stop|check)\b/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function distanceKm(lat1, lng1, lat2, lng2) {
  const radiusKm = 6371;
  const dLat = degreesToRadians(lat2 - lat1);
  const dLng = degreesToRadians(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(degreesToRadians(lat1)) *
      Math.cos(degreesToRadians(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return radiusKm * c;
}

function degreesToRadians(degrees) {
  return degrees * Math.PI / 180;
}

async function previewImagesForJob(requestData, plan) {
  const fallbackImages = Array.isArray(requestData.fallbackImages) ?
    requestData.fallbackImages :
    [];
  const itemImages = Array.isArray(plan?.items) ?
    plan.items
      .map((item) => item.imageUrl)
      .filter((image) => typeof image === "string" && image.startsWith("https://")) :
    [];
  const itemQueries = Array.isArray(plan?.items) ?
    plan.items
      .filter(shouldEnrichScheduleItem)
      .map((item) => `${scheduleItemPlaceQuery(item)} ${requestData.place?.name}`)
      .slice(0, 6) :
    [];
  const searchedImages = [];
  for (const query of itemQueries) {
    searchedImages.push(...await fetchWikimediaPreviewImages(query));
  }
  if (!searchedImages.length) {
    searchedImages.push(
      ...await fetchWikimediaPreviewImages(requestData.place?.name),
    );
  }
  const seen = new Set();
  return [...itemImages, ...searchedImages, ...fallbackImages]
    .filter((image) => typeof image === "string" && image.startsWith("https://"))
    .filter((image) => {
      if (seen.has(image)) return false;
      seen.add(image);
      return true;
    })
    .slice(0, 8);
}

async function firstPreviewImageForQueries(queries) {
  for (const query of queries) {
    const images = await fetchWikimediaPreviewImages(query);
    if (images.length) return images[0];
  }
  return null;
}

async function fetchWikimediaPreviewImages(destination) {
  const query = `${String(destination ?? "").trim()} travel landmark`.trim();
  if (!query) return [];

  const url = new URL("https://commons.wikimedia.org/w/api.php");
  url.searchParams.set("action", "query");
  url.searchParams.set("generator", "search");
  url.searchParams.set("gsrsearch", query);
  url.searchParams.set("gsrnamespace", "6");
  url.searchParams.set("gsrlimit", "8");
  url.searchParams.set("prop", "imageinfo");
  url.searchParams.set("iiprop", "url");
  url.searchParams.set("iiurlwidth", "900");
  url.searchParams.set("format", "json");
  url.searchParams.set("origin", "*");

  try {
    const response = await fetch(url, {
      headers: {
        "Accept": "application/json",
        "User-Agent": "TravellingWithFlutter/1.0 trip-preview-jobs",
      },
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) return [];
    const body = await response.json();
    const pages = body?.query?.pages ?? {};
    return Object.values(pages)
      .flatMap((page) => Array.isArray(page.imageinfo) ? page.imageinfo : [])
      .map((info) => info.thumburl ?? info.url)
      .filter(isPreviewImageUrl)
      .slice(0, 8);
  } catch (error) {
    logger.warn("Preview image search failed", {
      destination,
      message: error?.message,
    });
    return [];
  }
}

function isPreviewImageUrl(value) {
  const lower = String(value ?? "").toLowerCase();
  return lower.startsWith("https://") &&
    (lower.includes(".jpg") ||
      lower.includes(".jpeg") ||
      lower.includes(".png") ||
      lower.includes(".webp"));
}

function publicTripPreviewError(error) {
  if (error instanceof HttpsError) return error.message;
  return "AI could not finish the itinerary preview. Please try again.";
}

exports.chatWithAssistant = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const message = String(request.data?.message ?? "").trim();
    if (!message) {
      throw new HttpsError("invalid-argument", "Message is required.");
    }
    if (message.length > 1200) {
      throw new HttpsError("invalid-argument", "Message is too long.");
    }

    const response = await fetchOpenAiResponses({
      payload: {
        model: openAiChatModel,
        instructions: travelAssistantInstructions,
        input: JSON.stringify({
          message,
          appContext: request.data?.appContext ?? null,
        }),
        store: false,
        reasoning: {effort: "low"},
        text: {verbosity: "low"},
      },
      logContext: "OpenAI chat failed",
      publicMessage: "AI chat is unavailable.",
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
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request) => {
    const plan = await generateTripPlanFromRequest(request.data ?? {}, {
      timeoutMs: 90000,
    });
    return {plan};
  },
);

exports.createTripPreviewJob = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Sign in to create a preview.");
    }

    validateTripPlanRequest(request.data ?? {});
    const jobRef = admin
      .firestore()
      .collection("travel_users")
      .doc(userId)
      .collection("tripPreviewJobs")
      .doc();

    await jobRef.set({
      ownerId: userId,
      status: "queued",
      request: sanitizedTripPreviewRequest(request.data ?? {}),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {jobId: jobRef.id};
  },
);

exports.runTripPreviewJob = onDocumentCreated(
  {
    region: "us-central1",
    document: "travel_users/{userId}/tripPreviewJobs/{jobId}",
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data() ?? {};
    if (data.status !== "queued") return;

    const userId = event.params.userId;
    const jobId = event.params.jobId;
    const jobRef = admin
      .firestore()
      .collection("travel_users")
      .doc(userId)
      .collection("tripPreviewJobs")
      .doc(jobId);

    await jobRef.set({
      status: "running",
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    try {
      const requestData = data.request ?? {};
      const plan = await generateTripPlanFromRequest(requestData, {
        timeoutMs: 90000,
      });
      const images = await previewImagesForJob(requestData, plan);
      await jobRef.set({
        status: "ready",
        result: {plan, images},
        finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    } catch (error) {
      logger.error("Trip preview job failed", {
        userId,
        jobId,
        message: error?.message,
      });
      await jobRef.set({
        status: "failed",
        errorMessage: publicTripPreviewError(error),
        finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  },
);

exports.generateScheduleStop = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const data = request.data ?? {};
    const destination = String(data.destination ?? "").trim();
    const targetDay = Number.parseInt(data.targetDay, 10);
    const requestText = String(data.request ?? "").trim();

    if (!destination || !Number.isFinite(targetDay)) {
      throw new HttpsError("invalid-argument", "Trip day is required.");
    }
    if (requestText.length > 800) {
      throw new HttpsError("invalid-argument", "Description is too long.");
    }

    const item = await createStructuredResponse({
      instructions: [
        "Generate exactly one practical schedule stop for a mobile travel app.",
        "Fit it into the requested trip day without duplicating existing stops.",
        "Use current local time and location only if the request asks for nearby or location-aware help.",
        "Keep the activity title concise, specific, and useful during the trip.",
        "Return only JSON matching the schema.",
      ].join(" "),
      input: {
        destination,
        startDate: String(data.startDate ?? ""),
        endDate: String(data.endDate ?? ""),
        currency: String(data.currency ?? "USD"),
        budget: Number.parseInt(data.budget, 10) || 0,
        numOfTravelers: safeTravelerCount(data.numOfTravelers),
        preferences: Array.isArray(data.preferences) ? data.preferences : [],
        targetDay,
        request: requestText || "Suggest a useful trip stop.",
        existingSchedule: Array.isArray(data.existingSchedule)
          ? data.existingSchedule
          : [],
        appContext: data.appContext ?? null,
      },
      format: scheduleStopFormat,
      logContext: "OpenAI schedule stop generation failed",
      publicMessage: "AI schedule stop generation failed.",
    });

    return {item};
  },
);

exports.createTripReply = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const message = String(request.data?.message ?? "").trim();
    if (!message) {
      throw new HttpsError("invalid-argument", "Message is required.");
    }
    if (message.length > 1200) {
      throw new HttpsError("invalid-argument", "Message is too long.");
    }

    const languageInstructions = outputLanguageInstructions(
      request.data?.profileLanguage,
      request.data?.outputLanguage,
    );

    const reply = await createStructuredResponse({
      model: openAiChatModel,
      instructions: `${createTripInstructions} ${languageInstructions}`,
      input: {
        latestMessage: message,
        currentDraft: request.data?.currentDraft ?? {},
        recentHistory: Array.isArray(request.data?.history)
          ? request.data.history.slice(-8)
          : [],
        today: request.data?.today ?? null,
        profileLanguage: String(request.data?.profileLanguage ?? "en"),
        outputLanguage: aiLanguageName(
          request.data?.profileLanguage,
          request.data?.outputLanguage,
        ),
        appContext: request.data?.appContext ?? null,
      },
      format: createTripReplyFormat,
      logContext: "OpenAI create trip chat failed",
      publicMessage: "AI create trip chat failed.",
    });

    return {reply};
  },
);

exports.runTripAutomationReminders = onSchedule(
  {
    region: "us-central1",
    schedule: "every day 06:00",
    timeZone: "Asia/Taipei",
  },
  async () => {
    const db = admin.firestore();
    const snapshot = await db
      .collection("trips")
      .where("status", "in", ["upcoming", "ongoing"])
      .get();

    let checked = 0;
    let updated = 0;
    let notified = 0;

    for (const tripDoc of snapshot.docs) {
      checked += 1;
      const result = await automateTripWeatherReminder(db, tripDoc).catch(
        (error) => {
          logger.warn("Trip automation failed", {
            tripId: tripDoc.id,
            message: error?.message,
          });
          return {updated: false, notified: 0};
        },
      );
      if (result.updated) updated += 1;
      notified += result.notified;
    }

    logger.info("Trip automation reminders complete", {
      checked,
      updated,
      notified,
    });
  },
);

exports.ensureGroupChatJoinCode = onDocumentCreated(
    "chat_groups/{chatId}",
    async (event) => {
      const chat = event.data?.data();
      if (!chat) return;
      await createOrRotateGroupJoinCode({
        db: admin.firestore(),
        chatId: String(event.params.chatId),
        actorId: String(chat.ownerId || ""),
        regenerate: false,
        system: true,
      }).catch((error) => {
        logger.error("Could not create group join code", {
          chatId: event.params.chatId,
          message: error?.message,
        });
      });
    },
);

exports.getGroupChatJoinCode = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to manage a group code.",
      );
    }
    const chatId = String(request.data?.chatId || "").trim();
    if (!chatId) {
      throw new HttpsError("invalid-argument", "Choose a group chat.");
    }

    const code = await createOrRotateGroupJoinCode({
      db: admin.firestore(),
      chatId,
      actorId: request.auth.uid,
      regenerate: request.data?.regenerate === true,
      system: false,
    });
    return {chatId, code};
  },
);

exports.joinGroupChatByCode = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to join a group.");
    }

    const rawCode = normalizeGroupJoinCode(request.data?.code);
    if (!rawCode) {
      throw new HttpsError(
        "invalid-argument",
        "Enter a valid group code.",
      );
    }

    const db = admin.firestore();
    const codeRef = db.collection("chat_join_codes").doc(rawCode);
    const accountId = request.auth.uid;
    const result = await db.runTransaction(async (transaction) => {
      const codeSnapshot = await transaction.get(codeRef);
      if (!codeSnapshot.exists || codeSnapshot.data()?.active !== true) {
        throw new HttpsError("not-found", "This group code is not valid.");
      }

      const codeData = codeSnapshot.data() || {};
      const chatId = String(codeData.chatId || "");
      const chatRef = db.collection("chat_groups").doc(chatId);
      const memberRef = chatRef.collection("members").doc(accountId);
      const membershipRef = db
          .collection("travel_users")
          .doc(accountId)
          .collection("chatMemberships")
          .doc(chatId);
      const profileRef = db.collection("travel_users").doc(accountId);
      const [
        chatSnapshot,
        memberSnapshot,
        profileSnapshot,
      ] = await Promise.all([
        transaction.get(chatRef),
        transaction.get(memberRef),
        transaction.get(profileRef),
      ]);
      if (!chatSnapshot.exists) {
        throw new HttpsError("not-found", "This group no longer exists.");
      }

      const chat = chatSnapshot.data() || {};
      if (normalizeGroupJoinCode(chat.joinCode) !== rawCode) {
        throw new HttpsError(
          "failed-precondition",
          "This group code was replaced.",
        );
      }

      const existingMember = memberSnapshot.data() || {};
      if (
        existingMember.status === "active" &&
        Array.isArray(chat.memberIds) &&
        chat.memberIds.includes(accountId)
      ) {
        return {
          chatId,
          title: String(chat.title || "Group chat"),
          role: String(existingMember.role || "member"),
          alreadyMember: true,
        };
      }

      const profile = profileSnapshot.data() || {};
      const role = "member";
      const now = admin.firestore.FieldValue.serverTimestamp();
      const memberIds = Array.isArray(chat.memberIds)
        ? chat.memberIds.map(String)
        : [];
      const roles = {...(chat.roles || {}), [accountId]: role};
      const displayName = String(
          profile.name || request.auth.token.name || "Explorer",
      ).trim() || "Explorer";
      const photoUrl = typeof profile.photoUrl === "string" ?
        profile.photoUrl :
        null;

      transaction.set(
          chatRef,
          {
            memberIds: memberIds.includes(accountId) ?
              memberIds :
              [...memberIds, accountId],
            roles,
            updatedAt: now,
          },
          {merge: true},
      );
      transaction.set(
          memberRef,
          {
            role,
            status: "active",
            displayNameSnapshot: displayName,
            photoUrlSnapshot: photoUrl,
            joinedAt: now,
            invitedBy: String(codeData.createdBy || chat.ownerId || ""),
            inviteCode: formatGroupJoinCode(rawCode),
            updatedAt: now,
          },
          {merge: true},
      );
      transaction.set(
          membershipRef,
          {
            chatId,
            role,
            status: "active",
            titleSnapshot: String(chat.title || "Group chat"),
            lastMessageText: String(chat.lastMessageText || ""),
            lastMessageAt: chat.lastMessageAt || null,
            unreadCount: 0,
            mutedUntil: null,
            mutedForever: false,
            createdAt: now,
            updatedAt: now,
          },
          {merge: true},
      );

      return {
        chatId,
        title: String(chat.title || "Group chat"),
        role,
        alreadyMember: false,
      };
    });

    return result;
  },
);

async function createOrRotateGroupJoinCode({
  db,
  chatId,
  actorId,
  regenerate,
  system,
}) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const candidate = newGroupJoinCode();
    try {
      return await db.runTransaction(async (transaction) => {
        const chatRef = db.collection("chat_groups").doc(chatId);
        const memberRef = chatRef.collection("members").doc(actorId);
        const candidateRef = db.collection("chat_join_codes").doc(candidate);
        const reads = [
          transaction.get(chatRef),
          transaction.get(candidateRef),
        ];
        if (!system) reads.push(transaction.get(memberRef));
        const snapshots = await Promise.all(reads);
        const chatSnapshot = snapshots[0];
        const candidateSnapshot = snapshots[1];
        const memberSnapshot = system ? null : snapshots[2];

        if (!chatSnapshot.exists) {
          throw new HttpsError("not-found", "Group chat not found.");
        }
        const chat = chatSnapshot.data() || {};
        const existingCode = normalizeGroupJoinCode(chat.joinCode);

        if (!system) {
          const member = memberSnapshot?.data() || {};
          const activeMember =
            memberSnapshot?.exists === true &&
            member.status === "active" &&
            Array.isArray(chat.memberIds) &&
            chat.memberIds.includes(actorId);
          if (!activeMember) {
            throw new HttpsError(
              "permission-denied",
              "You are not an active member of this group.",
            );
          }
          if (
            regenerate &&
            !["owner", "admin"].includes(String(member.role || ""))
          ) {
            throw new HttpsError(
              "permission-denied",
              "Only the owner or an admin can change the group code.",
            );
          }
        }

        if (!regenerate && existingCode) {
          return formatGroupJoinCode(existingCode);
        }

        if (candidateSnapshot.exists) {
          const collision = new Error("join-code-collision");
          collision.joinCodeCollision = true;
          throw collision;
        }

        const now = admin.firestore.FieldValue.serverTimestamp();
        if (existingCode && existingCode !== candidate) {
          transaction.delete(
              db.collection("chat_join_codes").doc(existingCode),
          );
        }
        transaction.set(candidateRef, {
          chatId,
          active: true,
          createdBy: actorId || String(chat.ownerId || ""),
          createdAt: now,
          updatedAt: now,
        });
        transaction.set(
            chatRef,
            {
              joinCode: formatGroupJoinCode(candidate),
              joinCodeUpdatedAt: now,
              updatedAt: now,
            },
            {merge: true},
        );
        return formatGroupJoinCode(candidate);
      });
    } catch (error) {
      if (error?.joinCodeCollision === true) continue;
      throw error;
    }
  }
  throw new HttpsError(
    "internal",
    "Could not generate a unique group code.",
  );
}

function newGroupJoinCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  return Array.from(
      {length: 10},
      () => alphabet[randomInt(0, alphabet.length)],
  ).join("");
}

function normalizeGroupJoinCode(value) {
  const code = String(value || "")
      .trim()
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, "");
  return code.length === 10 ? code : "";
}

function formatGroupJoinCode(value) {
  const code = normalizeGroupJoinCode(value);
  return code ? `${code.slice(0, 5)}-${code.slice(5)}` : "";
}

exports.notifyGroupChatMembers = onDocumentCreated(
    "chat_groups/{chatId}/messages/{messageId}",
    async (event) => {
      const message = event.data?.data();
      if (!message) return;

      const db = admin.firestore();
      const chatId = String(event.params.chatId);
      const chatSnapshot = await db.collection("chat_groups").doc(chatId).get();
      if (!chatSnapshot.exists) return;

      const chat = chatSnapshot.data() || {};
      const senderId = String(message.senderId || "");
      const memberIds = Array.isArray(chat.memberIds)
        ? chat.memberIds.map(String).filter((id) => id && id !== senderId)
        : [];
      if (!memberIds.length) return;

      const title = String(chat.title || "Group chat");
      const sender = String(message.senderNameSnapshot || "Someone");
      const body = chatMessageNotificationBody(message, sender);
      await sendNotificationToUsers({
        db,
        userIds: memberIds,
        title,
        body,
        chatId,
        data: {
          chatId,
          messageId: String(event.params.messageId),
          type: "group_chat",
          tag: `group-chat-${chatId}`,
          targetPath: `/chat/${encodeURIComponent(chatId)}`,
        },
      });
    },
);

exports.notifyGroupChatMemberJoined = onDocumentWritten(
    "chat_groups/{chatId}/members/{memberId}",
    async (event) => {
      const before = event.data?.before.data();
      const after = event.data?.after.data();
      if (!after || after.status !== "active" || before?.status === "active") {
        return;
      }

      const db = admin.firestore();
      const chatId = String(event.params.chatId);
      const joinedMemberId = String(event.params.memberId);
      const chatSnapshot = await db.collection("chat_groups").doc(chatId).get();
      if (!chatSnapshot.exists) return;

      const chat = chatSnapshot.data() || {};
      const memberIds = Array.isArray(chat.memberIds)
        ? chat.memberIds
            .map(String)
            .filter((id) => id && id !== joinedMemberId)
        : [];
      if (!memberIds.length) return;

      const joinedName = String(
          after.displayNameSnapshot || "Someone",
      ).trim() || "Someone";
      const title = String(chat.title || "Group chat");
      await sendNotificationToUsers({
        db,
        userIds: memberIds,
        title,
        body: `${joinedName} joined the group.`,
        chatId,
        data: {
          chatId,
          memberId: joinedMemberId,
          type: "group_member_joined",
          tag: `group-member-${chatId}`,
          targetPath: `/chat/${encodeURIComponent(chatId)}`,
        },
      });
    },
);

function chatMessageNotificationBody(message, sender) {
  const attachment = Array.isArray(message.attachments)
    ? message.attachments[0]
    : null;
  if (String(attachment?.type || "") === "image") {
    return `${sender} just sent a photo.`;
  }
  if (String(message.type || "") === "poll") {
    const question = String(message.poll?.question || "").trim();
    return question ?
      `${sender} started a poll: ${question}` :
      `${sender} started a poll.`;
  }
  return `${sender}: ${chatMessagePreview(message)}`;
}

function chatMessagePreview(message) {
  const text = String(message.text || "").trim();
  if (text) {
    return text.length <= 120 ? text : `${text.slice(0, 117)}...`;
  }
  const attachment = Array.isArray(message.attachments)
    ? message.attachments[0]
    : null;
  switch (String(attachment?.type || "")) {
    case "image":
      return "Photo";
    case "gif":
      return "GIF";
    case "video":
      return "Video";
    case "pdf":
      return `PDF: ${String(attachment?.name || "document")}`;
    default:
      return `File: ${String(attachment?.name || "attachment")}`;
  }
}

async function sendNotificationToUsers({
  db,
  userIds,
  title,
  body,
  data,
  chatId,
}) {
  const recipients = await loadNotificationRecipients({
    db,
    userIds,
    chatId,
  });
  if (!recipients.length) return 0;

  const payloadData = {
    title: String(title),
    body: String(body),
    ...Object.fromEntries(
        Object.entries(data || {}).map(([key, value]) => [
          key,
          String(value),
        ]),
    ),
  };
  const targetPath = payloadData.targetPath || "/";
  let sent = 0;

  for (let start = 0; start < recipients.length; start += 500) {
    const chunk = recipients.slice(start, start + 500);
    const response = await admin.messaging().sendEachForMulticast({
      tokens: chunk.map((recipient) => recipient.token),
      notification: {title, body},
      data: payloadData,
      webpush: {
        notification: {
          title,
          body,
          icon: "/icons/Icon-192.png",
          tag: payloadData.tag || payloadData.type || "travel-agent",
          data: payloadData,
        },
        fcmOptions: {
          link: targetPath,
        },
      },
      android: {
        priority: "high",
        notification: {
          tag: payloadData.tag || payloadData.type || "travel-agent",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    sent += response.successCount;
    const deletes = [];
    response.responses.forEach((result, offset) => {
      if (!result.error) return;
      const code = result.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        deletes.push(chunk[offset].ref.delete());
      }
    });
    await Promise.all(deletes);
  }

  return sent;
}

async function loadNotificationRecipients({db, userIds, chatId}) {
  const recipients = [];
  const uniqueUserIds = [...new Set(userIds.map(String).filter(Boolean))];
  const now = Date.now();
  const activePresenceLifetimeMs = 2 * 60 * 1000;

  for (const userId of uniqueUserIds) {
    const userRef = db.collection("travel_users").doc(userId);
    const reads = [userRef.get()];
    if (chatId) {
      reads.push(userRef.collection("chatMemberships").doc(chatId).get());
    }
    const snapshots = await Promise.all(reads);
    const user = snapshots[0].data() || {};
    if (user.settings?.notificationsEnabled === false) continue;

    if (chatId) {
      const membership = snapshots[1].data() || {};
      const mutedUntil = membership.mutedUntil?.toDate?.();
      if (
        membership.status !== "active" ||
        membership.mutedForever === true ||
        (mutedUntil instanceof Date && mutedUntil.getTime() > now)
      ) {
        continue;
      }
    }

    const tokenSnapshot = await userRef
        .collection("notificationTokens")
        .where("enabled", "==", true)
        .get();
    for (const tokenDoc of tokenSnapshot.docs) {
      const tokenData = tokenDoc.data() || {};
      const token = tokenData.token;
      if (typeof token !== "string" || !token.trim()) continue;

      const presenceUpdatedAt = tokenData.presenceUpdatedAt?.toDate?.();
      const viewingThisChat =
        Boolean(chatId) &&
        tokenData.appState === "foreground" &&
        tokenData.activeChatId === chatId &&
        presenceUpdatedAt instanceof Date &&
        now - presenceUpdatedAt.getTime() <= activePresenceLifetimeMs;
      if (viewingThisChat) continue;

      recipients.push({token, ref: tokenDoc.ref});
    }
  }

  return recipients;
}

const aiChecklistMarker = "[AI] ";
const aiGuardianCategory = "AI Trip Guardian";
const aiWeatherReminderPrefix = "AI weather check:";
const rainWeatherCodes = new Set([
  51,
  53,
  55,
  56,
  57,
  61,
  63,
  65,
  66,
  67,
  80,
  81,
  82,
  95,
  96,
  99,
]);

async function automateTripWeatherReminder(db, tripDoc) {
  const trip = tripDoc.data();
  if (!canAutomateTrip(trip)) return {updated: false, notified: 0};

  const rainyDays = await fetchRainyTripDays(trip);
  if (!rainyDays.length) return {updated: false, notified: 0};

  const checklist = withRainChecklist(trip.checklist, rainyDays);
  const existingRainReminders = await tripDoc.ref
    .collection("itineraryItems")
    .get();
  const existingReminderDays = new Set(
    existingRainReminders.docs
      .filter((doc) => {
        const item = doc.data();
        return (
          item.source === "ai_weather" ||
          String(item.activity || "")
            .trimStart()
            .toLowerCase()
            .startsWith(aiWeatherReminderPrefix.toLowerCase())
        );
      })
      .map((doc) => Number(doc.data().day)),
  );
  const newReminderDays = rainyDays.filter(
    (day) => !existingReminderDays.has(day.day),
  );

  const checklistChanged = !sameJson(
    Array.isArray(trip.checklist) ? trip.checklist : [],
    checklist,
  );
  if (!checklistChanged && !newReminderDays.length) {
    return {updated: false, notified: 0};
  }

  const batch = db.batch();
  if (checklistChanged) {
    batch.set(
      tripDoc.ref,
      {
        checklist,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        automationLastWeatherCheck: dateKey(new Date()),
      },
      {merge: true},
    );
  }

  for (const day of newReminderDays) {
    batch.set(tripDoc.ref.collection("itineraryItems").doc(day.docId), {
      day: day.day,
      time: "07:30",
      activity:
        `${aiWeatherReminderPrefix} ${day.summary}. Pack umbrella/raincoat, ` +
        "protect tickets and electronics, and keep an indoor backup ready " +
        "if showers build.",
      type: "cloud",
      cost: 0,
      source: "ai_weather",
      order: 730,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  const notified = await notifyTripMembers(db, tripDoc.id, trip, rainyDays);
  return {updated: true, notified};
}

function canAutomateTrip(trip) {
  if (!trip || trip.status === "past") return false;
  if (typeof trip.latitude !== "number" || typeof trip.longitude !== "number") {
    return false;
  }

  const start = parseIsoDate(trip.startDate);
  const end = parseIsoDate(trip.endDate);
  if (!start || !end || end < start) return false;

  const today = dateOnly(new Date());
  const forecastLimit = addDays(today, 15);
  return end >= today && start <= forecastLimit;
}

async function fetchRainyTripDays(trip) {
  const start = parseIsoDate(trip.startDate);
  const end = parseIsoDate(trip.endDate);
  if (!start || !end) return [];

  const url = new URL("https://api.open-meteo.com/v1/forecast");
  url.searchParams.set("latitude", Number(trip.latitude).toFixed(5));
  url.searchParams.set("longitude", Number(trip.longitude).toFixed(5));
  url.searchParams.set(
    "daily",
    "weather_code,precipitation_sum,precipitation_probability_max",
  );
  url.searchParams.set("timezone", "auto");
  url.searchParams.set("forecast_days", "16");

  const response = await fetch(url, {
    signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) return [];

  const body = await response.json();
  const daily = body?.daily ?? {};
  const times = Array.isArray(daily.time) ? daily.time : [];
  const codes = Array.isArray(daily.weather_code) ? daily.weather_code : [];
  const amounts = Array.isArray(daily.precipitation_sum)
    ? daily.precipitation_sum
    : [];
  const probabilities = Array.isArray(daily.precipitation_probability_max)
    ? daily.precipitation_probability_max
    : [];

  const today = dateOnly(new Date());
  const rainyDays = [];
  for (let index = 0; index < times.length; index += 1) {
    const date = parseIsoDate(times[index]);
    if (!date || date < today || date < start || date > end) continue;

    const weatherDay = {
      day: daysBetween(start, date) + 1,
      date,
      dateKey: dateKey(date),
      weatherCode: numberAt(codes, index),
      precipitationSum: numberAt(amounts, index),
      precipitationProbability: numberAt(probabilities, index),
    };
    weatherDay.docId = `ai-weather-${weatherDay.dateKey}`;
    weatherDay.summary = weatherSummary(weatherDay);
    if (isRainyWeatherDay(weatherDay)) rainyDays.push(weatherDay);
  }
  return rainyDays;
}

function withRainChecklist(checklistValue, rainyDays) {
  const checklist = Array.isArray(checklistValue)
    ? checklistValue.map((category) => ({
        category: String(category?.category || "Checklist"),
        items: Array.isArray(category?.items)
          ? category.items.filter((item) => typeof item === "string")
          : [],
      }))
    : [];
  const index = checklist.findIndex(
    (category) =>
      category.category.trim().toLowerCase() ===
      aiGuardianCategory.toLowerCase(),
  );
  const guardian =
    index === -1
      ? {category: aiGuardianCategory, items: []}
      : checklist[index];
  const existing = new Set(guardian.items.map(checklistCompareText));
  const additions = [
    "Umbrella or light raincoat",
    "Waterproof pouch for phone, passport, and tickets",
    rainSummaryChecklistItem(rainyDays),
  ];

  const items = [...guardian.items];
  for (const addition of additions) {
    if (existing.has(checklistCompareText(addition))) continue;
    existing.add(checklistCompareText(addition));
    items.push(aiChecklistItem(addition));
  }

  const nextGuardian = {...guardian, items};
  if (index === -1) checklist.push(nextGuardian);
  else checklist[index] = nextGuardian;
  return checklist;
}

async function notifyTripMembers(db, tripId, trip, rainyDays) {
  const memberIds = Array.isArray(trip.memberIds) ? trip.memberIds : [];
  const title = `${trip.destination || "Your trip"} weather update`;
  const body = rainPushBody(rainyDays);
  return sendNotificationToUsers({
    db,
    userIds: memberIds,
    title,
    body,
    data: {
      tripId,
      tag: `trip-weather-${tripId}-${dateKey(new Date())}`,
      type: "trip_weather",
      targetPath: `/trips/${encodeURIComponent(tripId)}`,
    },
  });
}

function rainPushBody(rainyDays) {
  const peak = rainyDays
    .map((day) => day.precipitationProbability)
    .filter((value) => typeof value === "number")
    .reduce((max, value) => Math.max(max, value), 0);
  const dayText = rainyDays.length === 1 ? "one day" : `${rainyDays.length} days`;
  if (peak > 0) {
    return `Rain is possible on ${dayText}, up to ${peak}%. I added umbrella/raincoat reminders.`;
  }
  return `Rain is possible on ${dayText}. I added umbrella/raincoat reminders.`;
}

function rainSummaryChecklistItem(rainyDays) {
  const peak = rainyDays
    .map((day) => day.precipitationProbability)
    .filter((value) => typeof value === "number")
    .reduce((max, value) => Math.max(max, value), 0);
  const rainyDayText =
    rainyDays.length === 1
      ? "Rain is possible on one trip day"
      : `Rain is possible on ${rainyDays.length} trip days`;
  if (peak > 0) return `${rainyDayText}, up to ${peak}%; keep shoes dry`;
  return `${rainyDayText}; keep shoes dry`;
}

function isRainyWeatherDay(day) {
  return (
    rainWeatherCodes.has(day.weatherCode) ||
    (typeof day.precipitationSum === "number" && day.precipitationSum >= 1) ||
    (typeof day.precipitationProbability === "number" &&
      day.precipitationProbability >= 50)
  );
}

function weatherSummary(day) {
  const parts = [];
  if (typeof day.precipitationProbability === "number") {
    parts.push(`${day.precipitationProbability}% rain chance`);
  }
  if (typeof day.precipitationSum === "number" && day.precipitationSum > 0) {
    const digits = day.precipitationSum >= 10 ? 0 : 1;
    parts.push(`${day.precipitationSum.toFixed(digits)} mm expected`);
  }
  return parts.length ? parts.join(", ") : "rain is possible today";
}

function aiChecklistItem(item) {
  const display = checklistDisplayText(item).trim();
  return display ? `${aiChecklistMarker}${display}` : aiChecklistMarker.trim();
}

function checklistDisplayText(item) {
  const text = String(item ?? "").trimStart();
  if (!text.startsWith(aiChecklistMarker)) return String(item ?? "");
  return text.slice(aiChecklistMarker.length).trimStart();
}

function checklistCompareText(item) {
  return checklistDisplayText(item)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function sameJson(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function numberAt(values, index) {
  const value = values[index];
  return typeof value === "number" ? value : null;
}

function parseIsoDate(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value ?? ""));
  if (!match) return null;
  return new Date(
    Number(match[1]),
    Number(match[2]) - 1,
    Number(match[3]),
  );
}

function dateOnly(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function addDays(date, days) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function daysBetween(start, end) {
  const millisPerDay = 24 * 60 * 60 * 1000;
  return Math.round((dateOnly(end) - dateOnly(start)) / millisPerDay);
}

function dateKey(date) {
  const year = date.getFullYear().toString().padStart(4, "0");
  const month = (date.getMonth() + 1).toString().padStart(2, "0");
  const day = date.getDate().toString().padStart(2, "0");
  return `${year}-${month}-${day}`;
}

async function createStructuredResponse({
  model = openAiItineraryModel,
  instructions,
  input,
  format,
  tools,
  toolChoice,
  logContext,
  publicMessage,
  timeoutMs,
}) {
  const payload = {
    model,
    instructions,
    input: JSON.stringify(input),
    store: false,
    reasoning: {effort: "low"},
    text: {
      verbosity: "low",
      format,
    },
  };
  if (Array.isArray(tools) && tools.length) {
    payload.tools = tools;
  }
  if (toolChoice) {
    payload.tool_choice = toolChoice;
  }

  const response = await fetchOpenAiResponses({
    payload,
    logContext,
    publicMessage,
    timeoutMs,
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

async function fetchOpenAiResponses({
  payload,
  logContext,
  publicMessage,
  timeoutMs = openAiTimeoutMs,
}) {
  try {
    return await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openAiApiKey()}`,
        "Content-Type": "application/json",
      },
      signal: AbortSignal.timeout(timeoutMs),
      body: JSON.stringify(payload),
    });
  } catch (error) {
    const timedOut = error?.name === "AbortError" ||
      error?.name === "TimeoutError";
    logger.error(logContext, {
      timeoutMs,
      message: error?.message,
    });
    throw new HttpsError(
      timedOut ? "deadline-exceeded" : "unavailable",
      publicMessage,
    );
  }
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
