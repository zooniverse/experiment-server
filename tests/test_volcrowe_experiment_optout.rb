# Note: These are not really unit tests - in fact they are external tests.
# They assume you have already started a server with:
#   SUGAR_HOST=... SUGAR_USERNAME=... SUGAR_PASSWORD=`...` ruby server.rb -o 0.0.0.0
# (or modify this IP if you change @@SERVER_URL)

require "test/unit"
require 'net/http'
require 'uri'
require_relative '../experiments/comet_hunters_volcrowe_experiment.rb'
require 'json'

class TestVolcroweExperimentOptOut < Test::Unit::TestCase

    include PlanOut

    @@SERVER_URL = "http://localhost:4567"
    @@TEST_CONTROL_USER_ID = "TEST_USER"
    @@TEST_STATEMENTS_USER_ID = "TEST_USER_1"
    @@TEST_QUESTIONS_USER_ID = "TEST_USER_2"
    @@FIRST_SESSION_ID = "TEST_SESSION_1"
    @@SECOND_SESSION_ID = "TEST_SESSION_2"
    @@CLASSIFICATION_MARKER = "classification"
    @@CLASSIFICATION_IDS = []

    def setup
      @@CLASSIFICATION_IDS = []
      1000.times do |i|
        @@CLASSIFICATION_IDS.push (i+101)
      end
    end

     def testOptOutForNewStatementsUser
       uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[0]}")
       http = Net::HTTP.new(uri.host, uri.port)
       request = Net::HTTP::Post.new(uri.request_uri)
       begin
         response = http.request(request)
         assert_equal("200",response.code)
         optOutUser(@@TEST_STATEMENTS_USER_ID)
         checkOptedOut(@@TEST_STATEMENTS_USER_ID)
       ensure
         deleteUser(@@TEST_STATEMENTS_USER_ID)
         deleteOptOutForUser(@@TEST_STATEMENTS_USER_ID)
       end
     end

     def testOptOutAndCancelOptOutForNewStatementsUser
       uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[0]}")
       http = Net::HTTP.new(uri.host, uri.port)
       request = Net::HTTP::Post.new(uri.request_uri)
       begin
         response = http.request(request)
         assert_equal("200",response.code)
         optOutUser(@@TEST_STATEMENTS_USER_ID)
         checkOptedOut(@@TEST_STATEMENTS_USER_ID)
         deleteOptOutForUser(@@TEST_STATEMENTS_USER_ID)
         checkNotOptedOut(@@TEST_STATEMENTS_USER_ID)
       ensure
         deleteUser(@@TEST_STATEMENTS_USER_ID)
         deleteOptOutForUser(@@TEST_STATEMENTS_USER_ID, false)
       end
     end


## Helper methods
    def deleteUser(user_id)
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/participant/#{user_id}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Delete.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code)
    end

    def optOutUser(user_id)
      uri = URI.parse("#{@@SERVER_URL}/users/#{user_id}/optout")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data({"user_id" => user_id, "experiment_name" => "CometHuntersVolcroweExperiment1", "project" => "mschwamb/comet-hunters"})
      response = http.request(request)
      assert(response.code=="200"||response.code=="202")
    end

    def checkOptedOut(user_id)
      uri = URI.parse("#{@@SERVER_URL}/users/#{user_id}/optout")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      request.set_form_data({"user_id" => user_id, "experiment_name" => "CometHuntersVolcroweExperiment1", "project" => "mschwamb/comet-hunters"})
      response = http.request(request)
      assert_equal("200",response.code)
      obj = JSON.parse(response.body)
      assert_equal(true,obj["data"]["opted_out"],"Expected user to be opted out")
    end

    def checkNotOptedOut(user_id)
      uri = URI.parse("#{@@SERVER_URL}/users/#{user_id}/optout")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      request.set_form_data({"user_id" => user_id, "experiment_name" => "CometHuntersVolcroweExperiment1", "project" => "mschwamb/comet-hunters"})
      response = http.request(request)
      assert_equal("200",response.code)
      obj = JSON.parse(response.body)
      assert_equal(false,obj ["data"]["opted_out"],"Expected user not to be opted out")
    end

    def deleteOptOutForUser(user_id, checks=true)
      uri = URI.parse("#{@@SERVER_URL}/users/#{user_id}/optout")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Delete.new(uri.request_uri)
      request.set_form_data({"user_id" => user_id, "experiment_name" => "CometHuntersVolcroweExperiment1", "project" => "mschwamb/comet-hunters"})
      response = http.request(request)
      if checks
        assert_equal("200",response.code)
      end
    end
##

end