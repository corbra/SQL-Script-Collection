## SQL Script Collection 
    
### Move-DBSystemDatabase

Move System database files to a new location.  Attempls to automate the process found [here](https://learn.microsoft.com/en-us/sql/relational-databases/databases/move-system-databases?view=sql-server-ver16).

**WARNING** SQL Must be restarted during the process. Semi Automated Function!! Some prompted manual steps to configure the master database are necessary see Microsft Help on moving SQL system databases.

- **Notes**

    - If copy ACL fails remotely, run it manually on the server to copy the permissions from the source folder, for example:

        `Get-Acl -Path  "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\" | Set-Acl "D:\SQLSystem\"`

    - For the error below, usually this will NOT occur when the FQN is used.

        `WinRM cannot process the request. The following error occurred while using Kerberos authentication: Cannot find the computer. `

- **Prerequisits**
    -  [DBATOOLS](https://dbatools.io/download/) module.


