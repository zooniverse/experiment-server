class Intervention
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user_id, type: String
  field :project, type: String
  field :preconfigured_id, type: Integer
  field :intervention_type, type: String
  field :text_message, type: String
  field :cohort_id, type: Integer
  field :experiment_name, type: String
  field :time_duration, type: Integer
  field :presentation_duration, type: Integer
  field :intervention_channel, type: String
  field :take_action, type: String
  field :details, type: Hash, default: {}
  field :state, type: String, default: 'active'

   validates_inclusion_of :preconfigured_id, in: [ 1, 2, 3 ], message: "Not a valid message ID. Supported values are: 1, 2, 3"
   validates_presence_of :cohort_id, message: "Cohort must be specified"
   validates_inclusion_of :project, in: [ "galaxy_zoo" ], message: "Not a recognized project name. Supported project names are: galaxy_zoo"
   validates_presence_of :experiment_name, message: "Experiment name must be specified"
   validates_numericality_of :presentation_duration, message: "Presentation duration must be an integer value"
   validates_numericality_of :time_duration, message: "Time duration must be an integer value"
   validates_inclusion_of :state , in: [ "active", "inactive", "delivered" ], message: "Not a valid state. Valid states are: active, inactive, delivered"
#  validates_inclusion_of :intervention_type, in: [ "short" ], message: "Not a valid intervention type"
#  validates_inclusion_of :intervention_channel, in: [ "web message", "web modal", "email" ], message: "Not a valid channel"
#  validates_inclusion_of :take_action , in: [ "after_next_classification", "before_next_classification", "now" ], message: "Not a valid action"

  after_find :check_retire

  def check_retire
    if Time.now > created_at + time_duration and state == 'active'
      update_attributes! state: "inactive"
    end
  end

  def as_json(args)
    result = super(args)
    id = result.delete("_id")
    result["id"] = id.to_s
    result
  end

  def delivered!
    update_attributes! state: "delivered"
  end
end
