# Note: These are not really unit tests - in fact they are external tests.
# They assume you have already started a server with:
#   SUGAR_HOST=... SUGAR_USERNAME=... SUGAR_PASSWORD=`...` ruby server.rb -o 0.0.0.0
# (or modify this IP if you change @@SERVER_URL)

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
      1000.times do |i|
        @@CLASSIFICATION_IDS.push (i+101)
      end
    end

#   If the testFullExperiment tests below fail, disable these and enable these simpler/subset ones instead - easier to debug.
#
#    def testUpToFirstInterventionForANewStatementsUser
#      handleTestUpToFirstIntervention @@TEST_STATEMENTS_USER_ID, 15, CometHuntersVolcroweExperiment1::getStatementsCohort
#    end
#
#    def testUpToFirstInterventionForANewQuestionsUser
#      handleTestUpToFirstIntervention @@TEST_QUESTIONS_USER_ID, 15, CometHuntersVolcroweExperiment1::getQuestionsCohort
#    end
#
#    def testUpToFirstInterventionForANewControlUser
#      handleTestUpToFirstIntervention @@TEST_CONTROL_USER_ID, 0, CometHuntersVolcroweExperiment1::getControlCohort
#    end

    def testFullExperimentForANewControlUser
      handleTestFullExperiment @@TEST_CONTROL_USER_ID, 0, CometHuntersVolcroweExperiment1::getControlCohort
    end

    def testFullExperimentForANewStatementsUser
      handleTestFullExperiment @@TEST_STATEMENTS_USER_ID, 15, CometHuntersVolcroweExperiment1::getStatementsCohort
    end

    def testFullExperimentForANewQuestionsUser
      handleTestFullExperiment @@TEST_QUESTIONS_USER_ID, 15, CometHuntersVolcroweExperiment1::getQuestionsCohort
    end

## Helper methods

    def deleteUser(user_id)
      uri = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/participant/#{user_id}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Delete.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code)
    end

    def handleTestFullExperiment(user_id, expected_available_interventions, expected_cohort)
      classification_id_index = 0
      interventions_available_count = expected_available_interventions
      interventions_seen_count = 0
      begin
        data = postClassification user_id, classification_id_index
        seq, classification_id_index, session_plan, nextEvent, current_session_history = advanceExpectationsAfterClassification data, seq, session_plan, nextEvent, current_session_history, classification_id_index
        interventions_available_count.times do |i|
          # print "\nStarting classifications + interventions loop for intervention #{i}\n"
          data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count = handleABlockOfClassificationsThenAnIntervention data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, user_id, expected_cohort
        end
      ensure
        deleteUser(user_id)
      end
    end

    def handleTestUpToFirstIntervention(user_id, expected_available_interventions, expected_cohort)
      classification_id_index = 0
      interventions_available_count = expected_available_interventions
      interventions_seen_count = 0
      begin
        data = postClassification user_id, classification_id_index
        seq, classification_id_index, session_plan, nextEvent, current_session_history = advanceExpectationsAfterClassification data, seq, session_plan, nextEvent, current_session_history, classification_id_index
        data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count = handleABlockOfClassificationsThenAnIntervention data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, user_id, expected_cohort
      ensure
        deleteUser(user_id)
      end
    end

    def handleABlockOfClassificationsThenAnIntervention(data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, user_id, expected_cohort)
      while nextEvent==@@CLASSIFICATION_MARKER
        data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count = handleClassificationWithChecks data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, user_id
      end
      while nextEvent!=@@CLASSIFICATION_MARKER and not nextEvent.nil?
        data, seq, interventions_available_count, interventions_seen_count, current_session_history, nextEvent = handleInterventionWithChecks data, session_plan, seq, current_session_history, interventions_available_count, interventions_seen_count, nextEvent, user_id, expected_cohort
      end
      return data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count
    end

    def handleClassificationWithChecks(data, session_plan, seq, classification_id_index, nextEvent, current_session_history, interventions_available_count, interventions_seen_count, user_id)
      preCheckClassification data, session_plan, seq, current_session_history, nextEvent
      data = postClassification user_id, classification_id_index
      seq, classification_id_index, session_plan, nextEvent, current_session_history = advanceExpectationsAfterClassification data, seq, session_plan, nextEvent, current_session_history, classification_id_index
      postCheckClassification seq, data, session_plan, classification_id_index, current_session_history, nextEvent
      return data, seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count
    end

    def handleInterventionWithChecks(data, session_plan, seq, current_session_history, interventions_available_count, interventions_seen_count, nextEvent, user_id, expected_cohort)
      preCheckIntervention data, session_plan, seq, current_session_history, nextEvent
      intervention_to_post = session_plan[seq]
      data = postIntervention intervention_to_post, current_session_history, user_id
      seq, interventions_available_count, interventions_seen_count, current_session_history, nextEvent = advanceExpectationsAfterIntervention data, seq, current_session_history, intervention_to_post, interventions_available_count, interventions_seen_count, session_plan, nextEvent
      postCheckIntervention data, interventions_available_count, interventions_seen_count, intervention_to_post, current_session_history, seq, session_plan, nextEvent, user_id, expected_cohort
      return data, seq, interventions_available_count, interventions_seen_count, current_session_history, nextEvent
    end

    def preCheckClassification(data, session_plan, seq, current_session_history, nextEvent)
      context = getContextForAssert "preCheckClassification", session_plan, seq, current_session_history, nextEvent, data["message"]["intervention_time"]
      assert_equal(false,data["message"]["intervention_time"],"#{context}Expected to be told that an intervention is not due next.")
      assert_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"#{context}Expected to be told that the next event is a classification.")
      assert_equal(session_plan[seq],data["message"]["next_event"],"#{context}Expected next event in session plan to also be in next_event.")
    end

    def postCheckClassification(seq, data, session_plan, classification_id_index, current_session_history, nextEvent)
      context = getContextForAssert "postCheckClassification", session_plan, seq, current_session_history, nextEvent, data["message"]["intervention_time"]
      assert_equal(@@FIRST_SESSION_ID,data["message"]["current_session_id"], "#{context}Expected session ID not to change.")
      assert_equal(seq,data["message"]["seq_of_next_event"],"#{context}Expected session plan pointer to advance.")
      assert_equal(session_plan,data["message"]["current_session_plan"],"#{context}Expected session plan not to change.")
    end

    def postClassification(user_id, classification_id_index)
      assert(!@@CLASSIFICATION_IDS[classification_id_index].nil?, "Expected to find a classification ID with index #{classification_id_index} for use in testing.")
      url = "#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{user_id}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[classification_id_index]}"
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code, "Expected POST of classification to succeed. Tried to post to #{url}. Message from server: #{response.code} - #{response.message} Response body:\n #{response.body}")
      JSON.parse(response.body)
    end

    def preCheckIntervention(data, session_plan, seq, current_session_history, nextEvent)
      context = getContextForAssert "preCheckIntervention", session_plan, seq, current_session_history, nextEvent, data["message"]["intervention_time"]
      assert_equal(true,data["message"]["intervention_time"],"#{context}Expected to be told that an intervention is due next.")
      assert_not_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"#{context}Expected to be told that the next event is an intervention.")
      assert_not_equal(@@CLASSIFICATION_MARKER,session_plan[seq],"#{context}Expected the next event in the session plan to be an intervention.")
      assert_equal(session_plan[seq],data["message"]["next_event"],"#{context}Expected next event in session plan to also be in next_event.")
    end

    def postIntervention(intervention_to_post, current_session_history, user_id)
      url = "#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{user_id}/session/#{@@FIRST_SESSION_ID}/intervention/#{intervention_to_post}"
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      response = http.request(request)
      assert_equal("200",response.code, "Expected POST of intervention #{intervention_to_post} to succeed. Tried to post to #{url}. Message from server: #{response.code} - #{response.message}. Response body:\n #{response.body}")
      JSON.parse(response.body)
    end

    def postCheckIntervention(data, interventions_available_count, interventions_seen_count, intervention_to_post, current_session_history, seq, session_plan, nextEvent, user_id, expected_cohort)
      context = getContextForAssert "postCheckIntervention", session_plan, seq, current_session_history, nextEvent, data["message"]["intervention_time"]
      assert_equal(CometHuntersVolcroweExperiment1::getExperimentName,data["message"]["experiment_name"],"#{context}Wrong experiment name.")
      assert_equal(expected_cohort,data["message"]["cohort"],"#{context}Wrong cohort.")
      assert_equal(user_id,data["message"]["user_id"],"#{context}Wrong user ID.")
      assert(data["message"]["active"]==true,"#{context}Expected participant to be active.")
      assert(data["message"]["excluded"]==false,"#{context}Expected participant not to be excluded.")
      assert_nil(data["message"]["excluded_reason"],"#{context}Expected no exclusion reason")
      assert_equal(interventions_available_count,data["message"]["interventions_available"].length,"#{context}Expected #{interventions_available_count} available interventions.")
      assert(!data["message"]["interventions_available"].include?(intervention_to_post),"#{context}Expected that intervention no longer to be marked available.")
      assert_equal(interventions_seen_count,data["message"]["interventions_seen"].length,"Expected #{interventions_seen_count} seen interventions.")
      assert_equal(intervention_to_post,data["message"]["interventions_seen"].last,"#{context}Expected that intervention marked seen.")
      assert_equal(Hash.new, data["message"]["original_session_plans"],"#{context}Expected no original session plans.")
      assert_equal(Hash.new, data["message"]["session_histories"],"#{context}Expected no session histories.")
      assert_equal(@@FIRST_SESSION_ID,data["message"]["current_session_id"], "#{context}Expected session ID not to change.")
      assert_equal(current_session_history,data["message"]["current_session_history"],"#{context}Expected current session history to be updated.")
      assert_equal(session_plan,data["message"]["current_session_plan"],"#{context}Expected session plan not to change.")
      assert_equal(seq,data["message"]["seq_of_next_event"],"#{context}Expected session plan pointer to advance.")
      assert_equal(false,data["message"]["intervention_time"],"#{context}Expected to be told that an intervention is not due next.")

      if seq < session_plan.length
        assert_equal(@@CLASSIFICATION_MARKER,data["message"]["next_event"],"#{context}Expected to be told that the next event is a classification.")
        assert_equal(@@CLASSIFICATION_MARKER,session_plan[seq],"#{context}Expected the next event in the session plan is a classification..")
        assert_equal(session_plan[seq],data["message"]["next_event"],"#{context}Expected next event in session plan to also be in next_event.")
      else
        # checking after the very last intervention
        assert_equal(nil,data["message"]["next_event"],"#{context}Expected no next event.")
      end

    end

    def getContextForAssert(method, session_plan, seq, current_session_history, nextEvent, intervention_time)
      msg = "\n#{method}"
      msg += "\nSession so far is:\n#{current_session_history}"
      if not session_plan.nil?
        msg += "\nSession plan is:\n#{session_plan}"
        msg += "\nCurrent seq value is: #{seq} => #{session_plan[seq]}"
      else
        msg += "\nCurrent seq value is: #{seq}"
      end
      msg += "\nnextEvent is #{nextEvent}"
      msg += "\nintervention_time is #{intervention_time ? "true" : "false"}\n"
      msg
    end

    def advanceExpectationsAfterIntervention(data, seq, current_session_history, intervention_to_post, interventions_available_count, interventions_seen_count, session_plan, nextEvent)
      current_session_history.push "intervention:#{intervention_to_post}"
      interventions_seen_count = data["message"]["interventions_seen"].length
      interventions_available_count = data["message"]["interventions_available"].length
      seq += 1
      nextEvent = session_plan[seq]
      #print "\nAfter intervention, advancing expectations ready for position #{seq}: nextEvent is now expected to be #{session_plan[seq]} (actually #{nextEvent})\n"

      return seq, interventions_available_count, interventions_seen_count, current_session_history, nextEvent
    end

    def advanceExpectationsAfterClassification(data, seq, session_plan, nextEvent, current_session_history, classification_id_index)
      context = getContextForAssert "preAdvanceExpectationsAfterClassification", session_plan, seq, current_session_history, nextEvent, data["message"]["intervention_time"]
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
      #print "\nAfter classifying, advancing expectations ready for position #{seq}: nextEvent is now expected to be #{session_plan[seq]} (actually #{nextEvent})\n"
      nextEvent = session_plan[seq]
      classification_id_index += 1
      interventions_seen_count = data["message"]["interventions_seen"].length
      interventions_available_count = data["message"]["interventions_available"].length
      return seq, classification_id_index, session_plan, nextEvent, current_session_history, interventions_available_count, interventions_seen_count
    end
##

end

## tests that could be added for robustness:

# new session when one already exists for this user (i.e. resume)
# full end to end across multiple sessions
# past intervention when not expected
# absent intervention when not expected
# future intervention when not expected
# classification when intervention was expected
# classification after end of experiment
# intervention after end of experiment
