# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Collect/store bootup time from publiccloud instances.
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use testapi;
use base 'opensusebasetest';
use registration qw(register_product);
use utils;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    assert_script_run("hostname -f");
    assert_script_run("uname -a");
    register_product();
    zypper_call("in traceroute");
    assert_script_run("ls /etc", 900);
    assert_script_run("cat /etc/hosts", 900);
    assert_script_run("cat /etc/os-release", 900);
    assert_script_run("ip a s", 900);
    assert_script_run("ip -6 a s", 900);
    assert_script_run("ip r s", 900);
    assert_script_run("ip -6 r s", 900);
    assert_script_run("ps aux | nl", 900);
    assert_script_run("traceroute -I gate.suse.cz", 90);
}

1;

