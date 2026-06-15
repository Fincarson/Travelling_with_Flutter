class LocalApiKeys {
  const LocalApiKeys._();

  static const openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const geoapifyApiKey = String.fromEnvironment('GEOAPIFY_API_KEY');
  static const googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDlGzhW9UWlzv4F_QxZZEfo_mxM6zozEUs',
  );

  static bool get hasOpenAiApiKey => openAiApiKey.trim().isNotEmpty;
  static bool get hasGeoapifyApiKey => geoapifyApiKey.trim().isNotEmpty;
  static bool get hasGoogleMapsApiKey => googleMapsApiKey.trim().isNotEmpty;
}
