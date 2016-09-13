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

    @@SUGAR_STAGING_URL = "https://notifications-staging.zooniverse.org/experiment"
    @@SUGAR_PRODUCTION_URL = "https://notifications.zooniverse.org/experiment"
    @@SUGAR_URL = !ENV["SUGAR_HOST"].nil? ? "#{ENV["SUGAR_HOST"]}/experiment" : @@SUGAR_STAGING_URL
    @@PROJECT_SLUG_PRODUCTION = "mschwamb/comet-hunters"
    @@PROJECT_SLUG_DEVELOPMENT = "mschwamb/planet-four-terrains"
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
      if @@SUGAR_URL == @@SUGAR_PRODUCTION_URL
        @@PROJECT_SLUG = @@PROJECT_SLUG_PRODUCTION
      else
        @@PROJECT_SLUG = @@PROJECT_SLUG_DEVELOPMENT
      end
    end

    def testOptOutAndCancelOptOutForNewStatementsUser
      classification_id_index = 0
      begin
        postClassification @@TEST_STATEMENTS_USER_ID, classification_id_index
        optOutUser @@TEST_STATEMENTS_USER_ID
        checkOptedOut @@TEST_STATEMENTS_USER_ID
        data = postClassification @@TEST_STATEMENTS_USER_ID, classification_id_index, "422"
        checkThatUserIsNowExcluded data
        deleteOptOutForUser @@TEST_STATEMENTS_USER_ID
        checkNotOptedOut @@TEST_STATEMENTS_USER_ID
      ensure
        deleteUser @@TEST_STATEMENTS_USER_ID
        deleteOptOutForUser @@TEST_STATEMENTS_USER_ID, false
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

    def postClassification(user_id, classification_id_index, expected_response_code="200")
      assert(!@@CLASSIFICATION_IDS[classification_id_index].nil?, "Expected to find a classification ID with index #{classification_id_index} for use in testing.")
      url = "#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{user_id}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[classification_id_index]}"
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      response = http.request(request)
      assert_equal(expected_response_code,response.code, "Expected POST of classification to return #{expected_response_code}. Tried to post to #{url}. Message from server: #{response.code} - #{response.message} Response body:\n #{response.body[0..1000]}...")
      JSON.parse(response.body)
    end

    def optOutUser(user_id)
      uri = URI.parse("#{@@SERVER_URL}/users/#{user_id}/optout")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data({"user_id" => user_id, "experiment_name" => "CometHuntersVolcroweExperiment1", "project" => @@PROJECT_SLUG})
      response = http.request(request)
      assert(response.code=="200"||response.code=="202")
    end

    def checkOptedOut(user_id)
      uri = URI.parse("#{@@SERVER_URL}/users/#{user_id}/optout")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      request.set_form_data({"user_id" => user_id, "experiment_name" => "CometHuntersVolcroweExperiment1", "project" => @@PROJECT_SLUG})
      response = http.request(request)
      assert_equal("200",response.code)
      obj = JSON.parse(response.body)
      assert_equal(true,obj["data"]["opted_out"],"Expected user to be opted out")
    end

    def checkNotOptedOut(user_id)
      uri = URI.parse("#{@@SERVER_URL}/users/#{user_id}/optout")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      request.set_form_data({"user_id" => user_id, "experiment_name" => "CometHuntersVolcroweExperiment1", "project" => @@PROJECT_SLUG})
      response = http.request(request)
      assert_equal("200",response.code)
      obj = JSON.parse(response.body)
      assert_equal(false,obj ["data"]["opted_out"],"Expected user not to be opted out")
    end

    def checkThatUserIsNowExcluded(data)
      assert_equal(false,data["active"],"After opt-out, expected participant to no longer be active")
      assert_equal(true,data["excluded"],"After opt-out, expected participant to be excluded")
      assert_equal("Participant has opted out of the experiment",data["excluded_reason"],"After opt-out, expected participant to have the correct excluded_reason.")
      assert_equal(-1,data["seq_of_next_event"],"After opt-out, expected no pointer to next event")
      assert_equal(false,data["intervention_time"],"After opt-out, expected no intervention to be stated as required")
      assert_equal(0,data["current_session_plan"].length,"After opt-out, expected an empty session plan")
      assert_equal(0,data["interventions_available"].length,"After opt-out, expected no available interventions")
      assert_equal(0,data["interventions_seen"].length,"After opt-out, expected no seen interventions")
    end

    def deleteOptOutForUser(user_id, checks=true)
      uri = URI.parse("#{@@SERVER_URL}/users/#{user_id}/optout")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Delete.new(uri.request_uri)
      request.set_form_data({"user_id" => user_id, "experiment_name" => "CometHuntersVolcroweExperiment1", "project" => @@PROJECT_SLUG})
      response = http.request(request)
      if checks
        assert_equal("200",response.code)
      end
    end
##

end