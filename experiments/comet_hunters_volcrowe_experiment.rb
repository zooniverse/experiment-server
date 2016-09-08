require 'plan_out'
require 'uri'
require 'net/http'
require 'net/https'

module PlanOut
  class CometHuntersVolcroweExperiment1 < PlanOut::SimpleExperiment
    @@SUGAR_STAGING_URL = "https://notifications-staging.zooniverse.org/experiment"
    @@SUGAR_PRODUCTION_URL = "https://notifications.zooniverse.org/experiment"
    @@SUGAR_URL = !ENV["SUGAR_HOST"].nil? ? "#{ENV["SUGAR_HOST"]}/experiment" : @@SUGAR_STAGING_URL
    @@SUGAR_USERNAME = ENV["SUGAR_USERNAME"]
    @@SUGAR_PASSWORD = ENV["SUGAR_PASSWORD"]
    @@PRODUCTION_EXPERIMENT_SERVER = "http://experiments.zooniverse.org/"
    @@ENV = Assignment.new(@@PRODUCTION_EXPERIMENT_SERVER) # seed for random assignment to cohorts
    @@COHORT_CONTROL = "control"
    @@COHORT_QUESTIONS = "questions"
    @@COHORT_STATEMENTS = "statements"
    @@COHORT_INELIGIBLE = "(ineligible)"
    @@ANONYMOUS = "(anonymous)"
    @@PROJECT_SLUG_PRODUCTION = "mschwamb/comet-hunters"
    @@PROJECT_SLUG_DEVELOPMENT = "mschwamb/planet-four-terrains"
    @@EXPERIMENT_NAME = "CometHuntersVolcroweExperiment1"
    @@CLASSIFICATION_MARKER = "classification"

    def setup
      if @@SUGAR_URL == @@SUGAR_PRODUCTION_URL
        @@PROJECT_SLUG = @@PROJECT_SLUG_PRODUCTION
      else
        @@PROJECT_SLUG = @@PROJECT_SLUG_DEVELOPMENT
      end
    end

    def self.getExperimentName
      @@EXPERIMENT_NAME
    end

    def self.getControlCohort
      @@COHORT_CONTROL
    end

    def self.getStatementsCohort
      @@COHORT_STATEMENTS
    end

    def self.getQuestionsCohort
      @@COHORT_QUESTIONS
    end

    def self.ensureNotArray(jsonString)
      if jsonString!=""
        obj = JSON.parse(jsonString.dup)
        if obj.kind_of?(Array) and obj.length==1
          obj = obj[0]
        end
        obj.to_json
      else
        jsonString
      end
    end

    def self.projects
      [@@PROJECT_SLUG]
    end

    def self.getCohort(user_id)
      if user_id==@@ANONYMOUS or defined?(user_id)==nil or user_id.nil?
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
            project_slug:                   @@PROJECT_SLUG,
            cohort:                         cohort,
            user_id:                        user_id,
            active:                         true,
            excluded:                       false,
            excluded_reason:                nil,
            interventions_available:        [],
            interventions_seen:             [],
            original_session_plans:         Hash.new,
            session_histories:              Hash.new,
            current_session_id:             nil,
            current_session_history:        [],
            current_session_plan:           [],
            seq_of_next_event:              -1,
            intervention_time:              false,
            next_event:                     @@CLASSIFICATION_MARKER
      }
      if cohort
        creation_params[:interventions_available] = CometHuntersVolcroweExperiment1::getInterventionsAvailable(cohort)
      else
        creation_params[:active] = false
        creation_params[:excluded] = true
        creation_params[:excluded_reason] = "No cohort available for user."
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

    # start a new session (or restart the session)
    def self.startOrRestartSession(participant, session_id)
      # archive the session history for the previous session
      if !participant.current_session_id.nil?
        participant.session_histories[participant.current_session_id] = participant.current_session_history.dup
      end

      # back up first non-nil session plan for each session_id
      if !participant.current_session_id.nil? and !participant.current_session_plan.nil? and !participant.original_session_plans.key?(participant.current_session_id)
        participant.original_session_plans[participant.current_session_id] = participant.current_session_plan
      end

      # if not a restart, clear the current session log and mark that we are now in the new session
      if participant.current_session_id != session_id
        participant.current_session_history = []
        participant.current_session_id = session_id
      end

      # generate a new plan for this session, and point to the start of it
      participant.current_session_plan = CometHuntersVolcroweExperiment1::generateSessionPlan(participant.cohort, participant.interventions_available)
      if participant.current_session_plan.length > 0
        participant.seq_of_next_event = 0
      end
    end

    # ensure that participant data is set up correctly according to the provided session ID
    def self.verifySession(participant, session_id)
      if participant.current_session_id.nil? or participant.current_session_id != session_id
        # new session
        CometHuntersVolcroweExperiment1::startOrRestartSession(participant, session_id)
      end
    end

    # if the next entry in the session plan matches the event we just completed, advance.
    def self.advanceIfNextEventSatisfied(this_event, participant, session_id)
      if (participant.cohort == @@COHORT_QUESTIONS or participant.cohort == @@COHORT_STATEMENTS)
        if this_event == @@CLASSIFICATION_MARKER and participant.next_event == @@CLASSIFICATION_MARKER
          # expected classification satisfied
          participant.seq_of_next_event += 1
        elsif this_event == participant.next_event
          # expected intervention satisfied
          participant.seq_of_next_event += 1
        else
          # mismatch - it is recorded but we do not advance.

          # if we encountered an intervention, that features in the session plan somewhere in the future,
          # we have to come up with a new session plan for this session, excluding that intervention
          # (Note: it has already been marked unavailable so just regenerating a new plan is sufficient).
          if this_event != @@CLASSIFICATION_MARKER and participant.current_session_plan[participant.seq_of_next_event..-1].include?(this_event)
            CometHuntersVolcroweExperiment1::startOrRestartSession(participant, session_id)
          end
        end

        participant.next_event = participant.current_session_plan[participant.seq_of_next_event]
        participant.intervention_time = (participant.next_event != @@CLASSIFICATION_MARKER)
      else
        participant.next_event = @@CLASSIFICATION_MARKER
        participant.intervention_time = false
      end

      # check for end of experiment (ie completion of last intervention)
      if (participant.cohort == @@COHORT_QUESTIONS or participant.cohort == @@COHORT_STATEMENTS) and participant.seq_of_next_event >= participant.current_session_plan.length
        # session plan complete
        participant.active = true # for this experiment, we're keeping partipants active after completing the session plan.
                                  # Change this line (and tests) if that is not what is wanted.
        participant.next_event = nil
        participant.intervention_time = false
      end
    end

    def self.getJSONPostBodyForSugar(participant)
      {experiments: [{
        user_id: participant.user_id,
        message: participant,
        section: @@PROJECT_SLUG,
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
      response = https.request(req)
      body = CometHuntersVolcroweExperiment1::ensureNotArray(response.body)
      [response.code, body] # response.body is a json string
    end

    # upon notification that a classification has ended, update participant and post latest data to Sugar
    def self.endClassification(user_id, session_id, classification_id)
      # ensure the user is registered
      participant = CometHuntersVolcroweExperiment1::getParticipant(user_id)
      CometHuntersVolcroweExperiment1::verifySession(participant, session_id)
      participant.current_session_history.push "classification:#{classification_id}"
      CometHuntersVolcroweExperiment1::advanceIfNextEventSatisfied(@@CLASSIFICATION_MARKER, participant, session_id)
      sugar_response = CometHuntersVolcroweExperiment1::postLatestToSugar(participant,session_id) # returns json
      participant.save!
      sugar_response
    end

    # upon notification that an intervention has ended, update participant and post latest data to Sugar
    def self.endIntervention(user_id, session_id, intervention_id)
      # ensure the user is registered
      participant = CometHuntersVolcroweExperiment1::getParticipant(user_id)
      participant.interventions_available.delete intervention_id
      participant.interventions_seen.push intervention_id
      CometHuntersVolcroweExperiment1::verifySession(participant, session_id)
      participant.current_session_history.push "intervention:#{intervention_id}"
      CometHuntersVolcroweExperiment1::advanceIfNextEventSatisfied(intervention_id, participant, session_id)
      sugar_response = CometHuntersVolcroweExperiment1::postLatestToSugar(participant,session_id) # returns json
      participant.save!
      sugar_response
    end

    #def assign(params, **inputs)
    #  userid = inputs[:userid]
    #
    #  params[:cohort] = UniformChoice.new({
    #    choices: [@@COHORT_CONTROL, @@COHORT_QUESTIONS, @@COHORT_STATEMENTS],
    #    unit: userid
    #  })
    #end
  end
end