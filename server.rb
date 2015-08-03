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

def register_participant(experiment_name,user_id)
  experiment = get_experiment(experiment_name).new
  participant = experiment.class.registerParticipant(experiment_name,user_id)
  if participant.present?
    status 201
    participant[:cohort] = experiment.class.getCohort(user_id)
    participant.save
    participant
  else
    nil
  end
end

get '/' do
  "OK"
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

# if set to true, then opt outs are handled silently: interventions are hidden if the user is opted out for
# that experiment, and opt out details are not returned except from the opt out methods. setting this to false
# may be useful during development.
SUPPRESS_INTERVENTIONS_FOR_OPTED_OUT_USERS = true

# helper method for checking, creating and updating opt out for a user
# if set_opted_out is true, any unset or false value for "opted out" will be overwritten and set to true
# a bundle of data explaining what was found and what was done is returned
#
def check_opt_out_settings(user_id,experiment_name,project,set_opted_out = false)
  bundle = { :found => false, :created => false, :updated => false, :errors => nil, :status => 200, :data => nil }
  bundle[:found] = InterventionOptOut.find_by(:user_id => user_id, :experiment_name => experiment_name, :project => project)
  if bundle[:found]
    intervention_opt_out = bundle[:found]
    bundle[:found] = true
    bundle[:data] = intervention_opt_out.attributes
  else
    bundle[:found] = false
    intervention_opt_out = InterventionOptOut.create(:user_id => user_id, :experiment_name => experiment_name, :project => project)
    ok = intervention_opt_out.save
    if intervention_opt_out.errors.size > 0
      bundle[:status] = 400
      bundle[:errors] = intervention_opt_out.errors
    else
      if ok
        bundle[:status] = 201
        bundle[:created] = true
        bundle[:data] = intervention_opt_out.attributes
      else
        bundle[:status] = 500
      end
    end
  end
  if bundle[:errors].nil? and set_opted_out and intervention_opt_out.present? and not intervention_opt_out["opted_out"]
    if intervention_opt_out.optout! and intervention_opt_out.save
      bundle[:status] = 202
      bundle[:updated] = true
      bundle[:data] = intervention_opt_out.attributes
    else
      bundle[:status] = 500
    end
  end
  return bundle
end

def clean_opt_out_results(opt_out_results)
  opt_out_results.delete(:status)
  opt_out_results.delete(:data) if opt_out_results[:data].nil?
  opt_out_results.delete(:errors) if opt_out_results[:errors].nil?
  if opt_out_results[:data].present? and opt_out_results[:data]["_id"].present?
    opt_out_results[:data].delete("_id")
  end
end

get '/users/:user_id/interventions' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  results = Intervention.where( state: "active", user_id: params[:user_id])
  if params[:project]
    results = results.where(project: params[:project])
  end
  if params[:experiment_name]
    results = results.where(experiment_name: params[:experiment_name])
  end
  interventions = results.all
  if interventions.length == 0
    halt 200, {'Content-Type' => 'application/json'}, { :interventions => [], :error => "No interventions found for user #{params[:user_id]}" }.to_json
  else
    suppressed_count = 0
    if SUPPRESS_INTERVENTIONS_FOR_OPTED_OUT_USERS
      interventions = interventions.clone
      interventions_filtered = []
      interventions.each do |x|
        opt_out_results = check_opt_out_settings(params[:user_id],x[:experiment_name],x[:project])
        if opt_out_results[:data][:opted_out]
          suppressed_count += 1
        else
          interventions_filtered.push(x)
        end
      end
      {
        :interventions => interventions_filtered,
        :suppressed_interventions => suppressed_count
      }.to_json
    else
      opt_out_pairs = []
      interventions.each { |x|
        new_pair = {
          :experiment_name => x[:experiment_name] ,
          :project => x[:project]
        }
        if not opt_out_pairs.any?{|p| p[:experiment_name] == x[:experiment_name] and p[:project] == x[:project]}
          opt_out_pairs.push(new_pair)
        end
      }
      opt_outs = []
      any_creates = false
      opt_out_pairs.each { |p|
        opt_out_results = check_opt_out_settings(params[:user_id],p[:experiment_name],p[:project])
        any_creates = true if opt_out_results[:created]
        clean_opt_out_results(opt_out_results)
        opt_outs.push (opt_out_results)
      }
      status any_creates ? 201 : 200
      {
        :interventions => interventions,
        :opt_outs => opt_outs,
        :suppressed_interventions => suppressed_count
      }.to_json
    end
  end
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
                                       preconfigured_id:      params["preconfigured_id"],
                                       experiment_name:       params["experiment_name"],
                                       time_duration:         params["time_duration"],
                                       presentation_duration: params["presentation_duration"],
                                       intervention_channel:  params["intervention_channel"],
                                       take_action:           params["take_action"],
                                       details:               params["details"]
                                       })
  if intervention.valid?
    opt_out_results = check_opt_out_settings(params[:user_id],params[:experiment_name],params[:project])
    status opt_out_results[:created] ? 201 : 200
    clean_opt_out_results(opt_out_results)
    will_be_suppressed = false
    if SUPPRESS_INTERVENTIONS_FOR_OPTED_OUT_USERS
      if opt_out_results[:data][:opted_out]
        will_be_suppressed = true
      end
    end
    {
      :intervention => intervention,
      :opt_out => opt_out_results,
      :will_be_suppressed => will_be_suppressed
    }.to_json
  else
    halt 500, {'Content-Type' => 'application/json'}, { :errors => intervention.errors.messages }.to_json
  end
end

get '/interventions/:intervention_id' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  intervention = Intervention.find(params[:intervention_id])
  if intervention
    opt_out_results = check_opt_out_settings(intervention[:user_id],intervention[:experiment_name],intervention[:project])
    if SUPPRESS_INTERVENTIONS_FOR_OPTED_OUT_USERS and opt_out_results[:data][:opted_out]
      halt 405, {'Content-Type' => 'application/json'}, { :error => "Intervention #{params[:intervention_id]} exists but was suppressed due to user opt-out" }.to_json
    end
    status opt_out_results[:created] ? 201 : 200
    clean_opt_out_results(opt_out_results)
    {
      :intervention => intervention,
      :opt_out => opt_out_results
    }.to_json
  else
    halt 404, {'Content-Type' => 'application/json'}, { :error => "Intervention #{params[:intervention_id]} not found" }.to_json
  end
end

def update_intervention(intervention_id,method_to_call)
  intervention = Intervention.find(intervention_id)
  if intervention
    opt_out_results = check_opt_out_settings(intervention[:user_id],intervention[:experiment_name],intervention[:project])
    if SUPPRESS_INTERVENTIONS_FOR_OPTED_OUT_USERS and opt_out_results[:data][:opted_out]
      halt 405, {'Content-Type' => 'application/json'}, { :error => "Modifying intervention #{params[:intervention_id]} is disallowed due to user opt-out" }.to_json
    end
    intervention.send method_to_call
    if intervention.save
      status opt_out_results[:created] ? 201 : 200
      clean_opt_out_results(opt_out_results)
      {
        :intervention => intervention,
        :opt_out => opt_out_results,
        :will_be_suppressed => false
      }.to_json
    else
      halt 500, {'Content-Type' => 'application/json'}, { :error => "Could not update intervention #{params[:intervention_id]}" }.to_json
    end
  else
    halt 404, {'Content-Type' => 'application/json'}, { :error => "Intervention #{params[:intervention_id]} not found" }.to_json
  end
end

# mark an intervention as delivered - body is ignored
post '/interventions/:intervention_id/delivered' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  update_intervention(params[:intervention_id],:delivered!)
end

# mark an intervention as detected - body is ignored
post '/interventions/:intervention_id/detected' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  update_intervention(params[:intervention_id],:detected!)
end

# mark an intervention as dismissed - body is ignored
post '/interventions/:intervention_id/dismissed' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  update_intervention(params[:intervention_id],:detected!)
end

# mark an intervention as completed - body is ignored
post '/interventions/:intervention_id/completed' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  update_intervention(params[:intervention_id],:completed!)
end

# check opt out status for a user. if no record exists, a record marked as "not opted out" is created  - params must contain project and experiment name.
get '/users/:user_id/optout' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  opt_out_results = check_opt_out_settings(params[:user_id],params[:experiment_name],params[:project])
  status opt_out_results[:status]
  clean_opt_out_results(opt_out_results)
  opt_out_results.to_json
end

# mark an intervention participant as opted out - params must contain project and experiment name
post '/users/:user_id/optout' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  opt_out_results = check_opt_out_settings(params[:user_id],params[:experiment_name],params[:project],true)
  status opt_out_results[:status]
  clean_opt_out_results(opt_out_results)
  opt_out_results.to_json
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
    halt 200, {'Content-Type' => 'application/json'}, { :error => "No participants found for experiment #{params[:experiment_name]}" }.to_json
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
    Participant.where(experiment_name:params[:experiment_name]).delete
    { :message => "Successfully deleted all participants from experiment #{params[:experiment_name]}" }.to_json
  else
    halt 405, {'Content-Type' => 'application/json'}, { :error => "No participants to delete for experiment #{params[:experiment_name]}" }.to_json
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
#
# .. temporarily disabled, as it doesn't initialize blank arrays yet ... use request next N instead.
#
# post '/experiment/:experiment_name/participant/:user_id' do
#   content_type :json
#   headers \
#     "Access-Control-Allow-Origin"   => "*",
#     "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
#   if ADMIN_ENABLED
#     participants = Participant.where( experiment_name:params[:experiment_name] , user_id:params[:user_id] )
#     if participants.count > 0
#       halt 409, {'Content-Type' => 'application/json'}, { :error => "Participant #{params[:user_id]} already registered in experiment #{params[:experiment_name]}" }.to_json
#     else
#       participant = register_participant(params[:experiment_name],params[:user_id])
#       if participant.nil?
#         halt 500, {'Content-Type' => 'application/json'}, '{"error":"Could not register participant #{params[:user_id]} for experiment #{params[:experiment_name]}."}'
#       else
#         participant.to_json
#       end
#     end
#   else
#     halt 401, {'Content-Type' => 'application/json'}, '{"error":"Attempted to use administrator method."}'
#   end
# end

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

  total_available = participant[:blank_subjects_available].length + participant[:non_blank_subjects_available].length
  if total_available == 0
    experiment = get_experiment(params[:experiment_name]).new
    experiment.class.deactivateParticipant(participant)
    response = {
        :nextSubjectIDs => [],
        :participant => participant
    }
    response.to_json
  elsif total_available >= N
    blanks = participant[:blank_subjects_available].map do |e| e.dup end
    non_blanks = participant[:non_blank_subjects_available].map do |e| e.dup end
    selection_set = blanks.concat(non_blanks)
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
# post '/experiment/:experiment_name/participant/:user_id/random' do
#   content_type :json
#   headers \
#     "Access-Control-Allow-Origin"   => "*",
#     "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
#   participant = Participant.where( experiment_name:params[:experiment_name] , user_id:params[:user_id] ).first
#   if participant
#     status 200
#     if participant[:num_random_subjects_available] >= 1
#       participant[:num_random_subjects_seen]+=1
#       participant[:num_random_subjects_available]-=1
#       participant.save
#       participant.to_json
#     else
#       halt 409, {'Content-Type' => 'application/json'}, { :error => "No more random subjects available for participant #{params[:user_id]} in experiment #{params[:experiment_name]}", :participant => participant }.to_json
#     end
#   else
#     halt 404, {'Content-Type' => 'application/json'}, { :error => "Participant #{params[:user_id]} not found in experiment #{params[:experiment_name]}" }.to_json
#   end
# end

# mark an image as seen - accepts prefix not necessarily whole subject ID.
post '/experiment/:experiment_name/participant/:user_id/:subject_id' do
  content_type :json
  headers \
    "Access-Control-Allow-Origin"   => "*",
    "Access-Control-Expose-Headers" => "Access-Control-Allow-Origin"
  participant = Participant.where( experiment_name:params[:experiment_name] , user_id:params[:user_id] ).first
  if participant
    found = false
    no_blanks = false
    no_non_blanks = false
    if participant[:blank_subjects_available].size >= 1
      if participant[:blank_subjects_available].any? { |s| s.include?(params[:subject_id]) }
        found = true
        status 200
        pattern = Regexp.quote(params[:subject_id])
        idx = participant[:blank_subjects_available].index{|s| s =~ /^#{pattern}/ }
        if idx.present?
          subject_matched = participant[:blank_subjects_available][idx]
          updated_blanks_available = participant[:blank_subjects_available].clone
          updated_blanks_available.delete_if {|s| s =~ /^#{pattern}/ }
          participant.unset(:blank_subjects_available)
          participant.add_to_set(blank_subjects_available:updated_blanks_available)
          participant.save
          if participant[:blank_subjects_seen].size == 0
            participant[:blank_subjects_seen] = [subject_matched]
          else
            participant.add_to_set(blank_subjects_seen:subject_matched.to_s)
          end
        end
        participant.save
        participant.to_json
      end
    else
      no_blanks = true
    end
    if !found and participant[:non_blank_subjects_available].size >= 1
      if participant[:non_blank_subjects_available].any? { |s| s.include?(params[:subject_id]) }
        found = true
        status 200
        pattern = Regexp.quote(params[:subject_id])
        idx = participant[:non_blank_subjects_available].index{|s| s =~ /^#{pattern}/ }
        if idx.present?
          subject_matched = participant[:non_blank_subjects_available][idx]
          updated_non_blanks_available = participant[:non_blank_subjects_available].clone
          updated_non_blanks_available.delete_if {|s| s =~ /^#{pattern}/ }
          participant.unset(:non_blank_subjects_available)
          participant.add_to_set(non_blank_subjects_available:updated_non_blanks_available)
          participant.save
          if participant[:non_blank_subjects_seen].size == 0
            participant[:non_blank_subjects_seen] = [subject_matched]
          else
            participant.add_to_set(non_blank_subjects_seen:subject_matched.to_s)
          end
        end
        participant.save
        participant.to_json
      else
        no_non_blanks = true
      end
    end
    if participant[:blank_subjects_available].size == 0 and participant[:non_blank_subjects_available].size == 0
      experiment = get_experiment(params[:experiment_name]).new
      experiment.class.deactivateParticipant(participant)
      params[:message] = "#{params[:user_id]} has completed experiment #{params[:experiment_name]}."
      participant.attributes.each do |attr_name, attr_value|
        params[attr_name]=attr_value unless attr_name=="_id"
      end
    end
    if found
      participant.save
      participant.to_json
    else
      if no_blanks and no_non_blanks
        halt 409, {'Content-Type' => 'application/json'}, { :error => "#{params[:subject_id]} is not an available subject for participant #{params[:user_id]} in experiment #{params[:experiment_name]}", :participant => participant }.to_json
      else
        halt 409, {'Content-Type' => 'application/json'}, { :error => "No more subjects available for participant #{params[:user_id]} in experiment #{params[:experiment_name]}", :participant => participant }.to_json
      end
    end
  else
    halt 404, {'Content-Type' => 'application/json'}, { :error => "Participant #{params[:user_id]} not found in experiment #{params[:experiment_name]}" }.to_json
  end
end
