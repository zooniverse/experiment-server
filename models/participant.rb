class Participant
    include Mongoid::Document
    field :experiment_name, type: String
    field :cohort, type: String
    field :user_id, type: String
    field :active, type: Mongoid::Boolean
    field :non_blank_subjects_seen, type: Array
    field :blank_subjects_seen, type: Array
    field :non_blank_subjects_available, type: Array
    field :blank_subjects_available, type: Array
    field :most_liked_species, type: Array
    field :excluded, type: Mongoid::Boolean
    field :excluded_reason, type: String

    def as_json(args)
        result = super(args)
        id = result.delete("_id")
        result["id"] = id.to_s
        result
    end
end