require 'plan_out'
require "mysql"
require "pry"

module PlanOut
  class SerengetiBlanksExperiment1 < PlanOut::SimpleExperiment
    @@ENV = Assignment.new('http://experiments.zooniverse.org/')  # seed for random assignment to cohorts
    @@SUBJECTS_IN_SET = 70  # how many subjects to include in the experiment set
    @@COHORT_00 = "0"
    @@COHORT_20 = "20"
    @@COHORT_40 = "20"
    @@COHORT_60 = "20"
    @@COHORT_80 = "20"
    @@COHORT_INELIGIBLE = "ineligible"
    @@COHORT_CONTROL = "control"
    @@DB_HOST = 'zooniverse-db1.cezuuccr9cw6.us-east-1.rds.amazonaws.com'
    @@DB_USERNAME = 'geordi-agent'
    @@DB_PASSWORD = '7yofU[GPO3?lAOD'
    @@DB_DATABASE = 'geordi'


    def setup

    end

    def self.projects
      ["serengeti"]
    end

    def self.getNumberOfBlanks(cohort)
      if cohort == @@COHORT_20
        return (0.2 * @@SUBJECTS_IN_SET).round
      elsif cohort == @@COHORT_40
        return (0.4 * @@SUBJECTS_IN_SET).round
      elsif cohort == @@COHORT_60
        return (0.6 * @@SUBJECTS_IN_SET).round
      elsif cohort == @@COHORT_80
        return (0.8 * @@SUBJECTS_IN_SET).round
      else
        return 0
      end
    end

    def self.getNumberOfNonBlanks(cohort)
      if cohort == @@COHORT_00
        return @@SUBJECTS_IN_SET
      elsif cohort == @@COHORT_20
        return (0.8 * @@SUBJECTS_IN_SET).round
      elsif cohort == @@COHORT_40
        return (0.6 * @@SUBJECTS_IN_SET).round
      elsif cohort == @@COHORT_60
        return (0.4 * @@SUBJECTS_IN_SET).round
      elsif cohort == @@COHORT_80
        return (0.2 * @@SUBJECTS_IN_SET).round
      else
        return 0
      end
    end

    def self.getCohort(user_id)
      UniformChoice.new({
          choices: [@@COHORT_00,@@COHORT_20,@@COHORT_40,@@COHORT_60,@@COHORT_80,@@COHORT_CONTROL],
          unit: user_id
        }).execute(@@ENV)
    end

    def self.getNonBlankSubjectID()
      begin
        subjectID = nil
        con = Mysql.new @@DB_HOST,@@DB_USERNAME,@@DB_PASSWORD,@@DB_DATABASE
        query = 'SELECT subjectID FROM subject_species_all AS r1 JOIN (SELECT CEIL(RAND() * (SELECT MAX(id) FROM subject_species_all)) AS id) AS r2 WHERE r1.id >= r2.id AND r1.species<>"blank" ORDER BY r1.id ASC LIMIT 1;'
        rs = con.query(query)
        rs.each do |row|
          subjectID = row[0].to_s
        end
        return subjectID
      rescue Mysql::Error => e
        puts e
        return nil
      ensure
        con.close if con
      end
    end

    def self.getBlankSubjectID()
      subjectID = nil
      begin
        subjectID = nil
        con = Mysql.new @@DB_HOST,@@DB_USERNAME,@@DB_PASSWORD,@@DB_DATABASE
        query = 'SELECT subjectID FROM subject_species_all AS r1 JOIN (SELECT CEIL(RAND() * (SELECT MAX(id) FROM subject_species_all)) AS id) AS r2 WHERE r1.id >= r2.id AND r1.species="blank" ORDER BY r1.id ASC LIMIT 1;'
        rs = con.query(query)
        rs.each do |row|
          subjectID = row[0].to_s
        end
        return subjectID
      rescue Mysql::Error => e
        puts e
        return nil
      ensure
        con.close if con
      end
    end

    def self.registerParticipant(experiment_name,user_id)
      Participant.create({experiment_name:                experiment_name,
                          user_id:                        user_id,
                          active:                         true,
                          non_blank_subjects_seen:        [],
                          blank_subjects_seen:            [],
                          excluded:                       false
                         })
    end

    def self.markParticipantIneligible(participant)
      participant[:active] = false
      participant[:cohort] = @@COHORT_INELIGIBLE
      # user is not part of experiment - clear all "available" data (but leave a record of "seen")
      participant[:blank_subjects_available] = []
      participant[:non_blank_subjects_available] = []
    end

    def self.deactivateParticipant(participant)
      participant[:active] = false
      # user is not part of experiment - clear all "available" data (but leave a record of "seen")
      participant[:blank_subjects_available] = []
      participant[:non_blank_subjects_available] = []
      participant.save
    end

    def self.initializeParticipant(user_id,experiment_name,params,participant)
      if participant
        cohort = SerengetiBlanksExperiment1::getCohort(user_id)
        participant[:cohort] = cohort
        participant[:blank_subjects_available] = []
        participant[:non_blank_subjects_available] = []
        if cohort!=@@COHORT_CONTROL
          # figure out the subject IDs for experimental cohorts and prepare the subject sets
          blanks = SerengetiBlanksExperiment1.getNumberOfBlanks(cohort)
          non_blanks = SerengetiBlanksExperiment1.getNumberOfNonBlanks(cohort)
          do_not_repeat_these = []
          for i in 1..blanks
            blankSubjectID = SerengetiBlanksExperiment1.getBlankSubjectID()
            until blankSubjectID.present? and !do_not_repeat_these.include? blankSubjectID do
              blankSubjectID = SerengetiBlanksExperiment1.getBlankSubjectID()
              if !do_not_repeat_these.include? blankSubjectID
                do_not_repeat_these.push blankSubjectID
              end
            end
            participant[:blank_subjects_available].push("#{blankSubjectID}:blank")
          end
          for i in 1..non_blanks
            nonBlankSubjectID = SerengetiBlanksExperiment1.getNonBlankSubjectID()
            until nonBlankSubjectID.present? and !do_not_repeat_these.include? nonBlankSubjectID do
              nonBlankSubjectID = SerengetiBlanksExperiment1.getNonBlankSubjectID()
              if !do_not_repeat_these.include? nonBlankSubjectID
                do_not_repeat_these.push nonBlankSubjectID
              end
            end
            participant[:non_blank_subjects_available].push("#{nonBlankSubjectID}:non-blank")
          end
        end
        participant.save
        params[:message] = "Successfully registered #{user_id} as a participant in experiment #{experiment_name}, cohort #{cohort}"
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
        if participant.present?
          #status 200
          params[:message] = "#{inputs[:user_id]} already assigned for experiment #{inputs[:experiment_name]}"
          participant.to_json
        else
          participant = SerengetiBlanksExperiment1::registerParticipant("SerengetiBlanksExperiment1",inputs[:user_id])
          SerengetiBlanksExperiment1::initializeParticipant(inputs[:user_id],inputs[:experiment_name],params,participant)
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