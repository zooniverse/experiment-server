class Participant
    include Mongoid::Document
    field :experiment_name, type: String
    field :cohort, type: String
    field :user_id, type: String
    field :active, type: Mongoid::Boolean
    field :num_random_subjects_seen, type: Integer
    field :num_random_subjects_available, type: Integer
    field :insertion_subjects_seen, type: Array
    field :insertion_subjects_available, type: Array
    field :most_liked_species, type: Array
    field :fallback, type: Mongoid::Boolean
    field :fallback_reason, type: String

    def as_json(args)
        result = super(args)
        id = result.delete("_id")
        result["id"] = id.to_s
        result
    end
end