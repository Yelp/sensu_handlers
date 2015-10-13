require 'spec_helper'

describe "sensu_handlers::mailer" do
  let(:facts) {{
    :osfamily => 'Debian',
    :lsbdistid => 'debian',
  }}
  let(:teams) {{
    'operations' => {}
  }}
  let(:hiera_data) {{
    'sensu_handlers::teams'             => teams,
    'sensu_handlers::mailer::mail_from' => "foo@bar.com"
  }}

  it { should compile }

  describe "dependencies param" do
    context "when left to default" do
      it { should contain_package('nagios-plugins-basic')      }
      it { should contain_package('mail').with_provider('gem') }

      context "with use_embeded_ruby set in sensu_handlers" do
        let(:pre_condition) do
          %( class {'sensu_handlers':  use_embedded_ruby => true } )
        end
        it { should contain_package('mail').with_provider('sensu_gem') }
      end
    end

    context "when empty hash" do
      let(:params) {{ :dependencies => {} }}
      it { should_not contain_package('nagios-plugins-basic') }
      it { should_not contain_package('mail')                 }
    end

    context "when passed override" do
      let(:params) {{
        :dependencies => { 'foo' => { 'provider' => 'bar' } }
      }}
      it { should_not contain_package('nagios-plugins-basic') }
      it { should_not contain_package('mail')                 }
      it { should contain_package('foo').with_provider('bar') }
    end

  end
end
