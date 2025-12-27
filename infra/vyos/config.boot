interfaces {
    ethernet eth0 {
        address "dhcp"
        description "WAN"
        hw-id "bc:24:11:79:f2:f8"
        offload {
            gro
            gso
            sg
            tso
        }
    }
    ethernet eth1 {
        address "192.168.2.1/24"
        description "LAN"
        hw-id "bc:24:11:e6:27:69"
        offload {
            gro
            gso
            sg
            tso
        }
    }
    loopback lo {
    }
}
service {
    dhcp-server {
        shared-network-name LAB {
            subnet 192.168.2.0/24 {
                option {
                    default-router "192.168.2.1"
                    name-server "192.168.2.1"
                }
                range 0 {
                    start "192.168.2.10"
                    stop "192.168.2.100"
                }
                subnet-id "1"
            }
        }
    }
    ntp {
        allow-client {
            address "127.0.0.0/8"
            address "169.254.0.0/16"
            address "10.0.0.0/8"
            address "172.16.0.0/12"
            address "192.168.0.0/16"
            address "::1/128"
            address "fe80::/10"
            address "fc00::/7"
        }
        server time1.vyos.net {
        }
        server time2.vyos.net {
        }
        server time3.vyos.net {
        }
    }
    ssh {
        disable-password-authentication
        port "22"
    }
}
system {
    config-management {
        commit-revisions "100"
    }
    console {
        device ttyS0 {
            speed "115200"
        }
    }
    host-name "vyos"
    login {
        operator-group default {
            command-policy {
                allow "*"
            }
        }
        user stan {
            authentication {
                public-keys stan@tp1-ubuntu {
                    key "AAAAB3NzaC1yc2EAAAADAQABAAABgQDPKFMbjStE5sjG2Q5z3ovmbB3hTj85E4FtIC46T8NSHWDqCbMEpdN4AP2UZEjdf8tBS+LH5EGeQEQD1DTGScPodOloeU9/2OHHrjD066qIjYGa/2AWwdbnOSNxGY0sOFW//RojO8DeoK4fhWHunTbgxbzpuqFegmttyRrIkiaTQilBuIPM0Z52Dh9o1aLDnXBBScoz/txvVspNSqTgXWELO5TM3guHWaQhtHt5nEMksd0wmbtXmDu3aBXOQoQv2t1s3JIzyDk1wPLEfeiwXRM92yXv/pyV8Ww3UhdvDFol9MO00FDRQzaC6iKUQmIB2WhccSb/OgrCiG0gLnCrKGoAnDzpalTy1Ytq5zH+wVl+kfCSqTnId+9fXly5wK5LTw39P/T8VqbbQqi3s489Evh+wUOuy07NziF5fSwHzHYOP0Kz0bcKNoPb+SKIyC55HKOfsLR98JLdvEghYcDgntkQOAfTf3eYGzu2dUR3cw5JByD8lAtUZL5rJ0H+r1WEvJU="
                    type "ssh-rsa"
                }
            }
        }
        user vyos {
            authentication {
                encrypted-password "$6$rounds=656000$7tPuk4U8SkvpKH0K$JK/GIRje2BUS36Tb3enuoZ0SQcqR4jYXt0rVZ8q2d8TRbAN.0ao/ddLBb2xJMxKipoQWtogNkFBua5DaH3X3K0"
                plaintext-password ""
                public-keys stan@tp1-ubuntu {
                    key "AAAAB3NzaC1yc2EAAAADAQABAAABgQDPKFMbjStE5sjG2Q5z3ovmbB3hTj85E4FtIC46T8NSHWDqCbMEpdN4AP2UZEjdf8tBS+LH5EGeQEQD1DTGScPodOloeU9/2OHHrjD066qIjYGa/2AWwdbnOSNxGY0sOFW//RojO8DeoK4fhWHunTbgxbzpuqFegmttyRrIkiaTQilBuIPM0Z52Dh9o1aLDnXBBScoz/txvVspNSqTgXWELO5TM3guHWaQhtHt5nEMksd0wmbtXmDu3aBXOQoQv2t1s3JIzyDk1wPLEfeiwXRM92yXv/pyV8Ww3UhdvDFol9MO00FDRQzaC6iKUQmIB2WhccSb/OgrCiG0gLnCrKGoAnDzpalTy1Ytq5zH+wVl+kfCSqTnId+9fXly5wK5LTw39P/T8VqbbQqi3s489Evh+wUOuy07NziF5fSwHzHYOP0Kz0bcKNoPb+SKIyC55HKOfsLR98JLdvEghYcDgntkQOAfTf3eYGzu2dUR3cw5JByD8lAtUZL5rJ0H+r1WEvJU="
                    type "ssh-rsa"
                }
            }
        }
    }
    name-server "192.168.1.1"
    option {
        reboot-on-upgrade-failure "5"
    }
    syslog {
        local {
            facility all {
                level "info"
            }
            facility local7 {
                level "debug"
            }
        }
    }
}


// Warning: Do not remove the following line.
// vyos-config-version: "bgp@6:broadcast-relay@1:cluster@2:config-management@1:conntrack@6:conntrack-sync@2:container@3:dhcp-relay@2:dhcp-server@11:dhcpv6-server@6:dns-dynamic@4:dns-forwarding@4:firewall@20:flow-accounting@3:https@7:ids@2:interfaces@34:ipoe-server@4:ipsec@14:isis@3:l2tp@9:lldp@3:mdns@1:monitoring@2:nat@8:nat66@3:nhrp@1:ntp@3:openconnect@3:openvpn@4:ospf@2:pim@1:policy@9:pppoe-server@11:pptp@5:qos@3:quagga@12:reverse-proxy@3:rip@1:rpki@2:salt@1:snmp@3:ssh@2:sstp@6:system@30:vpp@4:vrf@3:vrrp@4:vyos-accel-ppp@2:wanloadbalance@4:webproxy@2"
// Release version: 2025.12.14-0023-rolling
