require 'sinatra'
require 'json'
require_relative 'environment'


def active_experiments
  experiments = PlanOut.constants.collect{|experiment| experiment.to_s}.select{|experiment_name| experiment_name.include? "Experiment" }
  experiments - ["SimpleExperiment", "Experiment"]
end

def active_experiments_for_project(project)
  active_experiments.select{|p| get_experiment(p).projects.include? project}
end

def get_experiment(experiment_name)
  PlanOut.const_get(experiment_name)
end

get '/active_experiments' do
  content_type :json

  if project = params[:project]
    active_experiments_for_project(project).to_json
  else
    active_experiments.to_json
  end
end

get '/experiment/:experiment_name' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  experiment_params = params.inject({}){|h,(k,v)| h[k.to_sym] = v; h}
  experiment = get_experiment(params[:experiment_name])

  if experiment
    my_exp = experiment.new(**experiment_params)
    my_exp.get_params.to_json
  else
    status 404
  end
end

post '/experiment/:experiment_name/log/:log_type' do
  get_experiment(params[:experiment_name]).log_event(params[:log_type],params-[:log_type])
end

###### Intervention API

get '/users/:user_id/interventions' do
  content_type :json
  results = Intervention.where( state: "active", user_id: params[:user_id])
  if params[:project]
    results = results.where(project_name: params[:project])
  end
  results.all.to_json
end

post '/users/:user_id/interventions' do
  content_type :json
  intervention  = Intervention.create({user_id:               params["user_id"],
                                       project:               params["project"],
                                       intervention_type:     params["intervention_type"],
                                       text_message:          params["text_message"],
                                       cohort_id:             params["cohort_id"],
                                       experiment_name:       params["experiment_name"],
                                       time_duration:         params["time_duration"],
                                       presentation_duration: params["presentation_duration"],
                                       intervention_channel:  params["intervention_channel"],
                                       take_action:           params["take_action"],
                                       details:               params["details"]
                                       })
  status 500 unless intervention
  intervention.to_json
end

get '/interventions/:intervention_id' do
  content_type :json
  intervention = Intervention.find(params[:intervention_id])
  status 500 unless intervention
  intervention.to_json
end
