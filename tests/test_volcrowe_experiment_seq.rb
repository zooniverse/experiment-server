# Note: These are not really unit tests - in fact they are external tests.
# They assume you have already started a server with `ruby server.rb -o 0.0.0.0`

require "test/unit"
require 'net/http'
require 'uri'
require_relative '../experiments/comet_hunters_volcrowe_experiment.rb'
require 'json'

class TestVolcroweExperimentSeq < Test::Unit::TestCase

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

    def testUpToFirstInterventionForANewStatementsUser
      classification_id_index = 0
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[classification_id_index]}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      begin
        step = 1
        response = http.request(request)
        assert_equal("200",response.code)
        data = JSON.parse(response.body)
        session_plan = data["message"]["current_session_plan"]
        seq = data["message"]["seq_of_next_event"]
        nextEvent = session_plan[seq]
        current_session_history = ["classification:#{@@CLASSIFICATION_IDS[classification_id_index]}"]
        assert_equal(current_session_history,data["message"]["current_session_history"],"After #{step} classifications, expected current session history to be updated.")
        step = 1
        while nextEvent==@@CLASSIFICATION_MARKER
          step += 1
          classification_id_index += 1
          uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[classification_id_index]}")
          http = Net::HTTP.new(uri.host, uri.port)
          request = Net::HTTP::Post.new(uri.request_uri)
          response = http.request(request)
          assert_equal("200",response.code)
          data = JSON.parse(response.body)
          assert_equal(@@FIRST_SESSION_ID,data["message"]["current_session_id"], "After #{step} classifications, expected session ID not to change.")
          seq += 1
          assert_equal(seq,data["message"]["seq_of_next_event"],"After #{step} classifications, expected session plan pointer to advance.")
          assert_equal(session_plan,data["message"]["current_session_plan"],"After #{step} classifications, expected session plan not to change.")
          current_session_history.push "classification:#{@@CLASSIFICATION_IDS[classification_id_index]}"
          assert_equal(current_session_history,data["message"]["current_session_history"],"After #{step} classifications, expected current session history to be updated.")
          nextEvent = session_plan[seq]
        end
        assert_not_equal(@@CLASSIFICATION_MARKER,session_plan[seq],"After #{step} classifications, verifying test logic: Expected the next event in the session plan to be an intervention.")
        # now post the intervention.
        intervention_to_post = session_plan[seq]
        uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/intervention/#{intervention_to_post}")
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri)
        response = http.request(request)
        assert_equal("200",response.code)
        seq += 1
        current_session_history.push "intervention:#{intervention_to_post}"
        data = JSON.parse(response.body)
        # and check everything is as expected
        assert_equal(CometHuntersVolcroweExperiment1::getExperimentName,data["message"]["experiment_name"],"Wrong experiment name.")
        assert_equal(CometHuntersVolcroweExperiment1::getStatementsCohort,data["message"]["cohort"],"Wrong cohort.")
        assert_equal(@@TEST_STATEMENTS_USER_ID,data["message"]["user_id"],"Wrong user ID.")
        assert(data["message"]["active"]==true,"Expected participant to be active.")
        assert(data["message"]["excluded"]==false,"Expected participant not to be excluded.")
        assert_nil(data["message"]["excluded_reason"],"Expected no exclusion reason")
        assert_equal(14,data["message"]["interventions_available"].length,"Expected 14 available interventions.")
        assert(!data["message"]["interventions_available"].include?(intervention_to_post),"After #{step} classifications and the #{intervention_to_post} intervention, expected that intervention no longer to be marked available.")
        assert_equal(1,data["message"]["interventions_seen"].length,"Expected 1 seen intervention.")
        assert_equal(intervention_to_post,data["message"]["interventions_seen"][0],"After #{step} classifications and the #{intervention_to_post} intervention, expected that intervention marked seen.")
        assert_equal(Hash.new, data["message"]["original_session_plans"],"After #{step} classifications and the #{intervention_to_post} intervention, expected no original session plans.")
        assert_equal(Hash.new, data["message"]["session_histories"],"After #{step} classifications and the #{intervention_to_post} intervention, expected no session histories.")
        assert_equal(@@FIRST_SESSION_ID,data["message"]["current_session_id"], "After #{step} classifications and the #{intervention_to_post} intervention, expected session ID not to change.")
        assert_equal(current_session_history,data["message"]["current_session_history"],"After #{step} classifications and the #{intervention_to_post} intervention, expected current session history to be updated.")
        assert_equal(session_plan,data["message"]["current_session_plan"],"After #{step} classifications and the #{intervention_to_post} intervention, expected session plan not to change.")
        assert_equal(seq,data["message"]["seq_of_next_event"],"After #{step} classifications and the #{intervention_to_post} intervention, expected session plan pointer to advance.")
        # now one more classification
      ensure
        deleteUser(@@TEST_STATEMENTS_USER_ID)
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

## tests TODO:

# new session
# reset session
# full end to end sequence of an experimental session
# end of experiment (empty/inactive)
# past intervention when not expected
# absent intervention when not expected
# future intervention when not expected
# classification when intervention was expected
# classification after end of experiment
# intervention after end of experiment
