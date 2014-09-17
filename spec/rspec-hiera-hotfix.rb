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
        [:modulepath, :module_path],
        [:manifestdir, :manifest_dir],
        [:manifest, :manifest],
        [:templatedir, :template_dir],
        [:config, :config],
        [:confdir, :confdir],
        [:hiera_config, :hiera_config],
      ].each do |a, b|
        if Puppet[a]
          if self.respond_to? b
            Puppet[a] = self.send(b)
          else
            Puppet[a] = RSpec.configuration.send(b)
          end
        end
      end

      Puppet[:libdir] = Dir["#{Puppet[:modulepath]}/*/lib"].entries.join(File::PATH_SEPARATOR)
      vardir
    end
  end
end
