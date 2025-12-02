# RDSMCP Troubleshooting Guide

## Installation Issues

### Step 1: Python Installation

**Issue: "python is not recognized as a cmdlet"**

**Cause:** Python is not installed or not added to PATH

**Solution:**
1. Download Python from: https://www.python.org/downloads/
2. Run the installer
3. **IMPORTANT**: Check the box "Add Python to PATH" during installation
4. Click "Install Now"
5. Close and reopen PowerShell

**Verify:**
```powershell
python --version
```

**Alternative Fix (if already installed):**

If Python is installed but not in PATH (e.g., at `C:\Users\Administrator\AppData\Local\Programs\Python\Python313`):

**Option 1: Quick Fix (Current session only)**
```powershell
$env:Path += ";C:\Users\Administrator\AppData\Local\Programs\Python\Python313;C:\Users\Administrator\AppData\Local\Programs\Python\Python313\Scripts"
python --version
```

**Option 2: Permanent Fix**
1. Press `Windows Key + R`
2. Type `sysdm.cpl` and press Enter
3. Click "Advanced" tab → "Environment Variables"
4. Under "System variables", find "Path" → Click "Edit"
5. Click "New" and add:
   - `C:\Users\Administrator\AppData\Local\Programs\Python\Python313`
   - `C:\Users\Administrator\AppData\Local\Programs\Python\Python313\Scripts`
6. Click OK on all windows
7. Close and reopen PowerShell

**Note:** Replace `Python313` with your actual Python folder name

---

### Step 2: Git Installation

**Issue: "git is not recognized as a cmdlet"**

**Cause:** Git is not installed

**Solution:**
1. Download Git from: https://git-scm.com/download/win
2. Run the installer
3. Use default settings (click "Next" through all options)
4. Close and reopen PowerShell

**Verify:**
```powershell
git --version
```

---

### Step 2: Clone Repository

**Issue: PowerShell shows error when cloning**

**Example:**
```
git : Cloning into 'RDSMCP'...
At line:1 char:1
+ git clone https://github.com/bobtherdsman/RDSMCP.git
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (Cloning into 'RDSMCP'...:String) [], RemoteException
```

**Cause:** PowerShell displays git's stderr output as an error (this is normal)

**Solution:** This is actually a success! The message "Cloning into 'RDSMCP'..." means it worked.

**Verify:**
```powershell
dir RDSMCP
```

---

**Issue: "Cannot find path 'C:\RDSMCP' because it does not exist"**

**Cause:** Repository was cloned to a different directory than expected

**Solution:**
1. Find where the repository was cloned:
   ```powershell
   pwd
   dir
   ```
2. Either:
   - Navigate to that directory: `cd path\to\RDSMCP`
   - Or move the folder to C:\: Move the RDSMCP folder to `C:\RDSMCP`

---

### Step 4: Activate Virtual Environment

**Issue: Execution policy error when activating venv**

**Example:**
```
venv\Scripts\activate : File C:\RDSMCP\venv\Scripts\Activate.ps1 cannot be loaded because running scripts is disabled on this system.
```

**Cause:** PowerShell execution policy is too restrictive

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
venv\Scripts\activate
```

**Verify:** Your prompt should show `(venv)` at the beginning:
```
(venv) C:\RDSMCP>
```

---

### Step 5: Install Dependencies

**Issue: "pip is not recognized"**

**Cause:** Virtual environment is not activated

**Solution:**
```powershell
venv\Scripts\activate
pip install -r requirements.txt
```

---

**Issue: Package installation fails**

**Cause:** Network issues or missing dependencies

**Solution:**
1. Check internet connection
2. Try upgrading pip first:
   ```powershell
   python -m pip install --upgrade pip
   pip install -r requirements.txt
   ```

---

### Step 6: Test CLI

**Issue: "No module named..."**

**Cause:** Dependencies didn't install properly

**Solution:**
```powershell
pip install -r requirements.txt
```

---

**Issue: "python: can't open file 'cli.py'"**

**Cause:** Not in the RDSMCP directory

**Solution:**
```powershell
cd C:\RDSMCP
python cli.py --help
```

---

## Usage Issues

### Recommend Command

**Issue: "No such option: --edition"**

**Cause:** README has incorrect parameters

**Correct Usage:**
```powershell
python cli.py recommend --cpu 16 --memory 64 --storage 500
```

**Not:**
```powershell
python cli.py recommend --cpu 16 --memory 64 --edition SE --version 15
```

**Available Options:**
- `--cpu INTEGER` - Number of CPUs (required)
- `--memory FLOAT` - Memory in GB (required)
- `--storage FLOAT` - Storage in GB (required)

---

## ODBC Driver Issues

### Installation

**Issue: ODBC Driver not installed**

**Solution:**
1. Download ODBC Driver 17 or 18 from: https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server
2. Run installer and follow prompts
3. Restart PowerShell

**Note:** The tool automatically detects and uses the installed ODBC driver. It supports:
- ODBC Driver 18 for SQL Server (preferred)
- ODBC Driver 17 for SQL Server
- ODBC Driver 13 for SQL Server
- ODBC Driver 11 for SQL Server
- SQL Server Native Client 11.0
- SQL Server (legacy)

You don't need a specific version - the tool will use whichever is installed.

**Verify:**
Check installed ODBC drivers in Windows:
1. Press `Windows Key + R`
2. Type `odbcad32` and press Enter
3. Go to "Drivers" tab
4. Look for any "ODBC Driver XX for SQL Server" or "SQL Server Native Client"

**Check via PowerShell:**
```powershell
Get-OdbcDriver | Where-Object {$_.Name -like "*SQL Server*"}
```

---

### Connection Issues

**Issue: "Data source name not found and no default driver specified"**

**Cause:** No ODBC driver for SQL Server is installed

**Solution:**
1. Install ODBC Driver 17 or 18 (see Installation section above)
2. The tool will automatically detect and use it

**Alternative:** If you have an older driver installed, verify it's detected:
```powershell
python -c "import pyodbc; print([d for d in pyodbc.drivers() if 'SQL Server' in d])"
```

If this shows an empty list, you need to install an ODBC driver.

---

**Issue: "Login failed for user"**

**Cause:** Incorrect credentials or permissions

**Solution:**
1. Verify SQL Server credentials
2. Check user has required permissions:
   - VIEW SERVER STATE
   - VIEW ANY DEFINITION
   - Access to master, msdb databases

---

**Issue: Windows Authentication not working**

**Cause:** Requires domain/local Windows authentication

**Solution:**
- Ensure you're running PowerShell as the correct Windows user
- Use `--windows-auth` flag (no username/password needed)
- Verify the Windows user has SQL Server access

---

## General Tips

1. **Always activate virtual environment** before running commands:
   ```powershell
   cd C:\RDSMCP
   venv\Scripts\activate
   ```

2. **Check you're in the right directory:**
   ```powershell
   pwd
   ```
   Should show: `C:\RDSMCP`

3. **Verify installation:**
   ```powershell
   python cli.py --help
   ```

4. **Test without SQL Server connection:**
   ```powershell
   python cli.py recommend --cpu 16 --memory 64 --storage 500
   ```
