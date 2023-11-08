# SQL Script Collection 
    
## <u>Move-DBSystemDatabase</u>

Move System database files to a new location.  Attempts to automate the process found [here](https://learn.microsoft.com/en-us/sql/relational-databases/databases/move-system-databases?view=sql-server-ver16).

**WARNING** SQL Must be restarted during the process. Semi Automated Function!! Some prompted manual steps to configure the master database are necessary see Microsoft Help on moving SQL system databases.

- **Notes**

    - If copy ACL fails remotely, run it manually on the server to copy the permissions from the source folder, for example:

        `Get-Acl -Path  "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\" | Set-Acl "D:\SQLSystem\"`

    - For the error below, usually this will NOT occur when the FQN is used.

        `WinRM cannot process the request. The following error occurred while using Kerberos authentication: Cannot find the computer. `



## <u>Get-SQLEngineServiceAccounts</u>

Retrieve the SQL Server Engine service account.  The AD object used for SQL to access resources is returned.  See [here](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/configure-windows-service-accounts-and-permissions?view=sql-server-ver16).

## <u>New-SQLShare</u>

Create a local SMB share and setup access for SQL.  This is useful for taking remote backups.  


## <u>Prerequisites</u>

[DBATOOLS](https://dbatools.io/download/) module.