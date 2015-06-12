require 'plan_out'
require "mysql"
require "pry"

module PlanOut
  class SerengetiInterestingAnimalsExperiment1 < PlanOut::SimpleExperiment
    @@ENV = Assignment.new('http://experiments.zooniverse.org/')  # seed for random assignment to cohorts
    @@SUBJECTS_TO_INSERT_PER_SPECIES = 10                         # how many known subjects will be inserted for each liked species
    @@INSERTION_RATIO = 1.5                                       # how many times more random subjects should appear than inserted images
    @@COHORT_CONTROL = "control"
    @@COHORT_INSERTION = "interesting"

    def setup

    end

    def self.projects
      ["serengeti"]
    end

    def self.getCohort(user_id)
      UniformChoice.new({
          choices: ['control', 'interesting'],
          unit: user_id
        }).execute(@@ENV)
    end

    def self.getLikedSpecies(userID,limit)
       data = []
       begin
          con = Mysql.new 'zooniverse-db1.cezuuccr9cw6.us-east-1.rds.amazonaws.com', 'geordi-agent', '7yofU[GPO3?lAOD', 'geordi'
          query = 'SELECT secondaryID FROM user_profile WHERE userID="'+userID+'" ORDER BY score DESC;'
          rs = con.query(query)
          rs.each do |row|
            data << row[0]
          end
      rescue Mysql::Error => e
          return nil
      ensure
          con.close if con
      end
      if data && data.length > 0
        data.slice(0,limit)
      else
        nil
      end
    end

    def self.getInsertionSubjects(species,limit)
      data = nil
      begin
          con = Mysql.new 'zooniverse-db1.cezuuccr9cw6.us-east-1.rds.amazonaws.com', 'geordi-agent', '7yofU[GPO3?lAOD', 'geordi'
          query = 'SELECT subjectIDs FROM random_known_subjects_per_species WHERE species="'+species+'" LIMIT 1;'
          rs = con.query(query)
          rs.each do |row|
            data = row[0].to_s
          end
      rescue Mysql::Error => e
          return nil
      ensure
          con.close if con
      end
      if data && data!=""
        data.split(',').slice(0,limit)
      else
        nil
      end
    end

    def self.registerParticipant(experiment_name,user_id)
      Participant.create({experiment_name:                experiment_name,
                          user_id:                        user_id,
                          active:                         true,
                          num_random_subjects_seen:       0,
                          insertion_subjects_seen:        []
                         })
    end

    def self.assignToControl(participant,active=true)
      participant[:active] = active
      participant[:cohort] = "control"
      # user is not part of experiment - clear all "available" data (but leave a record of "seen")
      participant[:num_random_subjects_available] = 0
      participant[:insertion_subjects_available] = []
    end

    def self.initializeParticipant(user_id,experiment_name,params,participant)
      if participant
        cohort = SerengetiInterestingAnimalsExperiment1::getCohort(user_id)
        participant[:cohort] = cohort
        if cohort==@@COHORT_CONTROL
          SerengetiInterestingAnimalsExperiment1.assignToControl(participant,true)
          params[:message] = "#{user_id} assigned to control cohort for experiment #{experiment_name}"
        elsif cohort==@@COHORT_INSERTION
          speciesList = SerengetiInterestingAnimalsExperiment1::getLikedSpecies(user_id,2)
          if speciesList && speciesList.length > 0
            participant[:most_liked_species] = speciesList
            subjectIDs = []
            speciesList.each do |species|
                # insert subjects for this species
                subjectIDs.concat(SerengetiInterestingAnimalsExperiment1::getInsertionSubjects(species,@@SUBJECTS_TO_INSERT_PER_SPECIES))
            end
            if subjectIDs.length > 0
              participant[:insertion_subjects_available] = subjectIDs
              participant[:num_random_subjects_available] = subjectIDs.length * @@INSERTION_RATIO
            else
              SerengetiInterestingAnimalsExperiment1.assignToControl(participant,false)
              participant[:excluded] = true
              participant[:excluded_reason] = "Unable to find subjects to insert for #{user_id} in experiment #{experiment_name} - treating as a control user."
            end
          else
            SerengetiInterestingAnimalsExperiment1.assignToControl(participant,false)
            participant[:excluded] = true
            participant[:excluded_reason] = "Unable to establish preferences for #{user_id} in experiment #{experiment_name} - treating as a control user."
          end
          params[:message] = "Successfully registered #{user_id} as a participant in experiment #{experiment_name}"
        else
          SerengetiInterestingAnimalsExperiment1.assignToControl(participant,false)
          participant[:excluded] = true
          participant[:excluded_reason] = "Unrecognized cohort #{cohort} was assigned for #{user_id} in experiment #{experiment_name}. Assigning to control."
        end
        participant.save
        participant.attributes.each do |attr_name, attr_value|
          params[attr_name]=attr_value unless attr_name=="_id"
        end
      else
        params[:error] = "Could not register participant #{user_id} for experiment #{experiment_name} due to internal error."
      end

    end

    def assign(params, **inputs)
      if inputs[:user_id].present?
        participant = Participant.where( experiment_name:inputs[:experiment_name] , user_id:inputs[:user_id] ).first
        if participant
          #status 200
          params[:message] = "#{inputs[:user_id]} already assigned for experiment #{inputs[:experiment_name]}"
          participant.to_json
        else
          participant = SerengetiInterestingAnimalsExperiment1::registerParticipant("SerengetiInterestingAnimalsExperiment1",inputs[:user_id])
          SerengetiInterestingAnimalsExperiment1::initializeParticipant(inputs[:user_id],inputs[:experiment_name],params,participant)
        end
        participant.attributes.each do |attr_name, attr_value|
          params[attr_name]=attr_value unless attr_name=="_id"
        end
      else
        params[:error] = "Missing user_id."
      end
    end
  end
end