# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This is a first test
#
# Maintainer: <qa-c@suse.de>

package test_base;
use base 'opensusebasetest';
use testapi;

our $test;

sub post_run_hook {
    my ($self) = @_;
    record_info('TEST_BASE', 'test_base: post_run_hook():' . $test);
}

sub post_fail_hook {
    my ($self) = @_;
    record_info('TEST_BASE', 'test_base: post_fail_hook():' . $test);
}

1;
