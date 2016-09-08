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

    def handleClassificationWithChecks(data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count)
      preCheckClassification data, session_plan, seq, current_session_history
      data = postClassification classification_id_index
      seq, classification_id_index, session_plan, nextEvent, current_session_history = advanceByClassification data, seq, session_plan, nextEvent, current_session_history, classification_id_index
      postCheckClassification seq, data, session_plan, classification_id_index, current_session_history
      return data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count
    end

    def handleInterventionWithChecks(data, session_plan, seq, current_session_history, interventions_available_count, interventions_seen_count)
      preCheckIntervention data, session_plan, seq, current_session_history
      intervention_to_post = session_plan[seq]
      data = postIntervention intervention_to_post, current_session_history
      seq, interventions_available_count, interventions_seen_count = advanceByIntervention data, seq, current_session_history, intervention_to_post, interventions_available_count, interventions_seen_count
      postCheckIntervention data, interventions_available_count, interventions_seen_count, intervention_to_post, current_session_history, seq, session_plan
      return data, seq, interventions_available_count, interventions_seen_count
    end

    def testUpToFirstInterventionForANewStatementsUser
      classification_id_index = 0
      interventions_available_count = 15
      interventions_seen_count = 0
      begin
        data = postClassification classification_id_index
        seq, classification_id_index, session_plan, nextEvent, current_session_history = advanceByClassification data, seq, session_plan, nextEvent, current_session_history, classification_id_index
        while nextEvent==@@CLASSIFICATION_MARKER
          data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count = handleClassificationWithChecks data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count
        end
        data, seq, interventions_available_count, interventions_seen_count = handleInterventionWithChecks data, session_plan, seq, current_session_history, interventions_available_count, interventions_seen_count
      ensure
        deleteUser(@@TEST_STATEMENTS_USER_ID)
      end
    end

    def handleABlockOfClassificationsThenAnIntervention(data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count)
      while nextEvent==@@CLASSIFICATION_MARKER
        data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count = handleClassificationWithChecks data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count
      end
      data, seq, interventions_available_count, interventions_seen_count = handleInterventionWithChecks data, session_plan, seq, current_session_history, interventions_available_count, interventions_seen_count
      return data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count
    end


    def testUpToFirstInterventionForANewStatementsUser
      classification_id_index = 0
      interventions_available_count = 15
      interventions_seen_count = 0
      begin
        data = postClassification classification_id_index
        seq, classification_id_index, session_plan, nextEvent, current_session_history = advanceByClassification data, seq, session_plan, nextEvent, current_session_history, classification_id_index
        data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count = handleABlockOfClassificationsThenAnIntervention(data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count)
      ensure
        deleteUser(@@TEST_STATEMENTS_USER_ID)
      end
    end

#    def testFullExperimentForANewStatementsUser
#      classification_id_index = 0
#      interventions_available_count = 15
#      interventions_seen_count = 0
#      begin
#        data = postClassification classification_id_index
#        seq, classification_id_index, session_plan, nextEvent, current_session_history = advanceByClassification data, seq, session_plan, nextEvent, current_session_history, classification_id_index
#        interventions_available_count.times do |i|
#          data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count = handleABlockOfClassificationsThenAnIntervention(data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count)
#        end
#      ensure
#        deleteUser(@@TEST_STATEMENTS_USER_ID)
#      end
#    end

## Helper methods

    def deleteUser(user_id)
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/participant/#{user_id}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Delete.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code)
    end

    def preCheckClassification(data, session_plan, seq, current_session_history)
      assert_equal(false,data["message"]["intervention_time"],"#{getSessionSoFar(current_session_history)}Expected to be told that an intervention is not due next.")
      assert_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"#{getSessionSoFar(current_session_history)}Expected to be told that the next event is a classification.")
      assert_equal(session_plan[seq],data["message"]["next_event"],"#{getSessionSoFar(current_session_history)}Expected next event in session plan to also be in next_event.")
    end

    def postCheckClassification(seq, data, session_plan, classification_id_index, current_session_history)
      assert_equal(@@FIRST_SESSION_ID,data["message"]["current_session_id"], "#{getSessionSoFar(current_session_history)}Expected session ID not to change.")
      assert_equal(seq,data["message"]["seq_of_next_event"],"#{getSessionSoFar(current_session_history)}Expected session plan pointer to advance.")
      assert_equal(session_plan,data["message"]["current_session_plan"],"#{getSessionSoFar(current_session_history)}Expected session plan not to change.")
    end

    def postClassification(classification_id_index)
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[classification_id_index]}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code)
      JSON.parse(response.body)
    end

    def preCheckIntervention(data, session_plan, seq, current_session_history)
      assert_equal(true,data["message"]["intervention_time"],"#{getSessionSoFar(current_session_history)}Expected to be told that an intervention is due next.")
      assert_not_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"#{getSessionSoFar(current_session_history)}Expected to be told that the next event is an intervention.")
      assert_not_equal(@@CLASSIFICATION_MARKER,session_plan[seq],"#{getSessionSoFar(current_session_history)}Expected the next event in the session plan to be an intervention.")
      assert_equal(session_plan[seq],data["message"]["next_event"],"#{getSessionSoFar(current_session_history)}Expected next event in session plan to also be in next_event.")
    end

    def postIntervention(intervention_to_post, current_session_history)
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/intervention/#{intervention_to_post}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code)
      JSON.parse(response.body)
    end

    def postCheckIntervention(data, interventions_available_count, interventions_seen_count, intervention_to_post, current_session_history, seq, session_plan)
      assert_equal(CometHuntersVolcroweExperiment1::getExperimentName,data["message"]["experiment_name"],"Wrong experiment name.")
      assert_equal(CometHuntersVolcroweExperiment1::getStatementsCohort,data["message"]["cohort"],"Wrong cohort.")
      assert_equal(@@TEST_STATEMENTS_USER_ID,data["message"]["user_id"],"Wrong user ID.")
      assert(data["message"]["active"]==true,"Expected participant to be active.")
      assert(data["message"]["excluded"]==false,"Expected participant not to be excluded.")
      assert_nil(data["message"]["excluded_reason"],"Expected no exclusion reason")
      assert_equal(interventions_available_count,data["message"]["interventions_available"].length,"#{getSessionSoFar(current_session_history)}Expected #{interventions_available_count} available interventions.")
      assert(!data["message"]["interventions_available"].include?(intervention_to_post),"#{getSessionSoFar(current_session_history)}Expected that intervention no longer to be marked available.")
      assert_equal(interventions_seen_count,data["message"]["interventions_seen"].length,"Expected #{interventions_seen_count} seen interventions.")
      assert_equal(intervention_to_post,data["message"]["interventions_seen"][0],"#{getSessionSoFar(current_session_history)}Expected that intervention marked seen.")
      assert_equal(Hash.new, data["message"]["original_session_plans"],"#{getSessionSoFar(current_session_history)}Expected no original session plans.")
      assert_equal(Hash.new, data["message"]["session_histories"],"#{getSessionSoFar(current_session_history)}Expected no session histories.")
      assert_equal(@@FIRST_SESSION_ID,data["message"]["current_session_id"], "#{getSessionSoFar(current_session_history)}Expected session ID not to change.")
      assert_equal(current_session_history,data["message"]["current_session_history"],"#{getSessionSoFar(current_session_history)}Expected current session history to be updated.")
      assert_equal(session_plan,data["message"]["current_session_plan"],"#{getSessionSoFar(current_session_history)}Expected session plan not to change.")
      assert_equal(seq,data["message"]["seq_of_next_event"],"#{getSessionSoFar(current_session_history)}Expected session plan pointer to advance.")
      assert_equal(false,data["message"]["intervention_time"],"#{getSessionSoFar(current_session_history)}Expected to be told that an intervention is not due next.")
      assert_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"#{getSessionSoFar(current_session_history)}Expected to be told that the next event is an intervention.")
      assert_equal(@@CLASSIFICATION_MARKER,session_plan[seq],"#{getSessionSoFar(current_session_history)}Expected the next event in the session plan to be an intervention.")
      assert_equal(session_plan[seq],data["message"]["next_event"],"#{getSessionSoFar(current_session_history)}Expected next event in session plan to also be in next_event.")
    end

    def getSessionSoFar(current_session_history)
      return "\nAfter session so far of:\n#{current_session_history}\n"
    end

    def advanceByIntervention(data, seq, current_session_history, intervention_to_post, interventions_available_count, interventions_seen_count)
      current_session_history.push "intervention:#{intervention_to_post}"
      interventions_seen_count = data["message"]["interventions_seen"].length
      interventions_available_count = data["message"]["interventions_available"].length
      seq += 1
      return seq, interventions_available_count, interventions_seen_count
    end

    def advanceByClassification(data, seq, session_plan, nextEvent, current_session_history, classification_id_index)
      if current_session_history.nil?
        current_session_history = []
      end
      current_session_history.push "classification:#{@@CLASSIFICATION_IDS[classification_id_index]}"
      assert_equal(current_session_history,data["message"]["current_session_history"],"#{getSessionSoFar(current_session_history)}Expected current session history to be updated.")
      if seq.nil?
        session_plan = data["message"]["current_session_plan"]
        seq = data["message"]["seq_of_next_event"]
      else
        seq += 1
      end
      nextEvent = session_plan[seq]
      classification_id_index += 1
      interventions_seen_count = data["message"]["interventions_seen"].length
      interventions_available_count = data["message"]["interventions_available"].length
      return seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count
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
