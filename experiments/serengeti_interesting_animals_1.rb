require 'plan_out'
require "mysql"

module PlanOut
  class SerengetiInterestingAnimalsExperiment1 < PlanOut::SimpleExperiment
    def setup

    end

    def self.projects
      ["serengeti"]
    end

    def self.getCohort(user_id)
      UniformChoice.new({
          choices: ['control', 'interesting'],
          unit: user_id
        })
    end

    def self.registerParticipant(experiment_name,user_id)
      Participant.create({experiment_name:                experiment_name,
                          user_id:                        user_id,
                          active:                         true,
                          num_random_subjects_seen:       0,
                          num_random_subjects_available:  3,
                          insertion_subjects_seen:        [],
                          insertion_subjects_available:   ["A","B","C"]
                         })
    end

    def assign(params, **inputs)
      participant = Participant.where( experiment_name:params[:experiment_name] , user_id:params[:user_id] ).first
      if participant
        #status 200
        participant.to_json
      else
        participant = self.class.registerParticipant("SerengetiInterestingAnimalsExperiment1",inputs[:user_id])
        if participant
          #status 201
          participant.attributes.each do |attr_name, attr_value|
            params[attr_name]=attr_value unless attr_name=="_id"
          end
          cohort = self.class.getCohort(inputs[:user_id])
          participant[:cohort] = cohort
          participant.save
          params[:cohort] = cohort
          params[:message] = "Successfully registered #{params[:user_id]} as a participant in experiment #{params[:experiment_name]}"
        else
          halt 500, {'Content-Type' => 'application/json'}, '{"error":"Could not register participant #{params[:user_id]} for experiment #{params[:experiment_name]}."}'
        end
      end
    end
  end
end

__END__

    # check if participant's cohort has been previously generated or changed - if so then return that.
    participant = Participant.where( experiment_name:"SerengetiInterestingAnimalsExperiment1" , user_id:user_id ).first
    if participant
      cohort = participant[:cohort]
    else
      # select cohort
      cohort = UniformChoice.new({
        choices: ['control', 'interesting'],
        unit: user_id
      })
    end
    return cohort
