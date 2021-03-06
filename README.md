# Introduction
This is the eduVPN deploy manual.

# Software Requirements
CentOS >= 6.6 is the only officially supported deployment platform. However, 
it should also work on Fedora >= 20, CentOS >= 7.1 and Red Hat 
Enterprise >= 6.6 or >= 7.1.

# Hardware Requirements
It is highly recommended to use at least three (virtual) machines to run this.

1. the `vpn-cert-service` (CERT) machine handling the signing/configuration 
   management an revocation. The web service MUST only available to the other 
   two machines
2. the `vpn-user-portal` (PORTAL) machine handling the user interaction. It 
   MUST have access to the `vpn-cert-service` and have a password to use the 
   API
3. the OpenVPN (VPN) machine handling the VPN connections. It does not need to 
   have a connection to `vpn-user-portal` machine, and only needs read access 
   to the `ca.crl` URL on the `vpn-cert-service` machine. It does not need a 
   password to access the API

# Security Considerations

    +-----+         +------+         +--------+
    |     |  VLAN1  |      |  VLAN2  |        |
    | VPN +---------+ CERT +---------+ PORTAL |
    |     |         |      |         |        |
    +--+--+         +------+         +----+---+
       |                                  |
       |                                  |
       | Internet                         | Internet
          
Of course, CERT should also get software and security updates, but it should 
not be reachable from the Internet in any way. Only through the VLANs from 
PORTAL and VPN.

VPN should only be able to retrieve the CRL from CERT.
PORTAL should only be allowed to send POST and DELETE requests to CERT to 
generate and delete configurations.

For testing purposes of course this can be deployed on one machine. But for
production you MUST use at least three machines with sufficient security in 
place to avoid unauthorized access.

## Revoking a VPN server certificate
A potential problem is the revocation of a server in case its private key falls
into the wrong hands. In order to solve this, all clients need to become 
aware of this fact and thus need to also obtain the CRL periodically. This is 
a bit of a nightmare as the CRL needs to be downloaded regularly by all the
clients. One of the potential solutions for this is use short lived server
certificates that last e.g. one day. This is highly cumbersome.

Probably the easiest is to do nothing and hope that the MITM that wants to 
attack users is not the same as the one who obtained the private key from the
VPN server.

**UNSOLVED PROBLEM**

# Docker
See `docker/` directory. Currently only `vpn-cert-service `and 
`vpn-user-portal` can be tested. OpenVPN will not be running inside the 
Docker container.

# Repositories
For CentOS/Red Hat Enterprise you will need to enable 
[EPEL](https://fedoraproject.org/wiki/EPEL#How_can_I_use_these_extra_packages.3F).

# Packages
The software is contained in these projects:

- [vpn-user-portal](https://github.com/fkooman/vpn-user-portal)
- [vpn-cert-service](https://github.com/fkooman/vpn-cert-service)
- [vpn-crl-fetcher](https://github.com/fkooman/vpn-crl-fetcher)

The component `vpn-user-portal` is the UI for the end user, protected by SAML 
(using `mod_mellon`). It interacts with `vpn-cert-service` using a HTTP API 
protected by basic authentication.

The `vpn-cert-service` component is responsible for all the 'low level' 
configuration handling like running the CA, generating certificates, generating 
configurations, handling revocations and maintaining the CRL.

The `vpn-crl-fetcher` is responsible for fetching the CRL from 
`vpn-cert-service` for use with OpenVPN on the VPN machine.

These components depend on the following PHP libraries that are not available
in EPEL or the base repository:

- [php-lib-rest](https://github.com/fkooman/php-lib-rest)
- [php-lib-rest-plugin-basic](https://github.com/fkooman/php-lib-rest-plugin-basic)
- [php-lib-rest-plugin-mellon](https://github.com/fkooman/php-lib-rest-plugin-mellon)
- [php-lib-ini](https://github.com/fkooman/php-lib-ini)
- [php-lib-json](https://github.com/fkooman/php-lib-json)

These libraries are also all packaged as RPMs. All required files for 
generating the RPMs are available in the project directories under the `rpm` 
directory in their respective repository.

# Building RPMs
You can regenerate the eduVPN RPMs (or any of its dependencies) yourself from
source using the files in the `rpm` directory of this project. On a development 
machine you can do the following:

    $ sudo yum install rpmdevtools createrepo
    $ rpmdev-setuptree

    $ cd rpm
    $ sh ./build_all.sh

This should create SRPMs in `${HOME}/rpmbuild/SRPMS`

# Installation
For your convenience the RPMs are also available from two COPR repositories:

    https://copr.fedoraproject.org/coprs/fkooman/php-base/
    https://copr.fedoraproject.org/coprs/fkooman/vpn-management/

The first one contains the dependencies, the second one the actual eduVPN 
software. To enable them see the instructions. For CentOS 6 you will need to
manually copy the `repo` files to `/etc/yum.repos.d/` as the COPR plugin for 
`yum` is not available.

To install `vpn-cert-service`: 
    
    $ sudo yum -y install vpn-cert-service

To install `vpn-user-portal`:

    $ sudo yum -y install vpn-user-portal

You will also want to install `mod_ssl`. The `mod_auth_mellon` package is an 
(indirect) dependency of `vpn-user-portal`. 

    $ sudo yum -y install mod_ssl

Now enable `httpd` by default:

    $ sudo chkconfig httpd on

# Configuration
Both `vpn-cert-service` and `vpn-user-portal` will have a working configuration
file on installation. But you SHOULD update the configuration files in 
`/etc/vpn-user-portal` and `/etc/vpn-cert-service` to suit your environment if
needed. For example if you want to use something else than SQlite, you need to
setup your database first and modify the configuration.

You then need to run the database initialization scripts, they will populate
the database:

    $ sudo -u apache vpn-cert-service-init
    $ sudo -u apache vpn-user-portal-init

Do not forget to update the passwords and Apache configuration of both 
`vpn-cert-service` (`/etc/httpd/conf.d/vpn-cert-service.conf`) and 
`vpn-user-portal` (`/etc/httpd/conf.d/vpn-user-porta.conf`). They allow only 
connections from `localhost` by default. To generate a password hash you can 
use this:

    $ vpn-cert-service-generate-password-hash mySecretPass

You can add the hash to `/etc/vpn-cert-service/config.ini` and the plain text
value to `/etc/vpn-user-portal/config.ini`.

If you want to adapt the default templates for generating server and client
configurations they can be copied from the default location to the 
configuration directory:

    $ sudo mkdir /etc/vpn-cert-service/views
    $ sudo cp /usr/share/vpn-cert-service/views/server.twig /etc/vpn-cert-service/views
    $ sudo cp /usr/share/vpn-cert-service/views/client.twig /etc/vpn-cert-service/views

This mostly makes sense for the client template as that is used every time a 
new client configuration is generated. The server configuration that is 
generated can also easily be modified on the server, but in case you want to
deploy a lot of servers it may make sense to already make modifications in
the template.

# Time
Make sure the time is set correctly and is kept up to date. If the offset 
becomes too big SAML will no longer work correctly.

    $ sudo ntpdate pool.ntp.org
    $ sudo yum -y install ntp
    $ sudo chkconfig ntpd on
    $ sudo service ntpd start

# SAML configuration
Using the Apache module `mod_auth_mellon`. See 
[php-lib-rest-plugin-mellon](https://github.com/fkooman/php-lib-rest-plugin-mellon) 
documentation for more information on how to configure `mod_auth_mellon`. There
is an example line in `/etc/httpd/conf.d/vpn-user-portal.conf` to "fake"
`mod_auth_mellon` by directly specifying the `MELLON_NAME_ID` request header.

## Example
Generate the certificate and metadata:

    $ /usr/libexec/mod_auth_mellon/mellon_create_metadata.sh https://eduvpn.surfcloud.nl/saml https://eduvpn.surfcloud.nl/saml

Copy the files to the correct location:

    $ sudo mkdir /etc/httpd/saml
    $ sudo cp *.cert *.key *.xml /etc/httpd/saml/

Fetch the IdP metadata from SURFconext:

    $ curl -o SURFconext.xml https://engine.surfconext.nl/authentication/idp/metadata

Put `SURFconext.xml` in `/etc/httpd/saml` as well.

No create a configuration in `/etc/httpd.conf/saml.conf`:

    # This is a server-wide configuration that will add information from the Mellon session to all requests.
    <Location />
        # Add information from the mod_auth_mellon session to the request.
        MellonEnable "info"

        # Configure the SP metadata
        # This should be the files which were created when creating SP metadata.
        MellonSPPrivateKeyFile /etc/httpd/saml/https_eduvpn.surfcloud.nl_saml.key

        MellonSPCertFile /etc/httpd/saml/https_eduvpn.surfcloud.nl_saml.cert
        MellonSPMetadataFile /etc/httpd/saml/https_eduvpn.surfcloud.nl_saml.xml

        # IdP metadata. This should be the metadata file you got from the IdP.
        MellonIdPMetadataFile /etc/httpd/saml/SURFconext.xml

        # The location all endpoints should be located under.
        # It is the URL to this location that is used as the second parameter to the metadata generation script.
        # This path is relative to the root of the web server.
        MellonEndpointPath /saml
    </Location>

    # This is a location that will trigger authentication when requested.
    <Location /vpn-user-portal>
        # This location will trigger an authentication request to the IdP.
        MellonEnable "auth"
    </Location>

# Server configuration
You can now generate a OpenVPN server configuration on the `vpn-cert-service` 
machine and copy that to OpenVPN machine:

    $ sudo -u apache vpn-cert-service-generate-server-config vpn.example.org

Copy/paste the output and place it in `/etc/openvpn/server.conf` on your 
OpenVPN server. Do **NOT** forget to set the permissions:

    $ sudo chmod 0600 /etc/openvpn/server.conf

To start OpenVPN and enable it on boot:

    $ sudo chkconfig openvpn on
    $ sudo service openvpn restart

To enable IP forwarding set the following property in `/etc/sysctl.conf`:

    net.ipv4.ip_forward = 1

You also need to modify the firewall by using `system-config-firewall-tui`. 
You need to enable the OpenVPN, SSH, HTTPS services and enable masquerading
for `eth0`, assuming `eth0` is your interface which connects to the Internet 
and that you are using NAT. If you use publicly routable IP adresses you do 
not need to enable masquerading.

In the example below the configurations were modified to enable routing with 
public IP ranges. The firewall is configured in such a way that only the 
clients can initiate a connection, it is not possible to run a service on a 
client IP. If this is required, forwarding should be explicitly allowed from 
`eth0` to `tun0`, like this for IPv4, it is similar for IPv6:

    -A FORWARD -i eth0 -o tun0 -d 11.22.33.0/23 -j ACCEPT

The output of that script in `/etc/sysconfig/iptables` looks like this:

    # Firewall configuration written by system-config-firewall
    # Manual customization of this file is not recommended.
    *filter
    :INPUT ACCEPT [0:0]
    :FORWARD ACCEPT [0:0]
    :OUTPUT ACCEPT [0:0]
    -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    -A INPUT -p icmp -j ACCEPT
    -A INPUT -i lo -j ACCEPT
    -A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
    -A INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
    -A INPUT -m state --state NEW -m udp -p udp --dport 1194 -j ACCEPT
    -A INPUT -j REJECT --reject-with icmp-host-prohibited
    -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    -A FORWARD -i tun0 -o eth0 -s 11.22.33.0/23 -j ACCEPT
    -A FORWARD -j REJECT --reject-with icmp-host-prohibited
    COMMIT

The output of the script in `/etc/sysconfig/ip6tables` looks like this:

    # Firewall configuration written by system-config-firewall
    # Manual customization of this file is not recommended.
    *filter
    :INPUT ACCEPT [0:0]
    :FORWARD ACCEPT [0:0]
    :OUTPUT ACCEPT [0:0]
    -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    -A INPUT -p ipv6-icmp -j ACCEPT
    -A INPUT -i lo -j ACCEPT
    -A INPUT -m state --state NEW -m udp -p udp --dport 546 -d fe80::/64 -j ACCEPT
    -A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
    -A INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
    -A INPUT -m state --state NEW -m udp -p udp --dport 1194 -j ACCEPT
    -A INPUT -j REJECT --reject-with icmp6-adm-prohibited
    -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    -A FORWARD -i tun0 -o eth0 -s 2001:aaaa:bbbb:cccc::/64 -j ACCEPT
    -A FORWARD -j REJECT --reject-with icmp6-adm-prohibited
    COMMIT

To restart the firewall use the following:

    $ sudo service iptables restart
    $ sudo service ip6tables restart

See Red Hat Enterprise [Documentation](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Security_Guide/sect-Security_Guide-Firewalls-FORWARD_and_NAT_Rules.html) for more information.

**NOTE**: there is a missing dependency on (at least) CentOS 6.6 where you 
still need to manually install the `system-config-firewall` package before 
`system-config-firewall-tui` will work.

## IPv6
If you also want to enable IPv6 for use by clients the server needs to have 
an IPv6 address and a range of IPv6 addresses to give to clients. In the 
generated server configuration there are some commented lines that show you 
how to enable IPv6, just replace the IPv6 range with your range.

For further tweaking see the OpenVPN IPv6 
[wiki](https://community.openvpn.net/openvpn/wiki/IPv6) page. 

The following should be enough assuming the first `/64` of the IP block you 
want to use is `2001:aaaa:bbbb:cccc::`:

    server-ipv6 2001:aaaa:bbbb:cccc::/64
    push "route-ipv6 2000::/3"

To enable IPv6 routing add the following to `/etc/sysctl.conf`:

    net.ipv6.conf.all.forwarding = 1

You also need to modify the IPv6 firewall to allow forwarding in 
`/etc/sysconfig/ip6tables`:

    -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    -A FORWARD -i tun0 -o eth0 -s 2001:aaaa:bbbb:cccc::/64 -j ACCEPT

## CRL
The make the CRL work, a 'cronjob' is needed to occasionally retrieve the CRL
from `vpn-cert-service`. Install `vpn-crl-fetcher` on the VPN machine:

    $ sudo yum -y install vpn-crl-fetcher

Now add a cronjob:

    $ sudo crontab -e

Put the following information there:

    */5 * * * * /usr/bin/vpn-crl-fetcher http://localhost/vpn-cert-service/api.php/ca.crl /etc/openvpn/ca.crl

Run this as often as you want. The example below makes it run every 5 minutes. 
You SHOULD use `https` and of course change the domain name to your own server.

Modify the `/etc/openvpn/server.conf` file to enable using the CRL.

    crl-verify /etc/openvpn/ca.crl

**NOTE**: current connections will NOT be terminated if the certificate is 
added to the CRL, only new connections will be denied.
