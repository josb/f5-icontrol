# vim:expandtab shiftwidth=2 softtabstop=2

require 'rubygems'
require 'soap/wsdlDriver'

module F5

  DEBUG = false

  class IControl
    attr_reader :endpoint_url, :basic_auth, :connect_timeout

    def initialize(endpoint, opts={})
      config_file      = opts[:config_file] || 'config.yaml'
      method           = opts[:method]      || 'https'
      @connect_timeout = opts[:connect_timeout]

      begin
        configuration = YAML::load_file(config_file)
      rescue Exception => exc
        raise "error loading configuration from '#{config_file}': #{exc.message}"
      end

      @wsdl = configuration['wsdl']
      username = configuration['username']
      password = configuration['password']

      @endpoint_url = "#{method}://#{endpoint}/iControl/iControlPortal.cgi"
      @basic_auth = [@endpoint_url, username, password]

      @modules = {}
      @wsdl.each do |module_name, interfaces|
        @modules[module_name] = Module.new(self, module_name, interfaces)
        class << self; self; end.module_eval do
          define_method(module_name.downcase) { @modules[module_name] }
        end
      end
    end

    class Module
      attr_reader :base

      def initialize(base, name, interfaces)
        puts "loading module #{name}" if DEBUG
        @base, @name = base, name
        @interfaces = Hash.new {|h, interface_name|
          if interfaces.has_key? interface_name
            h[interface_name] = Interface.new(self, interface_name, interfaces[interface_name])
            class << self; self; end.module_eval do
              define_method(interface_name) { h[interface_name] }
            end
            h[interface_name]
          else
            raise "module #{@name}: unknown interface: #{interface_name}"
          end
        }
      end

      def method_missing(meth, *args)
        @interfaces[meth.to_s] # Instantiate RPC driver
      end

      class Interface
        def initialize(mod, name, wsdl_name)
          puts "loading interface #{name}" if DEBUG
          @name = name
          @driver = SOAP::WSDLDriverFactory.new(wsdl_name).create_rpc_driver

          verify_mode = OpenSSL::SSL::VERIFY_NONE
          @driver.options['protocol.http.ssl_config.verify_mode'] = verify_mode
          @driver.options['protocol.http.ssl_config.verify_callback'] = lambda {|is_ok, ctx| true}
          @driver.options['protocol.http.basic_auth'] << mod.base.basic_auth
          if mod.base.connect_timeout
            @driver.options["protocol.http.connect_timeout"] = mod.base.connect_timeout
          end

          # Override WSDL service endpoint
          @driver.endpoint_url = mod.base.endpoint_url
        end

        def method_missing(meth, *args)
          if @driver.respond_to? meth
            @driver.send(meth, *args)
          else
            raise "interface #{@name}: unknown method: #{meth}"
          end
        end
      end # class Interface

    end # class Module

  end # class IControl

end # module F5
