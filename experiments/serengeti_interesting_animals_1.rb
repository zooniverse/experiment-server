require 'plan_out'
require "mysql"

module PlanOut
  class SerengetiInterestingAnimalsExperiment1 < PlanOut::SimpleExperiment
    def setup

    end

    def self.projects
      ["serengeti"]
    end

    def assign(params, **inputs)
      params[:cohort] = PlanOut.getCohort(inputs[:userid])
    end
  end

  def self.getCohort(user_id)
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
  end
end