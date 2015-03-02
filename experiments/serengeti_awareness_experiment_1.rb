require 'plan_out'

module PlanOut
  class SerengetiAwarenessExperiment1 < PlanOut::SimpleExperiment
    def setup

    end

    def self.projects
      ["serengeti"]
    end

    def assign(params, **inputs)
      userid = inputs[:userid]

      params[:cohort] = UniformChoice.new({
        choices: ['control', 'both', 'self', 'crowd'],
        unit: userid
      })

    end
  end
end
