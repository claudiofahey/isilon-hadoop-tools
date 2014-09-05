#!/usr/bin/perl

# Remove mounts from fstab
system("egrep -v '/mnt/scsi-|/data/' /etc/fstab > /tmp/fstab ; cp /tmp/fstab /etc/fstab") && die;

# Unmount from /mnt/scsi-*
@mounts = `ls -d /mnt/scsi-*`;
foreach my $mount (@mounts)
	{
	chomp($mount);
	system("umount $mount");
	system("rmdir $mount") && die;
	}

system("mkdir -p /data");

# Get list of disk partitions to mount
@disks = `ls /dev/sd?1 | grep -v /dev/sda1 | sort`;
my $data_number = 1;
foreach my $disk (@disks)
	{
	chomp($disk);
	$mount = "/data/$data_number";
	if (-l $mount)
	    {
	    # Remove symlink
	    system("rm $mount");
	    }
    if (! -d $mount)
        {
	    system("mkdir /data/$data_number") && die;
	    }
	system("echo $disk\t$mount\text4\tdefaults,noatime\t0\t0 >> /etc/fstab") && die;
	system("mount $mount");
	$data_number++;
	}

system("mount | grep /data/");

