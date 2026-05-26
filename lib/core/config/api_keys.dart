class LocalApiKeys {
  const LocalApiKeys._();

  static const openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const geoapifyApiKey = String.fromEnvironment('GEOAPIFY_API_KEY');

  static bool get hasOpenAiApiKey => openAiApiKey.trim().isNotEmpty;
  static bool get hasGeoapifyApiKey => geoapifyApiKey.trim().isNotEmpty;
}
