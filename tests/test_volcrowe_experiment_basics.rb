# Note: These are not really unit tests - in fact they are external tests.
# They assume you have already started a server with `ruby server.rb -o 0.0.0.0`

require "test/unit"
require 'net/http'
require 'uri'
require_relative '../experiments/comet_hunters_volcrowe_experiment.rb'
require 'json'

class TestVolcroweExperimentBasics < Test::Unit::TestCase

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
      100.times do |i|
        @@CLASSIFICATION_IDS.push (i+101)
      end
    end

    def testThatExperimentNameIsAvailableAndCorrect
      experimentName = CometHuntersVolcroweExperiment1::getExperimentName
      assert_equal(experimentName,"CometHuntersVolcroweExperiment1")
    end

    def testThatExperimentIsLoaded
      uri = URI.parse("#{@@SERVER_URL}/active_experiments")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code)
      exps = response.body
      assert(exps.include?(CometHuntersVolcroweExperiment1::getExperimentName),"Expected to find '#{CometHuntersVolcroweExperiment1::getExperimentName}'")
    end

    def testClassificationForNewStatementsUser
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[0]}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      begin
        response = http.request(request)
        assert_equal("200",response.code)
        data = JSON.parse(response.body)
        assert_equal(CometHuntersVolcroweExperiment1::getExperimentName,data["message"]["experiment_name"],"Wrong experiment name.")
        assert_equal(CometHuntersVolcroweExperiment1::getStatementsCohort,data["message"]["cohort"],"Wrong cohort.")
        assert_equal(@@TEST_STATEMENTS_USER_ID,data["message"]["user_id"],"Wrong user ID.")
        assert(data["message"]["active"]==true,"Expected participant to be active.")
        assert(data["message"]["excluded"]==false,"Expected participant not to be excluded.")
        assert_nil(data["message"]["excluded_reason"],"Expected no exclusion reason")
        assert_equal(15,data["message"]["interventions_available"].length,"Expected 15 available interventions.")
        assert_equal(0,data["message"]["interventions_seen"].length,"Expected no seen interventions.")
        assert_equal(Hash.new, data["message"]["original_session_plans"],"Expected no original session plans.")
        assert_equal(Hash.new, data["message"]["session_histories"],"Expected no session histories.")
        assert_equal(@@FIRST_SESSION_ID, data["message"]["current_session_id"],"Wrong session ID.")
        assert_equal(["classification:#{@@CLASSIFICATION_IDS[0]}"], data["message"]["current_session_history"],"Expected empty current session history.")
        assert_not_equal(0, data["message"]["current_session_plan"].length,"Expected a non-empty session plan.")
        assert(data["message"]["current_session_plan"].length>30,"Expected a session plan longer than 30 events.")
        assert_equal(1, data["message"]["seq_of_next_event"],"Expected to be pointing to second event in session plan.")
      ensure
        deleteUser(@@TEST_STATEMENTS_USER_ID)
      end
    end

    def testClassificationForNewQuestionsUser
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_QUESTIONS_USER_ID}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[0]}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      begin
        response = http.request(request)
        assert_equal("200",response.code)
        data = JSON.parse(response.body)
        assert_equal(CometHuntersVolcroweExperiment1::getExperimentName,data["message"]["experiment_name"],"Wrong experiment name.")
        assert_equal(CometHuntersVolcroweExperiment1::getQuestionsCohort,data["message"]["cohort"],"Wrong cohort.")
        assert_equal(@@TEST_QUESTIONS_USER_ID,data["message"]["user_id"],"Wrong user ID.")
        assert(data["message"]["active"]==true,"Expected participant to be active.")
        assert(data["message"]["excluded"]==false,"Expected participant not to be excluded.")
        assert_nil(data["message"]["excluded_reason"],"Expected no exclusion reason")
        assert_equal(15,data["message"]["interventions_available"].length,"Expected 15 available interventions.")
        assert_equal(0,data["message"]["interventions_seen"].length,"Expected no seen interventions.")
        assert_equal(Hash.new, data["message"]["original_session_plans"],"Expected no original session plans.")
        assert_equal(Hash.new, data["message"]["session_histories"],"Expected no session histories.")
        assert_equal(@@FIRST_SESSION_ID, data["message"]["current_session_id"],"Wrong session ID.")
        assert_equal(["classification:#{@@CLASSIFICATION_IDS[0]}"], data["message"]["current_session_history"],"Expected empty current session history.")
        assert_not_equal(0, data["message"]["current_session_plan"].length,"Expected a non-empty session plan.")
        assert(data["message"]["current_session_plan"].length>30,"Expected a session plan longer than 30 events.")
        assert_equal(1, data["message"]["seq_of_next_event"],"Expected to be pointing to second event in session plan.")
      ensure
        deleteUser(@@TEST_QUESTIONS_USER_ID)
      end
    end

    def testClassificationForNewControlUser
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_CONTROL_USER_ID}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[0]}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      begin
        response = http.request(request)
        assert_equal("200",response.code)
        data = JSON.parse(response.body)
        assert_equal(CometHuntersVolcroweExperiment1::getExperimentName,data["message"]["experiment_name"],"Wrong experiment name.")
        assert_equal(CometHuntersVolcroweExperiment1::getControlCohort,data["message"]["cohort"],"Wrong cohort.")
        assert_equal(@@TEST_CONTROL_USER_ID,data["message"]["user_id"],"Wrong user ID.")
        assert(data["message"]["active"]==true,"Expected participant to be active.")
        assert(data["message"]["excluded"]==false,"Expected participant not to be excluded.")
        assert_nil(data["message"]["excluded_reason"],"Expected no exclusion reason")
        assert_equal(0,data["message"]["interventions_available"].length,"Expected no available interventions.")
        assert_equal(0,data["message"]["interventions_seen"].length,"Expected no seen interventions.")
        assert_equal(Hash.new, data["message"]["original_session_plans"],"Expected no original session plans.")
        assert_equal(Hash.new, data["message"]["session_histories"],"Expected no session histories.")
        assert_equal(@@FIRST_SESSION_ID, data["message"]["current_session_id"],"Wrong session ID.")
        assert_equal(["classification:#{@@CLASSIFICATION_IDS[0]}"], data["message"]["current_session_history"],"Expected empty current session history.")
        assert_equal(0, data["message"]["current_session_plan"].length,"Expected an empty session plan.")
        assert_equal(-1, data["message"]["seq_of_next_event"],"Expected no valid pointer in session plan.")
      ensure
        deleteUser(@@TEST_CONTROL_USER_ID)
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
##

end