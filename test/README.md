# How to maintain test cases

1. to test, please make sure that GNU sed, [pict](https://github.com/microsoft/pict) and [shunit2](https://github.com/kward/shunit2.git) are installed.

Example for pict: 
```bash
$ git clone https://github.com/Microsoft/pict.git
$ cd pict/
#### Install Clang and libc++ on Ubuntu if necessary
$ sudo apt-get install clang libc++-dev
$ make
$ sudo install -m 0755 pict /usr/local/bin/pict
```

Example for shunit2: 
```bash
$ cd /path_to_xpanes_project/test/
$ git submodule init
$ git submodule update
# => https://github.com/kward/shunit2.git is cloned into /path_to_xpanes_project/test/shunit2 directory
```

3. Edit `config.pict` to add/remove/modify software versions.

4. Run `bash ./update_yaml.sh`

