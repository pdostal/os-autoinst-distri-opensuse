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
use publiccloud::basetest;
use utils;

sub run {
    my ($self) = @_;
    select_console 'root-console';
    type_string("exit\n");
    $serialdev = get_var('serialdev_');
    set_var('SERIALDEV', $serialdev);
    bmwqemu::save_vars();
    assert_script_run("ps --no-headers ao 'pid:1,cmd:1' | grep '[s]sh'");
    assert_script_run("kill -9 `ps --no-headers ao 'pid:1,cmd:1' | grep '[s]sh -t -R' | cut -d' ' -f1`");
    select_console 'user-console';
    publiccloud::basetest::_cleanup();
}

1;

