# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This is a second test
#
# Maintainer: <qa-c@suse.de>

use Mojo::Base 'test_base';
use serial_terminal 'select_serial_terminal';
use testapi;

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    record_info('TEST_SECOND', 'test_second: run():' . $test_base::test);
}

1;
