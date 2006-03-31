class Idcitizen < ActiveRecord::Base
  validates_presence_of :identification_id, :citizen_country_id
  validates_numericality_of :identification_id, :citizen_country_id
  belongs_to :identification
  belongs_to :citizen_country, :class_name => 'Country', :foreign_key => 'citizen_country_id'
end
