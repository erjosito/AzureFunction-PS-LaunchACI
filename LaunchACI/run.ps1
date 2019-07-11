# July 2019, FastTrack for Azure (jose.moreno@microsoft.com)
#
# This function launches an Azure Container Instance out of an image stored in an Azure Container Repository
#
# OsType defaults to Linux, but it can be changed to Windows if specified in the query or body
#

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Get info from query parameters
$rg_name = $Request.Query.rg_name
$aci_name = $Request.Query.aci_name
$acr_name = $Request.Query.acr_name
$acr_rg_name = $Request.Query.acr_rg_name
$image_name = $Request.Query.image_name
$os_type = $Request.Query.os_type

# If not received in the query, check the body
if (-not $rg_name) {
    $rg_name = $Request.Body.rg_name
}
if (-not $aci_name) {
    $aci_name = $Request.Body.aci_name
}
if (-not $acr_name) {
    $acr_name = $Request.Body.acr_name
}
if (-not $acr_rg_name) {
    $acr_rg_name = $Request.Body.acr_rg_name
}
if (-not $image_name) {
    $image_name = $Request.Body.image_name
}
if (-not $os_type_name) {
    $os_type = $Request.Body.os_type
}

# Check for compulsory parameters
if ($rg_name -and $aci_name -and $acr_name -and $image_name) {
    $status = [HttpStatusCode]::OK
    $body = "$(Get-Date -Format G): Starting creation of Azure Container Instance $aci_name in resource group $rg_name out of container image $image_name from Azure Container Repository $acr_name"
    Write-Host $body
    $continue = $true
}
else {
    $status = [HttpStatusCode]::BadRequest
    $body = "$(Get-Date -Format G): Please pass the following parameters in the query or the body: rg_name, aci_name, acr_name, image_name"
    Write-Host $body
    $continue = $false
}

# Set defaults for optional parameters
if (-not $os_type) {
    $os_type = "Linux"
    Write-Host "$(Get-Date -Format G): Setting OSType default to Linux"
}

# Invoke debugger
# Wait-Debugger

# Logging in to Azure not required here, since login is performe more effectively in profile.ps1
# Write-Host "Authenticating to Azure..."
# Connect-AzAccount -Identity

# Verify we are logged in
if ($continue) {
    $sub = $(get-azcontext).Subscription.Name
    $user = $(get-azcontext).Account.Id
    if ($sub -and $user) {
        $status = [HttpStatusCode]::OK
        $body = "$(Get-Date -Format G): Logged in successfully to Azure subscription $sub as user $user"
        Write-Host $body
        $continue = $true
    }
    else {
        $status = [HttpStatusCode]::BadRequest
        $body = "$(Get-Date -Format G): Azure login failed"
        Write-Host $body
        $continue=$false
    }
}

# Get RG for ACR if not spedified as parameter.
# Full read-only subscription access required for this to work.
if ($continue -and (-not $acr_rg_name)) {
    $acr_rg_name=$(Get-AzContainerregistry | Where-Object Name -eq $acr_name -ErrorAction SilentlyContinue).ResourceGroupName
    if ($acr_rg_name) {
        $status = [HttpStatusCode]::OK
        $body = "$(Get-Date -Format G): Resource Group for ACR $acr_name found: $acr_rg_name"
        Write-Host $body
        $continue = $true
    }
    else {
        $status = [HttpStatusCode]::BadRequest
        $body = "$(Get-Date -Format G): Resource group for ACR $acr_name could not be found." 
        $body += " Verify that the ACR resource exists, and that the Azure Function system identity has access to it."
        $body += " Note that if the Azure Function identity does not have permissions for the whole subscription you need to specify the parameter acr_rg_name."
        Write-Host $body
        $continue=$false
    }
}

# First delete any possible container instance
if ($continue)
{
    Write-Host "Trying to find and delete previous container instance $aci_name in resource group $rg_name"
    $aci = Get-AzContainerGroup -ResourceGroupName $rg_name -Name $aci_name -ErrorAction SilentlyContinue
    if ($aci) {
        Remove-AzContainerGroup -Name $aci_name -ResourceGroup $rg_name -Confirm:$false
        Write-Host "$(Get-Date -Format G): Deleted previous container instance of container $aci_name"
    } else {
        Write-Host "$(Get-Date -Format G): Container $aci_name could not be found, proceeding without deleting previous instance"
    }

    # Get ACR Credentials
    Write-Host "$(Get-Date -Format G): Getting credentials for ACR $acr_name"
    $acr_creds=$(Get-AzContainerRegistryCredential -Name $acr_name -ResourceGroupName $acr_rg_name)
    $secpasswd = ConvertTo-SecureString $acr_creds.Password -AsPlainText -Force
    $system_acr_creds = New-Object System.Management.Automation.PSCredential ($acr_creds.Username, $secpasswd)
    if ($system_acr_creds) {
        $status = [HttpStatusCode]::OK
        $user = $acr_creds.Username
        $body = "$(Get-Date -Format G): Credentials obtained for ACR $acr_name for user $user"
        Write-Host $body
        $continue = $true
    } else {
        $status = [HttpStatusCode]::BadRequest
        $body = "$(Get-Date -Format G): Credentials for ACR $acr_name in resource group $acr_rg_name could not be found"
        Write-Host $body
        $continue=$false
    }
}

# Launch container
if ($continue)
{
    Write-Host "$(Get-Date -Format G): Launching new container instance..."
    $image_path=$acr_name.ToLower() + '.azurecr.io/' + $image_name
    New-AzContainerGroup -ResourceGroupName $rg_name -Name $aci_name -Image $image_path -OsType $os_type -RegistryCredential $system_acr_creds -RestartPolicy Never

    # Verify that new container instance
    Write-Host "Verifying that the container instance has been successfully started..."
    $aci = Get-AzContainerGroup -ResourceGroupName $rg_name -Name $aci_name -ErrorAction SilentlyContinue
    if ($aci) {
        $status = [HttpStatusCode]::OK
        $body = "$(Get-Date -Format G): Azure Container Instance $aci_name successfully created in resource group $rg_name out of container image $image_name from Azure Container Repository $acr_name"
        Write-Host $body
    } else {
        $status = [HttpStatusCode]::BadRequest
        $body = "$(Get-Date -Format G): Container $aci_name could not be found, looks like the New-AzContainerGroup command has failed"
        Write-Host $body
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
})
