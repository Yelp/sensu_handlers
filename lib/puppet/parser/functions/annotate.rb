module Puppet::Parser::Functions
  newfunction(:annotate, :type => :rvalue, :doc => <<-EOS
  Determines the location (file:line) of the declaration for the current
  resource.  Useful for creating links to documentation automaticall from
  Puppet code.

  Doesn't work with the 'include' function (e.g. include sshd) or
  (probably) resources created with create_resources.
  EOS
  ) do |args|
    scope = self
    resource = scope.resource

    # Travel two directories up to determine the size of the prefix to chop off
    # This is a cheap and ugly hack
    sizeof_prefix = File.dirname(File.dirname(scope.environment.manifest)).length + 1

    if scope.resource.file and scope.resource.line
      "https://gitweb.yelpcorp.com/?p=puppet.git;a=blob;f=%s#l%d" % [resource.file[sizeof_prefix..-1], resource.line]
    else
      raise(Puppet::ParseError, "annotate couldn't find a file and line; is this an included class?")
    end
  end
end
