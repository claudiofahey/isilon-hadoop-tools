#!/usr/bin/python
# Written by Claudio Fahey (claudio.fahey@emc.com)

import os
import multiprocessing
import sys
import getopt
import shutil
import functools
import socket

def fill_disk_disk(config):
    tmpfile = os.path.join(config['disk'], 'filldisk.dat')
    cmd = 'dd if=/dev/zero of=' + tmpfile + ' bs=1M ; rm -f ' + tmpfile
    print(socket.gethostname() + ': ' + config['disk'] + ': # ' + cmd)
    os.system(cmd)
    print(socket.gethostname() + ': ' + config['disk'] + ': Done.')

def fill_disk_host(config):
    mountdir = '/data/'
    disks = [os.path.join(mountdir,f) for f in os.listdir(mountdir)]
    configs = [dict(config.items() + {'disk': disk}.items()) for disk in disks]

    pool = multiprocessing.Pool(len(configs))
    pool.map_async(fill_disk_disk, configs)    
    pool.close()
    pool.join()
    print(socket.gethostname() + ': All disks complete.')

def fill_disk_remote_host(config):
    cmd = 'ssh root@' + config['host_name'] + ' ' + config['fill_disk_script_path'] + ' --host'
    print('# ' + cmd)
    os.system(cmd)

def fill_disk_all_hosts(config):
    with open(config['host_file']) as f:
        host_names = f.read().splitlines()
    configs = [dict(config.items() + {'host_name': h}.items()) for h in host_names]
    
    pool = multiprocessing.Pool(len(configs))
    pool.map_async(fill_disk_remote_host, configs)    
    pool.close()
    pool.join()
    print('All hosts complete.')
    
def main():
    mode = sys.argv[1]
    if mode == '--host':
        fill_disk_host({})
    else:
        host_file = sys.argv[1]
        fill_disk_script_path = os.path.realpath(__file__)
        fill_disk_all_hosts({'host_file': host_file, 'fill_disk_script_path': fill_disk_script_path})
    
if __name__ == '__main__':
    main()

