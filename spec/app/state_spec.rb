require 'spec_helper'
require "fluidfeatures/persistence/buckets"
require "fluidfeatures/persistence/features"

describe FluidFeatures::AppState do

  it_should_behave_like "polling loop", :load_state

  context do
    let(:state) { described_class.new(app) }

    let(:features) { { "feature" => { "a" => true } } }

    let(:app) { mock "FluidFeatures::App", client: mock("client", uuid: 'client uuid'), logger: mock('logger') }

    before(:each) do
      app.stub!(:is_a?).and_return(false)
      app.stub!(:is_a?).with(FluidFeatures::App).and_return(true)
      described_class.any_instance.stub(:run_loop)
      FluidFeatures.stub(:config).and_return(config)
    end

    describe "#features_storage" do
      before(:each) do
        described_class.any_instance.stub(:configure)
        FluidFeatures::Persistence::Features.should_receive(:create).with(config["cache"])
        .and_return(FluidFeatures::Persistence::NullFeatures.new)
      end

      it "should create features storage" do
        state.features_storage
      end

      it "should not call create twice" do
        state.features_storage
        state.features_storage
      end
    end

    describe "#configure" do
      let(:features_storage) { mock("features_storage") }

      before(:each) do
        state.stub!(:features_storage).and_return(features_storage)
      end

      it "should assign result of features_storage.list to @features" do
        features = mock("features")
        features_storage.should_receive(:list).and_return(features)
        state.configure(app)
        state.instance_variable_get(:@features).should == features
      end
    end

    describe "#features=" do
      it "should replace features if there are changes" do
        state.features_storage.should_receive(:replace).with({foo: "bar"})
        state.features = {foo: "bar"}
      end

      it "should not replace features if not amended" do
        state.features_storage.should_not_receive(:replace)
        state.features = {}
      end
    end

    describe "#load_state" do
      before(:each) do
        app.stub!(:get)
      end

      it "should return false if getting state from server failed" do
        app.stub!(:get).and_return(false, nil)
        state.load_state.should == [false, nil]
      end

      it "should return true and state if getting state from server succeeded" do
        app.stub!(:get).and_return([true, {
            "feature" => { "versions" => { "a" => { "parts" => [1, 2, 3] } } }
        }])
        state.load_state.should == [true, "feature" => { "versions" => { "a" => { "parts" => Set.new([1, 2, 3]) } } }]
      end
    end

    describe "#feature_version_enabled_for_user" do
      let(:features) { { "Feature" => { "num_parts" => 3, "versions" => { "a" => { "parts" => [1, 3, 5], "enabled" => { "attributes" => { "key" => ["id"] }} } } } } }

      before(:each) do
        state.stub!(:features).and_return features
      end

      it "should raise error if feature name is invalid" do
        expect { state.feature_version_enabled_for_user(0, "a", "123") }.to raise_error /feature_name invalid/
      end

      it "should raise error if version name is invalid" do
        expect { state.feature_version_enabled_for_user("Feature", 0, "123") }.to raise_error /version_name invalid/
      end

      it "should return true if user id/parts number modulus included in feature parts" do
        state.feature_version_enabled_for_user("Feature", "a", 4).should be_true
      end

      it "should return true if string user id/parts number modulus included in feature parts" do
        state.feature_version_enabled_for_user("Feature", "a", "4").should be_true
      end

      it "should return false if user id/parts number modulus not included in feature parts" do
        state.feature_version_enabled_for_user("Feature", "a", 5).should be_false
      end

      it "should return true if stated implicitly" do
        state.feature_version_enabled_for_user("Feature", "a", 5, { "key" => "id" }).should be_true
      end
    end
  end
end
