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

    def testUpToFirstInterventionForANewStatementsUser
      classification_id_index = 0
      interventions_available_count = 15
      interventions_seen_count = 0
      begin
        data = postClassification classification_id_index
        seq, classification_id_index, session_plan, nextEvent, current_session_history, intervention_time = advanceByClassification data, seq, session_plan, nextEvent, current_session_history, classification_id_index, intervention_time
        data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count = handleABlockOfClassificationsThenAnIntervention data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, intervention_time
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
#        seq, classification_id_index, session_plan, nextEvent, current_session_history, intervention_time = advanceByClassification data, seq, session_plan, nextEvent, current_session_history, classification_id_index, intervention_time
#        interventions_available_count.times do |i|
#          data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count = handleABlockOfClassificationsThenAnIntervention data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, intervention_time
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

    def handleABlockOfClassificationsThenAnIntervention(data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, intervention_time)
      while nextEvent==@@CLASSIFICATION_MARKER
        data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, intervention_time = handleClassificationWithChecks data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, intervention_time
      end
      data, seq, interventions_available_count, interventions_seen_count, intervention_time = handleInterventionWithChecks data, session_plan, seq, current_session_history, interventions_available_count, interventions_seen_count, nextEvent, intervention_time
      return data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, intervention_time
    end

    def handleClassificationWithChecks(data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, intervention_time)
      preCheckClassification data, session_plan, seq, current_session_history, nextEvent, intervention_time
      data = postClassification classification_id_index
      seq, classification_id_index, session_plan, nextEvent, current_session_history = advanceByClassification data, seq, session_plan, nextEvent, current_session_history, classification_id_index, intervention_time
      postCheckClassification seq, data, session_plan, classification_id_index, current_session_history, nextEvent, intervention_time
      return data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, intervention_time
    end

    def handleInterventionWithChecks(data, session_plan, seq, current_session_history, interventions_available_count, interventions_seen_count, nextEvent, intervention_time)
      preCheckIntervention data, session_plan, seq, current_session_history, nextEvent, intervention_time
      intervention_to_post = session_plan[seq]
      data = postIntervention intervention_to_post, current_session_history
      seq, interventions_available_count, interventions_seen_count = advanceByIntervention data, seq, current_session_history, intervention_to_post, interventions_available_count, interventions_seen_count
      postCheckIntervention data, interventions_available_count, interventions_seen_count, intervention_to_post, current_session_history, seq, session_plan, nextEvent, intervention_time
      return data, seq, interventions_available_count, interventions_seen_count, nextEvent, intervention_time
    end

    def preCheckClassification(data, session_plan, seq, current_session_history, nextEvent, intervention_time)
      context = getContextForAssert session_plan, seq, current_session_history, nextEvent, intervention_time
      assert_equal(false,data["message"]["intervention_time"],"#{context}Expected to be told that an intervention is not due next.")
      assert_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"#{context}Expected to be told that the next event is a classification.")
      assert_equal(session_plan[seq],data["message"]["next_event"],"#{context}Expected next event in session plan to also be in next_event.")
    end

    def postCheckClassification(seq, data, session_plan, classification_id_index, current_session_history, nextEvent, intervention_time)
      context = getContextForAssert session_plan, seq, current_session_history, nextEvent, intervention_time
      assert_equal(@@FIRST_SESSION_ID,data["message"]["current_session_id"], "#{context}Expected session ID not to change.")
      assert_equal(seq,data["message"]["seq_of_next_event"],"#{context}Expected session plan pointer to advance.")
      assert_equal(session_plan,data["message"]["current_session_plan"],"#{context}Expected session plan not to change.")
    end

    def postClassification(classification_id_index)
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[classification_id_index]}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code)
      JSON.parse(response.body)
    end

    def preCheckIntervention(data, session_plan, seq, current_session_history, nextEvent, intervention_time)
      context = getContextForAssert session_plan, seq, current_session_history, nextEvent, intervention_time
      assert_equal(true,data["message"]["intervention_time"],"#{context}Expected to be told that an intervention is due next.")
      assert_not_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"#{context}Expected to be told that the next event is an intervention.")
      assert_not_equal(@@CLASSIFICATION_MARKER,session_plan[seq],"#{context}Expected the next event in the session plan to be an intervention.")
      assert_equal(session_plan[seq],data["message"]["next_event"],"#{context}Expected next event in session plan to also be in next_event.")
    end

    def postIntervention(intervention_to_post, current_session_history)
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/intervention/#{intervention_to_post}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code)
      JSON.parse(response.body)
    end

    def postCheckIntervention(data, interventions_available_count, interventions_seen_count, intervention_to_post, current_session_history, seq, session_plan, nextEvent, intervention_time)
      context = getContextForAssert session_plan, seq, current_session_history, nextEvent, intervention_time
      assert_equal(CometHuntersVolcroweExperiment1::getExperimentName,data["message"]["experiment_name"],"Wrong experiment name.")
      assert_equal(CometHuntersVolcroweExperiment1::getStatementsCohort,data["message"]["cohort"],"Wrong cohort.")
      assert_equal(@@TEST_STATEMENTS_USER_ID,data["message"]["user_id"],"Wrong user ID.")
      assert(data["message"]["active"]==true,"Expected participant to be active.")
      assert(data["message"]["excluded"]==false,"Expected participant not to be excluded.")
      assert_nil(data["message"]["excluded_reason"],"Expected no exclusion reason")
      assert_equal(interventions_available_count,data["message"]["interventions_available"].length,"#{context}Expected #{interventions_available_count} available interventions.")
      assert(!data["message"]["interventions_available"].include?(intervention_to_post),"#{context}Expected that intervention no longer to be marked available.")
      assert_equal(interventions_seen_count,data["message"]["interventions_seen"].length,"Expected #{interventions_seen_count} seen interventions.")
      assert_equal(intervention_to_post,data["message"]["interventions_seen"][0],"#{context}Expected that intervention marked seen.")
      assert_equal(Hash.new, data["message"]["original_session_plans"],"#{context}Expected no original session plans.")
      assert_equal(Hash.new, data["message"]["session_histories"],"#{context}Expected no session histories.")
      assert_equal(@@FIRST_SESSION_ID,data["message"]["current_session_id"], "#{context}Expected session ID not to change.")
      assert_equal(current_session_history,data["message"]["current_session_history"],"#{context}Expected current session history to be updated.")
      assert_equal(session_plan,data["message"]["current_session_plan"],"#{context}Expected session plan not to change.")
      assert_equal(seq,data["message"]["seq_of_next_event"],"#{context}Expected session plan pointer to advance.")
      assert_equal(false,data["message"]["intervention_time"],"#{context}Expected to be told that an intervention is not due next.")
      assert_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"#{context}Expected to be told that the next event is an intervention.")
      assert_equal(@@CLASSIFICATION_MARKER,session_plan[seq],"#{context}Expected the next event in the session plan to be an intervention.")
      assert_equal(session_plan[seq],data["message"]["next_event"],"#{context}Expected next event in session plan to also be in next_event.")
    end

    def getContextForAssert(session_plan, seq, current_session_history, nextEvent, intervention_time)
      return "\nAfter session so far of:\n#{current_session_history}\n"
    end

    def advanceByIntervention(data, seq, current_session_history, intervention_to_post, interventions_available_count, interventions_seen_count)
      current_session_history.push "intervention:#{intervention_to_post}"
      interventions_seen_count = data["message"]["interventions_seen"].length
      interventions_available_count = data["message"]["interventions_available"].length
      intervention_time = data["message"]["intervention_time"]
      seq += 1
      return seq, interventions_available_count, interventions_seen_count, intervention_time
    end

    def advanceByClassification(data, seq, session_plan, nextEvent, current_session_history, classification_id_index, intervention_time)
      intervention_time = data["message"]["intervention_time"]
      context = getContextForAssert session_plan, seq, current_session_history, nextEvent, intervention_time
      if current_session_history.nil?
        current_session_history = []
      end
      current_session_history.push "classification:#{@@CLASSIFICATION_IDS[classification_id_index]}"
      assert_equal(current_session_history,data["message"]["current_session_history"],"#{context}Expected current session history to be updated.")
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
      return seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, intervention_time
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
