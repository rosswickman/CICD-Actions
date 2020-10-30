[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,Position=0)]
    [string] $Operation
)
$config = (Get-Content -Raw config.json) -join "`n" | convertfrom-json

function Start-MCMStackSetOperations {
    if($config.Customers.length -eq 0){
        Write-Host -ForegroundColor Magenta $("INFO : No customer root accounts configured for this StackSet.")
    } else {
        $deploy = @()
        $update = @()
        $remove = @()
        foreach ($customer in $config.Customers) {
            Switch (($customer.Status).ToLower()) {
                "deploy" { $deploy += $customer }
                "update" { $update += $customer }
                "remove" { $remove += $customer }
            }
        }
    }

    if($Operation.ToLower() -eq "deploy" -And $deploy){
        #write-host 'will deploy'
        $deploy | ForEach-Object -Parallel {
            Import-Module AWSPowerShell.NetCore
            $function:MCMDeployStackSet = $using:funcDeployDef
            MCMDeployStackSet $_
        }
    }

    if($Operation.ToLower() -eq "update" -And $update){
        #write-host 'will update'
        $update | ForEach-Object -Parallel {
            Import-Module AWSPowerShell.NetCore
            $function:MCMDeployStackSet = $using:funcDeployDef
            MCMDeployStackSet $_
        }
    }

    if($Operation.ToLower() -eq "remove" -And $remove){
        #write-host 'will remove'
        $remove | ForEach-Object -Parallel {
            Import-Module AWSPowerShell.NetCore
            $function:MCMRemoveStackSet = $using:funcRemoveDef
            MCMRemoveStackSet $_
        }
    }
}

function MCMRemoveStackSet {
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [object[]] $customer
    )
    Write-Host -ForegroundColor Blue $("INFO : {0} : Creating [ REMOVE ] Job." -f $customer.Name)
    .\Remove-MCMStackSet.ps1 -Customer $customer
}
$funcRemoveDef = $function:MCMRemoveStackSet.ToString() ## Get the function's definition *as a string* for paralle job

function MCMDeployStackSet {
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [object[]] $customer
    )

    Write-Host -ForegroundColor Blue $("INFO : {0} : Creating [ DEPLOY ] Job." -f $customer.Name)
    .\Deploy-MCMStackSet.ps1 -Customer $customer
}
$funcDeployDef = $function:MCMDeployStackSet.ToString() ## Get the function's definition *as a string* for paralle job

Start-MCMStackSetOperations
