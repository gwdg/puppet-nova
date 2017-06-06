require 'spec_helper'

describe 'nova::wsgi::apache' do

 let :pre_condition do
   "include nova
    class { '::nova::api':
      service_name   => 'httpd',
      admin_password => 'secrete',
    }"
 end

  shared_examples_for 'apache serving nova with mod_wsgi' do
    it { is_expected.to contain_service('httpd').with_name(platform_parameters[:httpd_service_name]) }
    it { is_expected.to contain_class('nova::params') }
    it { is_expected.to contain_class('apache') }
    it { is_expected.to contain_class('apache::mod::wsgi') }

    context 'with default parameters' do

      let :pre_condition do
        "include nova
         class { '::nova::api':
           service_name   => 'httpd',
           admin_password => 'secrete',
         }"
      end

      it { is_expected.to contain_file("#{platform_parameters[:wsgi_script_path]}").with(
        'ensure'  => 'directory',
        'owner'   => 'nova',
        'group'   => 'nova',
        'require' => 'Package[httpd]'
      )}


      it { is_expected.to contain_file('nova_api_wsgi').with(
        'ensure'  => 'file',
        'path'    => "#{platform_parameters[:wsgi_script_path]}/nova-api",
        'source'  => platform_parameters[:api_wsgi_script_source],
        'owner'   => 'nova',
        'group'   => 'nova',
        'mode'    => '0644'
      )}
      it { is_expected.to contain_file('nova_api_wsgi').that_requires("File[#{platform_parameters[:wsgi_script_path]}]") }

      it { is_expected.to contain_apache__vhost('nova_api_wsgi').with(
        'servername'                  => 'some.host.tld',
        'ip'                          => nil,
        'port'                        => '8774',
        'docroot'                     => "#{platform_parameters[:wsgi_script_path]}",
        'docroot_owner'               => 'nova',
        'docroot_group'               => 'nova',
        'ssl'                         => 'true',
        'wsgi_daemon_process'         => 'nova-api',
        'wsgi_process_group'          => 'nova-api',
        'wsgi_script_aliases'         => { '/' => "#{platform_parameters[:wsgi_script_path]}/nova-api" },
        'require'                     => 'File[nova_api_wsgi]'
      )}
      it { is_expected.to contain_concat("#{platform_parameters[:httpd_ports_file]}") }

      it { is_expected.to contain_file('nova_api_wsgi').with(
        'ensure'  => 'file',
        'path'    => "#{platform_parameters[:wsgi_script_path]}/nova-api",
        'source'  => platform_parameters[:api_wsgi_script_source],
        'owner'   => 'nova',
        'group'   => 'nova',
        'mode'    => '0644'
      )}
      it { is_expected.to contain_file('nova_api_wsgi').that_requires("File[#{platform_parameters[:wsgi_script_path]}]") }

      it { is_expected.to contain_concat("#{platform_parameters[:httpd_ports_file]}") }
    end

    context 'when overriding parameters using different ports' do
      let :pre_condition do
        "include nova
         class { '::nova::api':
           service_name   => 'httpd',
           admin_password => 'secrete',
         }"
      end

      let :params do
        {
          :servername  => 'dummy.host',
          :bind_host   => '10.42.51.1',
          :api_port    => 12345,
          :ssl         => false,
          :workers     => 37,
        }
      end

      it { is_expected.to contain_apache__vhost('nova_api_wsgi').with(
        'servername'                  => 'dummy.host',
        'ip'                          => '10.42.51.1',
        'port'                        => '12345',
        'docroot'                     => "#{platform_parameters[:wsgi_script_path]}",
        'docroot_owner'               => 'nova',
        'docroot_group'               => 'nova',
        'ssl'                         => 'false',
        'wsgi_daemon_process'         => 'nova-api',
        'wsgi_process_group'          => 'nova-api',
        'wsgi_script_aliases'         => { '/' => "#{platform_parameters[:wsgi_script_path]}/nova-api" },
        'require'                     => 'File[nova_api_wsgi]'
      )}
    end

    context 'when ::nova::api is missing in the composition layer' do

      let :pre_condition do
        "include nova"
      end

      it { is_expected.to raise_error Puppet::Error, /::nova::api class must be declared in composition layer./ }
    end

  end

  on_supported_os({
    :supported_os => OSDefaults.get_supported_os
  }).each do |os,facts|
    context "on #{os}" do
      let (:facts) do
        facts.merge!(OSDefaults.get_facts({ :fqdn => 'some.host.tld'}))
      end

      let (:platform_parameters) do
        case facts[:osfamily]
        when 'Debian'
          {
            :httpd_service_name     => 'apache2',
            :httpd_ports_file       => '/etc/apache2/ports.conf',
            :wsgi_script_path       => '/usr/lib/cgi-bin/nova',
            :api_wsgi_script_source => '/usr/lib/python2.7/dist-packages/nova/wsgi/nova-api.py',
          }
        when 'RedHat'
          {
            :httpd_service_name     => 'httpd',
            :httpd_ports_file       => '/etc/httpd/conf/ports.conf',
            :wsgi_script_path       => '/var/www/cgi-bin/nova',
            :api_wsgi_script_source => '/usr/lib/python2.7/site-packages/nova/wsgi/nova-api.py',
          }
        end
      end
      it_behaves_like 'apache serving nova with mod_wsgi'
    end
  end

end
