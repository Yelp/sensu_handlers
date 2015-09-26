module Puppet::Parser::Functions
  newfunction(:merge_resources, :type => :rvalue) do |args|
    if args.length != 2
      raise Puppet::Error,
        "wrong number of args expected 2 resource hashes"
    end

    args.each do |arg|
      unless arg.kind_of? Hash
        raise "expected resource hash. got #{arg}"
      end
    end

    overrides = args[0]
    results   = args[1].dup

    overrides.each do |k,v|
      if v == :undef
        results.delete(k)
      else
        results[k] ||= {}
        results[k].merge!(v)
      end
    end

    results
  end
end
