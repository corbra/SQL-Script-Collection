. "$PSScriptRoot\Get-SQLEngineServiceAccounts.ps1"

function New-SQLShare
{
        <#
    .SYNOPSIS
        Create a local SMB share and setup access for SQL 
    .DESCRIPTION
        Create a local SMB share and grant full access to SQL service account
        If the share exists the access will be granted
    .PARAMETER Instance
        The SQL instance.
    .PARAMETER ShareName
        The Share Name 
    .PARAMETER ShareFolder
        The Share Folder - a local path
    .PARAMETER Trustee
       List of additional Trustee(s) - these will be granted full access to the share
    .PARAMETER SqlCredential
       
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
        New-SQLShare -SqlInstance SQLSERVER001 -ShareName "Test" -ShareFolder "D:\test" -Trustee "domain\user" 

        This will create a new share providing access to the SQLSERVER001 service account and -Trustees
        #>
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory,ValueFromPipeline)][string[]]$SqlInstance,
        [Parameter(Mandatory)][string]$ShareName, 
        [Parameter(Mandatory)][string]$ShareFolder,
        [string[]]$Trustee = @(),
        [PSCredential]$SqlCredential
    )
    begin{

    }

    process {
        foreach($Instance in $SqlInstance){
            # Get the SQL Instance Service accounts - required for share access
            $Trustee += Get-SQLAutoEngineServiceAccounts -SQLInstance  $SqlInstance -Credential $SqlCredential
            Write-Debug "New-SQLShare Trustees $Trustees"
        }
    }
    end{
        New-Item -Path $ShareFolder -ItemType "directory" -Force -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference
        if ($PSCmdlet.ShouldProcess("Performing the operation `"New-SMBShare`" `"$ShareName`" on Folder `"$ShareFolder`"","","")){
            New-SMBShare -Name $ShareName -Path $ShareFolder -Description "DBA migration Share" -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference -ErrorAction SilentlyContinue
        }
        if ($PSCmdlet.ShouldProcess("Performing the operation `"Grant-SmbShareAccess`" on Share `"$ShareName`" for `"$Trustee`"","","")){
            $Access = Get-SmbShareAccess -Name $ShareName 
                
            #remove everyone permissions
            $Access | Where-Object {$_.AccountName -eq "Everyone"} | ForEach-Object {
                Revoke-SmbShareAccess -name $ShareName -AccountName $_.AccountName -Force -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference}

            if($Trustee.count -gt 0)
            {
                Grant-SmbShareAccess -Name $ShareName -AccountName $Trustee -AccessRight Full -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference 

                #Set the folder permissions
                $NewAcl = Get-Acl -Path $ShareFolder
                # Set properties

                foreach ($Ident in $Trustee ){
                    # Create new rule
                    $fileSystemAccessRuleArgumentList = $Ident, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow' # $identity, $fileSystemRights, $type
                    $fileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $fileSystemAccessRuleArgumentList
                    # Apply new rule
                    $NewAcl.SetAccessRule($fileSystemAccessRule)
                }
                if($NewAcl){
                    Set-Acl -Path $ShareFolder -AclObject $NewAcl
                }   
            }
        }
    }
}
