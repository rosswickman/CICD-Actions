#Import-Module AWSPowerShell.NetCore
[CmdletBinding()]
Param(
    [object[]] $Customer
)
$config = (Get-Content -Raw "config.json") -join "`n" | convertfrom-json

function Deploy-MCMStackSet {
    if(Get-MCMStackSet){
        Write-Host -ForegroundColor Blue $("INFO : {0} : StackSet {1} already deployed. Will attempt to update stackset." -f $Customer.Name, $config.Service.StackSetName)
        Update-MCMStackSet
    } else {
        $cid = New-Object Amazon.CloudFormation.Model.Parameter
        $cid.ParameterKey="pCidValue"
        $cid.ParameterValue=$Customer.CID
        try {
            New-CFNStackSet `
                -StackSetName $config.Service.StackSetName `
                -Description $config.Service.Description `
                -Region $config.Service.Region `
                -AutoDeployment_Enabled $true `
                -AutoDeployment_RetainStacksOnAccountRemoval $true `
                -Capability 'CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM', 'CAPABILITY_AUTO_EXPAND' `
                -PermissionModel 'service_managed' `
                -TemplateURL $config.Service.TemplateUrl `
                -Credential $AccountCred `
                -Tag $(Get-MCMStackSetTags) | Out-Null
                #-Parameters @( $cid ) | Out-Null
                #-Parameters $(Get-MCMStackSetParams)| Out-Null
            Write-Host -ForegroundColor Blue $("INFO : {0} : Deploying StackSet {1}." -f $Customer.Name, $config.Service.StackSetName)
            Get-MCMStackSetDeployStatus
        } catch {
            Write-Host -ForegroundColor Red $("ERROR : {0} : {1}." -f $Customer.Name, $_.Exception.Message)
        }
    }
}

function Get-MCMStackSetDeployStatus {
    try {
        $stackSetInfo = Get-CFNStackSet -StackSetName $config.Service.StackSetName -Region $config.Service.Region -Credential $AccountCred
        Write-Host -ForegroundColor Blue $("INFO : {0} : StackSet {1} created successfully." -f $Customer.Name, $stackSetInfo.StackSetName)
        New-MCMStackSetInstance
    } catch {
        Write-Host -ForegroundColor Red $("ERROR : {0} : {1}" -f $Customer.Name, $_.Exception.Message)
    }
}

function New-MCMStackSetInstance {
    try {
        New-CFNStackInstance `
            -StackSetName $config.Service.StackSetName `
            -DeploymentTargets_OrganizationalUnitId $Customer.DeployedOuID `
            -StackInstanceRegion $Customer.DeployedRegions `
            -Region $config.Service.Region `
            -Credential $AccountCred `
            -OperationPreferences $(Get-MCMStackSetPrefs) | Out-Null
            Write-Host -ForegroundColor Blue $("INFO : {0} : Deploying new instances of {1}." -f $Customer.Name, $config.Service.StackSetName)
    } catch {
        Write-Host -ForegroundColor Red $("ERROR : {0} : {1}." -f $Customer.Name, $_.Exception.Message)
    }
}

function Update-MCMStackSet {
    try {
        Update-CFNStackSet `
            -StackSetName $config.Service.StackSetName `
            -Description $config.Service.Description `
            -Region $config.Service.Region `
            -AutoDeployment_Enabled $true `
            -AutoDeployment_RetainStacksOnAccountRemoval $true `
            -Capability 'CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM', 'CAPABILITY_AUTO_EXPAND' `
            -PermissionModel 'service_managed' `
            -TemplateURL $config.Service.TemplateUrl `
            -Credential $AccountCred `
            -Tag $(Get-MCMStackSetTags) | Out-Null
        Write-Host -ForegroundColor Blue $("INFO : {0} : Updating StackSet instances for {1}." -f $Customer.Name, $config.Service.StackSetName)
        New-MCMStackSetInstance
    } catch {
        Write-Host -ForegroundColor Red $("ERROR : {0} : {1}." -f $Customer.Name, $_.Exception.Message)
    }
}

function Get-MCMStackSet {
    try {
        $stackDetails = (Get-CFNStackSet -StackSetName $config.Service.StackSetName-Region $config.Service.Region -Credential $AccountCred)
    } catch {
        Write-Host -ForegroundColor Blue $("INFO : {0} : {1}" -f $Customer.Name, $_.Exception.Message)
    }
    return $stackDetails
 }

function Get-MCMStackSetTags {
    $stackSetTags = @()

    $cidTag = New-Object -TypeName Amazon.CloudFormation.Model.Tag
    $cidTag.Key="CID"
    $cidTag.Value=$Customer.CID
    $stackSetTags += $cidTag

    $gitTag = New-Object -TypeName Amazon.CloudFormation.Model.Tag
    $gitTag.Key="GitURL"
    $gitTag.Value=$config.Service.GitURL
    $stackSetTags += $gitTag

    $versionTag = New-Object -TypeName Amazon.CloudFormation.Model.Tag
    $versionTag.Key="Version"
    $versionTag.Value=$config.Service.Version
    $stackSetTags += $versionTag

    return $stackSetTags
}

function Get-MCMStackSetParams {
    $stackSetParams = @()

    # $applicaiton = New-Object -TypeName Amazon.CloudFormation.Model.Parameter
    # $applicaiton.ParameterKey="pApplication"
    # $application.ParameterValue=$Customer.Applicaiton
    # $stackSetParams += $application

    $cid = New-Object -TypeName Amazon.CloudFormation.Model.Parameter
    $cid.ParameterKey="pCidValue"
    $cid.ParameterValue=$Customer.CID
    $stackSetParams += $cid

    $customer = New-Object -TypeName Amazon.CloudFormation.Model.Parameter
    $customer.ParameterKey="pCustomerValue"
    $customer.ParameterValue=$Customer.CID
    $stackSetParams += $cid

    # $environment = New-Object -TypeName Amazon.CloudFormation.Model.Tag
    # $environment.ParameterKey="pEnvironment"
    # $environment.ParameterValue=$config.Service.GitURL
    # $stackSetParas += $environment

    return $stackSetParams
}

function Get-MCMStackSetPrefs {
    $prefs = New-Object -TypeName Amazon.CloudFormation.Model.StackSetOperationPreferences
    $prefs.FailureTolerancePercentage=50
    $prefs.MaxConcurrentPercentage=50
    return $prefs
}

 function Get-MCMCustomerCredential{
    $Account = $Customer.AccountId
    $ExecutionRole = $config.Service.ExecutionRole
    $RoleSessionName = $config.Service.SessionName
    $RoleArn = "arn:aws:iam::${Account}:role/${ExecutionRole}"
    $Response = (Use-STSRole -Region $config.Service.Region -RoleArn $RoleArn -RoleSessionName $RoleSessionName).Credentials
    $Credentials = New-AWSCredentials -AccessKey $Response.AccessKeyId -SecretKey $Response.SecretAccessKey -SessionToken $Response.SessionToken
    return $Credentials
}
$AccountCred = Get-MCMCustomerCredential

Deploy-MCMStackSet
