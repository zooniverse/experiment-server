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
      begin
        data = postClassification classification_id_index
        seq, step, classification_id_index, session_plan, nextEvent, current_session_history = advanceByClassification data, step, seq, session_plan, nextEvent, current_session_history, classification_id_index
        while nextEvent==@@CLASSIFICATION_MARKER
          preCheckClassification data, step, session_plan, seq
          data = postClassification classification_id_index
          seq, step, classification_id_index, session_plan, nextEvent, current_session_history = advanceByClassification data, step, seq, session_plan, nextEvent, current_session_history, classification_id_index
          postCheckClassification seq, data, step, session_plan, classification_id_index
        end
        preCheckIntervention data, step, session_plan, seq
        intervention_to_post = session_plan[seq]
        data = postIntervention intervention_to_post, current_session_history
        seq = advanceByIntervention seq, current_session_history, intervention_to_post
        postCheckIntervention data, 14, 1, step, intervention_to_post, current_session_history, seq, session_plan

        # TODO now one more classification
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

    def preCheckClassification(data,step,session_plan,seq)
      assert_equal(false,data["message"]["intervention_time"],"After #{step} classifications, expected to be told that an intervention is not due next.")
      assert_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"After #{step} classifications, expected to be told that the next event is a classification.")
      assert_equal(session_plan[seq],data["message"]["next_event"],"After #{step} classifications, expected next event in session plan to also be in next_event.")
    end

    def postCheckClassification(seq,data,step,session_plan,classification_id_index)
      assert_equal(@@FIRST_SESSION_ID,data["message"]["current_session_id"], "After #{step} classifications, expected session ID not to change.")
      assert_equal(seq,data["message"]["seq_of_next_event"],"After #{step} classifications, expected session plan pointer to advance.")
      assert_equal(session_plan,data["message"]["current_session_plan"],"After #{step} classifications, expected session plan not to change.")
    end

    def postClassification(classification_id_index)
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[classification_id_index]}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code)
      JSON.parse(response.body)
    end

    def preCheckIntervention(data, step, session_plan, seq)
      assert_equal(true,data["message"]["intervention_time"],"After #{step} classifications, expected to be told that an intervention is due next.")
      assert_not_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"After #{step} classifications, expected to be told that the next event is an intervention.")
      assert_not_equal(@@CLASSIFICATION_MARKER,session_plan[seq],"After #{step} classifications, expected the next event in the session plan to be an intervention.")
      assert_equal(session_plan[seq],data["message"]["next_event"],"After #{step} classifications, expected next event in session plan to also be in next_event.")
    end

    def postIntervention(intervention_to_post, current_session_history)
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/intervention/#{intervention_to_post}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code)
      JSON.parse(response.body)
    end

    def postCheckIntervention(data, interventions_left_after_this, interventions_used_after_this, step, intervention_to_post, current_session_history, seq, session_plan)
      assert_equal(CometHuntersVolcroweExperiment1::getExperimentName,data["message"]["experiment_name"],"Wrong experiment name.")
      assert_equal(CometHuntersVolcroweExperiment1::getStatementsCohort,data["message"]["cohort"],"Wrong cohort.")
      assert_equal(@@TEST_STATEMENTS_USER_ID,data["message"]["user_id"],"Wrong user ID.")
      assert(data["message"]["active"]==true,"Expected participant to be active.")
      assert(data["message"]["excluded"]==false,"Expected participant not to be excluded.")
      assert_nil(data["message"]["excluded_reason"],"Expected no exclusion reason")
      assert_equal(interventions_left_after_this,data["message"]["interventions_available"].length,"Expected #{interventions_left_after_this} available interventions.")
      assert(!data["message"]["interventions_available"].include?(intervention_to_post),"After #{step} classifications and the #{intervention_to_post} intervention, expected that intervention no longer to be marked available.")
      assert_equal(interventions_used_after_this,data["message"]["interventions_seen"].length,"Expected #{interventions_used_after_this} seen interventions.")
      assert_equal(intervention_to_post,data["message"]["interventions_seen"][0],"After #{step} classifications and the #{intervention_to_post} intervention, expected that intervention marked seen.")
      assert_equal(Hash.new, data["message"]["original_session_plans"],"After #{step} classifications and the #{intervention_to_post} intervention, expected no original session plans.")
      assert_equal(Hash.new, data["message"]["session_histories"],"After #{step} classifications and the #{intervention_to_post} intervention, expected no session histories.")
      assert_equal(@@FIRST_SESSION_ID,data["message"]["current_session_id"], "After #{step} classifications and the #{intervention_to_post} intervention, expected session ID not to change.")
      assert_equal(current_session_history,data["message"]["current_session_history"],"After #{step} classifications and the #{intervention_to_post} intervention, expected current session history to be updated.")
      assert_equal(session_plan,data["message"]["current_session_plan"],"After #{step} classifications and the #{intervention_to_post} intervention, expected session plan not to change.")
      assert_equal(seq,data["message"]["seq_of_next_event"],"After #{step} classifications and the #{intervention_to_post} intervention, expected session plan pointer to advance.")
      assert_equal(false,data["message"]["intervention_time"],"After #{step} classifications and the #{intervention_to_post} intervention, expected to be told that an intervention is not due next.")
      assert_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"After #{step} classifications, expected to be told that the next event is an intervention.")
      assert_equal(@@CLASSIFICATION_MARKER,session_plan[seq],"After #{step} classifications and the #{intervention_to_post} intervention, expected the next event in the session plan to be an intervention.")
      assert_equal(session_plan[seq],data["message"]["next_event"],"After #{step} classifications and the #{intervention_to_post} intervention, expected next event in session plan to also be in next_event.")
    end

    def advanceByIntervention(seq, current_session_history, intervention_to_post)
      current_session_history.push "intervention:#{intervention_to_post}"
      seq + 1
    end

    def advanceByClassification(data, step, seq, session_plan, nextEvent, current_session_history, classification_id_index)
      if current_session_history.nil?
        current_session_history = []
      end
      current_session_history.push "classification:#{@@CLASSIFICATION_IDS[classification_id_index]}"
      assert_equal(current_session_history,data["message"]["current_session_history"],"After #{step} classifications, expected current session history to be updated.")
      if seq.nil?
        session_plan = data["message"]["current_session_plan"]
        seq = data["message"]["seq_of_next_event"]
      else
        seq += 1
      end
      nextEvent = session_plan[seq]
      if step.nil?
        step = 1
      else
        step += 1
      end
      classification_id_index += 1
      return seq, step, classification_id_index, session_plan, nextEvent, current_session_history
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
