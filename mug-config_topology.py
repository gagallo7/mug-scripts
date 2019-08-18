#!/usr/bin/python

import os
import commands
import re
import sys

PAD_CONFIG_DIRNAME = "pad_config"

# params:
# 1) NAME
# 2) WIDTH=$2
# 3) HEIGHT=$3
# 4) DEV=/dev/media0
# 5) PAD=0
# 7) CODE=RGB888_1X24
# 8) VERBOSE=
def change_sd_fmt(params, mdev):
    print "==========================================="
    print "%s, Pad %d" % (params['name'], params['pad'])
    print "==========================================="

    # Check field parameter
    field = params['field'] if 'field' in params else 'none'

    # Add quotes in the name
    name = "\'" + params['name'] + "\'"

    # Print the old format
    cmd = "%s media-ctl %s -d %s --get-v4l2 \"%s:%d\"" % (sudo, params['verbose'], mdev, name, params['pad'])
    print '>' + cmd
    os.system(cmd)

    # Set the new format
    cmd = "%s media-ctl %s -d %s -V \"%s:%s [fmt:%s/%dx%d field:%s]\"" % \
            (sudo, params['verbose'], mdev, name, params['pad'], params['code'], params['width'], params['height'], field)
    print '>' + cmd
    os.system(cmd)

    # Print the new format
    cmd = "%s media-ctl %s -d %s --get-v4l2 \"%s:%d\"" % (sudo, params['verbose'], mdev, name, params['pad'])
    print '>' + cmd
    output = commands.getstatusoutput(cmd)
    print output[1]
    if output[0] != 0:
        print ""
        print "ERR: Could not apply format"
        exit(-1)

    # Check if we could apply the format
    new_fmt = re.search(':(.*)/(.* field.*)]', output[1])
    print(new_fmt)
    cond1 = False
    cond2 = False
    if new_fmt:
        cond1 = new_fmt.group(1).strip() != str(params['code']).strip()
        cond2 = new_fmt.group(2).strip() != "%dx%d field:%s" % \
                (params['width'], params['height'], field)
    if not new_fmt or cond1 or cond2:

        print("condition 1 == {} -- condition 2 == {}".format(cond1, cond2))

        if new_fmt:
            print "{}>> !=\n{}<<".format(new_fmt.group(2), "%dx%d field:%s" % \
                                (params['width'], params['height'], field))
            print new_fmt.group(2)
        print params

        print ""
        print "ERR: Could not apply format"
        exit(-1)

# params
# 1) NAME
# 2) WIDTH=$2
# 3) HEIGHT=$3
# 4) VDEV=/dev/video0
# 5) FORMAT=SBGGR8
def change_vid_fmt(params):
    print "==========================================="
    print params['name']
    print "==========================================="

    # Check field parameter
    field = params['field'] if 'field' in params else 'none'

    # Print the old format
    cmd = 'yavta --enum-formats '+ params['dev']
    print '>' + cmd
    os.system(cmd)

    # Set the new format
    cmd = "yavta -f %s -s %dx%d --field %s %s" % (params['fmt'], params['width'], params['height'], field, params['dev'])
    print '>' + cmd
    output = commands.getstatusoutput(cmd)
    print output[1]
    if output[0] != 0:
        print ""
        print "ERR: Could not apply format"
        exit(-1)

    # Check if we could apply the format
    new_fmt = re.search('Video format: (.*?) .*? (.*?) ', output[1])
    print(new_fmt)
    if not new_fmt or \
        new_fmt.group(1) != params['fmt'] or \
        new_fmt.group(2) != "%dx%d" % (params['width'], params['height']):

        print ""
        print "ERR: Could not apply format"
        exit(-1)

    print ""

if __name__ == "__main__":
    MDEV='/dev/media0'

    sudo = "sudo" if os.geteuid() != 0 else ""

    if len(sys.argv) != 2:
        print "Usage %s <pad_config>" % sys.argv[0]
        print "Where <pad_config> is in pad_config/<pad_config>.py"
        exit(-1)

    sys.dont_write_bytecode = True # avoid .pyc from the modules
    sys.path.append(os.path.join(os.path.curdir, PAD_CONFIG_DIRNAME))

    exec('import %s' % sys.argv[1])
    mod = sys.modules[sys.argv[1]]
    if not mod.pads:
        print "File %s doesn't define pads variable" % sys.argv[1]
        exit(-1)

    print mod.pads

    for pad in mod.pads:
        if 'code' in pad:
            change_sd_fmt(pad, MDEV)
        else:
            change_vid_fmt(pad)

    print "==========================================="
    print "SUMMARY"
    print "==========================================="
    cmd = '{} media-ctl -p -d '.format(sudo) + MDEV
    print '>' + cmd
    os.system(cmd)
