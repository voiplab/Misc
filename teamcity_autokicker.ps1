param(
    $teamcityUsername = $(throw "-TeamcityUsername is required"),
    $teamcityPassword = $(throw "-TeamcityPassword is required"),
    $teamcityBuildConfigurationId = $(throw "-teamcityBuildConfigurationId is required"),
    $teamcityHost = $(throw "-teamcityHost is required"),
    $teamcityEnvVariables = "",
    $teamcityComment = "Triggered by autokicker"
)

function getAuthHeader($user, $pass) {
    $pair = "$($user):$($pass)"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $basicAuthValue = "Basic $base64"
    return $basicAuthValue
}


function getParams($vars) {
    $arr = $vars -split ';'
    $buffer = "";
    foreach ($item in $arr) {
        $key,$val = $item.split('=');
        if (![string]::IsNullOrWhiteSpace($key) -and ![string]::IsNullOrWhiteSpace($val)) {
            $buffer += $('<property name="'+ $key +'" value="' + $val +'"/>') 
        }
    }
    return $buffer;
}


# Request object
[xml]$request = $('
    <build>
        <buildType id="' + $teamcityBuildConfigurationId + '"/>
        <comment>
            <text>' + $teamcityComment +'</text>
        </comment>
        <properties>' + $(getParams $teamcityEnvVariables) + '</properties>
    </build>')

                          
# Send POST to TeamCity to trigger the build, store the returned status URL
[xml]$response = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $($teamcityHost + "/httpAuth/app/rest/buildQueue") -Body $request -Headers @{ Authorization = $(getAuthHeader $teamcityUsername $teamcityPassword) } -ContentType "application/xml"

# Failed to queue build
if ($response.build.state -ne "queued") {
  Write-Host "Failed to queue build"
  exit 1;
} else {
    Write-Host $("Build started with ID " + $response.build.id)
}
