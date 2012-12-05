require 'spec_helper'

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
