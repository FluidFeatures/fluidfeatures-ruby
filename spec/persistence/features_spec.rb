require "spec_helper"

describe FluidFeatures::Persistence::Features do
  context "instance" do
    let(:storage) { described_class.create(config["cache"]) }

    it "#list should return all features" do
      storage.replace({ feature: "foo" })
      storage.list.should == ({ feature: "foo" })
    end

    it "#replace should replace features with passed hash" do
      storage.replace({ feature: "foo" }).should == true
    end

    it "#list_unknown should return unknown_features features" do
      storage.replace_unknown({ feature: "foo" })
      storage.list_unknown.should == ({ feature: "foo" })
    end

    it "#replace_unknown should replace unknown_features with passed hash" do
      storage.replace_unknown({ feature: "foo" }).should == true
    end
  end

  context "null instance" do
    let(:storage) { described_class.create(nil) }

    specify { storage.list.should == {} }

    specify { storage.list_unknown.should == {} }

    specify { storage.replace([["bucket0"], ["bucket1"]]).should == false }

    specify { storage.replace_unknown([["bucket0"], ["bucket1"]]).should == false }
  end
end