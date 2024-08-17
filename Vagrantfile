# -*- mode: ruby -*-
# vi: set ft=ruby :

MACHINES = {
  :'bash-script' => {
    :domain => 'internal',
    :box => 'generic/centos9s',
    :cpus => 1,
    :memory => 1024,
    :networks => [
      [
        :forwarded_port, {
          :guest => 80,
          :host_ip => '127.0.0.1',
          :host => 8080
        }
      ]
    ]
  }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |host_name, host_config|
    config.vm.define host_name do |host|
      host.vm.box = host_config[:box]
      host.vm.host_name = host_name.to_s + '.' + host_config[:domain].to_s

      host.vm.provider :virtualbox do |vb|
        vb.cpus = host_config[:cpus]
        vb.memory = host_config[:memory]
      end

      host_config[:networks].each do |network|
        host.vm.network(network[0], **network[1])
      end

      if MACHINES.keys.last == host_name
        host.vm.provision :ansible do |ansible|
          ansible.playbook = 'playbook.yml'
          ansible.limit = 'all'
          ansible.compatibility_mode = '2.0'
          ansible.raw_arguments = ['--diff']
        end
      end
    end
  end
end
