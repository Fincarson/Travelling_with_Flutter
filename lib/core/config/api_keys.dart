class LocalApiKeys {
  const LocalApiKeys._();

  static const openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const geoapifyApiKey = String.fromEnvironment('GEOAPIFY_API_KEY');
  static const googleMapsWebEnabled = bool.fromEnvironment(
    'GOOGLE_MAPS_WEB_ENABLED',
  );

  static bool get hasOpenAiApiKey => openAiApiKey.trim().isNotEmpty;
  static bool get hasGeoapifyApiKey => geoapifyApiKey.trim().isNotEmpty;
}
