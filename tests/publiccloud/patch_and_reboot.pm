# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Refresh repositories, apply patches and reboot
#
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use warnings;
use testapi;
use strict;
use utils qw(ssh_fully_patch_system);
use publiccloud::utils qw(kill_packagekit ssh_update_transactional_system is_cloudinit_supported permit_root_passwordless);
use publiccloud::ssh_interactive qw(select_host_console);
use version_utils qw(is_sle_micro);

sub run {
    my ($self, $args) = @_;
    select_host_console();    # select console on the host, not the PC instance

    my $cmd_time = time();
    my $ref_timeout = check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE') ? 3600 : 240;
    my $remote = $args->{my_instance}->username . '@' . $args->{my_instance}->public_ip;
    $self->{remote} = $remote;
    # pkcon not present on SLE-micro
    kill_packagekit($args->{my_instance}) unless (is_sle_micro);
    $args->{my_instance}->ssh_script_retry("sudo zypper -n --gpg-auto-import-keys ref", timeout => $ref_timeout, retry => 6, delay => 60);
    record_info('zypper ref time', 'The command zypper -n ref took ' . (time() - $cmd_time) . ' seconds.');
    record_soft_failure('bsc#1195382 - Considerable decrease of zypper performance and increase of registration times') if ((time() - $cmd_time) > 240);
    if (is_sle_micro) {
        ssh_update_transactional_system($args->{my_instance});
    } else {
        ssh_fully_patch_system($remote);
    }
    record_info('UNAME', $args->{my_instance}->ssh_script_output(cmd => 'uname -a'));
    $args->{my_instance}->ssh_assert_script_run(cmd => 'rpm -qa > /tmp/rpm-qa.txt');
    $args->{my_instance}->upload_log('/tmp/rpm-qa.txt');
    #$args->{my_instance}->cleanup_cloudinit() if (is_cloudinit_supported);
    $args->{my_instance}->ssh_assert_script_run(qq(echo -e "$testapi::password\\n$testapi::password" | sudo passwd azureuser));
    $args->{my_instance}->ssh_assert_script_run("sudo passwd -u azureuser");
    $args->{my_instance}->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));

    if (is_cloudinit_supported) {
        $args->{my_instance}->check_cloudinit();
        permit_root_passwordless($args->{my_instance});
    }
}

sub debug {
    my $self = shift;
    script_run('ssh ' . $self->{remote} . ' sudo chmod 655 /var/log/zypper.log');
    script_run("scp " . $self->{remote} . ":/var/log/zypper.log /var/tmp/zypper.log");
    upload_logs('/var/tmp/zypper.log', failok => 1);
}

sub post_fail_hook {
    my $self = shift;

    $self->debug();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my $self = shift;

    $self->debug();
    $self->SUPER::post_run_hook;
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
