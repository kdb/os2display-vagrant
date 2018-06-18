VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "bento/debian-7.8"

  # IP
  config.vm.network "private_network", ip: "192.168.50.129"

  # Memory
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "4096"]
  end

  # To ensure access to eg. github.
  config.ssh.forward_agent = true

  # Shared folder
  config.vm.synced_folder ".", "/vagrant",
    :nfs => true,
    :mount_options => ['actimeo=2']

  # Hostname(s)
  config.vm.hostname = "os2display.vm"
  config.hostsupdater.aliases = ["screen.os2display.vm", "admin.os2display.vm", "search.os2display.vm", "middleware.os2display.vm"]

  # What to install
  config.vm.provision "shell" do |s|

    if ARGV[0] == 'up'
        if ENV['MODE'] != "demo" && ENV['MODE'] != "dev"
            puts 'Set the environment variable ENV to demo or dev before running vagrant up. Eg `MODE=dev vagrant up`'
            abort
        end
    end

    s.env = { MODE: ENV['MODE'] }
    s.path = "bootstrap.sh"
  end
end
