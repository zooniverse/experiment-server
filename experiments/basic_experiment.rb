require 'plan_out'

module PlanOut
  class BasicExperiment < SimpleExperiment
    def setup

    end

    def self.projects
      ["planet_hunter"]
    end

    def assign(params, **inputs)
      userid = inputs[:userid]
      pageid = inputs[:pageid]
      classification_no = inputs[:classification_no]
      
      params[:button_color] = UniformChoice.new({
        choices: ['ff0000', '00ff00'],
        unit: userid
      })

      params[:button_text] = UniformChoice.new({
        choices: ["I'm voting", "I'm a voter"],
        unit: pageid,
        salt:'x'
      })

      params[:prompt] = UniformChoice.new({
        choices: ["If you vote I will give you a puppy", "If you vote I will give you a kitten", 'If you vote I will stab your face'],
        unit: userid,
        salt:'x'
      })
    end
  end
end
