function Get-SQLEngineServiceAccount
{
    <#
    .SYNOPSIS
        Get the sql engine service account for a SQL instance
    .DESCRIPTION
        Get the sql engine service account for a SQL instance
    .PARAMETER SqlInstance
        The SQL instance.
    .OUTPUTS
        Trustee name
    .NOTES
        Tags: SQLServer
        Author: Cormac Bracken
        Website:
        Copyright: icensed under MIT
        License: MIT https://opensource.org/licenses/MIT
        Prerequisits: DBATools https://dbatools.io
    .EXAMPLE
        Get-SQLEngineServiceAccount -SqlInstance SQLSERVER001 -InformationAction Continue
    #>
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string[]]$SqlInstance,
        [PSCredential]$Credential
    )
    begin{
        $Trustee = @()
    }

    process {
        foreach($Instance in $SqlInstance){
            #Get the sql engine service account for both SQL instances
            $ServiceAccount = (Get-DbaService -SqlInstance  $Instance -Credential $Credential | where-object -Property ServiceType -EQ Engine).StartName
            if ( $ServiceAccount -EQ "NT Service\MSSQLSERVER") {  # Replace virtual account with computer account
                $Trustee += "$((Resolve-DbaNetworkName -ComputerName $Instance).Domain)\$($Instance)$"
                Write-Information "adding trustee computer account  $Trustee" 
            }
            elseif (  $ServiceAccount -like 'NT Service\MSSQL$*') {  # Replace virtual account with computer account
                $Trustee += "$((Resolve-DbaNetworkName -ComputerName $Instance).Domain)\$($Instance.split("\")[0])$"
                Write-Information "adding trustee computer account  $Trustee" 
            }
            else {
                $Trustee += $ServiceAccount 
            }
        }
    }
    end{
        return  $Trustee | Get-Unique
    }
}