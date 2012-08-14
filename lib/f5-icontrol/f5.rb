# vim:expandtab shiftwidth=2 softtabstop=2

require 'f5-icontrol/icontrol'

module F5

  class LoadBalancer
    attr_reader :hostname, :icontrol

    class Node
      attr_reader :address
      attr_reader :session_enabled_state, :monitor_status

      def initialize(lb, address)
        @lb, @address = lb, address
        clear
      end

      def clear
        @session_enabled_state = 'UNKNOWN'
        @monitor_status = 'UNKNOWN'
      end

      def refresh
        get_session_enabled_state
        get_monitor_status
      end

      def to_s
        "#{@address} (#{@session_enabled_state},#{@monitor_status})"
      end

      def set_monitor_state(what)
        @lb.icontrol.locallb.node_address.set_monitor_state([@address], [what])
      end

      def get_monitor_status
        @monitor_status = @lb.icontrol.locallb.node_address.get_monitor_status([@address]).first
      end

      def set_session_enabled_state(what)
        @lb.icontrol.locallb.node_address.set_session_enabled_state([@address], [what])
      end

      def get_session_enabled_state
        @session_enabled_state = @lb.icontrol.locallb.node_address.get_session_enabled_state([@address]).first
      end

      def get_object_status
        @lb.icontrol.locallb.node_address.get_object_status([@address]).first
      end

      def set_state(what)
        set_session_enabled_state(what)
        set_monitor_state(what)
      end
    end # class Node

    class Pool
      attr_reader :name, :lb

      def initialize(lb, name)
        @lb, @name = lb, name
        @members = nil
      end

      def to_s
        "#{@lb} #{@name}"
      end

      def members
        @members ||= @lb.icontrol.locallb.pool.get_member(@name).first.map do |member|
          PoolMember.new(self, member.address, member.port)
        end
      end

      def find_member(a_member)
        members.find {|member| member.address == a_member.address and member.port == a_member.port}
      end

      def find_node(a_node)
        members.find {|member| member.address == a_node.address}
      end

      def clear_members
        members.each do |member| member.clear end
      end

      # Fetch/update session_enabled_state for the PoolMembers in this Pool
      def get_session_enabled_state
        @lb.icontrol.locallb.pool_member.get_session_enabled_state(@name).first.each do |member_state|
          if m = find_member(member_state.member)
            m.session_enabled_state = member_state.session_state
          end
        end
      end

      # Fetch/update session_status for the PoolMembers in this Pool
      def get_session_status
        @lb.icontrol.locallb.pool_member.get_session_status(@name).first.each do |member_status|
          if m = find_member(member_status.member)
            m.session_status = member_status.session_status
          end
        end
      end

      def get_monitor_instance
        @lb.icontrol.locallb.pool.get_monitor_instance([@name]).first
      end

      def get_monitor_association
        @lb.icontrol.locallb.pool.get_monitor_association([@name]).first
      end

      def get_object_status
        @lb.icontrol.locallb.pool.get_object_status([@name]).first
      end

    end # class Pool

    class PoolMember
      attr_accessor :address, :port
      attr_reader :session_enabled_state, :session_status, :monitor_status

      def initialize(pool, address, port)
        @pool, @address, @port = pool, address, port
        clear
      end

      def clear
        @session_enabled_state = 'UNKNOWN'
        @session_status = 'UNKNOWN'
        @monitor_status = 'UNKNOWN'
      end

      def refresh
        get_session_status
        get_session_enabled_state
        get_monitor_status
      end

      def enabled?
        @session_enabled_state == 'STATE_ENABLED' and
        @session_status == 'SESSION_STATUS_ENABLED' and
        @monitor_status == 'MONITOR_STATUS_UP'
      end

      def to_s
        "#{@address}:#{@port} (#{@session_enabled_state},#{@session_status},#{@monitor_status})"
      end

      def to_hash
        {
          'address' => @address,
          'port'    => @port,
          'state'   => {
            'session_enabled_state' => @session_enabled_state,
            'session_status' => @session_status,
            'monitor_status' => @monitor_status,
          }
        }
      end

      def get_session_status
        @session_status = @pool.lb.icontrol.locallb.pool_member.get_session_status([@pool.name]).first.select {|state|
          state.member.address == @address and state.member.port == @port
        }.map {|state| state.session_status}.first
      end

      def get_session_enabled_state
        @session_enabled_state = @pool.lb.icontrol.locallb.pool_member.get_session_enabled_state([@pool.name]).first.select {|state|
          state.member.address == @address and state.member.port == @port
        }.map {|state| state.session_state}.first
      end

      def set_session_enabled_state(what)
        @pool.lb.icontrol.locallb.pool_member.set_session_enabled_state([@pool.name], [[{'member' => to_hash, 'session_state' => what}]])
        get_session_enabled_state
      end

      def get_monitor_status
        @monitor_status = @pool.lb.icontrol.locallb.pool_member.get_monitor_status([@pool.name]).first.select {|state|
          state.member.address == @address and state.member.port == @port
        }.map {|state| state.monitor_status}.first
      end

      def set_monitor_state(what)
        @pool.lb.icontrol.locallb.pool_member.set_monitor_state([@pool.name], [[{'member' => to_hash, 'monitor_state' => what}]])
        get_monitor_status
      end

      def set_state(what)
        set_session_enabled_state(what)
        set_monitor_state(what)
      end

      def get_monitor_instance
        @pool.lb.icontrol.locallb.pool_member.get_monitor_instance([@pool.name]).first
      end

      def get_monitor_association
        @pool.lb.icontrol.locallb.pool_member.get_monitor_association([@pool.name]).first
      end

    end # class PoolMember

    def initialize(hostname, opts={})
      @hostname = hostname
      @icontrol = F5::IControl.new(@hostname, opts)
    end

    def to_s
      "#{@hostname}"
    end

    def nodes
      @icontrol.locallb.node_address.get_list.map {|node| Node.new(self, node)}
    end

    def pools
      @icontrol.locallb.pool.get_list.map {|pool| Pool.new(self, pool)}
    end

    def pool(pool)
      pools.find {|p| p.name == pool.name}
    end

    def pool_by_name(pool_name)
      pools.find {|p| p.name == pool_name}
    end

    class Management

      class DBVariable
        attr_reader :name

        def initialize(name)
          @name = name
        end

        def query(lb)
          lb.icontrol.management.db_variable.query([@name]).first.value
        end

        def modify(lb, value)
          lb.icontrol.management.db_variable.modify([ { 'name' => @name, 'value' => value } ])
        end

        def delete(lb)
          lb.icontrol.management.db_variable.delete_variable([@name])
        end

        def available?(lb)
          lb.icontrol.management.db_variable.is_variable_available([@name]).first
        end

      end # class DBVariable

    end # class Management

    class System

      class Failover
        
        def get_failover_mode(lb)
          lb.icontrol.system.failover.get_failover_mode
        end
        
        def get_failover_state(lb)
          lb.icontrol.system.failover.get_failover_state
        end

        def get_peer_address(lb)
          lb.icontrol.system.failover.get_peer_address
        end

        def get_version(lb)
          lb.icontrol.system.failover.get_version
        end

        def is_redundant?(lb)
          lb.icontrol.system.failover.is_redundant
        end

      end # class Failover

    end # class System

  end # class LoadBalancer

end # module F5
