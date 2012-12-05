require "spec_helper"

describe FluidFeatures::App do

  let(:client) { mock("client") }

  let(:app) { FluidFeatures::App.new(client, "id", "secret", Logger.new(STDERR)) }

  before(:each) do
    client.stub!(:is_a?).and_return(false)
    client.stub!(:is_a?).with(FluidFeatures::Client).and_return(true)
    FluidFeatures::AppState.stub!(:new)
    FluidFeatures::AppReporter.stub!(:new)
  end

  context "initialization" do

    it "should raise error if invalid client passed" do
      client.stub!(:is_a?).with(FluidFeatures::Client).and_return(false)
      expect { described_class.new(client, "", "", Logger.new(STDERR)) }.to raise_error /client invalid/
    end

    it "should raise error if invalid app id passed" do
      expect { described_class.new(client, 0, "", Logger.new(STDERR)) }.to raise_error /app_id invalid/
    end

    it "should raise error if invalid secret passed" do
      expect { described_class.new(client, "", 0, Logger.new(STDERR)) }.to raise_error /secret invalid/
    end

    it "should initialize instance variables with passed values" do
      app = described_class.new(client, "id", "secret", Logger.new(STDERR))
      app.client.should == client
      app.app_id.should == "id"
    end

    it "should start up reporter runner" do
      FluidFeatures::AppState.should_receive(:new).with(app)
      app
    end

    it "should start up state runner" do
      FluidFeatures::AppReporter.should_receive(:new).with(app)
      app
    end
  end

  it "#get should proxy to client" do
    client.should_receive(:get).with("/app/id/url", "secret", nil, false)
    app.get("/url")
  end

  it "#put should proxy to client" do
    client.should_receive(:put).with("/app/id/url", "secret", "payload")
    app.put("/url", "payload")
  end

  it "#post should proxy to client" do
    client.should_receive(:post).with("/app/id/url", "secret", "payload")
    app.post("/url", "payload")
  end

  it "#feature should get features" do
    app.should_receive(:get).with("/features")
    app.features
  end

  it "#user should create user" do
    attrs = ["user id", "John Doe", false, {}, {}]
    FluidFeatures::AppUser.should_receive(:new).with(*[app] + attrs)
    app.user(*attrs)
  end

  it "#user_transaction should return user transaction" do
    attrs = ["user id", "/url", "John Doe", false, {}, {}]
    transaction = mock('transaction')
    transaction.should_receive(:transaction).with("/url")
    app.should_receive(:user).with(*attrs.reject {|a| a == '/url'}).and_return(transaction)
    app.user_transaction(*attrs)
  end

  it "#feature_version should create version" do
    attrs = ["Feature", "a"]
    FluidFeatures::AppFeatureVersion.should_receive(:new).with(*[app] + attrs)
    app.feature_version(*attrs)
  end

end
