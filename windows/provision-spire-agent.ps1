param(
    $spireVersion='1.3.3'
)

$serviceName = "spire-agent"
$agentHome = "$env:ProgramData\$serviceName"
$joinToken = Get-Content -Raw "c:\vagrant\share\$($env:COMPUTERNAME.ToLowerInvariant())-join-token.txt"

# download.
# see https://github.com/spiffe/spire/releases
$archiveVersion = $spireVersion
$archiveUrl = "https://github.com/spiffe/spire/releases/download/v$archiveVersion/spire-$archiveVersion-windows-x86_64.zip"
$archiveName = Split-Path -Leaf $archiveUrl
$archiveHash = 'e9df8c65c03538d39848a8c313d3951fc942da60ef9c1e404b5a7fee343ed9f8'
$archivePath = "$env:TEMP\$archiveName"
Write-Host "Downloading spire-agent $archiveVersion..."
(New-Object System.Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveActualHash -ne $archiveHash) {
    throw "the $archiveUrl file hash $archiveActualHash does not match the expected $archiveHash"
}

# install.
Write-Host "Installing spire-agent $archiveVersion..."
mkdir -Force "$agentHome\bin" | Out-Null
mkdir -Force "$agentHome\conf" | Out-Null
mkdir -Force "$agentHome\logs" | Out-Null
Expand-Archive $archivePath $agentHome
Copy-Item "$agentHome\spire-$spireVersion\bin\spire-agent.exe" "$agentHome\bin"
Copy-Item c:\vagrant\share\spire-trust-bundle.pem "$agentHome\conf"
Copy-Item c:\vagrant\spire-agent-windows.conf "$agentHome\conf\spire-agent.conf"
Remove-Item -Force -Recurse "$agentHome\spire-$spireVersion"

Write-Host "Validating the spire-agent configuration..."
&"$agentHome\bin\spire-agent" validate -config "$agentHome\conf\spire-agent.conf"

Write-Host "Installing the $serviceName service..."
nssm install $serviceName "$agentHome\bin\spire-agent.exe"
nssm set $serviceName AppParameters `
    'run' `
    '-config conf\spire-agent.conf' `
    "-joinToken $joinToken"
nssm set $serviceName AppRotateFiles 1
nssm set $serviceName AppRotateOnline 1
nssm set $serviceName AppRotateSeconds 86400
nssm set $serviceName AppRotateBytes 1048576
nssm set $serviceName AppStdout "$agentHome\logs\$serviceName-stdout.log"
nssm set $serviceName AppStderr "$agentHome\logs\$serviceName-stderr.log"
nssm set $serviceName AppDirectory $agentHome
nssm set $serviceName AppExit Default Exit

Write-Host "Starting the $serviceName service..."
Start-Service $serviceName

Write-Host "Waiting for the agent to be healthy..."
while ((&"$agentHome\bin\spire-agent" healthcheck) -ne 'Agent is healthy.') {
    Start-Sleep -Seconds 1
}

Write-Host "Showing the spire-agent SVID..."
openssl x509 -inform der -in "$agentHome\data\agent_svid.der" -text -noout

Write-Host "Showing the spire-agent bundle..."
openssl x509 -inform der -in "$agentHome\data\bundle.der" -text -noout
