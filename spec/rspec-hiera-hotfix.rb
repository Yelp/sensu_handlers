#
# Monkey-patch rspec-puppet to hotfix https://github.com/rodjek/rspec-puppet/issues/137
# This reverts commit https://github.com/rodjek/rspec-puppet/commit/b04e7c5e23ebb3f0a8293a29757bb649c89db262
#
module RSpec::Puppet
  module Support
    def setup_puppet
      vardir = Dir.mktmpdir
      Puppet[:vardir] = vardir

      [
        %i[modulepath module_path],
        %i[manifestdir manifest_dir],
        %i[manifest manifest],
        %i[templatedir template_dir],
        %i[config config],
        %i[confdir confdir],
        %i[hiera_config hiera_config]
      ].each do |a, b|
        next unless Puppet[a]
        Puppet[a] = if respond_to? b
                      send(b)
                    else
                      RSpec.configuration.send(b)
                    end
      end

      Puppet[:libdir] = Dir["#{Puppet[:modulepath]}/*/lib"].entries.join(File::PATH_SEPARATOR)
      vardir
    end
  end
end
