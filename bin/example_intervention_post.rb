#!/bin/bash
host=http://localhost:4567/users/1/interventions
curl --data "project=galaxy_zoo&intervention_type=short&text_message=please return&cohort_id=1&time_duration=60&presentation_duration=20&intervention_channel=web model&take_action=after_next_classification" $host
