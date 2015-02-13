module Puppet::Parser::Functions
  newfunction(:annotate, :type => :rvalue, :doc => <<-EOS
  Determines the location (file:line) of the declaration for the current
  resource.  Useful for creating links to documentation automaticall from
  Puppet code.

  Doesn't work with the 'include' function (e.g. include sshd) or
  (probably) resources created with create_resources.
  EOS
  ) do |args|
    scope     = self
    resource  = scope.resource
    prefix    = File.realdirpath(environment.manifest).split('/')[0..-3].join('/')
    real_file = if resource.file
      resource.file =~ /spec\/fixtures/ ?
        resource.file : File.realdirpath(resource.file)
    end
    file_name = real_file.gsub(/^#{prefix}\//, '') if real_file =~ /^#{prefix}\//

    if file_name && resource.line
      "https://gitweb.yelpcorp.com/?p=puppet.git;a=blob;f=%s#l%d" % [file_name, resource.line]
    else
      raise(Puppet::ParseError, "annotate couldn't find a file and line; is this an included class?")
    end
  end
end
