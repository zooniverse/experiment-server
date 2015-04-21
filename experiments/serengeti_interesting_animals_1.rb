require 'plan_out'
require "mysql"
require "pry"

module PlanOut
  class SerengetiInterestingAnimalsExperiment1 < PlanOut::SimpleExperiment
    @@ENV = Assignment.new('http://experiments.zooniverse.org/')  # seed for random assignment to cohorts
    @@SUBJECTS_TO_INSERT_PER_SPECIES = 20                         # how many known subjects will be inserted for each liked species
    @@INSERTION_RATIO = 3                                         # how many times more random subjects should appear than inserted images
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

    def self.getInsertionSubjects(species,limit)
      data = nil
      begin
          con = Mysql.new 'zooniverse-db1.cezuuccr9cw6.us-east-1.rds.amazonaws.com', 'geordi-agent', '7yofU[GPO3?lAOD', 'geordi'
          query = 'SELECT subjectIDs FROM species_subjects WHERE species="'+species+'" LIMIT 1;'
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

    def assignToControl(participant,active=true)
      participant[:active] = active
      # user is not part of experiment - clear all data.
      participant[:num_random_subjects_available] = 0
      participant[:num_random_subjects_seen] = 0
      participant[:insertion_subjects_available] = []
      participant[:insertion_subjects_seen] = []
    end

    def assign(params, **inputs)
      participant = Participant.where( experiment_name:params[:experiment_name] , user_id:params[:user_id] ).first
      if participant
        #status 200
        participant.to_json
      else
        participant = self.class.registerParticipant("SerengetiInterestingAnimalsExperiment1",inputs[:user_id])
        if participant
          #status 201
          cohort = self.class.getCohort(inputs[:user_id])
          participant[:cohort] = cohort
          if cohort==@@COHORT_CONTROL
            assignToControl(participant,true)
            params[:message] = "#{inputs[:user_id]} assigned to control cohort for experiment #{inputs[:experiment_name]}"
          elsif cohort==@@COHORT_INSERTION
            #TODO get species for this user
            species="lionMale"
            subjectIDs = self.class.getInsertionSubjects(species,@@SUBJECTS_TO_INSERT_PER_SPECIES)
            if subjectIDs
              participant[:insertion_subjects_available] = subjectIDs
              participant[:num_random_subjects_available] = subjectIDs.length * @@INSERTION_RATIO
              #TODO update for multi species
            else
              assignToControl(participant,false)
              participant[:fallback_reason] = "Unable to establish preferences for #{inputs[:user_id]} in experiment #{inputs[:experiment_name]} - treating as a control user."
            end
            params[:message] = "Successfully registered #{inputs[:user_id]} as a participant in experiment #{inputs[:experiment_name]}"
          else
            assignToControl(participant,false)
            participant[:fallback_reason] = "Unrecognized cohort #{cohort} was assigned for #{inputs[:user_id]} in experiment #{inputs[:experiment_name]}. Assigning to control."
          end
          participant.save
          participant.attributes.each do |attr_name, attr_value|
            params[attr_name]=attr_value unless attr_name=="_id"
          end
        else
          params[:error] = "Could not register participant #{inputs[:user_id]} for experiment #{inputs[:experiment_name]} due to internal error."
        end
      end
    end
  end
end

__END__

#TODO create SQL find user's most liked subjects, and from that, the most liked species
