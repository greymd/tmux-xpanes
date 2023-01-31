# How to maintain test cases

1. Please make sure that GNU sed and [pict](https://github.com/microsoft/pict) are installed.

Example: 
```bash
$ git clone https://github.com/Microsoft/pict.git
$ cd pict/
#### Install Clang and libc++ on Ubuntu if necesarry
$ sudo apt-get install clang libc++-dev
$ make
$ sudo install -m 0755 pict /usr/local/bin/pict
```

2. Edit `config.pict` to add/remove/modify software versions.

3. Run `bash ./update_yaml.sh`
