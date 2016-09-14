class InterventionOptOut
  include Mongoid::Document

  field :user_id, type: String
  field :experiment_name, type: String
  field :project, type: String
  field :opted_out, type: Boolean, default: false

  validates_inclusion_of :project, in: [ "galaxy_zoo", "mschwamb/comet-hunters", "mschwamb/planet-four-terrains", "mschwamb/hsc-comet-hunters-prototype" ], message: "Not a recognized project name. Supported project names are: galaxy_zoo, mschwamb/comet-hunters, mschwamb/planet-four-terrains, mschwamb/hsc-comet-hunters-prototype"
  validates_presence_of :experiment_name, message: "Experiment name must be specified"

  def as_json(args)
    result = super(args)
    id = result.delete("_id")
    result["id"] = id.to_s
    result
  end

  def optout!
    update_attributes! opted_out: true
  end

  def cancelOptOut!
    update_attributes! opted_out: false
  end

end
