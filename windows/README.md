## PrimeApps Omnibus Package for Windows

You can easily install the PrimeApps Runtime (PRE) using this package.

### Prerequisites
* [ASP.NET Core Runtime 2.2](https://dotnet.microsoft.com/download/dotnet-core/2.2)
* Bash for Windows (Git Bash, Cygwin, Msys2, etc)
  * We recommend [Git Bash](https://github.com/git-for-windows/git/releases)
* [Microsoft Visual C++ Redistributable](https://support.microsoft.com/en-us/help/2977003/the-latest-supported-visual-c-downloads)

### Setup
1. Download and extract the package
2. Set environment variables
3. Run install.sh

#### 1. Download and extract the package
```bash
curl http://file.primeapps.io/omnibus/windows.zip -O &&
unzip windows.zip
```

Enter folder:
```bash
cd primeapps
```

#### 2. Set environment variables
Open .env file and set variables

```bash
nano .env
```

#### 3. Run install.sh
```bash
./install.sh
```
