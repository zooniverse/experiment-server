require 'plan_out'

module PlanOut
  class KelpExperiment < SimpleExperiment
    def setup

    end

    def self.projects
      ["kelp"]
    end

    def assign(params, **inputs)
      userid = inputs[:userid]
      pageid = inputs[:pageid]

      params[:button_color] = UniformChoice.new({
        choices: ['ff0000', '00ff00'],
        unit: pageid
      })

      params[:goals] = UniformChoice.new({
        choices: [10, 20, 30],
        unit: userid,
        salt:'x'
      })
    end
  end
end
