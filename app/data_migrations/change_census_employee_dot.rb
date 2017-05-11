require File.join(Rails.root, "lib/mongoid_migration_task")
class ChangeCensusEmployeeDot < MongoidMigrationTask
  def migrate
    begin
      ce=CensusEmployee.find(ENV['census_employee_id'])
      dot = Date.strptime(ENV['date_of_terminate'].to_s, "%m/%d/%Y")
      if ce.nil?
        puts "No census employee was found with the given id" unless Rails.env.test?
      elsif ce.aasm_state != "employment_terminated"
        ce.update_attributes(aasm_state:"employment_terminated")
        ce.update_attributes(employment_terminated_on: dot)
        puts "Changed census employee to termination state and employment termination date to #{dot}" unless Rails.env.test?
      else
        ce.update_attributes(employment_terminated_on: dot)
        puts "Changed census employee employment termination date to #{dot}" unless Rails.env.test?
      end
    rescue Exception => e
      puts e.message
    end
  end
end
