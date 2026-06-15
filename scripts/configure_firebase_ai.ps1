param(
    [string]$Project = "travelling-with-flutter"
)

$ErrorActionPreference = "Stop"

function Read-RequiredSecret {
    param([string]$Name)

    $secure = Read-Host "Enter $Name" -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringUni(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    )

    if ([string]::IsNullOrWhiteSpace($plain)) {
        throw "$Name cannot be empty."
    }

    return $plain.Trim()
}

$geoapifyKey = Read-RequiredSecret "GEOAPIFY_API_KEY"
$openAiKey = Read-RequiredSecret "OPENAI_API_KEY"

$functionsDir = Join-Path $PSScriptRoot "..\functions"
$envPath = Join-Path $functionsDir ".env"

@(
    "GEOAPIFY_API_KEY=$geoapifyKey"
    "OPENAI_API_KEY=$openAiKey"
) | Set-Content -LiteralPath $envPath -Encoding UTF8

firebase deploy --only functions --project $Project
