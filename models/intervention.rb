class Intervention
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user_id, type: String
  field :project, type: String
  field :intervention_type, type: String
  field :text_message,    type: String
  field :cohort_id,       type: Integer
  field :experiment_name, type: String
  field :time_duration, type: Integer
  field :presentation_duration, type: Integer
  field :intervention_channel, type: String
  field :take_action, type: String
  field :details, type: Hash, default: {}
  field :state, type: String, default: 'active'

  validates_inclusion_of :intervention_channel, in: [ "web message", "web model", "email" ], message: "not a valid channel"
  validates_inclusion_of :take_action , in: [ "after_next_classification", "before_next_classification", "now" ], message: "not a valid action"
  validates_inclusion_of :state , in: [ "active", "inactive", "delivered" ], message: "Not a valid state"

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
