# encoding: utf-8
require 'spec_helper'

describe Quandl::Operation::Transform do
  
  describe "#perform" do
    it "should rdiff_from" do
      data = [[1,3,5],[4,5,4],[5,15,20]]
      result = Quandl::Operation::Transform.perform(data, :rdiff_from)
      result.should eq [[1,4,3],[4,2,4],[5,0,0]]      
    end
    it "should cumul asc" do
      data = [[1000, 10], [1001, 20], [1002, 30]]
      result = Quandl::Operation::Transform.perform(data, :cumul)
      result.should eq [[1000, 10], [1001, 30], [1002, 60]]
    end
    it "should cumul desc" do
      data = [[1002, 30], [1001, 20], [1000, 10]]
      result = Quandl::Operation::Transform.perform(data, :cumul)
      result.should eq [[1002, 60], [1001, 30], [1000, 10]]
    end
    
  end
  
end