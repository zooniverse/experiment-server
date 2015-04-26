require 'sinatra'
require 'json'
require_relative 'environment'

ADMIN_ENABLED = true

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

def register_participant(experiment_name,user_id)
  experiment = get_experiment(experiment_name).new
  participant = experiment.class.registerParticipant(experiment_name,user_id)
  if participant
    status 201
    participant[:cohort] = experiment.class.getCohort(user_id)
    participant.save
    participant
  else
    nil
  end
end

get '/active_experiments' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
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
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  results = Intervention.where( state: "active", user_id: params[:user_id])
  if params[:project]
    results = results.where(project_name: params[:project])
  end
  results.all.to_json
end

post '/users/:user_id/interventions' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
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
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  intervention = Intervention.find(params[:intervention_id])
  status 500 unless intervention
  intervention.to_json
end

###### Experimental Participant API
###### At the moment this only works for an experiment based around maintaining a set list of random & inserted subjects per user, but could be generalized.

get '/experiment/:experiment_name/participants' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  participants = Participant.where(experiment_name:params[:experiment_name])
  if participants.length>0
    participants.all.to_json
  else
    halt 404, {'Content-Type' => 'application/json'}, { :error => "No participants found for experiment #{params[:experiment_name]}" }.to_json
  end
end

get '/experiment/:experiment_name/participant/:user_id' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  participant = Participant.where( experiment_name:params[:experiment_name] , user_id:params[:user_id] ).first
  if participant
    participant.to_json
  else
    halt 404, {'Content-Type' => 'application/json'}, { :error => "Participant #{params[:user_id]} not found in experiment #{params[:experiment_name]}" }.to_json
  end
end

delete '/experiment/:experiment_name/participants' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  participants = Participant.where( experiment_name:params[:experiment_name] )
  if participants.count > 0
    status 200
    participants.all.delete
    { :message => "Successfully deleted all participants from experiment #{params[:experiment_name]}" }.to_json
  else
    halt 404, {'Content-Type' => 'application/json'}, { :error => "No participants to delete for experiment #{params[:experiment_name]}" }.to_json
  end
end

delete '/experiment/:experiment_name/participant/:user_id' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  participant = Participant.where( experiment_name:params[:experiment_name] , user_id:params[:user_id] ).first
  if participant
    status 200
    participant.delete
    { :message => "#{params[:user_id]} successfully deleted from experiment #{params[:experiment_name]}" }.to_json
  else
    halt 404, {'Content-Type' => 'application/json'}, { :error => "Participant #{params[:user_id]} not found in experiment #{params[:experiment_name]}" }.to_json
  end
end

# register this user in this experiment
post '/experiment/:experiment_name/participant/:user_id' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  if ADMIN_ENABLED
    participants = Participant.where( experiment_name:params[:experiment_name] , user_id:params[:user_id] )
    if participants.count > 0
      halt 409, {'Content-Type' => 'application/json'}, { :error => "Participant #{params[:user_id]} already registered in experiment #{params[:experiment_name]}" }.to_json
    else
      participant = register_participant(params[:experiment_name],params[:user_id])
      if participant is nil
        halt 500, {'Content-Type' => 'application/json'}, '{"error":"Could not register participant #{params[:user_id]} for experiment #{params[:experiment_name]}."}'
      else
        participant.to_json
      end
    end
  else
    halt 401, {'Content-Type' => 'application/json'}, '{"error":"Attempted to use administrator method."}'
  end
end

# get the next N subjects for this experimental participant (at random across both random & insertion set)
# this is read only, it does not modify the queues, it is not a 'pop'
# it will also ensure the participant is registered.
get '/experiment/:experiment_name/participant/:user_id/next/:number_of_subjects' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  N = params[:number_of_subjects].to_i
  participant = Participant.where( experiment_name:params[:experiment_name] , user_id:params[:user_id] ).first
  if !participant.present?
    participant = register_participant(params[:experiment_name],params[:user_id])
    if participant.nil?
      halt 500, {'Content-Type' => 'application/json'}, '{"error":"Could not register participant #{params[:user_id]} for experiment #{params[:experiment_name]}."}'
    end
    experiment = get_experiment(params[:experiment_name]).new
    experiment.class.initializeParticipant(params[:user_id],params[:experiment_name],params,participant)
  end
  status 200

  total_available = participant[:num_random_subjects_available].to_i + participant[:insertion_subjects_available].length
  if total_available >= N
    selection_set = participant[:insertion_subjects_available].map do |e| e.dup end
    for i in 1..participant[:num_random_subjects_available]
      selection_set << "RANDOM"
    end
    if selection_set.length < N
      halt 409, {'Content-Type' => 'application/json'}, { :error => "Only #{selection_set.length} subjects available - not enough to return #{N} for participant #{params[:user_id]} in experiment #{params[:experiment_name]}", :participant => participant }.to_json
    else
      selection_set = selection_set.shuffle
      response = {
        :nextSubjectIDs => selection_set.slice(0,N),
        :participant => participant
      }
      response.to_json
    end
  else
    halt 409, {'Content-Type' => 'application/json'}, { :error => "Only #{total_available} subjects available - not enough to return #{N} for participant #{params[:user_id]} in experiment #{params[:experiment_name]}", :participant => participant }.to_json
  end
end

# mark a random image as seen
post '/experiment/:experiment_name/participant/:user_id/random' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  participant = Participant.where( experiment_name:params[:experiment_name] , user_id:params[:user_id] ).first
  if participant
    status 200
    if participant[:num_random_subjects_available] >= 1
      participant[:num_random_subjects_seen]+=1
      participant[:num_random_subjects_available]-=1
      participant.save
      participant.to_json
    else
      halt 409, {'Content-Type' => 'application/json'}, { :error => "No more random subjects available for participant #{params[:user_id]} in experiment #{params[:experiment_name]}", :participant => participant }.to_json
    end
  else
    halt 404, {'Content-Type' => 'application/json'}, { :error => "Participant #{params[:user_id]} not found in experiment #{params[:experiment_name]}" }.to_json
  end
end

# mark an insertion image as seen
post '/experiment/:experiment_name/participant/:user_id/insertion/:subject_id' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  participant = Participant.where( experiment_name:params[:experiment_name] , user_id:params[:user_id] ).first
  if participant
    if participant[:insertion_subjects_available].size >= 1
      if participant[:insertion_subjects_available].include? params[:subject_id]
        status 200
        participant.pull(insertion_subjects_available:params[:subject_id])
        participant.push(insertion_subjects_seen:params[:subject_id])
        participant.save
        participant.to_json
      else
        halt 409, {'Content-Type' => 'application/json'}, { :error => "#{params[:subject_id]} is not an available subject for participant #{params[:user_id]} in experiment #{params[:experiment_name]}", :participant => participant }.to_json
      end
    else
      halt 409, {'Content-Type' => 'application/json'}, { :error => "No more random subjects available for participant #{params[:user_id]} in experiment #{params[:experiment_name]}", :participant => participant }.to_json
    end
  else
    halt 404, {'Content-Type' => 'application/json'}, { :error => "Participant #{params[:user_id]} not found in experiment #{params[:experiment_name]}" }.to_json
  end
end