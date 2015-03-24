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

- GET  /users/:user_id/interventions  will return all active interventions for a given user 
- POST /users/:user_id/interventions  will register an intervention for a user (see later for intervention format)
- GET /interventions/:intervention_id allows you to poll the status of an intervention. 

To register an intervention you need to send a POST request with the following data to the server: 

    {
      "project":"galaxy_zoo",
      "intervention_type":"prompt user about talk",
      "text_message":"please return",
      "cohort_id":1,
      "time_duration":60,
      "presentation_duration":20,
      "intervention_channel": "web model",
      "take_action" : "after_next_classification"
    }

- project : is the project on which the intervention should be taken
- intervention_type: the name of the intervention 
- text_message : an optional text message to send to the user
- cohort_id    : used along with a planout plan to select aditional split properties for the user
- time_duration: how long does the intervention remain active. If the user does not see the intervention in this time the intervention retires.
- presentation_duration: how long does the message stay on screen. 
- intervention_channel : how should the intervention be delivered
- take_action : at what point in a users experince should the intervention be presented


On POSTing an intervention the API will return that intervention along with an ID which allows researchers to poll for the current state of the intervention. 
