package containers::operations::docker;
use Mojo::Base -base;

sub check_containers_firewall {
    my $docker_version = get_docker_version() if $runtime->runtime eq 'docker';
    
    my $running = script_output qq(docker ps -q | wc -l);
    validate_script_output('ip a s docker0', sub { /state DOWN/ }) if $running == 0;
    # Docker zone is created for docker version >= 20.10 (Tumbleweed), but it
    # is backported to docker 19 for SLE15-SP3 and for Leap 15.3
    if (check_runtime_version($docker_version, ">=20.10") || is_sle('>=15-sp3') || is_leap(">=15.3")) {
	assert_script_run "firewall-cmd --list-all --zone=docker";
	validate_script_output "firewall-cmd --list-interfaces --zone=docker", sub { /docker0/ };
    }
    # Rules applied before DOCKER. Default is to listen to all tcp connections
    # ex. output: "1           0        0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0"
    validate_script_output "iptables -L DOCKER-USER -nvx --line-numbers", sub { /1.+all.+0\.0\.0\.0\/0\s+0\.0\.0\.0\/0/ };
    assert_script_run "docker run -id --rm --name $container_name -p 1234:1234 " . registry_url('alpine');
    my $container_ip = container_ip($container_name, 'docker');
    # Each running container should have added a new entry to the DOCKER zone.
    # ex. output: "1           0        0 ACCEPT     tcp  --  !docker0 docker0  0.0.0.0/0            172.17.0.2           tcp dpt:1234"
    validate_script_output "iptables -L DOCKER -nvx --line-numbers", sub { /1.+ACCEPT.+!docker0 docker0.+$container_ip\s+tcp dpt:1234/ };
    assert_script_run "docker kill $container_name ";

    if ($runtime eq 'docker') {
        assert_script_run "sysctl -a | grep '\\.forwarding'";
        assert_script_run "firewall-cmd --list-all-zones";
        script_run "docker run --rm " . registry_url('alpine') . " ip a s";
        script_run "docker run --rm " . registry_url('alpine') . " ip r s";

        # Connectivity check
        assert_script_run "docker run --rm " . registry_url('alpine') . " wget " . get_var('OPENQA_URL');
}

package containers::operations::podman;
use Mojo::Base -base;

sub check_containers_firewall {
    assert_script_run "podman run --rm " . registry_url('alpine');
    validate_script_output('ip a s cni-podman0', sub { /,UP/ });
    
    # Cheking rules of specific running container
    assert_script_run "podman run -id --rm --name $container_name -p 1234:1234 " . registry_url('alpine');
    assert_script_run "iptables -vnL";
    assert_script_run "iptables -vnL -t nat";
    validate_script_output("iptables -vn -t nat -L PREROUTING", sub { /CNI-HOSTPORT-DNAT/ });
    validate_script_output("iptables -vn -t nat -L POSTROUTING", sub { /CNI-HOSTPORT-MASQ/ });
    assert_script_run "podman kill $container_name";
    
    # Connectivity check
    assert_script_run "podman run --rm " . registry_url('alpine') . " wget " . get_var('OPENQA_URL');
}
