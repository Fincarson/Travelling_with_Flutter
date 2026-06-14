/* global process */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const openAiModel = "gpt-5.5";
const openAiTimeoutMs = 50000;

function geoapifyApiKey() {
  return String(process.env.GEOAPIFY_API_KEY ?? "").trim();
}

function openAiApiKey() {
  return String(process.env.OPENAI_API_KEY ?? "").trim();
}

function googleMapsPlatformApiKey() {
  return String(process.env.GOOGLE_MAPS_PLATFORM_API_KEY ?? "").trim();
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
  "Keep activities suitable for the destination, dates, budget, group, and tags.",
  "Use appContext.localDate and appContext.timeZoneOffset as today's context.",
  "Use startLocation as the trip origin when provided. If startLocation is missing, use appContext.location when available.",
  "If startLocation has an address, use that address as the origin reference; do not show raw coordinates in user-facing itinerary text.",
  "Use web search to identify the nearest practical station, bus stop, airport, ferry terminal, HSR/rail station, or transit hub from the origin address before recommending transport to the destination.",
  "Distribute activities across every date in the trip. Do not leave middle or later days empty.",
  "For trips of 3 or more days, include at least 2 useful schedule items per day and 3 on full sightseeing days.",
  "Day 1 must start with realistic transportation from the trip origin to the destination before destination activities.",
  "The final trip day must include realistic return transportation home after destination activities.",
  "For a one-day trip, do not add hotel stays or hotel bookings unless the user explicitly asks for lodging.",
  "When moving to a different city or district, or when returning home, include pack-up/preparation wording before the transport.",
  "Choose transport by distance: local transit/taxi for nearby trips, train/bus/high-speed rail for regional trips, and flights only for genuinely long-distance trips.",
  "Never suggest a plane for short regional travel such as Hsinchu to Taipei.",
  "Use web search data for current attraction names, transportation options, ticket prices, and local food costs.",
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
  "Required final fields: destination, startDate, endDate, budget, groupType.",
  "Dates must be ISO yyyy-MM-dd. groupType must be Solo, Friends, Family, or Tour.",
  "If the user names a currency, set currency to USD, TWD, IDR, JPY, or EUR.",
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

exports.resolveItineraryMapStops = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const userId = requireAuthenticatedUser(request);
    const tripId = String(request.data?.tripId ?? "").trim();
    const destination = String(request.data?.destination ?? "").trim();
    const items = Array.isArray(request.data?.items) ?
      request.data.items.slice(0, 16) :
      [];
    if (!tripId || !destination || !items.length) {
      throw new HttpsError(
        "invalid-argument",
        "Trip destination and itinerary stops are required.",
      );
    }
    await requireTripMember({tripId, userId});

    const apiKey = googleMapsPlatformApiKey();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "Google Places is not configured.",
      );
    }

    const stops = [];
    for (const item of items) {
      const existingLatitude = Number(item?.latitude);
      const existingLongitude = Number(item?.longitude);
      if (
        Number.isFinite(existingLatitude) &&
        Number.isFinite(existingLongitude) &&
        existingLatitude !== 0 &&
        existingLongitude !== 0
      ) {
        const existingPlaceId = String(item?.placeId ?? "").trim();
        stops.push({
          index: Number.parseInt(item?.index ?? -1, 10),
          placeId: existingPlaceId,
          formattedAddress: String(item?.formattedAddress ?? ""),
          latitude: existingLatitude,
          longitude: existingLongitude,
        });
        continue;
      }

      const activity = String(item?.activity ?? "").trim();
      if (!activity) continue;
      const place = await searchGooglePlace({
        textQuery: `${activity}, ${destination}`,
        apiKey,
      });
      if (!place?.location) continue;
      stops.push({
        index: Number.parseInt(item?.index ?? -1, 10),
        placeId: String(place.id ?? ""),
        formattedAddress: String(place.formattedAddress ?? activity),
        latitude: Number(place.location.latitude),
        longitude: Number(place.location.longitude),
      });
    }

    return {stops};
  },
);

exports.computeItineraryRoute = onCall(
  {
    region: "us-central1",
  },
  async (request) => {
    const userId = requireAuthenticatedUser(request);
    const tripId = String(request.data?.tripId ?? "").trim();
    if (!tripId) {
      throw new HttpsError("invalid-argument", "Trip is required.");
    }
    await requireTripMember({tripId, userId});
    const apiKey = googleMapsPlatformApiKey();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "Google Routes is not configured.",
      );
    }

    const allowedModes = new Set([
      "DRIVE",
      "WALK",
      "BICYCLE",
      "TRANSIT",
    ]);
    const requestedMode = String(request.data?.mode ?? "").toUpperCase();
    const mode = {
      DRIVING: "DRIVE",
      WALKING: "WALK",
      BICYCLING: "BICYCLE",
      TRANSIT: "TRANSIT",
    }[requestedMode] ?? requestedMode;
    const stops = normalizeRouteStops(request.data?.stops);
    if (!allowedModes.has(mode) || stops.length < 2) {
      throw new HttpsError(
        "invalid-argument",
        "A valid travel mode and at least two stops are required.",
      );
    }

    const routeParts = [];
    if (mode === "TRANSIT") {
      for (let index = 0; index < stops.length - 1; index += 1) {
        routeParts.push(
          await fetchGoogleRoute({
            stops: [stops[index], stops[index + 1]],
            mode,
            apiKey,
          }),
        );
      }
    } else {
      routeParts.push(await fetchGoogleRoute({stops, mode, apiKey}));
    }

    const validParts = routeParts.filter((part) => part?.encodedPolyline);
    if (!validParts.length) {
      throw new HttpsError("not-found", "No route was found for these stops.");
    }
    return {
      encodedPolylines: validParts.map((part) => part.encodedPolyline),
      distanceMeters: validParts.reduce(
        (total, part) => total + part.distanceMeters,
        0,
      ),
      durationSeconds: validParts.reduce(
        (total, part) => total + part.durationSeconds,
        0,
      ),
    };
  },
);

function requireAuthenticatedUser(request) {
  const userId = String(request.auth?.uid ?? "").trim();
  if (!userId) {
    throw new HttpsError("unauthenticated", "Sign in to use trip maps.");
  }
  return userId;
}

async function requireTripMember({tripId, userId}) {
  const member = await admin.firestore()
    .collection("trips")
    .doc(tripId)
    .collection("members")
    .doc(userId)
    .get();
  if (!member.exists || member.data()?.status !== "active") {
    throw new HttpsError(
      "permission-denied",
      "You do not have access to this trip.",
    );
  }
}

async function searchGooglePlace({textQuery, apiKey}) {
  const response = await fetch(
    "https://places.googleapis.com/v1/places:searchText",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": [
          "places.id",
          "places.displayName",
          "places.formattedAddress",
          "places.location",
        ].join(","),
      },
      body: JSON.stringify({
        textQuery,
        maxResultCount: 1,
      }),
    },
  );
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    logger.warn("Google Place search failed", {
      status: response.status,
      detail: detail.slice(0, 300),
    });
    return null;
  }
  const body = await response.json();
  return Array.isArray(body.places) && body.places.length ?
    body.places[0] :
    null;
}

function normalizeRouteStops(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 12).map((stop) => ({
    latitude: Number(stop?.latitude),
    longitude: Number(stop?.longitude),
  })).filter(
    (stop) =>
      Number.isFinite(stop.latitude) &&
      Number.isFinite(stop.longitude) &&
      Math.abs(stop.latitude) <= 90 &&
      Math.abs(stop.longitude) <= 180,
  );
}

async function fetchGoogleRoute({stops, mode, apiKey}) {
  const location = (stop) => ({
    location: {
      latLng: {
        latitude: stop.latitude,
        longitude: stop.longitude,
      },
    },
  });
  const body = {
    origin: location(stops[0]),
    destination: location(stops[stops.length - 1]),
    travelMode: mode,
    polylineQuality: "HIGH_QUALITY",
  };
  if (stops.length > 2) {
    body.intermediates = stops.slice(1, -1).map(location);
  }

  const response = await fetch(
    "https://routes.googleapis.com/directions/v2:computeRoutes",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": [
          "routes.distanceMeters",
          "routes.duration",
          "routes.polyline.encodedPolyline",
        ].join(","),
      },
      body: JSON.stringify(body),
    },
  );
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    logger.warn("Google route request failed", {
      mode,
      status: response.status,
      detail: detail.slice(0, 300),
    });
    return null;
  }
  const responseBody = await response.json();
  const route = Array.isArray(responseBody.routes) ?
    responseBody.routes[0] :
    null;
  if (!route) return null;
  return {
    encodedPolyline: String(route.polyline?.encodedPolyline ?? ""),
    distanceMeters: Number(route.distanceMeters ?? 0),
    durationSeconds: googleDurationSeconds(route.duration),
  };
}

function googleDurationSeconds(value) {
  const match = String(value ?? "").match(/^([\d.]+)s$/);
  return match ? Math.round(Number(match[1])) : 0;
}

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
        model: openAiModel,
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
          confirmation: String(data.flightConfirmation ?? ""),
        },
        startLocation: data.startLocation ?? null,
        appContext: data.appContext ?? null,
      },
      format: tripPlanFormat,
      tools: [
        {
          type: "web_search",
          search_context_size: "low",
          external_web_access: true,
        },
      ],
      toolChoice: "required",
      logContext: "OpenAI itinerary generation failed",
      publicMessage: "AI itinerary generation failed.",
    });

    return {plan};
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
        groupType: String(data.groupType ?? "Solo"),
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

async function createStructuredResponse({
  instructions,
  input,
  format,
  tools,
  toolChoice,
  logContext,
  publicMessage,
}) {
  const payload = {
    model: openAiModel,
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

async function fetchOpenAiResponses({payload, logContext, publicMessage}) {
  try {
    return await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openAiApiKey()}`,
        "Content-Type": "application/json",
      },
      signal: AbortSignal.timeout(openAiTimeoutMs),
      body: JSON.stringify(payload),
    });
  } catch (error) {
    const timedOut = error?.name === "AbortError" ||
      error?.name === "TimeoutError";
    logger.error(logContext, {
      timeoutMs: openAiTimeoutMs,
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
