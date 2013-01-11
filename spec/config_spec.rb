require "spec_helper"
require 'fluidfeatures/exceptions'

describe FluidFeatures::Config do
  let(:source) { "#{File.dirname(__FILE__)}/fixtures/fluidfeatures.yml" }

  let(:env) { "development" }

  let(:config) { FluidFeatures::Config.new(source, env) }

  context "parse file size" do
    [nil, "foo", Object.new, Object, [], {} ].each do |input|
      it "should raise exception for non-matching #{input.class.to_s} #{input||'nil'}" do
        expect { described_class.parse_file_size(input) }
          .to raise_error(FFeaturesConfigInvalid)
      end
    end

    { "1Kb" => 1024, "2mb" => 2097152, "2GB" => 2147483648}.each do |i, o|
      it "should read '#{i}' as #{o}" do
        described_class.parse_file_size(i).should == o
      end
    end

    { "123" => 123, "456" => 456 }.each do |i, o|
      it "should read '#{i}' as #{o}" do
        described_class.parse_file_size(i).should == o
      end
    end
  end

  %w{test development production}.each do |env_name|
    context "with #{env_name} environment" do
      let(:env) { env_name }

      it "should load environment configuration from yml file and merge common section" do
        config.vars.should == {
            "base_uri" => "base_uri",
            "cache" => { "enable" => false, "dir" => "cache_dir", "limit" => 2097152 },
            "app_id" => "#{env_name}_app_id",
            "secret" => "#{env_name}_secret"
        }
      end
    end
  end

  context "with hash config" do
    let(:source) { { "base_uri" => "env_base_uri", "app_id" => "env_app_id", "secret" => "env_secret" } }

    it "should update variables with passed hash" do
      config.vars.should == {
        "base_uri" => "env_base_uri",
        "app_id" => "env_app_id",
        "secret" => "env_secret"
      }
    end
  end

end
