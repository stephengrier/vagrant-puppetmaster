# Puppet manifest for bootstrapping the client nodes.

host { 'pm-dev-0.ucl-0.ucl.ac.uk':
  ensure       => 'present',
  host_aliases => ['puppet'],
  ip           => '192.168.33.10',
  target       => '/etc/hosts',
}

