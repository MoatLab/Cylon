# Run Experiments

## Redis

1. Install java
    ```bash
    sudo apt install openjdk-21-jdk
    ```

2. Install maven
    ```bash
        sudo apt install maven -y
    ```

3. Set Up YCSB

Git clone YCSB and compile:
```bash
git clone http://github.com/brianfrankcooper/YCSB.git
cd YCSB
mvn -pl site.ycsb:redis-binding -am clean package
```

4. Extract redis in `YCSB/redis/target/ycsb-redis-binding-0.18.0-SNAPSHOT.tar.gz`.
```bash
    tar xvf ycsb-redis-binding-0.18.0-SNAPSHOT.tar.gz
```

5. Install necessary dependencies for redis
```bash
    sudo apt-get update
    sudo apt-get install -y sudo
    sudo apt-get install -y --no-install-recommends ca-certificates wget dpkg-dev gcc g++ libc6-dev libssl-dev make git cmake python3 python3-pip python3-venv python3-dev unzip rsync clang automake autoconf libtool
```

6. After that, download the redis-8.0.0
```bash
    wget -O redis-8.0.0.tar.gz https://github.com/redis/redis/archive/refs/tags/8.0.0.tar.gz
    tar xvf redis-8.0.0.tar.gz
```

7. Build redis
```bash
    cd redis-8.0.0
    export BUILD_TLS=yes BUILD_WITH_MODULES=yes INSTALL_RUST_TOOLCHAIN=yes DISABLE_WERRORS=yes
    make -j "$(nproc)" all
```

8. Check the version of redis by doing:
    ```bash
   cd src
   ./redis-server --version
    ```
    It should outputed like this
    ```
    Redis server v=8.0.0 sha=00000000:1 malloc=jemalloc-5.3.0 bits=64 build=5468a126d23b4509
    ```
9. Install latest perf
First we need to install the dependencies
```bash
sudo apt install -y libelf-dev libdw-dev libnuma-dev
```
next we need to install `libtraceevent` from source
```bash
git clone https://github.com/rostedt/libtraceevent.git
cd libtraceevent
make
sudo make install
```
Then install latest perf using
```bash
cd ~
git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux/tools/perf
make
```

9. To run redis experiments, first inside the `redis2.conf` change the pidfile, logfile, and dir to your own path

10. Install python and seamlink it to python
```bash
which python3
sudo ln -s /usr/bin/python3 /usr/local/bin/python
python --version
```

11. Install gnuplot
```bash
sudo apt install gnuplot
```

12. Change all the path in the script inside 'benchmark.sh`, `run_proces.sh`, `run-fix-simple.sh`, and `run_and_plot.sh` to your own path

13. Run it with
```bash
ENABLE_TCMALLOC=0 RUN_TAG=cylon-1t ./run_and_plot.sh
```

14. Check the graph result inside `../plots/.`

