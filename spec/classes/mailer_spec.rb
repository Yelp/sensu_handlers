describe "sensu_handlers::mailer" do
  let(:facts) {{
    :osfamily => 'Debian',
    :lsbdistid => 'debian',
  }}
  let(:teams) {{
    'operations' => {}
  }}
  let(:hiera_data) {{
    'sensu_handlers::teams' => teams
  }}

  it { should compile }

  describe "dependencies param" do
    context "when left to default" do
      it { should contain_package('nagios-plugins-basic')      }
      it { should contain_package('mail').with_provider('gem') }
    end
    context "when false" do
      let(:params) {{ :dependencies => false }}
      it { should_not contain_package('nagios-plugins-basic')      }
      it { should_not contain_package('mail').with_provider('gem') }
    end

    context "with knockouts" do
      context "with mail set to undef" do
        # hack enable next hack
        let(:params)    { true }
        # next hack, rspec-puppet #param_str can't create param undef
        let(:param_str) { 'dependencies => { mail => undef }' }

        it { should     contain_package('nagios-plugins-basic')      }
        it { should_not contain_package('mail').with_provider('gem') }
      end
    end

    context "with package level overrides" do
      let(:params)    { true }
      let(:param_str) { 'dependencies => { mail => { provider => "foo" }}' }

      it { should contain_package('nagios-plugins-basic')      }
      it { should contain_package('mail').with_provider('foo') }
    end

  end
end
