## PrimeApps Omnibus Package for Linux

You can easily install the PrimeApps Runtime (PRE) using this package.

### Setup
1. Download and extract the package
2. Set environment variables
3. Run install.sh

#### 1. Download and extract the package
```bash
curl http://file.primeapps.io/omnibus/linux.tar.gz &&
tar -xzvf linux.tar.gz
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
sudo ./install.sh
```
