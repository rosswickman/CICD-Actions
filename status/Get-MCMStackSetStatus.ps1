#Import-Module AWSPowerShell.NetCore
$config = (Get-Content -Raw config.json) -join "`n" | convertfrom-json
$deploy = @()
$update = @()
$remove = @()
$other = @()

function Get-MCMStackSetStatus {
    if($config.Customers.length -eq 0){
        Write-Host -ForegroundColor Blue $("+++++++++++++++ NO CUSTOMER ACCOUNTS CONFIGURED FOR THIS STACKSSET +++++++++++++++`n" -f $deploy.Count)
    } else {
        foreach ($customer in $config.Customers) {
            Switch (($customer.Status).ToLower()) {
                "deploy" { $deploy += $customer }
                "update" { $update += $customer }
                "remove" { $remove += $customer }
                default { $other += $customer}
            }
        }
    }

    if($deploy){
        Write-Host -ForegroundColor Blue $("+++++++++++++++ CHECKING [ DEPLOY ] STATUS FOR [ {0} ] CUSTOMER STACKS +++++++++++++++`n" -f $deploy.Count)
        foreach ($c in $deploy) {
            Get-MCMDeployStatus -customer $deploy
        }
    }

    if($update){
        Write-Host -ForegroundColor Blue $("+++++++++++++++ CHECKING [ UPDATE ] STATUS FOR [ {0} ] CUSTOMER STACKS +++++++++++++++`n" -f $update.Count)
        foreach ($c in $update) {
            Get-MCMDeployStatus -customer $update
        }
    }

    if($remove){
        Write-Host -ForegroundColor Blue $("+++++++++++++++ CHECKING [ REMOVE ] STATUS FOR [ {0} ] CUSTOMER STACKS +++++++++++++++`n" -f $remove.Count)
        foreach ($c in $remove) {
            Get-MCMRemoveStatus -customer $remove
        }
    }

    if($other){
        Write-Host -ForegroundColor Yellow $("+++++++++++++++ [ {0} ] CUSTOMERS ON HOLD OR INVALD STATUS +++++++++++++++`n" -f $customer.Count)
        foreach ($c in $other) {
            Write-Host -ForegroundColor Yellow $("CUSTOMER : {0} : Status of [ {1} ]" -f $c.Name, $c.Status)
        }
    }
}

function Get-MCMDeployStatus {
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [object[]] $customer
    )

    $AccountCred = Get-MCMCustomerCredential $customer.AccountId
    try {
        $stackDetails = Get-CFNStackSet -StackSetName $config.Service.StackSetName -Region $config.Service.Region -Credential $AccountCred
        $opId = Get-CFNStackSetOperationList -StackSetName $stackDetails.StackSetName -Credential $AccountCred
        if($opId[0].Action -eq "CREATE" -and $opId[0].Status -eq "SUCCEEDED"){
            Write-Host -ForegroundColor Green $("SUCCESS: {0} : StackSet {1} [ {2} ]" -f $customer.Name, $opId[0].Action, $opId[0].Status)
        } else {
            Write-Host -ForegroundColor Blue $("INFO : {0} : StackSet {1} [ {2} ]" -f $customer.Name, $opId[0].Action, $opId[0].Status)
        }
    } catch {
        Write-Host -ForegroundColor Red $("ERROR : {0} : {1}" -f $customer.Name, $_.Exception.Message)
    }
}

function Get-MCMRemoveStatus {
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [object[]] $customer
    )

    $AccountCred = Get-MCMCustomerCredential $customer.AccountId
    try{
        $stackDetails = Get-CFNStackSet -StackSetName $config.Service.StackSetName -Region $config.Service.Region -Credential $AccountCred
        $opId = Get-CFNStackSetOperationList -StackSetName $stackDetails.StackSetName -Credential $AccountCred
        $stackSetInstances = Get-CFNStackInstanceList -StackSetName $stackDetails.StackSetName -Credential $AccountCred
        if($opId[0].Action -eq "DELETE" -and $opId[0].Status -eq "SUCCEEDED" -and -not $stackSetInstances){
            Write-Host -ForegroundColor Blue $("INFO : {0} : StackSet present but with no instances. Will complete delete." -f $customer.Name)
            try{
                Remove-CFNStackSet -StackSetName $stackDetails.StackSetName -Confirm:$false -Force -Credential $AccountCred
                Write-Host -ForegroundColor Green $("SUCCESS : {0} : StackSet [ REMOVED ]" -f $Customer.Name)
            } catch {
                Write-Host -ForegroundColor Red $("ERROR : {0} : StackSet cannot be removed." -f $Customer.Name)
            }
        } else {
            Write-Host -ForegroundColor Blue $("INFO : {0} : StackSet {1} [ {2} ]" -f $customer.Name, $opId[0].Action, $opId[0].Status)
        }
    } catch {
        Write-Host -ForegroundColor Green $("SUCCESS : {0} : StackSet [ NOT PRESENT ]" -f $Customer.Name)
    }
}

function Get-MCMCustomerCredential{
    Param(
        [Parameter(Mandatory=$true,Position=0)]
        [string] $Account
    )
    $ExecutionRole = $config.Service.ExecutionRole
    $RoleSessionName = $config.Service.SessionName
    $RoleArn = "arn:aws:iam::${Account}:role/${ExecutionRole}"
    $Response = (Use-STSRole -Region $config.Service.Region -RoleArn $RoleArn -RoleSessionName $RoleSessionName).Credentials
    $Credentials = New-AWSCredentials -AccessKey $Response.AccessKeyId -SecretKey $Response.SecretAccessKey -SessionToken $Response.SessionToken
    return $Credentials
}

Get-MCMStackSetStatus
