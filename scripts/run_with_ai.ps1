param(
    [string]$Device = "windows"
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

flutter run `
    -d $Device `
    --dart-define=GEOAPIFY_API_KEY=$geoapifyKey `
    --dart-define=OPENAI_API_KEY=$openAiKey
