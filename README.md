# ZooniverseExperimentServer
Implementation of planout for zooniverse for A/B splits and logging. 


Experiments defined in /experiments. 

Use the server by hitting up the following routes. All replies in JSON

- GET /active_experiments?project= lists active experiments with an optional project param to limit it to experiments on a given project
- GET /experiment/:experiment_name?user_id=&page_id= gives back the params for an experiment given user_id page_id etc. These params can be anything you want to select on, could be classification count etc.
- POST /experiment/:experiment_name/log/:log_type will log all params to the experiment under the label log_type. 


New experiemnts will be accepted using pull requests.
