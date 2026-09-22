/// What the stats, ps and OS-detection scripts print on real kinds of server.
///
/// Each follows the exact byte format of the tool that produced it —
/// procps, busybox, BSD/macOS — including the awkward cases: a mount point
/// with a space, `/proc/net/dev` with a counter glued to the interface name,
/// a kernel too old for `MemAvailable`, a router with no `/proc/net/dev`, a
/// login banner before the first marker.
library;

/// Ubuntu 24.04 on a small VPS, with Docker and snaps installed.
const ubuntuStats = '''
Welcome to Ubuntu 24.04.1 LTS (GNU/Linux 6.8.0-45-generic x86_64)
@@sshetu:uname
Linux
6.8.0-45-generic
@@sshetu:hostname
web-1
@@sshetu:osrelease
PRETTY_NAME="Ubuntu 24.04.1 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.1 LTS (Noble Numbat)"
ID=ubuntu
ID_LIKE=debian
@@sshetu:stat
cpu  10000 500 3000 80000 1500 0 200 0 0 0
cpu0 5000 250 1500 40000 750 0 100 0 0 0
cpu1 5000 250 1500 40000 750 0 100 0 0 0
@@sshetu:meminfo
MemTotal:        4015192 kB
MemFree:          312344 kB
MemAvailable:    2007596 kB
Buffers:          102400 kB
Cached:          1500000 kB
SwapCached:            0 kB
Active(anon):     900000 kB
SwapTotal:       2097148 kB
SwapFree:        1572860 kB
@@sshetu:loadavg
0.52 0.58 0.59 2/467 123456
@@sshetu:uptime
350000.25 690000.10
@@sshetu:df
Filesystem     1024-blocks     Used Available Capacity Mounted on
tmpfs               401520     1204    400316       1% /run
/dev/vda1         50620216 20248086  30372130      40% /
tmpfs              2007596        0   2007596       0% /dev/shm
/dev/vda15          106858     6186    100672       6% /boot/efi
/dev/loop0           65536    65536         0     100% /snap/core22/1612
/dev/vdb1        103081248 92773123   5065580      95% /mnt/backup disk
overlay           50620216 20248086  30372130      40% /var/lib/docker/overlay2/abc/merged
tmpfs               401516        4    401512       1% /run/user/1000
@@sshetu:netdev
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 1000000    5000    0    0    0     0          0         0  1000000    5000    0    0    0     0       0          0
  eth0: 5000000   40000    0    0    0     0          0         0  2000000   30000    0    0    0     0       0          0
docker0:  700000    3000    0    0    0     0          0         0   800000    3000    0    0    0     0       0          0
veth12ab: 700000    3000    0    0    0     0          0         0   800000    3000    0    0    0     0       0          0
@@sshetu:end
''';

/// The same Ubuntu machine three seconds later: 500 more jiffies, 300 of them
/// idle (40% busy); 300 kB in and 30 kB out on eth0 over 3 s of uptime.
/// Loopback moved a lot, and must not count.
final ubuntuStatsLater = ubuntuStats
    .replaceFirst(
      'cpu  10000 500 3000 80000 1500 0 200 0 0 0',
      'cpu  10150 500 3050 80280 1520 0 200 0 0 0',
    )
    .replaceFirst('350000.25 690000.10', '350003.25 690002.10')
    .replaceFirst('    lo: 1000000    5000', '    lo: 9000000    5000')
    .replaceFirst(
      '  eth0: 5000000   40000    0    0    0     0          0         0  2000000',
      '  eth0: 5300000   40000    0    0    0     0          0         0  2030000',
    );

/// Captured, not written: [statsScript] run with `sh -s` over a real
/// OpenSSH session to Arch Linux under WSL2 (hostname replaced). Windows
/// drives appear as `C:\` sources, and WSL mounts plenty of `none`.
const archWslStats = r'''
@@sshetu:uname
Linux
6.18.33.2-microsoft-standard-WSL2
@@sshetu:hostname
wsl-box
@@sshetu:osrelease
NAME="Arch Linux"
PRETTY_NAME="Arch Linux"
ID=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://archlinux.org/"
DOCUMENTATION_URL="https://wiki.archlinux.org/"
SUPPORT_URL="https://bbs.archlinux.org/"
BUG_REPORT_URL="https://gitlab.archlinux.org/groups/archlinux/-/issues"
PRIVACY_POLICY_URL="https://terms.archlinux.org/docs/privacy-policy/"
LOGO=archlinux-logo
@@sshetu:stat
cpu  2485045 72192 2920851 943258299 116432 0 1501052 0 0 0
cpu0 22618 1046 351651 29022323 6779 0 1406320 0 0 0
cpu1 19946 797 16052 29630840 9655 0 71734 0 0 0
cpu2 101684 2382 181671 29338134 8192 0 8404 0 0 0
cpu3 71430 3225 69290 29522446 3764 0 1984 0 0 0
cpu4 101837 2191 135071 29389804 10628 0 2324 0 0 0
cpu5 68697 2934 69246 29521141 4918 0 1099 0 0 0
cpu6 95536 2047 120875 29408177 12406 0 2284 0 0 0
cpu7 71748 1300 64769 29525032 5923 0 1229 0 0 0
cpu8 94005 3988 113503 29427400 7293 0 434 0 0 0
cpu9 65313 3441 69379 29527123 2024 0 326 0 0 0
cpu10 95740 2974 110263 29434354 4613 0 413 0 0 0
cpu11 66158 2359 71330 29523795 1714 0 272 0 0 0
cpu12 96138 3216 105843 29433777 3507 0 497 0 0 0
cpu13 59242 2026 63192 29542367 871 0 268 0 0 0
cpu14 93367 1891 103688 29444872 3266 0 339 0 0 0
cpu15 56720 1616 60192 29550352 860 0 236 0 0 0
cpu16 94947 3910 98350 29447552 2791 0 396 0 0 0
cpu17 63458 2630 56365 29545846 2364 0 235 0 0 0
cpu18 103576 2302 96871 29443834 2391 0 413 0 0 0
cpu19 66458 2523 56818 29545220 732 0 216 0 0 0
cpu20 102050 3397 97632 29443457 3265 0 424 0 0 0
cpu21 56402 3388 53729 29556499 1143 0 300 0 0 0
cpu22 105593 2148 97627 29441093 2782 0 501 0 0 0
cpu23 63603 2115 54112 29551525 937 0 240 0 0 0
cpu24 101286 2182 97595 29448235 2508 0 21 0 0 0
cpu25 63910 1506 53679 29553904 875 0 17 0 0 0
cpu26 104223 2090 98645 29445025 2516 0 28 0 0 0
cpu27 58127 1239 52130 29562801 1406 0 29 0 0 0
cpu28 108150 1441 101592 29442720 1418 0 19 0 0 0
cpu29 55142 1007 49002 29571089 726 0 14 0 0 0
cpu30 103569 2062 99437 29449120 2520 0 19 0 0 0
cpu31 54356 805 51239 29568427 1631 0 5 0 0 0
@@sshetu:meminfo
MemTotal:       32724672 kB
MemFree:        25393372 kB
MemAvailable:   29677948 kB
Buffers:          254308 kB
Cached:          1722820 kB
SwapCached:            0 kB
Active:           830348 kB
Inactive:        2502780 kB
Active(anon):       6248 kB
Inactive(anon):  1738508 kB
Active(file):     824100 kB
Inactive(file):   764272 kB
Unevictable:          64 kB
Mlocked:              64 kB
SwapTotal:       8388608 kB
SwapFree:        8388608 kB
Dirty:              1364 kB
Writeback:             0 kB
AnonPages:       1355976 kB
Mapped:           405912 kB
Shmem:            388888 kB
KReclaimable:    3074684 kB
Slab:            3473156 kB
SReclaimable:    3074684 kB
SUnreclaim:       398472 kB
KernelStack:       12960 kB
PageTables:        22476 kB
SecPageTables:         0 kB
NFS_Unstable:          0 kB
Bounce:                0 kB
WritebackTmp:          0 kB
CommitLimit:    24750944 kB
Committed_AS:    2918896 kB
VmallocTotal:   34359738367 kB
VmallocUsed:       46828 kB
VmallocChunk:          0 kB
Percpu:            13056 kB
HardwareCorrupted:     0 kB
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
ShmemPmdMapped:        0 kB
FileHugePages:     20480 kB
FilePmdMapped:         0 kB
Unaccepted:            0 kB
Balloon:               0 kB
HugePages_Total:       0
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
Hugetlb:               0 kB
DirectMap4k:       54272 kB
DirectMap2M:     7145472 kB
DirectMap1G:    34603008 kB
@@sshetu:loadavg
0.33 0.38 0.42 2/780 3413756
@@sshetu:uptime
296941.07 9432583.06
@@sshetu:df
Filesystem     1024-blocks      Used Available Capacity Mounted on
none              16362336         0  16362336       0% /usr/lib/modules/6.18.33.2-microsoft-standard-WSL2
none              16362336         4  16362332       1% /mnt/wsl
drivers          997872636 955400664  42471972      96% /usr/lib/wsl/drivers
/dev/sdd        1055762868 105479624 896579772      11% /
none              16362336        60  16362276       1% /mnt/wslg
none              16362336         0  16362336       0% /usr/lib/wsl/lib
rootfs            16356576      2772  16353804       1% /init
none              16356576         0  16356576       0% /dev
none              16362336       584  16361752       1% /run
none              16362336         0  16362336       0% /run/lock
none              16362336         0  16362336       0% /run/shm
none              16362336        80  16362256       1% /mnt/wslg/versions.txt
none              16362336        80  16362256       1% /mnt/wslg/doc
C:\              997872636 955400664  42471972      96% /mnt/c
F:\              976744444 291854364 684890080      30% /mnt/f
tmpfs             16362336    385240  15977096       3% /tmp
none                  1024         0      1024       0% /run/credentials/systemd-journald.service
none                  1024         0      1024       0% /run/credentials/systemd-resolved.service
none                  1024         0      1024       0% /run/credentials/systemd-networkd.service
tmpfs              3272464         0   3272464       0% /run/user/1000
@@sshetu:netdev
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 1388995593  313598    0    0    0     0          0         0 1388995593  313598    0    0    0     0       0          0
  eth0: 199943738  391479    0    0    0     0          0       443 388794562  188645    0    0    0     0       0          0
@@sshetu:end
''';

/// Alpine in a container: busybox df, an older kernel with no MemAvailable,
/// no swap, overlay as `/`.
const alpineStats = '''
@@sshetu:uname
Linux
4.9.337
@@sshetu:hostname
alpine-box
@@sshetu:osrelease
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.20.3
PRETTY_NAME="Alpine Linux v3.20"
HOME_URL="https://alpinelinux.org/"
@@sshetu:stat
cpu  2255 34 2290 22625563 6290 127 456 0 0 0
cpu0 1132 34 1441 11311718 3675 127 438 0 0 0
@@sshetu:meminfo
MemTotal:        1017236 kB
MemFree:          500000 kB
Buffers:           20000 kB
Cached:           180000 kB
SReclaimable:      10000 kB
SwapTotal:             0 kB
SwapFree:              0 kB
@@sshetu:loadavg
0.00 0.01 0.05 1/78 4321
@@sshetu:uptime
86461.00 86000.00
@@sshetu:df
Filesystem           1024-blocks    Used Available Capacity Mounted on
overlay               61255492  9870124  48243000  17% /
tmpfs                    65536        0     65536   0% /dev
shm                      65536        0     65536   0% /dev/shm
/dev/sda1             61255492  9870124  48243000  17% /etc/hosts
@@sshetu:netdev
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo:       0       0    0    0    0     0          0         0        0       0    0    0    0     0       0          0
  eth0:4294967000   9000    0    0    0     0          0         0  1200000    8000    0    0    0     0       0          0
@@sshetu:end
''';

/// A MacBook: no /proc, sysctl + vm_stat + sw_vers, autofs and system
/// sub-volumes in df.
const macStats = '''
@@sshetu:uname
Darwin
23.5.0
@@sshetu:hostname
Studio.local
@@sshetu:osrelease
@@sshetu:stat
@@sshetu:meminfo
@@sshetu:loadavg
@@sshetu:uptime
@@sshetu:df
Filesystem     1024-blocks      Used Available Capacity  Mounted on
/dev/disk3s1s1   971350180  10523452 545123456     2%    /
devfs                  201       201         0   100%    /dev
/dev/disk3s6     971350180   2097172 545123456     1%    /System/Volumes/VM
/dev/disk3s2     971350180   6291780 545123456     2%    /System/Volumes/Preboot
/dev/disk3s5     971350180 400000000 545123456    43%    /System/Volumes/Data
map auto_home            0         0         0   100%    /System/Volumes/Data/home
/dev/disk5s1       1000000    500000    500000    50%    /Volumes/My Passport
@@sshetu:netdev
@@sshetu:sysctl
hw.ncpu: 10
hw.memsize: 17179869184
hw.physmem: 2147483648
vm.loadavg: { 1.52 1.63 1.70 }
kern.boottime: { sec = 1700000000, usec = 123456 } Tue Nov 14 22:13:20 2023
vm.swapusage: total = 2048.00M  used = 512.00M  free = 1536.00M  (encrypted)
@@sshetu:vmstat
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                                3276.
Pages active:                            300000.
Pages inactive:                          290000.
Pages speculative:                         5000.
Pages throttled:                              0.
Pages wired down:                        100000.
Pages purgeable:                           2000.
"Translation faults":                 123456789.
Pages occupied by compressor:             50000.
@@sshetu:swvers
ProductName:		macOS
ProductVersion:		14.5
BuildVersion:		23F79
@@sshetu:now
1700086400
@@sshetu:end
''';

/// A consumer router on an old kernel: busybox everything, no hostname
/// binary, no `/proc/net/dev` (a stripped kernel), no `-P` for df.
const routerStats = '''
@@sshetu:uname
Linux
2.6.36.4brcmarm
@@sshetu:hostname
RT-AC68U
@@sshetu:osrelease
@@sshetu:stat
cpu  123456 0 65432 9876543 0 1234 4321 0
cpu0 61728 0 32716 4938271 0 617 2160 0
cpu1 61728 0 32716 4938272 0 617 2161 0
@@sshetu:meminfo
MemTotal:         255504 kB
MemFree:           90000 kB
Buffers:           10000 kB
Cached:            40000 kB
SwapTotal:             0 kB
SwapFree:              0 kB
@@sshetu:loadavg
1.12 1.05 1.01 1/61 1523
@@sshetu:uptime
1234567.89 2000000.00
@@sshetu:df
@@sshetu:netdev
@@sshetu:end
''';

/// A Windows OpenSSH server: no `sh`, so the script produced nothing.
const windowsStats = '';

/// procps `ps -eo pid,user,pcpu,pmem,etime,comm --sort=-pcpu`.
const psProcps = '''
@@sshetu:ps
    PID USER     %CPU %MEM     ELAPSED COMMAND
   1234 www-data 12.5  3.2    02:13:44 nginx
    987 postgres  4.0 10.1 12-03:14:15 postgres
      1 root      0.0  0.3 30-00:00:01 systemd
   2345 ubuntu    0.5  0.1       00:42 kworker/0:1 H
''';

/// macOS `ps -Aro pid,user,pcpu,pmem,etime,comm`.
const psMac = '''
@@sshetu:ps
  PID USER             %CPU %MEM     ELAPSED COMM
  402 me               23.1  2.4 01-02:03:04 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
  101 root              1,5  0,2    03:04:05 /usr/sbin/cfprefsd
''';

/// Busybox `ps`: no CPU or memory share at all.
const psBusybox = '''
@@sshetu:ps
PID   USER     TIME  COMMAND
    1 root      0:03 /sbin/init
  512 admin     0:00 dropbear -p 22
  777 admin     1:20 [kworker/0:1]
''';

const osUbuntu = '''
@@sshetu:osrelease
PRETTY_NAME="Ubuntu 24.04.1 LTS"
NAME="Ubuntu"
ID=ubuntu
ID_LIKE=debian
@@sshetu:uname
Linux
@@sshetu:swvers
''';

const osMint = '''
@@sshetu:osrelease
NAME="Linux Mint"
PRETTY_NAME="Linux Mint 22"
ID=linuxmint
ID_LIKE="ubuntu debian"
@@sshetu:uname
Linux
@@sshetu:swvers
''';

const osRocky = '''
@@sshetu:osrelease
NAME="Rocky Linux"
ID="rocky"
ID_LIKE="rhel centos fedora"
PRETTY_NAME="Rocky Linux 9.4 (Blue Onyx)"
@@sshetu:uname
Linux
@@sshetu:swvers
''';

const osUnknownDistro = '''
@@sshetu:osrelease
NAME="Obscure OS"
ID=obscure
PRETTY_NAME="Obscure OS 1.0"
@@sshetu:uname
Linux
@@sshetu:swvers
''';

const osRouter = '''
@@sshetu:osrelease
@@sshetu:uname
Linux
@@sshetu:swvers
''';

const osMac = '''
@@sshetu:osrelease
@@sshetu:uname
Darwin
@@sshetu:swvers
ProductName:		macOS
ProductVersion:		14.5
BuildVersion:		23F79
''';

const osFreeBsd = '''
@@sshetu:osrelease
NAME=FreeBSD
VERSION="14.1-RELEASE"
ID=freebsd
PRETTY_NAME="FreeBSD 14.1-RELEASE"
@@sshetu:uname
FreeBSD
@@sshetu:swvers
''';

const windowsVer = '\r\nMicrosoft Windows [Version 10.0.22631.4169]\r\n';
