require 'spec_helper'

describe FluidFeatures::AppReporter do

  it_should_behave_like "polling loop", :send_transactions do
    before(:each) { described_class.any_instance.stub(:transactions_queued?).and_return(true) }
  end

  context do

    let(:reporter) { described_class.new(app) }

    let(:user) { mock('user', unique_id: 'unique id', display_name: 'John Doe', anonymous: false, unique_attrs: [], cohort_attrs: []) }

    let(:transaction) { mock('transaction', url: 'http://example.com/source.html', duration: 999, user: user, unknown_features: [], features_hit: %w[feature], goals_hit: %w[goal]) }

    before(:each) do
      described_class.any_instance.stub(:run_loop)
      FluidFeatures.stub(:config).and_return(config)
    end

    describe "#features_storage" do
      before(:each) do
        described_class.any_instance.stub(:configure)
        FluidFeatures::Persistence::Features.should_receive(:create).with(config["cache"]).twice
        .and_return(FluidFeatures::Persistence::NullFeatures.new)
      end

      it "should create features storage" do
        reporter.features_storage
      end

      it "should not call create twice" do
        reporter.features_storage
        reporter.features_storage
      end
    end

    describe "#buckets_storage" do
      before(:each) do
        described_class.any_instance.stub(:configure)
        FluidFeatures::Persistence::Buckets.should_receive(:create).with(config["cache"])
        .and_return(FluidFeatures::Persistence::NullBuckets.new)
      end

      it "should create buckets storage" do
        reporter.buckets_storage
      end

      it "should not call create twice" do
        reporter.buckets_storage
        reporter.buckets_storage
      end
    end

    describe "#configure" do
      let(:features_storage) { mock("features_storage") }
      let(:buckets_storage) { mock("buckets_storage") }
      let(:bucket) { mock("bucket") }

      before(:each) do
        reporter.stub!(:features_storage).and_return(features_storage)
        reporter.stub!(:buckets_storage).and_return(buckets_storage)
        reporter.stub!(:last_or_new_bucket)
        features_storage.stub!(:list_unknown)
        buckets_storage.stub!(:fetch)
      end

      it "should assign result of buckets_storage.fetch to @buckets" do
        buckets = mock("buckets")
        buckets_storage.should_receive(:fetch).with(described_class::MAX_BUCKETS).and_return(buckets)
        reporter.configure(app)
        reporter.instance_variable_get(:@buckets).should == buckets
      end

      it "should assign result of last_or_new_bucket to @current_bucket" do
        reporter.should_receive(:last_or_new_bucket).and_return(bucket)
        reporter.configure(app)
        reporter.instance_variable_get(:@current_bucket).should == bucket
      end

      it "should assign result of features_storage.list_unknown to @unknown_features" do
        features = mock("features")
        features_storage.should_receive(:list_unknown).and_return(features)
        reporter.configure(app)
        reporter.instance_variable_get(:@unknown_features).should == features
      end
    end

    describe "last_or_new_bucket" do
      it "should return new bucket if buckets empty" do
        reporter.instance_variable_set(:@buckets, [])
        reporter.should_receive(:new_bucket).and_return([])
        reporter.last_or_new_bucket.should == []
      end

      it "should return new bucket if last bucket is full" do
        bucket = mock("bucket")
        bucket.should_receive(:size).and_return(described_class::MAX_BUCKET_SIZE + 1)
        reporter.instance_variable_set(:@buckets, [bucket])
        reporter.should_receive(:new_bucket).and_return([])
        reporter.last_or_new_bucket.should == []
      end

      it "should return last bucket of buckets" do
        bucket = mock("bucket")
        bucket.should_receive(:size).and_return(described_class::MAX_BUCKET_SIZE - 1)
        reporter.instance_variable_set(:@buckets, [bucket])
        reporter.should_not_receive(:new_bucket)
        reporter.last_or_new_bucket.should == bucket
      end
    end

    describe "#report_transaction" do
      before(:each) do
        reporter.stub!(:queue_transaction_payload)
        reporter.stub!(:queue_unknown_features)
      end

      it "should queue transaction payload" do
        reporter.should_not_receive(:queue_unknown_features)
        reporter.should_receive(:queue_transaction_payload).with(
            url: "http://example.com/source.html",
            user: { id: "unique id", name: "John Doe", unique: [], cohorts: [] },
            hits: { feature: ["feature"], goal: ["goal"] },
            stats: { duration: 999 }
        )
        reporter.report_transaction(transaction)
      end

      it "should queue unknown features if any" do
        transaction.stub!(:unknown_features).and_return(%w[feature])
        reporter.should_receive(:queue_unknown_features).with(transaction.unknown_features)
        reporter.report_transaction(transaction)
      end
    end

    describe "#transactions_queued?" do
      before(:each) do
        reporter.configure(app)
      end

      it "should return false if no transaction queued" do
        reporter.transactions_queued?.should be_false
      end

      it "should return true if at least one transaction queued" do
        reporter.instance_variable_set(:@buckets, %w[bucket])
        reporter.instance_variable_set(:@current_bucket, %w[payload])
        reporter.transactions_queued?.should be_true
      end
    end

    describe "#queue_transaction_payload" do
      it "should push transaction payload to current bucket" do
        reporter.instance_variable_set(:@current_bucket, [])
        reporter.queue_transaction_payload({ foo: 'bar' })
        reporter.instance_variable_get(:@current_bucket).should == [{ foo: 'bar' }]
      end

      it "should create new bucket if current bucket is full" do
        reporter.instance_variable_set(:@current_bucket, [])
        current_bucket = reporter.instance_variable_get(:@current_bucket)
        current_bucket.stub!(:size).and_return(described_class::MAX_BUCKET_SIZE + 1)
        reporter.should_receive(:new_bucket).and_return([])
        reporter.queue_transaction_payload({ foo: 'bar' })
      end
    end

    describe "#queue_unknown_features" do
      let(:unknown_features) { { "feature" => { "a" => true } } }

      it "should add unknown_features to instance variable" do
        reporter.queue_unknown_features(unknown_features)
        reporter.instance_variable_get(:@unknown_features).should == unknown_features
      end

      it "should raise error if unknown_features is not Hash" do
        expect { reporter.queue_unknown_features("not cool") }.to raise_error /should be a Hash/
      end

      it "should raise error if versions is not Hash" do
        expect { reporter.queue_unknown_features("feature" => "not cool") }.to raise_error /should be a Hash/
      end
    end

    describe "#send_transactions" do
      let(:unknown_features) { { "feature" => { "a" => true } } }

      let(:app) { mock "FluidFeatures::App", client: mock("client", uuid: 'client uuid'), logger: mock('logger') }

      before(:each) do
        app.stub!(:is_a?).and_return(false)
        app.stub!(:is_a?).with(FluidFeatures::App).and_return(true)
        app.client.stub(:siphon_api_request_log).and_return("api log")
        app.stub!(:post)
        reporter.stub(:remove_bucket).and_return(["transactions"])
        reporter.instance_variable_set(:@unknown_features, unknown_features)
        reporter.instance_variable_set(:@buckets, [%w[one], %w[one two]])
      end

      it "should send transaction to server" do
        app.should_receive(:post).with("/report/transactions", :client_uuid=>"client uuid", :transactions=>["transactions"], :stats=>{:waiting_buckets=>[1, 2]}, :unknown_features=>{"feature"=>{"a"=>true}}, :api_request_log=>"api log").and_return(true)
        reporter.send_transactions
      end

      it "should emit warning and queue unknown features on failure" do
        app.stub!(:post).and_return(false)
        reporter.stub!(:unremove_bucket).and_return(false)
        app.logger.should_receive(:warn)
        reporter.should_receive(:queue_unknown_features).with(unknown_features)
        reporter.send_transactions
      end

      it "should reset unknown features in storage on success" do
        app.stub!(:post).and_return(true)
        reporter.features_storage.should_receive(:replace_unknown).with({})
        reporter.send_transactions
      end
    end

    describe "#new_bucket" do
      let(:buckets) { [] }

      before(:each) do
        reporter.instance_variable_set(:@buckets, buckets)
      end

      it "should append first bucket to storage if over the limit" do
        buckets.stub!(:size).and_return(described_class::MAX_BUCKETS + 1)
        reporter.buckets_storage.should_receive(:append_one).with([])
        reporter.new_bucket
      end

      it "should append first bucket to storage if" do
        buckets.stub!(:size).and_return(described_class::MAX_BUCKETS - 1)
        reporter.buckets_storage.should_not_receive(:append)
        reporter.new_bucket
      end
    end

    describe "#remove_bucket" do
      let(:buckets) { [] }

      before(:each) do
        reporter.instance_variable_set(:@buckets, buckets)
      end

      it "should load buckets from storage if buckets empty and something in storage" do
        buckets.stub!(:empty?).and_return(true)
        reporter.buckets_storage.stub!(:empty?).and_return(false)
        reporter.buckets_storage.should_receive(:fetch).and_return(buckets)
        reporter.remove_bucket
      end

      it "should not load buckets if buckets not empty" do
        buckets.stub!(:empty?).and_return(false)
        reporter.buckets_storage.stub!(:empty?).and_return(false)
        reporter.buckets_storage.should_not_receive(:fetch)
        reporter.remove_bucket
      end

      it "should not load buckets if storage empty" do
        buckets.stub!(:empty?).and_return(true)
        reporter.buckets_storage.stub!(:empty?).and_return(true)
        reporter.buckets_storage.should_not_receive(:fetch)
        reporter.remove_bucket
      end
    end

    describe "#unremove_bucket" do
      let(:buckets) { [] }

      let(:bucket) { mock("bucket") }

      before(:each) do
        reporter.instance_variable_set(:@buckets, buckets)
      end

      it "should offload bucket to storage if buckets over limit" do
        buckets.stub!(:size).and_return(described_class::MAX_BUCKETS + 1)
        reporter.buckets_storage.should_receive(:append_one).with(bucket)
        reporter.unremove_bucket(bucket)
      end

      it "should not offload bucket to storage if buckets under limit" do
        buckets.stub!(:size).and_return(described_class::MAX_BUCKETS - 1)
        reporter.buckets_storage.should_not_receive(:append)
        reporter.unremove_bucket(bucket)
      end
    end
  end
end
