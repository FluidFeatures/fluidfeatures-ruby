require "spec_helper"

describe FluidFeatures::Config do
  let(:path) { "#{File.dirname(__FILE__)}/fixtures/fluidfeatures.yml" }

  let(:env) { "development" }

  let(:replacements) { {} }

  let(:config) { FluidFeatures::Config.new(path, env, replacements) }

  context "parse file size" do
    [nil, 1024, "foo"].each do |input|
      it "should pass #{input.class.to_s} through" do
        described_class.parse_file_size(input).should == input
      end
    end

    { "1Kb" => 1024, "2mb" => 2097152, "2GB" => 2147483648}.each do |i, o|
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
            "baseuri" => "baseuri",
            "cache" => { "enable" => false, "dir" => "cache_dir", "limit" => 2097152 },
            "appid" => "#{env_name}_appid",
            "secret" => "#{env_name}_secret"
        }
      end

      context "and incorrect path" do
        let(:path) { "#{File.dirname(__FILE__)}/fixtures/not_correct.yml" }
        it "should return empty hash" do
          config.vars.should == {}
        end
      end

      context "and replacements" do
        let(:replacements) { { "baseuri" => "env_baseuri", "appid" => "env_appid", "secret" => "env_secret" } }

        it "should update variables with passed hash" do
          config.vars.should == {
              "baseuri" => "env_baseuri",
              "cache" => { "enable" => false, "dir" => "cache_dir", "limit" => 2097152 },
              "appid" => "env_appid",
              "secret" => "env_secret"
          }
        end
      end
    end
  end
end
