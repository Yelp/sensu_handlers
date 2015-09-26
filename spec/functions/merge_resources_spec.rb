require 'spec_helper'
describe 'merge_resources', :type => :function do
  # these facts are required because the fixtures top scope
  # manifest includes the apt class
  let(:facts) {{
    :osfamily => 'Debian',
    :lsbdistid => 'debian',
  }}

  it "requires two arguments" do
    should run.with_params() \
      .and_raise_error(/wrong number of args/)

    should run.with_params(:one) \
      .and_raise_error(/wrong number of args/)

    should run.with_params(:one,:two,:three) \
      .and_raise_error(/wrong number of args/)

    should run.with_params({},{})
  end

  it "requires two hashes" do
    should run.with_params(:one,:two) \
      .and_raise_error(/expected resource hash/)

    should run.with_params({}, :two) \
      .and_raise_error(/expected resource hash/)

    should run.with_params(:one,{}) \
      .and_raise_error(/expected resource hash/)

    should run.with_params({},{})
  end

  let(:defaults) {{
    'title1' => {
      'param1' => 'value1',
      'param2' => 'value2'
    },
    'title2' => { 'param' => 'value2' }
  }}

  context "with matching key in override" do
    let(:override) {{
      'title1' => {
        'param1' => 'value3',
        'thing'  => 'value3'
      }
    }}

    it "merges those two values" do
      should run.with_params(override,defaults) \
        .and_return({
          'title1' => {
            'param1' => 'value3',
            'param2' => 'value2',
            'thing'  => 'value3'
          },
          'title2' => { 'param' => 'value2' }
        })
    end
  end

  context "non matching key in overrides" do
    let(:override) {{
      'title3' => { 'thing' => 'value3' }
    }}
    it "is merged in with results" do
      should run.with_params(override,defaults) \
        .and_return({
          'title1' => {
            'param1' => 'value1',
            'param2' => 'value2'
          },
          'title2' => { 'param' => 'value2' },
          'title3' => { 'thing' => 'value3' }
        })
    end
  end

  context "key in overrides who's value is undef" do
    let(:override) {{
      'title3' => :undef,
      'title1' => :undef,
    }}
    it "removes that key from the results" do
      should run.with_params(override,defaults) \
        .and_return({
          'title2' => { 'param' => 'value2' }
        })
    end
  end

  context "undef from puppet manifests" do
    # flip back into catalog as subject mode
    let(:subject) { lambda { catalogue } }
    let(:pre_condition) do
      <<-EOM
        create_resources(file, merge_resources({
          '/extra'    => { owner => 'extra' },
          '/knockout' => undef
        }, {
          '/knockout' => { owner => 'knockout' },
          '/default'  => { owner => 'default' },
        }))
      EOM
    end
    it { should     contain_file('/default')  }
    it { should     contain_file('/extra')    }
    it { should_not contain_file('/knockout') }
  end

end
