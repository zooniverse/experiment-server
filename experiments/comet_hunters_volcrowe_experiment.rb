require 'plan_out'
require 'net/http'
require 'uri'
require 'net/http'
require 'net/https'

module PlanOut
  class CometHuntersVolcroweExperiment1 < PlanOut::SimpleExperiment
    def setup
      if ENV["SUGAR_HOST"].present?
        @@SUGAR_URL = "#{ENV["SUGAR_HOST"]}/experiment"
      else
        @@SUGAR_URL = "https://notifications-staging.zooniverse.org/experiment"
      end
      @@SUGAR_USERNAME = ENV["SUGAR_USERNAME"]
      @@SUGAR_PASSWORD = ENV["SUGAR_PASSWORD"]
      @@PRODUCTION_EXPERIMENT_SERVER = "http://experiments.zooniverse.org/"
      @@ENV = Assignment.new(@@PRODUCTION_EXPERIMENT_SERVER) # seed for random assignment to cohorts
      @@COHORT_CONTROL = "control"
      @@COHORT_QUESTIONS = "questions"
      @@COHORT_STATEMENTS = "statements"
      @@COHORT_INELIGIBLE = "(ineligible)"
      @@ANONYMOUS = "(anonymous)"
      @@PROJECT_TOKEN = "mschwamb/comet-hunters"
      @@EXPERIMENT_NAME = "CometHuntersVolcroweExperiment1"
      @@CLASSIFICATION_MARKER = "classification"
    end

    def self.projects
      [@@PROJECT_TOKEN]
    end

    def self.getCohort(user_id)
      if user_id==@@ANONYMOUS or defined?(user_id)==nil or user_ID.nil?
        @@COHORT_INELIGIBLE
      else
        UniformChoice.new({
          choices: [@@COHORT_CONTROL,@@COHORT_QUESTIONS,@@COHORT_STATEMENTS],
          unit: user_id
        }).execute(@@ENV)
      end
    end

    def self.getInterventionsAvailable(cohort)
      case cohort
      when @@COHORT_CONTROL then []
      when @@COHORT_QUESTIONS then [
        "valued-question-1",
        "valued-question-2",
        "valued-question-3",
        "valued-question-4",
        "valued-question-5",
        "gamisation-question-1",
        "gamisation-question-2",
        "gamisation-question-3",
        "gamisation-question-4",
        "gamisation-question-5",
        "learning-question-1",
        "learning-question-2",
        "learning-question-3",
        "learning-question-4",
        "learning-question-5"]
      when @@COHORT_STATEMENTS then [
        "valued-statement-1",
        "valued-statement-2",
        "valued-statement-3",
        "valued-statement-4",
        "valued-statement-5",
        "gamisation-statement-1",
        "gamisation-statement-2",
        "gamisation-statement-3",
        "gamisation-statement-4",
        "gamisation-statement-5",
        "learning-statement-1",
        "learning-statement-2",
        "learning-statement-3",
        "learning-statement-4",
        "learning-statement-5"]
      else []
      end
    end

    def self.registerParticipant(user_id)
      cohort = CometHuntersVolcroweExperiment1::getCohort(user_id)
      creation_params = {
            experiment_name:                @@EXPERIMENT_NAME,
            user_id:                        user_id,
            interventions_seen:             [],
            session_histories:              Hash.new,
            current_session_history:        []
      }
      if cohort
        interventions_available = CometHuntersVolcroweExperiment1::getInterventionsAvailable(cohort)
        creation_params.interventions_available = interventions_available
        creation_params.active = true
        creation_params.excluded = false
      else
        creation_params.interventions_available = []
        creation_params.active = false
        creation_params.excluded = true
        creation_params.excluded_reason = "No cohort available for user."
      end
      Participant.create(creation_params)
    end

    # get the participant for this user ID, registering the user first if they are not already registered
    def self.getParticipant(user_id)
      participant = Participant.where( experiment_name:@@EXPERIMENT_NAME , user_id:user_id ).first
      if not participant.present?
        participant = CometHuntersVolcroweExperiment1::registerParticipant(user_id)
      end
      participant
    end

    # pick a random number of classifications that need to occur before the first intervention
    def self.getClassificationsBeforeFirstIntervention(cohort)
      after = -1
      case cohort
      when @@COHORT_QUESTIONS
        # after 6th classification +/- 2
        after = rand(4..8)
      when @@COHORT_STATEMENTS
        # after 4th classification +/- 2
        after = rand(2..6)
      end
      after
    end

    # pick a random number of classifications that need to occur before the next intervention
    def self.getClassificationsBeforeNextIntervention(cohort)
      after = -1
      case cohort
      when @@COHORT_QUESTIONS
        # after 8 more classifications +/- 2
        after = rand(6..10)
      when @@COHORT_STATEMENTS
        # after 6 more classifications +/- 2
        after = rand(4..8)
      end
      after
    end

    # generate a random session plan according to cohort, long enough to use up all available interventions
    def self.generateSessionPlan(cohort, available_interventions)
      session_plan = []
      interventions = available_interventions.dup.shuffle
      if interventions.length > 0
        first_intervention = interventions.pop()
        classifications_before_first = CometHuntersVolcroweExperiment1::getClassificationsBeforeFirstIntervention(cohort)
        if classifications_before_first > -1
          classifications_before_first.times { session_plan.push(@@CLASSIFICATION_MARKER) }
          session_plan.push(first_intervention)
          while interventions.length > 0
            next_intervention = interventions.pop()
            classifications_before_next = CometHuntersVolcroweExperiment1::getClassificationsBeforeNextIntervention(cohort)
            if classifications_before_next > -1
              classifications_before_next.times { session_plan.push(@@CLASSIFICATION_MARKER) }
              session_plan.push(next_intervention)
            else
              session_plan = []
              break
            end
          end
          return session_plan
        end
      end
      return []
    end

    # ensure that participant data is set up correctly according to the provided session ID
    def self.verifySession(participant, session_id)
      if participant.current_session_id != session_id
        # new session
        participant.session_histories.current_session_id = participant.current_session_history.dup
        participant.current_session_id = session_id
        participant.seq_of_next_event = 0
        participant.current_session_history = []
        participant.current_session_plan = CometHuntersVolcroweExperiment1::generateSessionPlan(participant.cohort, participant.interventions_available)
      end
    end

    # if the next entry in the session plan matches the event we just completed, advance.
    def self.advancedIfNextEventSatisfied(this_event,participant)
      next_event = participant.current_session_plan[participant.seq_of_next_event]
      if this_event==@@CLASSIFICATION_MARKER and next_event==@@CLASSIFICATION_MARKER
        # expected classification satisfied
        participant.seq_of_next_event += 1
      elsif this_event==next_event
        # expected intervention satisfied
        participant.seq_of_next_event += 1
      else
        # mismatch - it is recorded but we do not advance.
      end
      if participant.seq_of_next_event >= participant.current_session_plan.length
        # session plan complete
        participant.active = false
        # TODO: do we need to do more here? e.g. check all used? archive the session?
      end
    end

    def self.getJSONPostBodyForSugar(participant)
      {experiments: [{
        user_id: participant.user_id,
        message: participant.to_json,
        section: @@PROJECT_TOKEN,
        delivered: false
      }]}.to_json
    end

    def self.postLatestToSugar(participant, session_id)
      uri = URI(@@SUGAR_URL)
      https = Net::HTTP.new(uri.host,uri.port)
      https.use_ssl = true
      req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' => 'application/json'})
      req.basic_auth @@SUGAR_USERNAME, @@SUGAR_PASSWORD
      req.body = CometHuntersVolcroweExperiment1::getJSONPostBodyForSugar(participant)
      res = https.request(req)
      [res.code, res.body]
    end

    # upon notification that a classification has ended, update participant and post latest data to Sugar
    def self.endClassification(user_id, session_id, classification_id)
      # ensure the user is registered
      participant = CometHuntersVolcroweExperiment1::getParticipant(user_id)
      CometHuntersVolcroweExperiment1::verifySession(participant, session_id)
      participant.current_session_history.push "classification:#{classification_id}"
      CometHuntersVolcroweExperiment1::advancedIfNextEventSatisfied(@@CLASSIFICATION_MARKER,participant)
      participant.save()
      CometHuntersVolcroweExperiment1::postLatestToSugar(participant)
    end

    # upon notification that an intervention has ended, update participant and post latest data to Sugar
    def self.endIntervention(user_id, session_id, intervention_id)
      # ensure the user is registered
      participant = CometHuntersVolcroweExperiment1::getParticipant(user_id)
      participant.interventions_available.delete intervention_id
      participant.interventions_seen.push intervention_id
      CometHuntersVolcroweExperiment1::verifySession(participant, session_id)
      participant.current_session_history.push "intervention:#{intervention_id}"
      CometHuntersVolcroweExperiment1::advancedIfNextEventSatisfied(intervention_id,participant)
      participant.save()
      CometHuntersVolcroweExperiment1::postLatestToSugar(participant)
    end

    def assign(params, **inputs)
      userid = inputs[:userid]

      params[:cohort] = UniformChoice.new({
        choices: [@@COHORT_CONTROL, @@COHORT_QUESTIONS, @@COHORT_STATEMENTS],
        unit: userid
      })
    end
  end
end