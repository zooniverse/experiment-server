# ZooniverseExperimentServer
Implementation of planout for zooniverse for A/B splits and logging. 


Experiments defined in /experiments. 

Use the server by hitting up the following routes. All replies in JSON

- GET /active_experiments?project= lists active experiments with an optional project param to limit it to experiments on a given project
- GET /experiment/:experiment_name?userid=&pageid= gives back the params for an experiment given userid pageid etc. These params can be anything you want to select on, could be classification count etc. and should match what is defined in the experiment file.
- POST /experiment/:experiment_name/log/:log_type will log all params to the experiment under the label log_type. 

Note that :experiment_name should be replaced (without the colon) by one of the values returned from `active_experiments`.

New experiments will be accepted using pull requests.

#Intervention API 

While planout provides an elegant way to run static A/B splits, often what we need is an intervention based on external models or data. The intervention API allows third parties to register interventions to be taken for a given user. 

- GET  /users/:user_id/interventions will return all active interventions for a given user, except those for experiments which the user has been opted out of
- POST /users/:user_id/interventions will register an intervention for a user (see later for intervention format)
- GET /interventions/:intervention_id allows you to poll the status of an intervention. 
- POST /interventions/:intervention_id/detected allows you to mark an intervention as detected
- POST /interventions/:intervention_id/delivered allows you to mark an intervention as delivered
- POST /interventions/:intervention_id/dismissed allows you to mark an intervention as dismissed
- POST /interventions/:intervention_id/completed allows you to mark an intervention as completed
- GET  /users/:user_id/optout will return the current opt out settings for the user for this experiment (project and experiment_name must be specified)
- POST /users/:user_id/optout will opt out the user from the specified experiment (project and experiment_name must be specified). This means that any interventions posted to this experiment for this user will be suppressed and not returned or modifiable by the API.


To register an intervention you need to send a POST request with the following data to the server: 

    {
      "project":"galaxy_zoo",
      "experiment_name":"name of experiment",
      "cohort_id":1,
      "preconfigured_id":1,
      "state": "active"
      "intervention_type":"prompt user about talk",
      "text_message":"please return",
      "time_duration":60,
      "presentation_duration":20,
      "intervention_channel": "web model",
      "take_action" : "after_next_classification",
    }

- project : is the project on which the intervention should be taken
- intervention_type: the name of the intervention 
- preconfigured_id: the id of the message to display (currently 1, 2 or 3 only)
- experiment_name: the name of the experiment
- text_message : an optional text message to send to the user
- cohort_id    : used along with a planout plan to select additional split properties for the user
- time_duration: how long does the intervention remain active (in seconds). If the user does not see the intervention in this time the intervention is retired server-side before any client can see it (moves from active to inactive state)
- presentation_duration: how long does the message stay on screen (in seconds) 
- intervention_channel : how should the intervention be delivered
- take_action : at what point in a user's experience should the intervention be presented
- state: the state of the intervention: initially "active", until the first GET after time_duration has passed, at which point it becomes "inactive". An active intervention will be set to "detected" when the client reports detection, and "delivered" when the client reports delivery. Additionally a delivered intervention may be set to "dismissed" if the user dismissed it before the presentation_duration has elapsed, and the client can set it to "completed" once the presentation_duration has elapsed.

On POSTing an intervention the API will return that intervention along with an ID which allows researchers to poll for the current state of the intervention. It will also return information about the current user's opt out status, and a value showing whether or not the user's current opt out status will cause this intervention to be suppressed.

#Example endpoints 

## Create intervention 
See [here](https://github.com/zooniverse/ZooniverseExperimentServer/blob/master/bin/example_intervention_post.rb) for an example of creating an intervention 

## Interventions for a user 
[example](http://experiments.zooniverse.org/users/1/interventions)

## Poll interaction 
[example](http://experiments.zooniverse.org/interventions/551188293033630001000000)

