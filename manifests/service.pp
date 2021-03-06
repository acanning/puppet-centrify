#  Class centrify::service
#
#  This class will configure the services for
#  centrify and also will join the system to the
#  domain
#
#
class centrify::service {
  $auto_join = $centrify::auto_join
  $dc_service_ensure = $centrify::dc_service_ensure
  $ssh_service_ensure = $centrify::ssh_service_ensure
  $adjoin_server = $centrify::adjoin_server
  $adjoin_password = $centrify::adjoin_password
  $adjoin_domain = $centrify::adjoin_domain
  $adjoin_user = $centrify::adjoin_user
  $ssh_service_enable = $centrify::ssh_service_enable
  $ssh_service_name = $centrify::ssh_service_name
  $dc_service_name = $centrify::dc_service_name
  $dc_service_enable = $centrify::dc_service_enable

  if $auto_join {

    notice('running with auto_join enabled')

    # Error check for the dc_service ensure option
    if ! ($dc_service_ensure in [ 'running', 'stopped' ]) {
      fail('dc_service_ensure parameter must be running or stopped')
    }

    # Error check for the ssh_service ensure option
    if ! ($ssh_service_ensure in [ 'running', 'stopped' ]) {
      fail('ssh_service_ensure parameter must be running or stopped')
    }

    # ad-join
    exec { 'adjoin':
      path        => '/usr/bin:/usr/sbin:/bin',
      command     => "adjoin -w -u ${adjoin_user} -s ${adjoin_server} -p ${adjoin_password} ${adjoin_domain}",
      unless      => "adinfo -d | grep ${adjoin_domain}",
      refreshonly => true,
    }

    #adflush
    exec { 'adflush':
      path        => '/usr/local/bin:/bin:/usr/bin:/usr/sbin',
      command     => '/usr/sbin/adflush && /usr/sbin/adreload',
      refreshonly => true,
    }

  service {'centrify-ssh-service':
      ensure     => $ssh_service_ensure,
      name       => $ssh_service_name,
      hasrestart => true,
      hasstatus  => true,
      enable     => $ssh_service_enable,
      subscribe  => [
        File['/etc/centrifydc/centrifydc.conf'],
        File['/etc/centrifydc/groups.allow'],
        File['/etc/centrifydc/users.allow'],
      ],
    notify       => Exec['adflush'],
  }

  service {'centrify-dc-service':
      ensure     => $dc_service_ensure,
      name       => $dc_service_name,
      hasrestart => true,
      hasstatus  => true,
      enable     => $dc_service_enable,
      subscribe  => [
        File['/etc/centrifydc/centrifydc.conf'],
        File['/etc/centrifydc/groups.allow'],
        File['/etc/centrifydc/users.allow'],
      ],
      notify     => Exec['adflush'],
    }

    Exec['adjoin'] -> Service['centrify-dc-service'] ->
    Service['centrify-ssh-service'] -> Exec['adflush']
  }
}