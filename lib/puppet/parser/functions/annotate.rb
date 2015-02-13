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
    env_reg   = /^.*(#{scope.environment.name.to_s}|production|masterbranch)\/?/
    file_name = resource.file.gsub(env_reg, '') if "#{resource.file}" =~ env_reg

    if file_name && resource.line
      "https://gitweb.yelpcorp.com/?p=puppet.git;a=blob;f=%s#l%d" % [file_name, resource.line]
    else
      raise(Puppet::ParseError, "annotate couldn't find a file and line; is this an included class?")
    end
  end
end
