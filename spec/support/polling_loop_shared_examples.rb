shared_examples "polling loop" do
  let(:app) { mock "FluidFeatures::App" }

  before(:each) do
    app.stub!(:is_a?).and_return(false)
    app.stub!(:is_a?).with(FluidFeatures::App).and_return(true)
    FluidFeatures.stub(:config).and_return(config)
  end

  context "initialization" do
    before(:each) do
      described_class.any_instance.stub(:configure)
      described_class.any_instance.stub(:run_loop)
    end

    it "should log error if no valid app passed" do
      expect { described_class.new(nil) }.to raise_error(/app invalid/)
    end

    it "should configure instance variables" do
      described_class.any_instance.should_receive(:configure).with(app)
      described_class.new(app)
    end

    it "should not call #run_loop" do
      described_class.any_instance.should_not_receive(:run_loop)
      described_class.new(app)
    end
  end

  it "should initialize @app" do
    described_class.new(app).app.should == app
  end
end
