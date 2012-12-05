require 'spec_helper'

describe FluidFeatures::AppUserTransaction do

  let(:user) { mock "user" }
  let(:features) { { "Feature" => { "num_parts" => 3, "a" => { "parts" => [1, 3, 5], "enabled" => { "attributes" => { "key" => ["id"] } } }, "versions" => { "a" => { "parts" => [1, 3, 5], "enabled" => { "attributes" => { "key" => ["id"] } } } } } } }
  let(:transaction){ described_class.new(user, "/url") }

  before(:each) do
    user.stub!(:features).and_return(features)
    user.stub!(:is_a?).and_return(false)
    user.stub!(:is_a?).with(FluidFeatures::AppUser).and_return(true)
    transaction.stub(:ended).and_return(false)
  end

  it "should initialize instance variables with passed values" do
    transaction.user.should == user
    transaction.url.should == "/url"
  end

  describe "#feature_enabled?" do

    it "should add known feature to features hit" do
      transaction.should_not_receive(:unknown_feature_hit)
      transaction.feature_enabled?("Feature", "a", true)
      transaction.features_hit["Feature"]["a"].should == Hash.new
    end

    it "should call unknown_feature_hit for unknown feature" do
      transaction.should_receive(:unknown_feature_hit).with("Feature", "b", true)
      transaction.feature_enabled?("Feature", "b", true)
    end

    it "should raise error if transaction ended" do
      transaction.stub!(:ended).and_return(true)
      expect { transaction.feature_enabled?("Feature", "a", true) }.to raise_error /transaction ended/
    end

    it "should raise error if feature name invalid" do
      expect { transaction.feature_enabled?(0, "a", true) }.to raise_error /feature_name invalid/
    end
  end

  describe "#unknown_feature_hit" do

    it "should add passed feature to feature hits" do
      transaction.unknown_feature_hit("Feature", "a", true)
      transaction.unknown_features["Feature"]["a"].should == true
    end

    it "should raise error if transaction ended" do
      transaction.stub!(:ended).and_return(true)
      expect { transaction.unknown_feature_hit("Feature", "a", true) }.to raise_error /transaction ended/
    end

  end

  describe "#goal_hit" do

    it "should add passed goal to goal hits" do
      transaction.goal_hit("Goal", "default")
      transaction.goals_hit["Goal"]["default"].should == Hash.new
    end

    it "should raise error if transaction ended" do
      transaction.stub!(:ended).and_return(true)
      expect { transaction.goal_hit("Goal", "default") }.to raise_error /transaction ended/
    end

    it "should raise error if goal name invalid" do
      expect { transaction.goal_hit(0, "default") }.to raise_error /goal_name invalid/
    end

    it "should raise error if goal version name invalid" do
      expect { transaction.goal_hit("Goal", 0) }.to raise_error /goal_version_name invalid/
    end

  end

  describe "#duration" do
    it "should calculate difference between now and transaction start" do
      now = Time.now
      start_time = now - 3600
      Time.stub!(:now).and_return(now)
      transaction.stub!(:start_time).and_return(start_time)
      transaction.duration.should == 3600
    end

    it "should return saved duration if ended" do
      transaction.stub!(:ended).and_return(true)
      transaction.instance_variable_set(:@duration, 60)
      transaction.duration.should == 60
    end
  end

  describe "#end_transaction" do
    let!(:reporter) { mock("reporter") }

    before(:each) do
      transaction.stub_chain(:user, :app, :reporter).and_return(reporter)
      reporter.stub!(:report_transaction)
    end

    it "should raise error if transaction ended" do
      transaction.stub!(:ended).and_return(true)
      expect { transaction.end_transaction }.to raise_error /transaction ended/
    end

    it "should report transaction" do
      reporter.should_receive(:report_transaction).with(transaction)
      transaction.end_transaction
    end

    it "should save duration at transaction end" do
      transaction.should_receive(:duration).and_return(100)
      transaction.end_transaction
      transaction.instance_variable_get(:@duration).should == 100
    end

    it "should mark transaction ended" do
      transaction.end_transaction
      transaction.instance_variable_get(:@ended).should be_true
    end

  end

end