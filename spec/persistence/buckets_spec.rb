require "spec_helper"

describe FluidFeatures::Persistence::Buckets do
  context "instance" do
    let(:storage) { described_class.create(config["cache"]) }

    describe "#fetch" do
      it "should return [] for empty storage" do
        storage.fetch.should == []
      end

      it "should return [] for empty storage when called with limit" do
        storage.fetch(10).should == []
      end

      it "should return limited set when called with limit" do
        storage.append([["bucket0"], ["bucket1"], ["bucket2"]])
        storage.fetch(2).should == [["bucket0"], ["bucket1"]]
        storage.should_not be_empty
        storage.fetch.should == [["bucket2"]]
        storage.should be_empty

      end

      it "should return limited set when called with limit over of bounds" do
        storage.append([["bucket0"], ["bucket1"], ["bucket2"]])
        storage.fetch(10).should == [["bucket0"], ["bucket1"], ["bucket2"]]
        storage.should be_empty
      end
    end

    describe "#append" do
      it "should append buckets to empty storage" do
        storage.append([["bucket"]]).should be_true
        storage.fetch(10).should == [["bucket"]]
      end

      it "should append buckets to existing buckets" do
        storage.append_one(["bucket0"])
        storage.append([["bucket1"], ["bucket2"]]).should be_true
        storage.fetch(10).should == [["bucket0"], ["bucket1"], ["bucket2"]]
      end

      it "should not append and return false if storage size over the limit" do
        storage.stub!(:file_size).and_return(2)
        storage.stub!(:limit).and_return(1)
        storage.append([["bucket0"], ["bucket1"]]).should be_false
        storage.fetch.should == []
      end
    end

    describe "#append_one" do
      it "should append bucket to empty storage" do
        storage.append_one(["bucket"]).should be_true
        storage.fetch.should == [["bucket"]]
      end

      it "should append bucket to existing buckets" do
        storage.append([["bucket0"], ["bucket1"]])
        storage.append_one(["bucket2"]).should be_true
        storage.fetch(10).should == [["bucket0"], ["bucket1"], ["bucket2"]]
      end

      it "should not append and return false if storage size over the limit" do
        storage.stub!(:file_size).and_return(2)
        storage.stub!(:limit).and_return(1)
        storage.append_one(["bucket"]).should be_false
        storage.fetch.should == []
      end
    end

    describe "#empty?" do
      it "should return true for fresh storage" do
        storage.should be_empty
      end

      it "should return false when storage has buckets" do
        storage.append_one(["bucket"])
        storage.should_not be_empty
      end
    end
  end

  context "null instance" do
    let(:storage) { described_class.create(nil) }

    specify { storage.fetch.should == [] }

    specify { storage.append([["bucket0"], ["bucket1"]]).should == false }

    specify { storage.append_one(["bucket"]).should == false }

    specify { storage.empty?.should == true }
  end
end
