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
    select_console 'user-console';
    become_root;

    my $provider = publiccloud::basetest::provider_factory();
    my $instance = $provider->create_instance(check_connectivity => 0);
    $instance->check_ssh_port(timeout => 300);

    # configure ssh client, fetch the instance ssh public key
    assert_script_run('curl ' . data_url('publiccloud/ssh_config') . ' -o ~/.ssh/config');
    assert_script_run "ssh-keyscan " . $instance->public_ip . " > ~/.ssh/known_hosts";

    # Allow root ssh login
    assert_script_run("ssh -l " . $instance->username . " " . $instance->public_ip . " hostname -f");
    assert_script_run("ssh -l " . $instance->username . " " . $instance->public_ip . " 'echo -e \"" . $testapi::password . "\\n" . $testapi::password . "\" | sudo passwd root'");
    assert_script_run("ssh -l " . $instance->username . " " . $instance->public_ip . " 'sudo sed -i \"s/PermitRootLogin no/PermitRootLogin yes/g\" /etc/ssh/sshd_config'");
    assert_script_run("ssh -l " . $instance->username . " " . $instance->public_ip . " 'sudo sed -i \"s/PasswordAuthentication no/PasswordAuthentication yes/g\" /etc/ssh/sshd_config'");
    assert_script_run("ssh -l " . $instance->username . " " . $instance->public_ip . " 'sudo systemctl reload sshd'");
    assert_script_run("ssh -l " . $instance->username . " " . $instance->public_ip . " 'sudo cp /home/ec2-user/.ssh/authorized_keys /root/.ssh/'");
    assert_script_run("ssh -l " . $instance->username . " " . $instance->public_ip . " 'echo \"echo ssh_serial_ready >> /dev/sshserial\" > .bashrc; sudo cp .bashrc /root/'");

    set_var('SUT_HOSTNAME',          $instance->public_ip);
    set_var('AUTOINST_URL_HOSTNAME', 'localhost');
    my $upload_port = get_required_var('QEMUPORT') + 1;
    my $upload_host = testapi::host_ip();
    script_run("ssh -t -R $upload_port:$upload_host:$upload_port " . $instance->public_ip . " 'rm -rf /dev/sshserial; mkfifo -m a=rwx /dev/sshserial; tail -Fn +1 /dev/sshserial' | tee /dev/$serialdev ", 0);
    sleep 10;
    save_screenshot;
    send_key('ret');
    
    select_console 'root-console';
    assert_script_run  "ps aux | grep -i [s]sh";
    type_string("ssh " . $instance->public_ip . "\n");
    wait_serial("ssh_serial_ready", 10);
    set_var('serialdev_', $serialdev);
    $serialdev = 'sshserial';
    set_var('SERIALDEV', $serialdev);
    bmwqemu::save_vars();
    $self->set_standard_prompt('root');
}

1;

