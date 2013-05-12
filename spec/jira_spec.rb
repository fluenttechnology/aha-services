require 'spec_helper'
require 'faraday'

describe "Service::Jira" do
  before do
    @stubs = Faraday::Adapter::Test::Stubs.new
  end

  it "can receive new features" do
    @stubs.post "/a/rest/api/a/issue" do |env|
      env[:request_headers]['Content-Type'].should == 'application/json'
      env[:url].host.should == 'foo.com'
      [200, {}, '']
    end

    svc = service(Service::Jira, 
      {'server_url' => 'http://foo.com/a', 'username' => 'u', 'password' => 'p', 'api_version' => 'a'},
      new_feature_payload)
    svc.receive_create_feature
  end
  
end