$DebugPreference = "SilentlyContinue"

function Move-DBSystemDatabase {
        <#
    .SYNOPSIS
        Semi Automated Function to Move System database files to a new location - takes sql offline.
        WARNING!!! Some manual steps to configure the master database are necessary see Microsft Help on moving SQL system databases

    .DESCRIPTION
         Move System database files to a new location.
    .PARAMETER SqlInstance
        The target SQL Server instance
    .PARAMETER Destination
        The destination file path
    .PARAMETER Credential
        PSCredential object, otherwise the current user will be used.

    .NOTES
       
        Author: Cormac Bracken
        -- Sometime copy ACL fails, Run this on the server to copy permission 
        -- Get-Acl -Path  "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\" | Set-Acl "D:\SQLSystem\"

        For error "WinRM cannot process the request. The following error occurred while using Kerberos authentication: Cannot find the computer. 
        Usually this will not occur when the FQN is used.

    .EXAMPLE
        PS C:\> Move-DBSystemDatabase -SqlInstance SQLSERVER001.domain.com -Destination D:\SQLSystem -WhatIf

        PS C:\> Move-DBSystemDatabase -SqlInstance SQLSERVER001.domain.com -Destination "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA" 

        Will return an object containing all file groups and their contained files for every database on the sql2016 SQL Server instance
    .EXAMPLE
        $Credential = Get-Credential -UserName DOMAIN\User1 -Message  "Please enter your password:"
        Move-DBSystemDatabase -SqlInstance SQLSERVER001.domain.com -Destination D:\SQLSystem -Credential $Credential
    #>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    param (

        [parameter(ValueFromPipeline)]
        [DbaInstanceParameter]$SqlInstance,
        [System.IO.FileInfo]$Destination,
        [PSCredential]$Credential
    )

    $ComputerNetworkName = Resolve-DbaNetworkName -ComputerName $SqlInstance.ComputerName -Credential $Credential

    # GET DATABASE FILE DETAILS
    $DBFiles = Get-DbaDbFile -SqlInstance $SqlInstance -Database model  -SqlCredential $Credential
    $model_data = $DBFiles | Where-Object {$_.TypeDescription -eq 'ROWS'}
    $model_log = $DBFiles | Where-Object {$_.TypeDescription -eq 'LOG'}

    $DBFiles = Get-DbaDbFile -SqlInstance $SqlInstance -Database master   -SqlCredential $Credential
    $master_data = $DBFiles | Where-Object {$_.TypeDescription -eq 'ROWS'}
    $master_log = $DBFiles | Where-Object {$_.TypeDescription -eq 'LOG'}

    $DBFiles = Get-DbaDbFile -SqlInstance $SqlInstance -Database msdb   -SqlCredential $Credential
    $msdb_data = $DBFiles | Where-Object {$_.TypeDescription -eq 'ROWS'}
    $msdb_log = $DBFiles | Where-Object {$_.TypeDescription -eq 'LOG'}


    # Get the source path of the system database files
    $SourcePath = Split-Path $model_data.PhysicalName 


    # Set the new path for each system database file
    $model_data_new = $model_data.PhysicalName.replace($SourcePath , $Destination.FullName)
    $model_log_new = $model_log.PhysicalName.replace($SourcePath , $Destination.FullName)

    $master_data_new = $master_data.PhysicalName.replace($SourcePath , $Destination.FullName)
    $master_log_new = $master_log.PhysicalName.replace($SourcePath , $Destination.FullName)

    $msdb_data_new = $msdb_data.PhysicalName.replace($SourcePath , $Destination.FullName)
    $msdb_log_new = $msdb_log.PhysicalName.replace($SourcePath , $Destination.FullName)


    # Check if the destination folder exists
    try{
        $scriptBlock = {
            $path = $args[0]
            Test-Path -Path $path -PathType Container -Credential $Credential
        }

        if(Invoke-Command -ComputerName $ComputerNetworkName.FQDN -ScriptBlock $scriptBlock -ArgumentList $Destination.FullName -Credential $Credential){
            Write-Host "Confirmed path " $Destination " exists on " $SqlInstance.SqlFullName -ForegroundColor Green}
        else{
            Write-Host "Path " $Destination " does not exists on " $SqlInstance.SqlFullName -ForegroundColor Red
            Exit 1}
    }
    catch{
        Write-Host "Path " $Destination " does not exists on " $SqlInstance.SqlFullName -ForegroundColor Red
        Exit 1
    }

    # test destination already files exists
    $scriptTestDest = {
        $MachineName = $args[0]
        $Path = $args[1]

        if(Test-Path -Path $path -PathType Leaf -Credential $Credential){
            $Message = "Error: File {0} already exists on {1}" -f $Path,$MachineName 
            Write-Host $Message -ForegroundColor Red -ErrorAction Stop
            throw $Message
        }
    }

    try{
        Invoke-Command -ComputerName $ComputerNetworkName.FQDN -ScriptBlock $scriptTestDest -ArgumentList $SqlInstance.ComputerName,$model_data_new -Credential $Credential
        Invoke-Command -ComputerName $ComputerNetworkName.FQDN -ScriptBlock $scriptTestDest -ArgumentList $SqlInstance.ComputerName,$model_log_new  -Credential $Credential
        Invoke-Command -ComputerName $ComputerNetworkName.FQDN -ScriptBlock $scriptTestDest -ArgumentList $SqlInstance.ComputerName,$master_data_new -Credential $Credential
        Invoke-Command -ComputerName $ComputerNetworkName.FQDN -ScriptBlock $scriptTestDest -ArgumentList $SqlInstance.ComputerName,$master_log_new -Credential $Credential
        Invoke-Command -ComputerName $ComputerNetworkName.FQDN -ScriptBlock $scriptTestDest -ArgumentList $SqlInstance.ComputerName,$msdb_data_new -Credential $Credential
        Invoke-Command -ComputerName $ComputerNetworkName.FQDN -ScriptBlock $scriptTestDest -ArgumentList $SqlInstance.ComputerName,$msdb_log_new -Credential $Credential
        }
    catch{
        exit 1
    }


    # RUN THE ALTER DATABSES COMMAND FOR EACH FILE
    $command = {
        $SqlInstance = $args[0]
        $Query = $args[1]

        if ($PSCmdlet.ShouldProcess($SqlInstance,$Query)){
            Write-Host "Running " $Query  -ForegroundColor Green
            Invoke-DbaQuery -SqlInstance $SqlInstance -Query $Query #-SqlCredential  $Credential
        }
    }

    # Run the alter database command on each database
    $Query = "ALTER DATABASE {0} MODIFY FILE ( NAME = {1}  , FILENAME = '{2}' );" -f $model_data.Database,$model_data.LogicalName, $model_data_new
    Invoke-Command  -ScriptBlock $command -ArgumentList $SqlInstance,$Query -Credential $Credential
    $Query = "ALTER DATABASE {0} MODIFY FILE ( NAME = {1}  , FILENAME = '{2}' );" -f $model_log.Database,$model_log.LogicalName, $model_log_new
    Invoke-Command  -ScriptBlock $command -ArgumentList $SqlInstance,$Query -Credential $Credential
    #$Query = "ALTER DATABASE {0} MODIFY FILE ( NAME = {1}  , FILENAME = '{2}' );" -f $master_data.Database,$master_data.LogicalName, $master_data_new
    #Invoke-Command  -ScriptBlock $command -ArgumentList $SqlInstance,$Query
    #$Query = "ALTER DATABASE {0} MODIFY FILE ( NAME = {1}  , FILENAME = '{2}' );" -f $master_log.Database,$master_log.LogicalName, $master_log_new
    #Invoke-Command  -ScriptBlock $command -ArgumentList $SqlInstance,$Query
    $Query = "ALTER DATABASE {0} MODIFY FILE ( NAME = {1}  , FILENAME = '{2}' );" -f $msdb_data.Database,$msdb_data.LogicalName, $msdb_data_new
    Invoke-Command  -ScriptBlock $command -ArgumentList $SqlInstance,$Query -Credential $Credential
    $Query = "ALTER DATABASE {0} MODIFY FILE ( NAME = {1}  , FILENAME = '{2}' );" -f $msdb_log.Database,$msdb_log.LogicalName, $msdb_log_new
    Invoke-Command  -ScriptBlock $command -ArgumentList $SqlInstance,$Query -Credential $Credential


    

    Write-Host "Stopping SQL Server...."  -ForegroundColor Green
    # STOP SQL SERVER
    try {
        if ($PSCmdlet.ShouldProcess($SqlInstance,"Stop SQL Server")){
            Write-Host "Stopping"
            Invoke-Command -ComputerName $ComputerNetworkName.FQDN -ScriptBlock {Stop-Service -Name $Using:SqlInstance.InstanceName -Force} -Credential $Credential
        }
    }
    catch {

        do{
            $ans = Read-Host 'Unable to stop instance, confirm stopped manually? (Y/N)'
            if($ans -eq 'N'){ 
                Exit 1 
            }
        }
        until($ans -eq 'Y')
    }


    Write-Host "Moving system database files...."  -ForegroundColor Green

    $scriptBlock = {
        $SourcePath = $args[0] 
        $destination = $args[1]

        Get-Acl -Path  $SourcePath | Set-Acl $destination 
        Copy-Item -Path ($SourcePath + "\*") -Destination $destination -ErrorAction Stop
  
    }

    if ($PSCmdlet.ShouldProcess($SqlInstance,"Copy files")){
        Write-Host "Copying files from " $SourcePath " to " $Destination.FullName -ForegroundColor Green
        Invoke-Command -ComputerName $SqlInstance.ComputerName -ScriptBlock $scriptBlock -ArgumentList $SourcePath, $Destination.FullName  -Credential $Credential
    }



    Write-Host "SQL Startup options must be updated manually to move the master database - see " -NoNewline -ForegroundColor Yellow
    Write-Host "https://learn.microsoft.com/en-us/sql/relational-databases/databases/move-system-databases?view=sql-server-ver16" -ForegroundColor Yellow
    Write-Host "Please replace the -d and -l startup parameters as follows:" -ForegroundColor Yellow
    Write-Host "-d$master_data_new" -ForegroundColor Cyan
    Write-Host "-l$master_log_new" -ForegroundColor Cyan

    do{
        $ans = Read-Host 'Confirm startup options update before starting SQL Server (Y/N)'
        if($ans -eq 'N'){ 
            exit 
        }
    }
    until($ans -eq 'Y')

    
   
    $scriptBlock = {
        $SqlInstance = $args[0] 

        Start-Service -Name $SqlInstance -Verbose  -Credential $Credential
        Get-Service -Name $SqlInstance -DependentServices | Start-Service -Verbose
    }

    # START SQL SERVER
    if ($PSCmdlet.ShouldProcess($SqlInstance,"Start SQL Server")){
        Write-Host "Sarting " $SqlInstance.SqlFullName -ForegroundColor Green
        Invoke-Command -ComputerName $ComputerNetworkName.FQDN -ScriptBlock $scriptBlock -ArgumentList $SqlInstance.InstanceName -Credential $Credential
    }

    Write-Host "Move complete - remove old source database files manually - see " -NoNewline -ForegroundColor Green
    Write-Host "https://learn.microsoft.com/en-us/sql/relational-databases/databases/move-system-databases?view=sql-server-ver16" -ForegroundColor Green

}