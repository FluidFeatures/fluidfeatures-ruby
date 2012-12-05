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

    end

  end

end
