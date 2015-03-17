require 'plan_out'

module PlanOut
  class SerengetiInterestingAnimalsExperiment1 < PlanOut::SimpleExperiment
    def setup

    end

    def self.projects
      ["serengeti"]
    end

    def assign(params, **inputs)
      userid = inputs[:userid]

      params[:cohort] = UniformChoice.new({
        choices: ['control', 'interesting'],
        unit: userid
      })

    end
  end
end
