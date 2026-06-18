param(
    [string]$Project = "travelling-with-flutter"
)

$ErrorActionPreference = "Stop"

firebase functions:secrets:set GEOAPIFY_API_KEY --project $Project
firebase functions:secrets:set OPENAI_API_KEY --project $Project
firebase deploy --only functions --project $Project
