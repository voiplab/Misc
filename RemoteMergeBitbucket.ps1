Param (
    [string]$username = "", 
    [string]$password = "",
    [string]$repo = "",
    [string]$branchSource = "",
    [string]$branchDestination = ""
)

if (!$username -or !$password -or !$repo -or !$branchSource -or !$branchDestination)
{
    Write-TeamcityError "Parameters(username,password,repo,branchSource,branchDestination) could not be blank"
}

$user = $username
$pass = $password
$pair = "$($user):$($pass)"
$result = $null
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValue = "Basic $encodedCreds"
$Headers = @{
    Authorization = $basicAuthValue
}

$bitbucket_pull_requests_url = "https://bitbucket.org/api/2.0/repositories/muranosoft/$repo/pullrequests/"

Write-Host "Base url" $bitbucket_pull_requests_url

$json_create_pull_request= '{ "title": "Automerge from Teamcity", "description": "Automerge", "source": { "branch": { "name": "' + $branchSource + '" }, "repository": { "full_name": "muranosoft/' + $repo + '" } }, "destination": { "branch": { "name": "'+ $branchDestination +'" } }, "reviewers": [ { "username": "some other user needed to review changes" } ], "close_source_branch": false }'

Function WebRequest([string] $url, [string] $json_data){
    return Invoke-WebRequest -Headers $headers -UseBasicParsing $url -ContentType "application/json" -Method POST -Body $json_data
}

Function Write-TeamcityError([string] $message)
{
    Write-Host "Problem: $message"
    Write-Host "##teamcity[buildProblem description='$message']"
}

try{
    # Creating pull request
    $result = WebRequest $bitbucket_pull_requests_url $json_create_pull_request
    
    if ($result.StatusCode -eq "201") {
        Write-Host "Pull request successfully created"
        $result_json_content = $result.Content | ConvertFrom-Json
       
        $bitbucket_url_create_pull_request = $bitbucket_pull_requests_url + $result_json_content.id + '/merge/'
        Write-Host "API Url: " $bitbucket_url_create_pull_request
         
        #Merge pull request
        try{
            $result = Invoke-WebRequest -Headers $headers -UseBasicParsing $bitbucket_url_create_pull_request -ContentType "application/json" -Method POST -Body $json_create_pull_request
	    Write-Host $result
            if ($result.StatusCode -eq "200")
            {
                Write-Host "Result: <" $branchSource "> successfully merged to <" $branchDestination ">"
            }
        }
        catch
        {
	    $result =  $_ | ConvertFrom-Json
	    Write-Host $_
	    Write-TeamcityError $result.error.message
            
	    # We need to remove pull request If we've got some error
            Write-Host "Removing pull request"
            Invoke-WebRequest -Headers $headers -UseBasicParsing ($bitbucket_pull_requests_url + $result_json_content.id + '/decline/') -ContentType "application/json" -Method POST -Body $json_create_pull_request
            exit 1
        }
    }
}
catch
{
    $error_msg = $_
    try
    {
	$result =  $error_msg | ConvertFrom-Json

        #Hack for There are no changes to be pulled
	if ($result.error.message -eq "There are no changes to be pulled")
        {
	    Write-Host $error_msg
            exit 0
	}
        else
	{
	    Write-TeamcityError $result.error.message
        }
    }
    catch
    {
	Write-TeamcityError $error_msg
    }
}
