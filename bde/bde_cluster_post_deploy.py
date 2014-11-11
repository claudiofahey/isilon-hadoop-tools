#!/usr/bin/env python
# Perform post-processing after VMware Big Data Extensions provisions a new cluster.
# Written by Claudio Fahey (claudio.fahey@emc.com)

import subprocess
import sys
import os
import multiprocessing
import sys
import getopt
import shutil
import functools
import subprocess
import shutil
import glob
import json
import uuid
import datetime
import cookielib
import urllib2
import urllib
import re
import tempfile

def die(error_message='died'):
    raise Exception(error_message)

def system_command(cmd, print_output=False):
    print('# ' + cmd)
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, errors = p.communicate()
    if print_output: print(output + errors)
    return p.returncode, output, errors

def system_command_required(cmd, print_output=True):
    returncode, output, errors = system_command(cmd, print_output=print_output)
    returncode == 0 or die();
    return returncode, output, errors

def load_json_from_file(filename):
    with open(filename) as data_file:
        data = json.load(data_file)
    return data

def serengeti_auth(serurl, username, password):
    cj = cookielib.CookieJar()
    opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cj))
    try:
        # First try using non-encoded username used by BDE 2.1
        data = urllib.urlencode({'j_username': username, 'j_password': password})
        r = opener.open(serurl + "/j_spring_security_check", data)
    except:
        # If that fails, use the base64 encoding of actual username used by BDE 2.0
        encoded_username = username.encode('base64').strip()
        data = urllib.urlencode({'j_username': encoded_username, 'j_password': password})
        r = opener.open(serurl + "/j_spring_security_check", data)
    return opener

def serengeti_api_read(serurl, urlsuffix, opener=None, data=None):
    url = serurl + '/api' + urlsuffix
    r = opener.open(url)
    return r.read()

def configure_ssh(host, username, password):
    # host can be IP, fqdn, or relative host name
    # Remove host from known_hosts file to avoid problems with IP address reuse
    orgfilename = os.path.expanduser('~/.ssh/known_hosts')
    if os.path.isfile(orgfilename):
        orgfile = open(orgfilename, 'r')
        newfilename = tempfile.mktemp()
        newfile = open(newfilename, 'w')
        for line in orgfile:
            if line.startswith(host + ' '):
                print('removing line ' + line)
                pass
            else:
                newfile.write(line)
        newfile.close()
        orgfile.close()
        os.rename(newfilename, orgfilename)    
    
    returncode, output, errors = system_command_required(
        'cat ~/.ssh/id_rsa.pub | sshpass -p ' + password + ' ssh -o StrictHostKeyChecking=no ' + username + '@' + host + 
        ' "mkdir -p .ssh ; chmod 700 .ssh ; chown -R ' + username + ':' + username + ' .ssh ; ' +
        'touch .ssh/authorized_keys ; chmod 600 .ssh/authorized_keys ; ' +
        'cat - >> .ssh/authorized_keys"')

    ssh_command(username, host, 'echo -n success: ; hostname')

def configure_network(node_name, ip, fqdn, username='root'):
    # Copy remote /etc/sysconfig/network to local file
    orgfilename = tempfile.mktemp()
    returncode, output, errors = system_command_required('scp ' + username + '@' + ip + ':/etc/sysconfig/network ' + orgfilename)
    
    # Generate new /etc/sysconfig/network file locally
    with open(orgfilename, 'r') as orgfile:
        newfilename = tempfile.mktemp()
        with open(newfilename, 'w') as newfile:
            newfile.write('DHCP_HOSTNAME=' + node_name + '\n')
            for line in orgfile:
                if line == '' or re.match('HOSTNAME=', line) or re.match('DHCP_HOSTNAME', line) or re.match('DOMAINNAME=', line):
                    pass
                else:
                    newfile.write(line)   
        
    # Copy new file to remote server
    returncode, output, errors = system_command_required('scp ' + newfilename + ' ' + username + '@' + ip + ':/etc/sysconfig/network')
    print(output + errors)
    returncode == 0 or die();

    os.remove(orgfilename)
    os.remove(newfilename)

    returncode, output, errors = ssh_command(username, ip, 'service network restart ; hostname ' + fqdn)

def get_fqdn(host, username='root'):
    returncode, output, errors = ssh_command(username, host, 'hostname')
    returncode == 0 or die()
    return output.strip()

def configure_nfs(node_name, host, mountpoint, nfs_path, config):
    returncode, output, errors = system_command(config['tools_root'] + '/bde/remote_mount_nfs.sh ' + host + ' ' + mountpoint + ' ' + nfs_path)
    print(output + errors)
    returncode == 0 or die();

def ssh_command(username, host, command):
    returncode, output, errors = system_command_required('ssh ' + username + '@' + host + ' "' + command + '"')
    return returncode, output, errors
    
def configure_node_phase_1(node, config, username='root', password='none'):
    configure_ssh(node['ip'], username, password)
    if not config.get('skip_configure_network',False):
        configure_network(node['node_name'], node['ip'], node['fqdn'], username)
    node['fqdn'] = get_fqdn(node['ip'], username)
    #configure_ssh(node['node_name'], username, password)
    configure_ssh(node['fqdn'], username, password)
    return node

def configure_node_phase_2(node, config, username='root', password='none'): 
    if not config.get('skip_phase_2',False):
        ssh_command(username, node['fqdn'], 'yum -y install ed nano mlocate zip unzip nfs-utils')
        map(lambda m: configure_nfs(node['node_name'], node['fqdn'], m['mount_point'], m['path'], config), config.get('nfs_mounts',[]))
        map(lambda cmd: ssh_command(username, node['fqdn'], cmd), config.get('ssh_commands',[]))
    return node
    
def main():
    print('bde_cluster_post_deploy.py\n')

    config_filename = sys.argv[1]
    config = load_json_from_file(config_filename)
    
    serurl = config['ser_host'] + '/serengeti'
    opener = serengeti_auth(serurl, config['ser_username'], config['ser_password'])

    cluster_data = json.loads(serengeti_api_read(serurl, '/cluster/' + config['cluster_name'], opener))
    print(json.dumps(cluster_data, sort_keys=True, indent=4, ensure_ascii=False))
    
    nodes = []
    for node_group in cluster_data['nodeGroups']:
        for instance in node_group['instances']:
            node_name = instance['name']
            if re.match(config.get('name_filter_regex',''), node_name) is None: continue
            nodes.append({
                'node_name': node_name,
                'ip': instance['ipConfigs']['MGT_NETWORK'][0]['ipAddress'],
                'fqdn': node_name + config['dhcp_domain']
                })

    nodes = map(lambda n: configure_node_phase_1(n, config, password=config['node_password']), nodes)
    nodes = map(lambda n: configure_node_phase_2(n, config, password=config['node_password']), nodes)

    with open(config['host_file_name'], 'w') as host_file:
        map(lambda n: host_file.write(n['fqdn'] + '\n'), nodes)
    
    print('Success!')

if __name__ == "__main__":
    main()

