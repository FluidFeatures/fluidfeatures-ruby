require "spec_helper"

describe FluidFeatures::AppFeatureVersion do

  let(:app) { mock "FluidFeatures::App", client: mock("client", uuid: 'client uuid'), logger: mock('logger') }

  before(:each) do
    app.stub!(:is_a?).and_return(false)
    app.stub!(:is_a?).with(FluidFeatures::App).and_return(true)
  end

  context "initialization" do

    it "should raise error if invalid application passed" do
      app.stub!(:is_a?).with(FluidFeatures::App).and_return(false)
      expect { described_class.new(app, "Feature", "a") }.to raise_error /app invalid/
    end

    it "should raise error if invalid feature name passed" do
      expect { described_class.new(app, 0, "a") }.to raise_error /feature_name invalid/

    end

    it "should raise error if invalid version name passed" do
      expect { described_class.new(app, "Feature", 0) }.to raise_error /version_name invalid/
    end

    it "should use default version name if omitted" do
      described_class.new(app, "Feature").version_name.should == described_class::DEFAULT_VERSION_NAME
    end

    it "should initialize instance variables with passed values" do
      feature = described_class.new(app, "Feature", "a")
      feature.app.should == app
      feature.feature_name.should == "Feature"
      feature.version_name.should == "a"
    end

  end

  describe "#set_enabled_percent" do

    let(:feature) { described_class.new(app, "Feature", "a") }

    ["50", 120, -12.2, nil].each do |invalid_percent|
      it "should raise error if '#{invalid_percent}' passed as percentage value" do
        expect { feature.set_enabled_percent(invalid_percent) }.to raise_error /percent invalid/
      end
    end

    it "should update percentage on server" do
      app.should_receive(:put).with("/feature/Feature/a/enabled/percent", {:enabled=>{:percent=>44}})
      feature.set_enabled_percent(44)
    end

  end

end
