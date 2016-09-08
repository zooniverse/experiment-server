class Participant
    include Mongoid::Document
    field :experiment_name, type: String
    field :project_slug, type: String
    field :cohort, type: String
    field :user_id, type: String
    field :active, type: Mongoid::Boolean
    field :excluded, type: Mongoid::Boolean
    field :excluded_reason, type: String
    field :interventions_available, type: Array
    field :interventions_seen, type: Array
    field :original_session_plans, type: Hash
    field :session_histories, type: Hash
    field :current_session_id, type: String
    field :current_session_history, type: Array
    field :current_session_plan, type: Array
    field :seq_of_next_event, type: Integer
    field :intervention_time, type: Mongoid::Boolean
    field :next_event, type: String

    def as_json(args)
        result = super(args)
        id = result.delete("_id")
        result["id"] = id.to_s
        result
    end
end