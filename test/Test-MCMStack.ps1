#Import-Module AWSPowerShell.NetCore
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,Position=0)]
    [string] $Operation
)
$config = (Get-Content -Raw config.json) -join "`n" | convertfrom-json

function Test-MCMStack {
    if($Operation.ToLower() -eq "test"){
        Write-Host -ForegroundColor Blue $("INFO : Testing the deployment of stack in MCM.")
        if(-Not (Test-CFNStack -StackName 'ross-test')){
            Deploy-MCMTestStack
        } else {
            Update-MCMTestStack
        }
    }
    if($Operation.ToLower() -eq "cleanup"){
        if((Test-CFNStack -StackName 'ross-test')){
            Write-Host -ForegroundColor Magenta $("INFO : Cleaning up the deployment of stack in MCM.")
            Remove-MCMTestStack
        } else {
            Write-Host -ForegroundColor Magenta $("INFO : Stack .")
        }
    }
}

function Deploy-MCMTestStack {
    try {
        stackDetails = New-CFNStack `
            -StackName $config.Service.StackSetName `
            -Region $config.Service.Region `
            -Capability 'CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM', 'CAPABILITY_AUTO_EXPAND' `
            -Tag $(Get-MCMStackSetTags) `
            -TemplateURL $config.Service.TemplateUrl `
            -Credential $AccountCred
        Wait-CFNStack -StackName stackDetails.StackName -Status
    } catch {
        Write-Host -ForegroundColor Red $("ERROR : {0} : {1}." -f $Customer.Name, $_.Exception.Message)
    }
}

function Get-MCMStack {
    try {
        $stackDetails = (Get-CFNStackSet -StackSetName $config.Service.StackSetName-Region $config.Service.Region -Credential $AccountCred)
    } catch {
        Write-Host -ForegroundColor Blue $("INFO : {0} : {1}" -f $Customer.Name, $_.Exception.Message)
    }
    return $stackDetails
 }

function Get-MCMStackTags {
    $stackSetTags = @()

    $solutionTag = New-Object -TypeName Amazon.CloudFormation.Model.Tag
    $solutionTag.Key="Solution"
    $soltuionTag.Value=$config.Service.Name
    $stackSetTags += $solutionTag

    $versionTag = New-Object -TypeName Amazon.CloudFormation.Model.Tag
    $versionTag.Key="Version"
    $versionTag.Value=$config.Service.Version
    $stackSetTags += $versionTag

    $gitTag = New-Object -TypeName Amazon.CloudFormation.Model.Tag
    $gitTag.Key="GitURL"
    $gitTag.Value=$config.Service.GitURL
    $stackSetTags += $gitTag

    return $stackSetTags
}



function Get-MCMCustomerCredential{
    $Account = $config.Service.TestAccountId
    $ExecutionRole = $config.Service.ExecutionRole
    $RoleSessionName = $config.Service.SessionName
    $RoleArn = "arn:aws:iam::${Account}:role/${ExecutionRole}"
    $Response = (Use-STSRole -Region $config.Service.Region -RoleArn $RoleArn -RoleSessionName $RoleSessionName).Credentials
    $Credentials = New-AWSCredentials -AccessKey $Response.AccessKeyId -SecretKey $Response.SecretAccessKey -SessionToken $Response.SessionToken
    return $Credentials
}
$AccountCred = Get-MCMCustomerCredential

Test-MCMStackSet