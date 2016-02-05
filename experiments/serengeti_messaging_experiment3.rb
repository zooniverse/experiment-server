require 'plan_out'

module PlanOut
  class SerengetiMessagingExperiment3 < PlanOut::SimpleExperiment
    def setup

    end

    def self.projects
      ["serengeti"]
    end

    def assign(params, **inputs)
      userid = inputs[:userid]

      params[:cohort] = UniformChoice.new({
        choices: ['control', 'experimental_ui'],
        unit: userid
      })

    end
  end
end
