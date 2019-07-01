# frozen_string_literal: true

module ActiveRecordExtended
  module QueryMethods
    module Inet
      # Finds matching inet column records that fall within a given submasked IP range
      #
      # Column(inet) << "127.0.0.1/24"
      #
      # User.where.inet_contained_within(ip: "127.0.0.1/16")
      #  #=> "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"ip\" << '127.0.0.1/16'"
      #
      # User.where.inet_contained_within(ip: IPAddr.new("192.168.2.0/24"))
      #  #=> "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"ip\" << '192.168.2.0/24'"
      #
      def inet_contained_within(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::Inet::ContainedWithin, "inet_contained_within")
      end

      # Finds matching inet column records that fall within a given submasked IP range and also finds records that also
      # contain a submasking field that fall within range too.
      #
      # Column(inet) <<= "127.0.0.1/24"
      #
      # User.where.inet_contained_within_or_equals(ip: "127.0.0.1/16")
      #  #=> "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"ip\" <<= '127.0.0.44/32'"
      #
      # User.where.inet_contained_within_or_equals(ip: IPAddr.new("192.168.2.0/24"))
      #  #=> "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"ip\" <<= '192.168.2.0/24'"
      #
      def inet_contained_within_or_equals(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::Inet::ContainedWithinEquals, "inet_contained_within_or_equals")
      end

      # Finds records that contain a submask and the supplied IP address falls within its range.
      #
      # Column(inet) >>= "127.0.0.1/24"
      #
      # User.where.inet_contained_within_or_equals(ip: "127.0.255.255")
      #  #=> "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"ip\" >>= '127.0.255.255'"
      #
      # User.where.inet_contained_within_or_equals(ip: IPAddr.new("127.0.0.255"))
      #  #=> "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"ip\" >>= '127.0.0.255/32'"
      #
      def inet_contains_or_equals(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::Inet::ContainsEquals, "inet_contains_or_equals")
      end

      # Strictly finds records that contain a submask and the supplied IP address falls within its range.
      #
      # Column(inet) >>= "127.0.0.1"
      #
      # User.where.inet_contained_within_or_equals(ip: "127.0.255.255")
      #  #=> "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"ip\" >> '127.0.255.255'"
      #
      # User.where.inet_contained_within_or_equals(ip: IPAddr.new("127.0.0.255"))
      #  #=> "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"ip\" >> '127.0.0.255/32'"
      #
      def inet_contains(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::Inet::Contains, "inet_contains")
      end

      # This method is a combination of `inet_contains` and `inet_contained_within`
      #
      # Finds records that are contained within a given submask. And will also find records where their submask is also
      # contains a given IP or IP submask.
      #
      # Column(inet) && "127.0.0.1/28"
      #
      # User.where.inet_contains_or_is_contained_by(ip: "127.0.255.255/28")
      #  #=> "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"ip\" && '127.0.255.255/28'"
      #
      # User.where.inet_contains_or_is_contained_by(ip: IPAddr.new("127.0.0.255"))
      #  #=> "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"ip\" && '127.0.0.255/32'"
      #
      def inet_contains_or_is_contained_within(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::Inet::ContainsOrContainedWithin,
                               "inet_contains_or_is_contained_within")
      end
    end
  end
end

ActiveRecord::QueryMethods::WhereChain.prepend(ActiveRecordExtended::QueryMethods::Inet)
