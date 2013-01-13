require "spec_helper"

describe FluidFeatures::AppUser do

  let(:app) { mock "app", state: mock('state'), client: mock("client", uuid: 'client uuid'), logger: mock('logger') }
  let(:user_params) { [app, "user_id", "John Doe", false, {}, {}] }
  let(:user) { described_class.new(*user_params) }

  before(:each) do
    app.stub!(:is_a?).and_return(false)
    app.stub!(:is_a?).with(FluidFeatures::App).and_return(true)
  end

  context "initialization" do

    it "should raise error if invalid application passed" do
      app.stub!(:is_a?).with(FluidFeatures::App).and_return(false)
      expect { described_class.new(*user_params) }.to raise_error /app invalid/
    end

    it "should initialize instance variables with passed values" do
      user.app.should == app
      user.unique_id.should == "user_id"
      user.display_name.should == "John Doe"
      user.anonymous.should be_false
      user.unique_attrs = {}
      user.cohort_attrs = {}
    end

    it "should generate id for anonymous user" do
      user = described_class.new(app, nil, "John Doe", true, {}, {})
      user.unique_id.should match /anon-/
    end
  end

  it "#get should proxy to app" do
    app.should_receive(:get).with("/user/user_id/url", nil)
    user.get("/url")
  end

  it "#post should proxy to app" do
    app.should_receive(:post).with("/user/user_id/url", "payload")
    user.post("/url", "payload")
  end

  describe "#features" do
    let(:features) { { "Feature" => { "num_parts" => 3, "versions" => { "a" => { "parts" => [1, 3, 5], "enabled" => { "attributes" => { "key" => ["id"] }} } } } } }

    it "should get features from state" do
      ENV["FLUIDFEATURES_USER_FEATURES_FROM_API"] = nil
      app.should_not_receive(:get)
      app.state.should_receive(:features).and_return(features)
      app.state.should_receive(:feature_version_enabled_for_user).and_return(true)
      user.features.should == { "Feature" => { "a" => true } }
    end

=begin
    it "should get features from api if env variable set" do
      ENV["FLUIDFEATURES_USER_FEATURES_FROM_API"] = "true"
      app.should_receive(:get).with("/user/user_id/features", {:anonymous=>"false"})
      user.features
    end
=end

  end

  it "#transaction should create transaction" do
    FluidFeatures::AppUserTransaction.should_receive(:new).with(user, "/url")
    user.transaction("/url")
  end
end
