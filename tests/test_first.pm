# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This is a first test
#
# Maintainer: <qa-c@suse.de>

use Mojo::Base 'test_base';
use serial_terminal 'select_serial_terminal';
use testapi;

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    $test_base::test = "This is a test";
    record_info('TEST_FIRST', 'test_first: run():' . $test_base::test);
}

1;
