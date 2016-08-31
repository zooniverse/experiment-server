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
        #binding.pry
        #
        #step = 1
        #binding.pry
        #while nextEvent==@@CLASSIFICATION_MARKER
        #  step += 1
        #  classification_id_index += 1
        #  uri2 = URI.parse("#{@@SERVER_URL}/experiment/CometHuntersVolcroweExperiment1/user/#{@@TEST_STATEMENTS_USER_ID}/session/#{@@FIRST_SESSION_ID}/classification/#{@@CLASSIFICATION_IDS[classification_id_index]}")
        #  http2 = Net::HTTP.new(uri2.host, uri2.port)
        #  request2 = Net::HTTP::Post.new(uri2.request_uri)
        #  response2 = http2.request(request2)
        #  assert_equal("200",response2.code)
        #  data2 = JSON.parse(response2.body)
        #  assert_equal(@@FIRST_SESSION_ID,data2["message"]["current_session_id"], "After #{step} classifications, expected session ID not to change.")
        #  seq += 1
        #  assert_equal(seq,data2["message"]["seq_of_next_event"],"After #{step} classifications, expected session plan pointer to advance.")
        #  assert_equal(session_plan,data2["message"]["current_session_plan"],"After #{step} classifications, expected session plan not to change.")
        #  current_session_history.push "classification:#{@@CLASSIFICATION_IDS[classification_id_index]}"
        #  assert_equal(current_session_history,data2["message"]["current_session_history"],"After #{step} classifications, expected current session history to be updated.")
        #  nextEvent = session_plan[seq]
        #end
        #assert_not_equal(@@CLASSIFICATION_MARKER,session_plan[seq],"After #{step} classifications, verifying test logic: Expected the next event in the session plan to be an intervention.")
        ## now post the intervention.
        ## and check everything.
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