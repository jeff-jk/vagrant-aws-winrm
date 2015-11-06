require "aws-sdk"

module VagrantPlugins
  module AWS
    module WinRM
      class Capability
        def self.winrm_info(machine)
          if machine.config.winrm.password == :aws
            machine.ui.info('Getting WinRM password from AWS')

            # AWS connection info
            access_key_id     = machine.provider_config.access_key_id
            secret_access_key = machine.provider_config.secret_access_key 
            credentials       = ::Aws::Credentials.new(access_key_id, secret_access_key)
            region            = machine.provider_config.region

            # Grab the region endpoint explicitly in the event that
            # a custom endpoint was specified (e.g. OpenStack)            
            region_config = machine.provider_config.get_region_config(region)
            endpoint      = region_config.endpoint            

            # Fetch that password data for the instance
            ec2                 = Aws::EC2::Client.new(region: region, endpoint: endpoint, credentials: credentials)
            password_data       = ec2.get_password_data({ instance_id: machine.id }).password_data
            password_data_bytes = Base64.decode64(password_data)
            
            # Try to decrypt the password data using each one of the private key files
            # set by the user until we hit one that decrypts successfully
            machine.config.ssh.private_key_path.each do |private_key_path|
              rsa = OpenSSL::PKey::RSA.new File.read(File.expand_path private_key_path)

              begin
                machine.config.winrm.password = rsa.private_decrypt password_data_bytes
              rescue OpenSSL::PKey::RSAError
                next
              end

              break
            end            
          end

          return {}
        end
      end        
    end      
  end
end